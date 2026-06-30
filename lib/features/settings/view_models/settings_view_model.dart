// presentation/view_models/settings_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';
import '../repositories/settings_repository_impl.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../core/windows_platform_fix.dart';
import '../../../core/services/society_event_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repository; // ✅ Fixed: Use _repository consistently
  
  // Initialization guard to prevent duplicates
  static bool _isInitializing = false;
  
  SettingsViewModel(this._repository); // ✅ Constructor injects _repository

  // State
  Map<String, dynamic>? _currentUser;
  String? _profileImagePath;
  List<Map<String, dynamic>> _societies = [];
  List<Map<String, dynamic>> _blocks = [];
  String? _selectedSocietyId;
  bool _loading = true;
  bool _savingProfile = false;
  bool _isLoadingBlocks = false;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get profileImagePath => _profileImagePath;
  List<Map<String, dynamic>> get societies => _societies;
  List<Map<String, dynamic>> get blocks => _blocks;
  String? get selectedSocietyId => _selectedSocietyId;
  bool get loading => _loading;
  bool get savingProfile => _savingProfile;
  bool get isLoadingBlocks => _isLoadingBlocks;

  // CRITICAL FIX: Emergency method to force loading state to false
  void forceLoadingComplete() {
    if (_loading) {
      debugPrint('SettingsViewModel: Forcefully setting loading to false');
      _loading = false;
      safeNotifyListeners();
    }
  }
  
  // ✨ CRITICAL FIX: Safe notifyListeners for Windows compatibility
  void safeNotifyListeners() {
    if (WindowsPlatformFix.isWindows) {
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('SettingsViewModel: notifyListeners error on Windows: $e');
        WindowsPlatformFix.handleConnectionLossError(e, null);
      }
    } else {
      notifyListeners();
    }
  }

 // ✅ FIXED: Society create method with event emission
