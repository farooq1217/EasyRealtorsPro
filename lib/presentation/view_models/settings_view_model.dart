// presentation/view_models/settings_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../core/services/auth_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repository;
  
  SettingsViewModel(this._repository);

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

  // Initialize
  Future<void> initialize() async {
    await _loadCurrentUser();
    await _loadSocieties();
    await _loadBlocks();
  }

  // User profile methods
  Future<void> _loadCurrentUser() async {
    try {
      _loading = true;
      notifyListeners();
      
      _currentUser = await _repository.getCurrentUser();
      
      if (_currentUser != null) {
        _profileImagePath = _currentUser!['profile_picture_path']?.toString();
      }
      
      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading current user: $e');
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String companyName,
    String? profilePicturePath,
  }) async {
    if (_currentUser == null) return;

    _savingProfile = true;
    notifyListeners();

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

      // Update local state
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

      // Update AuthService cache
      AuthService.currentUser = _currentUser;

      _savingProfile = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _savingProfile = false;
      notifyListeners();
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
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      rethrow;
    }
  }

  // Societies methods
  Future<void> _loadSocieties() async {
    try {
      final rawData = await _repository.getSocieties();
      debugPrint('SettingsViewModel: Repository returned ${rawData.length} raw societies: $rawData');
      
      // Fix the "Non-subtype" Error: Use type-safe mapping logic
      _societies = List<Map<String, dynamic>>.from(
        rawData.map((item) => {
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
        })
      );
      
      debugPrint('SettingsViewModel: Type-safe societies mapping completed, societies count: ${_societies.length}');
      debugPrint('SettingsViewModel: Final societies list: $_societies');
      
      // AUTO-SELECTION: If there is only one society and no society is currently selected, auto-select it
      if (_societies.length == 1 && _selectedSocietyId == null) {
        final singleSociety = _societies.first;
        debugPrint('SettingsViewModel: Auto-selecting single society: ${singleSociety['name']} (${singleSociety['id']})');
        setSelectedSociety(singleSociety['id'].toString());
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading societies: $e');
    }
  }

  Future<void> addSociety(String name) async {
    try {
      await _repository.addSociety(name);
      await _loadSocieties(); // Refresh list
    } catch (e) {
      debugPrint('Error adding society: $e');
      rethrow;
    }
  }

  Future<void> updateSociety(String id, String name) async {
    try {
      await _repository.updateSociety(id, name);
      await _loadSocieties(); // Refresh list
    } catch (e) {
      debugPrint('Error updating society: $e');
      rethrow;
    }
  }

  Future<void> deleteSociety(String id) async {
    try {
      await _repository.deleteSociety(id);
      
      // Clear selection if deleted society was selected
      if (_selectedSocietyId == id) {
        _selectedSocietyId = null;
        _blocks = [];
      }
      
      await _loadSocieties(); // Refresh list
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting society: $e');
      rethrow;
    }
  }

  void setSelectedSociety(String? societyId) {
    if (_selectedSocietyId != societyId) {
      // 1. Update the selected society ID
      _selectedSocietyId = societyId;
      
      // 2. Clear the current blocks list to prevent old data from showing
      _blocks = [];
      
      // 3. Call notifyListeners() immediately to reset the Block dropdown state
      notifyListeners();
      
      // 4. If societyId is not null, trigger block loading for fresh data
      if (societyId != null) {
        _loadBlocksForSociety(societyId).then((_) {
          // Additional notification after blocks are loaded
          notifyListeners();
        });
      }
    }
  }

  // Helper method to load blocks for a specific society
  Future<void> _loadBlocksForSociety(String societyId) async {
    try {
      _isLoadingBlocks = true;
      notifyListeners();
      
      final rawData = await _repository.getBlocksBySociety(societyId);
      debugPrint('SettingsViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      // Fix the "Non-subtype" Error: Use type-safe mapping logic
      _blocks = rawData.map((b) => {
        'id': b['id']?.toString() ?? '',
        'society_id': b['society_id']?.toString() ?? '',
        'name': b['name']?.toString() ?? '',
      }).toList();
      
      debugPrint('SettingsViewModel: Type-safe blocks mapping completed, blocks count: ${_blocks.length}');
      debugPrint('SettingsViewModel: Final blocks list: $_blocks');
      
      _isLoadingBlocks = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading blocks for society $societyId: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      notifyListeners();
    }
  }

  // Blocks methods
  Future<void> _loadBlocks() async {
    try {
      final rawData = await _repository.getBlocks();
      debugPrint('SettingsViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      // Fix the "Non-subtype" Error: Use type-safe mapping logic
      _blocks = rawData.map((b) => {
        'id': b['id']?.toString() ?? '',
        'society_id': b['society_id']?.toString() ?? '',
        'name': b['name']?.toString() ?? '',
      }).toList();
      
      debugPrint('SettingsViewModel: Type-safe blocks mapping completed, blocks count: ${_blocks.length}');
      debugPrint('SettingsViewModel: Final blocks list: $_blocks');
      
      notifyListeners();
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
      await _loadBlocksForSociety(_selectedSocietyId!); // Refresh list
    } catch (e) {
      debugPrint('Error adding block: $e');
      rethrow;
    }
  }

  Future<void> updateBlock(String id, String name) async {
    try {
      await _repository.updateBlock(id, name);
      await _loadBlocksForSociety(_selectedSocietyId!); // Refresh list
    } catch (e) {
      debugPrint('Error updating block: $e');
      rethrow;
    }
  }

  Future<void> deleteBlock(String id) async {
    try {
      await _repository.deleteBlock(id);
      await _loadBlocksForSociety(_selectedSocietyId!); // Refresh list
    } catch (e) {
      debugPrint('Error deleting block: $e');
      rethrow;
    }
  }

  // Data export
  Future<void> exportDataToCsv() async {
    try {
      await _repository.exportDataToCsv();
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }

  // Form sync helpers
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
