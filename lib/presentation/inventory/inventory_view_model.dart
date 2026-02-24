// presentation/inventory/inventory_view_model.dart
import 'package:flutter/foundation.dart';
import '../../domain/models/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';

class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _repository;
  
  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filteredItems = [];
  List<Map<String, String>> _societies = [];
  List<Map<String, String>> _blocks = [];
  bool _isLoading = false;
  bool _isLoadingSocieties = false;
  bool _isLoadingBlocks = false;
  bool _initialized = false;
  
  // Filter state
  InventoryType _selectedType = InventoryType.file;
  String _searchQuery = '';
  String? _selectedSocietyId;
  String? _selectedBlockId;
  String? _selectedStatusFilter;

  InventoryViewModel(this._repository) {
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
  InventoryRepository get repository => _repository;

  // Load all data
  Future<void> loadAllData() async {
    await Future.wait([
      loadItems(),
      loadSocieties(),
    ]);
  }

  // Load items based on current filters
  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _allItems = await _repository.getFilteredItems(
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
      notifyListeners();
    }
  }

  // Load societies
  Future<void> loadSocieties() async {
    _isLoadingSocieties = true;
    notifyListeners();
    
    try {
      _societies = await _repository.getSocieties();
    } catch (e) {
      debugPrint('Error loading societies: $e');
      _societies = [];
    } finally {
      _isLoadingSocieties = false;
      notifyListeners();
    }
  }

  // Load blocks (all or by society)
  Future<void> loadBlocks({String? societyId}) async {
    _isLoadingBlocks = true;
    notifyListeners();
    
    try {
      if (societyId != null) {
        _blocks = await _repository.getBlocksBySociety(societyId);
      } else {
        _blocks = await _repository.getBlocks();
      }
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      _blocks = [];
    } finally {
      _isLoadingBlocks = false;
      notifyListeners();
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
    if (_selectedSocietyId != societyId) {
      _selectedSocietyId = societyId;
      _selectedBlockId = null; // Reset block when society changes
      loadBlocks(societyId: societyId);
      loadItems();
    }
  }

  void setSelectedBlock(String? blockId) {
    if (_selectedBlockId != blockId) {
      _selectedBlockId = blockId;
      loadItems();
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
        await _repository.updateItem(item);
      } else {
        await _repository.addItem(item);
      }
      await loadItems(); // Reload to reflect changes
    } catch (e) {
      debugPrint('Error saving inventory item: $e');
      rethrow; // Let UI handle error
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repository.deleteItem(id);
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
    if (_selectedSocietyId == null) return _blocks;
    return _blocks.where((block) => block['society_id'] == _selectedSocietyId).toList();
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
    super.dispose();
  }
}
