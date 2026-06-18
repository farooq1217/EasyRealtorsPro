// presentation/inventory/inventory_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../models/inventory_item.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/inventory_repository_impl.dart';
import '../../settings/repositories/society_repository.dart';
import '../../settings/repositories/settings_repository.dart';
import '../../../core/services/society_event_service.dart';

class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _inventoryRepository;
  final SettingsRepository _settingsRepository;
  
  // User context for RBAC
  String? _currentUserCompanyId;
  bool? _currentUserIsSuper;
  
  // Data lists
  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filteredItems = [];
  List<Map<String, String>> _societies = [];
  List<Map<String, String>> _blocks = [];
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingSocieties = false;
  bool _isLoadingBlocks = false;
  bool _initialized = false;
  bool _mounted = false;
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  // Stream subscriptions
  StreamSubscription<List<Map<String, String>>>? _societiesSubscription;
  StreamSubscription<List<Map<String, String>>>? _blocksSubscription;
  StreamSubscription<SocietyEvent>? _societyEventSubscription;
  
  // Filter state
  InventoryType _selectedType = InventoryType.file;
  String _searchQuery = '';
  String? _selectedSocietyId;
  String? _selectedBlockId;
  String? _selectedStatusFilter;

  // Constructor
  InventoryViewModel(
    this._inventoryRepository, 
    this._settingsRepository, {
    String? companyId, 
    bool? isSuper,
  }) {
    _currentUserCompanyId = companyId;
    _currentUserIsSuper = isSuper;
    _mounted = true;
    _initialized = true;
    
    // Start listening to society events
    _listenToSocietyEvents();
  }

  // ✅ NEW: Listen to society changes from Settings
 // ✅ FIXED: Listen to society changes with proper handling