Future<void> createSociety(String name) async {
  try {
    _loading = true;
    safeNotifyListeners();
    
    // ✅ FIXED: addSociety void return karta hai, directly call karein
    await _repository.addSociety(name);
    
    // ✅ FIXED: Pehle societies reload karein
    await _loadSocieties();
    
    // ✅ FIXED: Ab latest society ko find karein (jo abhi add hui)
    if (_societies.isNotEmpty) {
      // Last society ko get karein (assuming it's the newest)
      final newSociety = _societies.last;
      
      // ✅ Event emit karein with actual data
      SocietyEventService().notifySocietyCreated({
        'id': newSociety['id']?.toString() ?? '',
        'name': newSociety['name']?.toString() ?? name,
      });
      
      debugPrint('SettingsViewModel: Society created and event emitted - ID: ${newSociety['id']}, Name: ${newSociety['name']}');
    }
    
    _loading = false;
    safeNotifyListeners();
  } catch (e) {
    debugPrint('Error creating society: $e');
    _loading = false;
    safeNotifyListeners();
    rethrow;
  }
}
  // Initialize
  Future<void> initialize() async {
    if (_isInitializing) {
      debugPrint('SettingsViewModel: Already initializing, skipping duplicate call');
      return;
    }
    
    WindowsPlatformFix.initialize();
    debugPrint('SettingsViewModel: Starting initialization');
    
    _isInitializing = true;
    _loading = true;
    safeNotifyListeners();
    
    try {
      debugPrint('SettingsViewModel: Loading current user and societies in parallel');
      await Future.wait([
        _loadCurrentUser().timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('SettingsViewModel: Current user loading timed out');
          _currentUser = {'name': 'Unknown', 'email': 'unknown@example.com', 'role': 'user'};
        }),
        _loadSocieties().timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('SettingsViewModel: Societies loading timed out');
          _societies = [];
        }),
      ]);
      
      if (_currentUser != null) {
        final detectedRole = _currentUser!['role']?.toString().toLowerCase();
        debugPrint('SettingsViewModel: ROLE SYNC FIX - User role detected: $detectedRole');
        
        if (detectedRole == null || detectedRole.isEmpty) {
          final roleFromUtils = _getUserRoleFromUtils();
          if (roleFromUtils.isNotEmpty) {
            _currentUser!['role'] = roleFromUtils;
            debugPrint('SettingsViewModel: ROLE SYNC FIX - Updated role from utils: $roleFromUtils');
          }
        }
      }
      
      debugPrint('SettingsViewModel: User and societies loaded, loading blocks if needed');
      
      if (_selectedSocietyId != null) {
        await _loadBlocksForSociety(_selectedSocietyId!).timeout(const Duration(seconds: 2), onTimeout: () {
          debugPrint('SettingsViewModel: Blocks loading timed out');
          _blocks = [];
        });
      }
      
      debugPrint('SettingsViewModel: Initialization completed successfully');
    } catch (e) {
      debugPrint('Settings initialization error: $e');
    } finally {
      _loading = false;
      _isInitializing = false;
      debugPrint('SettingsViewModel: Loading set to false, notifying listeners');
      safeNotifyListeners();
    }
  }

  // User profile methods
  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await _repository.getCurrentUser().timeout(const Duration(seconds: 3));
      
      if (_currentUser != null) {
        _profileImagePath = _currentUser!['profile_picture_path']?.toString();
        
        final detectedRole = _currentUser!['role']?.toString().toLowerCase();
        debugPrint('SettingsViewModel._loadCurrentUser: Raw role from repository: $detectedRole');
        
        if (detectedRole == null || detectedRole.isEmpty) {
          final roleFromUtils = _getUserRoleFromUtils();
          if (roleFromUtils.isNotEmpty) {
            _currentUser!['role'] = roleFromUtils;
            debugPrint('SettingsViewModel._loadCurrentUser: ROLE SYNC FIX - Set role from utils: $roleFromUtils');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
      _currentUser = {'name': 'Unknown', 'email': 'unknown@example.com', 'role': 'user'};
    }
  }
  
  String _getUserRoleFromUtils() {
    try {
      final role = _currentUser!['role']?.toString() ?? '';
      if (role.isNotEmpty) return role;
      
      final permissionsRaw = _currentUser!['permissions'];
      if (permissionsRaw != null) {
        if (permissionsRaw is String) {
          try {
            final permissions = Map<String, dynamic>.from(
              Uri.splitQueryString(permissionsRaw)
            );
            return permissions['role']?.toString() ?? '';
          } catch (e) {
            debugPrint('SettingsViewModel: Error parsing permissions: $e');
          }
        } else if (permissionsRaw is Map) {
          return permissionsRaw['role']?.toString() ?? '';
        }
      }
    } catch (e) {
      debugPrint('SettingsViewModel._getUserRoleFromUtils: Error: $e');
    }
    return '';
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String companyName,
    String? profilePicturePath,
  }) async {
    if (_currentUser == null) return;

    _savingProfile = true;
    safeNotifyListeners();

    try {
      final emailKey = (_currentUser!['email'] ?? _currentUser!['username'] ?? '').toString().toLowerCase();
      final userIdRaw = (_currentUser!['id'] ?? _currentUser!['user_uid'] ?? _currentUser!['userId'] ?? _currentUser!['user_id']);
      final userId = (userIdRaw == null || userIdRaw.toString().isEmpty) ? emailKey : userIdRaw.toString();

      await _repository.updateProfile({
        'name': name,
        'phone': phone,
        'companyName': companyName,
        'profilePicturePath': profilePicturePath,
        'email': emailKey,
        'userId': userId,
        'permissions': _currentUser!['permissions'],
        'status': _currentUser!['status'],
        'created_at': _currentUser!['created_at'],
      });

      _currentUser = {
        ...?_currentUser,
        'name': name,
        'full_name': name,
        'fullName': name,
        'contact_no': phone,
        'phone': phone,
        'mobile': phone,
        'company_name': companyName,
        'companyName': companyName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        if (profilePicturePath != null) 'profile_picture_path': profilePicturePath,
      };

      if (profilePicturePath != null) {
        _profileImagePath = profilePicturePath;
      }

      AuthService.currentUser = _currentUser;

      _savingProfile = false;
      safeNotifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _savingProfile = false;
      safeNotifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfileImage(String imagePath) async {
    try {
      await _repository.updateProfileImage(imagePath);
      
      _profileImagePath = imagePath;
      
      if (_currentUser != null) {
        _currentUser = {
          ...?_currentUser,
          'profile_picture_path': imagePath,
        };
        AuthService.currentUser = _currentUser;
      }
      
      safeNotifyListeners();
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Societies methods - using _repository consistently
  Future<void> _loadSocieties() async {
    try {
      debugPrint('SettingsViewModel: Starting to load societies');
      final rawData = await _repository.getSocieties().timeout(const Duration(seconds: 3));
      debugPrint('SettingsViewModel: Repository returned ${rawData.length} raw societies: $rawData');
      
      _societies = List<Map<String, dynamic>>.from(
        rawData.map((item) => {
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
        })
      );
      
      debugPrint('SettingsViewModel: Type-safe societies mapping completed, societies count: ${_societies.length}');
      debugPrint('SettingsViewModel: Final societies list: $_societies');
      
      if (_societies.length == 1 && _selectedSocietyId == null) {
        final singleSociety = _societies.first;
        debugPrint('SettingsViewModel: Auto-selecting single society: ${singleSociety['name']} (${singleSociety['id']})');
        _selectedSocietyId = singleSociety['id'].toString();
      }
      
      safeNotifyListeners();
      
      debugPrint('SettingsViewModel: Societies loading completed successfully');
    } catch (e) {
      debugPrint('Error loading societies: $e');
      _societies = [];
      safeNotifyListeners();
    }
  }

  Future<void> addSociety(String name) async {
    try {
      await _repository.addSociety(name);
      
      // ✅ Emit event for real-time updates
      SocietyEventService().notifySocietyCreated({
        'id': '', // Will be populated after reload
        'name': name,
      });
      
      await _loadSocieties();
      safeNotifyListeners();
    } catch (e) {
      debugPrint('Error adding society: $e');
      rethrow;
    }
  }

  Future<void> updateSociety(String id, String name) async {
    try {
      await _repository.updateSociety(id, name);
      
      // ✅ Emit event
      SocietyEventService().notifySocietyUpdated({
        'id': id,
        'name': name,
      });
      
      await _loadSocieties();
    } catch (e) {
      debugPrint('Error updating society: $e');
      rethrow;
    }
  }

// ✅ FIXED: Delete society with proper error handling
Future<void> deleteSociety(String id) async {
  if (id.isEmpty) {
    debugPrint('SettingsViewModel: Cannot delete society - empty ID');
    return;
  }
  
  try {
    debugPrint('SettingsViewModel: Starting delete for society ID: $id');
    
    _loading = true;
    safeNotifyListeners();
    
    // ✅ CRITICAL: Clear selection FIRST if this society is selected
    if (_selectedSocietyId == id) {
      debugPrint('SettingsViewModel: Clearing selected society before delete');
      _selectedSocietyId = null;
      _blocks = [];
      // ✅ Don't call safeNotifyListeners() here - will call after delete
    }
    
    // ✅ Perform delete
    debugPrint('SettingsViewModel: Calling repository.deleteSociety()');
    await _repository.deleteSociety(id);
    debugPrint('SettingsViewModel: Repository delete completed');
    
    // ✅ Reload societies
    debugPrint('SettingsViewModel: Reloading societies list');
    await _loadSocieties();
    debugPrint('SettingsViewModel: Societies reloaded');
    
    // ✅ Emit event AFTER reload
    SocietyEventService().notifySocietyDeleted(id);
    debugPrint('SettingsViewModel: Event emitted');
    
    _loading = false;
    safeNotifyListeners();
    
    debugPrint('SettingsViewModel: Delete operation completed successfully');
  } catch (e, stackTrace) {
    debugPrint('SettingsViewModel: ERROR deleting society: $e');
    debugPrint('SettingsViewModel: Stack trace: $stackTrace');
    _loading = false;
    safeNotifyListeners();
    rethrow;
  }
}
  void setSelectedSociety(String? societyId) {
    if (_selectedSocietyId != societyId) {
      _selectedSocietyId = societyId;
      _blocks = [];
      safeNotifyListeners();
      
      if (societyId != null) {
        _loadBlocksForSociety(societyId).then((_) {
          safeNotifyListeners();
        });
      }
    }
  }

  Future<void> _loadBlocksForSociety(String societyId) async {
    try {
      _isLoadingBlocks = true;
      safeNotifyListeners();
      
      final rawData = await _repository.getBlocksBySociety(societyId).timeout(const Duration(seconds: 3));
      debugPrint('SettingsViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      _blocks = rawData.map((b) => {
        'id': b['id']?.toString() ?? '',
        'society_id': b['society_id']?.toString() ?? '',
        'name': b['name']?.toString() ?? '',
      }).toList();
      
      debugPrint('SettingsViewModel: Type-safe blocks mapping completed, blocks count: ${_blocks.length}');
      debugPrint('SettingsViewModel: Final blocks list: $_blocks');
    } catch (e) {
      debugPrint('Error loading blocks for society $societyId: $e');
      _blocks = [];
    } finally {
      _isLoadingBlocks = false;
      safeNotifyListeners();
    }
  }

  Future<void> _loadBlocks() async {
    try {
      final rawData = await _repository.getBlocks();
      debugPrint('SettingsViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      _blocks = rawData.map((b) => {
        'id': b['id']?.toString() ?? '',
        'society_id': b['society_id']?.toString() ?? '',
        'name': b['name']?.toString() ?? '',
      }).toList();
      
      debugPrint('SettingsViewModel: Type-safe blocks mapping completed, blocks count: ${_blocks.length}');
      debugPrint('SettingsViewModel: Final blocks list: $_blocks');
      
      safeNotifyListeners();
    } catch (e) {
      debugPrint('Error loading blocks: $e');
    }
  }

  Future<void> addBlock(String name) async {
    if (_selectedSocietyId == null) {
      throw Exception('No society selected');
    }

    try {
      await _repository.addBlock(_selectedSocietyId!, name);
      await _loadBlocksForSociety(_selectedSocietyId!);
    } catch (e) {
      debugPrint('Error adding block: $e');
      rethrow;
    }
  }

  Future<void> updateBlock(String id, String name) async {
    try {
      await _repository.updateBlock(id, name);
      await _loadBlocksForSociety(_selectedSocietyId!);
    } catch (e) {
      debugPrint('Error updating block: $e');
      rethrow;
    }
  }

  Future<void> deleteBlock(String id) async {
    try {
      await _repository.deleteBlock(id);
      await _loadBlocksForSociety(_selectedSocietyId!);
    } catch (e) {
      debugPrint('Error deleting block: $e');
      rethrow;
    }
  }

  Future<void> exportDataToCsv() async {
    try {
      await _repository.exportDataToCsv();
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }

  void syncProfileForm({
    required TextEditingController fullNameController,
    required TextEditingController phoneController,
    required TextEditingController companyController,
    required TextEditingController emailController,
  }) {
    if (_currentUser == null) return;

    final companyName = _currentUser!['company_name']?.toString() ?? _currentUser!['companyName']?.toString() ?? '';
    final fullName = _currentUser!['name']?.toString() ?? _currentUser!['full_name']?.toString() ?? _currentUser!['fullName']?.toString() ?? '';
    final phone = _currentUser!['phone']?.toString() ?? _currentUser!['mobile']?.toString() ?? _currentUser!['contact_no']?.toString() ?? '';
    final email = _currentUser!['email']?.toString() ?? _currentUser!['gmail']?.toString() ?? '';

    companyController.text = companyName == 'N/A' ? '' : companyName;
    fullNameController.text = fullName == 'N/A' ? '' : fullName;
    phoneController.text = phone == 'N/A' ? '' : phone;
    emailController.text = email;
  }
}