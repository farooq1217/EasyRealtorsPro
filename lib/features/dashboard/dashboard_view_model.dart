import 'dart:async';
import 'package:flutter/material.dart';
import '../users/repositories/user_repository.dart' as user_repo;
import '../companies/repositories/company_repository.dart';
import '../expenditure/repositories/expenditure_repository.dart';
import '../rental/repositories/rental_repository.dart';
import '../trading/repositories/trading_repository.dart';
import '../inventory/repositories/inventory_repository.dart';
import '../users/models/user_model.dart';
import '../companies/models/company_model.dart';
import '../expenditure/models/expenditure_item.dart';
import 'package:shared/shared.dart' show TradingEntry;
import '../inventory/models/inventory_item.dart';

class DashboardViewModel extends ChangeNotifier {
  final user_repo.UserRepository _userRepository;
  final CompanyRepository _companyRepository;
  final ExpenditureRepository _expenditureRepository;
  final RentalRepository _rentalRepository;
  final TradingRepository _tradingRepository;
  final InventoryRepository _inventoryRepository;
  final user_repo.UserRepository _usersRepository;

  // Stream subscriptions for real-time updates
  StreamSubscription<List<UserModel>>? _usersSubscription;
  StreamSubscription<List<CompanyModel>>? _companiesSubscription;
  StreamSubscription<List<ExpenditureItem>>? _expendituresSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _rentalsSubscription;
  StreamSubscription<List<TradingEntry>>? _tradingSubscription;

  // Dashboard data
  int _totalUsers = 0;
  int _totalCompanies = 0;
  double _monthlyExpenditure = 0.0;
  int _activeRentals = 0;
  int _totalClosedDeals = 0;
  double _totalTradingProfit = 0.0;
  int _availableProperties = 0;
  List<UserModel> _users = [];
  List<TradingEntry> _totalTradingEntries = [];

  // Loading states
  bool _isLoading = true;
  bool _usersLoading = true;
  bool _companiesLoading = true;
  bool _expenditureLoading = true;
  bool _rentalsLoading = true;
  bool _tradingLoading = true;
  bool _inventoryLoading = true;

  // Error states
  String? _error;
  bool _mounted = true;
  String? _usersError;
  String? _companiesError;
  String? _expenditureError;
  String? _rentalsError;
  String? _tradingError;
  String? _inventoryError;

  bool get mounted => _mounted;

  DashboardViewModel({
    required user_repo.UserRepository userRepository,
    required CompanyRepository companyRepository,
    required ExpenditureRepository expenditureRepository,
    required RentalRepository rentalRepository,
    required TradingRepository tradingRepository,
    required InventoryRepository inventoryRepository,
    required user_repo.UserRepository usersRepository,
  })  : _userRepository = userRepository,
        _companyRepository = companyRepository,
        _expenditureRepository = expenditureRepository,
        _rentalRepository = rentalRepository,
        _tradingRepository = tradingRepository,
        _inventoryRepository = inventoryRepository,
        _usersRepository = usersRepository;

  // Getters
  int get totalUsers => _totalUsers;
  int get totalCompanies => _totalCompanies;
  double get monthlyExpenditure => _monthlyExpenditure;
  int get activeRentals => _activeRentals;
  int get totalClosedDeals => _totalClosedDeals;
  double get totalTradingProfit => _totalTradingProfit;
  int get availableProperties => _availableProperties;

  bool get isLoading => _isLoading;
  bool get usersLoading => _usersLoading;
  bool get companiesLoading => _companiesLoading;
  bool get expenditureLoading => _expenditureLoading;
  bool get rentalsLoading => _rentalsLoading;
  bool get tradingLoading => _tradingLoading;
  bool get inventoryLoading => _inventoryLoading;

  String? get error => _error;
  String? get usersError => _usersError;
  String? get companiesError => _companiesError;
  String? get expenditureError => _expenditureError;
  String? get rentalsError => _rentalsError;
  String? get tradingError => _tradingError;
  String? get inventoryError => _inventoryError;

  bool get hasError => _error != null || 
                      _usersError != null || 
                      _companiesError != null || 
                      _expenditureError != null || 
                      _rentalsError != null ||
                      _tradingError != null ||
                      _inventoryError != null;

  /// Initialize dashboard data and set up real-time streams
  Future<void> initialize() async {
    if (_isLoading) return; // Prevent multiple initializations
    
    await Future.wait([
      _loadUsersData(),
      _loadCompaniesData(),
      _loadExpenditureData(),
      _loadRentalsData(),
      _loadTradingData(),
      _loadInventoryData(),
    ]);

    // Check if all data is loaded
    _updateOverallLoadingState();
  }

