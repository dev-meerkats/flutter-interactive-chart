import 'package:flutter/material.dart';

/// 📌 차트 스타일을 정의하는 클래스
///
/// 이 클래스는 차트의 색상, 텍스트 스타일, 패딩 등을 설정합니다.
/// 예를 들어, 상승/하락 캔들의 색상, 거래량 바의 색상, 가격 및 시간 라벨 스타일 등을 지정할 수 있습니다.
class ChartStyle {
  /// 🔹 거래량 영역의 높이 비율 (전체 차트 높이 대비)
  ///
  /// 기본값은 `0.2` (즉, 거래량 바가 전체 차트의 20%를 차지)
  final double volumeHeightFactor;

  /// 🔹 차트 오른쪽 가격 라벨의 너비
  final double priceLabelWidth;

  /// 🔹 차트 아래쪽 시간 라벨의 높이
  ///
  /// 기본값은 `24.0`. 이 값을 조정하면 차트와 날짜/시간 라벨 사이의 간격을 변경할 수 있습니다.
  final double timeLabelHeight;

  /// 🔹 시간 레이블의 텍스트 스타일 (차트 하단)
  final TextStyle timeLabelStyle;

  /// 🔹 가격 레이블의 텍스트 스타일 (차트 오른쪽)
  final TextStyle priceLabelStyle;

  /// 🔹 차트 위에 표시되는 오버레이 텍스트 스타일
  ///
  /// 사용자가 차트를 클릭하거나 호버할 때 나타나는 정보의 스타일을 정의합니다.
  final TextStyle overlayTextStyle;

  /// 🔹 가격이 상승한 경우(종가 > 시가) 캔들 색상
  final Color priceGainColor;

  /// 🔹 가격이 하락한 경우(종가 < 시가) 캔들 색상
  final Color priceLossColor;

  /// 🔹 거래량 바의 색상
  final Color volumeColor;

  /// 🔹 트렌드 라인의 스타일
  ///
  /// 여러 개의 트렌드 라인이 있을 경우, 이 리스트에서 순서대로 스타일을 적용합니다.
  /// 리스트가 부족할 경우 기본값(파란색)이 사용됩니다.
  final List<Paint> trendLineStyles;

  /// 🔹 가격 그리드 라인의 색상 (수평선)
  final Color priceGridLineColor;

  /// 🔹 선택된 캔들 하이라이트 색상 (사용자가 클릭/호버할 때)
  final Color selectionHighlightColor;

  /// 🔹 오버레이 배경 색상 (차트 위에 나타나는 정보 창)
  final Color overlayBackgroundColor;

  /// 📌 `ChartStyle` 생성자
  ///
  /// 모든 속성은 기본값이 제공되며, 필요할 경우 개별적으로 커스텀할 수 있습니다.
  const ChartStyle({
    this.volumeHeightFactor = 0.2,
    this.priceLabelWidth = 48.0,
    this.timeLabelHeight = 24.0,
    this.timeLabelStyle = const TextStyle(
      fontSize: 16,
      color: Colors.grey,
    ),
    this.priceLabelStyle = const TextStyle(
      fontSize: 12,
      color: Colors.grey,
    ),
    this.overlayTextStyle = const TextStyle(
      fontSize: 16,
      color: Colors.white,
    ),
    this.priceGainColor = Colors.green,
    this.priceLossColor = Colors.red,
    this.volumeColor = Colors.grey,
    this.trendLineStyles = const [],
    this.priceGridLineColor = Colors.grey,
    this.selectionHighlightColor = const Color(0x33757575),
    this.overlayBackgroundColor = const Color(0xEE757575),
  });
}
