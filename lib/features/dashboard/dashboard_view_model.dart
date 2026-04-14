import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import '../../../core/services/auth_service.dart';
import '../../../core/role_utils.dart';
import '../users/repositories/user_repository.dart' as user_repo;
import '../companies/repositories/company_repository.dart';
import '../expenditure/repositories/expenditure_repository.dart';
import '../rental/repositories/rental_repository.dart';
import '../trading/repositories/trading_repository.dart';
import '../inventory/repositories/inventory_repository.dart';
import '../users/models/user_model.dart';
import '../companies/models/company_model.dart';
import '../expenditure/models/expenditure_item.dart';
import 'package:shared/shared.dart' show TradingEntry, AppDatabase;
import '../inventory/models/inventory_item.dart';

class DashboardViewModel extends ChangeNotifier {
  final user_repo.UserRepository _userRepository;
  final CompanyRepository _companyRepository;
  final ExpenditureRepository _expenditureRepository;
  final RentalRepository _rentalRepository;
  final TradingRepository _tradingRepository;
  final InventoryRepository _inventoryRepository;
  final user_repo.UserRepository _usersRepository;

  // Current user context for RBAC
  Map<String, dynamic>? _currentUser;
  String? _currentUserCompanyId;
  String? _currentUserEmail;
  bool _isSuperAdmin = false;
  bool _isCompanyAdmin = false;
  bool _isAgent = false;

  // Stream subscriptions for real-time updates
  StreamSubscription<List<UserModel>>? _usersSubscription;
  StreamSubscription<List<CompanyModel>>? _companiesSubscription;
  StreamSubscription<List<ExpenditureItem>>? _expendituresSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _rentalsSubscription;
  StreamSubscription<List<TradingEntry>>? _tradingSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _tasksSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _inventorySub;
  
  // Database instance for direct queries
  late AppDatabase _database;
  
  // Selected inventory type for queries
  InventoryType _selectedType = InventoryType.file;

  // Dashboard statistics with RBAC filtering
  int _totalInventory = 0;
  int _totalRentalItems = 0;
  int _totalActiveUsers = 0;
  double _totalExpenses = 0.0;
  int _totalTasks = 0;
  
