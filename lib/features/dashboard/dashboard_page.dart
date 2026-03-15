import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared/shared.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../../core/font_utils.dart';
import '../../../shimmer_widgets.dart';
import '../dashboard/dashboard_view_model.dart';
import '../users/repositories/user_repository_impl.dart';
import '../companies/repositories/company_repository_impl.dart';
import '../expenditure/repositories/expenditure_repository_impl.dart';
import '../rental/repositories/rental_repository_impl.dart';
import '../trading/repositories/trading_repository_impl.dart';
import '../inventory/repositories/inventory_repository_impl.dart';

class DashboardPage extends StatefulWidget {
  final AppDatabase db;
  const DashboardPage({super.key, required this.db});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel(
      userRepository: UserRepositoryImpl(widget.db),
      companyRepository: CompanyRepositoryImpl(widget.db),
      expenditureRepository: ExpenditureRepositoryImpl(widget.db),
      rentalRepository: RentalRepositoryImpl(widget.db),
      tradingRepository: TradingRepositoryImpl(widget.db),
      inventoryRepository: InventoryRepositoryImpl(widget.db, companyId: null, isSuperAdmin: true),
      usersRepository: UserRepositoryImpl(widget.db),
    );

    // Initialize ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardViewModel>.value(
      value: _viewModel,
      child: Consumer<DashboardViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              title: Text(
                'Analytics Dashboard',
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF2D3748),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => viewModel.refreshAll(),
                  tooltip: 'Refresh Dashboard',
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: viewModel.refreshAll,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Live Analytics Overview',
                      style: AppFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Real-time insights into your business performance',
                      style: AppFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dashboard Cards Grid
                    _buildDashboardGrid(viewModel),
                    
                    const SizedBox(height: 32),
                    
                    // Revenue vs Expenses Chart
                    _buildRevenueChartNew(viewModel),
                    
                    const SizedBox(height: 24),
                    
                    // Error Message (if any)
                    if (viewModel.hasError) _buildErrorMessage(viewModel),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardGrid(DashboardViewModel viewModel) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        // Trading Card - Purple Theme
        _buildDashboardCard(
          title: 'Total Closed Deals',
          value: viewModel.totalClosedDeals.toString(),
          subtitle: 'Completed transactions',
          icon: Icons.trending_up,
          color: const Color(0xFF805AD5),
          backgroundColor: const Color(0xFFF3E8FF),
          loading: viewModel.tradingLoading,
          error: viewModel.tradingError,
          viewModel: viewModel,
        ),
        
        // Trading Profit Card - Orange Theme
        _buildDashboardCard(
          title: 'Trading Profit',
          value: 'Rs ${viewModel.totalTradingProfit.toStringAsFixed(0)}',
          subtitle: 'Net profit from deals',
          icon: Icons.attach_money,
          color: const Color(0xFFED8936),
          backgroundColor: const Color(0xFFFFFAF0),
          loading: viewModel.tradingLoading,
          error: viewModel.tradingError,
          viewModel: viewModel,
        ),
        
        // Users Card - Blue Theme
        _buildDashboardCard(
          title: 'Active Agents',
          value: viewModel.totalUsers.toString(),
          subtitle: 'Active team members',
          icon: Icons.people,
          color: const Color(0xFF3182CE),
          backgroundColor: const Color(0xFFEBF8FF),
          loading: viewModel.usersLoading,
          error: viewModel.usersError,
          viewModel: viewModel,
        ),
        
        // Expense Card - Red Theme
        _buildDashboardCard(
          title: "This Month's Expenses",
          value: viewModel.formattedMonthlyExpenditure,
          subtitle: 'Current month spending',
          icon: Icons.account_balance_wallet,
          color: const Color(0xFFE53E3E),
          backgroundColor: const Color(0xFFFFF5F5),
          loading: viewModel.expenditureLoading,
          error: viewModel.expenditureError,
          viewModel: viewModel,
        ),
        
        // Inventory Card - Green Theme
        _buildDashboardCard(
          title: 'Available Properties',
          value: viewModel.availableProperties.toString(),
          subtitle: 'Properties for sale/rent',
          icon: Icons.home,
          color: const Color(0xFF38A169),
          backgroundColor: const Color(0xFFF0FFF4),
          loading: viewModel.inventoryLoading,
          error: viewModel.inventoryError,
          viewModel: viewModel,
        ),
        
