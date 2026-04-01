import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared/src/auth/role_utils.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_repository_impl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/app_utils.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;

class UserViewModel extends ChangeNotifier {
  final UserRepository _repository;
  bool _mounted = false;
  bool _isDisposed = false; // CRITICAL: Prevent disposed crashes

  UserViewModel(this._repository);

  // State
  bool _loading = true;
  bool _saving = false;
  String _error = '';
  Map<String, dynamic>? _currentUser;
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  UserModel? _editingUser;
  List<Map<String, String>> _companies = [];
  String _searchQuery = '';
  bool _backfillingUserIds = false;
  bool _backfillUserIdsDone = false;
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  // Filter state
  String? _selectedCompanyId;
  String? _selectedStatus;
  String? _selectedRole;
  String? _filterCompanyId;
  String? _filterStatus;
  String? _filterRole;
  Map<String, dynamic> _permissions = {};

  // Stream subscriptions
  StreamSubscription<List<UserModel>>? _usersSubscription;

  // Getters
  bool get loading => _loading;
  bool get saving => _saving;
  String get error => _error;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get _currentUserCompanyId => _currentUser?['company_id']?.toString();
  List<UserModel> get users => _users;
  List<UserModel> get filteredUsers => _filteredUsers;
  UserModel? get editingUser => _editingUser;
  List<Map<String, String>> get companies => _companies;
  String get searchQuery => _searchQuery;
  bool get backfillingUserIds => _backfillingUserIds;
  bool get backfillUserIdsDone => _backfillUserIdsDone;
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_filteredUsers.length / _itemsPerPage).ceil();
  List<UserModel> get paginatedUsers {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredUsers.skip(startIndex).take(_itemsPerPage).toList();
  }

  // Set mounted state and process any stored data
  void setMounted(bool mounted) {
    _mounted = mounted;
    debugPrint('UserViewModel: setMounted called with mounted: $mounted');
    
    if (mounted && _users.isNotEmpty) {
      debugPrint('UserViewModel: Widget mounted, processing stored ${_users.length} users');
      
      // Process the stored data that was received before widget was mounted
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final effectiveCompanyId = RoleUtils.getUserCompanyId(_currentUser);
      
      debugPrint('UserViewModel: Processing stored data - isSuperAdmin=$isSuperAdmin, effectiveCompanyId=$effectiveCompanyId');
      
      List<UserModel> filteredData = _users;
      if (!isSuperAdmin && effectiveCompanyId != null) {
        filteredData = _users.where((user) => user.companyId == effectiveCompanyId).toList();
        debugPrint('UserViewModel: Filtered stored data to ${filteredData.length} users for company $effectiveCompanyId');
      }
      
      _users = filteredData;
      _applySearchFilter();
      
      debugPrint('UserViewModel: Stored data processed, notifyListeners called');
      notifyListeners();
    }
  }

  // Form getters
  TextEditingController get nameController => _nameController;
  TextEditingController get emailController => _emailController;
  TextEditingController get contactController => _contactController;
  TextEditingController get usernameController => _usernameController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get confirmPasswordController => _confirmPasswordController;
  TextEditingController get userIdController => _userIdController;
  String? get selectedCompanyId => _selectedCompanyId;
  String? get selectedStatus => _selectedStatus;
  String? get selectedRole => _selectedRole;
  String? get filterCompanyId => _filterCompanyId;
  String? get filterStatus => _filterStatus;
  String? get filterRole => _filterRole;
  Map<String, dynamic> get permissions => _permissions;
  bool get mounted => _mounted;

  // Setters for form state
  set selectedCompanyId(String? value) {
    _selectedCompanyId = value;
    notifyListeners();
  }

  set selectedStatus(String? value) {
    _selectedStatus = value;
    notifyListeners();
  }

  set selectedRole(String? value) {
    _selectedRole = value;
    notifyListeners();
  }

  // Setters for filter state
  set filterCompanyId(String? value) {
    _filterCompanyId = value;
    _applyMultiCriteriaFilters();
  }

  set filterStatus(String? value) {
    _filterStatus = value;
    _applyMultiCriteriaFilters();
  }

  set filterRole(String? value) {
    _filterRole = value;
    _applyMultiCriteriaFilters();
  }

  // Computed properties
  bool get canAdd => 
    PermissionHelper.getModulePermissionLevel(_currentUser, 'users').contains('add') || 
    RoleUtils.isCompanyAdmin(_currentUser) ||
    RoleUtils.isSuperAdmin(_currentUser);

  bool get canEdit => 
    PermissionHelper.getModulePermissionLevel(_currentUser, 'users').contains('edit') || 
    RoleUtils.isCompanyAdmin(_currentUser) ||
    RoleUtils.isSuperAdmin(_currentUser);

  bool get canDelete => 
    PermissionHelper.getModulePermissionLevel(_currentUser, 'users').contains('delete') || 
    RoleUtils.isCompanyAdmin(_currentUser) ||
    RoleUtils.isSuperAdmin(_currentUser);

  // Helper method to check if current user is Super Admin
  bool get isCurrentUserSuperAdmin => 
    RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);

  // Public sync method
  Future<void> syncFromFirestore() async {
    await _repository.syncUsersFromFirestore();
  }

  // Edit user functionality
  void setEditingUser(UserModel user) {
    _editingUser = user;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _contactController.text = user.contactNo ?? '';
    notifyListeners();
  }

  Future<void> updateUser() async {
    if (_editingUser == null) return;
    
    try {
      _saving = true;
      notifyListeners();
      
      final updatedUser = _editingUser!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        contactNo: _contactController.text.trim(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      await _repository.updateUser(updatedUser);
      
      // Clear editing state
      _editingUser = null;
      _nameController.clear();
      _emailController.clear();
      _contactController.clear();
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update user: $e';
      notifyListeners();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> updateUserPassword(String newPassword) async {
    if (_editingUser == null) return;
    
    try {
      _saving = true;
      notifyListeners();
      
      await _repository.updateUserPassword(_editingUser!.id, newPassword);
      
      // Clear editing state
      _editingUser = null;
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update password: $e';
      notifyListeners();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> assignRole(String role, Map<String, bool> selectedModules) async {
    if (_editingUser == null) return;
    
    try {
      _saving = true;
      notifyListeners();
      
      debugPrint('UserViewModel: Starting role assignment for user ${_editingUser!.id} to role: $role');
      debugPrint('UserViewModel: Selected modules: $selectedModules');
      
      // CRITICAL FIX: Use new dedicated updateUserRole method with dynamic permissions
      await _repository.updateUserRole(_editingUser!.id, role.toLowerCase(), selectedModules);
      
      debugPrint('UserViewModel: Role assignment completed successfully');
      
      // ✨ CRITICAL FIX: Update local user data immediately for instant UI update ✨
      final userIndex = _users.indexWhere((user) => user.id == _editingUser!.id);
      if (userIndex != -1) {
        // Generate the new permissions that were saved to database
        Map<String, dynamic> dynamicPermissionsMap = {};
        selectedModules.forEach((key, isSelected) {
          if (isSelected) {
            // Assign view_add_edit or full_access depending on the base role
            dynamicPermissionsMap[key] = (role.toLowerCase() == 'company_admin') ? 'full_access' : 'view_add_edit';
          }
        });
        
        final updatedPerms = {
          'role': role.toLowerCase(),
          'permission': (role.toLowerCase() == 'company_admin') ? 'full_access' : 'custom',
          'canDelete': (role.toLowerCase() == 'company_admin'),
          'permissionsMap': dynamicPermissionsMap
        };
        
        // Create updated user model with new role and permissions
        final updatedUser = _users[userIndex].copyWith(
          permissions: jsonEncode(updatedPerms),
          updatedAt: DateTime.now().toIso8601String(),
        );
        
        // Update local list immediately
        _users[userIndex] = updatedUser;
        _applySearchFilter(); // Update filtered list too
        
        debugPrint('UserViewModel: Updated local user data for immediate UI update');
        debugPrint('UserViewModel: New role for user ${_editingUser!.name}: ${updatedUser.role}');
      }
      
      // Notify listeners to trigger immediate UI rebuild
      notifyListeners();
      
      // Clear editing state
      _editingUser = null;
      
    } catch (e) {
      debugPrint('UserViewModel: Error in assignRole: $e');
      _error = 'Failed to assign role: $e';
      notifyListeners();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // Helper method to force refresh users list
  Future<void> _loadUsersFromRepository() async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      _users = await _repository.getUsers(companyId);
      _applySearchFilter();
      debugPrint('UserViewModel: Force refreshed ${_users.length} users');
    } catch (e) {
      debugPrint('Error force refreshing users: $e');
    }
  }

  Future<void> archiveUser(String userId) async {
    try {
      await _repository.archiveUser(userId);
    } catch (e) {
      _error = 'Failed to archive user: $e';
      notifyListeners();
    }
  }

  void clearEditingUser() {
    _editingUser = null;
    _nameController.clear();
    _emailController.clear();
    _contactController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _userIdController.clear();
    _selectedCompanyId = null;
    _selectedStatus = null;
    _selectedRole = null;
    notifyListeners();
  }

  // Initialization
  Future<void> initialize() async {
    try {
      _loading = true;
      _error = '';
      notifyListeners();
      
      await _loadCurrentUser();
      await _repository.ensureUserTableColumns();
      
      // CRITICAL: Sync users from Firestore before loading companies
      debugPrint('UserViewModel: Starting Firestore sync...');
      await _repository.syncUsersFromFirestore();
      debugPrint('UserViewModel: Firestore sync completed');
      
      await _loadCompanies();
      await _setupStreams();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      debugPrint('Error initializing UserViewModel: $e');
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

  Future<void> _loadCompanies() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      // For now, load companies directly. In a full implementation, 
      // this would use CompanyRepository
      final db = AppDatabase.instanceIfInitialized;
      if (db != null) {
        final result = await db.customSelect(
          isSuperAdmin
              ? 'SELECT id, name FROM companies WHERE (is_active = 1 OR is_active IS NULL) ORDER BY name'
              : 'SELECT id, name FROM companies WHERE id = ? AND (is_active = 1 OR is_active IS NULL) ORDER BY name',
          variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
        ).get();
        
        _companies = result.map((r) => {
          'id': r.data['id'].toString(),
          'name': r.data['name'].toString(),
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading companies: $e');
    }
  }

  Future<void> _setupStreams() async {
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    
    // CRITICAL DEBUG: Log company filtering for Umer Shahzad
    if (_currentUser?['email']?.toString().toLowerCase() == 'umershahzad596@gmail.com') {
      debugPrint('USER VIEW MODEL DEBUG: Umer Shahzad setting up streams');
      debugPrint('USER VIEW MODEL DEBUG: Company ID: $companyId');
      debugPrint('USER VIEW MODEL DEBUG: User role: ${RoleUtils.getUserRole(_currentUser)}');
      debugPrint('USER VIEW MODEL DEBUG: isCompanyAdmin: ${RoleUtils.isCompanyAdmin(_currentUser)}');
      debugPrint('USER VIEW MODEL DEBUG: isSuperAdmin: ${RoleUtils.isSuperAdmin(_currentUser)}');
    }
    
    // Cancel existing subscription
    await _usersSubscription?.cancel();
    
    // Setup new stream
    _usersSubscription = _repository.watchUsers(companyId).listen(
      (data) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          // CRITICAL: Set loading to false when stream data arrives
          if (_loading) {
            _loading = false;
            debugPrint('UserViewModel: Loading set to false - stream data received');
          }
          
          // CRITICAL DEBUG: Log user filtering results for Umer Shahzad
          if (_currentUser?['email']?.toString().toLowerCase() == 'umershahzad596@gmail.com') {
            debugPrint('USER VIEW MODEL DEBUG: Stream update received for Umer Shahzad');
            debugPrint('USER VIEW MODEL DEBUG: Total users loaded: ${data.length}');
            for (int i = 0; i < data.length && i < 5; i++) {
              final user = data[i];
              debugPrint('USER VIEW MODEL DEBUG: User ${i + 1}: ${user.name} (${user.email}) - Company: ${user.companyId}');
            }
            if (data.length > 5) {
              debugPrint('USER VIEW MODEL DEBUG: ... and ${data.length - 5} more users');
            }
          }
          
          _users = data;
          _applySearchFilter();
          
          debugPrint('UserViewModel: notifyListeners called - stream data processed');
          notifyListeners();
        });
      },
      onError: (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_loading) {
            _loading = false;
            debugPrint('UserViewModel: Loading set to false - stream error');
          }
          _error = 'Error loading users: $e';
          debugPrint('UserViewModel: Stream error - $e');
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
      _filteredUsers = List.from(_users);
    } else {
      _filteredUsers = _users.where((user) {
        final name = user.name.toLowerCase();
        final email = user.email.toLowerCase();
        final username = user.username.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query) || username.contains(query);
      }).toList();
    }
    // Apply additional filters after search
    _applyMultiCriteriaFilters();
  }
  
  // ✨ NEW: Multi-criteria filtering method
  void _applyMultiCriteriaFilters() {
    List<UserModel> sourceList = _searchQuery.isEmpty ? List.from(_users) : List.from(_filteredUsers);
    
    // Apply company filter (if not 'All')
    if (_filterCompanyId != null && _filterCompanyId!.isNotEmpty) {
      sourceList = sourceList.where((user) => user.companyId == _filterCompanyId).toList();
    }
    
    // Apply role filter (if not 'All')
    if (_filterRole != null && _filterRole!.isNotEmpty) {
      sourceList = sourceList.where((user) => user.role == _filterRole).toList();
    }
    
    // Apply status filter (if not 'All')
    if (_filterStatus != null && _filterStatus!.isNotEmpty) {
      if (_filterStatus == 'active') {
        sourceList = sourceList.where((user) => user.isActive).toList();
      } else if (_filterStatus == 'inactive') {
        sourceList = sourceList.where((user) => !user.isActive).toList();
      } else if (_filterStatus == 'archived') {
        sourceList = sourceList.where((user) => user.status == 'archived').toList();
      }
    }
    
    _filteredUsers = sourceList;
    // Reset to page 1 when filter changes
    _currentPage = 1;
    notifyListeners();
  }
  
  // ✨ NEW: Public method to apply all filters at once
  void applyFilters(String? companyId, String? role, String? status) {
    _filterCompanyId = companyId;
    _filterRole = role;
    _filterStatus = status;
    _applyMultiCriteriaFilters();
  }
  
  // ✨ NEW: Clear all filters
  void clearAllFilters() {
    _filterCompanyId = null;
    _filterRole = null;
    _filterStatus = null;
    _searchQuery = '';
    _applySearchFilter();
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
    _emailController.clear();
    _contactController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _userIdController.clear();
    _selectedCompanyId = null;
    _selectedStatus = 'active';
    _selectedRole = null;
    _permissions = {};
    _editingUser = null;
    notifyListeners();
  }

  void editUser(UserModel user) {
    _editingUser = user;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _contactController.text = user.contactNo ?? '';
    _usernameController.text = user.username;
    _userIdController.text = user.userId;
    
    // CRITICAL FIX: Handle GLOBAL_ADMIN company ID properly
    if (user.companyId == 'GLOBAL_ADMIN' || user.companyId == null) {
      _selectedCompanyId = null; // Set to null for Super Admins
    } else {
      _selectedCompanyId = user.companyId;
    }
    
    _selectedStatus = user.status ?? 'active';
    _selectedRole = _getUserRoleFromPermissions(user.permissionsMap);
    _permissions = user.permissionsMap; // Use permissionsMap getter
    notifyListeners();
  }

  Future<bool> saveUser() async {
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
      final email = _emailController.text.trim();
      final contact = _contactController.text.trim();
      final userId = _userIdController.text.trim();

      if (name.isEmpty) {
        _error = 'Name is required';
        _saving = false;
        notifyListeners();
        return false;
      }

      if (email.isEmpty) {
        _error = 'Email is required';
        _saving = false;
        notifyListeners();
        return false;
      }

      if (!_isValidEmail(email)) {
        _error = 'Invalid email format';
        _saving = false;
        notifyListeners();
        return false;
      }

      if (_selectedRole == null) {
        _error = 'Role is required';
        _saving = false;
        notifyListeners();
        return false;
      }

      if (_selectedCompanyId == null) {
        _error = 'Company is required';
        _saving = false;
        notifyListeners();
        return false;
      }

      // For new users, check password
      if (_editingUser == null) {
        final password = _passwordController.text;

        if (password.isEmpty) {
          _error = 'Password is required';
          _saving = false;
          notifyListeners();
          return false;
        }

        if (password.length < 6) {
          _error = 'Password must be at least 6 characters';
          _saving = false;
          notifyListeners();
          return false;
        }
      }

      // Check if email is unique
      final existingUser = await _repository.getUserByEmail(email);
      if (existingUser != null && existingUser.id != _editingUser?.id) {
        _error = 'Email already exists';
        _saving = false;
        notifyListeners();
        return false;
      }

      // Generate user ID if not provided
      String finalUserId = userId;
      if (finalUserId.isEmpty) {
        finalUserId = await _repository.generateUniqueUserId(_selectedCompanyId!);
      } else {
        // Check if user ID is unique
        final isUnique = await _repository.isUserIdUnique(_selectedCompanyId!, finalUserId, excludeUserId: _editingUser?.id);
        if (!isUnique) {
          _error = 'User ID already exists';
          _saving = false;
          notifyListeners();
          return false;
        }
      }

      // Set permissions based on selected role
      Map<String, dynamic> newPermissions = {};
      if (_selectedRole != null) {
        switch (_selectedRole!.toLowerCase()) {
          case 'super_admin':
            newPermissions['super_admin'] = true;
            break;
          case 'company_admin':
            newPermissions['company_admin'] = true;
            break;
          case 'agent':
            newPermissions['agent'] = true;
            break;
        }
      }

      // Create or update user
      final user = UserModel(
        id: _editingUser?.id ?? const Uuid().v4(),
        username: email.split('@')[0], // Use email prefix as username
        userId: finalUserId,
        name: name,
        email: email,
        contactNo: contact.isEmpty ? null : contact,
        permissions: newPermissions.isNotEmpty ? jsonEncode(newPermissions) : null,
        companyId: _selectedCompanyId,
        status: _selectedStatus,
        isActive: _selectedStatus != 'archived',
        isFirstLogin: _editingUser?.isFirstLogin ?? true,
        createdAt: _editingUser?.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (_editingUser == null) {
        await _repository.addUser(user);
      } else {
        await _repository.updateUser(user);
      }

      clearForm();
      return true;
    } catch (e) {
      _error = 'Failed to save user: $e';
      debugPrint('Error saving user: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String id) async {
    if (!canDelete) {
      _error = 'Permission denied';
      notifyListeners();
      return false;
    }

    try {
      await _repository.deleteUser(id);
      return true;
    } catch (e) {
      _error = 'Failed to delete user: $e';
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  Future<bool> toggleUserStatus(String id, String newStatus) async {
    if (!canEdit) {
      _error = 'Permission denied';
      notifyListeners();
      return false;
    }

    try {
      final user = await _repository.getUserById(id);
      if (user != null) {
        final updatedUser = user.copyWith(
          status: newStatus,
          isActive: newStatus != 'archived',
          updatedAt: DateTime.now().toIso8601String(),
        );
        await _repository.updateUser(updatedUser);
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to update user status: $e';
      debugPrint('Error updating user status: $e');
      return false;
    }
  }

  Future<bool> toggleUserActiveStatus(String id, bool newActiveStatus) async {
    if (!canEdit) {
      _error = 'Permission denied';
      notifyListeners();
      return false;
    }

    try {
      final user = await _repository.getUserById(id);
      if (user != null) {
        final updatedUser = user.copyWith(
          isActive: newActiveStatus,
          status: newActiveStatus ? 'active' : 'inactive',
          updatedAt: DateTime.now().toIso8601String(),
        );
        await _repository.updateUser(updatedUser);
        
        // CRITICAL: Notify listeners immediately for UI update
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to toggle user active status: $e';
      notifyListeners();
      return false;
    }
  }

  // User ID management
  Future<void> backfillUserIds() async {
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (companyId == null) return;

    try {
      _backfillingUserIds = true;
      notifyListeners();

      await _repository.backfillUserIds(companyId);
      _backfillUserIdsDone = true;
    } catch (e) {
      _error = 'Failed to backfill user IDs: $e';
      debugPrint('Error backfilling user IDs: $e');
    } finally {
      _backfillingUserIds = false;
      notifyListeners();
    }
  }

  // Permission management
  void updatePermission(String module, String value) {
    _permissions[module] = value;
    notifyListeners();
  }

  void clearPermissions() {
    _permissions = {};
    notifyListeners();
  }

  // Statistics
  Future<Map<String, dynamic>> getUserStatistics() async {
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    return await _repository.getUserStatistics(companyId);
  }

  // Utility methods
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // Helper method to extract role from permissions
  String _getUserRoleFromPermissions(Map<String, dynamic> permissions) {
    if (permissions['super_admin'] == true) return 'super_admin';
    if (permissions['company_admin'] == true) return 'company_admin';
    if (permissions['agent'] == true) return 'agent';
    return '';
  }

  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final users = await _repository.getUsers(null);
      return users.firstWhere(
        (user) => user.username.toLowerCase() == username.toLowerCase(),
        orElse: () => UserModel.empty(),
      );
    } catch (e) {
      debugPrint('Error getting user by username: $e');
      return null;
    }
  }

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
    _usersSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _userIdController.dispose();
    
    super.dispose();
  }
}
