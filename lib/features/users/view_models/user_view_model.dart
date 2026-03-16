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

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  String? _selectedCompanyId;
  String? _selectedStatus;
  Map<String, dynamic> _permissions = {};

  // Stream subscriptions
  StreamSubscription<List<UserModel>>? _usersSubscription;

  // Getters
  bool get loading => _loading;
  bool get saving => _saving;
  String get error => _error;
  Map<String, dynamic>? get currentUser => _currentUser;
  List<UserModel> get users => _users;
  List<UserModel> get filteredUsers => _filteredUsers;
  UserModel? get editingUser => _editingUser;
  List<Map<String, String>> get companies => _companies;
  String get searchQuery => _searchQuery;
  bool get backfillingUserIds => _backfillingUserIds;
  bool get backfillUserIdsDone => _backfillUserIdsDone;

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
  Map<String, dynamic> get permissions => _permissions;
  bool get mounted => _mounted;

  // Setters
  set selectedCompanyId(String? value) {
    _selectedCompanyId = value;
    notifyListeners();
  }

  set selectedStatus(String? value) {
    _selectedStatus = value;
    notifyListeners();
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

  // Initialization
  Future<void> initialize() async {
    try {
      _loading = true;
      _error = '';
      notifyListeners();
      
      await _loadCurrentUser();
      await _repository.ensureUserTableColumns();
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
        });
      },
      onError: (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _error = 'Error loading users: $e';
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
    notifyListeners();
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
      final username = _usernameController.text.trim();
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

      if (username.isEmpty) {
        _error = 'Username is required';
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
        final confirmPassword = _confirmPasswordController.text;

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

        if (password != confirmPassword) {
          _error = 'Passwords do not match';
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

      // Check if username is unique
      final existingUsername = await _repository.getUserByUsername(username);
      if (existingUsername != null && existingUsername.id != _editingUser?.id) {
        _error = 'Username already exists';
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

      // Create or update user
      final user = UserModel(
        id: _editingUser?.id ?? const Uuid().v4(),
        username: username,
        userId: finalUserId,
        name: name,
        email: email,
        contactNo: contact.isEmpty ? null : contact,
        permissions: _permissions.isNotEmpty ? jsonEncode(_permissions) : null,
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
  void dispose() {
    _mounted = false;
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
