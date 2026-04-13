import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/role_utils.dart';
import '../../../core/services/app_storage.dart';
import '../trading/view_models/trading_view_model.dart';
import '../trading/repositories/trading_repository_impl.dart';
import '../inventory/view_models/inventory_view_model.dart';
import '../inventory/repositories/inventory_repository_impl.dart';
import '../expenditure/view_models/expenditure_view_model.dart';
import '../expenditure/repositories/expenditure_repository_impl.dart';
import '../users/view_models/user_view_model.dart';
import '../users/repositories/user_repository_impl.dart';
import '../todo/view_models/todo_view_model.dart';
import '../todo/repositories/todo_repository_impl.dart';
import '../rental/view_models/rental_view_model.dart';
import '../rental/repositories/rental_repository_impl.dart';
import '../companies/repositories/company_repository_impl.dart';
import 'dashboard_view_model.dart';
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
  late DashboardViewModel _dashboardViewModel;

  @override
  void initState() {
    super.initState();
    
    // Initialize DashboardViewModel with proper dependencies
    _dashboardViewModel = DashboardViewModel(
      userRepository: UserRepositoryImpl(widget.db),
      companyRepository: CompanyRepositoryImpl(widget.db),
      expenditureRepository: ExpenditureRepositoryImpl(widget.db),
      rentalRepository: RentalRepositoryImpl(widget.db),
      tradingRepository: TradingRepositoryImpl(widget.db),
      inventoryRepository: InventoryRepositoryImpl(
        widget.db,
        companyId: RoleUtils.getUserCompanyId(AuthService.currentUser),
        isSuperAdmin: RoleUtils.isSuperAdmin(AuthService.currentUser),
      ),
      usersRepository: UserRepositoryImpl(widget.db),
      database: widget.db,
    );
    
    // Initialize dashboard data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dashboardViewModel.initialize();
    });
  }

  @override
  void dispose() {
    _dashboardViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardViewModel>.value(
      value: _dashboardViewModel,
      child: Consumer<DashboardViewModel>(
        builder: (context, dashboardViewModel, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(dashboardViewModel),
                  const SizedBox(height: 24),
                  _buildCentralArea(dashboardViewModel),
                  const SizedBox(height: 24),
                  _buildTradingPerformanceTable(dashboardViewModel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // Top 4 Summary Cards with Sparkline Charts
  Widget _buildSummaryCards(DashboardViewModel dashboardViewModel) {
    return Row(
      children: [
        // Total Inventory Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Inventory',
            value: dashboardViewModel.totalInventory.toString(),
            icon: Icons.home,
            color: const Color(0xFF805AD5),
            sparklineData: _generateMockSparklineData(),
            loading: dashboardViewModel.inventoryLoading,
          ),
        ),
        const SizedBox(width: 16),
        // Rental Items Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Rental Items',
            value: dashboardViewModel.totalRentalItems.toString(),
            icon: Icons.apartment,
            color: const Color(0xFF4A90E2),
            sparklineData: _generateMockSparklineData(),
            loading: dashboardViewModel.rentalsLoading,
          ),
        ),
        const SizedBox(width: 16),
        // Active Users Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Active Users',
            value: dashboardViewModel.totalActiveUsers.toString(),
            icon: Icons.people,
            color: const Color(0xFFFF6B35),
            sparklineData: _generateMockSparklineData(),
            loading: dashboardViewModel.usersLoading,
          ),
        ),
        const SizedBox(width: 16),
        // Combined Summary Card
        Expanded(
          child: _buildSummaryCard(
            title: 'Expenses & Tasks',
            value: 'Rs ${dashboardViewModel.totalExpenses.toStringAsFixed(0)}',
            subtitle: '${dashboardViewModel.totalTasks} tasks',
            icon: Icons.analytics,
            color: const Color(0xFF38A169),
            sparklineData: _generateMockSparklineData(),
            loading: dashboardViewModel.expenditureLoading,
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
  Widget _buildCentralArea(DashboardViewModel dashboardViewModel) {
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
                      tradingEntries: dashboardViewModel.tradingEntries,
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
                tradingEntries: dashboardViewModel.tradingEntries,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Trading Performance Table
  Widget _buildTradingPerformanceTable(DashboardViewModel dashboardViewModel) {
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
            child: dashboardViewModel.tradingLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: dashboardViewModel.tradingEntries.take(10).length,
                    itemBuilder: (context, index) {
                      final entry = dashboardViewModel.tradingEntries[index];
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
