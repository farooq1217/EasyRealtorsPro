// data/repositories/society_repository_impl.dart
import '../../domain/repositories/society_repository.dart';
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
      final result = await db.customSelect('''
        SELECT id, name FROM societies 
        WHERE is_active = 1
        ORDER BY name
      ''').get();
      
      // Explicit type-safe mapping
      final List<Map<String, String>> items = [];
      for (final row in result) {
        final Map<String, String> item = {
          'id': row.data['id'] as String,
          'name': row.data['name'] as String,
        };
        items.add(item);
      }
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        return items.where((item) => item['id'] == companyId).toList();
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
      final result = await db.customSelect('''
        SELECT id, society_id, name FROM blocks 
        WHERE is_active = 1
        ORDER BY name
      ''').get();
      
      // Explicit type-safe mapping
      final List<Map<String, String>> items = [];
      for (final row in result) {
        final Map<String, String> item = {
          'id': row.data['id'] as String,
          'society_id': row.data['society_id'] as String,
          'name': row.data['name'] as String,
        };
        items.add(item);
      }
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        return items.where((item) => item['society_id'] == companyId).toList();
      }
      
      return items;
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, String>>> getBlocksBySociety(String societyId) async {
    try {
      final result = await db.customSelect(
        'SELECT id, name FROM blocks WHERE society_id = ? AND is_active = 1 ORDER BY name',
        variables: [d.Variable.withString(societyId)],
      ).get();
      
      // Explicit type-safe mapping
      final List<Map<String, String>> items = [];
      for (final row in result) {
        final Map<String, String> item = {
          'id': row.data['id'] as String,
          'name': row.data['name'] as String,
        };
        items.add(item);
      }
      
      // Filter by company if not super admin
      if (!isSuperAdmin && companyId != null) {
        return items.where((item) => item['id'] == companyId).toList();
      }
      
      return items;
    } catch (e) {
      debugPrint('Error loading blocks by society: $e');
      return [];
    }
  }
}
