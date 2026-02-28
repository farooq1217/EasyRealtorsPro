// data/repositories/inventory_repository_impl.dart
import '../../domain/models/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final dynamic db;
  final String? companyId;
  final bool isSuperAdmin;
  
  InventoryRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin});

  @override
  Future<List<InventoryItem>> getAllItems() async {
    try {
      // Get both files and properties
      final filesResult = await _getFiles();
      final propertiesResult = await _getProperties();
      
      // Combine and sort by updated_at
      final allItems = [...filesResult, ...propertiesResult];
      allItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return allItems;
    } catch (e) {
      debugPrint('Error loading all inventory items: $e');
      return [];
    }
  }

  @override
  Future<List<InventoryItem>> getItemsByType(InventoryType type) async {
    try {
      if (type == InventoryType.file) {
        return await _getFiles();
      } else {
        return await _getProperties();
      }
    } catch (e) {
      debugPrint('Error loading items by type $type: $e');
      return [];
    }
  }

  @override
  Future<List<InventoryItem>> getFilteredItems({
    InventoryType? type,
    String? searchQuery,
    String? societyId,
    String? blockId,
    String? statusFilter,
  }) async {
    try {
      List<InventoryItem> items;
      
      if (type != null) {
        items = await getItemsByType(type);
      } else {
        items = await getAllItems();
      }

      // Apply filters
      if (societyId != null) {
        items = items.where((item) => item.societyId == societyId).toList();
      }

      if (blockId != null) {
        items = items.where((item) => item.blockId == blockId).toList();
      }

      if (statusFilter != null) {
        items = items.where((item) => item.saleStatus == statusFilter).toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        items = items.where((item) {
          return item.clientName.toLowerCase().contains(query) ||
                 item.referenceNo.toLowerCase().contains(query) ||
                 (item.fileNo?.toLowerCase().contains(query) ?? false) ||
                 (item.mobileNo?.toLowerCase().contains(query) ?? false) ||
                 (item.propertyName?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      return items;
    } catch (e) {
      debugPrint('Error filtering inventory items: $e');
      return [];
    }
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    try {
      final map = item.toMap();
      
      if (item.type == InventoryType.file) {
        await db.customStatement('''
          INSERT INTO files_table (
            id, name, client_name, file_no, reference_no, mobile_no, 
            society_id, block_id, sale_status, path, remarks, cnic,
            updated_at, company_id, is_active
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ''', [
          map['id'], map['name'], map['client_name'], map['file_no'], 
          map['reference_no'], map['mobile_no'], map['society_id'], 
          map['block_id'], map['sale_status'], map['path'], 
          map['remarks'], map['cnic'], map['updated_at'], map['company_id']
        ]);
      } else {
        await db.customStatement('''
          INSERT INTO properties (
            id, client_name, reference_no, property_name, demand, price,
            society_id, block_id, sale_status, remarks, cnic,
            updated_at, company_id, is_active
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ''', [
          map['id'], map['client_name'], map['reference_no'], 
          map['property_name'], map['demand'], map['price'],
          map['society_id'], map['block_id'], map['sale_status'], 
          map['remarks'], map['cnic'], map['updated_at'], map['company_id']
        ]);
      }
    } catch (e) {
      debugPrint('Error adding inventory item: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    try {
      final map = item.toMap();
      
      if (item.type == InventoryType.file) {
        await db.customStatement('''
          UPDATE files_table SET 
            client_name = ?, file_no = ?, reference_no = ?, mobile_no = ?,
            society_id = ?, block_id = ?, sale_status = ?, path = ?,
            remarks = ?, cnic = ?, updated_at = ?, company_id = ?
          WHERE id = ?
        ''', [
          map['client_name'], map['file_no'], map['reference_no'], map['mobile_no'],
          map['society_id'], map['block_id'], map['sale_status'], map['path'],
          map['remarks'], map['cnic'], map['updated_at'], map['company_id'], map['id']
        ]);
      } else {
        await db.customStatement('''
          UPDATE properties SET 
            client_name = ?, reference_no = ?, property_name = ?, demand = ?, price = ?,
            society_id = ?, block_id = ?, sale_status = ?, remarks = ?, cnic = ?,
            updated_at = ?, company_id = ?
          WHERE id = ?
        ''', [
          map['client_name'], map['reference_no'], map['property_name'], 
          map['demand'], map['price'], map['society_id'], map['block_id'], 
          map['sale_status'], map['remarks'], map['cnic'], 
          map['updated_at'], map['company_id'], map['id']
        ]);
      }
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    try {
      // Try to delete from both tables (soft delete)
      await db.customStatement('''
        UPDATE files_table SET is_active = 0, updated_at = ? WHERE id = ?
      ''', [DateTime.now().toUtc().toIso8601String(), id]);
      
      await db.customStatement('''
        UPDATE properties SET is_active = 0, updated_at = ? WHERE id = ?
      ''', [DateTime.now().toUtc().toIso8601String(), id]);
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      rethrow;
    }
  }

  // Private helper methods
  Future<List<InventoryItem>> _getFiles() async {
    try {
      final result = await db.customSelect('''
        SELECT * FROM files_table 
        WHERE is_active = 1
        ORDER BY updated_at DESC
      ''').get();
      
      // Explicit type-safe mapping
      final List<InventoryItem> items = [];
      for (final row in result) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row.data);
        final item = InventoryItem.fromMap(data, InventoryType.file);
        items.add(item);
      }
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        return items.where((item) => item.companyId == companyId).toList();
      }
      
      return items;
    } catch (e) {
      debugPrint('Error in _getFiles: $e');
      rethrow;
    }
  }

  Future<List<InventoryItem>> _getProperties() async {
    try {
      final result = await db.customSelect('''
        SELECT * FROM properties 
        WHERE is_active = 1
        ORDER BY updated_at DESC
      ''').get();
      
      // Explicit type-safe mapping
      final List<InventoryItem> items = [];
      for (final row in result) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row.data);
        final item = InventoryItem.fromMap(data, InventoryType.property);
        items.add(item);
      }
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        return items.where((item) => item.companyId == companyId).toList();
      }
      
      return items;
    } catch (e) {
      debugPrint('Error in _getProperties: $e');
      rethrow;
    }
  }
}
