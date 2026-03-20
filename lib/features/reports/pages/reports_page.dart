import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_selector/file_selector.dart';
import '../../../../core/font_utils.dart';
import '../../../../core/services/permission_helper.dart';
import '../../../../core/services/auth_service.dart';
import '../../agents/view_models/agent_view_model.dart';
import '../../agents/repositories/agent_repository_impl.dart';
import '../../inventory/view_models/inventory_view_model.dart';
import '../../inventory/repositories/inventory_repository_impl.dart';
import '../../rental/view_models/rental_view_model.dart';
import '../../rental/repositories/rental_repository_impl.dart';
import '../../todo/view_models/todo_view_model.dart';
import '../../todo/repositories/todo_repository_impl.dart';
import '../../trading/view_models/trading_view_model.dart';
import '../../trading/repositories/trading_repository_impl.dart';
import '../../expenditure/view_models/expenditure_view_model.dart';
import '../../expenditure/repositories/expenditure_repository_impl.dart';
import '../../settings/repositories/settings_repository_impl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared/shared.dart';

class ReportsPage extends StatefulWidget {
  final AppDatabase db;
  const ReportsPage({super.key, required this.db});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // ViewModels
  late AgentViewModel _agentViewModel;
  late InventoryViewModel _inventoryViewModel;
  late RentalViewModel _rentalViewModel;
  late TodoViewModel _todoViewModel;
  late TradingViewModel _tradingViewModel;
  late ExpenditureViewModel _expenditureViewModel;
  
  // Filter state
  String _selectedModule = 'Agent Working';
  String _dateRange = 'All Time';
  DateTime? _fromDate;
  DateTime? _toDate;
  