  /// Refresh all dashboard data
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await Future.wait([
        _loadTradingData(),
        _loadUsersData(),
        _loadCompaniesData(),
        _loadExpenditureData(),
      ]);
      
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh dashboard data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load users data with real-time updates
  Future<void> _loadUsersData() async {
    try {
      _usersLoading = true;
      _usersError = null;
      notifyListeners();
      
      // Cancel existing subscription
      await _usersSubscription?.cancel();
      
      // Set up stream for users
      _usersSubscription = _usersRepository.watchUsers(null).listen(
        (users) {
          if (!_mounted) return;
          _users = users;
          _usersLoading = false;
          notifyListeners();
        },
        onError: (e) {
          if (!_mounted) return;
          _usersError = 'Failed to load users: $e';
          _usersLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _usersError = 'Failed to initialize users stream: $e';
      _usersLoading = false;
      _updateOverallLoadingState();
      notifyListeners();
    }
  }

  /// Load companies data with real-time updates
  Future<void> _loadCompaniesData() async {
    try {
      _companiesLoading = true;
      _companiesError = null;
      notifyListeners();

      // Cancel existing subscription
      await _companiesSubscription?.cancel();

      // Set up stream for real-time updates
      _companiesSubscription = _companyRepository.watchCompanies().listen(
        (companies) {
          if (!mounted) return;
          
          // Count registered companies
          _totalCompanies = companies.where((company) => company.isActive).length;
          
          _companiesLoading = false;
          _companiesError = null;
          _updateOverallLoadingState();
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _companiesError = 'Failed to load companies: $e';
          _companiesLoading = false;
          _updateOverallLoadingState();
          notifyListeners();
        },
      );
    } catch (e) {
      _companiesError = 'Failed to initialize companies stream: $e';
      _companiesLoading = false;
      _updateOverallLoadingState();
      notifyListeners();
    }
  }

  /// Load expenditure data with real-time updates
  Future<void> _loadExpenditureData() async {
    try {
      _expenditureLoading = true;
      _expenditureError = null;
      notifyListeners();

      // Cancel existing subscription
      await _expendituresSubscription?.cancel();

      // Set up stream for real-time updates
      _expendituresSubscription = _expenditureRepository.watchExpenditures('' /* all companies */).listen(
        (expenditures) {
          if (!mounted) return;
          
          // Calculate current month's expenses
          final now = DateTime.now();
          final currentMonth = DateTime(now.year, now.month, 1);
          final nextMonth = DateTime(now.year, now.month + 1, 1);
          
          _monthlyExpenditure = expenditures
              .where((exp) => 
                exp.isActive &&
                exp.createdAt.isAfter(currentMonth) &&
                exp.createdAt.isBefore(nextMonth)
              )
              .fold(0.0, (sum, exp) => sum + exp.amount);
          
          _expenditureLoading = false;
          _expenditureError = null;
          _updateOverallLoadingState();
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _expenditureError = 'Failed to load expenditures: $e';
          _expenditureLoading = false;
          _updateOverallLoadingState();
          notifyListeners();
        },
      );
    } catch (e) {
      _expenditureError = 'Failed to initialize expenditures stream: $e';
      _expenditureLoading = false;
      _updateOverallLoadingState();
      notifyListeners();
    }
  }

  /// Load rental data with real-time updates
  Future<void> _loadRentalsData() async {
    try {
      _rentalsLoading = true;
      _rentalsError = null;
      notifyListeners();

      // Cancel existing subscription
      await _rentalsSubscription?.cancel();

      // Set up stream for real-time updates
      _rentalsSubscription = _rentalRepository.watchRentalItems(
        statusFilter: RentalStatus.rented,
      ).listen(
        (rentals) {
          if (!mounted) return;
          
          // Count currently rented properties
          _activeRentals = rentals.length;
          
          _rentalsLoading = false;
          _rentalsError = null;
          _updateOverallLoadingState();
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _rentalsError = 'Failed to load rentals: $e';
          _rentalsLoading = false;
          _updateOverallLoadingState();
          notifyListeners();
        },
      );
    } catch (e) {
      _rentalsError = 'Failed to initialize rentals stream: $e';
      _rentalsLoading = false;
      _updateOverallLoadingState();
      notifyListeners();
    }
  }

  /// Load trading data with real-time updates
  Future<void> _loadTradingData() async {
    try {
      _tradingLoading = true;
      _tradingError = null;
      notifyListeners();

      // Cancel existing subscription
      await _tradingSubscription?.cancel();

      // Set up stream for real-time updates
      _tradingSubscription = _tradingRepository.watchEntries().listen(
        (entries) {
          if (!mounted) return;
          
          // Calculate trading performance metrics
          _totalClosedDeals = entries.where((e) => e.isActive).length;
          _totalTradingEntries = entries;
          _tradingLoading = false;
          _updateOverallLoadingState();
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _tradingError = 'Failed to load trading data: $e';
          _tradingLoading = false;
          _updateOverallLoadingState();
          notifyListeners();
        },
      );
    } catch (e) {
      _tradingError = 'Failed to initialize trading stream: $e';
      _tradingLoading = false;
      _updateOverallLoadingState();
      notifyListeners();
    }
  }

  /// Load inventory data with polling updates
  Future<void> _loadInventoryData() async {
    try {
      _inventoryLoading = true;
      _inventoryError = null;
      notifyListeners();

      // Load initial data
      final items = await _inventoryRepository.getAllItems();
      
      if (!mounted) return;
      
      // Count available properties (not sold/rented)
      _availableProperties = items.where((item) => 
        item.saleStatus == 'Available' || 
        item.saleStatus == null ||
        item.saleStatus == ''
      ).length;
      
      _inventoryLoading = false;
      _inventoryError = null;
      _updateOverallLoadingState();
      notifyListeners();
      
      // Set up periodic polling for updates (every 30 seconds)
      Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _refreshInventoryData();
      });
      
    } catch (e) {
      _inventoryError = 'Failed to load inventory data: $e';
      _inventoryLoading = false;
      _updateOverallLoadingState();
      notifyListeners();
    }
  }

