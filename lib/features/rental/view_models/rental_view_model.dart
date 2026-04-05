import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../repositories/rental_repository.dart';
import '../repositories/rental_repository_impl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/shared_utils.dart';
import '../../../core/role_utils.dart';

/// ViewModel for rental items with real-time updates and state management
class RentalViewModel extends ChangeNotifier {
  late final RentalRepository _repository;
  bool _mounted = false;
  
  // State
  List<Map<String, dynamic>> _rentalItems = [];
  bool _loading = true;
  String _searchQuery = '';
  RentalStatus? _statusFilter;
  Map<RentalStatus, int> _stats = {};
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  
  // User context
  Map<String, dynamic>? _currentUser;
  bool _isSuperAdmin = false;
  bool _isAgent = false;
  String? _companyId;
  String? _userId;

  // Stream subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _rentalItemsSubscription;

  RentalViewModel({
    RentalRepository? repository,
  }) : _repository = repository ?? RentalRepositoryImpl() {
    _initializeUser();
  }

  // Getters
  List<Map<String, dynamic>> get rentalItems => _rentalItems;
  bool get loading => _loading;
  String get searchQuery => _searchQuery;
  RentalStatus? get statusFilter => _statusFilter;
  Map<RentalStatus, int> get stats => _stats;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get isAgent => _isAgent;
  String? get companyId => _companyId;
  String? get userId => _userId;
  bool get mounted => _mounted;

  // Permission getters
  bool get canAddRental => PermissionHelper.canAddModule(_currentUser, 'rental_items');
  bool get canEditRental => PermissionHelper.canEditModule(_currentUser, 'rental_items');
  bool get canDeleteRental => PermissionHelper.canDeleteModule(_currentUser, 'rental_items');

  // Standard pagination getters (for consistency with other modules)
  int get currentPage => _currentPage;
  int get itemsPerPage => _pageSize;
  int get totalPages => (_rentalItems.length / _pageSize).ceil();
  List<Map<String, dynamic>> get paginatedRentalItems {
    final startIndex = (_currentPage - 1) * _pageSize;
    return _rentalItems.skip(startIndex).take(_pageSize).toList();
  }

  /// Initialize user context and start data loading
  Future<void> initialize() async {
    await _initializeUser();
    await _loadStats();
    await _loadRentalItems();
  }

