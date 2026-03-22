import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/font_utils.dart';
import 'package:shared/shared.dart' show TradingEntry;

class RevenueAreaChart extends StatelessWidget {
  final List<TradingEntry> tradingEntries;

  const RevenueAreaChart({
    super.key,
    required this.tradingEntries,
  });

  @override
  Widget build(BuildContext context) {
    if (tradingEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 48,
              color: Color(0xFFCBD5E0),
            ),
            SizedBox(height: 8),
            Text(
              'No trading data available',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
      );
    }

    // Process trading data for the chart
    final chartData = _processTradingData();
    
    if (chartData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 48,
              color: Color(0xFFCBD5E0),
            ),
            SizedBox(height: 8),
            Text(
              'No completed trading data available',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
      );
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateHorizontalInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE2E8F0),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _calculateHorizontalInterval(),
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact().format(value),
                  style: AppFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF718096),
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < chartData.length && value.toInt() >= 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      chartData[value.toInt()].label,
                      style: AppFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: chartData
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            isCurved: true,
            color: const Color(0xFF805AD5),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF805AD5),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF805AD5).withOpacity(0.3),
                  const Color(0xFF805AD5).withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minX: 0,
        maxX: (chartData.length - 1).toDouble(),
        minY: 0,
        maxY: _calculateMaxY(),
      ),
    );
  }

  List<ChartDataPoint> _processTradingData() {
    // Group trading entries by week and calculate revenue
    final Map<String, double> weeklyRevenue = {};
    
    for (final entry in tradingEntries) {
      if (entry.status == 'completed' && entry.isActive) {
        final weekKey = _getWeekKey(entry.createdAt);
        final revenue = (entry.totalPrice * entry.quantity);
        weeklyRevenue[weekKey] = (weeklyRevenue[weekKey] ?? 0) + revenue;
      }
    }
    
    // Sort by week and take last 8 weeks
    final sortedWeeks = weeklyRevenue.keys.toList()..sort();
    final recentWeeks = sortedWeeks.length > 8 
        ? sortedWeeks.sublist(sortedWeeks.length - 8)
        : sortedWeeks;
    
    return recentWeeks.map((week) {
      return ChartDataPoint(
        label: _formatWeekLabel(week),
        value: weeklyRevenue[week] ?? 0,
      );
    }).toList();
  }

  String _getWeekKey(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
  }

  String _formatWeekLabel(String weekKey) {
    final parts = weekKey.split('-');
    if (parts.length == 3) {
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return DateFormat('MMM d').format(date);
    }
    return weekKey;
  }

  double _calculateHorizontalInterval() {
    if (tradingEntries.isEmpty) return 1000;
    
    final maxValue = tradingEntries
        .where((e) => e.status == 'completed' && e.isActive)
        .fold<double>(0, (sum, e) => sum + (e.totalPrice * e.quantity));
    
    if (maxValue <= 10000) return 2000;
    if (maxValue <= 50000) return 10000;
    if (maxValue <= 100000) return 20000;
    return 50000;
  }

  double _calculateMaxY() {
    if (tradingEntries.isEmpty) return 1000;
    
    final maxValue = tradingEntries
        .where((e) => e.status == 'completed' && e.isActive)
        .fold<double>(0, (sum, e) => sum + (e.totalPrice * e.quantity));
    
    return maxValue * 1.2;
  }
}

class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint({
    required this.label,
    required this.value,
  });
}