  // Module options
  final List<String> _modules = ['Agent Working', 'Inventory', 'Rental', 'To-Do', 'Trading', 'Expenditure'];
  final List<String> _dateRanges = ['All Time', 'Daily', 'Weekly', 'Monthly'];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize all ViewModels
    _agentViewModel = AgentViewModel(AgentRepositoryImpl(
      widget.db,
      companyId: null,
      isSuperAdmin: true,
    ));
    _inventoryViewModel = InventoryViewModel(
      InventoryRepositoryImpl(
        widget.db,
        companyId: null,
        isSuperAdmin: true,
      ),
      SettingsRepositoryImpl(
        widget.db,
        companyId: null,
        isSuperAdmin: true,
      ),
    );
    _rentalViewModel = RentalViewModel(
      repository: RentalRepositoryImpl(widget.db),
    );
    _todoViewModel = TodoViewModel(
      repository: TodoRepositoryImpl(widget.db),
    );
    _tradingViewModel = TradingViewModel(TradingRepositoryImpl(widget.db));
    _expenditureViewModel = ExpenditureViewModel(widget.db);
    
    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAllData();
      }
    });
  }
  
  Future<void> _loadAllData() async {
    await Future.wait([
      _agentViewModel.initialize(),
      _inventoryViewModel.loadAllData(),
      _rentalViewModel.initialize(),
      _todoViewModel.loadTasks(
        '',
        null,
      ),
      _tradingViewModel.loadEntries(),
      _expenditureViewModel.initialize(),
    ]);
  }

  @override
  void dispose() {
    _agentViewModel.dispose();
    _inventoryViewModel.dispose();
    _rentalViewModel.dispose();
    _todoViewModel.dispose();
    _tradingViewModel.dispose();
    _expenditureViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Reports & Analytics',
          style: AppFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade500,
                Colors.purple.shade400,
                Colors.purple.shade300,
              ],
            ),
          ),
        ),
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _agentViewModel),
          ChangeNotifierProvider.value(value: _inventoryViewModel),
          ChangeNotifierProvider.value(value: _rentalViewModel),
          ChangeNotifierProvider.value(value: _todoViewModel),
          ChangeNotifierProvider.value(value: _tradingViewModel),
          ChangeNotifierProvider.value(value: _expenditureViewModel),
        ],
        child: Consumer6<AgentViewModel, InventoryViewModel, RentalViewModel, TodoViewModel, TradingViewModel, ExpenditureViewModel>(
          builder: (context, agent, inventory, rental, todo, trading, expenditure, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Top Filter Section
                  _buildFilterSection(),
                  const SizedBox(height: 24),
                  
                  // Step 2: Comprehensive Summary Cards Row
                  _buildSummaryCards(agent, inventory, rental, todo, trading, expenditure),
                  const SizedBox(height: 24),
                  
                  // Step 3: Data Table Section with Export Buttons
                  _buildDataTableSection(agent, inventory, rental, todo, trading, expenditure),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Step 1: Top Filter Section
  Widget _buildFilterSection() {
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
          // Module Selector
          Text(
            'Report Type',
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _modules.map((module) {
                final isSelected = _selectedModule == module;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      module,
                      style: AppFonts.poppins(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedModule = module;
                        });
                      }
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.orange.shade600,
                    checkmarkColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date Range Selector
          Text(
            'Date Range',
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dateRanges.map((range) {
                final isSelected = _dateRange == range;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      range,
                      style: AppFonts.poppins(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _dateRange = range;
                          _updateDateRange();
                        });
                      }
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.blue.shade600,
                    checkmarkColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Custom Date Pickers
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'From: ${_fromDate != null ? _formatDate(_fromDate!) : 'Select date'}',
                          style: AppFonts.poppins(
                            fontSize: 12,
                            color: _fromDate != null ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'To: ${_toDate != null ? _formatDate(_toDate!) : 'Select date'}',
                          style: AppFonts.poppins(
                            fontSize: 12,
                            color: _toDate != null ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedModule = 'Agent Working';
                      _dateRange = 'All Time';
                      _fromDate = null;
                      _toDate = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Clear',
                    style: AppFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Apply filters logic here
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Apply',
                    style: AppFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2: Comprehensive Summary Cards Row
  Widget _buildSummaryCards(
    AgentViewModel agent,
    InventoryViewModel inventory,
    RentalViewModel rental,
    TodoViewModel todo,
    TradingViewModel trading,
    ExpenditureViewModel expenditure,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary for ${_dateRange}',
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // Horizontal scrollable row of cards
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Agent Working Cards
              _buildSummaryCard(
                title: 'Total Transfers',
                value: agent.transfers.length.toString(),
                icon: Icons.swap_horiz,
                color: Colors.blue.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              _buildSummaryCard(
                title: 'Pending Transfers',
                value: agent.transfers.where((t) => t.status?.toLowerCase() == 'pending').length.toString(),
                icon: Icons.pending,
                color: Colors.orange.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              
              // Inventory Cards
              _buildSummaryCard(
                title: 'Total Inventory',
                value: inventory.allItems.length.toString(),
                icon: Icons.inventory,
                color: Colors.purple.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              _buildSummaryCard(
                title: 'Sold Inventory',
                value: inventory.allItems.where((i) => i.saleStatus.toLowerCase() == 'sold').length.toString(),
                icon: Icons.sell,
                color: Colors.green.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              _buildSummaryCard(
                title: 'Available Inventory',
                value: inventory.allItems.where((i) => i.saleStatus.toLowerCase() == 'not sold').length.toString(),
                icon: Icons.check_circle,
                color: Colors.teal.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              
              // Expenditure Card
              _buildSummaryCard(
                title: 'Total Expenditure',
                value: _formatCurrency(_calculateTotalExpenditure(expenditure)),
                icon: Icons.receipt_long,
                color: Colors.red.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              
              // Trading Cards
              _buildSummaryCard(
                title: 'Total Buying',
                value: _formatCurrency(_calculateTotalBuying(trading.entries)),
                icon: Icons.shopping_cart,
                color: Colors.green.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
              _buildSummaryCard(
                title: 'Total Selling',
                value: _formatCurrency(_calculateTotalSelling(trading.entries)),
                icon: Icons.sell,
                color: Colors.orange.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: backgroundColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Step 3: Data Table Section with Export Buttons
  Widget _buildDataTableSection(
    AgentViewModel agent,
    InventoryViewModel inventory,
    RentalViewModel rental,
    TodoViewModel todo,
    TradingViewModel trading,
    ExpenditureViewModel expenditure,
  ) {
    final data = _getModuleData(agent, inventory, rental, todo, trading, expenditure);
    final moduleName = _selectedModule;
    
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
          // Header with title and export buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  '$moduleName DATA (${data.length})',
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              // PDF Export Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _exportToPDF(data, moduleName),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  tooltip: 'Export to PDF',
                ),
              ),
              const SizedBox(width: 8),
              // CSV Export Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _exportToCSV(data, moduleName),
                  icon: const Icon(Icons.table_chart, color: Colors.white),
                  tooltip: 'Export to CSV',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Data Table
          if (data.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No data found for $_selectedModule',
                      style: AppFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildDataTable(data),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> data) {
    final columns = _getTableColumns();
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length + 1, // +1 for header
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header row
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: columns.map((column) {
                  return Expanded(
                    flex: column['flex'] ?? 1,
                    child: Text(
                      column['title'],
                      style: AppFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }
          
          final item = data[index - 1];
          return Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: columns.map((column) {
                final value = item[column['key']]?.toString() ?? '-';
                return Expanded(
                  flex: column['flex'] ?? 1,
                  child: Text(
                    value,
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getModuleData(
    AgentViewModel agent,
    InventoryViewModel inventory,
    RentalViewModel rental,
    TodoViewModel todo,
    TradingViewModel trading,
    ExpenditureViewModel expenditure,
  ) {
    switch (_selectedModule) {
      case 'Agent Working':
        return agent.transfers.map((transfer) => {
          'name': transfer.name ?? '-',
          'status': transfer.status ?? '-',
          'category': transfer.category ?? '-',
          'date': transfer.transferDate ?? '-',
        }).toList();
      case 'Inventory':
        return inventory.allItems.map((item) => {
          'name': item.clientName ?? '-',
          'status': item.saleStatus ?? '-',
          'price': item.price?.toString() ?? '-',
          'type': item.type?.toString() ?? '-',
        }).toList();
      case 'Rental':
        return rental.rentalItems.map((rental) => {
          'name': rental['name'] ?? '-',
          'status': rental['status'] ?? '-',
          'price': rental['price']?.toString() ?? '-',
          'date': rental['created_at'] ?? '-',
        }).toList();
      case 'To-Do':
        return todo.reminders.map((reminder) => {
          'title': reminder.reminderTitle ?? '-',
          'date': reminder.reminderDate ?? '-',
          'time': reminder.reminderTime ?? '-',
          'status': reminder.notificationStatus ?? '-',
        }).toList();
      case 'Trading':
        return trading.entries.map((entry) => {
          'person': entry.personName ?? '-',
          'estate': entry.estateName ?? '-',
          'type': entry.entryType ?? '-',
          'price': entry.totalPrice?.toString() ?? '-',
        }).toList();
      case 'Expenditure':
        final allExpenses = [...expenditure.officeExpenses, ...expenditure.projectExpenses];
        return allExpenses.map((expense) => {
          'title': expense.description ?? '-',
          'amount': expense.amount?.toString() ?? '-',
          'category': expense.category ?? '-',
          'date': expense.date ?? '-',
        }).toList();
      default:
        return [];
    }
  }

  List<Map<String, dynamic>> _getTableColumns() {
    switch (_selectedModule) {
      case 'Agent Working':
        return [
          {'title': 'Name', 'key': 'name', 'flex': 2},
          {'title': 'Status', 'key': 'status', 'flex': 1},
          {'title': 'Category', 'key': 'category', 'flex': 2},
          {'title': 'Date', 'key': 'date', 'flex': 1},
        ];
      case 'Inventory':
        return [
          {'title': 'Item Name', 'key': 'name', 'flex': 2},
          {'title': 'Status', 'key': 'status', 'flex': 1},
          {'title': 'Price', 'key': 'price', 'flex': 1},
          {'title': 'Type', 'key': 'type', 'flex': 1},
        ];
      case 'Rental':
        return [
          {'title': 'Name', 'key': 'name', 'flex': 2},
          {'title': 'Status', 'key': 'status', 'flex': 1},
          {'title': 'Price', 'key': 'price', 'flex': 1},
          {'title': 'Date', 'key': 'date', 'flex': 1},
        ];
      case 'To-Do':
        return [
          {'title': 'Title', 'key': 'title', 'flex': 2},
          {'title': 'Date', 'key': 'date', 'flex': 1},
          {'title': 'Time', 'key': 'time', 'flex': 1},
          {'title': 'Status', 'key': 'status', 'flex': 1},
        ];
      case 'Trading':
        return [
          {'title': 'Person', 'key': 'person', 'flex': 2},
          {'title': 'Estate', 'key': 'estate', 'flex': 2},
          {'title': 'Type', 'key': 'type', 'flex': 1},
          {'title': 'Price', 'key': 'price', 'flex': 1},
        ];
      case 'Expenditure':
        return [
          {'title': 'Title', 'key': 'title', 'flex': 2},
          {'title': 'Amount', 'key': 'amount', 'flex': 1},
          {'title': 'Category', 'key': 'category', 'flex': 1},
          {'title': 'Date', 'key': 'date', 'flex': 1},
        ];
      default:
        return [];
    }
  }

  // Helper Methods
  Future<void> _selectDate(bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_dateRange) {
      case 'Daily':
        _fromDate = now;
        _toDate = now;
        break;
      case 'Weekly':
        _fromDate = now.subtract(const Duration(days: 7));
        _toDate = now;
        break;
      case 'Monthly':
        _fromDate = DateTime(now.year, now.month - 1, now.day);
        _toDate = now;
        break;
      case 'All Time':
      default:
        _fromDate = null;
        _toDate = null;
        break;
    }
  }

  double _calculateTotalExpenditure(ExpenditureViewModel expenditure) {
    final allExpenses = [...expenditure.officeExpenses, ...expenditure.projectExpenses];
    double total = 0.0;
    for (final expense in allExpenses) {
      total += expense.amount ?? 0.0;
    }
    return total;
  }

  double _calculateTotalBuying(List entries) {
    double total = 0.0;
    for (final entry in entries) {
      final entryType = entry.entryType?.toString().toLowerCase() ?? '';
      if (['buy', 'hp', 'kp', 'purchase'].contains(entryType)) {
        final price = double.tryParse(entry.totalPrice?.toString() ?? '0') ?? 0.0;
        total += price;
      }
    }
    return total;
  }

  double _calculateTotalSelling(List entries) {
    double total = 0.0;
    for (final entry in entries) {
      final entryType = entry.entryType?.toString().toLowerCase() ?? '';
      if (['sell', 'aemp', 'sale'].contains(entryType)) {
        final price = double.tryParse(entry.totalPrice?.toString() ?? '0') ?? 0.0;
        total += price;
      }
    }
    return total;
  }

  String _formatCurrency(double amount) {
    return 'Rs ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    )}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}-${date.month}-${date.year}';
  }

  // Export Methods
  Future<void> _exportToCSV(List<Map<String, dynamic>> data, String moduleName) async {
    try {
      final columns = _getTableColumns();
      final List<List<String>> csvData = [];
      
      // Add header
      csvData.add(columns.map((col) => col['title'] as String).toList());
      
      // Add data rows
      for (final item in data) {
        final row = columns.map((col) => item[col['key']]?.toString() ?? '').toList();
        csvData.add(row);
      }
      
      final csv = const ListToCsvConverter().convert(csvData);
      
      final result = await getSaveLocation(
        suggestedName: '${moduleName}_report.csv',
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'CSV files',
            extensions: ['csv'],
          ),
        ],
      );
      
      if (result != null) {
        final file = XFile.fromData(
          Uint8List.fromList(csv.codeUnits),
          name: '${moduleName}_report.csv',
        );
        await file.saveTo(result.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(List<Map<String, dynamic>> data, String moduleName) async {
    try {
      final pdf = pw.Document();
      final columns = _getTableColumns();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$moduleName Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  context: context,
                  data: [
                    columns.map((col) => col['title'] as String).toList(),
                    ...data.map((item) => columns.map((col) => item[col['key']]?.toString() ?? '').toList()),
                  ],
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                  },
                ),
              ],
            );
          },
        ),
      );
      
      final result = await getSaveLocation(
        suggestedName: '${moduleName}_report.pdf',
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'PDF files',
            extensions: ['pdf'],
          ),
        ],
      );
      
      if (result != null) {
        final file = XFile.fromData(
          await pdf.save(),
          name: '${moduleName}_report.pdf',
          mimeType: 'application/pdf',
        );
        await file.saveTo(result.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
