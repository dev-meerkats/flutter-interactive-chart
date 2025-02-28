import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';

import 'mock_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<CandleData> _data = MockDataTesla.candles;
  bool _darkMode = true;
  bool _showAverage = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: _darkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Interactive Chart Demo"),
          actions: [
            IconButton(
              icon: Icon(_darkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () => setState(() => _darkMode = !_darkMode),
            ),
            IconButton(
              icon: Icon(
                _showAverage ? Icons.show_chart : Icons.bar_chart_outlined,
              ),
              onPressed: () {
                setState(() => _showAverage = !_showAverage);
                if (_showAverage) {
                  _computeTrendLines();
                } else {
                  _removeTrendLines();
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          minimum: const EdgeInsets.all(24.0),
          child: InteractiveChart(
            /** 필수 파라미터는 [candles]뿐입니다. */
            candles: _data,
            /** 선택적 파라미터에 대한 예시 (주석 해제 시 사용) */

            /** 예제 스타일링 */
            // style: ChartStyle(
            //   priceGainColor: Colors.teal[200]!,
            //   priceLossColor: Colors.blueGrey,
            //   volumeColor: Colors.teal.withOpacity(0.8),
            //   trendLineStyles: [
            //     Paint()
            //       ..strokeWidth = 2.0
            //       ..strokeCap = StrokeCap.round
            //       ..color = Colors.deepOrange,
            //     Paint()
            //       ..strokeWidth = 4.0
            //       ..strokeCap = StrokeCap.round
            //       ..color = Colors.orange,
            //   ],
            //   priceGridLineColor: Colors.blue[200]!,
            //   priceLabelStyle: TextStyle(color: Colors.blue[200]),
            //   timeLabelStyle: TextStyle(color: Colors.blue[200]),
            //   selectionHighlightColor: Colors.red.withOpacity(0.2),
            //   overlayBackgroundColor: Colors.red[900]!.withOpacity(0.6),
            //   overlayTextStyle: TextStyle(color: Colors.red[100]),
            //   timeLabelHeight: 32,
            //   volumeHeightFactor: 0.2, // 거래량 영역은 전체 높이의 20%입니다.
            // ),
            /** 축 레이블 사용자 정의 */
            // timeLabel: (timestamp, visibleDataCount) => "📅",
            // priceLabel: (price) => "${price.round()} 💎",
            /** 오버레이 사용자 정의 (길게 눌러서 확인)
             ** 또는 오버레이 정보를 비활성화하려면 빈 객체를 반환하세요. */
            // overlayInfo: (candle) => {
            //   "💎": "🤚    ",
            //   "Hi": "${candle.high?.toStringAsFixed(2)}",
            //   "Lo": "${candle.low?.toStringAsFixed(2)}",
            // },
            /** 콜백 함수 */
            // onTap: (candle) => print("user tapped on $candle"),
            // onCandleResize: (width) => print("each candle is $width wide"),
          ),
        ),
      ),
    );
  }

  _computeTrendLines() {
    final ma7 = CandleData.computeMA(_data, 7);
    final ma30 = CandleData.computeMA(_data, 30);
    final ma90 = CandleData.computeMA(_data, 90);

    for (int i = 0; i < _data.length; i++) {
      _data[i].trends = [ma7[i], ma30[i], ma90[i]];
    }
  }

  _removeTrendLines() {
    for (final data in _data) {
      data.trends = [];
    }
  }
}
