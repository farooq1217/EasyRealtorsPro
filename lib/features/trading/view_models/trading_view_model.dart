// presentation/view_models/trading_view_model.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart' show TradingEntry, RoleUtils, AppDatabase;
import '../repositories/trading_repository.dart';
import '../repositories/trading_repository_impl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firebase_threading_handler.dart';
import '../models/trading_models.dart';

class TradingViewModel extends ChangeNotifier {
  final TradingRepository _repository;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<List<TradingEntry>>? _entriesSubscription;
  
  // Data
  List<TradingEntry> _entries = [];
  Map<String, dynamic> _statistics = {};
  
  // Property deals and clients data (from property_deal_view_model)
  List<TradingDeal> _deals = [];
  List<TradingClient> _clients = [];
  
  // State
  bool _isLoading = false;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _dateRangeFilter = 'All';
  String _entryTypeFilter = 'All';
  
  // Error states
  String? _error;
  
  // User context
  Map<String, dynamic>? _currentUser;
  String? _userCompanyId;
  bool _isSuperAdmin = false;
  
  // Lifecycle state
  bool _mounted = true;

  TradingViewModel(this._repository) {
    _initializeUser();
  }
  
  bool get mounted => _mounted;

  // Getters
  List<TradingEntry> get entries => _getFilteredEntries();
  Map<String, dynamic> get statistics => _statistics;
  
  // Property deals and clients getters (from property_deal_view_model)
  List<TradingDeal> get deals => List.unmodifiable(_deals);
  List<TradingClient> get clients => List.unmodifiable(_clients);
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get dateRangeFilter => _dateRangeFilter;
  String get entryTypeFilter => _entryTypeFilter;
  
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get userCompanyId => _userCompanyId;
  bool get isSuperAdmin => _isSuperAdmin;

  // Initialize user context
  Future<void> _initializeUser() async {
    try {
      _currentUser = AuthService.currentUser;
      _isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || 
                      RoleUtils.hasPermission(_currentUser, 'bypass_all');
      _userCompanyId = RoleUtils.getUserCompanyId(_currentUser);
      
      await loadEntries();
    } catch (e) {
      debugPrint('Error initializing user context: $e');
      _error = 'Failed to initialize user context';
      notifyListeners();
    }
  }

  // Load entries with real-time stream
  Future<void> loadEntries() async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Cancel existing subscription
          await _entriesSubscription?.cancel();
          
          // Set up stream for entries
          _entriesSubscription = _repository.watchEntries(companyId: _userCompanyId).listen(
            (entries) {
              if (!_mounted) return;
              _entries = entries;
              _isLoading = false; // Set loading to false when data arrives
              _error = null; // Clear any previous error
              debugPrint('TradingViewModel: Received ${entries.length} entries from stream');
              notifyListeners();
            },
            onError: (e) {
              if (!_mounted) return;
              _error = 'Failed to load entries: $e';
              _isLoading = false; // Set loading to false on error
              debugPrint('TradingViewModel: Stream error - $e');
              notifyListeners();
            },
            onDone: () {
              if (!_mounted) return;
              debugPrint('TradingViewModel: Stream completed');
              _isLoading = false; // Ensure loading is false when stream completes
              notifyListeners();
            },
          );
          
