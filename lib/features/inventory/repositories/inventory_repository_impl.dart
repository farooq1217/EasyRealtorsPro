// data/repositories/inventory_repository_impl.dart
import '../../inventory/models/inventory_item.dart';
import 'inventory_repository.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final dynamic db;
  final String? companyId;
  final bool isSuperAdmin;
  
  InventoryRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin});

  @override
  Future<List<InventoryItem>> getAllItems({String? companyId}) async {
    try {
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      // Get both files and properties
      final filesResult = await _getFiles(companyId: effectiveCompanyId);
      final propertiesResult = await _getProperties(companyId: effectiveCompanyId);
      
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
  Future<List<InventoryItem>> getItemsByType(InventoryType type, {String? companyId}) async {
    try {
      // Use provided companyId or fall back to instance companyId
      final effectiveCompanyId = companyId ?? this.companyId;
      
      if (type == InventoryType.file) {
        return await _getFiles(companyId: effectiveCompanyId);
      } else {
        return await _getProperties(companyId: effectiveCompanyId);
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
    String? companyId,
  }) async {
    try {
      List<InventoryItem> items;
      
      if (type != null) {
        items = await getItemsByType(type, companyId: companyId);
      } else {
        items = await getAllItems(companyId: companyId);
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
      
      // CRITICAL FIX: Enforce companyId for non-super-admins to prevent data leakage
      final itemCompanyId = map['company_id']?.toString();
      if (!isSuperAdmin) {
        if (itemCompanyId == null || itemCompanyId.isEmpty) {
          throw Exception('Security Error: Company ID is required for inventory items');
        }
        // For non-super-admins, ensure the item belongs to their company
        if (companyId?.isNotEmpty == true && itemCompanyId != companyId) {
          throw Exception('Security Error: Cannot add items to other companies');
        }
        debugPrint('InventoryRepository: SECURITY - Adding item to company: $itemCompanyId');
      }
      
      if (item.type == InventoryType.file) {
        await db.customStatement('''
          INSERT INTO files_table (
            id, name, client_name, file_no, reference_no, mobile_no, 
            society_id, block_id, sale_status, path, remarks, cnic,
            updated_at, company_id, is_active, created_by
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
        ''', [
          map['id'], map['name'], map['client_name'], map['file_no'], 
          map['reference_no'], map['mobile_no'], map['society_id'], 
          map['block_id'], map['sale_status'], map['path'], 
          map['remarks'], map['cnic'], map['updated_at'], map['company_id'], 
          map['created_by'] ?? ''
        ]);
      } else {
        await db.customStatement('''
          INSERT INTO properties (
            id, client_name, reference_no, property_name, demand, price,
            society_id, block_id, sale_status, remarks, cnic,
            updated_at, company_id, is_active, created_by
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
        ''', [
          map['id'], map['client_name'], map['reference_no'], 
          map['property_name'], map['demand'], map['price'],
          map['society_id'], map['block_id'], map['sale_status'], 
          map['remarks'], map['cnic'], map['updated_at'], map['company_id'], 
          map['created_by'] ?? ''
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
  Future<List<InventoryItem>> _getFiles({String? companyId}) async {
    try {
      debugPrint('InventoryRepository: _getFiles called - companyId: $companyId, isSuperAdmin: $isSuperAdmin');
      String whereClause = 'WHERE is_active = 1';
      List<dynamic> whereArgs = [];
      
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (companyId == null || companyId.isEmpty) {
          debugPrint('InventoryRepository: SECURITY - No companyId for non-super-admin, returning empty results');
          return []; // Return empty list for security
        }
        whereClause += ' AND company_id = ?';
        whereArgs.add(companyId);
        debugPrint('InventoryRepository: SECURITY - Filtering files by company: $companyId');
      }
      // Super Admin: No company filtering (can see all data)
      
      final query = '''
        SELECT * FROM files_table 
        $whereClause
        ORDER BY updated_at DESC
      ''';
      debugPrint('InventoryRepository: Executing files query: $query');
      debugPrint('InventoryRepository: Query args: ${whereArgs.map((arg) => arg.toString()).toList()}');
      
      final result = await db.customSelect(query, variables: <d.Variable<Object>>[...whereArgs.map((arg) => d.Variable.withString(arg.toString()))]).get();
      debugPrint('InventoryRepository: Files query returned ${result.length} rows');
      
      // Explicit type-safe mapping
      final List<InventoryItem> items = [];
      for (final row in result) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row.data);
        final item = InventoryItem.fromMap(data, InventoryType.file);
        items.add(item);
      }
      
      return items;
    } catch (e) {
      debugPrint('Error in _getFiles: $e');
      rethrow;
    }
  }

  Future<List<InventoryItem>> _getProperties({String? companyId}) async {
    try {
      debugPrint('InventoryRepository: _getProperties called - companyId: $companyId, isSuperAdmin: $isSuperAdmin');
      String whereClause = 'WHERE is_active = 1';
      List<dynamic> whereArgs = [];
      
      // CRITICAL FIX: Strict company filtering for data leakage prevention
      if (!isSuperAdmin) {
        // For non-super-admins, ALWAYS require companyId and never allow null
        if (companyId == null || companyId.isEmpty) {
          debugPrint('InventoryRepository: SECURITY - No companyId for non-super-admin, returning empty results');
          return []; // Return empty list for security
        }
        whereClause += ' AND company_id = ?';
        whereArgs.add(companyId);
        debugPrint('InventoryRepository: SECURITY - Filtering properties by company: $companyId');
      }
      // Super Admin: No company filtering (can see all data)
      
      final query = '''
        SELECT * FROM properties 
        $whereClause
        ORDER BY updated_at DESC
      ''';
      debugPrint('InventoryRepository: Executing properties query: $query');
      debugPrint('InventoryRepository: Query args: ${whereArgs.map((arg) => arg.toString()).toList()}');
      
      final result = await db.customSelect(query, variables: <d.Variable<Object>>[...whereArgs.map((arg) => d.Variable.withString(arg.toString()))]).get();
      debugPrint('InventoryRepository: Properties query returned ${result.length} rows');
      
      // Explicit type-safe mapping
      final List<InventoryItem> items = [];
      for (final row in result) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row.data);
        final item = InventoryItem.fromMap(data, InventoryType.property);
        items.add(item);
      }
      
      return items;
    } catch (e) {
      debugPrint('Error in _getProperties: $e');
      rethrow;
    }
  }
}
