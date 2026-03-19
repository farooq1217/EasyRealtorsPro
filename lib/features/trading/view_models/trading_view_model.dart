// presentation/view_models/trading_view_model.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart' show TradingEntry, RoleUtils, AppDatabase;
import '../repositories/trading_repository.dart';
import '../repositories/trading_repository_impl.dart' show AlreadyDeletedException;
import '../../../core/services/auth_service.dart';
import '../../../core/services/firebase_threading_handler.dart';

class TradingViewModel extends ChangeNotifier {
  final TradingRepository _repository;
  
  // Singleton instance to prevent disposal
  static TradingViewModel? _instance;
  
  // Simple constructor with singleton pattern
  TradingViewModel(this._repository) {
    _instance = this;
    _initializeUser();
  }
  
  // Factory constructor to return existing instance if available
  factory TradingViewModel.getInstance(TradingRepository repository) {
    return _instance ?? TradingViewModel(repository);
  }
  
  // Stream subscriptions for real-time updates
  StreamSubscription<List<TradingEntry>>? _entriesSubscription;
  
  // Data
  List<TradingEntry> _entries = [];
  Map<String, dynamic> _statistics = {};
  
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
  bool _isStreamInitialized = false; // Prevent duplicate stream calls
  bool _isDisposed = false; // Prevent 'used after being disposed' errors
  
  bool get mounted => _mounted;

  // Getters
  List<TradingEntry> get entries => _getFilteredEntries();
  Map<String, dynamic> get statistics => _statistics;
  
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
      
      // Enhanced Super Admin detection for mayof286@gmail.com
      if (_currentUser != null && _currentUser!['email'] == 'mayof286@gmail.com') {
        _isSuperAdmin = true;
        debugPrint('TradingViewModel: Detected Super Admin mayof286@gmail.com - full bypass enabled');
      }
      
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
    if (_isLoading || _isStreamInitialized || _isDisposed) return; // Prevent duplicate calls and calls after dispose
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Cancel existing subscription
          await _entriesSubscription?.cancel();
          _entriesSubscription = null;
          
          // Set up stream for entries
          _entriesSubscription = _repository.watchEntries(companyId: _userCompanyId).listen(
            (entries) {
              if (!_mounted || _isDisposed) return;
              _entries = entries;
              _isLoading = false; // Set loading to false when data arrives
              _error = null; // Clear any previous error
              debugPrint('TradingViewModel: Received ${entries.length} entries from stream');
              notifyListeners();
            },
            onError: (e) {
              if (!_mounted || _isDisposed) return;
              _error = 'Failed to load entries: $e';
              _isLoading = false; // Set loading to false on error
              debugPrint('TradingViewModel: Stream error - $e');
              notifyListeners();
            },
            onDone: () {
              if (!_mounted || _isDisposed) return;
              debugPrint('TradingViewModel: Stream completed');
              _isLoading = false; // Ensure loading is false when stream completes
              notifyListeners();
            },
          );
          
          _isStreamInitialized = true; // Mark as initialized
          
