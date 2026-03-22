import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/app_storage.dart';
import '../trading/view_models/trading_view_model.dart';
import '../inventory/view_models/inventory_view_model.dart';
import '../expenditure/view_models/expenditure_view_model.dart';
import '../users/view_models/user_view_model.dart';
import '../todo/view_models/todo_view_model.dart';
import '../todo/repositories/todo_repository_impl.dart';
import '../rental/view_models/rental_view_model.dart';
import 'widgets/sparkline_chart.dart';
import 'widgets/revenue_area_chart.dart';
import 'widgets/property_map_widget.dart';
import 'package:shared/shared.dart' show AppDatabase, TradingEntry;

class DashboardPage extends StatefulWidget {
  final AppDatabase db;
  const DashboardPage({super.key, required this.db});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Force data fetching on dashboard load using proper Provider access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryViewModel = Provider.of<InventoryViewModel>(context, listen: false);
      final userViewModel = Provider.of<UserViewModel>(context, listen: false);
      final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);
      final expenditureViewModel = Provider.of<ExpenditureViewModel>(context, listen: false);
      
      // Load data if lists are empty to ensure Dashboard populates
      debugPrint('Dashboard: Checking data - Societies: ${inventoryViewModel.societies.length}, Users: ${userViewModel.users.length}');
      
      if (inventoryViewModel.societies.isEmpty) {
        debugPrint('Dashboard: Loading societies...');
        inventoryViewModel.loadSocieties();
      }
      if (userViewModel.users.isEmpty) {
        debugPrint('Dashboard: Loading users...');
        userViewModel.initialize();
      }
      if (rentalViewModel.rentalItems.isEmpty) {
        debugPrint('Dashboard: Loading rental items...');
        rentalViewModel.initialize();
      }
      if (expenditureViewModel.currentTotal == 0) {
        debugPrint('Dashboard: Loading expenses...');
        expenditureViewModel.refreshData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryViewModel>(
      builder: (context, inventoryViewModel, child) {
        return Consumer<RentalViewModel>(
          builder: (context, rentalViewModel, child) {
            return Consumer<UserViewModel>(
              builder: (context, userViewModel, child) {
                return Consumer<ExpenditureViewModel>(
                  builder: (context, expenditureViewModel, child) {
                    return Consumer<TodoViewModel>(
                      builder: (context, todoViewModel, child) {
                        return Consumer<TradingViewModel>(
                          builder: (context, tradingViewModel, child) {
                            return Scaffold(
                              backgroundColor: const Color(0xFFF8F9FA),
                              body: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSummaryCards(
                                      context.watch<InventoryViewModel>(),
                                      context.watch<RentalViewModel>(),
                                      context.watch<UserViewModel>(),
                                      context.watch<ExpenditureViewModel>(),
                                      context.watch<TodoViewModel>(),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildCentralArea(
                                      context.watch<TradingViewModel>(),
                                      context.watch<InventoryViewModel>(),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildTradingPerformanceTable(context.watch<TradingViewModel>()),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }


  // Top 4 Summary Cards with Sparkline Charts
  Widget _buildSummaryCards(
    InventoryViewModel inventoryViewModel,
    RentalViewModel rentalViewModel,
    UserViewModel userViewModel,
    ExpenditureViewModel expenditureViewModel,
    TodoViewModel todoViewModel,
  ) {
    return Row(
      children: [
        // Total Inventory Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Inventory',
            value: inventoryViewModel.societies.length.toString(),
            icon: Icons.home,
            color: const Color(0xFF805AD5),
            sparklineData: _generateMockSparklineData(),
            loading: false, // Remove infinite loading spinner
          ),
        ),
        const SizedBox(width: 16),
        // Rental Items Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Rental Items',
            value: rentalViewModel.rentalItems.length.toString(),
            icon: Icons.apartment,
            color: const Color(0xFF4A90E2),
            sparklineData: _generateMockSparklineData(),
            loading: false, // Remove infinite loading spinner
          ),
        ),
        const SizedBox(width: 16),
        // Active Users Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Active Users',
            value: userViewModel.users.length.toString(),
            icon: Icons.people,
            color: const Color(0xFFFF6B35),
            sparklineData: _generateMockSparklineData(),
            loading: false, // Remove infinite loading spinner
          ),
        ),
        const SizedBox(width: 16),
        // Combined Summary Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Expenses & Tasks',
            value: 'Rs ${expenditureViewModel.currentTotal.toStringAsFixed(0)}',
            subtitle: 'Track expenses and tasks',
            icon: Icons.analytics,
            color: const Color(0xFF38A169),
            sparklineData: _generateMockSparklineData(),
            loading: false, // Remove infinite loading spinner
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required List<double> sparklineData,
    required bool loading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Value
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Sparkline Chart
          SizedBox(
            height: 60, // Fixed height to prevent layout issues
            width: double.infinity, // Fixed width to prevent overflow
            child: SparklineChart(
              data: sparklineData,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Central Charts & Map Area
  Widget _buildCentralArea(
    TradingViewModel tradingViewModel,
    InventoryViewModel inventoryViewModel,
  ) {
    return SizedBox(
      height: 450, // Fixed height to prevent layout issues
      child: Row(
        children: [
          // Left Chart (70%)
          Expanded(
            flex: 7,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Trend',
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completed trading performance over time',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: RevenueAreaChart(
                      tradingEntries: tradingViewModel.entries,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right Map (30%)
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PropertyMapWidget(
                tradingEntries: tradingViewModel.entries,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Trading Performance Table
  Widget _buildTradingPerformanceTable(TradingViewModel tradingViewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trading Performance',
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recent trading entries and their status',
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 16),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Person Name',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Property',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Type',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Quantity',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Table Data
          SizedBox(
            height: 300,
            child: tradingViewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: tradingViewModel.entries.take(10).length,
                    itemBuilder: (context, index) {
                      final entry = tradingViewModel.entries[index];
                      return _buildTradingRow(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingRow(TradingEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              entry.personName,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.estateName,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.entryType ?? 'N/A',
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.quantity.toString(),
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('dd MMM yyyy').format(entry.createdAt),
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3748),
              ),
            ),
          ),
          Expanded(
            child: _buildStatusBadge(entry.status),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = const Color(0xFFD4EDDA);
        textColor = const Color(0xFF155724);
        break;
      case 'cancelled':
        backgroundColor = const Color(0xFFF8D7DA);
        textColor = const Color(0xFF721C24);
        break;
      case 'pending':
      default:
        backgroundColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // Helper Methods
  List<double> _generateMockSparklineData() {
    // Generate realistic trend data with at least 2 points to prevent RangeError
    return [
      20, 25, 22, 30, 28, 35, 32, 40, 38, 45, 42, 48, 45, 50,
    ];
  }

  int _getPendingTasksCount() {
    // This would come from TodoViewModel in a real implementation
    return 5; // Mock value
  }

  // Remove old methods - replaced with new structure
}