void _listenToSocietyEvents() {
  _societyEventSubscription = SocietyEventService().onSocietyChanged.listen((event) async {
    debugPrint('InventoryViewModel: Society event received: ${event.type}');
    
    // ✅ CRITICAL: Handle delete event specially
    if (event.type == SocietyEventType.deleted) {
      final deletedId = event.data['id'];
      debugPrint('InventoryViewModel: Society deleted - ID: $deletedId');
      
      // ✅ If selected society was deleted, clear selection
      if (_selectedSocietyId == deletedId) {
        debugPrint('InventoryViewModel: Selected society was deleted, clearing selection');
        _selectedSocietyId = null;
        _selectedBlockId = null;
        _blocks = [];
      }
    }
    
    // ✅ Refresh societies
    await loadSocieties(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    
    // ✅ If society was created/updated, also refresh items
    if (event.type == SocietyEventType.created || event.type == SocietyEventType.updated) {
      await loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }, onError: (error) {
    debugPrint('InventoryViewModel: Error in society event stream: $error');
  });
}

  // Getters
  List<InventoryItem> get allItems => _allItems;
  List<InventoryItem> get filteredItems => _filteredItems;
  List<Map<String, String>> get societies => _societies;
  List<Map<String, String>> get blocks => _blocks;
  bool get isLoading => _isLoading;
  bool get isLoadingSocieties => _isLoadingSocieties;
  bool get isLoadingBlocks => _isLoadingBlocks;
  bool get initialized => _initialized;
  InventoryType get selectedType => _selectedType;
  String get searchQuery => _searchQuery;
  String? get selectedSocietyId => _selectedSocietyId;
  String? get selectedBlockId => _selectedBlockId;
  String? get selectedStatusFilter => _selectedStatusFilter;
  InventoryRepository get repository => _inventoryRepository;
  bool get mounted => _mounted;
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_filteredItems.length / _itemsPerPage).ceil();
  List<InventoryItem> get paginatedItems {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return _filteredItems.skip(startIndex).take(_itemsPerPage).toList();
  }

  // Load all data
  Future<void> loadAllData({String? companyId, bool? isSuper}) async {
    await loadSocieties(companyId: companyId, isSuper: isSuper);
    await loadItems(companyId: companyId, isSuper: isSuper);
  }

  // Load items based on current filters
  Future<void> loadItems({String? companyId, bool? isSuper}) async {
    debugPrint('InventoryViewModel: loadItems called - companyId: $companyId, isSuper: $isSuper');
    _isLoading = true;
    notifyListeners();
    
    try {
      final effectiveCompanyId = companyId ?? _currentUserCompanyId;
      final effectiveIsSuper = isSuper ?? _currentUserIsSuper;
      
      debugPrint('InventoryViewModel: Effective context - companyId: $effectiveCompanyId, isSuper: $effectiveIsSuper');
      debugPrint('InventoryViewModel: Filters - type: $_selectedType, society: $_selectedSocietyId, block: $_selectedBlockId, status: $_selectedStatusFilter, search: $_searchQuery');
      
      _allItems = await _inventoryRepository.getFilteredItems(
        type: _selectedType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        societyId: _selectedSocietyId,
        blockId: _selectedBlockId,
        statusFilter: _selectedStatusFilter,
        companyId: effectiveCompanyId,
      );
      
      debugPrint('InventoryViewModel: Repository returned ${_allItems.length} items');
      _filteredItems = _allItems;
    } catch (e) {
      debugPrint('Error loading inventory items: $e');
      _allItems = [];
      _filteredItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load societies
  Future<void> loadSocieties({String? companyId, bool? isSuper}) async {
    _isLoadingSocieties = true;
    notifyListeners();
    
    try {
      await _societiesSubscription?.cancel();
      _societiesSubscription = null;
      
      final rawData = await _settingsRepository.getSocieties();
      debugPrint('InventoryViewModel: Repository returned ${rawData.length} raw societies');
      
      _societies = List<Map<String, String>>.from(rawData.map((item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
      }));
      
      debugPrint('InventoryViewModel: Final societies list: ${_societies.map((s) => '${s['id']}:${s['name']}').toList()}');
      
      _isLoadingSocieties = false;
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error loading societies: $e');
      _societies = [];
      _isLoadingSocieties = false;
      notifyListeners();
    }
  }

  // Load blocks
  Future<void> loadBlocks({String? societyId}) async {
    _isLoadingBlocks = true;
    notifyListeners();
    
    try {
      await _blocksSubscription?.cancel();
      _blocksSubscription = null;
      
      final rawData = societyId != null 
          ? await _settingsRepository.getBlocksBySociety(societyId)
          : await _settingsRepository.getBlocks();
      
      _blocks = List<Map<String, String>>.from(rawData.map((item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        if (item.containsKey('society_id')) 
          'society_id': item['society_id']?.toString() ?? '',
      }));
      
      _isLoadingBlocks = false;
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      notifyListeners();
    }
  }

  // Filter methods
  void setSelectedType(InventoryType type) {
    if (_selectedType != type) {
      _selectedType = type;
      _resetFilters();
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _currentPage = 1;
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }

  void setSelectedSociety(String? societyId) {
    debugPrint('InventoryViewModel: setSelectedSociety called with societyId: $societyId');
    if (_selectedSocietyId != societyId) {
      _selectedSocietyId = societyId;
      debugPrint('InventoryViewModel: Updated _selectedSocietyId to: $_selectedSocietyId');
      
      if (societyId == null || societyId.isEmpty || societyId == 'All') {
        _selectedBlockId = null;
        _blocks = [];
        debugPrint('InventoryViewModel: "All Society" selected - cleared blocks and block selection');
        
        notifyListeners();
        
        _currentPage = 1;
        loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
        return;
      }
      
      _selectedBlockId = null;
      _blocks = [];
      
      notifyListeners();
      
      debugPrint('InventoryViewModel: Loading blocks for society: $societyId');
      _loadBlocksForSociety(societyId).then((_) {
        notifyListeners();
        debugPrint('InventoryViewModel: Blocks loaded for society: $societyId');
      });
      
      _currentPage = 1;
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    } else {
      debugPrint('InventoryViewModel: SocietyId is the same, no action taken');
    }
  }

  // Helper method to load blocks for a specific society
  Future<void> _loadBlocksForSociety(String societyId) async {
    debugPrint('InventoryViewModel: _loadBlocksForSociety called with societyId: $societyId');
    try {
      _isLoadingBlocks = true;
      notifyListeners();
      
      debugPrint('InventoryViewModel: Calling getBlocksBySociety from repository');
      final rawData = await _settingsRepository.getBlocksBySociety(societyId);
      debugPrint('InventoryViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      _blocks = List<Map<String, String>>.from(rawData.map((item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        if (item.containsKey('society_id')) 
          'society_id': item['society_id']?.toString() ?? '',
      }));
      
      debugPrint('InventoryViewModel: Type-safe mapping completed, blocks count: ${_blocks.length}');
      debugPrint('InventoryViewModel: Final blocks list: $_blocks');
      
      _isLoadingBlocks = false;
      notifyListeners();
      debugPrint('InventoryViewModel: Blocks updated, notified listeners');
      
    } catch (e) {
      debugPrint('Error loading blocks for society $societyId: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      notifyListeners();
    }
  }

  void setSelectedBlock(String? blockId) {
    debugPrint('InventoryViewModel: setSelectedBlock called with blockId: $blockId');
    debugPrint('InventoryViewModel: Current _selectedBlockId: $_selectedBlockId');
    
    if (_selectedBlockId != blockId) {
      _selectedBlockId = blockId;
      debugPrint('InventoryViewModel: Updated _selectedBlockId to: $_selectedBlockId');
      notifyListeners();
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    } else {
      debugPrint('InventoryViewModel: BlockId is the same, no action taken');
    }
  }

  void setSelectedStatusFilter(String? status) {
    if (_selectedStatusFilter != status) {
      _selectedStatusFilter = status;
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }

  void clearAllFilters() {
    _resetFilters();
    loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
  }

  void _resetFilters() {
    _selectedSocietyId = null;
    _selectedBlockId = null;
    _selectedStatusFilter = null;
    _searchQuery = '';
  }

  // CRUD operations
  Future<void> saveItem(InventoryItem item) async {
    try {
      if (_allItems.any((existing) => existing.id == item.id)) {
        await _inventoryRepository.updateItem(item);
      } else {
        await _inventoryRepository.addItem(item);
      }
      await loadItems(companyId: null, isSuper: null);
    } catch (e) {
      debugPrint('Error saving inventory item: $e');
      rethrow;
    }
  }

  Future<void> updateItem(String id, InventoryItem item) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _inventoryRepository.updateItem(item);
      
      _allItems = await _inventoryRepository.getFilteredItems(
        type: _selectedType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        societyId: _selectedSocietyId,
        blockId: _selectedBlockId,
        statusFilter: _selectedStatusFilter,
      );
      _filteredItems = _allItems;
      
      _currentPage = 1;
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('InventoryViewModel: Item updated successfully, UI refreshed');
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _inventoryRepository.deleteItem(id);
      
      _allItems = await _inventoryRepository.getFilteredItems(
        type: _selectedType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        societyId: _selectedSocietyId,
        blockId: _selectedBlockId,
        statusFilter: _selectedStatusFilter,
        companyId: null,
      );
      _filteredItems = _allItems;
      
      _currentPage = 1;
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('InventoryViewModel: Item deleted successfully, UI refreshed');
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Utility methods
  InventoryItem? findItemById(String id) {
    try {
      return _allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  List<InventoryItem> getItemsByType(InventoryType type) {
    return _allItems.where((item) => item.type == type).toList();
  }

  List<Map<String, String>> getAvailableBlocks() {
    final availableBlocks = _selectedSocietyId == null 
        ? _blocks 
        : _blocks.where((block) {
            final blockId = block['id'] ?? '';
            return blockId.contains('$_selectedSocietyId\_');
          }).toList();
    
    return availableBlocks;
  }

  void forceRefresh() {
    debugPrint('InventoryViewModel: Force refresh called');
    notifyListeners();
  }

  bool get hasActiveFilters {
    return _selectedSocietyId != null ||
           _selectedBlockId != null ||
           _selectedStatusFilter != null ||
           _searchQuery.isNotEmpty;
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
      _currentPage = 1;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _societiesSubscription?.cancel();
    _blocksSubscription?.cancel();
    _societyEventSubscription?.cancel(); // ✅ Cancel event subscription
    super.dispose();
  }
}