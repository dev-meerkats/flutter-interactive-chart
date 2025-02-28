import 'dart:ui';
import 'package:flutter/widgets.dart';

import 'chart_style.dart';
import 'candle_data.dart';

/// 📌 차트 렌더링에 필요한 매개변수를 관리하는 클래스
///
/// `PainterParams`는 차트의 크기, 캔들 너비, 스크롤 오프셋,
/// 최대/최소 가격 및 거래량 등 차트를 그리기 위한 데이터를 포함합니다.
class PainterParams {
  /// 🔹 차트에 표시될 캔들 데이터 리스트
  final List<CandleData> candles;

  /// 🔹 차트의 스타일 설정 (색상, 레이블 스타일 등)
  final ChartStyle style;

  /// 🔹 차트의 크기 (너비, 높이)
  final Size size;

  /// 🔹 개별 캔들(막대)의 너비 (줌 인/아웃에 따라 변경됨)
  final double candleWidth;

  /// 🔹 차트의 스크롤 오프셋 (왼쪽 기준)
  final double startOffset;

  /// 🔹 현재 차트에서 보이는 **최대/최소 가격**
  final double maxPrice;
  final double minPrice;

  /// 🔹 현재 차트에서 보이는 **최대/최소 거래량**
  final double maxVol;
  final double minVol;

  /// 🔹 X축 이동 거리 (줌/스크롤 시 사용)
  final double xShift;

  /// 🔹 사용자가 클릭(또는 호버)한 위치 (없으면 `null`)
  final Offset? tapPosition;

  /// 🔹 트렌드 라인 (이동 평균선 등) - 이전 데이터
  final List<double?>? leadingTrends;

  /// 🔹 트렌드 라인 (이동 평균선 등) - 이후 데이터
  final List<double?>? trailingTrends;

  /// 📌 `PainterParams` 생성자
  ///
  /// 모든 필드를 초기화하여 차트를 그릴 때 필요한 정보를 전달합니다.
  PainterParams({
    required this.candles,
    required this.style,
    required this.size,
    required this.candleWidth,
    required this.startOffset,
    required this.maxPrice,
    required this.minPrice,
    required this.maxVol,
    required this.minVol,
    required this.xShift,
    required this.tapPosition,
    required this.leadingTrends,
    required this.trailingTrends,
  });

  /// 🔹 차트에서 가격 레이블을 제외한 **실제 캔들 영역 너비** 반환
  double get chartWidth => size.width - style.priceLabelWidth;

  /// 🔹 차트에서 시간 레이블을 제외한 **실제 캔들 영역 높이** 반환
  double get chartHeight => size.height - style.timeLabelHeight;

  /// 🔹 거래량 차트의 높이 반환 (전체 차트 높이 대비 `volumeHeightFactor` 비율 적용)
  double get volumeHeight => chartHeight * style.volumeHeightFactor;

  /// 🔹 가격 차트의 높이 반환 (전체 높이에서 거래량 차트 높이를 제외한 값)
  double get priceHeight => chartHeight - volumeHeight;

  /// 🔹 특정 X 좌표가 가리키는 **캔들 인덱스** 반환
  ///
  /// 사용자가 특정 위치를 클릭했을 때 해당하는 캔들 데이터의 인덱스를 찾는 데 사용됨.
  int getCandleIndexFromOffset(double x) {
    final adjustedPos = x - xShift + candleWidth / 2;
    return adjustedPos ~/ candleWidth;
  }

  /// 🔹 특정 가격을 차트 내 Y 좌표로 변환
  ///
  /// 차트의 `maxPrice`와 `minPrice`를 기준으로 적절한 위치를 계산함.
  double fitPrice(double y) => priceHeight * (maxPrice - y) / (maxPrice - minPrice);

  /// 🔹 특정 거래량을 차트 내 Y 좌표로 변환
  ///
  /// 거래량 막대의 높이를 `maxVol`과 `minVol`을 기준으로 조정하여 표시.
  double fitVolume(double y) {
    final gap = 12; // 가격 차트와 거래량 차트 사이의 간격
    final baseAmount = 2; // 최소 거래량 바 높이 (너무 작아지지 않도록)

    if (maxVol == minVol) {
      // 모든 거래량이 동일하면, 거래량 막대를 일정 높이로 설정
      return priceHeight + volumeHeight / 2;
    }

    final volGridSize = (volumeHeight - baseAmount - gap) / (maxVol - minVol);
    final vol = (y - minVol) * volGridSize;
    return volumeHeight - vol + priceHeight - baseAmount;
  }

  /// 🔹 `PainterParams`를 보간(lerp)하여 부드러운 애니메이션 효과 제공
  ///
  /// `Tween`을 이용해 차트가 부드럽게 전환될 수 있도록 함.
  static PainterParams lerp(PainterParams a, PainterParams b, double t) {
    double lerpField(double getField(PainterParams p)) => lerpDouble(getField(a), getField(b), t)!;
    return PainterParams(
      candles: b.candles,
      style: b.style,
      size: b.size,
      candleWidth: b.candleWidth,
      startOffset: b.startOffset,
      maxPrice: lerpField((p) => p.maxPrice),
      minPrice: lerpField((p) => p.minPrice),
      maxVol: lerpField((p) => p.maxVol),
      minVol: lerpField((p) => p.minVol),
      xShift: b.xShift,
      tapPosition: b.tapPosition,
      leadingTrends: b.leadingTrends,
      trailingTrends: b.trailingTrends,
    );
  }

  /// 🔹 차트를 다시 그려야 하는지 여부를 결정
  ///
  /// 크기, 데이터, 스타일이 변경되었을 경우 `true`를 반환하여 `CustomPainter`가 다시 그려지도록 함.
  bool shouldRepaint(PainterParams other) {
    if (candles.length != other.candles.length) return true;
    if (size != other.size ||
        candleWidth != other.candleWidth ||
        startOffset != other.startOffset ||
        xShift != other.xShift) return true;
    if (maxPrice != other.maxPrice ||
        minPrice != other.minPrice ||
        maxVol != other.maxVol ||
        minVol != other.minVol) return true;
    if (tapPosition != other.tapPosition) return true;
    if (leadingTrends != other.leadingTrends || trailingTrends != other.trailingTrends) return true;
    if (style != other.style) return true;

    return false;
  }
}

/// 📌 `Tween`을 이용해 `PainterParams`를 애니메이션 적용 가능하도록 만듦.
///
/// 차트가 부드럽게 변환될 수 있도록 `lerp()`를 사용하여 상태를 보간함.
class PainterParamsTween extends Tween<PainterParams> {
  PainterParamsTween({
    PainterParams? begin,
    required PainterParams end,
  }) : super(begin: begin, end: end);

  @override
  PainterParams lerp(double t) => PainterParams.lerp(begin ?? end!, end!, t);
}
