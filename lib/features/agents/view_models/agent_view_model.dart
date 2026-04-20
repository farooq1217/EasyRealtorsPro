import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/agent_repository.dart';
import '../repositories/agent_repository_impl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/permission_sync_service.dart' show PermissionSyncService;
import '../../../core/services/app_storage.dart' show AppStorage;
import 'package:shared/shared.dart' show WorkingProgressData, WorkingComment;
import '../../../core/role_utils.dart';

class AgentViewModel extends ChangeNotifier {
  final AgentRepository _repository;
  
  AgentViewModel(this._repository);

  // State
  List<WorkingProgressData> _transfers = [];
  List<WorkingProgressData> _clientRequirements = [];
  List<WorkingComment> _comments = [];
  List<Map<String, dynamic>> _officeNotes = [];
  List<Map<String, dynamic>> _otherNotes = [];
  bool _loading = false;
  bool _loadingTransfers = false;
  bool _loadingRequirements = false;
  bool _loadingComments = false;
  bool _loadingNotes = false;
  String _searchQuery = '';
  String _selectedType = 'Transfer'; // 'Transfer' or 'Client Requirements'
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;
  Map<String, dynamic>? _currentUser;
  String? _error;

  // Form controllers
  final TextEditingController dateCtl = TextEditingController();
  final TextEditingController plotCtl = TextEditingController();
  final TextEditingController clientNameCtl = TextEditingController();
  final TextEditingController clientMobileCtl = TextEditingController();
  final TextEditingController timeCtl = TextEditingController();
  final TextEditingController registryCtl = TextEditingController();
  final TextEditingController commentsCtl = TextEditingController();
  final TextEditingController reqDateCtl = TextEditingController();
  final TextEditingController reqPlotCtl = TextEditingController();
  final TextEditingController reqClientNameCtl = TextEditingController();
  final TextEditingController reqClientMobileCtl = TextEditingController();
  final TextEditingController reqTimeCtl = TextEditingController();
  final TextEditingController reqRegistryCtl = TextEditingController();
  final TextEditingController reqCommentsCtl = TextEditingController();
  final TextEditingController nextWorkingDateCtl = TextEditingController();
  final TextEditingController reqNextWorkingDateCtl = TextEditingController();
  final TextEditingController transferOtherCategoryCtl = TextEditingController();
  final TextEditingController transferOtherSizeCtl = TextEditingController();
  
  // New controllers for client requirement form
  final TextEditingController reqBudgetMinCtl = TextEditingController();
  final TextEditingController reqBudgetMaxCtl = TextEditingController();

  // Form state
  String? _transferCategory;
  String? _transferSize;
  String? _requirementCategory;
  String? _requirementSource = 'Direct'; // Set default value
  
  // New state variables for client requirement form
  String? _reqCategory;
  String? _reqSize;
  String? _reqLocation;
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _reqSelectedDate;
  TimeOfDay? _reqSelectedTime;
  DateTime? _nextWorkingDate;
  DateTime? _reqNextWorkingDate;
  List<String> _transferImages = [];
  List<String> _clientRequirementImages = [];
  String? _imagePath; // For single image upload in Transfer form

