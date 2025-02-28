import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import 'candle_data.dart';
import 'chart_painter.dart';
import 'chart_style.dart';
import 'painter_params.dart';

class InteractiveChart extends StatefulWidget {
  /// 차트에서 사용할 [CandleData]의 전체 리스트.
  ///
  /// 최소 3개 이상의 데이터가 필요합니다.
  /// 데이터가 충분히 많을 경우, 기본적으로 가장 최근 90개의 데이터를 표시하며
  /// ([initialVisibleCandleCount]로 조정 가능), 사용자는 자유롭게 확대/축소 및 스크롤할 수 있습니다.
  final List<CandleData> candles;

  /// 차트가 처음 열릴 때 기본적으로 표시할 데이터 포인트 수.
  /// 기본값은 90이며, [CandleData]의 데이터가 부족하면 전체 데이터를 표시합니다.
  final int initialVisibleCandleCount;

  /// 차트 스타일을 설정합니다 (null이 아닐 경우).
  final ChartStyle style;

  /// 하단의 날짜/시간 레이블 형식을 지정합니다.
  ///
  /// 기본값은 표시된 데이터가 20개 이상일 경우 `yyyy-mm` 형식,
  /// 20개 미만일 경우 `mm-dd` 형식으로 자동 설정됩니다.
  final TimeLabelGetter? timeLabel;

  /// 오른쪽 가격 레이블 형식을 지정합니다.
  ///
  /// 기본적으로 소수점 두 자리까지 표시됩니다.
  final PriceLabelGetter? priceLabel;

  /// 사용자가 차트를 터치할 때 표시되는 오버레이 정보.
  ///
  /// 기본적으로 `date`, `open`, `high`, `low`, `close`, `volume`을 표시합니다.
  ///
  /// 커스텀하려면 `Map<String, String>`을 반환하는 함수를 전달하세요:
  /// ```dart
  /// return {
  ///   "날짜": "사용자 지정 날짜 형식",
  ///   "시가": candle.open?.toStringAsFixed(2) ?? "-",
  ///   "종가": candle.close?.toStringAsFixed(2) ?? "-",
  /// };
  /// ```
  final OverlayInfoGetter? overlayInfo;

  /// 사용자가 캔들스틱을 클릭할 때 발생하는 선택적 이벤트.
  final ValueChanged<CandleData>? onTap;

  /// 사용자가 줌(확대/축소)할 때 발생하는 선택적 이벤트.
  ///
  /// 현재 줌 레벨에서 개별 캔들의 너비를 제공합니다.
  final ValueChanged<double>? onCandleResize;

  const InteractiveChart({
    Key? key,
    required this.candles,
    this.initialVisibleCandleCount = 90,
    ChartStyle? style,
    this.timeLabel,
    this.priceLabel,
    this.overlayInfo,
    this.onTap,
    this.onCandleResize,
  })  : this.style = style ?? const ChartStyle(),
        assert(candles.length >= 3, "InteractiveChart requires 3 or more CandleData"),
        assert(initialVisibleCandleCount >= 3, "initialVisibleCandleCount must be more 3 or more"),
        super(key: key);

  @override
  _InteractiveChartState createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  // 차트에서 개별 캔들의 너비.
  late double _candleWidth;

  // 현재 차트 창에서의 X 오프셋(px).
  // 값이 0.0이면 첫 번째 데이터를 표시하며,
  // 값이 20 * _candleWidth이면 첫 20개의 데이터를 건너뜁니다.
  late double _startOffset;

  // 사용자가 현재 클릭한 위치 (클릭하지 않았을 경우 null).
  Offset? _tapPosition;

  double? _prevChartWidth; // used by _handleResize
  late double _prevCandleWidth;
  late double _prevStartOffset;
  late Offset _initialFocalPoint;
  PainterParams? _prevParams; // used in onTapUp event

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final size = constraints.biggest;
        final w = size.width - widget.style.priceLabelWidth;
        _handleResize(w);

        // 현재 보이는 데이터 범위 찾기
        final int start = (_startOffset / _candleWidth).floor();
        final int count = (w / _candleWidth).ceil();
        final int end = (start + count).clamp(start, widget.candles.length);
        final candlesInRange = widget.candles.getRange(start, end).toList();
        if (end < widget.candles.length) {
          // 스크롤 시 추가 아이템을 포함하여 부드러운 렌더링 지원
          final nextItem = widget.candles[end];
          candlesInRange.add(nextItem);
        }

        // 가능한 경우, 이전 및 이후의 트렌드 라인 데이터를 찾기
        final leadingTrends = widget.candles.at(start - 1)?.trends;
        final trailingTrends = widget.candles.at(end + 1)?.trends;

