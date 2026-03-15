// presentation/inventory/inventory_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../inventory/models/inventory_item.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/inventory_repository_impl.dart';
import '../settings/repositories/society_repository.dart';
import '../settings/repositories/settings_repository.dart';

class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _inventoryRepository;
  final SettingsRepository _settingsRepository;
  
  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filteredItems = [];
  List<Map<String, String>> _societies = [];
  List<Map<String, String>> _blocks = [];
  bool _isLoading = false;
  bool _isLoadingSocieties = false;
  bool _isLoadingBlocks = false;
  bool _initialized = false;
  bool _mounted = false;
  
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

  InventoryViewModel(this._inventoryRepository, this._settingsRepository) {
    _initialized = true;
    _mounted = true;
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

  // Load all data with proper parameters
  Future<void> loadAllData({String? companyId, bool? isSuper}) async {
    await Future.wait([
      loadItems(),
      loadSocieties(companyId: companyId, isSuper: isSuper),
    ]);
  }

  // Load items based on current filters
  Future<void> loadItems() async {
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifyListeners();
    });
    
    try {
      _allItems = await _inventoryRepository.getFilteredItems(
        type: _selectedType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        societyId: _selectedSocietyId,
        blockId: _selectedBlockId,
        statusFilter: _selectedStatusFilter,
      );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      
      // AUTO-SELECTION: If there is only one society and no society is currently selected, auto-select it
      if (_societies.length == 1 && _selectedSocietyId == null) {
        final singleSociety = _societies.first;
        debugPrint('InventoryViewModel: Auto-selecting single society: ${singleSociety['name']} (${singleSociety['id']})');
        setSelectedSociety(singleSociety['id']);
      }
      
      _isLoadingSocieties = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error loading societies: $e');
      _societies = [];
      _isLoadingSocieties = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
    }
  }

  // Load blocks using Future-based approach for now
  Future<void> loadBlocks({String? societyId}) async {
    _isLoadingBlocks = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      loadItems();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      loadItems();
    }
  }

  void setSelectedSociety(String? societyId) {
    debugPrint('InventoryViewModel: setSelectedSociety called with societyId: $societyId');
    if (_selectedSocietyId != societyId) {
      // 1. Update the selected society ID
      _selectedSocietyId = societyId;
      debugPrint('InventoryViewModel: Updated _selectedSocietyId to: $_selectedSocietyId');
      
      // 2. Clear the existing blocks list and immediately call notifyListeners() 
      // so the UI shows the "Loading..." state in the Block dropdown
      _blocks = [];
      _selectedBlockId = null; // Reset block selection when society changes
      debugPrint('InventoryViewModel: Cleared blocks list and block selection');
      
      // 3. Immediately call notifyListeners() to show loading state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      debugPrint('InventoryViewModel: Notified listeners after clearing blocks');
      
      // 4. If societyId is not null, await fresh blocks from repository and notify again
      if (societyId != null) {
        debugPrint('InventoryViewModel: SocietyId is not null, calling _loadBlocksForSociety');
        _loadBlocksForSociety(societyId).then((_) {
          // Additional notification after blocks are loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            notifyListeners();
          });
          debugPrint('InventoryViewModel: Additional notification after blocks loaded');
        });
      } else {
        debugPrint('InventoryViewModel: SocietyId is null, not loading blocks');
      }
      
      // Load items with new filters
      loadItems();
    } else {
      debugPrint('InventoryViewModel: SocietyId is the same, no action taken');
    }
  }

  // Helper method to load blocks for a specific society
  Future<void> _loadBlocksForSociety(String societyId) async {
    debugPrint('InventoryViewModel: _loadBlocksForSociety called with societyId: $societyId');
    try {
      _isLoadingBlocks = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifyListeners();
      });
      debugPrint('InventoryViewModel: Blocks updated, notified listeners');
    } catch (e) {
      debugPrint('Error loading blocks for society $societyId: $e');
      _blocks = [];
      _isLoadingBlocks = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      loadItems();
    } else {
      debugPrint('InventoryViewModel: BlockId is the same, no action taken');
    }
  }

  void setSelectedStatusFilter(String? status) {
    if (_selectedStatusFilter != status) {
      _selectedStatusFilter = status;
      loadItems();
    }
  }

  void clearAllFilters() {
    _resetFilters();
    loadItems();
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
      await loadItems(); // Reload to reflect changes
    } catch (e) {
      debugPrint('Error saving inventory item: $e');
      rethrow; // Let UI handle error
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _inventoryRepository.deleteItem(id);
      await loadItems(); // Reload to reflect changes
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
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
    debugPrint('InventoryViewModel: getAvailableBlocks - selectedSocietyId: $_selectedSocietyId, total blocks: ${_blocks.length}, available blocks: ${availableBlocks.length}');
    debugPrint('InventoryViewModel: Available blocks: ${availableBlocks.map((b) => '${b['id']}:${b['name']}').toList()}');
    return availableBlocks;
  }

  // Check if any filters are active
  bool get hasActiveFilters {
    return _selectedSocietyId != null ||
           _selectedBlockId != null ||
           _selectedStatusFilter != null ||
           _searchQuery.isNotEmpty;
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