          // Set a timeout to prevent infinite loading
          Timer(const Duration(seconds: 5), () {
            if (_mounted && _isLoading) {
              _isLoading = false;
              _error = 'Loading timeout - please check your connection';
              notifyListeners();
            }
          });
        },
        operationName: 'loadEntries',
      );
    } catch (e) {
      debugPrint('Error loading entries: $e');
      _error = 'Failed to load entries';
      _isLoading = false; // Set loading to false on exception
      notifyListeners();
    }
  }

  // Load statistics
  Future<void> loadStatistics() async {
    try {
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          _statistics = await _repository.getTradingStatistics(companyId: _userCompanyId);
        },
        operationName: 'loadStatistics',
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      notifyListeners();
    }
  }

  // Save entry with proper user context and Firebase thread safety
  Future<void> saveEntry(TradingEntry entry) async {
    try {
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Add user context to entry
          final entryWithContext = TradingEntry(
            id: entry.id,
            entryType: entry.entryType,
            date: entry.date,
            personName: entry.personName,
            mobileNo: entry.mobileNo,
            estateName: entry.estateName,
            quantity: entry.quantity,
            unitPrice: entry.unitPrice,
            imagePath: entry.imagePath,
            companyId: _userCompanyId ?? '',
            isActive: entry.isActive,
            isSynced: entry.isSynced,
            createdAt: entry.createdAt,
            updatedAt: DateTime.now(),
            status: entry.status, // Add status field
          );

          await _repository.addEntry(entryWithContext);
          
          // Statistics will update automatically via stream
        },
        operationName: 'saveEntry',
      );
    } catch (e) {
      debugPrint('Error saving trading entry: $e');
      
      // In debug mode, if it's a schema error, reset the database
      if (kDebugMode && e.toString().contains('NOT NULL constraint failed')) {
        debugPrint('[TRADING_VM] Schema error detected, resetting database...');
        try {
          await AppDatabase.closeInstance();
          await AppDatabase.resetDatabaseInDevMode();
          debugPrint('[TRADING_VM] Database reset completed. Please try again.');
        } catch (resetError) {
          debugPrint('[TRADING_VM] Error during database reset: $resetError');
        }
      }
      
      rethrow;
    }
  }

  // Update entry
  Future<void> updateEntry(TradingEntry entry) async {
    try {
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Check if user can access this entry
          if (_currentUser != null && 
              !await _repository.canUserAccessEntry(_currentUser!['id'], entry.id)) {
            throw Exception('You do not have permission to update this entry');
          }

          await _repository.updateEntry(entry);
        },
        operationName: 'updateEntry',
      );
    } catch (e) {
      debugPrint('Error updating trading entry: $e');
      rethrow;
    }
  }

  // Delete entry (soft delete)
  Future<void> deleteEntry(String entryId) async {
    try {
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Check if user can access this entry
          if (_currentUser != null && 
              !await _repository.canUserAccessEntry(_currentUser!['id'], entryId)) {
            throw Exception('You do not have permission to delete this entry');
          }

          await _repository.deleteEntry(entryId);
        },
        operationName: 'deleteEntry',
      );
    } catch (e) {
      debugPrint('Error deleting trading entry: $e');
      rethrow;
    }
  }

  // Search functionality
  Future<void> searchEntries(String query) async {
    _searchQuery = query;
    notifyListeners();
  }

  // Filter by type (removed - using simple string types)
  // void filterByType(TradingEntryType? type) {
  //   _selectedTypeFilter = type;
  //   notifyListeners();
  // }

  // Filter by status
  void filterByStatus(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  // Filter by date range
  void filterByDateRange(String dateRange) {
    _dateRangeFilter = dateRange;
    notifyListeners();
  }

  // Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _statusFilter = 'All';
    _dateRangeFilter = 'All';
    _entryTypeFilter = 'All';
    notifyListeners();
  }

  // Get filtered entries based on search and filters
  List<TradingEntry> _getFilteredEntries() {
    var filtered = _entries.where((entry) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = entry.personName.toLowerCase().contains(query) ||
            entry.estateName.toLowerCase().contains(query) ||
            entry.mobileNo.toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }
      
      // Status filter
      if (_statusFilter != 'All' && _statusFilter.isNotEmpty) {
        if (entry.status.toLowerCase() != _statusFilter.toLowerCase()) return false;
      }
      
      // Date range filter
      if (_dateRangeFilter != 'All' && _dateRangeFilter.isNotEmpty) {
        final now = DateTime.now();
        DateTime? startDate;
        DateTime? endDate;
        
        switch (_dateRangeFilter) {
          case 'Today':
            startDate = DateTime(now.year, now.month, now.day);
            endDate = startDate.add(const Duration(days: 1));
            break;
          case 'This Week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate = DateTime(startDate.year, startDate.month, startDate.day);
            endDate = startDate.add(const Duration(days: 7));
            break;
          case 'This Month':
            startDate = DateTime(now.year, now.month, 1);
            endDate = DateTime(now.year, now.month + 1, 1);
            break;
          case 'This Year':
            startDate = DateTime(now.year, 1, 1);
            endDate = DateTime(now.year + 1, 1, 1);
            break;
        }
        
        if (startDate != null && endDate != null) {
          if (entry.date.isBefore(startDate) || entry.date.isAfter(endDate)) {
            return false;
          }
        }
      }
      
      // Entry type filter
      if (_entryTypeFilter != 'All' && _entryTypeFilter.isNotEmpty) {
        if (entry.entryType != _entryTypeFilter) return false;
      }
      
      return true;
    }).toList();
    
    return filtered;
  }

  // Refresh entries
  Future<void> refresh() async {
    await loadEntries();
  }

  // === PROPERTY DEALS AND CLIENTS METHODS ===
  // NOTE: These methods now use real database operations instead of mock data

  /// Load all property deals from database
  Future<void> loadDeals() async {
    _setLoading(true);
    _error = null;
    
    try {
      // TODO: Implement actual deals loading from database when deals table is created
      // For now, deals functionality is placeholder
      _deals = [];
      debugPrint('TradingViewModel: Deals functionality - table not yet implemented');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error loading deals: $e');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Load all trading clients from database
  Future<void> loadClients() async {
    _setLoading(true);
    _error = null;
    
    try {
      // TODO: Implement actual clients loading from database when clients table is created
      // For now, clients functionality is placeholder
      _clients = [];
      debugPrint('TradingViewModel: Clients functionality - table not yet implemented');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error loading clients: $e');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new property deal (placeholder until deals table is created)
  Future<void> addDeal(TradingDeal deal) async {
    try {
      // TODO: Implement actual database insertion when deals table is created
      debugPrint('TradingViewModel: Add deal functionality - table not yet implemented');
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error adding deal: $e');
      notifyListeners();
    }
  }

  /// Update an existing property deal (placeholder until deals table is created)
  Future<void> updateDeal(TradingDeal deal) async {
    try {
      // TODO: Implement actual database update when deals table is created
      debugPrint('TradingViewModel: Update deal functionality - table not yet implemented');
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error updating deal: $e');
      notifyListeners();
    }
  }

  /// Delete a property deal (placeholder until deals table is created)
  Future<void> deleteDeal(String dealId) async {
    try {
      // TODO: Implement actual database deletion when deals table is created
      debugPrint('TradingViewModel: Delete deal functionality - table not yet implemented');
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error deleting deal: $e');
      notifyListeners();
    }
  }

  /// Add a new trading client (placeholder until clients table is created)
  Future<void> addClient(TradingClient client) async {
    try {
      // TODO: Implement actual database insertion when clients table is created
      debugPrint('TradingViewModel: Add client functionality - table not yet implemented');
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error adding client: $e');
      notifyListeners();
    }
  }

  /// Update an existing trading client (placeholder until clients table is created)
  Future<void> updateClient(TradingClient client) async {
    try {
      // TODO: Implement actual database update when clients table is created
      debugPrint('TradingViewModel: Update client functionality - table not yet implemented');
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error updating client: $e');
      notifyListeners();
    }
  }

  /// Delete a trading client (placeholder until clients table is created)
  Future<void> deleteClient(String clientId) async {
    try {
      // TODO: Implement actual database deletion when clients table is created
      debugPrint('TradingViewModel: Delete client functionality - table not yet implemented');
    } catch (e) {
      _error = e.toString();
      debugPrint('TradingViewModel: Error deleting client: $e');
      notifyListeners();
    }
  }

  /// Get deals by status
  List<TradingDeal> getDealsByStatus(String status) {
    return _deals.where((deal) => deal.status == status).toList();
  }

  /// Get deals by type
  List<TradingDeal> getDealsByType(String type) {
    return _deals.where((deal) => deal.dealType == type).toList();
  }

  /// Calculate total deal amount
  double getTotalDealAmount({String? status, String? type}) {
    var filteredDeals = _deals;
    
    if (status != null) {
      filteredDeals = filteredDeals.where((deal) => deal.status == status).toList();
    }
    
    if (type != null) {
      filteredDeals = filteredDeals.where((deal) => deal.dealType == type).toList();
    }
    
    return filteredDeals.fold(0.0, (sum, deal) => sum + deal.dealAmount);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _mounted = false;
    _entriesSubscription?.cancel();
    super.dispose();
  }
}
