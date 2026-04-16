// presentation/inventory/inventory_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../models/inventory_item.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/inventory_repository_impl.dart';
import '../../settings/repositories/society_repository.dart';
import '../../settings/repositories/settings_repository.dart';

class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _inventoryRepository;
  final SettingsRepository _settingsRepository;
  
  // User context for RBAC
  String? _currentUserCompanyId;
  bool? _currentUserIsSuper;
  
  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filteredItems = [];
  List<Map<String, String>> _societies = [];
  List<Map<String, String>> _blocks = [];
  bool _isLoading = false;
  bool _isLoadingSocieties = false;
  bool _isLoadingBlocks = false;
  bool _initialized = false;
  bool _mounted = false;
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifyListeners();
    });
  }

  bool get mounted => _mounted;
  
  // Stream subscriptions
  StreamSubscription<List<Map<String, String>>>? _societiesSubscription;
  StreamSubscription<List<Map<String, String>>>? _blocksSubscription;
  
  // Filter state
  InventoryType _selectedType = InventoryType.file;
  String _searchQuery = '';
  String? _selectedSocietyId;
  String? _selectedBlockId;
  String? _selectedStatusFilter;

  InventoryViewModel(this._inventoryRepository, this._settingsRepository, {String? companyId, bool? isSuper}) {
    _currentUserCompanyId = companyId;
    _currentUserIsSuper = isSuper;
    _mounted = true;
    _initialized = true;
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
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_filteredItems.length / _itemsPerPage).ceil();
  List<InventoryItem> get paginatedItems {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return _filteredItems.skip(startIndex).take(_itemsPerPage).toList();
  }

  // Load all data with proper parameters
  Future<void> loadAllData({String? companyId, bool? isSuper}) async {
    await Future.wait([
      loadItems(companyId: companyId, isSuper: isSuper),
      loadSocieties(companyId: companyId, isSuper: isSuper),
    ]);
  }

  // Load items based on current filters
  Future<void> loadItems({String? companyId, bool? isSuper}) async {
    debugPrint('InventoryViewModel: loadItems called - companyId: $companyId, isSuper: $isSuper');
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifyListeners();
    });
    
    try {
      // Use provided parameters or fall back to stored user context
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
        companyId: effectiveCompanyId, // Use effective company context
      );
      
      debugPrint('InventoryViewModel: Repository returned ${_allItems.length} items');
      _filteredItems = _allItems;
    } catch (e) {
      debugPrint('Error loading inventory items: $e');
      _allItems = [];
      _filteredItems = [];
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
    }
  }

  // Load societies using Future-based approach for now
  Future<void> loadSocieties({String? companyId, bool? isSuper}) async {
    _isLoadingSocieties = true;
    
    // Force immediate UI refresh with microtask
    Future.microtask(() {
      if (!mounted) return;
      notifyListeners();
    });
    
    try {
      // Cancel existing subscription if any
      await _societiesSubscription?.cancel();
      _societiesSubscription = null;
      
      // Use Future-based approach for now to avoid stream type issues
      final rawData = await _settingsRepository.getSocieties();
      debugPrint('InventoryViewModel: Repository returned ${rawData.length} raw societies: $rawData');
      
      // Fix the "Non-subtype" Error: Use type-safe mapping logic
      _societies = List<Map<String, String>>.from(rawData.map((item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
      }));
      
      debugPrint('InventoryViewModel: Type-safe societies mapping completed, societies count: ${_societies.length}');
      debugPrint('InventoryViewModel: Final societies list: ${_societies.map((s) => '${s['id']}:${s['name']}').toList()}');
      
      // REMOVED AUTO-SELECTION: Do not auto-select any society
      // _selectedSocietyId should remain null to show "All Society" by default
      
      _isLoadingSocieties = false;
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
        debugPrint('InventoryViewModel: Societies loaded and UI refreshed');
      });
    } catch (e) {
      debugPrint('Error loading societies: $e');
      _societies = [];
      _isLoadingSocieties = false;
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
      });
    }
  }

  // Load blocks using Future-based approach for now
  Future<void> loadBlocks({String? societyId}) async {
    _isLoadingBlocks = true;
    
    // Force immediate UI refresh with microtask
    Future.microtask(() {
      if (!mounted) return;
      notifyListeners();
    });
    
    try {
      // Cancel existing subscription if any
      await _blocksSubscription?.cancel();
      _blocksSubscription = null;
      
      // Use Future-based approach for now to avoid stream type issues
      final rawData = societyId != null 
          ? await _settingsRepository.getBlocksBySociety(societyId)
          : await _settingsRepository.getBlocks();
      
      debugPrint('InventoryViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      // Fix the "Non-subtype" Error: Use type-safe mapping logic
      _blocks = List<Map<String, String>>.from(rawData.map((item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        if (item.containsKey('society_id')) 
          'society_id': item['society_id']?.toString() ?? '',
      }));
      
      debugPrint('InventoryViewModel: Type-safe blocks mapping completed, blocks count: ${_blocks.length}');
      debugPrint('InventoryViewModel: Final blocks list: $_blocks');
      
      _isLoadingBlocks = false;
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
        debugPrint('InventoryViewModel: Blocks loaded and UI refreshed');
      });
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
      });
    }
  }

  // Filter methods
  void setSelectedType(InventoryType type) {
    if (_selectedType != type) {
      _selectedType = type;
      _resetFilters();
      // Pass stored user context to loadItems
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _currentPage = 1; // Reset to page 1 when search changes
      // Pass stored user context to loadItems
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }

  void setSelectedSociety(String? societyId) {
    debugPrint('InventoryViewModel: setSelectedSociety called with societyId: $societyId');
    if (_selectedSocietyId != societyId) {
      // 1. Update the selected society ID
      _selectedSocietyId = societyId;
      debugPrint('InventoryViewModel: Updated _selectedSocietyId to: $_selectedSocietyId');
      
      // CRITICAL FIX: Reset Blocks if "All Society" is selected
      if (societyId == null || societyId.isEmpty || societyId == 'All') {
        _selectedBlockId = null; // Clear selected block
        _blocks = []; // Clear the blocks list
        debugPrint('InventoryViewModel: "All Society" selected - cleared blocks and block selection');
        
        // Notify listeners and refresh items
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          notifyListeners();
        });
        
        // Load items without block filter
      _currentPage = 1; // Reset to page 1 when filter changes
      // Pass stored user context to loadItems
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
        return;
      }
      
      // If a specific society IS selected:
      _selectedBlockId = null; // Reset block selection
      _blocks = []; // Clear blocks list temporarily
      
      // Immediately call notifyListeners() to show loading state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      
      // Load blocks for the specific society
      debugPrint('InventoryViewModel: Loading blocks for society: $societyId');
      _loadBlocksForSociety(societyId).then((_) {
        // Additional notification after blocks are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          notifyListeners();
        });
        debugPrint('InventoryViewModel: Blocks loaded for society: $societyId');
      });
      
      // Load items with new filters
      _currentPage = 1; // Reset to page 1 when filter changes
      // Pass stored user context to loadItems
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
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
      });
      
      debugPrint('InventoryViewModel: Calling getBlocksBySociety from repository');
      // Use repository to get blocks for the specific society
      final rawData = await _settingsRepository.getBlocksBySociety(societyId);
      debugPrint('InventoryViewModel: Repository returned ${rawData.length} raw blocks: $rawData');
      
      // Fix the "Non-subtype" Error: Use type-safe mapping logic
      _blocks = List<Map<String, String>>.from(rawData.map((item) => {
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        if (item.containsKey('society_id')) 
          'society_id': item['society_id']?.toString() ?? '',
      }));
      
      debugPrint('InventoryViewModel: Type-safe mapping completed, blocks count: ${_blocks.length}');
      debugPrint('InventoryViewModel: Final blocks list: $_blocks');
      
      _isLoadingBlocks = false;
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
        debugPrint('InventoryViewModel: Blocks updated, notified listeners');
      });
    } catch (e) {
      debugPrint('Error loading blocks for society $societyId: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      
      // Force immediate UI refresh with microtask
      Future.microtask(() {
        if (!mounted) return;
        notifyListeners();
      });
    }
  }

  void setSelectedBlock(String? blockId) {
    debugPrint('InventoryViewModel: setSelectedBlock called with blockId: $blockId');
    debugPrint('InventoryViewModel: Current _selectedBlockId: $_selectedBlockId');
    
    if (_selectedBlockId != blockId) {
      _selectedBlockId = blockId;
      debugPrint('InventoryViewModel: Updated _selectedBlockId to: $_selectedBlockId');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners(); // Immediate UI update for block change
      });
      // Pass stored user context to loadItems
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    } else {
      debugPrint('InventoryViewModel: BlockId is the same, no action taken');
    }
  }

  void setSelectedStatusFilter(String? status) {
    if (_selectedStatusFilter != status) {
      _selectedStatusFilter = status;
      // Pass stored user context to loadItems
      loadItems(companyId: _currentUserCompanyId, isSuper: _currentUserIsSuper);
    }
  }

  void clearAllFilters() {
    _resetFilters();
    // Pass stored user context to loadItems
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
      await loadItems(companyId: null, isSuper: null); // Reload to reflect changes
    } catch (e) {
      debugPrint('Error saving inventory item: $e');
      rethrow; // Let UI handle error
    }
  }

  Future<void> updateItem(String id, InventoryItem item) async {
    try {
      // CRITICAL: Set loading state immediately to prevent UI flicker
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      
      // Update from repository
      await _inventoryRepository.updateItem(item);
      
      // CRITICAL: Manual refresh - fetch updated list immediately
      _allItems = await _inventoryRepository.getFilteredItems(
        type: _selectedType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        societyId: _selectedSocietyId,
        blockId: _selectedBlockId,
        statusFilter: _selectedStatusFilter,
      );
      _filteredItems = _allItems;
      
      // Reset pagination to first page after update
      _currentPage = 1;
      
      // CRITICAL: Notify listeners to update UI instantly
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      
      debugPrint('InventoryViewModel: Item updated successfully, UI refreshed');
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      rethrow; // Let UI handle error
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      // CRITICAL: Set loading state immediately to prevent UI flicker
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      
      // Delete from repository
      await _inventoryRepository.deleteItem(id);
      
      // CRITICAL: Manual refresh - fetch updated list immediately
      _allItems = await _inventoryRepository.getFilteredItems(
        type: _selectedType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        societyId: _selectedSocietyId,
        blockId: _selectedBlockId,
        statusFilter: _selectedStatusFilter,
        companyId: null, // Pass company context
      );
      _filteredItems = _allItems;
      
      // Reset pagination to first page after deletion
      _currentPage = 1;
      
      // CRITICAL: Notify listeners to update UI instantly
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      
      debugPrint('InventoryViewModel: Item deleted successfully, UI refreshed');
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      rethrow; // Let UI handle error
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

  // Get available blocks for selected society
  List<Map<String, String>> getAvailableBlocks() {
    final availableBlocks = _selectedSocietyId == null 
        ? _blocks 
        : _blocks.where((block) {
            // Extract society_id from block ID: blk_soc_[society_id]_[block_name]_[timestamp]
            final blockId = block['id'] ?? '';
            return blockId.contains('$_selectedSocietyId\_');
          }).toList();
    
        
    return availableBlocks;
  }

  // Force refresh method for debugging
  void forceRefresh() {
    debugPrint('InventoryViewModel: Force refresh called');
    Future.microtask(() {
      if (!mounted) return;
      notifyListeners();
    });
  }

  // Check if any filters are active
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
      _currentPage = 1; // Reset to page 1 when items per page changes
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    // Cancel stream subscriptions to prevent memory leaks
    _societiesSubscription?.cancel();
    _blocksSubscription?.cancel();
    super.dispose();
  }
}