  // Getters
  List<WorkingProgressData> get transfers => _transfers;
  List<WorkingProgressData> get clientRequirements => _clientRequirements;
  List<WorkingComment> get comments => _comments;
  List<Map<String, dynamic>> get officeNotes => _officeNotes;
  List<Map<String, dynamic>> get otherNotes => _otherNotes;
  bool get loading => _loading;
  bool get loadingTransfers => _loadingTransfers;
  bool get loadingRequirements => _loadingRequirements;
  bool get loadingComments => _loadingComments;
  bool get loadingNotes => _loadingNotes;
  bool get saving => _loading;
  String get searchQuery => _searchQuery;
  String get selectedType => _selectedType;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get error => _error;
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_getCurrentData().length / _itemsPerPage).ceil();
  List<WorkingProgressData> get paginatedData {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return _getCurrentData().skip(startIndex).take(_itemsPerPage).toList();
  }

  // Helper method to get current data based on selected type
  List<WorkingProgressData> _getCurrentData() {
    return _selectedType == 'Transfer' ? _transfers : _clientRequirements;
  }

  // Form getters
  String? get transferCategory => _transferCategory;
  String? get transferSize => _transferSize;
  String? get requirementCategory => _requirementCategory;
  String? get requirementSource => _requirementSource;
  
  // Search functionality
  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1; // Reset to page 1 when search changes
    notifyListeners();
  }

  // Filter methods
  void setTransferCategory(String? category) {
    _transferCategory = category;
    _currentPage = 1; // Reset to page 1 when filter changes
    notifyListeners();
  }

  void setTransferSize(String? size) {
    _transferSize = size;
    _currentPage = 1; // Reset to page 1 when filter changes
    notifyListeners();
  }

  void setRequirementCategory(String? category) {
    _requirementCategory = category;
    _currentPage = 1; // Reset to page 1 when filter changes
    notifyListeners();
  }

  void setRequirementSource(String? source) {
    _requirementSource = source;
    _currentPage = 1; // Reset to page 1 when filter changes
    notifyListeners();
  }

  void setRequirementLocation(String? location) {
    _reqLocation = location;
    _currentPage = 1; // Reset to page 1 when filter changes
    notifyListeners();
  }

  void setRequirementSize(String? size) {
    _reqSize = size;
    _currentPage = 1; // Reset to page 1 when filter changes
    notifyListeners();
  }
  
  // New getters for client requirement form
  String? get reqCategory => _reqCategory;
  String? get reqSize => _reqSize;
  String? get reqLocation => _reqLocation;
  
  DateTime? get selectedDate => _selectedDate;
  TimeOfDay? get selectedTime => _selectedTime;
  DateTime? get reqSelectedDate => _reqSelectedDate;
  TimeOfDay? get reqSelectedTime => _reqSelectedTime;
  DateTime? get nextWorkingDate => _nextWorkingDate;
  DateTime? get reqNextWorkingDate => _reqNextWorkingDate;
  List<String> get transferImages => _transferImages;
  List<String> get requirementImages => _clientRequirementImages; // Renamed for consistency
  List<String> get clientRequirementImages => _clientRequirementImages; // Added for backward compatibility
  String? get imagePath => _imagePath;

  // Initialize
  Future<void> initialize() async {
    // CRITICAL FIX: Ensure user is loaded before any operations
    await _loadCurrentUser();
    
    // Only proceed with data loading if user is available
    if (_currentUser != null) {
      await loadTransfers();
      await loadClientRequirements();
      await loadOfficeNotes();
      await loadOtherNotes();
      await checkAndShowNotifications();
    } else {
      debugPrint('AgentViewModel: Cannot initialize - no user available');
    }
  }

  // Load current user
  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        debugPrint('AgentViewModel: Loading current user with permissions...');
        
        // CRITICAL FIX: Ensure AuthService is fully initialized before getting user
        try {
          // CRITICAL: Wait for user data with proper timeout to avoid null issues
          final user = await AuthService.getCurrentUser(authToken, waitForFirestore: false)
              .timeout(const Duration(seconds: 5));
              
          if (user != null) {
            _currentUser = user;
            debugPrint('AgentViewModel: User loaded successfully from AuthService: ${user['email']}');
            
            // NOW: Try to enhance with permissions after basic user data is loaded
            try {
              // Ensure cache is properly initialized with user data already available
              await PermissionSyncService.initializePermissionsCache(authToken);
              
              // Try to get enhanced user with permissions
              final userWithPermissions = await PermissionSyncService.getPermissionsInstantly(authToken)
                  .timeout(const Duration(seconds: 3)); // Reduced timeout since we have basic user
              
              if (userWithPermissions != null && userWithPermissions['permissions'] != null) {
                _currentUser = userWithPermissions;
                debugPrint('AgentViewModel: User enhanced with permissions: ${userWithPermissions['email']}');
              } else {
                debugPrint('AgentViewModel: Permission enhancement returned null, using basic user data');
              }
            } catch (permError) {
              debugPrint('AgentViewModel: Permission enhancement failed, using basic user data: $permError');
              // Keep the basic user data we already loaded
            }
          } else {
            debugPrint('AgentViewModel: AuthService returned null user');
            throw Exception('User authentication failed - no user data available');
          }
        } catch (e) {
          debugPrint('AgentViewModel: Error loading user from AuthService: $e');
          throw Exception('User authentication failed: $e');
        }
      } else {
        debugPrint('AgentViewModel: No auth token found');
        throw Exception('No authentication token available');
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
      rethrow; // Re-throw to ensure proper error handling
    }
  }

  // Load transfers with stream-based real-time updates
  Future<void> loadTransfers() async {
    _loadingTransfers = true;
    _error = null;
    notifyListeners();
    
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      // FOOLPROOF: Manual fetch instead of stream
      _transfers = await _repository.getTransfers(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      _loadingTransfers = false;
      notifyListeners();
      debugPrint('AgentViewModel: Transfers loaded manually - ${_transfers.length} items');
    } catch (e) {
      _error = 'Failed to load transfers: $e';
      _loadingTransfers = false;
      debugPrint('Error loading transfers: $e');
      notifyListeners();
    }
  }

  // Load client requirements with manual fetch
  Future<void> loadClientRequirements() async {
    _loadingRequirements = true;
    _error = null;
    notifyListeners();
    
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      // FOOLPROOF: Manual fetch instead of stream
      _clientRequirements = await _repository.getClientRequirements(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      _loadingRequirements = false;
      notifyListeners();
      debugPrint('AgentViewModel: Client requirements loaded manually - ${_clientRequirements.length} items');
    } catch (e) {
      _error = 'Failed to load client requirements: $e';
      _loadingRequirements = false;
      debugPrint('Error loading client requirements: $e');
      notifyListeners();
    }
  }

  // Load comments for a specific entry
  Future<void> loadComments(String parentId) async {
    _loadingComments = true;
    notifyListeners();
    
    try {
      _comments = await _repository.getComments(parentId);
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      _loadingComments = false;
      notifyListeners();
    }
  }

  // Load office notes
  Future<void> loadOfficeNotes() async {
    _loadingNotes = true;
    notifyListeners();
    
    try {
      _officeNotes = await _repository.getOfficeNotes();
    } catch (e) {
      debugPrint('Error loading office notes: $e');
    } finally {
      _loadingNotes = false;
      notifyListeners();
    }
  }

  // Load other notes
  Future<void> loadOtherNotes() async {
    _loadingNotes = true;
    notifyListeners();
    
    try {
      _otherNotes = await _repository.getOtherNotes();
    } catch (e) {
      debugPrint('Error loading other notes: $e');
    } finally {
      _loadingNotes = false;
      notifyListeners();
    }
  }


  void clearSearch() {
    setSearchQuery('');
  }

  void refresh() {
    if (_selectedType == 'Transfer') {
      loadTransfers();
    } else {
      loadClientRequirements();
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    dateCtl.dispose();
    plotCtl.dispose();
    clientNameCtl.dispose();
    clientMobileCtl.dispose();
    timeCtl.dispose();
    registryCtl.dispose();
    commentsCtl.dispose();
    reqDateCtl.dispose();
    reqPlotCtl.dispose();
    reqClientNameCtl.dispose();
    reqClientMobileCtl.dispose();
    reqTimeCtl.dispose();
    reqRegistryCtl.dispose();
    reqCommentsCtl.dispose();
    nextWorkingDateCtl.dispose();
    reqNextWorkingDateCtl.dispose();
    transferOtherCategoryCtl.dispose();
    transferOtherSizeCtl.dispose();
    reqBudgetMinCtl.dispose();
    reqBudgetMaxCtl.dispose();
    
    super.dispose();
  }

  // Type selection
  void setSelectedType(String type) {
    _selectedType = type;
    notifyListeners();
  }


  void setSelectedDate(DateTime? date) {
    debugPrint('AgentViewModel: setSelectedDate called with: $date');
    debugPrint('AgentViewModel: Previous selectedDate: $_selectedDate');
    _selectedDate = date;
    if (date != null) {
      dateCtl.text = DateFormat('dd MMM yyyy').format(date);
      debugPrint('AgentViewModel: dateCtl.text updated to: "${dateCtl.text}"');
    } else {
      debugPrint('AgentViewModel: Date is null, clearing dateCtl.text');
    }
    debugPrint('AgentViewModel: New selectedDate: $_selectedDate');
    debugPrint('AgentViewModel: Calling notifyListeners()');
    notifyListeners();
    debugPrint('AgentViewModel: notifyListeners() completed');
  }

  void setSelectedTime(TimeOfDay? time) {
    debugPrint('AgentViewModel: setSelectedTime called with: $time');
    debugPrint('AgentViewModel: Previous selectedTime: $_selectedTime');
    _selectedTime = time;
    if (time != null) {
      timeCtl.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      debugPrint('AgentViewModel: timeCtl.text updated to: "${timeCtl.text}"');
    } else {
      debugPrint('AgentViewModel: Time is null, clearing timeCtl.text');
    }
    debugPrint('AgentViewModel: New selectedTime: $_selectedTime');
    debugPrint('AgentViewModel: Calling notifyListeners()');
    notifyListeners();
    debugPrint('AgentViewModel: notifyListeners() completed');
  }

  void setReqSelectedDate(DateTime? date) {
    _reqSelectedDate = date;
    if (date != null) {
      reqDateCtl.text = DateFormat('dd MMM yyyy').format(date);
    }
    notifyListeners();
  }

  void setReqSelectedTime(TimeOfDay? time) {
    _reqSelectedTime = time;
    if (time != null) {
      reqTimeCtl.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    notifyListeners();
  }

  void setNextWorkingDate(DateTime? date) {
    _nextWorkingDate = date;
    if (date != null) {
      nextWorkingDateCtl.text = DateFormat('dd MMM yyyy').format(date);
    }
    notifyListeners();
  }

  void setReqNextWorkingDate(DateTime? date) {
    _reqNextWorkingDate = date;
    if (date != null) {
      reqNextWorkingDateCtl.text = DateFormat('dd MMM yyyy').format(date);
    }
    notifyListeners();
  }

  void setTransferImages(List<String> images) {
    _transferImages = images;
    notifyListeners();
  }

  void setClientRequirementImages(List<String> images) {
    _clientRequirementImages = images;
    notifyListeners();
  }

  // New setters for client requirement form
  void setReqCategory(String? category) {
    _reqCategory = category;
    notifyListeners();
  }

  void setReqSize(String? size) {
    _reqSize = size;
    notifyListeners();
  }

  void setReqLocation(String? location) {
    _reqLocation = location;
    notifyListeners();
  }

  void setRequirementImages(List<String> images) {
    _clientRequirementImages = images;
    notifyListeners();
  }

  // Image picker method for Windows compatibility
  Future<void> pickImage() async {
    try {
      debugPrint('AgentViewModel: Starting image picker...');
      
      // For Windows, use file_selector for better compatibility
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        
        if (image != null) {
          _imagePath = image.path;
          debugPrint('AgentViewModel: Image selected (Windows) - ${image.path}');
          notifyListeners();
        } else {
          debugPrint('AgentViewModel: No image selected');
        }
      } else {
        // For other platforms, use standard image picker
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        
        if (image != null) {
          _imagePath = image.path;
          debugPrint('AgentViewModel: Image selected - ${image.path}');
          notifyListeners();
        } else {
          debugPrint('AgentViewModel: No image selected');
        }
      }
    } catch (e) {
      debugPrint('AgentViewModel: Error picking image: $e');
      _error = 'Failed to pick image: $e';
      notifyListeners();
    }
  }

  // Clear single image path
  void clearImagePath() {
    _imagePath = null;
    notifyListeners();
  }

  // Add transfer
  Future<bool> addTransfer() async {
    print("AgentViewModel: addTransfer() called. Starting validation...");
    
    // CRITICAL FIX: Ensure user is loaded with permissions before proceeding
    if (_currentUser == null) {
      print("AgentViewModel: Current user is null, reloading...");
      await _loadCurrentUser();
    }
    
    debugPrint('AgentViewModel: Permission check - User: ${_currentUser?['email']}, Role: ${_currentUser?['role']}');
    debugPrint('AgentViewModel: Permission check - User permissions: ${_currentUser?['permissions']}');
    
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      _error = 'Permission Denied: Cannot add agent working entries';
      notifyListeners();
      debugPrint('AgentViewModel: Permission denied for agent_working module');
      return false;
    }
    
    debugPrint('AgentViewModel: Permission check passed for agent_working module');

    debugPrint('AgentViewModel: Date validation - _selectedDate: $_selectedDate, dateCtl.text: "${dateCtl.text}"');
    if (_selectedDate == null && dateCtl.text.isEmpty) {
      _error = 'Please select a date';
      notifyListeners();
      debugPrint('AgentViewModel: Validation failed - Date is required');
      return false;
    }
    debugPrint('AgentViewModel: Date validation passed');

    // CRITICAL FIX: Enhanced time validation with proper fallback
    debugPrint('AgentViewModel: Time validation - _selectedTime: $_selectedTime, timeCtl.text: "${timeCtl.text}"');
    
    // Check both selected time and text field - if either has a value, parse it
    TimeOfDay? timeToUse;
    if (_selectedTime != null) {
      timeToUse = _selectedTime;
    } else if (timeCtl.text.isNotEmpty) {
      // Parse time from text field (format: HH:MM)
      final parts = timeCtl.text.split(':');
      if (parts.length == 2) {
        try {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            timeToUse = TimeOfDay(hour: hour, minute: minute);
            debugPrint('AgentViewModel: Parsed time from text field: ${timeToUse.hour.toString().padLeft(2, '0')}:${timeToUse.minute.toString().padLeft(2, '0')}');
          }
        } catch (e) {
          debugPrint('AgentViewModel: Failed to parse time from text field: $e');
        }
      }
    }
    
    if (timeToUse == null) {
      _error = 'Please select a time';
      notifyListeners();
      debugPrint('AgentViewModel: Validation failed - Time is required');
      return false;
    }
    
    // Update selected time if we parsed from text
    if (_selectedTime == null && timeToUse != null) {
      _selectedTime = timeToUse;
      debugPrint('AgentViewModel: Updated _selectedTime from text field: $_selectedTime');
    }
    
    debugPrint('AgentViewModel: Time validation passed');

    // Validate category requirement
    if (_transferCategory == null || _transferCategory!.isEmpty) {
      _error = 'Please select a category';
      notifyListeners();
      return false;
    }

    // Validate "Other" category field
    if (_transferCategory == 'other' && transferOtherCategoryCtl.text.trim().isEmpty) {
      _error = 'Please specify the category when "Other" is selected';
      notifyListeners();
      return false;
    }

    // Validate "Other" size field
    if (_transferSize == 'other' && transferOtherSizeCtl.text.trim().isEmpty) {
      _error = 'Please specify the size when "Other" is selected';
      notifyListeners();
      return false;
    }

    print("AgentViewModel: Validation passed. Proceeding with save...");
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().trim().toLowerCase();
      final safeEmail = emailKey.replaceAll('/', '_');
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final id = safeEmail.isNotEmpty ? '${safeEmail}_$ts' : ts;
      final userId = _currentUser?['id']?.toString() ?? 'unknown';
      final transferDate = _selectedDate != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nextWorkingDateStr = _nextWorkingDate != null 
          ? DateFormat('yyyy-MM-dd').format(_nextWorkingDate!)
          : null;
      
      // Use custom category if "Other" is selected and custom value is provided
      final categoryToSave = _transferCategory == 'other' && transferOtherCategoryCtl.text.trim().isNotEmpty
          ? transferOtherCategoryCtl.text.trim()
          : _transferCategory;
      
      // Use custom size if "Other" is selected
      final sizeToSave = _transferSize == 'other'
          ? transferOtherSizeCtl.text.trim()
          : _transferSize;

      print("AgentViewModel: About to save transfer with ID: $id");
      print("AgentViewModel: Category: $categoryToSave, Size: $sizeToSave");

      final success = await _repository.addTransfer(
        id: id,
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        name: clientNameCtl.text.trim(),
        status: 'Pending',
        remarks: commentsCtl.text.trim().isEmpty ? null : commentsCtl.text.trim(),
        transferDate: transferDate,
        nextWorkingDate: null, // Removed next working date as requested
        category: categoryToSave,
        plotNo: plotCtl.text.trim().isEmpty ? null : plotCtl.text.trim(),
        registryNumber: registryCtl.text.trim().isEmpty ? null : registryCtl.text.trim(),
        size: sizeToSave,
        clientMobile: clientMobileCtl.text.trim().isEmpty ? null : clientMobileCtl.text.trim(),
        images: _transferImages,
      );

      if (!success) {
        throw Exception('Failed to save transfer to database');
      }

      print("AgentViewModel: Transfer saved successfully - ID: $id");
      debugPrint('AgentViewModel: Transfer saved successfully - ID: $id');

      // FIXED: Removed redundant manual refresh - notifyListeners() is enough
      // The repository should handle data updates, and UI will react to notifyListeners()
      notifyListeners(); // Single notify call after successful save

      // Clear form
      _clearTransferForm();
      
      return true;
    } catch (e) {
      print("AgentViewModel: Error saving transfer: $e");
      _error = 'Failed to add transfer: $e';
      debugPrint('Error adding transfer: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Delete working progress item
  Future<void> deleteItem(String id) async {
    try {
      await _repository.deleteItem(id);
      
      // CRITICAL: Manually fetch fresh data immediately
      _transfers = await _repository.getTransfers(
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        isSuperAdmin: RoleUtils.isSuperAdmin(_currentUser),
      ); 
      _clientRequirements = await _repository.getClientRequirements(
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        isSuperAdmin: RoleUtils.isSuperAdmin(_currentUser),
      );

      notifyListeners(); // Instantly update UI
    } catch (e) {
      _error = 'Failed to delete item: $e';
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  // Update transfer
  Future<bool> updateTransfer(String id) async {
    print("AgentViewModel: updateTransfer() called. Starting validation...");
    
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      _error = 'Permission Denied';
      notifyListeners();
      return false;
    }

    if (_selectedDate == null && dateCtl.text.isEmpty) {
      _error = 'Please select a date';
      notifyListeners();
      return false;
    }

    // Validate category requirement
    if (_transferCategory == null || _transferCategory!.isEmpty) {
      _error = 'Please select a category';
      notifyListeners();
      return false;
    }

    // Validate "Other" category field
    if (_transferCategory == 'other' && transferOtherCategoryCtl.text.trim().isEmpty) {
      _error = 'Please specify the category when "Other" is selected';
      notifyListeners();
      return false;
    }

    // Validate "Other" size field
    if (_transferSize == 'other' && transferOtherSizeCtl.text.trim().isEmpty) {
      _error = 'Please specify the size when "Other" is selected';
      notifyListeners();
      return false;
    }

    print("AgentViewModel: Validation passed. Proceeding with update...");
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final transferDate = _selectedDate != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nextWorkingDateStr = _nextWorkingDate != null 
          ? DateFormat('yyyy-MM-dd').format(_nextWorkingDate!)
          : null;
      
      // Use custom category if "Other" is selected and custom value is provided
      final categoryToSave = _transferCategory == 'other' && transferOtherCategoryCtl.text.trim().isNotEmpty
          ? transferOtherCategoryCtl.text.trim()
          : _transferCategory;
      
      // Use custom size if "Other" is selected
      final sizeToSave = _transferSize == 'other'
          ? transferOtherSizeCtl.text.trim()
          : _transferSize;

      print("AgentViewModel: About to update transfer with ID: $id");
      print("AgentViewModel: Category: $categoryToSave, Size: $sizeToSave");

      await _repository.updateEntry(
        id: id,
        name: clientNameCtl.text.trim(),
        status: 'Pending',
        remarks: commentsCtl.text.trim().isEmpty ? null : commentsCtl.text.trim(),
        transferDate: transferDate,
        nextWorkingDate: nextWorkingDateStr,
        category: categoryToSave,
        plotNo: plotCtl.text.trim().isEmpty ? null : plotCtl.text.trim(),
        registryNumber: registryCtl.text.trim().isEmpty ? null : registryCtl.text.trim(),
        size: sizeToSave,
        clientMobile: clientMobileCtl.text.trim().isEmpty ? null : clientMobileCtl.text.trim(),
        images: _transferImages,
      );

      print("AgentViewModel: Transfer updated successfully - ID: $id");
      debugPrint('AgentViewModel: Transfer updated successfully - ID: $id');

      // FIXED: Removed redundant manual refresh - notifyListeners() is enough
      // The repository should handle data updates, and UI will react to notifyListeners()
      notifyListeners(); // Single notify call after successful update

      // Clear form
      _clearTransferForm();
      
      return true;
    } catch (e) {
      print("AgentViewModel: Error updating transfer: $e");
      _error = 'Failed to update transfer: $e';
      debugPrint('Error updating transfer: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Update working progress item
  Future<void> updateEntry({
    required String id,
    String? name,
    String? status,
    String? remarks,
    String? transferDate,
    String? nextWorkingDate,
    String? category,
    String? plotNo,
    String? registryNumber,
    String? size,
    String? clientMobile,
    List<String>? images,
  }) async {
    try {
      await _repository.updateEntry(
        id: id,
        name: name,
        status: status,
        remarks: remarks,
        transferDate: transferDate,
        nextWorkingDate: nextWorkingDate,
        category: category,
        plotNo: plotNo,
        registryNumber: registryNumber,
        size: size,
        clientMobile: clientMobile,
        images: images,
      );
      
      // CRITICAL: Manually fetch fresh data immediately
      _transfers = await _repository.getTransfers(
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        isSuperAdmin: RoleUtils.isSuperAdmin(_currentUser),
      ); 
      _clientRequirements = await _repository.getClientRequirements(
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        isSuperAdmin: RoleUtils.isSuperAdmin(_currentUser),
      );

      notifyListeners(); // Instantly update UI
    } catch (e) {
      _error = 'Failed to update item: $e';
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  // Add client requirement
  Future<bool> addClientRequirement() async {
    print("AgentViewModel: addClientRequirement() called. Starting validation...");
    
    // CRITICAL FIX: Ensure user is loaded with permissions before proceeding
    if (_currentUser == null) {
      print("AgentViewModel: Current user is null, reloading...");
      try {
        await _loadCurrentUser();
        // If still null after reload, fail early
        if (_currentUser == null) {
          _error = 'User authentication failed - please log in again';
          notifyListeners();
          return false;
        }
      } catch (e) {
        _error = 'Failed to load user: $e';
        notifyListeners();
        return false;
      }
    }
    
    debugPrint('AgentViewModel: Permission check - User: ${_currentUser?['email']}, Role: ${_currentUser?['role']}');
    debugPrint('AgentViewModel: Permission check - User permissions: ${_currentUser?['permissions']}');
    
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      _error = 'Permission Denied: Cannot add client requirement entries';
      notifyListeners();
      debugPrint('AgentViewModel: Permission denied for client_working module');
      return false;
    }
    
    debugPrint('AgentViewModel: Permission check passed for client_working module');

    if (_reqSelectedDate == null && reqDateCtl.text.isEmpty) {
      _error = 'Please select a date';
      notifyListeners();
      debugPrint('AgentViewModel: Validation failed - Date is required for client requirement');
      return false;
    }

    // CRITICAL FIX: Enhanced time validation for client requirement with proper fallback
    debugPrint('AgentViewModel: Client requirement time validation - _reqSelectedTime: $_reqSelectedTime, reqTimeCtl.text: "${reqTimeCtl.text}"');
    
    // Check both selected time and text field - if either has a value, parse it
    TimeOfDay? timeToUse;
    if (_reqSelectedTime != null) {
      timeToUse = _reqSelectedTime;
    } else if (reqTimeCtl.text.isNotEmpty) {
      // Parse time from text field (format: HH:MM)
      final parts = reqTimeCtl.text.split(':');
      if (parts.length == 2) {
        try {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            timeToUse = TimeOfDay(hour: hour, minute: minute);
            debugPrint('AgentViewModel: Parsed client requirement time from text field: ${timeToUse.hour.toString().padLeft(2, '0')}:${timeToUse.minute.toString().padLeft(2, '0')}');
          }
        } catch (e) {
          debugPrint('AgentViewModel: Failed to parse client requirement time from text field: $e');
        }
      }
    }
    
    if (timeToUse == null) {
      _error = 'Please select a time';
      notifyListeners();
      debugPrint('AgentViewModel: Validation failed - Time is required for client requirement');
      return false;
    }
    
    // Update selected time if we parsed from text
    if (_reqSelectedTime == null && timeToUse != null) {
      _reqSelectedTime = timeToUse;
      debugPrint('AgentViewModel: Updated _reqSelectedTime from text field: $_reqSelectedTime');
    }
    
    debugPrint('AgentViewModel: Client requirement time validation passed');

    if (_requirementSource == null || _requirementSource!.isEmpty) {
      _error = 'Please select a source (Direct, Agent, Website, Social Media, or Referral)';
      notifyListeners();
      return false;
    }

    print("AgentViewModel: Validation passed. Proceeding with save...");
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().trim().toLowerCase();
      final safeEmail = emailKey.replaceAll('/', '_');
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final id = safeEmail.isNotEmpty ? '${safeEmail}_$ts' : ts;
      final userId = _currentUser?['id']?.toString() ?? 'unknown';
      final transferDate = _reqSelectedDate != null 
        ? DateFormat('yyyy-MM-dd').format(_reqSelectedDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nextWorkingDateStr = _reqNextWorkingDate != null 
          ? DateFormat('yyyy-MM-dd').format(_reqNextWorkingDate!)
          : null;

      await _repository.addClientRequirement(
        id: id,
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        name: reqClientNameCtl.text.trim(),
        status: 'Pending',
        remarks: reqCommentsCtl.text.trim().isEmpty ? null : reqCommentsCtl.text.trim(),
        transferDate: transferDate,
        nextWorkingDate: nextWorkingDateStr,
        source: _requirementSource,
        images: _clientRequirementImages,
      );
      
      debugPrint('AgentViewModel: Client requirement saved successfully - Source: $_requirementSource');

      // FIXED: Removed redundant manual refresh - notifyListeners() is enough
      // The repository should handle data updates, and UI will react to notifyListeners()
      notifyListeners(); // Single notify call after successful save

      // Clear form
      _clearRequirementForm();
      
      return true;
    } catch (e) {
      _error = 'Failed to add client requirement: $e';
      debugPrint('Error adding client requirement: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Update client requirement
  Future<bool> updateClientRequirement(String id) async {
    print("AgentViewModel: updateClientRequirement() called. Starting validation...");
    
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      _error = 'Permission Denied';
      notifyListeners();
      return false;
    }

    if (_reqSelectedDate == null && reqDateCtl.text.isEmpty) {
      _error = 'Please select a date';
      notifyListeners();
      return false;
    }

    if (_requirementSource == null || _requirementSource!.isEmpty) {
      _error = 'Please select a source (Direct, Agent, Website, Social Media, or Referral)';
      notifyListeners();
      return false;
    }

    print("AgentViewModel: Validation passed. Proceeding with update...");
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final transferDate = _reqSelectedDate != null 
        ? DateFormat('yyyy-MM-dd').format(_reqSelectedDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nextWorkingDateStr = _reqNextWorkingDate != null 
          ? DateFormat('yyyy-MM-dd').format(_reqNextWorkingDate!)
          : null;

      await _repository.updateEntry(
        id: id,
        name: reqClientNameCtl.text.trim(),
        status: 'Pending',
        remarks: reqCommentsCtl.text.trim().isEmpty ? null : reqCommentsCtl.text.trim(),
        transferDate: transferDate,
        nextWorkingDate: nextWorkingDateStr,
        category: _requirementSource, // Use source as category for client requirements
        images: _clientRequirementImages,
      );
      
      debugPrint('AgentViewModel: Client requirement updated successfully - Source: $_requirementSource');

      // FIXED: Removed redundant manual refresh - notifyListeners() is enough
      // The repository should handle data updates, and UI will react to notifyListeners()
      notifyListeners(); // Single notify call after successful update

      // Clear form
      _clearRequirementForm();
      
      return true;
    } catch (e) {
      _error = 'Failed to update client requirement: $e';
      debugPrint('Error updating client requirement: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Update status
  Future<bool> updateStatus({
    required String id,
    required String status,
    DateTime? nextDate,
  }) async {
    try {
      final nextDateStr = nextDate != null ? DateFormat('yyyy-MM-dd').format(nextDate) : null;
      
      await _repository.updateStatus(
        id: id,
        status: status,
        nextWorkingDate: nextDateStr,
      );
      
      // Reload data
      await loadTransfers();
      await loadClientRequirements();
      
      return true;
    } catch (e) {
      _error = 'Failed to update status: $e';
      debugPrint('Error updating status: $e');
      return false;
    }
  }

  // Add comment
  Future<bool> addComment({
    required String parentId,
    required String comment,
  }) async {
    try {
      final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().trim().toLowerCase();
      final safeEmail = emailKey.replaceAll('/', '_');
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final id = safeEmail.isNotEmpty ? '${safeEmail}_$ts' : ts;
      final userId = _currentUser?['id']?.toString() ?? 'unknown';

      await _repository.addComment(
        id: id,
        parentId: parentId,
        companyId: RoleUtils.getUserCompanyId(_currentUser),
        comment: comment,
      );

      // Reload comments
      await loadComments(parentId);
      
      return true;
    } catch (e) {
      _error = 'Failed to add comment: $e';
      debugPrint('Error adding comment: $e');
      return false;
    }
  }

  // Add office note
  Future<bool> addOfficeNote({
    required String text,
  }) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      await _repository.addOfficeNote(
        id: ts,
        text: text,
        createdAt: DateTime.now(),
      );

      // Reload office notes
      await loadOfficeNotes();
      
      return true;
    } catch (e) {
      _error = 'Failed to add office note: $e';
      debugPrint('Error adding office note: $e');
      return false;
    }
  }

  // Add other note
  Future<bool> addOtherNote({
    required String text,
  }) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      await _repository.addOtherNote(
        id: ts,
        text: text,
        createdAt: DateTime.now(),
      );

      // Reload other notes
      await loadOtherNotes();
      
      return true;
    } catch (e) {
      _error = 'Failed to add other note: $e';
      debugPrint('Error adding other note: $e');
      return false;
    }
  }

  // Check and show notifications
  Future<void> checkAndShowNotifications() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);

      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        return;
      }

      final tasks = await _repository.getTasksDueToday(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
      );
      
      if (tasks.isNotEmpty) {
        // This would trigger a notification in the UI
        debugPrint('Found ${tasks.length} tasks due today');
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  // Generate professional receipt
  Future<void> generateProfessionalReceipt(String entryId) async {
    try {
      await _repository.generateProfessionalReceipt(entryId);
    } catch (e) {
      _error = 'Failed to generate receipt: $e';
      notifyListeners();
    }
  }

  // Clear forms
  void _clearTransferForm() {
    dateCtl.clear();
    plotCtl.clear();
    clientNameCtl.clear();
    clientMobileCtl.clear();
    timeCtl.clear();
    registryCtl.clear();
    commentsCtl.clear();
    nextWorkingDateCtl.clear();
    transferOtherCategoryCtl.clear();
    transferOtherSizeCtl.clear();
    
    // Reset state variables
    _selectedDate = null;
    _selectedTime = null;
    _nextWorkingDate = null;
    _transferCategory = null;
    _transferSize = null;
    _transferImages = [];
    _imagePath = null; // Clear single image path
    
    notifyListeners();
  }

  void _clearRequirementForm() {
    reqClientNameCtl.clear();
    reqCommentsCtl.clear();
    reqNextWorkingDateCtl.clear();
    reqBudgetMinCtl.clear();
    reqBudgetMaxCtl.clear();
    
    // Reset state variables
    _reqSelectedDate = null;
    _reqSelectedTime = null;
    _reqNextWorkingDate = null;
    _requirementSource = null;
    _clientRequirementImages = [];
    
    notifyListeners();
  }

  // Public clear methods for form initialization
  void clearTransferForm() => _clearTransferForm();
  void clearRequirementForm() => _clearRequirementForm();

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

  // Get filtered entries based on selected type and search
  List<WorkingProgressData> get filteredEntries {
    if (_selectedType == 'Transfer') {
      return _transfers;
    } else {
      return _clientRequirements;
    }
  }

}
