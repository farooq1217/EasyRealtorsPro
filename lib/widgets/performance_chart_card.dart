import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class PerformanceChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  
  const PerformanceChartCard({super.key, required this.data});
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1B1F24).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark 
                ? Colors.grey.shade700
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'No performance data available',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ),
      );
    }
    
    final maxValue = data.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), (entry.value['value'] as int).toDouble());
    }).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Value of Sales/Rentals (Last 6 Months)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 0 ? maxValue / 5 : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1, // Show every label
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: 60, // Fixed width to prevent overlap
                              child: Text(
                                data[index]['month'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 55, // Increased from 30 to 55 for better spacing
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: maxValue > 0 ? maxValue * 1.2 : 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFFFF6B35),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

