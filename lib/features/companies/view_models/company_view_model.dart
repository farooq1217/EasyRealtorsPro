import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shimmer_widgets.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/company_model.dart';
import '../repositories/company_repository.dart';
import '../repositories/company_repository_impl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/professional_pdf_generator.dart';
import '../../../core/services/firebase_threading_handler.dart';
import '../../../core/shared_utils.dart';
import 'package:shared/src/auth/role_utils.dart';

class CompanyViewModel extends ChangeNotifier {
  final CompanyRepository _repository;
  bool _mounted = false;
  bool _isDisposed = false; // CRITICAL: Prevent disposed crashes
  
  CompanyViewModel(this._repository);

  // State
  bool _loading = true;
  bool _saving = false;
  String _error = '';
  Map<String, dynamic>? _currentUser;
  List<CompanyModel> _companies = [];
  List<CompanyModel> _filteredCompanies = [];
  CompanyModel? _editingCompany;
  String _searchQuery = '';
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _maxUserLimitController = TextEditingController();
  String? _selectedSubscriptionTier;
  String? _selectedStatus;
  Map<String, dynamic> _metadata = {};

  // Stream subscriptions
  StreamSubscription<List<CompanyModel>>? _companiesSubscription;

  // Getters
  bool get loading => _loading;
  bool get saving => _saving;
  String get error => _error;
  Map<String, dynamic>? get currentUser => _currentUser;
  List<CompanyModel> get companies => _companies;
  List<CompanyModel> get filteredCompanies => _filteredCompanies;
  CompanyModel? get editingCompany => _editingCompany;
  String get searchQuery => _searchQuery;
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_filteredCompanies.length / _itemsPerPage).ceil();
  List<CompanyModel> get paginatedCompanies {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredCompanies.skip(startIndex).take(_itemsPerPage).toList();
  }
  
  // Set mounted state and process any stored data
  void setMounted(bool mounted) {
    _mounted = mounted;
    debugPrint('CompanyViewModel: setMounted called with mounted: $mounted');
    
    if (mounted && _companies.isNotEmpty) {
      debugPrint('CompanyViewModel: Widget mounted, processing stored ${_companies.length} companies');
      
      // Process the stored data that was received before widget was mounted
      _companies = _companies;
      _applySearchFilter();
      
      debugPrint('CompanyViewModel: Stored data processed, notifyListeners called');
      notifyListeners();
    }
  }

  // Form getters
  TextEditingController get nameController => _nameController;
  TextEditingController get addressController => _addressController;
  TextEditingController get contactController => _contactController;
  TextEditingController get maxUserLimitController => _maxUserLimitController;
  String? get selectedSubscriptionTier => _selectedSubscriptionTier;
  String? get selectedStatus => _selectedStatus;
  Map<String, dynamic> get metadata => _metadata;
  bool get mounted => _mounted;

  // Setters
  set selectedSubscriptionTier(String? value) {
    _selectedSubscriptionTier = value;
    notifyListeners();
  }

  set selectedStatus(String? value) {
    _selectedStatus = value;
    notifyListeners();
  }

  // Computed properties
  bool get canAdd => 
    PermissionHelper.getModulePermissionLevel(_currentUser, 'companies').contains('add') || 
    RoleUtils.isSuperAdmin(_currentUser);

  bool get canEdit => 
    PermissionHelper.getModulePermissionLevel(_currentUser, 'companies').contains('edit') || 
    RoleUtils.isSuperAdmin(_currentUser);

  bool get canDelete => 
    PermissionHelper.getModulePermissionLevel(_currentUser, 'companies').contains('delete') || 
    RoleUtils.isSuperAdmin(_currentUser);

  bool get isCurrentUserSuperAdmin => 
    RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);

  // Public sync method
  Future<void> syncFromFirestore() async {
    await _repository.syncCompaniesFromFirestore();
  }

  // Subscription tiers with static limits
  static const Map<String, int> _tierLimits = {
    'Starter': 5,
    'Professional': 15,
    'Enterprise': 50,
  };
  
  List<String> get subscriptionTiers => _tierLimits.keys.toList();
  List<String> get statuses => ['active', 'inactive', 'archived'];
  
  // Synchronous method to get user limit for tier
  int getUserLimitForTier(String? tier) {
    return _tierLimits[tier ?? 'Starter'] ?? 5;
  }

  // Initialization
  Future<void> initialize() async {
    try {
      _loading = true;
      _error = '';
      notifyListeners();
      
      await _loadCurrentUser().timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('CompanyViewModel: User loading timed out, using default');
        _currentUser = {'name': 'Unknown', 'email': 'unknown@example.com'};
      });
      
      await _repository.ensureCompanyTableColumns().timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('CompanyViewModel: Table columns check timed out');
      });
      
      // CRITICAL: Sync companies from Firestore before setting up streams
      debugPrint('CompanyViewModel: Starting Firestore sync...');
      await _repository.syncCompaniesFromFirestore();
      debugPrint('CompanyViewModel: Firestore sync completed');
      
      await _setupStreams().timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('CompanyViewModel: Stream setup timed out, setting loading to false');
        _loading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = 'Failed to initialize: $e';
      debugPrint('Error initializing CompanyViewModel: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings().timeout(const Duration(seconds: 3));
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        _currentUser = await AuthService.getCurrentUser(authToken).timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('CompanyViewModel: getCurrentUser timed out');
          return <String, dynamic>{'name': 'Unknown', 'email': 'unknown@example.com'};
        });
        AuthService.currentUser = _currentUser;
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
      // Set default user to prevent complete failure
      _currentUser = {'name': 'Unknown', 'email': 'unknown@example.com'};
    }
  }

  Future<void> _setupStreams() async {
    // Debug permission information
    debugPrint('CompanyViewModel: Current User Role: ${_currentUser?['permissions']}');
    debugPrint('CompanyViewModel: Current User Data: $_currentUser');
    debugPrint('CompanyViewModel: Is Super Admin: ${RoleUtils.isSuperAdmin(_currentUser)}');
    debugPrint('CompanyViewModel: Widget mounted state: $mounted');
    
    // Cancel existing subscription
    await _companiesSubscription?.cancel();
    
    debugPrint('CompanyViewModel: Setting up stream subscription...');
    
    // Setup new stream
    try {
      _companiesSubscription = _repository.watchCompanies().listen(
        (data) {
          debugPrint('CompanyViewModel: RAW STREAM DATA RECEIVED - ${data.length} companies');
          debugPrint('CompanyViewModel: Widget mounted state in stream: $mounted');
          
          // CRITICAL: Set loading to false when stream data arrives
          if (_loading) {
            _loading = false;
            debugPrint('CompanyViewModel: Loading set to false - stream data received');
          }
          
          // Process data immediately
          _companies = data;
          _applySearchFilter();
          
          debugPrint('CompanyViewModel: notifyListeners called');
          if (mounted) {
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('CompanyViewModel: STREAM ERROR - $e');
          if (_loading) {
            _loading = false;
            debugPrint('CompanyViewModel: Loading set to false - stream error');
          }
          if (mounted) {
            _error = 'Error loading companies: $e';
            debugPrint('CompanyViewModel: Stream error - $e');
            notifyListeners();
          }
        },
        onDone: () {
          debugPrint('CompanyViewModel: Stream completed');
        },
      );
      
      debugPrint('CompanyViewModel: Stream subscription setup complete');
    } catch (e) {
      debugPrint('CompanyViewModel: Error setting up streams: $e');
      _error = 'Failed to setup streams: $e';
      notifyListeners();
    }
  }

  // Search functionality
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredCompanies = List.from(_companies);
    } else {
      _filteredCompanies = _companies.where((company) {
        final name = company.name?.toLowerCase() ?? '';
        final address = company.address?.toLowerCase() ?? '';
        final contact = company.contact?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || address.contains(query) || contact.contains(query);
      }).toList();
    }
    // Reset to page 1 when filter changes
    _currentPage = 1;
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

  // Form operations
  void clearForm() {
    _nameController.clear();
    _addressController.clear();
    _contactController.clear();
    _maxUserLimitController.clear();
    _selectedSubscriptionTier = 'Starter';
    _selectedStatus = 'active';
    _metadata = {};
    _editingCompany = null;
    notifyListeners();
  }

  void editCompany(CompanyModel company) {
    _editingCompany = company;
    _nameController.text = company.name ?? '';
    _addressController.text = company.address ?? '';
    _contactController.text = company.contact ?? '';
    _maxUserLimitController.text = company.maxUserLimit?.toString() ?? '';
    _selectedSubscriptionTier = company.subscriptionTier ?? 'Starter';
    _selectedStatus = company.status ?? 'active';
    _metadata = company.metadata ?? {};
    notifyListeners();
  }

  Future<bool> saveCompany() async {
    if (!canAdd && !canEdit) {
      _error = 'Permission denied';
      notifyListeners();
      return false;
    }

    try {
      _saving = true;
      _error = '';
      notifyListeners();

      // Validation
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      final contact = _contactController.text.trim();
      final maxUserLimitText = _maxUserLimitController.text.trim();

      if (name.isEmpty) {
        _error = 'Company name is required';
        _saving = false;
        notifyListeners();
        return false;
      }

      if (name.length < 2) {
        _error = 'Company name must be at least 2 characters';
        _saving = false;
        notifyListeners();
        return false;
      }

      int? maxUserLimit;
      if (maxUserLimitText.isNotEmpty) {
        maxUserLimit = int.tryParse(maxUserLimitText);
        if (maxUserLimit == null || maxUserLimit < 1) {
          _error = 'Invalid user limit';
          _saving = false;
          notifyListeners();
          return false;
        }
      }

      // Check if company name is unique
      final isUnique = await _repository.isCompanyNameUnique(name, excludeCompanyId: _editingCompany?.id);
      if (!isUnique) {
        _error = 'Company name already exists';
        _saving = false;
        notifyListeners();
        return false;
      }

      // Set default user limit based on subscription tier if not provided
      if (maxUserLimit == null) {
        maxUserLimit = getUserLimitForTier(_selectedSubscriptionTier);
      }

      // Create or update company
      final company = CompanyModel(
        id: _editingCompany?.id ?? const Uuid().v4(),
        name: name,
        address: address.isEmpty ? null : address,
        contact: contact.isEmpty ? null : contact,
        maxUserLimit: maxUserLimit,
        subscriptionTier: _selectedSubscriptionTier ?? 'Starter',
        status: _selectedStatus ?? 'active',
        metadata: _metadata.isNotEmpty ? _metadata : null,
        isActive: _selectedStatus != 'archived',
        createdAt: _editingCompany?.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (_editingCompany == null) {
        await _repository.addCompany(company);
      } else {
        await _repository.updateCompany(company);
      }

      clearForm();
      return true;
    } catch (e) {
      _error = 'Failed to save company: $e';
      debugPrint('Error saving company: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCompany(String id) async {
    if (!canDelete) {
      _error = 'Permission denied';
      notifyListeners();
      return false;
    }

    try {
      await _repository.deleteCompany(id);
      return true;
    } catch (e) {
      _error = 'Failed to delete company: $e';
      debugPrint('Error deleting company: $e');
      return false;
    }
  }

  Future<bool> toggleCompanyStatus(String id, String newStatus) async {
    if (!canEdit) {
      _error = 'Permission denied';
      notifyListeners();
      return false;
    }

    try {
      final company = await _repository.getCompanyById(id);
      if (company != null) {
        if (newStatus == 'active') {
          await _repository.activateCompany(id);
        } else if (newStatus == 'inactive') {
          await _repository.deactivateCompany(id);
        } else if (newStatus == 'archived') {
          await _repository.archiveCompany(id);
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to update company status: $e';
      debugPrint('Error updating company status: $e');
      return false;
    }
  }

  // User limit management
  Future<bool> canAddMoreUsers(String companyId) async {
    try {
      return await _repository.canAddMoreUsers(companyId);
    } catch (e) {
      debugPrint('Error checking user limit: $e');
      return false;
    }
  }

  Future<int> getCurrentUserCount(String companyId) async {
    try {
      return await _repository.getCurrentUserCount(companyId);
    } catch (e) {
      debugPrint('Error getting user count: $e');
      return 0;
    }
  }

  Future<int> getMaxUserLimit(String companyId) async {
    try {
      return await _repository.getMaxUserLimit(companyId);
    } catch (e) {
      debugPrint('Error getting max user limit: $e');
      return 5;
    }
  }

  Future<void> updateUserLimit(String companyId, int newLimit) async {
    try {
      await _repository.updateUserLimit(companyId, newLimit);
    } catch (e) {
      _error = 'Failed to update user limit: $e';
      debugPrint('Error updating user limit: $e');
      notifyListeners();
    }
  }

  // Subscription management
  Future<void> updateSubscriptionTier(String companyId, String tier) async {
    try {
      await _repository.updateSubscriptionTier(companyId, tier);
      
      // Update user limit based on new tier
      final newLimit = getUserLimitForTier(tier);
      await updateUserLimit(companyId, newLimit);
    } catch (e) {
      _error = 'Failed to update subscription tier: $e';
      debugPrint('Error updating subscription tier: $e');
      notifyListeners();
    }
  }

  // Metadata management
  void updateMetadata(String key, String value) {
    _metadata[key] = value;
    notifyListeners();
  }

  void clearMetadata() {
    _metadata = {};
    notifyListeners();
  }

  // Statistics
  Future<Map<String, dynamic>> getCompanyStatistics() async {
    return await _repository.getCompanyStatistics();
  }

  Future<Map<String, dynamic>> getCompanyStatisticsById(String companyId) async {
    return await _repository.getCompanyStatisticsById(companyId);
  }

  // Utility methods
  void refreshData() {
    _setupStreams();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mounted = false;
    _companiesSubscription?.cancel();
    
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _maxUserLimitController.dispose();
    
    super.dispose();
  }
}
