import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart';
import '../../../core/role_utils.dart' as local;
import 'package:uuid/uuid.dart';
import '../../../core/services/app_storage.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_helper.dart';
import 'company_repository.dart';
import '../../companies/models/company_model.dart';
import '../../../core/services/sync_database_helper.dart';
import '../../../firestore_sync_service.dart';
import '../../../core/app_utils.dart';
import '../../../core/services/firebase_threading_handler.dart';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;

class CompanyRepositoryImpl implements CompanyRepository {
  final AppDatabase db;
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();
  final FirestoreSyncService _firestoreSync = FirestoreSyncService();
  
  // SQLite-only flag - enables Firestore operations
  static const bool _sqliteOnlyMode = false;

  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  CompanyRepositoryImpl(this.db);

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('CompanyRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'CompanyRepository $streamName',
      );
    }
    return stream;
  }

  // Helper method to disable Firestore operations in SQLite-only mode
  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode;
  }

  // Helper method to execute Firestore operations only if allowed
  Future<void> _executeFirestoreOperation(Future<void> Function() operation) async {
    if (_isFirestoreOperationAllowed()) {
      try {
        await operation();
      } catch (e) {
        debugPrint('Firestore operation failed (non-critical in SQLite-only mode): $e');
      }
    } else {
      debugPrint('Firestore operation skipped in SQLite-only mode');
    }
  }

  // Helper method to check if current user is Super Admin
  Future<bool> _isSuperAdmin() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      
      if (authToken != null) {
        final user = await AuthService.getCurrentUser(authToken);
        return local.RoleUtils.isSuperAdmin(user) || PermissionHelper.isBypassUser(user);
      }
      return false;
    } catch (e) {
      debugPrint('CompanyRepository: Error checking Super Admin status: $e');
      return false;
    }
  }

  @override
  Future<List<CompanyModel>> getCompanies() async {
    try {
      // CRITICAL FIX: Enhanced Super Admin support for GLOBAL_ADMIN
      final isSuperAdmin = await _isSuperAdmin();
      
      String query;
      List<d.Variable> variables = [];
      
      if (isSuperAdmin) {
        // Super Admin - show all companies
        query = '''
          SELECT id, name, status, metadata, logo_url, address, contact, 
                 max_user_limit, subscription_tier, is_active, is_synced, 
                 created_at, updated_at
          FROM companies 
          WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) 
          AND (is_active = 1 OR is_active IS NULL) 
          ORDER BY updated_at DESC
          ''';
        debugPrint('CompanyRepository: getCompanies for Super Admin - showing all companies');
      } else {
        // Non-Super Admin - apply regular filtering
        query = '''
          SELECT id, name, status, metadata, logo_url, address, contact, 
                 max_user_limit, subscription_tier, is_active, is_synced, 
                 created_at, updated_at
          FROM companies 
          WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) 
          AND (is_active = 1 OR is_active IS NULL) 
          ORDER BY updated_at DESC
          ''';
        debugPrint('CompanyRepository: getCompanies for regular user');
      }
      
      final result = await db.customSelect(query, variables: variables).get();
      return result.map((row) => CompanyModel.fromMap(row.data)).toList();
    } catch (e) {
      debugPrint('CompanyRepository: Error getting companies: $e');
      return [];
    }
  }

  @override
  Future<CompanyModel?> getCompanyById(String id) async {
    try {
      final result = await db.customSelect(
        '''
        SELECT id, name, status, metadata, logo_url, address, contact, 
               max_user_limit, subscription_tier, is_active, is_synced, 
               created_at, updated_at
        FROM companies 
        WHERE id = ? AND (is_active = 1 OR is_active IS NULL)
        ''',
        variables: [d.Variable.withString(id)],
      ).get();
      
      if (result.isEmpty) return null;
      return CompanyModel.fromMap(result.first.data);
    } catch (e) {
      throw Exception('Failed to fetch company by ID: $e');
    }
  }

  @override
  Future<void> addCompany(CompanyModel company) async {
    try {
      final now = DateTime.now().toIso8601String();
      final companyWithTimestamp = company.copyWith(
        id: company.id.isEmpty ? const Uuid().v4() : company.id,
        createdAt: company.createdAt ?? now,
        updatedAt: now,
        status: company.status ?? 'active',
      );
      
      await db.customStatement(
        '''
        INSERT OR REPLACE INTO companies (
          id, name, status, metadata, logo_url, address, contact, 
          max_user_limit, subscription_tier, is_active, is_synced, 
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          companyWithTimestamp.id,
          companyWithTimestamp.name,
          companyWithTimestamp.status,
          companyWithTimestamp.metadata != null ? CompanyModel.encodeMetadata(companyWithTimestamp.metadata!) : null,
          companyWithTimestamp.logoUrl,
          companyWithTimestamp.address,
          companyWithTimestamp.contact,
          companyWithTimestamp.maxUserLimit ?? 5,
          companyWithTimestamp.subscriptionTier ?? 'Starter',
          companyWithTimestamp.isActive ? 1 : 0,
          companyWithTimestamp.isSynced ? 1 : 0,
          companyWithTimestamp.createdAt,
          companyWithTimestamp.updatedAt,
        ],
      );
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(companyWithTimestamp.id);
      }
    } catch (e) {
      throw Exception('Failed to add company: $e');
    }
  }

  @override
  Future<void> updateCompany(CompanyModel company) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updatedCompany = company.copyWith(updatedAt: now);
      
      await db.customStatement(
        '''
        UPDATE companies SET 
          name = ?, status = ?, metadata = ?, logo_url = ?, address = ?, 
          contact = ?, max_user_limit = ?, subscription_tier = ?, 
          is_active = ?, is_synced = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          updatedCompany.name,
          updatedCompany.status,
          updatedCompany.metadata != null ? CompanyModel.encodeMetadata(updatedCompany.metadata!) : null,
          updatedCompany.logoUrl,
          updatedCompany.address,
          updatedCompany.contact,
          updatedCompany.maxUserLimit,
          updatedCompany.subscriptionTier,
          updatedCompany.isActive ? 1 : 0,
          updatedCompany.isSynced ? 1 : 0,
          updatedCompany.updatedAt,
          updatedCompany.id,
        ],
      );
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(updatedCompany.id);
      }
    } catch (e) {
      throw Exception('Failed to update company: $e');
    }
  }

  @override
  Future<void> deleteCompany(String id) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE companies SET status = ?, is_active = 0, updated_at = ? WHERE id = ?',
        ['archived', now, id],
      );
      
      // Mark as unsynced for Firestore sync
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(id);
      }
    } catch (e) {
      throw Exception('Failed to delete company: $e');
    }
  }

  @override
  Stream<List<CompanyModel>> watchCompanies() {
    try {
      debugPrint('CompanyRepository: watchCompanies starting...');
      
      final stream = db
          .customSelect(
            '''
            SELECT id, name, status, metadata, logo_url, address, contact, 
                   max_user_limit, subscription_tier, is_active, is_synced, 
                   created_at, updated_at
            FROM companies 
            WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) 
            AND (is_active = 1 OR is_active IS NULL) 
            ORDER BY updated_at DESC
            ''',
          )
          .watch()
          .map((rows) {
            debugPrint('CompanyRepository: watchCompanies fetched ${rows.length} rows');
            return rows.map((r) {
              debugPrint('CompanyRepository: mapping company data: ${r.data}');
              return CompanyModel.fromMap(r.data);
            }).toList();
          });
      
      // CRITICAL: Wrap stream with platform thread safety for Windows
      return _wrapStreamWithThreadSafety(stream, 'watchCompanies');
    } catch (e) {
      debugPrint('Error in watchCompanies stream: $e');
      // Return empty stream on error
      return Stream.value([]);
    }
  }

  @override
  Stream<CompanyModel?> watchCompanyById(String id) {
    return getCompanyById(id).asStream();
  }

  @override
  Future<void> activateCompany(String id) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE companies SET status = ?, is_active = 1, updated_at = ? WHERE id = ?',
        ['active', now, id],
      );
      
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(id);
      }
    } catch (e) {
      throw Exception('Failed to activate company: $e');
    }
  }

  @override
  Future<void> deactivateCompany(String id) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE companies SET status = ?, is_active = 0, updated_at = ? WHERE id = ?',
        ['inactive', now, id],
      );
      
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(id);
      }
    } catch (e) {
      throw Exception('Failed to deactivate company: $e');
    }
  }

  @override
  Future<void> archiveCompany(String id) async {
    await deleteCompany(id);
  }

  @override
  Future<bool> canAddMoreUsers(String companyId) async {
    try {
      // Get company's user limit
      final limitResult = await db.customSelect(
        'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      if (limitResult.isEmpty) return false;
      
      final limitRaw = limitResult.first.data['max_user_limit'];
      final tier = limitResult.first.data['subscription_tier']?.toString();
      
      int? limit = limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? '');
      limit ??= await getUserLimitForTier(tier ?? 'Starter');
      
      // Get current user count
      final countResult = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL) AND (is_active = 1 OR is_active IS NULL)",
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      final count = int.tryParse(countResult.first.data['cnt'].toString() ?? '0') ?? 0;
      
      return count < (limit ?? 0);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getCurrentUserCount(String companyId) async {
    try {
      final result = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL) AND (is_active = 1 OR is_active IS NULL)",
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      return int.tryParse(result.first.data['cnt'].toString() ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<int> getMaxUserLimit(String companyId) async {
    try {
      final result = await db.customSelect(
        'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      if (result.isEmpty) return 5;
      
      final limitRaw = result.first.data['max_user_limit'];
      final tier = result.first.data['subscription_tier']?.toString();
      
      int? limit = limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? '');
      return limit ?? await getUserLimitForTier(tier ?? 'Starter');
    } catch (e) {
      return 5;
    }
  }

  @override
  Future<void> updateUserLimit(String companyId, int newLimit) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE companies SET max_user_limit = ?, updated_at = ? WHERE id = ?',
        [newLimit, now, companyId],
      );
      
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(companyId);
      }
    } catch (e) {
      throw Exception('Failed to update user limit: $e');
    }
  }

  @override
  Future<String?> getSubscriptionTier(String companyId) async {
    try {
      final result = await db.customSelect(
        'SELECT subscription_tier FROM companies WHERE id = ? LIMIT 1',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      return result.isNotEmpty ? result.first.data['subscription_tier']?.toString() : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateSubscriptionTier(String companyId, String tier) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.customStatement(
        'UPDATE companies SET subscription_tier = ?, updated_at = ? WHERE id = ?',
        [tier, now, companyId],
      );
      
      if (!_sqliteOnlyMode) {
        await markCompanyAsUnsynced(companyId);
      }
    } catch (e) {
      throw Exception('Failed to update subscription tier: $e');
    }
  }

  @override
  Future<int> getUserLimitForTier(String tier) async {
    try {
      switch (tier?.toLowerCase()) {
        case 'starter':
          return 5;
        case 'professional':
          return 20;
        case 'enterprise':
          return 100;
        default:
          return 5;
      }
    } catch (e) {
      debugPrint('Error getting user limit for tier: $e');
      return 5;
    }
  }

  @override
  Future<List<CompanyModel>> searchCompanies(String query) async {
    try {
      final result = await db.customSelect(
        '''
        SELECT id, name, status, metadata, logo_url, address, contact, 
               max_user_limit, subscription_tier, is_active, is_synced, 
               created_at, updated_at
        FROM companies 
        WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) 
        AND (is_active = 1 OR is_active IS NULL) 
        AND (LOWER(name) LIKE LOWER(?) OR LOWER(address) LIKE LOWER(?) OR LOWER(contact) LIKE LOWER(?))
        ORDER BY updated_at DESC
        ''',
        variables: [
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
          d.Variable.withString('%$query%'),
        ],
      ).get();
      
      return result.map((r) => CompanyModel.fromMap(r.data)).toList();
    } catch (e) {
      throw Exception('Failed to search companies: $e');
    }
  }

  @override
  Stream<List<CompanyModel>> watchSearchCompanies(String query) {
    return searchCompanies(query).asStream();
  }

  @override
  Future<void> ensureCompanyTableColumns() async {
    try {
      // Ensure all required columns exist
      final columns = [
        'ALTER TABLE companies ADD COLUMN is_active INTEGER DEFAULT 1',
        'ALTER TABLE companies ADD COLUMN is_synced INTEGER DEFAULT 1',
        'ALTER TABLE companies ADD COLUMN logo_url TEXT',
        'ALTER TABLE companies ADD COLUMN address TEXT',
        'ALTER TABLE companies ADD COLUMN contact TEXT',
      ];
      
      for (final column in columns) {
        try {
          await db.customStatement(column);
        } catch (e) {
          // Column might already exist, ignore error
        }
      }
      
      // Update null values
      await db.customStatement('UPDATE companies SET is_active = 1 WHERE is_active IS NULL');
      await db.customStatement('UPDATE companies SET is_synced = 1 WHERE is_synced IS NULL');
    } catch (e) {
      throw Exception('Failed to ensure company table columns: $e');
    }
  }

  @override
  Future<void> syncCompaniesFromFirestore() async {
    if (!_isFirestoreOperationAllowed()) {
      debugPrint('CompanyRepository: Firestore sync not allowed in SQLite-only mode');
      return;
    }
    
    await _executeFirestoreOperation(() async {
      debugPrint('CompanyRepository: Starting sync from Firestore...');
      
      try {
        final firestore = FirebaseFirestore.instance;
        final companiesCollection = firestore.collection('companies');
        
        // Get all companies from Firestore
        final querySnapshot = await companiesCollection.get();
        debugPrint('CompanyRepository: Fetched ${querySnapshot.docs.length} companies from Firestore');
        
        // Begin transaction for bulk insert
        await db.transaction(() async {
          for (final doc in querySnapshot.docs) {
            final data = doc.data();
            
            // Convert Firestore data to CompanyModel format
            final companyMap = {
              'id': doc.id,
              'name': data['name'] ?? '',
              'status': data['status'] ?? 'active', // CRITICAL: Ensure status is always provided
              'address': data['address'] ?? '',
              'phone': data['phone'] ?? '',
              'email': data['email'] ?? '',
              'description': data['description'] ?? '',
              'logo_url': data['logo_url'] ?? '',
              'is_active': data['is_active'] ?? true,
              'is_synced': 1, // Mark as synced
              'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': data['updated_at'] ?? DateTime.now().toIso8601String(),
              'created_by': data['created_by'] ?? '',
            };
            
            // Insert or replace company in SQLite
            await db.customInsert(
              '''INSERT OR REPLACE INTO companies (
                id, name, status, address, contact, email, description, logo_url,
                is_active, is_synced, created_at, updated_at, created_by
              ) VALUES (
                :id, :name, :status, :address, :contact, :email, :description, :logo_url,
                :is_active, :is_synced, :created_at, :updated_at, :created_by
              )''',
              variables: [
                d.Variable.withString(companyMap['id']),
                d.Variable.withString(companyMap['name']),
                d.Variable.withString(companyMap['status']),
                d.Variable.withString(companyMap['address']),
                d.Variable.withString(companyMap['phone'] ?? companyMap['contact'] ?? ''), // Map phone to contact
                d.Variable.withString(companyMap['email']),
                d.Variable.withString(companyMap['description']),
                d.Variable.withString(companyMap['logo_url']),
                d.Variable.withInt(companyMap['is_active'] ? 1 : 0),
                d.Variable.withInt(companyMap['is_synced']),
                d.Variable.withString(companyMap['created_at']),
                d.Variable.withString(companyMap['updated_at']),
                d.Variable.withString(companyMap['created_by']),
              ],
            );
            
            debugPrint('CompanyRepository: Synced company: ${companyMap['name']}');
          }
        });
        
        debugPrint('CompanyRepository: Successfully synced ${querySnapshot.docs.length} companies from Firestore');
      } catch (e) {
        debugPrint('CompanyRepository: Error syncing from Firestore: $e');
        rethrow;
      }
    });
  }
  
  /// Helper method to run async operations without awaiting
  void unawaited(Future<void> future) {
    // Intentionally not awaiting the future
    // This allows the operation to run in background without blocking
  }

  @override
  Future<void> markCompanyAsUnsynced(String companyId) async {
    await _syncHelper.markAsUnsynced('companies', companyId);
  }

  @override
  Future<void> markCompanyAsSynced(String companyId) async {
    await _syncHelper.markAsSynced('companies', companyId);
  }

  @override
  Future<Map<String, dynamic>> getCompanyStatistics() async {
    try {
      final result = await db.customSelect(
        '''
        SELECT 
          COUNT(*) as total_companies,
          COUNT(CASE WHEN status = 'active' OR status IS NULL THEN 1 END) as active_companies,
          COUNT(CASE WHEN status = 'inactive' THEN 1 END) as inactive_companies,
          COUNT(CASE WHEN status = 'archived' THEN 1 END) as archived_companies
        FROM companies 
        WHERE (is_active = 1 OR is_active IS NULL)
        ''',
      ).get();
      
      final data = result.first.data;
      
      return {
        'total_companies': int.tryParse(data['total_companies'].toString() ?? '0') ?? 0,
        'active_companies': int.tryParse(data['active_companies'].toString() ?? '0') ?? 0,
        'inactive_companies': int.tryParse(data['inactive_companies'].toString() ?? '0') ?? 0,
        'archived_companies': int.tryParse(data['archived_companies'].toString() ?? '0') ?? 0,
      };
    } catch (e) {
      return {
        'total_companies': 0,
        'active_companies': 0,
        'inactive_companies': 0,
        'archived_companies': 0,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> getCompanyStatisticsById(String companyId) async {
    try {
      // Get company info
      final companyResult = await db.customSelect(
        '''
        SELECT name, max_user_limit, subscription_tier 
        FROM companies 
        WHERE id = ? AND (is_active = 1 OR is_active IS NULL)
        LIMIT 1
        ''',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      if (companyResult.isEmpty) return {};
      
      final companyData = companyResult.first.data;
      
      // Get user statistics for this company
      final userResult = await db.customSelect(
        '''
        SELECT 
          COUNT(*) as total_users,
          COUNT(CASE WHEN status = 'active' OR status IS NULL THEN 1 END) as active_users,
          COUNT(CASE WHEN status = 'inactive' THEN 1 END) as inactive_users,
          COUNT(CASE WHEN status = 'archived' THEN 1 END) as archived_users
        FROM users 
        WHERE company_id = ? AND (is_active = 1 OR is_active IS NULL)
        ''',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      final userData = userResult.isNotEmpty ? userResult.first.data : {};
      
      return {
        'company_name': companyData['name']?.toString(),
        'max_user_limit': companyData['max_user_limit'] is int ? companyData['max_user_limit'] : int.tryParse(companyData['max_user_limit']?.toString() ?? ''),
        'subscription_tier': companyData['subscription_tier']?.toString(),
        'total_users': int.tryParse(userData['total_users']?.toString() ?? '0') ?? 0,
        'active_users': int.tryParse(userData['active_users']?.toString() ?? '0') ?? 0,
        'inactive_users': int.tryParse(userData['inactive_users']?.toString() ?? '0') ?? 0,
        'archived_users': int.tryParse(userData['archived_users']?.toString() ?? '0') ?? 0,
        'can_add_more_users': await canAddMoreUsers(companyId),
      };
    } catch (e) {
      return {};
    }
  }

  @override
  Future<bool> isCompanyNameUnique(String name, {String? excludeCompanyId}) async {
    String query = 'SELECT COUNT(*) as c FROM companies WHERE LOWER(name) = LOWER(?)';
    List<d.Variable> variables = [d.Variable.withString(name)];
    
    if (excludeCompanyId != null) {
      query += ' AND id != ?';
      variables.add(d.Variable.withString(excludeCompanyId));
    }
    
    final result = await db.customSelect(query, variables: variables).get();
    final count = int.tryParse(result.first.data['c'].toString() ?? '0') ?? 0;
    return count == 0;
  }

  @override
  Future<bool> isCompanyActive(String companyId) async {
    try {
      final result = await db.customSelect(
        'SELECT is_active, status FROM companies WHERE id = ? LIMIT 1',
        variables: [d.Variable.withString(companyId)],
      ).get();
      
      if (result.isEmpty) return false;
      
      final data = result.first.data;
      final isActive = (data['is_active'] is int ? data['is_active'] == 1 : data['is_active'] == true) ?? true;
      final status = data['status']?.toString();
      
      return isActive && (status == null || status == 'active');
    } catch (e) {
      return false;
    }
  }
}