        /// 캔들을 그릴 때 필요한 가로 이동값을 계산합니다.
        /// 먼저, 항상 차트를 반 캔들만큼 이동합니다.
        /// 그 이유는 굵은 선(Paint)을 사용할 때, 선이 양쪽으로 퍼지기 때문입니다.
        /// 그 다음, 사용자가 스크롤할 때 정확한 위치에서 멈추지 않기 때문에
        /// "캔들의 일부(fraction)"가 얼마나 보이는지 계산합니다.
        final halfCandle = _candleWidth / 2;
        final fractionCandle = _startOffset - start * _candleWidth;
        final xShift = halfCandle - fractionCandle;

        /// 현재 보이는 데이터 중 최소값과 최대값을 계산합니다.
        double? highest(CandleData c) {
          if (c.high != null) return c.high;
          if (c.open != null && c.close != null) return max(c.open!, c.close!);
          return c.open ?? c.close;
        }

        double? lowest(CandleData c) {
          if (c.low != null) return c.low;
          if (c.open != null && c.close != null) return min(c.open!, c.close!);
          return c.open ?? c.close;
        }

        final maxPrice = candlesInRange.map(highest).whereType<double>().reduce(max);
        final minPrice = candlesInRange.map(lowest).whereType<double>().reduce(min);
        final maxVol = candlesInRange
            .map((c) => c.volume)
            .whereType<double>()
            .fold(double.negativeInfinity, max);
        final minVol =
            candlesInRange.map((c) => c.volume).whereType<double>().fold(double.infinity, min);

