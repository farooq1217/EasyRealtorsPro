import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:shared/shared.dart';
import '../firebase_threading_handler.dart';
import '../../database/app_database_extensions.dart';
import './local_auth_storage.dart';

class FirestoreAuthSync {
  final FirebaseFirestore? _firestoreOverride;
  final AppDatabase? _db;
  final LocalAuthStorage _localStore;

  FirestoreAuthSync({
    FirebaseFirestore? firestore,
    AppDatabase? db,
    LocalAuthStorage? localStore,
  })  : _firestoreOverride = firestore,
        _db = db,
        _localStore = localStore ?? LocalAuthStorage();

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  AppDatabase get db => _db ?? AppDatabase.instanceIfInitialized!;

  Stream<DocumentSnapshot> watchUser(String userId) {
    if (Firebase.apps.isEmpty) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Future<void> syncUserData(String userId, Map<String, dynamic> data) async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').doc(userId).set(data, SetOptions(merge: true)),
        operationName: 'FirestoreAuthSync syncUserData',
      );
    } catch (e) {
      debugPrint('FirestoreAuthSync: syncUserData failed (offline mode): $e');
    }
  }

  /// Sync users from Firestore to SQLite and local JSON cache
  Future<int> syncUsersFromFirestore() async {
    return await Future.microtask(() async {
      return await _syncUsersFromFirestoreInternal();
    });
  }

  Future<int> _syncUsersFromFirestoreInternal() async {
    if (Firebase.apps.isEmpty) return 0;
    
    if (!kIsWeb && io.Platform.isWindows) {
      debugPrint('FirestoreAuthSync: Bypassing Firestore users sync on Windows platform');
      return 0;
    }
    
    // Ensure Firebase Auth is ready
    try {
      final token = await FirebaseThreadingHandler.executeIdTokenRefreshWithThreadSafety();
      if (token == null && FirebaseAuth.instance.currentUser == null) {
        debugPrint('FirestoreAuthSync: Firebase Auth not ready');
        return 0;
      }
    } catch (_) {
      return 0;
    }

    int synced = 0;
    try {
      final snap = await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').get(),
        operationName: 'FirestoreAuthSync syncUsersFromFirestore',
      );
      
      for (final doc in snap.docs) {
        final data = doc.data();
        final docIdRaw = doc.id.toString().trim();
        final emailField = (data['email'] ?? data['username'] ?? docIdRaw).toString().trim().toLowerCase();
        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
        if (!emailRegex.hasMatch(docIdRaw) && !emailRegex.hasMatch(emailField)) {
          continue;
        }
        
        final email = emailField;
        final id = docIdRaw;
        final username = (data['username'] ?? email).toString();
        final userId = (data['user_id'] ?? data['userId'])?.toString();
        final name = (data['name'] ?? '').toString();
        final contactNo = (data['contact_no'] ?? data['contactNo'] ?? '').toString();
        final permissions = _cleanPermissions(data['permissions']);
        final companyId = (data['company_id'] ?? data['companyId'])?.toString();
        final status = (data['status'] ?? 'active').toString();
        final isActiveRaw = data['is_active'] ?? data['isActive'];
        final isActive = isActiveRaw == null ? 1 : ((isActiveRaw is bool) ? (isActiveRaw ? 1 : 0) : int.tryParse(isActiveRaw.toString()) ?? 1);
        final createdAt = (data['created_at'] ?? data['createdAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
        final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
        final passwordHash = (data['password_hash'] ?? data['passwordHash'])?.toString();
        final salt = data['salt']?.toString();
        final iterations = data['iterations'] is int ? data['iterations'] as int : int.tryParse(data['iterations']?.toString() ?? '');

        // Update local SQLite
        await db.customStatement(
          'INSERT OR REPLACE INTO users (id, username, password_hash, salt, iterations, user_id, name, email, contact_no, permissions, company_id, status, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            username,
            passwordHash,
            salt,
            iterations,
            userId,
            name,
            email,
            contactNo,
            permissions != null ? jsonEncode(permissions) : null,
            companyId,
            status,
            isActive,
            createdAt,
            updatedAt
          ],
        );

        // Update local JSON cache
        final users = await _localStore.readUsers();
        Map<String, dynamic> updatedUser = {
          'id': id,
          'email': email,
          'username': username,
          'password': passwordHash,
          'passwordHash': passwordHash,
          'name': name,
          'contactNo': contactNo,
          'permissions': permissions,
          'companyId': companyId,
          'status': status,
          'isActive': isActive,
          'is_active': isActive,
          'userId': userId,
          'user_id': userId,
          'createdAt': createdAt,
          'created_at': createdAt,
          'salt': salt,
          'iterations': iterations,
        };
        
        try {
          if (permissions is String) {
            final decoded = jsonDecode(permissions);
            if (decoded is Map) updatedUser['role'] = decoded['role']?.toString();
          } else if (permissions is Map) {
            updatedUser['role'] = permissions['role']?.toString();
          }
        } catch (_) {}
        
        users[email] = updatedUser;
        await _localStore.writeUsers(users);
        synced++;
      }
    } catch (e) {
      debugPrint('FirestoreAuthSync: syncUsersFromFirestoreInternal failed: $e');
    }
    return synced;
  }

  dynamic _cleanPermissions(dynamic perms) {
    if (perms == null) return null;
    try {
      if (perms is Map) return Map<String, dynamic>.from(perms);
      if (perms is String) {
        final unescaped = perms.replaceAll(r'\"', '"');
        final decoded = jsonDecode(unescaped);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return decoded;
      }
    } catch (_) {}
    return perms;
  }

  /// Fetch Firestore user document by email
  Future<Map<String, dynamic>?> fetchFirestoreUserByEmail(String emailKey) async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final query = await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').where('email', isEqualTo: emailKey).limit(1).get(),
        operationName: 'FirestoreAuthSync fetchFirestoreUserByEmail',
      );
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        data['id'] ??= doc.id;
        return data;
      }
    } catch (e) {
      debugPrint('Firestore lookup failed for $emailKey: $e');
    }
    return null;
  }

  /// Merge duplicate Firestore profiles if needed
  Future<void> mergeSplitProfileIfNeeded(String email, String resolvedPhone, Map<String, dynamic> baseUser) async {
    if (Firebase.apps.isEmpty) return;
    final emailKey = email.trim().toLowerCase();
    try {
      final emailDocRef = _firestore.collection('users').doc(emailKey);
      final emailDoc = await FirebaseThreadingHandler.executeWithThreadSafety(
        () => emailDocRef.get(),
        operationName: 'FirestoreAuthSync mergeSplitProfile get emailDoc',
      );
      final emailData = emailDoc.data();
      final emailRole = (emailData?['role'] ?? '').toString().trim();
      if (emailRole.isNotEmpty) return; // Already has role, nothing to merge

      Map<String, dynamic>? candidateData;
      String? candidateId;

      bool hasRole(Map<String, dynamic>? data) {
        final role = (data?['role'] ?? '').toString().trim();
        return role.isNotEmpty;
      }

      // Try phone-based lookup first
      if (resolvedPhone.isNotEmpty) {
        final phoneQueries = [
          _firestore.collection('users').where('contact_no', isEqualTo: resolvedPhone).limit(5).get(),
          _firestore.collection('users').where('phone', isEqualTo: resolvedPhone).limit(5).get(),
          _firestore.collection('users').where('mobile', isEqualTo: resolvedPhone).limit(5).get(),
        ];
        for (final q in phoneQueries) {
          final snap = await FirebaseThreadingHandler.executeWithThreadSafety(
            () => q,
            operationName: 'FirestoreAuthSync mergeSplitProfile phone query',
          );
          for (final doc in snap.docs) {
            if (doc.id == emailKey) continue;
            final data = doc.data();
            if (hasRole(data)) {
              candidateData = data;
              candidateId = doc.id;
              break;
            }
          }
          if (candidateData != null) break;
        }
      }

      // Fallback: same email stored under a different doc id
      if (candidateData == null) {
        final snap = await FirebaseThreadingHandler.executeWithThreadSafety(
          () => _firestore.collection('users').where('email', isEqualTo: emailKey).limit(5).get(),
          operationName: 'FirestoreAuthSync mergeSplitProfile email fallback query',
        );
        for (final doc in snap.docs) {
          if (doc.id == emailKey) continue;
          final data = doc.data();
          if (hasRole(data)) {
            candidateData = data;
            candidateId = doc.id;
            break;
          }
        }
      }

      if (candidateData != null) {
        final roleToSet = candidateData['role'];
        final permsToSet = candidateData['permissions'];
        final companyIdToSet = candidateData['company_id'] ?? candidateData['companyId'];
        final companyNameToSet = candidateData['company_name'] ?? candidateData['companyName'];

        await FirebaseThreadingHandler.executeWithThreadSafety(
          () => emailDocRef.set(
            {
              'role': roleToSet,
              'permissions': permsToSet,
              'company_id': companyIdToSet,
              'companyId': companyIdToSet,
              'company_name': companyNameToSet,
              'companyName': companyNameToSet,
            },
            SetOptions(merge: true),
          ),
          operationName: 'FirestoreAuthSync mergeSplitProfile update emailDoc',
        );

        // Delete the duplicate number-based doc
        if (candidateId != null && candidateId.isNotEmpty) {
          try {
            await FirebaseThreadingHandler.executeWithThreadSafety(
              () => _firestore.collection('users').doc(candidateId!).delete(),
              operationName: 'FirestoreAuthSync mergeSplitProfile delete duplicate',
            );
          } catch (_) {}
        }

        // Update local user snapshot
        baseUser['role'] = (roleToSet ?? '').toString();
        baseUser['permissions'] = permsToSet;
        if (companyIdToSet != null) {
          baseUser['companyId'] = companyIdToSet;
          baseUser['company_id'] = companyIdToSet;
        }
        if (companyNameToSet != null) {
          baseUser['company_name'] = companyNameToSet;
          baseUser['companyName'] = companyNameToSet;
        }
        final users = await _localStore.readUsers();
        users[emailKey] = baseUser;
        await _localStore.writeUsers(users);
      }
    } catch (e) {
      debugPrint('Split-profile merge failed: $e');
    }
  }

  /// Merge phone doc into email doc in Firestore
  Future<void> mergePhoneDocIntoEmail(String email, String resolvedPhone, Map<String, dynamic> u) async {
    if (Firebase.apps.isEmpty) return;
    final phoneId = resolvedPhone.trim();
    if (phoneId.isEmpty) return;
    final emailKeyLower = email.trim().toLowerCase();
    if (phoneId == emailKeyLower) return;
    try {
      final phoneDoc = await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').doc(phoneId).get(),
        operationName: 'FirestoreAuthSync mergePhoneDoc get phoneDoc',
      );
      if (!phoneDoc.exists) return;
      final phoneData = phoneDoc.data();
      if (phoneData == null) {
        await FirebaseThreadingHandler.executeWithThreadSafety(
          () => _firestore.collection('users').doc(phoneId).delete(),
          operationName: 'FirestoreAuthSync mergePhoneDoc delete phoneDoc empty',
        );
        return;
      }
      final payload = {
        ...phoneData,
        'id': emailKeyLower,
        'email': emailKeyLower,
        'username': phoneData['username'] ?? emailKeyLower,
        'contact_no': phoneId,
        'phone': phoneId,
        'mobile': phoneId,
      };
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').doc(emailKeyLower).set(payload, SetOptions(merge: true)),
        operationName: 'FirestoreAuthSync mergePhoneDoc update emailDoc',
      );
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').doc(phoneId).delete(),
        operationName: 'FirestoreAuthSync mergePhoneDoc delete phoneDoc merged',
      );
      u
        ..addAll(payload)
        ..['id'] = emailKeyLower
        ..['user_uid'] = emailKeyLower
        ..['role'] = payload['role'] ?? u['role']
        ..['permissions'] = payload['permissions'] ?? u['permissions'];
      final users = await _localStore.readUsers();
      users[emailKeyLower] = u;
      await _localStore.writeUsers(users);
    } catch (e) {
      debugPrint('Phone-doc merge failed: $e');
    }
  }

  /// Push local data to Firestore
  Future<void> pushLocalDataToFirestore(Map<String, dynamic> user) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final email = (user['email'] ?? user['username'] ?? '').toString().toLowerCase();
      final isSuper = email == 'mayof286@gmail.com';
      final companyId = (user['company_id'] ?? user['companyId'])?.toString();
      if (!isSuper && (companyId == null || companyId.isEmpty)) {
        debugPrint('Push local data skipped: missing company_id');
        return;
      }

      // Push users
      final usersRows = await db.customSelect(
        isSuper ? 'SELECT * FROM users' : 'SELECT * FROM users WHERE company_id = ?',
        variables: isSuper ? [] : [Variable.withString(companyId!)],
      ).get();
      for (final r in usersRows) {
        try {
          final data = r.data;
          final cid = (data['company_id'] ?? data['companyId'])?.toString();
          if (!isSuper && (cid == null || cid.isEmpty)) continue;
          final docId = (data['email'] ?? data['username'] ?? data['id'] ?? '').toString().toLowerCase();
          if (docId.isEmpty) continue;
          await FirebaseThreadingHandler.executeWithThreadSafety(
            () => _firestore.collection('users').doc(docId).set(
              {
                ...data,
                'company_id': cid ?? companyId,
                'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
              },
              SetOptions(merge: true),
            ),
            operationName: 'FirestoreAuthSync pushLocalData user',
          );
        } catch (e) {
          debugPrint('FirestoreAuthSync: Error pushing user record: $e');
        }
      }

      // Push trading file entries
      final fileRows = await db.customSelect(
        isSuper ? 'SELECT * FROM trading_file_entries' : 'SELECT * FROM trading_file_entries WHERE company_id = ?',
        variables: isSuper ? [] : [Variable.withString(companyId!)],
      ).get();
      for (final r in fileRows) {
        try {
          final data = r.data;
          final id = data['id']?.toString() ?? '';
          final cid = (data['company_id'] ?? data['companyId'])?.toString();
          if (id.isEmpty) continue;
          if (!isSuper && (cid == null || cid.isEmpty)) continue;
          await FirebaseThreadingHandler.executeWithThreadSafety(
            () => _firestore.collection('trading_file_entries').doc(id).set(
              {
                ...data,
                'company_id': cid ?? companyId,
                'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
              },
              SetOptions(merge: true),
            ),
            operationName: 'FirestoreAuthSync pushLocalData trading_file_entry',
          );
        } catch (e) {
          debugPrint('FirestoreAuthSync: Error pushing trading file entry: $e');
        }
      }

      // Push trading form entries
      final formRows = await db.customSelect(
        isSuper ? 'SELECT * FROM trading_entries' : 'SELECT * FROM trading_entries WHERE company_id = ?',
        variables: isSuper ? [] : [Variable.withString(companyId!)],
      ).get();
      for (final r in formRows) {
        try {
          final data = r.data;
          final id = data['id']?.toString() ?? '';
          final cid = (data['company_id'] ?? data['companyId'])?.toString();
          if (id.isEmpty) continue;
          if (!isSuper && (cid == null || cid.isEmpty)) continue;
          await FirebaseThreadingHandler.executeWithThreadSafety(
            () => _firestore.collection('trading_entries').doc(id).set(
              {
                ...data,
                'company_id': cid ?? companyId,
                'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
              },
              SetOptions(merge: true),
            ),
            operationName: 'FirestoreAuthSync pushLocalData trading_entry',
          );
        } catch (e) {
          debugPrint('FirestoreAuthSync: Error pushing trading entry: $e');
        }
      }
    } catch (e) {
      debugPrint('Push local data to Firestore failed: $e');
    }
  }

  /// Sync offline created users to Firebase Auth
  Future<void> syncOfflineUsersToFirebaseAuth(Map<String, dynamic> usersCache) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final auth = FirebaseAuth.instance;
      final rows = await db.customSelect(
        "SELECT id, email, username, password_hash, is_active, status FROM users WHERE email IS NOT NULL AND email != ''",
      ).get();
      for (final row in rows) {
        final data = row.data;
        final email = (data['email'] ?? data['username'] ?? '').toString().trim().toLowerCase();
        if (email.isEmpty) continue;
        
        final cacheUser = usersCache[email] as Map<String, dynamic>?;
        final cachedPassword = cacheUser?['password']?.toString();
        String? plainPassword;
        if (cachedPassword != null && !cachedPassword.contains(':')) {
          plainPassword = cachedPassword;
        }
        plainPassword ??= 'Temp#${DateTime.now().millisecondsSinceEpoch}';

        try {
          await FirebaseThreadingHandler.executeWithThreadSafety(
            () => auth.createUserWithEmailAndPassword(email: email, password: plainPassword!),
            operationName: 'FirestoreAuthSync syncOfflineUsersToFirebaseAuth create',
          );
          debugPrint('FirestoreAuthSync: Firebase Auth created offline user $email');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            continue;
          }
          debugPrint('fb.FirebaseAuth sync: createUser failed for $email: ${e.code}');
          continue;
        }

        try {
          final newHash = PasswordHasher.hash(plainPassword);
          await db.customStatement('UPDATE users SET password_hash = ?, updated_at = ? WHERE email = ? OR username = ?', [newHash, DateTime.now().toUtc().toIso8601String(), email, email]);
          if (cacheUser != null) {
            cacheUser['password'] = newHash;
            cacheUser['passwordHash'] = newHash;
            usersCache[email] = cacheUser;
            await _localStore.writeUsers(usersCache);
          }
        } catch (e) {
          debugPrint('fb.FirebaseAuth sync: failed to persist hash for $email: $e');
        }
      }
    } catch (e) {
      debugPrint('fb.FirebaseAuth sync: failed $e');
    }
  }

  /// Update password in Firestore
  Future<void> updatePasswordInFirestore({
    required String userId,
    required String passwordHash,
    required String? salt,
    required int? iterations,
  }) async {
    try {
      if (Firebase.apps.isEmpty) return;
      await FirebaseThreadingHandler.executeWithThreadSafety(
        () => _firestore.collection('users').doc(userId).set({
          'password_hash': passwordHash,
          'salt': salt,
          'iterations': iterations,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true)),
        operationName: 'FirestoreAuthSync updatePasswordInFirestore',
      );
    } catch (e) {
      debugPrint('Error updating password in Firestore: $e');
    }
  }
}
