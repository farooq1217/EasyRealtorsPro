import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
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
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../core/services/app_storage.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;

class ReportsViewModel extends ChangeNotifier {
  final AppDatabase db;
  
  // ViewModels
  late AgentViewModel _agentViewModel;
  late InventoryViewModel _inventoryViewModel;
  late RentalViewModel _rentalViewModel;
  late TodoViewModel _todoViewModel;
  late TradingViewModel _tradingViewModel;
  late ExpenditureViewModel _expenditureViewModel;
  
  // State
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _reportsData = [];
  List<Map<String, dynamic>> _filteredReportsData = [];
  
  // Filter state
  String _selectedModule = 'Agent Working';
  String _dateRange = 'All Time';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _searchQuery = '';
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  // Module options
  final List<String> _modules = ['Agent Working', 'Inventory', 'Rental', 'To-Do', 'Trading', 'Expenditure'];
  final List<String> _dateRanges = ['All Time', 'Daily', 'Weekly', 'Monthly'];

  ReportsViewModel(this.db) {
    _initializeViewModels();
  }

  // Getters
  bool get loading => _loading;
  String get error => _error;
  Map<String, dynamic>? get currentUser => _currentUser;
  List<Map<String, dynamic>> get reportsData => _reportsData;
  List<Map<String, dynamic>> get filteredReportsData => _filteredReportsData;
  String get selectedModule => _selectedModule;
  String get dateRange => _dateRange;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  String get searchQuery => _searchQuery;
  List<String> get modules => _modules;
  List<String> get dateRanges => _dateRanges;
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_filteredReportsData.length / _itemsPerPage).ceil();
  List<Map<String, dynamic>> get paginatedReportsData {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredReportsData.skip(startIndex).take(_itemsPerPage).toList();
  }
  
  // ViewModel getters
  AgentViewModel get agentViewModel => _agentViewModel;
  InventoryViewModel get inventoryViewModel => _inventoryViewModel;
  RentalViewModel get rentalViewModel => _rentalViewModel;
  TodoViewModel get todoViewModel => _todoViewModel;
  TradingViewModel get tradingViewModel => _tradingViewModel;
  ExpenditureViewModel get expenditureViewModel => _expenditureViewModel;

  void _initializeViewModels() {
    _agentViewModel = AgentViewModel(AgentRepositoryImpl(
      db,
      companyId: null,
      isSuperAdmin: true,
    ));
    _inventoryViewModel = InventoryViewModel(
      InventoryRepositoryImpl(
        db,
        companyId: null,
        isSuperAdmin: true,
      ),
      SettingsRepositoryImpl(
        db,
        companyId: null,
        isSuperAdmin: true,
      ),
    );
    _rentalViewModel = RentalViewModel(
      repository: RentalRepositoryImpl(db),
    );
    _todoViewModel = TodoViewModel(
      repository: TodoRepositoryImpl(db),
    );
    _tradingViewModel = TradingViewModel(TradingRepositoryImpl(
      db,
      companyId: RoleUtils.getUserCompanyId(AuthService.currentUser),
      isSuperAdmin: RoleUtils.isSuperAdmin(AuthService.currentUser),
    ));
    _expenditureViewModel = ExpenditureViewModel(db);
  }

  // Setters
  set selectedModule(String value) {
    _selectedModule = value;
    _applyFilters();
    notifyListeners();
  }

  set dateRange(String value) {
    _dateRange = value;
    _updateDateRange();
    _applyFilters();
    notifyListeners();
  }

  set fromDate(DateTime? value) {
    _fromDate = value;
    _applyFilters();
    notifyListeners();
  }

  set toDate(DateTime? value) {
    _toDate = value;
    _applyFilters();
    notifyListeners();
  }

  set searchQuery(String value) {
    _searchQuery = value;
    _applySearchFilter();
    notifyListeners();
  }

  // Pagination methods
  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  void setItemsPerPage(int limit) {
    if (_itemsPerPage != limit) {
      _itemsPerPage = limit;
      _currentPage = 1; // Reset to page 1 when items per page changes
      notifyListeners();
    }
  }

  // Initialization
  Future<void> initialize() async {
    try {
      _loading = true;
      _error = '';
      notifyListeners();
      
      await _loadCurrentUser();
      await _loadAllData();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      debugPrint('Error initializing ReportsViewModel: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        _currentUser = await AuthService.getCurrentUser(authToken);
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _agentViewModel.initialize(),
      _inventoryViewModel.loadAllData(),
      _rentalViewModel.initialize(),
      _todoViewModel.loadTasks('', null),
      _tradingViewModel.loadEntries(),
      _expenditureViewModel.initialize(),
    ]);
    
    _loadReportsData();
  }

  void _loadReportsData() {
    _reportsData = _getModuleData();
    _applyFilters();
  }

  List<Map<String, dynamic>> _getModuleData() {
    switch (_selectedModule) {
      case 'Agent Working':
        return _agentViewModel.transfers.map((transfer) => {
          'name': transfer.name ?? '-',
          'status': transfer.status ?? '-',
          'category': transfer.category ?? '-',
          'date': transfer.transferDate ?? '-',
        }).toList();
      case 'Inventory':
        return _inventoryViewModel.allItems.map((item) => {
          'name': item.clientName ?? '-',
          'status': item.saleStatus ?? '-',
          'price': item.price?.toString() ?? '-',
          'type': item.type?.toString() ?? '-',
        }).toList();
      case 'Rental':
        return _rentalViewModel.rentalItems.map((rental) => {
          'name': rental['name'] ?? '-',
          'status': rental['status'] ?? '-',
          'price': rental['price']?.toString() ?? '-',
          'date': rental['created_at'] ?? '-',
        }).toList();
      case 'To-Do':
        return _todoViewModel.reminders.map((reminder) => {
          'title': reminder.reminderTitle ?? '-',
          'date': reminder.reminderDate ?? '-',
          'time': reminder.reminderTime ?? '-',
          'status': reminder.notificationStatus ?? '-',
        }).toList();
      case 'Trading':
        return _tradingViewModel.entries.map((entry) => {
          'person': entry.personName ?? '-',
          'estate': entry.estateName ?? '-',
          'type': entry.entryType ?? '-',
          'price': entry.totalPrice?.toString() ?? '-',
        }).toList();
      case 'Expenditure':
        final allExpenses = [..._expenditureViewModel.officeExpenses, ..._expenditureViewModel.projectExpenses];
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

  void _applyFilters() {
    _reportsData = _getModuleData();
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredReportsData = List.from(_reportsData);
    } else {
      _filteredReportsData = _reportsData.where((item) {
        final query = _searchQuery.toLowerCase();
        return item.values.any((value) => 
          value.toString().toLowerCase().contains(query)
        );
      }).toList();
    }
    
    // Reset to page 1 when filter changes
    _currentPage = 1;
    notifyListeners();
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

  // Clear filters
  void clearFilters() {
    _selectedModule = 'Agent Working';
    _dateRange = 'All Time';
    _fromDate = null;
    _toDate = null;
    _searchQuery = '';
    _currentPage = 1;
    _applyFilters();
  }

  // Refresh data
  Future<void> refreshData() async {
    await _loadAllData();
  }

  // Get table columns for current module
  List<Map<String, dynamic>> getTableColumns() {
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

  // Get summary statistics
  Map<String, dynamic> getSummaryStatistics() {
    switch (_selectedModule) {
      case 'Agent Working':
        final total = _agentViewModel.transfers.length;
        final pending = _agentViewModel.transfers.where((t) => t.status?.toLowerCase() == 'pending').length;
        return {
          'total': total.toString(),
          'pending': pending.toString(),
        };
      case 'Inventory':
        final total = _inventoryViewModel.allItems.length;
        final sold = _inventoryViewModel.allItems.where((i) => i.saleStatus.toLowerCase() == 'sold').length;
        final available = _inventoryViewModel.allItems.where((i) => i.saleStatus.toLowerCase() == 'not sold').length;
        return {
          'total': total.toString(),
          'sold': sold.toString(),
          'available': available.toString(),
        };
      case 'Expenditure':
        final allExpenses = [..._expenditureViewModel.officeExpenses, ..._expenditureViewModel.projectExpenses];
        double total = 0.0;
        for (final expense in allExpenses) {
          total += expense.amount ?? 0.0;
        }
        return {
          'total': _formatCurrency(total),
        };
      case 'Trading':
        final entries = _tradingViewModel.entries;
        double totalBuying = 0.0;
        double totalSelling = 0.0;
        for (final entry in entries) {
          final entryType = entry.entryType?.toString().toLowerCase() ?? '';
          final price = double.tryParse(entry.totalPrice?.toString() ?? '0') ?? 0.0;
          if (['buy', 'hp', 'kp', 'purchase'].contains(entryType)) {
            totalBuying += price;
          } else if (['sell', 'aemp', 'sale'].contains(entryType)) {
            totalSelling += price;
          }
        }
        return {
          'buying': _formatCurrency(totalBuying),
          'selling': _formatCurrency(totalSelling),
        };
      default:
        return {'total': '0'};
    }
  }

  String _formatCurrency(double amount) {
    return 'Rs ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    )}';
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
}