        final child = TweenAnimationBuilder(
          tween: PainterParamsTween(
            end: PainterParams(
              candles: candlesInRange,
              style: widget.style,
              size: size,
              candleWidth: _candleWidth,
              startOffset: _startOffset,
              maxPrice: maxPrice,
              minPrice: minPrice,
              maxVol: maxVol,
              minVol: minVol,
              xShift: xShift,
              tapPosition: _tapPosition,
              leadingTrends: leadingTrends,
              trailingTrends: trailingTrends,
            ),
          ),
          duration: Duration(milliseconds: 100),
          curve: Curves.easeOut,
          builder: (_, PainterParams params, __) {
            _prevParams = params;
            return RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: ChartPainter(
                  params: params,
                  getTimeLabel: widget.timeLabel ?? defaultTimeLabel,
                  getPriceLabel: widget.priceLabel ?? defaultPriceLabel,
                  getOverlayInfo: widget.overlayInfo ?? defaultOverlayInfo,
                ),
              ),
            );
          },
        );

        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              final dy = signal.scrollDelta.dy;
              if (dy.abs() > 0) {
                _onScaleStart(signal.position);
                _onScaleUpdate(
                  dy > 0 ? 0.9 : 1.1,
                  signal.position,
                  w,
                );
              }
            }
          },
          child: GestureDetector(
            /// 캔들 정보를 보기 위해 탭하고 길게 누르세요.
            onTapDown: (details) => setState(() {
              _tapPosition = details.localPosition;
            }),
            onTapCancel: () => setState(() => _tapPosition = null),
            onTapUp: (_) {
              /// 콜백 이벤트를 실행하고 `_tapPosition`을 초기화합니다.
              if (widget.onTap != null) _fireOnTapEvent();
              setState(() => _tapPosition = null);
            },

            /// 패닝(이동) 및 줌(확대/축소)
            onScaleStart: (details) => _onScaleStart(details.localFocalPoint),
            onScaleUpdate: (details) => _onScaleUpdate(details.scale, details.localFocalPoint, w),
            child: child,
          ),
        );
      },
    );
  }

  /// 🔹 줌(확대/축소) 시작 시 초기 값 저장
  _onScaleStart(Offset focalPoint) {
    _prevCandleWidth = _candleWidth;
    _prevStartOffset = _startOffset;
    _initialFocalPoint = focalPoint;
  }

  /// 🔹 줌(확대/축소) 및 패닝(이동) 처리
  _onScaleUpdate(double scale, Offset focalPoint, double w) {
    // 🔹 줌(확대/축소) 처리
    final candleWidth =
        (_prevCandleWidth * scale).clamp(_getMinCandleWidth(w), _getMaxCandleWidth(w));
    final clampedScale = candleWidth / _prevCandleWidth;
    var startOffset = _prevStartOffset * clampedScale;

    // 🔹 패닝(스크롤) 처리
    final dx = (focalPoint - _initialFocalPoint).dx * -1;
    startOffset += dx;

    // 🔹 줌 시 스크롤 위치 자동 조정
    final double prevCount = w / _prevCandleWidth;
    final double currCount = w / candleWidth;
    final zoomAdjustment = (currCount - prevCount) * candleWidth;
    final focalPointFactor = focalPoint.dx / w;
    startOffset -= zoomAdjustment * focalPointFactor;

    // 🔹 시작 위치를 최소/최대 값으로 제한
    startOffset = startOffset.clamp(0, _getMaxStartOffset(w, candleWidth));

    // 🔹 줌 이벤트 발생 (사용자 정의 콜백 실행)
    if (candleWidth != _candleWidth) {
      widget.onCandleResize?.call(candleWidth);
    }

    // 🔹 변경 사항 적용
    setState(() {
      _candleWidth = candleWidth;
      _startOffset = startOffset;
    });
  }

  /// 🔹 차트 크기 변경 시 호출됨 (예: 화면 회전)
  _handleResize(double w) {
    if (w == _prevChartWidth) return;
    if (_prevChartWidth != null) {
      // 🔹 화면 크기 변경 시 줌 범위 재설정
      _candleWidth = _candleWidth.clamp(
        _getMinCandleWidth(w),
        _getMaxCandleWidth(w),
      );
      _startOffset = _startOffset.clamp(
        0,
        _getMaxStartOffset(w, _candleWidth),
      );
    } else {
      // 🔹 기본 줌 레벨 설정 (기본값: 최근 90일 데이터)
      final count = min(
        widget.candles.length,
        widget.initialVisibleCandleCount,
      );
      _candleWidth = w / count;

      // 🔹 최신 데이터를 기본으로 표시
      _startOffset = (widget.candles.length - count) * _candleWidth;
    }
    _prevChartWidth = w;
  }

  /// 🔹 가장 좁은 캔들 너비 반환 (모든 데이터를 한 번에 표시할 경우)
  double _getMinCandleWidth(double w) => w / widget.candles.length;

  /// 🔹 가장 넓은 캔들 너비 반환 (기본적으로 14일 데이터 표시)
  double _getMaxCandleWidth(double w) => w / min(14, widget.candles.length);

  /// 🔹 최대 시작 오프셋 반환 (차트의 끝까지 스크롤할 수 있는 범위)
  double _getMaxStartOffset(double w, double candleWidth) {
    final count = w / candleWidth; // 현재 창에서 보이는 캔들 수
    final start = widget.candles.length - count;
    return max(0, candleWidth * start);
  }

  /// 🔹 기본 시간 레이블 형식 (yyyy-mm 또는 mm-dd)
  String defaultTimeLabel(int timestamp, int visibleDataCount) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp)
        .toIso8601String()
        .split("T")
        .first
        .split("-");

    if (visibleDataCount > 20) {
      // 🔹 20개 이상의 데이터가 보일 경우 연도와 월 표시
      return "${date[0]}-${date[1]}"; // yyyy-mm
    } else {
      // 🔹 20개 미만의 데이터가 보일 경우 월과 일 표시
      return "${date[1]}-${date[2]}"; // mm-dd
    }
  }

  /// 🔹 기본 가격 레이블 형식 (소수점 두 자리)
  String defaultPriceLabel(double price) => price.toStringAsFixed(2);

  /// 🔹 기본 오버레이 정보 (캔들 정보를 문자열로 변환)
  Map<String, String> defaultOverlayInfo(CandleData candle) {
    final date =
        intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(candle.timestamp));
    return {
      "날짜": date,
      "시가": candle.open?.toStringAsFixed(2) ?? "-",
      "고가": candle.high?.toStringAsFixed(2) ?? "-",
      "저가": candle.low?.toStringAsFixed(2) ?? "-",
      "종가": candle.close?.toStringAsFixed(2) ?? "-",
      "거래량": candle.volume?.asAbbreviated() ?? "-",
    };
  }

  /// 🔹 사용자가 캔들을 클릭했을 때 실행되는 이벤트 핸들러
  void _fireOnTapEvent() {
    if (_prevParams == null || _tapPosition == null) return;
    final params = _prevParams!;
    final dx = _tapPosition!.dx;
    final selected = params.getCandleIndexFromOffset(dx);
    final candle = params.candles[selected];
    widget.onTap?.call(candle);
  }
}

/// 🔹 숫자를 퍼센트 문자열로 변환하는 확장 메서드
extension Formatting on double {
  String asPercent() {
    final format = this < 100 ? "##0.00" : "#,###";
    final v = intl.NumberFormat(format, "en_US").format(this);
    return "${this >= 0 ? '+' : ''}$v%";
  }

  /// 🔹 숫자를 K(천), M(백만), B(십억) 등의 단위로 변환하는 확장 메서드
  String asAbbreviated() {
    if (this < 1000) return this.toStringAsFixed(3);
    if (this >= 1e18) return this.toStringAsExponential(3);
    final s = intl.NumberFormat("#,###", "en_US").format(this).split(",");
    const suffixes = ["K", "M", "B", "T", "Q"];
    return "${s[0]}.${s[1]}${suffixes[s.length - 2]}";
  }
}
