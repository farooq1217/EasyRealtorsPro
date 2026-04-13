// domain/repositories/inventory_repository.dart
import '../../inventory/models/inventory_item.dart';

abstract class InventoryRepository {
  // Get all items (both files and properties) with optional company filtering
  Future<List<InventoryItem>> getAllItems({String? companyId});
  
  // Get items by type with optional company filtering
  Future<List<InventoryItem>> getItemsByType(InventoryType type, {String? companyId});
  
  // Get filtered items with search and filters
  Future<List<InventoryItem>> getFilteredItems({
    InventoryType? type,
    String? searchQuery,
    String? societyId,
    String? blockId,
    String? statusFilter,
    String? companyId,
  });
  
  // Add new item
  Future<void> addItem(InventoryItem item);
  
  // Update existing item
  Future<void> updateItem(InventoryItem item);
  
  // Delete item (soft delete)
  Future<void> deleteItem(String id);
}
