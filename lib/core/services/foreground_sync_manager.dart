import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import 'package:easyrealtorspro/core/role_utils.dart';
import 'package:shared/shared.dart' show AppDatabase;

class ForegroundSyncManager {
  static final ForegroundSyncManager instance = ForegroundSyncManager._();
  ForegroundSyncManager._();
  
  bool _isSyncing = false;
  bool _isPaused = false;
  Timer? _periodicSyncTimer;
  StreamSubscription? _usersListener;
  StreamSubscription? _companiesListener;
  StreamSubscription? _inventoryListener;
  
  Future<void> syncNow() async {
    if (_isSyncing || _isPaused) return;
    if (Firebase.apps.isEmpty) return;
    
    _isSyncing = true;
    debugPrint('🔄 ForegroundSyncManager: Starting foreground sync...');
    
    try {
      await _syncUsers();
      await _syncCompanies();
      await _syncInventory();
      _startPeriodicSync();
      _startRealtimeListeners();
      debugPrint('✅ ForegroundSyncManager: Sync completed successfully');
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  Future<void> pauseSync() async {
    _isPaused = true;
    debugPrint('⏸️ ForegroundSyncManager: Pausing sync...');
    
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    
    await _usersListener?.cancel();
    await _companiesListener?.cancel();
    await _inventoryListener?.cancel();
    
    _usersListener = null;
    _companiesListener = null;
    _inventoryListener = null;
    
    debugPrint('✅ ForegroundSyncManager: Sync paused - all listeners cancelled');
  }
  
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (!_isPaused && Firebase.apps.isNotEmpty) {
          debugPrint('🔄 ForegroundSyncManager: Periodic sync triggered');
          await _syncUsers();
          await _syncCompanies();
        }
      },
    );
  }
  
  void _startRealtimeListeners() {
    if (Firebase.apps.isEmpty) return;
    
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = AuthService.currentUser;
      final isSuperAdmin = RoleUtils.isSuperAdmin(currentUser);
      final userCompanyId = RoleUtils.getUserCompanyId(currentUser);
      
      Query usersQuery = firestore.collection('users');
      if (!isSuperAdmin && userCompanyId != null) {
        usersQuery = usersQuery.where('company_id', isEqualTo: userCompanyId);
      }
      
      _usersListener = usersQuery.snapshots().listen(
        (snapshot) async {
          if (_isPaused) return;
          debugPrint('🔔 ForegroundSyncManager: Users realtime update - ${snapshot.docs.length} docs');
          await _saveUsersToLocal(snapshot.docs);
        },
        onError: (e) => debugPrint('❌ ForegroundSyncManager: Users listener error: $e'),
      );
      
      if (isSuperAdmin) {
        _companiesListener = firestore.collection('companies').snapshots().listen(
          (snapshot) async {
            if (_isPaused) return;
            debugPrint('🔔 ForegroundSyncManager: Companies realtime update - ${snapshot.docs.length} docs');
            await _saveCompaniesToLocal(snapshot.docs);
          },
          onError: (e) => debugPrint('❌ ForegroundSyncManager: Companies listener error: $e'),
        );
      }
      debugPrint('✅ ForegroundSyncManager: Realtime listeners started');
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Error starting realtime listeners: $e');
    }
  }
  
  Future<void> _syncUsers() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = AuthService.currentUser;
      final isSuperAdmin = RoleUtils.isSuperAdmin(currentUser);
      final userCompanyId = RoleUtils.getUserCompanyId(currentUser);
      
      Query query = firestore.collection('users');
      if (!isSuperAdmin && userCompanyId != null) {
        query = query.where('company_id', isEqualTo: userCompanyId);
      }
      
      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      debugPrint('📥 ForegroundSyncManager: Fetched ${snapshot.docs.length} users from Firestore');
      await _saveUsersToLocal(snapshot.docs);
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Users sync failed: $e');
    }
  }
  
  Future<void> _syncCompanies() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('companies').get().timeout(const Duration(seconds: 10));
      debugPrint('📥 ForegroundSyncManager: Fetched ${snapshot.docs.length} companies from Firestore');
      await _saveCompaniesToLocal(snapshot.docs);
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Companies sync failed: $e');
    }
  }
  
  Future<void> _syncInventory() async {
    try {
      debugPrint('📥 ForegroundSyncManager: Inventory sync (placeholder)');
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Inventory sync failed: $e');
    }
  }
  
  Future<void> _saveUsersToLocal(List<QueryDocumentSnapshot> docs) async {
    try {
      final db = await AppDatabase.instance();
      await db.transaction(() async {
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          await db.customStatement(
            '''INSERT OR REPLACE INTO users (
              id, username, password_hash, salt, iterations, user_id, name, email, 
              contact_no, role, permissions, company_id, status, is_first_login, 
              is_active, profile_picture_path, created_at, updated_at, is_synced
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              doc.id,
              data['username']?.toString() ?? '',
              data['password_hash']?.toString() ?? '',
              data['salt']?.toString() ?? '',
              int.tryParse(data['iterations']?.toString() ?? '') ?? 10000,
              data['user_id']?.toString() ?? doc.id,
              data['name']?.toString() ?? '',
              data['email']?.toString() ?? '',
              data['contact_no']?.toString() ?? '',
              data['role']?.toString() ?? 'agent',
              data['permissions']?.toString() ?? '{}',
              data['company_id']?.toString() ?? '',
              data['status']?.toString() ?? 'active',
              (data['is_first_login'] == true || data['is_first_login'] == 1) ? 1 : 0,
              (data['is_active'] == true || data['is_active'] == 1) ? 1 : 0,
              data['profile_picture_path']?.toString() ?? '',
              data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
              1,
            ],
          );
        }
      });
      debugPrint('✅ ForegroundSyncManager: Saved ${docs.length} users to local DB');
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Error saving users to local DB: $e');
    }
  }
  
  Future<void> _saveCompaniesToLocal(List<QueryDocumentSnapshot> docs) async {
    try {
      final db = await AppDatabase.instance();
      await db.transaction(() async {
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          await db.customStatement(
            '''INSERT OR REPLACE INTO companies (
              id, name, status, metadata, max_user_limit, subscription_tier, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              doc.id,
              data['name']?.toString() ?? '',
              data['status']?.toString() ?? 'active',
              data['metadata']?.toString() ?? '{}',
              data['max_user_limit'] ?? 5,
              data['subscription_tier']?.toString() ?? 'Starter',
              data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
            ],
          );
        }
      });
      debugPrint('✅ ForegroundSyncManager: Saved ${docs.length} companies to local DB');
    } catch (e) {
      debugPrint('❌ ForegroundSyncManager: Error saving companies to local DB: $e');
    }
  }
  
  void dispose() {
    _periodicSyncTimer?.cancel();
    _usersListener?.cancel();
    _companiesListener?.cancel();
    _inventoryListener?.cancel();
  }
}