        // Companies Card - Teal Theme
        _buildDashboardCard(
          title: 'Total Companies',
          value: viewModel.totalCompanies.toString(),
          subtitle: 'Business entities',
          icon: Icons.business,
          color: const Color(0xFF319795),
          backgroundColor: const Color(0xFFE6FFFA),
          loading: viewModel.companiesLoading,
          error: viewModel.companiesError,
          viewModel: viewModel,
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required bool loading,
    required String? error,
    required DashboardViewModel viewModel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const Spacer(),
                if (error != null)
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Loading State
            if (loading) ...[
              _buildShimmerValue(),
              const SizedBox(height: 8),
              _buildShimmerSubtitle(),
            ] else if (error != null) ...[
              // Error State
              Text(
                'Error',
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Failed to load',
                style: AppFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.red.shade400,
                ),
              ),
            ] else ...[
              // Normal State
              Text(
                value,
                style: AppFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF718096),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerValue() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E8ED),
      highlightColor: const Color(0xFFF4F5F7),
      child: Container(
        height: 32,
        width: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8ED),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildShimmerSubtitle() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E8ED),
      highlightColor: const Color(0xFFF4F5F7),
      child: Container(
        height: 16,
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8ED),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(DashboardViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Data Loading Error',
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.error ?? 'Some dashboard data failed to load. Please try refreshing.',
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.red.shade500,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: viewModel.refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Retry',
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartNew(DashboardViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Monthly Revenue vs Expenses',
            style: AppFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 6 months performance',
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: AppFonts.poppins(fontSize: 12),
                labelRotation: -45,
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(
                  width: 1,
                  color: Color(0xFFE2E8F0),
                ),
                labelStyle: AppFonts.poppins(fontSize: 12),
                numberFormat: NumberFormat.compactCurrency(
                  decimalDigits: 0,
                  symbol: 'Rs',
                ),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: 'point.x: point.y',
                textStyle: AppFonts.poppins(fontSize: 12),
              ),
              legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                textStyle: AppFonts.poppins(fontSize: 12),
              ),
              series: <CartesianSeries<ChartData, String>>[
                // Revenue Series
                ColumnSeries<ChartData, String>(
                  dataSource: _getRevenueData(),
                  xValueMapper: (ChartData data, _) => data.month,
                  yValueMapper: (ChartData data, _) => data.value,
                  name: 'Revenue',
                  color: const Color(0xFF805AD5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                // Expenses Series
                ColumnSeries<ChartData, String>(
                  dataSource: _getExpenseData(),
                  xValueMapper: (ChartData data, _) => data.month,
                  yValueMapper: (ChartData data, _) => data.value,
                  name: 'Expenses',
                  color: const Color(0xFFED8936),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ChartData> _getRevenueData() {
    // Sample data - in real app, this would come from repository
    return [
      ChartData('Oct', 450000),
      ChartData('Nov', 520000),
      ChartData('Dec', 480000),
      ChartData('Jan', 590000),
      ChartData('Feb', 620000),
      ChartData('Mar', 680000),
    ];
  }

  List<ChartData> _getExpenseData() {
    // Sample data - in real app, this would come from repository
    return [
      ChartData('Oct', 320000),
      ChartData('Nov', 380000),
      ChartData('Dec', 350000),
      ChartData('Jan', 410000),
      ChartData('Feb', 440000),
      ChartData('Mar', 480000),
    ];
  }
}

/// Custom shimmer widget for dashboard cards
class DashboardCardShimmer extends StatelessWidget {
  const DashboardCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon shimmer
            Shimmer.fromColors(
              baseColor: const Color(0xFFE6E8ED),
              highlightColor: const Color(0xFFF4F5F7),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E8ED),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Value shimmer
            Shimmer.fromColors(
              baseColor: const Color(0xFFE6E8ED),
              highlightColor: const Color(0xFFF4F5F7),
              child: Container(
                height: 32,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E8ED),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle shimmer
            Shimmer.fromColors(
              baseColor: const Color(0xFFE6E8ED),
              highlightColor: const Color(0xFFF4F5F7),
              child: Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E8ED),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  ChartData(this.month, this.value);
  final String month;
  final double value;
}
