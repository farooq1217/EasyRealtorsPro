import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/company_model.dart';
import '../../domain/repositories/company_repository.dart';
import '../../data/repositories/company_repository_impl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/permission_helper.dart';
import '../../core/app_utils.dart';
import 'package:shared/src/auth/role_utils.dart';

class CompanyViewModel extends ChangeNotifier {
  final CompanyRepository _repository;
  bool _mounted = false;
  
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

  // Subscription tiers
  List<String> get subscriptionTiers => ['Starter', 'Professional', 'Enterprise'];
  List<String> get statuses => ['active', 'inactive', 'archived'];

  // Initialization
  Future<void> initialize() async {
    try {
      _loading = true;
      _error = '';
      notifyListeners();
      
      await _loadCurrentUser();
      await _repository.ensureCompanyTableColumns();
      await _setupStreams();
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
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        final authService = AuthService();
        _currentUser = await authService.getCurrentUser(authToken);
        AuthService.currentUser = _currentUser;
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _setupStreams() async {
    // Cancel existing subscription
    await _companiesSubscription?.cancel();
    
    // Setup new stream
    _companiesSubscription = _repository.watchCompanies().listen(
      (data) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _companies = data;
          _applySearchFilter();
        });
      },
      onError: (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _error = 'Error loading companies: $e';
          notifyListeners();
        });
      },
    );
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
        final name = company.name.toLowerCase();
        final address = company.address?.toLowerCase() ?? '';
        final contact = company.contact?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || address.contains(query) || contact.contains(query);
      }).toList();
    }
    notifyListeners();
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
    _nameController.text = company.name;
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
        maxUserLimit = await getUserLimitForTier(_selectedSubscriptionTier);
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
      final newLimit = await _repository.getUserLimitForTier(tier);
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
  Future<int> getUserLimitForTier(String? tier) async {
    try {
      return await _repository.getUserLimitForTier(tier ?? 'Starter');
    } catch (e) {
      debugPrint('Error getting user limit for tier: $e');
      return 5;
    }
  }

  void refreshData() {
    _setupStreams();
  }

  @override
  void dispose() {
    _mounted = false;
    _companiesSubscription?.cancel();
    
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _maxUserLimitController.dispose();
    
    super.dispose();
  }
}