          // Set a timeout to prevent infinite loading
          Timer(const Duration(seconds: 5), () {
            if (_isLoading && _mounted && !_isDisposed) {
              debugPrint('TradingViewModel: Loading timeout - forcing load complete');
              _isLoading = false;
              _error = 'Loading timed out. Please try again.';
              notifyListeners();
            }
          });
        },
        operationName: 'loadEntries',
      );
    } catch (e) {
      debugPrint('Error loading entries: $e');
      _error = 'Failed to load entries: $e';
      _isLoading = false;
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
    if (_isDisposed) return; // Prevent calls after dispose
    
    try {
      _setLoading(true); // Set loading state
      _error = null; // Clear any previous error
      notifyListeners();
      
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Super Admin bypass: Super admins can save entries without restrictions
          // No permission check needed for save operations as they create new entries
          // Enhanced: Explicit role check for debugging
          if (_currentUser != null && _currentUser!['role'] == 'super_admin') {
            debugPrint('TradingViewModel: Super Admin ${_currentUser!['email']} bypassing save restrictions');
          }
          
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
          debugPrint('TradingViewModel: Entry saved successfully${_isSuperAdmin ? ' (Super Admin)' : ''}');
          
          // Immediate UI sync: Add to local list immediately
          _entries.insert(0, entryWithContext);
          debugPrint('TradingViewModel: Added entry to local list immediately - new count: ${_entries.length}');
          
          // Notify listeners immediately for instant UI update
          if (!_isDisposed) {
            notifyListeners();
          }
          
          // Statistics will update automatically via stream
        },
        operationName: 'saveEntry',
      );
      
      // Clean Async Calls: Removed redundant loadEntries() - stream handles updates automatically
      // The real-time stream will automatically update the UI when data changes
    } catch (e) {
      debugPrint('Error saving trading entry: $e');
      _error = 'Failed to save entry: $e';
      
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
    } finally {
      _setLoading(false); // Always reset loading state
      notifyListeners();
    }
  }

  // Update entry
  Future<void> updateEntry(TradingEntry entry) async {
    try {
      _setLoading(true); // Set loading state
      notifyListeners();
      
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Super Admin bypass: Skip permission check if user is super admin
          if (_currentUser != null && 
              !_isSuperAdmin && // Only check permissions if NOT super admin
              !await _repository.canUserAccessEntry(_currentUser!['id'], entry.id)) {
            throw Exception('You do not have permission to update this entry');
          }

          await _repository.updateEntry(entry);
          debugPrint('TradingViewModel: Entry updated successfully${_isSuperAdmin ? ' (Super Admin)' : ''}');
        },
        operationName: 'updateEntry',
      );
    } catch (e) {
      debugPrint('Error updating trading entry: $e');
      _error = 'Failed to update entry: $e';
      rethrow;
    } finally {
      _setLoading(false); // Always reset loading state
      notifyListeners();
    }
  }

  // Update entry status (Robust Approach)
  Future<void> updateEntryStatus(String entryId, String newStatus, {BuildContext? context}) async {
    if (_isDisposed) return;
    
    try {
      // 1. Perform background database update first (Local SQLite is fast enough for this)
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          if (_currentUser != null && 
              !_isSuperAdmin && 
              _currentUser!['role'] != 'super_admin' && 
              _currentUser!['email'] != 'mayof286@gmail.com' && 
              !await _repository.canUserAccessEntry(_currentUser!['id'], entryId)) {
            throw Exception('You do not have permission to update this entry');
          }
          await _repository.updateEntryStatus(entryId, newStatus);
        },
        operationName: 'updateEntryStatus',
      );

      // 2. Direct List Mutation to instantly trigger UI rebuild
      final index = _entries.indexWhere((e) => e.id == entryId);
      if (index != -1) {
        final e = _entries[index];
        _entries[index] = TradingEntry(
          id: e.id,
          entryType: e.entryType,
          date: e.date,
          personName: e.personName,
          mobileNo: e.mobileNo,
          estateName: e.estateName,
          quantity: e.quantity,
          unitPrice: e.unitPrice,
          imagePath: e.imagePath,
          companyId: e.companyId,
          isActive: e.isActive,
          isSynced: e.isSynced,
          createdAt: e.createdAt,
          updatedAt: DateTime.now(),
          status: newStatus,
        );
        notifyListeners(); 
      }

      // 3. Show Success Feedback
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.toUpperCase()}', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('Error updating trading entry status: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Delete entry (soft delete)
  Future<void> deleteEntry(String entryId) async {
    if (_isDisposed) return; // Prevent calls after dispose
    
    try {
      _setLoading(true); // Set loading state
      notifyListeners();
      
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () async {
          // Super Admin Check: Enhanced bypass for mayof286@gmail.com and all super admins
          if (_currentUser != null && 
              !_isSuperAdmin && // Only check permissions if NOT super admin
              _currentUser!['role'] != 'super_admin' && // Explicit role check
              _currentUser!['email'] != 'mayof286@gmail.com' && // Explicit email check
              !await _repository.canUserAccessEntry(_currentUser!['id'], entryId)) {
            throw Exception('You do not have permission to delete this entry');
          }

          await _repository.deleteEntry(entryId);
          debugPrint('TradingViewModel: Entry deleted successfully${_isSuperAdmin ? ' (Super Admin)' : ''} - $entryId');
          
          // Immediate UI sync: Remove from local list immediately
          _entries.removeWhere((entry) => entry.id == entryId);
          debugPrint('TradingViewModel: Removed entry $entryId from local list - new count: ${_entries.length}');
          
          // Notify listeners immediately for instant UI update
          if (!_isDisposed) {
            notifyListeners();
          }
        },
        operationName: 'deleteEntry',
      );
      
      // Don't refresh entries - the stream will handle removing deleted entries automatically
      
      // Show success message
      debugPrint('TradingViewModel: Delete completed successfully for $entryId');
    } catch (e) {
      debugPrint('Error deleting trading entry: $e');
      if (!_isDisposed) {
        _error = 'Failed to delete entry: $e';
        notifyListeners();
      }
      rethrow;
    } finally {
      if (!_isDisposed) {
        _setLoading(false); // Always reset loading state
        notifyListeners();
      }
      // Note: The stream will automatically update the UI when the entry is deleted
      // Manual refresh ensures immediate UI sync
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

  // Filter by entry type
  void filterByEntryType(String type) {
    _entryTypeFilter = type;
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
    _isStreamInitialized = false; // Force stream to re-initialize and fetch fresh DB data
    await loadEntries();
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return; // Safe notifyListeners: Prevent calls after dispose
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return; // Prevent calls after dispose
    _error = null;
    notifyListeners();
  }

  // Reinitialize method for recovery after unexpected disposal
  Future<void> reinitializeIfNeeded() async {
    if (_isDisposed && _mounted == false) {
      debugPrint('TradingViewModel: Reinitializing after disposal');
      _isDisposed = false;
      _mounted = true;
      _isStreamInitialized = false;
      
      await _initializeUser();
      debugPrint('TradingViewModel: Reinitialized successfully');
    }
  }

  // Proper cleanup method for app exit (not navigation)
  void disposeForAppExit() {
    debugPrint('APP EXIT: Disposing TradingViewModel singleton');
    _isDisposed = true;
    _mounted = false;
    _isStreamInitialized = false;
    _entriesSubscription?.cancel();
    _entries.clear();
    _instance = null; // Clear the singleton reference
    super.dispose();
  }

  @override
  void dispose() {
    debugPrint('DISPOSING TradingViewModel instance: ${identityHashCode(this)}');
    
    // ABSOLUTELY DO NOT DISPOSE THE SINGLETON
    // This prevents the blank screen issue entirely
    debugPrint('TradingViewModel: REFUSING TO DISPOSE - singleton must survive');
    
    // Don't cancel streams either - they need to keep working
    // Don't mark as disposed or clear mounted state
    // Keep the instance alive for the entire app lifecycle
    
    // Call super.dispose() to satisfy @mustCallSuper but don't actually dispose
    // The singleton will survive because Provider manages the lifecycle
    super.dispose();
  }
}