  Future<void> _refreshInventoryData() async {
    try {
      final items = await _inventoryRepository.getAllItems();
      
      if (!mounted) return;
      
      _availableProperties = items.where((item) => 
        item.saleStatus == 'Available' || 
        item.saleStatus == null ||
        item.saleStatus == ''
      ).length;
      
      notifyListeners();
    } catch (e) {
      // Silently fail on refresh to avoid disrupting UI
    }
  }

  /// Update overall loading state based on individual component states
  void _updateOverallLoadingState() {
    _isLoading = _usersLoading || _companiesLoading || _expenditureLoading || 
                  _rentalsLoading || _tradingLoading || _inventoryLoading;
    
    final hasError = _usersError != null || _companiesError != null || 
                     _expenditureError != null || _rentalsError != null || 
                     _tradingError != null || _inventoryError != null;
    
    _error = hasError ? 'Some dashboard data failed to load' : null;
    notifyListeners();
  }

  /// Refresh all dashboard data
  Future<void> refreshAll() async {
    // Reset loading states
    _isLoading = true;
    _usersLoading = true;
    _companiesLoading = true;
    _expenditureLoading = true;
    _rentalsLoading = true;
    _tradingLoading = true;
    _inventoryLoading = true;
    
    // Reset errors
    _error = null;
    _usersError = null;
    _companiesError = null;
    _expenditureError = null;
    _rentalsError = null;
    _tradingError = null;
    _inventoryError = null;
    
    notifyListeners();

    // Reload all data
    await initialize();
  }

  /// Dispose resources
  @override
  void dispose() {
    _mounted = false;
    _usersSubscription?.cancel();
    _companiesSubscription?.cancel();
    _expendituresSubscription?.cancel();
    _rentalsSubscription?.cancel();
    _tradingSubscription?.cancel();
    super.dispose();
  }

  /// Get formatted monetary value
  String get formattedMonthlyExpenditure {
    return 'Rs ${_monthlyExpenditure.toStringAsFixed(2)}';
  }

  /// Get percentage change for expenditure (placeholder for future implementation)
  double get expenditureChangePercentage {
    // This would compare current month with previous month
    // For now, return 0 as placeholder
    return 0.0;
  }

  /// Get formatted user count with label
  String get userCountLabel {
    return '$_totalUsers Active Users';
  }

  /// Get formatted company count with label
  String get companyCountLabel {
    return '$_totalCompanies Companies';
  }

  /// Get formatted rental count with label
  String get rentalCountLabel {
    return '$_activeRentals Rented Properties';
  }
}
