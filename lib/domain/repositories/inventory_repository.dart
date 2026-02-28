// domain/repositories/inventory_repository.dart
import '../models/inventory_item.dart';

abstract class InventoryRepository {
  // Get all items (both files and properties)
  Future<List<InventoryItem>> getAllItems();
  
  // Get items by type
  Future<List<InventoryItem>> getItemsByType(InventoryType type);
  
  // Get filtered items with search and filters
  Future<List<InventoryItem>> getFilteredItems({
    InventoryType? type,
    String? searchQuery,
    String? societyId,
    String? blockId,
    String? statusFilter,
  });
  
  // Add new item
  Future<void> addItem(InventoryItem item);
  
  // Update existing item
  Future<void> updateItem(InventoryItem item);
  
  // Delete item (soft delete)
  Future<void> deleteItem(String id);
}