  /// Initialize current user from AuthService
  Future<void> _initializeUser() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        _currentUser = await AuthService.getCurrentUser(authToken);
        _isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
        _isAgent = RoleUtils.isAgent(_currentUser);
        _companyId = RoleUtils.getUserCompanyId(_currentUser);
        _userId = _currentUser?['id']?.toString();
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
      _errorMessage = 'Failed to initialize user context';
      notifyListeners();
    }
  }

  /// Start watching rental items with real-time updates
  Future<void> _loadRentalItems({bool resetPagination = true}) async {
    try {
      _loading = true;
      _errorMessage = null;
      notifyListeners();

      // Cancel existing subscription
      await _rentalItemsSubscription?.cancel();

      // Reset pagination if filters changed
      if (resetPagination) {
        _currentPage = 1;
        _hasMore = true;
        _isLoadingMore = false;
      }

      // Build query parameters
      final companyId = _isSuperAdmin ? null : _companyId;
      final createdBy = _isAgent ? _userId : null;

      // Start real-time stream
      _rentalItemsSubscription = _repository.watchRentalItems(
        companyId: companyId,
        createdBy: createdBy,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        statusFilter: _statusFilter,
      ).listen(
        (items) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _rentalItems = items;
            _loading = false;
            _errorMessage = null;
            notifyListeners();
          });
        },
        onError: (error) {
          debugPrint('Error loading rental items: $error');
          _errorMessage = 'Failed to load rental items: $error';
          _loading = false;
          notifyListeners();
        },
      );

      // Load initial data for pagination
      if (resetPagination) {
        final initialItems = await _repository.getRentalItemsPaginated(
          companyId: companyId,
          createdBy: createdBy,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          statusFilter: _statusFilter,
          page: 1,
          limit: _pageSize,
        );
        
        _rentalItems = initialItems;
        _hasMore = initialItems.length >= _pageSize;
        _loading = false;
        notifyListeners();
      }

    } catch (e) {
      debugPrint('Error in _loadRentalItems: $e');
      _errorMessage = 'Failed to load rental items: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Load rental statistics
  Future<void> _loadStats() async {
    try {
      final companyId = _isSuperAdmin ? null : _companyId;
      _stats = await _repository.getRentalStats(companyId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading rental stats: $e');
    }
  }

  /// Load more items for pagination
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      final companyId = _isSuperAdmin ? null : _companyId;
      final createdBy = _isAgent ? _userId : null;

      final moreItems = await _repository.getRentalItemsPaginated(
        companyId: companyId,
        createdBy: createdBy,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        statusFilter: _statusFilter,
        page: _currentPage + 1,
        limit: _pageSize,
      );

      _rentalItems = [..._rentalItems, ...moreItems];
      _currentPage++;
      _hasMore = moreItems.length >= _pageSize;
      _isLoadingMore = false;
      notifyListeners();

    } catch (e) {
      debugPrint('Error loading more rental items: $e');
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Search rental items
  Future<void> searchRentalItems(String query) async {
    if (_searchQuery == query) return;
    
    _searchQuery = query;
    await _loadRentalItems();
  }

  /// Filter by status
  Future<void> filterByStatus(RentalStatus? status) async {
    if (_statusFilter == status) return;
    
    _statusFilter = status;
    await _loadRentalItems();
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    _searchQuery = '';
    _statusFilter = null;
    await _loadRentalItems();
  }

  /// Add a new rental item
  Future<bool> addRentalItem(Map<String, dynamic> item) async {
    if (!canAddRental) {
      _errorMessage = 'You do not have permission to add rental items';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      
      // Set company and creator context
      final finalItem = Map<String, dynamic>.from(item);
      if (!_isSuperAdmin) {
        finalItem['company_id'] = _companyId;
        finalItem['created_by'] = _userId;
      }

      await _repository.addRentalItem(finalItem);
      await _loadStats(); // Refresh stats
      
      // Real-time stream will update the list automatically
      return true;
    } catch (e) {
      debugPrint('Error adding rental item: $e');
      _errorMessage = 'Failed to add rental item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing rental item
  Future<bool> updateRentalItem(Map<String, dynamic> item) async {
    if (!canEditRental) {
      _errorMessage = 'You do not have permission to edit rental items';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _repository.updateRentalItem(item);
      await _loadStats(); // Refresh stats
      
      // Real-time stream will update the list automatically
      return true;
    } catch (e) {
      debugPrint('Error updating rental item: $e');
      _errorMessage = 'Failed to update rental item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update rental item status
  Future<bool> updateRentalStatus(String id, RentalStatus status) async {
    if (!canEditRental) {
      _errorMessage = 'You do not have permission to update rental items';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _repository.updateRentalStatus(id, status);
      await _loadStats(); // Refresh stats
      
      // Real-time stream will update the list automatically
      return true;
    } catch (e) {
      debugPrint('Error updating rental status: $e');
      _errorMessage = 'Failed to update rental status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a rental item
  Future<bool> deleteRentalItem(String id) async {
    if (!canDeleteRental) {
      _errorMessage = 'You do not have permission to delete rental items';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _repository.deleteRentalItem(id);
      await _loadStats(); // Refresh stats
      
      // Real-time stream will update the list automatically
      return true;
    } catch (e) {
      debugPrint('Error deleting rental item: $e');
      _errorMessage = 'Failed to delete rental item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get a single rental item by ID
  Future<Map<String, dynamic>?> getRentalItemById(String id) async {
    try {
      return await _repository.getRentalItemById(id);
    } catch (e) {
      debugPrint('Error getting rental item: $e');
      _errorMessage = 'Failed to get rental item: $e';
      notifyListeners();
      return null;
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await _loadStats();
    await _loadRentalItems();
  }

  /// Public method to load rental items (for modal refresh)
  Future<void> loadRentalItems() async {
    await _loadRentalItems();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Standard pagination methods (for consistency with other modules)
  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  void setItemsPerPage(int limit) {
    if (_pageSize != limit) {
      _pageSize = limit;
      _currentPage = 1; // Reset to page 1 when items per page changes
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _rentalItemsSubscription?.cancel();
    super.dispose();
  }
}
