import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/font_utils.dart';

class SparklineChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double width;

  const SparklineChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 40,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.length < 2) {
      return Container(
        height: height,
        width: width,
        child: const Center(
          child: Text(
            'No trend data',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFA0AEC0),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: data.reduce((a, b) => a < b ? a : b) * 0.9,
          maxY: data.reduce((a, b) => a > b ? a : b) * 1.1,
        ),
      ),
    );
  }
}
