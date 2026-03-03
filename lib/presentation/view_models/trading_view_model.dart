// presentation/view_models/trading_view_model.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/trading_entry.dart';
import '../../domain/repositories/trading_repository.dart';
import '../../core/services/auth_service.dart';
import 'package:shared/shared.dart' show RoleUtils;

class TradingViewModel extends ChangeNotifier {
  final TradingRepository _repository;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<List<TradingEntry>>? _entriesSubscription;
  StreamSubscription<List<TradingEntry>>? _fileEntriesSubscription;
  StreamSubscription<List<TradingEntry>>? _formEntriesSubscription;
  
  // Data
  List<TradingEntry> _entries = [];
  List<TradingEntry> _fileEntries = [];
  List<TradingEntry> _formEntries = [];
  Map<String, dynamic> _statistics = {};
  
  // State
  bool _isLoading = false;
  bool _isLoadingStats = false;
  String _searchQuery = '';
  TradingEntryType? _selectedTypeFilter;
  String _statusFilter = 'All';
  String _dateRangeFilter = 'All';
  
  // Error states
  String? _error;
  String? _statsError;
  
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
  List<TradingEntry> get fileEntries => _getFilteredFileEntries();
  List<TradingEntry> get formEntries => _getFilteredFormEntries();
  Map<String, dynamic> get statistics => _statistics;
  
  bool get isLoading => _isLoading;
  bool get isLoadingStats => _isLoadingStats;
  String? get error => _error;
  String? get statsError => _statsError;
  
  String get searchQuery => _searchQuery;
  TradingEntryType? get selectedTypeFilter => _selectedTypeFilter;
  String get statusFilter => _statusFilter;
  String get dateRangeFilter => _dateRangeFilter;
  
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
      await loadStatistics();
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

      // Cancel existing subscriptions
      await _entriesSubscription?.cancel();
      await _fileEntriesSubscription?.cancel();
      await _formEntriesSubscription?.cancel();

      // Set up stream for all entries
      _entriesSubscription = _repository.watchEntries(companyId: _userCompanyId).listen(
        (entries) {
          if (!mounted) return;
          _entries = entries;
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          _error = 'Failed to load entries: $e';
          _isLoading = false;
          notifyListeners();
        },
      );

      // Set up stream for file entries
      _fileEntriesSubscription = _repository.watchEntriesByType(
        TradingEntryType.file, 
        companyId: _userCompanyId
      ).listen(
        (entries) {
          if (!mounted) return;
          _fileEntries = entries;
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          debugPrint('Error loading file entries: $e');
        },
      );

      // Set up stream for form entries
      _formEntriesSubscription = _repository.watchEntriesByType(
        TradingEntryType.form, 
        companyId: _userCompanyId
      ).listen(
        (entries) {
          if (!mounted) return;
          _formEntries = entries;
          notifyListeners();
        },
        onError: (e) {
          if (!mounted) return;
          debugPrint('Error loading form entries: $e');
        },
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load entries: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load statistics
  Future<void> loadStatistics() async {
    try {
      _isLoadingStats = true;
      _statsError = null;
      notifyListeners();

      _statistics = await _repository.getTradingStatistics(companyId: _userCompanyId);
      
      _isLoadingStats = false;
      notifyListeners();
    } catch (e) {
      _statsError = 'Failed to load statistics: $e';
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  // Save entry with proper user context
  Future<void> saveEntry(TradingEntry entry) async {
    try {
      // Add user context to entry
      final entryWithContext = TradingEntry(
        id: entry.id,
        type: entry.type,
        entryType: entry.entryType,
        date: entry.date,
        personName: entry.personName,
        mobile: entry.mobile,
        estateName: entry.estateName,
        plotNo: entry.plotNo,
        block: entry.block,
        quantity: entry.quantity,
        rate: entry.rate,
        totalAmount: entry.totalAmount,
        commission: entry.commission,
        tax: entry.tax,
        netAmount: entry.netAmount,
        status: entry.status,
        comments: entry.comments,
        companyId: _userCompanyId,
        createdBy: _currentUser?['id'],
      );

      await _repository.addEntry(entryWithContext);
      
      // Statistics will update automatically via stream
    } catch (e) {
      debugPrint('Error saving trading entry: $e');
      rethrow;
    }
  }

  // Update entry
  Future<void> updateEntry(TradingEntry entry) async {
    try {
      // Check if user can access this entry
      if (_currentUser != null && 
          !await _repository.canUserAccessEntry(_currentUser!['id'], entry.id)) {
        throw Exception('You do not have permission to update this entry');
      }

      await _repository.updateEntry(entry);
    } catch (e) {
      debugPrint('Error updating trading entry: $e');
      rethrow;
    }
  }

  // Delete entry (soft delete)
  Future<void> deleteEntry(String entryId) async {
    try {
      // Check if user can access this entry
      if (_currentUser != null && 
          !await _repository.canUserAccessEntry(_currentUser!['id'], entryId)) {
        throw Exception('You do not have permission to delete this entry');
      }

      await _repository.deleteEntry(entryId);
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

  // Filter by type
  void filterByType(TradingEntryType? type) {
    _selectedTypeFilter = type;
    notifyListeners();
  }

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
    _selectedTypeFilter = null;
    _statusFilter = 'All';
    _dateRangeFilter = 'All';
    notifyListeners();
  }

  // Get filtered entries based on current filters
  List<TradingEntry> _getFilteredEntries() {
    var filtered = List<TradingEntry>.from(_entries);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) =>
        entry.personName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        entry.estateName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        entry.mobile.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (entry.comments?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    // Apply entry type filter
    if (_selectedTypeFilter != null) {
      filtered = filtered.where((entry) => entry.entryType == _selectedTypeFilter).toList();
    }

    // Apply status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((entry) => entry.status == _statusFilter).toList();
    }

    // Apply date range filter
    if (_dateRangeFilter != 'All') {
      final now = DateTime.now();
      DateTime? startDate;
      
      switch (_dateRangeFilter) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
      }
      
      if (startDate != null) {
        filtered = filtered.where((entry) => entry.date.isAfter(startDate!)).toList();
      }
    }

    return filtered;
  }

  // Get filtered file entries
  List<TradingEntry> _getFilteredFileEntries() {
    return _getFilteredEntries().where((entry) => entry.entryType == TradingEntryType.file).toList();
  }

  // Get filtered form entries
  List<TradingEntry> _getFilteredFormEntries() {
    return _getFilteredEntries().where((entry) => entry.entryType == TradingEntryType.form).toList();
  }

  // Get profit calculations
  double getTotalProfit() {
    return _statistics['totalAmount'] as double? ?? 0.0;
  }

  double getTotalCommission() {
    return _statistics['totalCommission'] as double? ?? 0.0;
  }

  int getCompletedEntries() {
    return _statistics['completedEntries'] as int? ?? 0;
  }

  int getPendingEntries() {
    return _statistics['pendingEntries'] as int? ?? 0;
  }

  // Refresh all data
  Future<void> refresh() async {
    await Future.wait([
      loadEntries(),
      loadStatistics(),
    ]);
  }

  @override
  void dispose() {
    _mounted = false;
    _entriesSubscription?.cancel();
    _fileEntriesSubscription?.cancel();
    _formEntriesSubscription?.cancel();
    super.dispose();
  }
}
