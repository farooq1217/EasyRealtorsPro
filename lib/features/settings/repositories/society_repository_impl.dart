// data/repositories/society_repository_impl.dart
import 'society_repository.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';

class SocietyRepositoryImpl implements SocietyRepository {
  final dynamic db;
  final String? companyId;
  final bool isSuperAdmin;
  
  SocietyRepositoryImpl(this.db, {required this.companyId, required this.isSuperAdmin});

  @override
  Future<List<Map<String, String>>> getSocieties() async {
    try {
      final clauses = <String>['is_active = 1'];
      final vars = <d.Variable<String>>[];
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId!));
      }
      
      final where = clauses.isNotEmpty ? 'WHERE ${clauses.join(' AND ')}' : '';
      
      final result = await db.customSelect('''
        SELECT id, name FROM societies $where
        ORDER BY name
      ''', variables: vars).get();
      
      // Explicit type-safe mapping
      final List<Map<String, String>> items = [];
      for (final row in result) {
        items.add({
          'id': row.data['id']?.toString() ?? '',
          'name': row.data['name']?.toString() ?? '',
        });
      }
      
      return items;
    } catch (e) {
      debugPrint('Error loading societies: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, String>>> getBlocks() async {
    try {
      final clauses = <String>['is_active = 1'];
      final vars = <d.Variable<String>>[];
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        clauses.add('company_id = ?');
        vars.add(d.Variable.withString(companyId!));
      }
      
      final where = clauses.isNotEmpty ? 'WHERE ${clauses.join(' AND ')}' : '';
      
      final result = await db.customSelect('''
        SELECT id, society_id, name FROM blocks $where
        ORDER BY name
      ''', variables: vars).get();
      
      // Explicit type-safe mapping
      final List<Map<String, String>> items = [];
      for (final row in result) {
        items.add({
          'id': row.data['id']?.toString() ?? '',
          'society_id': row.data['society_id']?.toString() ?? '',
          'name': row.data['name']?.toString() ?? '',
        });
      }
      
      return items;
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, String>>> getBlocksBySociety(String societyId) async {
    debugPrint('SocietyRepositoryImpl: getBlocksBySociety called with societyId: $societyId');
    try {
      final result = await db.customSelect(
        'SELECT id, society_id, name FROM blocks WHERE society_id = ? AND is_active = 1 ORDER BY name',
        variables: [d.Variable.withString(societyId)],
      ).get();
      
      debugPrint('SocietyRepositoryImpl: Query returned ${result.length} raw results');
      
      // Explicit type-safe mapping - FIX: Include society_id from query
      final List<Map<String, String>> items = [];
      for (final row in result) {
        final item = {
          'id': row.data['id']?.toString() ?? '',
          'society_id': row.data['society_id']?.toString() ?? societyId, // FIX: Use queried society_id or fallback
          'name': row.data['name']?.toString() ?? '',
        };
        items.add(item);
        debugPrint('SocietyRepositoryImpl: Mapped block: $item');
      }
      
      debugPrint('SocietyRepositoryImpl: Type-safe blocks mapping completed, blocks count: ${items.length}');
      debugPrint('SocietyRepositoryImpl: Final blocks list: $items');
      
      return items;
    } catch (e) {
      debugPrint('Error loading blocks for society $societyId: $e');
      return [];
    }
  }
}
