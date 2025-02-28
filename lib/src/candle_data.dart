/// 캔들 데이터 클래스: 차트에서 사용할 개별 데이터 포인트를 정의
class CandleData {
  /// 데이터 포인트의 타임스탬프 (밀리초 단위, epoch 기준)
  final int timestamp;

  /// "시가" 가격 (null 허용, 일부 데이터가 빠져도 가능)
  final double? open;

  /// "고가" 가격 (null 허용, 데이터가 없으면 심지를 그리지 않음)
  final double? high;

  /// "저가" 가격 (null 허용, 데이터가 없으면 심지를 그리지 않음)
  final double? low;

  /// "종가" 가격 (null 허용, 일부 데이터가 빠져도 가능)
  final double? close;

  /// 거래량 데이터 (null 허용)
  final double? volume;

  /// 특정 캔들에 대한 트렌드 라인 데이터 (이동평균선 등)
  /// 예: `trends = [ma7, ma30]` (7일, 30일 이동평균선)
  List<double?> trends;

  /// 캔들 데이터 생성자
  CandleData({
    required this.timestamp,
    required this.open,
    required this.close,
    required this.volume,
    this.high,
    this.low,
    List<double?>? trends,
  }) : this.trends = List.unmodifiable(trends ?? []);

  /// 이동평균(MA) 계산 함수
  static List<double?> computeMA(List<CandleData> data, [int period = 7]) {
    if (data.length < period * 2) return List.filled(data.length, null);
    final List<double?> result = [];
    final firstPeriod = data.take(period).map((d) => d.close).whereType<double>();
    double ma = firstPeriod.reduce((a, b) => a + b) / firstPeriod.length;
    result.addAll(List.filled(period, null));

    for (int i = period; i < data.length; i++) {
      final curr = data[i].close;
      final prev = data[i - period].close;
      if (curr != null && prev != null) {
        ma = (ma * period + curr - prev) / period;
        result.add(ma);
      } else {
        result.add(null);
      }
    }
    return result;
  }

  @override
  String toString() => "<CandleData ($timestamp: $close)>";
}