  // Additional metrics for detailed view
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
  bool _isDisposed = false; // CRITICAL: Prevent disposed crashes
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
    required AppDatabase database,
    required String? companyId,
    required bool? isSuperAdmin,
  })  : _userRepository = userRepository,
        _companyRepository = companyRepository,
        _expenditureRepository = expenditureRepository,
        _rentalRepository = rentalRepository,
        _tradingRepository = tradingRepository,
        _inventoryRepository = inventoryRepository,
        _usersRepository = usersRepository,
        _database = database;

  // Getters for dashboard statistics
  int get totalInventory => _totalInventory;
  int get totalRentalItems => _totalRentalItems;
  int get totalActiveUsers => _totalActiveUsers;
  double get totalExpenses => _totalExpenses;
  int get totalTasks => _totalTasks;
  
  // Additional getters
  int get totalUsers => _totalActiveUsers;
  int get totalCompanies => _totalCompanies;
  double get monthlyExpenditure => _monthlyExpenditure;
  int get activeRentals => _activeRentals;
  int get totalClosedDeals => _totalClosedDeals;
  double get totalTradingProfit => _totalTradingProfit;
  int get availableProperties => _availableProperties;
  List<TradingEntry> get tradingEntries => _totalTradingEntries;
  
  // User context getters
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get currentUserCompanyId => _currentUserCompanyId;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get isCompanyAdmin => _isCompanyAdmin;
  bool get isAgent => _isAgent;

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

  /// Initialize dashboard data with RBAC context and set up real-time streams
  Future<void> initialize() async {
    if (!_isLoading) return; // Already initialized, prevent multiple initializations
    
    try {
      // Set up current user context for RBAC
      _setupUserContext();
      
      await Future.wait([
        _loadUsersData(),
        _loadCompaniesData(),
        _loadExpenditureData(),
        _loadRentalsData(),
        _loadTradingData(),
        _loadInventoryData(),
        _loadTasksData(),
      ]);

      // Check if all data is loaded
      _updateOverallLoadingState();
    } catch (e) {
      debugPrint('DashboardViewModel: Initialization error: $e');
      _error = 'Failed to initialize dashboard: $e';
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Set up current user context for RBAC filtering
  void _setupUserContext() {
    _currentUser = AuthService.currentUser;
    _currentUserCompanyId = RoleUtils.getUserCompanyId(_currentUser);
    _currentUserEmail = _currentUser?['email']?.toString();
    
    _isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    _isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);
    _isAgent = RoleUtils.isAgent(_currentUser);
    
    debugPrint('DashboardViewModel: User context set - Role: ${RoleUtils.getUserRole(_currentUser)}, Company: $_currentUserCompanyId, Email: $_currentUserEmail');
  }

  /// Refresh all dashboard data
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    if (!_isDisposed) notifyListeners();
    
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
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load users data with strict RBAC filtering and real-time updates
  Future<void> _loadUsersData() async {
    try {
      _usersLoading = true;
      _usersError = null;
      if (!_isDisposed) notifyListeners();
      
      // Cancel existing subscription
      await _usersSubscription?.cancel();
      
      // Determine company filter based on role
      String? companyIdFilter;
      if (_isSuperAdmin) {
        // Super Admin sees all users across all companies
        companyIdFilter = null;
      } else if (_isCompanyAdmin || _isAgent) {
        // Company Admin and Agent see users from their company only
        companyIdFilter = _currentUserCompanyId;
      } else {
        // Regular users see no users - use null to return empty results
        companyIdFilter = null;
      }
      
      // Set up stream for users with RBAC filtering
      _usersSubscription = _usersRepository.watchUsers(companyIdFilter).listen(
        (users) {
          if (!_mounted) return;
          
          // Apply additional RBAC filtering
          List<UserModel> filteredUsers = users;
          
          if (_isAgent) {
            // Agents only see themselves in the users count
            filteredUsers = users.where((user) => 
              user.email == _currentUserEmail
            ).toList();
          } else if (_isCompanyAdmin) {
            // Company Admin sees all users in their company
            filteredUsers = users.where((user) => 
              user.companyId == _currentUserCompanyId
            ).toList();
          }
          // Super Admin sees all users (no additional filtering)
          
          _users = filteredUsers;
          _totalActiveUsers = filteredUsers.length;
          _usersLoading = false;
          if (!_isDisposed) notifyListeners();
        },
        onError: (e) {
          if (!_mounted) return;
          _usersError = 'Failed to load users: $e';
          _usersLoading = false;
          if (!_isDisposed) notifyListeners();
        },
      );
    } catch (e) {
      _usersError = 'Failed to initialize users stream: $e';
      _usersLoading = false;
      _updateOverallLoadingState();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load companies data with strict RBAC filtering and real-time updates
  Future<void> _loadCompaniesData() async {
    try {
      _companiesLoading = true;
      _companiesError = null;
      if (!_isDisposed) notifyListeners();

      // Cancel existing subscription
      await _companiesSubscription?.cancel();

      // Only Super Admins can see companies data
      if (!_isSuperAdmin) {
        _totalCompanies = 0;
        _companiesLoading = false;
        _updateOverallLoadingState();
        if (!_isDisposed) notifyListeners();
        return;
      }

      // Set up stream for real-time updates (Super Admin only)
      _companiesSubscription = _companyRepository.watchCompanies().listen(
        (companies) {
          if (!mounted) return;
          
          // Count registered companies
          _totalCompanies = companies.where((company) => company.isActive).length;
          
          _companiesLoading = false;
          _companiesError = null;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _companiesError = 'Failed to load companies: $e';
          _companiesLoading = false;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
      );
    } catch (e) {
      _companiesError = 'Failed to initialize companies stream: $e';
      _companiesLoading = false;
      _updateOverallLoadingState();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load expenditure data with strict RBAC filtering and real-time updates
  Future<void> _loadExpenditureData() async {
    try {
      _expenditureLoading = true;
      _expenditureError = null;
      if (!_isDisposed) notifyListeners();

      // Cancel existing subscription
      await _expendituresSubscription?.cancel();

      // Determine company filter based on role
      String? companyIdFilter;
      if (_isSuperAdmin) {
        // Super Admin sees all expenditures across all companies
        companyIdFilter = null;
      } else if (_isCompanyAdmin || _isAgent) {
        // Company Admin and Agent see expenditures from their company only
        companyIdFilter = _currentUserCompanyId;
      } else {
        // Regular users see no expenditures - use null to return empty results
        companyIdFilter = null;
      }

      // Set up stream for real-time updates with RBAC filtering
      _expendituresSubscription = _expenditureRepository.watchExpenditures(
        companyIdFilter,
      ).listen(
        (expenditures) {
          if (!mounted) return;
          
          // Apply additional RBAC filtering for Agents
          List<ExpenditureItem> filteredExpenditures = expenditures;
          
          if (_isAgent) {
            // Agents only see expenditures they personally created
            filteredExpenditures = expenditures.where((exp) => 
              exp.createdBy == _currentUserEmail
            ).toList();
          } else if (_isCompanyAdmin) {
            // Company Admin sees all expenditures in their company
            filteredExpenditures = expenditures.where((exp) => 
              exp.companyId == _currentUserCompanyId
            ).toList();
          }
          // Super Admin sees all expenditures (no additional filtering)
          
          // Calculate current month's expenses from filtered data
          final now = DateTime.now();
          final currentMonth = DateTime(now.year, now.month, 1);
          final nextMonth = DateTime(now.year, now.month + 1, 1);
          
          _monthlyExpenditure = filteredExpenditures
              .where((exp) => 
                exp.isActive &&
                exp.createdAt.isAfter(currentMonth) &&
                exp.createdAt.isBefore(nextMonth)
              )
              .fold(0.0, (sum, exp) => sum + exp.amount);
              
          // Calculate total expenses for dashboard
          _totalExpenses = filteredExpenditures
              .where((exp) => exp.isActive)
              .fold(0.0, (sum, exp) => sum + exp.amount);
          
          _expenditureLoading = false;
          _expenditureError = null;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _expenditureError = 'Failed to load expenditures: $e';
          _expenditureLoading = false;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
      );
    } catch (e) {
      _expenditureError = 'Failed to initialize expenditures stream: $e';
      _expenditureLoading = false;
      _updateOverallLoadingState();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load rental data with strict RBAC filtering and real-time updates
  Future<void> _loadRentalsData() async {
    try {
      _rentalsLoading = true;
      _rentalsError = null;
      if (!_isDisposed) notifyListeners();

      // Cancel existing subscription
      await _rentalsSubscription?.cancel();

      // Determine company filter based on role
      String? companyIdFilter;
      if (_isSuperAdmin) {
        // Super Admin sees all rentals across all companies
        companyIdFilter = null;
      } else if (_isCompanyAdmin || _isAgent) {
        // Company Admin and Agent see rentals from their company only
        companyIdFilter = _currentUserCompanyId;
      } else {
        // Regular users see no rentals - use null to return empty results
        companyIdFilter = null;
      }

      // Set up stream for real-time updates with RBAC filtering
      // Show all rentals (not just rented) for consistency with Rental list
      _rentalsSubscription = _rentalRepository.watchRentalItems(
        statusFilter: null, // Show all rentals
        companyId: companyIdFilter,
      ).listen(
        (rentals) {
          if (!mounted) return;
          
          // Apply additional RBAC filtering for Agents
          List<Map<String, dynamic>> filteredRentals = rentals;
          
          if (_isAgent) {
            // Agents only see rentals they personally created
            filteredRentals = rentals.where((rental) => 
              rental['created_by'] == _currentUserEmail
            ).toList();
          } else if (_isCompanyAdmin) {
            // Company Admin sees all rentals in their company
            filteredRentals = rentals.where((rental) => 
              rental['company_id'] == _currentUserCompanyId
            ).toList();
          }
          // Super Admin sees all rentals (no additional filtering)
          
          // Count all rental properties from filtered data
          _activeRentals = filteredRentals.where((rental) => 
            rental['status'] == 'Rented'
          ).length;
          _totalRentalItems = filteredRentals.length;
          
          _rentalsLoading = false;
          _rentalsError = null;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _rentalsError = 'Failed to load rentals: $e';
          _rentalsLoading = false;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
      );
    } catch (e) {
      _rentalsError = 'Failed to initialize rentals stream: $e';
      _rentalsLoading = false;
      _updateOverallLoadingState();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load trading data with strict RBAC filtering and real-time updates
  Future<void> _loadTradingData() async {
    try {
      _tradingLoading = true;
      _tradingError = null;
      if (!_isDisposed) notifyListeners();

      // Cancel existing subscription
      await _tradingSubscription?.cancel();

      // Determine company filter based on role
      String? companyIdFilter;
      if (_isSuperAdmin) {
        // Super Admin sees all trading entries across all companies
        companyIdFilter = null;
      } else if (_isCompanyAdmin || _isAgent) {
        // Company Admin and Agent see trading entries from their company only
        companyIdFilter = _currentUserCompanyId;
      } else {
        // Regular users see no trading entries - use null to return empty results
        companyIdFilter = null;
      }

      // Set up stream for real-time updates with RBAC filtering
      _tradingSubscription = _tradingRepository.watchEntries(
        companyId: companyIdFilter,
      ).listen(
        (entries) {
          if (!_mounted) return;
          
          // Apply additional RBAC filtering for Agents
          List<TradingEntry> filteredEntries = entries;
          
          // For now, we'll skip agent-specific filtering since TradingEntry doesn't have createdBy
          // This can be implemented later by adding a created_by field to TradingEntry
          if (_isCompanyAdmin) {
            // Company Admin sees all trading entries in their company
            filteredEntries = entries.where((entry) => 
              entry.companyId == _currentUserCompanyId
            ).toList();
          }
          // Super Admin sees all trading entries (no additional filtering)
          // Agents see all trading entries in their company (filtered at repository level)
          
          // Calculate trading performance metrics from filtered data
          _totalClosedDeals = filteredEntries.where((e) => e.isActive).length;
          _totalTradingEntries = filteredEntries;
          
          // Calculate profit from closed deals (using unitPrice * quantity)
          _totalTradingProfit = filteredEntries.where((e) => e.isActive).fold(0.0, (sum, entry) {
            // Using totalPrice which is quantity * unitPrice
            return sum + entry.totalPrice;
          });
          
          _tradingLoading = false;
          _tradingError = null;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
        onError: (e) {
          if (!_mounted) return;
          _tradingError = 'Failed to load trading data: $e';
          _tradingLoading = false;
          _updateOverallLoadingState();
          if (!_isDisposed) notifyListeners();
        },
      );
    } catch (e) {
      _tradingError = 'Failed to initialize trading stream: $e';
      _tradingLoading = false;
      _updateOverallLoadingState();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load inventory data with strict RBAC filtering and real-time updates
  Future<void> _loadInventoryData() async {
    try {
      _inventoryLoading = true;
      _inventoryError = null;
      if (!_isDisposed) notifyListeners();
      
      // Determine company filter based on role
      String? companyIdFilter;
      if (_isSuperAdmin) {
        // Super Admin sees all inventory across all companies
        companyIdFilter = null;
      } else if (_isCompanyAdmin || _isAgent) {
        // Company Admin and Agent see inventory from their company only
        companyIdFilter = _currentUserCompanyId;
      } else {
        // Regular users see no inventory - use null to return empty results
        companyIdFilter = null;
      }
      
      // Set up reactive stream for inventory data (like other methods)
      await _inventorySub?.cancel();
      
      final table = _selectedType == InventoryType.file ? 'files_table' : 'properties';
      final clauses = <String>['is_active = 1'];
      final vars = <d.Variable<String>>[];
      if (!_isSuperAdmin) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(_currentUserCompanyId!));
      }
      
      final where = clauses.isNotEmpty ? 'WHERE ${clauses.join(' AND ')}' : '';
      final query = '''
        SELECT * FROM $table $where ORDER BY updated_at DESC
      ''';
      
      // Set up reactive stream for real-time updates
      _inventorySub = _database
          .customSelect(query, variables: vars)
          .watch()
          .map((rows) => rows.map((r) => Map<String, dynamic>.from(r.data)).toList())
          .listen((data) {
            if (!_mounted) return;
            
            // Apply additional RBAC filtering for Agents and Company Admins
            List<Map<String, dynamic>> filteredItems = data;
            
            if (_isAgent) {
              // Agents only see inventory items they personally created
              // Note: InventoryItem doesn't have createdBy field yet, so agents see company items for now
              filteredItems = data.where((item) => 
                item['company_id'] == _currentUserCompanyId
              ).toList();
            } else if (_isCompanyAdmin) {
              // Company Admin sees all inventory items in their company
              filteredItems = data.where((item) => 
                item['company_id'] == _currentUserCompanyId
              ).toList();
            }
            // Super Admin sees all inventory items (no additional filtering)
            
            // Count available properties (not sold/rented) from filtered data
            _availableProperties = filteredItems.where((item) => 
              item['sale_status'] == 'Available' || 
              item['sale_status'] == null ||
              item['sale_status'] == ''
            ).length;
            
            // Set total inventory count for dashboard
            _totalInventory = filteredItems.length;
            
            _inventoryLoading = false;
            _inventoryError = null;
            _updateOverallLoadingState();
            if (!_isDisposed) notifyListeners();
          },
          onError: (e) {
            if (!_mounted) return;
            _inventoryError = 'Failed to load inventory data: $e';
            _inventoryLoading = false;
            _updateOverallLoadingState();
            if (!_isDisposed) notifyListeners();
          },
        );
      
      // Initial load to show data immediately
      final initialResult = await _database
          .customSelect(query, variables: vars)
          .get();
      
      if (!mounted) {
        // Process initial result immediately
        final initialRows = initialResult.map((r) => Map<String, dynamic>.from(r.data)).toList();
        
        // Apply RBAC filtering to initial data
        List<Map<String, dynamic>> filteredItems = initialRows;
        
        if (_isAgent) {
          filteredItems = initialRows.where((item) => 
            item['company_id'] == _currentUserCompanyId
          ).toList();
        } else if (_isCompanyAdmin) {
          filteredItems = initialRows.where((item) => 
            item['company_id'] == _currentUserCompanyId
          ).toList();
        }
        
        _totalInventory = filteredItems.length;
        _availableProperties = filteredItems.where((item) => 
          item['sale_status'] == 'Available' || 
          item['sale_status'] == null ||
          item['sale_status'] == ''
        ).length;
        
        _inventoryLoading = false;
        _inventoryError = null;
        _updateOverallLoadingState();
        if (!_isDisposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('DashboardViewModel: Error loading inventory data: $e');
      _inventoryError = 'Failed to load inventory data: $e';
      _inventoryLoading = false;
      _updateOverallLoadingState();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Load tasks data with strict RBAC filtering and real-time updates
  Future<void> _loadTasksData() async {
    try {
      // For now, we'll use a simple count based on role
      // In a full implementation, this would connect to a tasks repository
      
      if (_isSuperAdmin) {
        // Super Admin sees all tasks across all companies
        _totalTasks = 0; // Placeholder - would query all tasks
      } else if (_isCompanyAdmin) {
        // Company Admin sees tasks from their company
        _totalTasks = 0; // Placeholder - would query company tasks
      } else if (_isAgent) {
        // Agents only see their own tasks
        _totalTasks = 0; // Placeholder - would query agent tasks
      } else {
        // Regular users see no tasks
        _totalTasks = 0;
      }
      
      // For demonstration, we'll set a mock value
      _totalTasks = 5;
      
    } catch (e) {
      debugPrint('DashboardViewModel: Failed to load tasks data: $e');
      _totalTasks = 0;
    }
  }

  Future<void> _refreshInventoryData() async {
    try {
      // Determine company filter based on role
      String? companyIdFilter;
      if (_isSuperAdmin) {
        // Super Admin sees all inventory across all companies
        companyIdFilter = null;
      } else if (_isCompanyAdmin || _isAgent) {
        companyIdFilter = _currentUserCompanyId;
      } else {
        // Regular users see no inventory - use null to return empty results
        companyIdFilter = null;
      }
      
      final items = await _inventoryRepository.getAllItems(companyId: companyIdFilter);
      
      if (!mounted) return;
      
      // Apply additional RBAC filtering for Agents and Company Admins
      List<InventoryItem> filteredItems = items;
      
      if (_isAgent) {
        // Agents only see inventory items they personally created
        // Note: InventoryItem doesn't have createdBy field yet, so agents see company items for now
        filteredItems = items.where((item) => 
          item.companyId == _currentUserCompanyId
        ).toList();
      } else if (_isCompanyAdmin) {
        // Company Admin sees all inventory items in their company
        filteredItems = items.where((item) => 
          item.companyId == _currentUserCompanyId
        ).toList();
      }
      // Super Admin sees all inventory items (no additional filtering)
      // Agents see all inventory items in their company (filtered at repository level)
      
      // Count available properties (not sold/rented) from filtered data
      _availableProperties = filteredItems.where((item) => 
        item.saleStatus == 'Available' || 
        item.saleStatus == null ||
        item.saleStatus == ''
      ).length;
      
      _totalInventory = filteredItems.length;
      
      if (!_isDisposed) notifyListeners();
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
    if (!_isDisposed) notifyListeners();
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
    
    if (!_isDisposed) notifyListeners();

    // Reload all data
    await initialize();
  }

  /// Dispose resources
  @override
  void dispose() {
    _mounted = false;
    _isDisposed = true; // CRITICAL: Set disposal flag
    _usersSubscription?.cancel();
    _companiesSubscription?.cancel();
    _expendituresSubscription?.cancel();
    _rentalsSubscription?.cancel();
    _tradingSubscription?.cancel();
    _tasksSubscription?.cancel();
    _inventorySub?.cancel();
    debugPrint('DashboardViewModel: Disposed - all subscriptions cancelled');
    super.dispose();
  }

  /// Safe notifyListeners wrapper
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
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
    return '$_totalActiveUsers Active Users';
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
