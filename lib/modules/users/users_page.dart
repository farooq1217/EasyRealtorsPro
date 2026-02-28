import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey, FilteringTextInputFormatter, Clipboard, ClipboardData;
// REMOVED: Firestore dependencies for SQLite-only operation
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// Add back minimal Firebase imports for helper methods to work
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../core/services/auth_service.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
import '../../core/professional_pdf_generator.dart';
import '../../core/phone_actions.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart';
// REMOVED: Firestore services for SQLite-only operation
// import '../../core/services/firestore_cache_service.dart';
// import '../../firestore_sync_service.dart';
import '../../image_cache_service.dart';
import '../../responsive_widgets.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../firestore_sync_service.dart';
import '../../core/services/sync_database_helper.dart';
import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../core/shared_utils.dart' show TopRightSearch;

class UsersPage extends StatefulWidget {
  final AppDatabase db;
  const UsersPage({super.key, required this.db});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<Map<String, dynamic>> _rows = [];
  String _q = '';
  bool _loading = false;
  // REMOVED: Firestore-related state variables for SQLite-only operation
  // bool _firestoreReady = false;
  Map<String, dynamic>? _editingUser;
  List<Map<String, String>> _companies = [];
  Map<String, dynamic>? _currentUser;
  bool _backfillingUserIds = false;
  bool _backfillUserIdsDone = false;

  // Sync helper for marking records as unsynced
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();

  // Firestore subscriptions for real-time sync
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  FirestoreSyncState _syncState = FirestoreSyncState();

  // SQLite-only flag - disables all Firestore operations
  static const bool _sqliteOnlyMode = true;

  // Helper method to disable Firestore operations in SQLite-only mode
  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode && Firebase.apps.isNotEmpty;
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

  // Firebase Auth methods for SQLite-only operation
  Future<void> _ensureFirebaseAuth() async {
    if (Firebase.apps.isEmpty) return;
    if (!kIsWeb && io.Platform.isWindows) return;
    await AuthService.ensureFirebasePersistence();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        debugPrint('FirebaseAuth sign-in failed: $e');
      }
    }
    debugPrint('FirebaseAuth UID (agents): ${auth.currentUser?.uid ?? 'none'}');
  }

  Future<bool> _setUserClaims({
    required String uid,
    required String role,
    required String companyId,
    Map<String, dynamic>? perms,
  }) async {
    if (Firebase.apps.isEmpty) return false;
    try {
      // REMOVED: Firebase Auth for SQLite-only operation
      // await _ensureFirebaseAuth();
      // Cloud Functions removed for Spark plan; no-op
      debugPrint('Skipping setUserClaims for uid=$uid (Spark plan, no functions)');
      return true;
    } catch (e) {
      debugPrint('Failed to set custom claims for $uid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user claims: $e')),
        );
      }
      return false;
    }
  }
  Future<void> _ensureActiveColumns() async {
    try {
      await widget.db.customStatement('ALTER TABLE companies ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await widget.db.customStatement('UPDATE companies SET is_active = 1 WHERE is_active IS NULL');
    } catch (_) {}
    try {
      await widget.db.customStatement('ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await widget.db.customStatement('UPDATE users SET is_active = 1 WHERE is_active IS NULL');
    } catch (_) {}
    try {
      await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await widget.db.customStatement('UPDATE trading_entries SET is_active = 1 WHERE is_active IS NULL');
    } catch (_) {}
    try {
      await widget.db.customStatement('ALTER TABLE trading_file_entries ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await widget.db.customStatement('UPDATE trading_file_entries SET is_active = 1 WHERE is_active IS NULL');
    } catch (_) {}
  }
  Future<void> _syncUsersFromFirestore() async {
    await _executeFirestoreOperation(() async {
      if (Firebase.apps.isEmpty) return;
      try {
        final snap = await FirebaseFirestore.instance.collection('users').get();
        if (snap.docs.isEmpty) return;

        final nowIso = DateTime.now().toUtc().toIso8601String();
        await widget.db.batch((batch) {
          for (final doc in snap.docs) {
            final data = doc.data();
            final id = (data['id'] ?? doc.id).toString();
            if (id.trim().isEmpty) continue;

            final username = (data['username'] ?? '').toString();
            final userId = (data['user_id'] ?? data['userId'] ?? '').toString();
            final name = (data['name'] ?? '').toString();
            final email = (data['email'] ?? '').toString();
            final contactNo = (data['contact_no'] ?? data['contactNo'] ?? '').toString();
            final permissions = data['permissions'];
            final status = (data['status'] ?? 'active').toString();
            final cid = (data['company_id'] ?? data['companyId'])?.toString();
            final createdAt = (data['created_at'] ?? data['createdAt'] ?? nowIso).toString();
            final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? nowIso).toString();
            final isActiveRaw = data['is_active'] ?? data['isActive'];
            final isActive = isActiveRaw == null ? 1 : ((isActiveRaw is bool ? (isActiveRaw ? 1 : 0) : int.tryParse(isActiveRaw.toString()) ?? 1));

            batch.customStatement(
              'INSERT OR REPLACE INTO users (id, username, user_id, name, email, contact_no, permissions, company_id, status, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [id, username, userId, name, email, contactNo, permissions != null ? jsonEncode(permissions) : null, cid, status, isActive, createdAt, updatedAt],
            );
          }
        });
      } catch (_) {}
    });
  }

  // Helper methods for form field decoration
  InputDecoration _fieldDecoration(String label, {
    bool isRequired = false,
    Widget? suffixIcon,
    IconData? fieldIcon,
  }) {
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('email')) {
        fieldIcon = Icons.email_outlined;
      } else if (lowerLabel.contains('contact') || lowerLabel.contains('phone')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('password')) {
        fieldIcon = Icons.lock_outline;
      } else if (lowerLabel.contains('permission') || lowerLabel.contains('restriction')) {
        fieldIcon = Icons.security;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }
    return InputDecoration(
      labelText: isRequired ? null : label,
      label: isRequired
          ? RichText(
              text: TextSpan(
                text: label,
                style: AppFonts.poppins(color: Colors.grey.shade700),
                children: [
                  TextSpan(
                    text: ' *',
                    style: AppFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : null,
      prefixIcon: fieldIcon != null ? Icon(fieldIcon, color: Colors.grey.shade700) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23272E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: AppFonts.poppins(color: Colors.grey.shade700),
    );
  }

  String _getPermissionLabel(dynamic permissions) {
    try {
      if (permissions is String) {
        final perms = jsonDecode(permissions);
        return perms['permission']?.toString() ?? 'N/A';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _guardUnauthorized();
      await _ensureActiveColumns();
      await _loadCurrentUser();
      // REMOVED: Firestore sync for SQLite-only operation
      // await _syncUsersFromFirestore();
      await _loadCompanies();
      await _load();
    });
  }

  void _guardUnauthorized() {
    final role = (_currentUser?['role'] ?? '').toString().toLowerCase();
    final isAgent = RoleUtils.isAgent(_currentUser);
    final isUserRole = role == 'user';
    if (isAgent || isUserRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Denied'),
            content: const Text('You are not authorized to view Users.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    // REMOVED: Firestore subscription cancellation for SQLite-only operation
    // _firestoreSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      final user = await AuthService().getCurrentUser(authToken);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<List<Map<String, String>>?> _loadCompanies() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, name FROM companies WHERE (is_active = 1 OR is_active IS NULL) ORDER BY name'
            : 'SELECT id, name FROM companies WHERE (is_active = 1 OR is_active IS NULL) ORDER BY name',
      ).get();
      
      if (mounted) {
        setState(() {
          _companies = res.map((row) => {
            'id': row.data['id']?.toString() ?? '',
            'name': row.data['name']?.toString() ?? '',
          }).toList();
        });
      }
      return _companies; // Fix: Return value add ki
    } catch (e) {
      debugPrint('Error loading companies: $e');
      return []; // Fix: Error case mein khali list return ki
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? '''
              SELECT id, username, user_id, name, email, contact_no, permissions, company_id, status, is_active, created_at, updated_at
              FROM users 
              WHERE (is_active = 1 OR is_active IS NULL) 
              ORDER BY updated_at DESC
            '''
            : '''
              SELECT id, username, user_id, name, email, contact_no, permissions, company_id, status, is_active, created_at, updated_at
              FROM users 
              WHERE (company_id = ? OR company_id IS NULL) AND (is_active = 1 OR is_active IS NULL)
              ORDER BY updated_at DESC
            ''',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      
      if (mounted) {
        setState(() {
          _rows = res.map((row) {
            final data = row.data; // Local variable for cleaner null safety
            return {
              'id': data['id']?.toString() ?? '',
              'username': data['username']?.toString() ?? '',
              'user_id': data['user_id']?.toString() ?? '',
              'name': data['name']?.toString() ?? '',
              'email': data['email']?.toString() ?? '',
              'contact_no': data['contact_no']?.toString() ?? '',
              'permissions': data['permissions'],
              'company_id': data['company_id']?.toString() ?? '',
              'status': data['status']?.toString() ?? 'active',
              'is_active': data['is_active'] ?? 1,
              'created_at': data['created_at']?.toString() ?? '',
              'updated_at': data['updated_at']?.toString() ?? '',
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncCompaniesFromFirestore() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('companies').get();
      if (snap.docs.isEmpty) return;

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await widget.db.batch((batch) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final id = doc.id.toString();
          if (id.trim().isEmpty) continue;

          final name = (data['name'] ?? 'No Name').toString();
          final status = (data['status'] ?? 'inactive').toString();
          final metadataRaw = data['metadata'];
          final metadata = metadataRaw == null
              ? null
              : (metadataRaw is String ? metadataRaw : jsonEncode(metadataRaw));
          final logoUrl = (data['logo_url'] ?? data['logoUrl'])?.toString();
          final address = data['address']?.toString();
          final contact = data['contact']?.toString();
          final maxRaw = data['max_user_limit'] ?? data['maxUserLimit'] ?? 5;
          final maxUserLimit = maxRaw is int ? maxRaw : int.tryParse(maxRaw.toString());
          final tier = (data['subscription_tier'] ?? data['subscriptionTier'] ?? 'Starter').toString();
          final createdAt = (data['created_at'] ?? data['createdAt'] ?? nowIso).toString();
          final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? nowIso).toString();

          batch.customStatement(
            'INSERT OR REPLACE INTO companies (id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              id,
              name,
              status,
              metadata,
              logoUrl,
              address,
              contact,
              maxUserLimit,
              tier,
              createdAt,
              updatedAt,
            ],
          );
        }
      });
    } catch (_) {}
  }

  
  // Test method to query user by email
  Future<void> _testQueryUserByEmail(String email) async {
    try {
      debugPrint('\nðŸ” Querying user with email: $email');
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      
      final result = await widget.db.customSelect(
        'SELECT * FROM users WHERE email = ?',
        variables: [d.Variable.withString(email)],
      ).get();
      
      if (result.isEmpty) {
        debugPrint('âŒ No user found with email: $email');
        debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No user found with email: $email'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      
      debugPrint('âœ… Found ${result.length} user(s) with email: $email\n');
      
      for (var row in result) {
        debugPrint('ðŸ“‹ User Details:');
        row.data.forEach((key, value) {
          // Don't print full password hash for security, just show it exists
          if (key == 'password_hash' && value != null) {
            final hash = value.toString();
            debugPrint('   $key: ${hash.substring(0, hash.length > 30 ? 30 : hash.length)}... (hidden)');
          } else {
            debugPrint('   $key: $value');
          }
        });
        debugPrint('');
      }
      
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${result.length} user(s). Check console for details.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('âŒ Error querying user: $e');
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Method to check password hash (password cannot be retrieved, only reset)
  Future<void> _checkUserPasswordInfo(String email) async {
    try {
      debugPrint('\nðŸ” Checking Password Information for: $email');
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      
      final result = await widget.db.customSelect(
        'SELECT id, username, email, password_hash, salt, iterations, is_first_login, company_id FROM users WHERE email = ?',
        variables: [d.Variable.withString(email)],
      ).get();
      
      if (result.isEmpty) {
        debugPrint('âŒ No user found with email: $email\n');
        return;
      }
      
      final userData = result.first.data;
      final passwordHash = userData['password_hash'] as String?;
      final salt = userData['salt'] as String?;
      final iterations = userData['iterations'] as int?;
      final isFirstLogin = userData['is_first_login'] as int? ?? 0;
      final companyId = userData['company_id'] as String?;
      
      debugPrint('âš ï¸  SECURITY NOTE:');
      debugPrint('   Passwords are stored as HASHED values for security.');
      debugPrint('   The original password CANNOT be retrieved from the database.\n');
      
      debugPrint('ðŸ“‹ Password Hash Information:');
      if (passwordHash != null) {
        debugPrint('   Password Hash: ${passwordHash.substring(0, passwordHash.length > 50 ? 50 : passwordHash.length)}...');
        debugPrint('   Salt: ${salt ?? "N/A"}');
        debugPrint('   Iterations: ${iterations ?? "N/A"}');
        debugPrint('   Hash Format: ${passwordHash.split(":").length} parts');
      } else {
        debugPrint('   âš ï¸  No password hash found!');
      }
      
      debugPrint('\nðŸ‘¤ User Status:');
      debugPrint('   Username: ${userData['username']}');
      debugPrint('   Email: ${userData['email']}');
      debugPrint('   is_first_login: $isFirstLogin ${isFirstLogin == 1 ? "(Must change password)" : "(Password already changed)"}');
      debugPrint('   Company ID: ${companyId ?? "None (Regular User)"}');
      
      if (isFirstLogin == 1 && companyId != null) {
        debugPrint('\nðŸ’¡ IMPORTANT:');
        debugPrint('   This is a Company Admin with is_first_login = true.');
        debugPrint('   The temporary password was shown when the user was created.');
        debugPrint('   If you don\'t have it, you need to RESET the password.\n');
      }
      
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password info retrieved. Check console. Original password cannot be retrieved.'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('âŒ Error: $e\n');
    }
  }

  Future<void> _backfillMissingUserIds(List<Map<String, dynamic>> viewRows) async {
    if (_backfillUserIdsDone) return;
    if (_backfillingUserIds) return;
    _backfillingUserIds = true;
    try {
      final missing = viewRows.where((r) {
        final uid = r['user_id']?.toString().trim() ?? '';
        return uid.isEmpty;
      }).toList();
      if (missing.isEmpty) {
        _backfillUserIdsDone = true;
        return;
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final year = DateTime.now().year;

      int extractSeq(String raw) {
        final v = raw.trim().toUpperCase();
        final mUsr = RegExp(r'^USR-(\\d{4})-(\\d{1,6})$').firstMatch(v);
        if (mUsr != null) {
          final y = int.tryParse(mUsr.group(1) ?? '');
          if (y != year) return 0;
          final n = int.tryParse(mUsr.group(2) ?? '');
          return n ?? 0;
        }
        return 0;
      }

      final all = await widget.db.customSelect(
        'SELECT company_id, user_id FROM users',
      ).get();

      final maxSeqByCompany = <String, int>{};
      final usedByCompany = <String, Set<String>>{};

      for (final r in all) {
        final m = r.data;
        final companyId = (m['company_id'] ?? '').toString();
        final rawUserId = (m['user_id'] ?? '').toString();
        final used = usedByCompany.putIfAbsent(companyId, () => <String>{});
        if (rawUserId.trim().isNotEmpty) {
          used.add(rawUserId.trim().toUpperCase());
        }
        final seq = extractSeq(rawUserId);
        final currentMax = maxSeqByCompany[companyId] ?? 0;
        if (seq > currentMax) maxSeqByCompany[companyId] = seq;
      }

      for (final r in missing) {
        final id = (r['id'] ?? '').toString();
        if (id.trim().isEmpty) continue;
        final companyId = (r['company_id'] ?? '').toString();

        String next;
        if (companyId.trim().isEmpty) {
          next = 'USR-$year-000';
        } else {
          final used = usedByCompany.putIfAbsent(companyId, () => <String>{});
          var seq = (maxSeqByCompany[companyId] ?? 0) + 1;
          while (used.contains('USR-$year-${seq.toString().padLeft(3, '0')}')) {
            seq++;
          }
          next = 'USR-$year-${seq.toString().padLeft(3, '0')}';
          maxSeqByCompany[companyId] = seq;
          used.add(next.toUpperCase());
        }

        await widget.db.customStatement(
          'UPDATE users SET user_id = ?, updated_at = ? WHERE id = ?',
          [next, nowIso, id],
        );

        if (Firebase.apps.isNotEmpty) {
          try {
            final emailKey = (r['email'] ?? r['username'])?.toString().toLowerCase();
            final docId = (emailKey != null && emailKey.isNotEmpty) ? emailKey : id;
            await FirebaseFirestore.instance.collection('users').doc(docId).set({
              'user_id': next,
              'userId': next,
              'updated_at': nowIso,
            }, SetOptions(merge: true));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Backfill user_id Firestore sync failed for users/$id: $e');
            }
          }
        }

        r['user_id'] = next;
      }

      _backfillUserIdsDone = true;
    } finally {
      _backfillingUserIds = false;
    }
  }

  void _showAddFormDialog({Map<String, dynamic>? existing}) {
    // Refresh companies list right before opening so newly added companies appear
    _loadCompanies();
    setState(() {
      _editingUser = existing;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              _editingUser = null;
            });
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 600 ? 8 : 16,
            vertical: MediaQuery.of(context).size.height < 800 ? 8 : 16,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: StatefulBuilder(
                builder: (dialogContext, setDialogState) {
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 56),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildAddUserForm(setDialogState, dialogContext),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _editingUser = null;
                              });
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.grey.shade800,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetUserForm() {
    setState(() {
      _editingUser = null;
    });
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: AppFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddUserForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {
    final existing = _editingUser;
    final nameCtl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final userIdCtl = TextEditingController(text: (existing?['user_id'] ?? existing?['userId'])?.toString() ?? '');
    final emailCtl = TextEditingController(text: existing?['email']?.toString() ?? existing?['username']?.toString() ?? '');
    final usernameCtl = TextEditingController(text: existing?['username']?.toString() ?? '');
    final contactCtl = TextEditingController(text: existing?['contact_no']?.toString() ?? '');
    final passwordCtl = TextEditingController();
    String? selectedPermission;
    const String? defaultCompanyId = null;
    String? selectedCompanyId = existing?['company_id']?.toString() ?? defaultCompanyId;
    String selectedRole = 'agent';
    const moduleDefs = [
      {'key': 'inventory', 'label': 'Inventory'},
      {'key': 'agent_working', 'label': 'Agent Working'},
      {'key': 'rental_items', 'label': 'Rental Items'},
      {'key': 'todo', 'label': 'To-Do'},
      {'key': 'trading', 'label': 'Trading'},
      {'key': 'expenditure', 'label': 'Expenditure'},
    ];

    final Map<String, String> modulePermissions = {
      'inventory': 'view_add',
      'agent_working': 'view_add',
      'rental_items': 'view_add',
      'todo': 'view_add',
      'trading': 'view_add',
      'expenditure': 'view_add',
    };
    Map<String, String> _sanitizeModulePermissions(Map<String, String> source) {
      const allowedValues = {'no_access', 'view_only', 'view_add', 'view_add_edit', 'full_access'};
      final allowedKeys = moduleDefs.map((m) => m['key']!).toSet();
      final cleaned = <String, String>{};
      for (final key in allowedKeys) {
        final raw = (source[key] ?? '').toString().trim();
        cleaned[key] = allowedValues.contains(raw) ? raw : 'no_access';
      }
      return cleaned;
    }

    Map<String, dynamic> _buildPermissionsPayload(List<Map<String, String>> roleOptions) {
      selectedPermission ??= 'view_add';
      final allowedRoles = roleOptions.map((o) => o['value']!).toSet();
      if (!allowedRoles.contains(selectedRole)) {
        selectedRole = 'agent';
      }

      Map<String, String> modulePermissionsMap = <String, String>{};
      if (selectedRole == 'agent') {
        modulePermissionsMap = _sanitizeModulePermissions(modulePermissions);
        final values = modulePermissionsMap.values;
        if (values.isNotEmpty && values.every((v) => v.trim() == 'no_access')) {
          selectedPermission = 'no_access';
        } else if (values.any((v) => v.trim() == 'view_add' || v.trim() == 'view_add_edit')) {
          selectedPermission = 'view_add';
        } else {
          selectedPermission = 'view_only';
        }
      }

      final permissionsMap = {
        'permission': selectedPermission,
        'role': selectedRole,
        'canView': selectedPermission != 'no_access',
        'canAdd': selectedPermission == 'view_add' || selectedPermission == 'full_access',
        'canEdit': selectedPermission == 'full_access',
        'canDelete': selectedPermission == 'full_access',
        'permissionsMap': modulePermissionsMap,
      };

      final encoded = jsonEncode(permissionsMap);
      // Defensive guard against accidental oversized payloads that can exceed Firestore's 1MB field limit.
      if (encoded.length > 900000) {
        debugPrint('Permissions payload too large (${encoded.length}). Sending minimal permissions only.');
        return {
          'permission': selectedPermission,
          'role': selectedRole,
          'canView': selectedPermission != 'no_access',
          'canAdd': selectedPermission == 'view_add' || selectedRole != 'agent',
          'canEdit': selectedPermission == 'full_access' || selectedRole != 'agent',
          'canDelete': selectedPermission == 'full_access',
          'permissionsMap': <String, String>{},
        };
      }

      return permissionsMap;
    }
    final formKey = GlobalKey<FormState>();

    String? _userIdError;

    bool _checkingUserLimit = false;
    bool _userLimitReached = false;
    int? _currentActiveUsers;
    int? _maxUserLimit;
    String? _checkedCompanyId;
    bool _limitInitDone = false;
    bool _userIdInitDone = false;

    Future<void> _autoGenerateUserId({required String companyId, required StateSetter setLocal}) async {
      if (existing != null) return;
      if (_userIdInitDone) return;
      if (userIdCtl.text.trim().isNotEmpty) {
        _userIdInitDone = true;
        return;
      }
      _userIdInitDone = true;
      try {
        final year = DateTime.now().year;
        final res = await widget.db.customSelect(
          'SELECT user_id FROM users WHERE company_id = ? AND user_id IS NOT NULL',
          variables: [d.Variable.withString(companyId)],
        ).get();

        int extractSeq(String raw) {
          final v = raw.trim().toUpperCase();
          final mUsr = RegExp(r'^USR-(\d{4})-(\d{1,6})$').firstMatch(v);
          if (mUsr != null) {
            final y = int.tryParse(mUsr.group(1) ?? '');
            if (y != year) return 0;
            final n = int.tryParse(mUsr.group(2) ?? '');
            return n ?? 0;
          }
          return 0;
        }

        final used = <String>{};
        var maxNum = 0;
        for (final row in res) {
          final raw = row.data['user_id']?.toString() ?? '';
          final upper = raw.trim().toUpperCase();
          if (upper.isNotEmpty) used.add(upper);
          final n = extractSeq(raw);
          if (n > maxNum) maxNum = n;
        }

        var next = maxNum + 1;
        var suggested = 'USR-$year-${next.toString().padLeft(3, '0')}';
        while (used.contains(suggested.toUpperCase())) {
          next++;
          suggested = 'USR-$year-${next.toString().padLeft(3, '0')}';
        }

        userIdCtl.text = suggested;
        setLocal(() {});
      } catch (_) {
        // ignore auto-suggest failures
      }
    }

    Future<void> _ensureUniqueUserId({
      required String companyId,
      required String currentUserId,
      required StateSetter setLocal,
    }) async {
      if (existing != null) return;
      final year = DateTime.now().year;

      Future<bool> isUnique(String candidate) async {
        final res = await widget.db.customSelect(
          'SELECT COUNT(*) as c FROM users WHERE company_id = ? AND user_id = ? AND id != ?',
          variables: [
            d.Variable.withString(companyId),
            d.Variable.withString(candidate),
            d.Variable.withString(currentUserId),
          ],
        ).getSingle();
        final cRaw = res.data['c'];
        final c = cRaw is int ? cRaw : int.tryParse(cRaw?.toString() ?? '0') ?? 0;
        return c == 0;
      }

      int extractSeqForYear(String raw) {
        final v = raw.trim().toUpperCase();
        final m = RegExp(r'^USR-(\d{4})-(\d{1,6})$').firstMatch(v);
        if (m == null) return 0;
        final y = int.tryParse(m.group(1) ?? '');
        if (y != year) return 0;
        final n = int.tryParse(m.group(2) ?? '');
        return n ?? 0;
      }

      Future<String> nextCandidate({int? minSeq}) async {
        final res = await widget.db.customSelect(
          'SELECT user_id FROM users WHERE company_id = ? AND user_id IS NOT NULL',
          variables: [d.Variable.withString(companyId)],
        ).get();

        final used = <String>{};
        var maxNum = 0;
        for (final row in res) {
          final raw = row.data['user_id']?.toString() ?? '';
          final upper = raw.trim().toUpperCase();
          if (upper.isNotEmpty) used.add(upper);
          final n = extractSeqForYear(raw);
          if (n > maxNum) maxNum = n;
        }

        var seq = (minSeq != null && minSeq > maxNum) ? minSeq : (maxNum + 1);
        var candidate = 'USR-$year-${seq.toString().padLeft(3, '0')}';
        while (used.contains(candidate.toUpperCase())) {
          seq++;
          candidate = 'USR-$year-${seq.toString().padLeft(3, '0')}';
        }
        return candidate;
      }

      int? currentSeq;
      final currentRaw = userIdCtl.text.trim();
      if (currentRaw.isNotEmpty) {
        final n = extractSeqForYear(currentRaw);
        if (n > 0) currentSeq = n;
      }

      for (var attempt = 0; attempt < 25; attempt++) {
        if (userIdCtl.text.trim().isEmpty) {
          userIdCtl.text = await nextCandidate();
          setLocal(() {
            _userIdError = null;
          });
        }

        final cand = userIdCtl.text.trim();
        final unique = await isUnique(cand);
        if (unique) return;

        currentSeq = (currentSeq ?? extractSeqForYear(cand));
        userIdCtl.text = await nextCandidate(minSeq: (currentSeq ?? 0) + 1);
        setLocal(() {
          _userIdError = null;
        });
      }

      setLocal(() => _userIdError = 'Failed to generate unique User ID. Please try again.');
      throw Exception('Failed to generate unique User ID');
    }

    Future<bool> _isUserIdUnique({
      required String companyId,
      required String userId,
      required String currentUserId,
    }) async {
      final res = await widget.db.customSelect(
        'SELECT COUNT(*) as c FROM users WHERE company_id = ? AND user_id = ? AND id != ?',
        variables: [
          d.Variable.withString(companyId),
          d.Variable.withString(userId),
          d.Variable.withString(currentUserId),
        ],
      ).getSingle();
      final cRaw = res.data['c'];
      final c = cRaw is int ? cRaw : int.tryParse(cRaw?.toString() ?? '0') ?? 0;
      return c == 0;
    }

    Future<void> _refreshUserLimit({required String companyId, required StateSetter setLocal}) async {
      if (!mounted) return;
      if (_checkingUserLimit && _checkedCompanyId == companyId) return;
      final wasReached = _userLimitReached;
      _checkingUserLimit = true;
      _checkedCompanyId = companyId;
    final companyIdStr = companyId.toString();
      await _syncCompaniesFromFirestore(); // ensure latest companies (including companyIdStr) are present locally
      setLocal(() {});
      try {
        int? limit;
        int? cnt;
        String tier = 'Starter';

        if (Firebase.apps.isNotEmpty) {
          try {
          final doc = await FirebaseFirestore.instance.collection('companies').doc(companyIdStr).get();
            if (!doc.exists) {
            debugPrint('UserLimit: Firestore companies/$companyIdStr not found. Looking for ID: $companyIdStr');
            }
            final data = doc.data();
            final raw = data?['max_user_limit'] ?? data?['maxUserLimit'];
            limit = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
            tier = normalizeSubscriptionTier(data?['subscription_tier'] ?? data?['subscriptionTier']);
          } catch (e) {
            if (kDebugMode) {
            debugPrint('UserLimit: Firestore company limit read failed for companyId=$companyIdStr: $e');
            }
          }

          try {
            QuerySnapshot<Map<String, dynamic>> snap;
          snap = await FirebaseFirestore.instance.collection('users').where('company_id', isEqualTo: companyIdStr).get();
            if (snap.docs.isEmpty) {
            snap = await FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: companyIdStr).get();
            }
            final docs = snap.docs.map((d) => d.data()).toList();
            cnt = docs.where((u) {
              final status = (u['status'] ?? 'active').toString().trim().toLowerCase();
              final isDeleted = (u['isDeleted'] == true) || (u['is_deleted'] == true);
              final deletedAt = u['deleted_at'];
              if (isDeleted) return false;
              if (deletedAt != null && deletedAt.toString().trim().isNotEmpty) return false;
              if (status == 'inactive' || status == 'deleted') return false;
              if (status.isNotEmpty && status != 'active') return false;
              final role = (u['role'] ?? (u['permissions'] is Map ? (u['permissions'] as Map)['role'] : null))?.toString();
              return role != 'super_admin';
            }).length;
          } catch (e) {
            if (kDebugMode) {
              debugPrint('UserLimit: Firestore user count failed for companyId=$companyId: $e');
            }
          }
        }

        if (limit == null || cnt == null) {
          final limitRes = await widget.db.customSelect(
            'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',
            variables: [d.Variable.withString(companyId)],
          ).get();

          final row = limitRes.isNotEmpty ? limitRes.first.data : null;
          final limitRaw = row?['max_user_limit'];
          final tierRaw = row?['subscription_tier'];
          tier = normalizeSubscriptionTier(tierRaw ?? tier);
          limit ??= (limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? ''));
          limit ??= subscriptionLimitForTier(tier);

          final countRes = await widget.db.customSelect(
            "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL)",
            variables: [d.Variable.withString(companyId)],
          ).get();

          final cntRaw = countRes.isNotEmpty ? countRes.first.data['cnt'] : 0;
          cnt ??= cntRaw is int ? cntRaw : int.tryParse(cntRaw.toString()) ?? 0;
        }

        if (kDebugMode) {
          debugPrint('UserLimit: companyId=$companyId subscription_tier=$tier max_user_limit=$limit current_active_agents=$cnt');
        }

        _maxUserLimit = limit;
        _currentActiveUsers = cnt;
        _userLimitReached = (cnt ?? 0) >= (limit ?? 5);
      } catch (_) {
        _maxUserLimit = null;
        _currentActiveUsers = null;
        _userLimitReached = false;
      } finally {
        _checkingUserLimit = false;
        setLocal(() {});
      }

      if (!wasReached && _userLimitReached && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Limit reached: ${_currentActiveUsers ?? '?'} / ${_maxUserLimit ?? '?'} active users in use. Please contact Super Admin to upgrade your plan.')),
        );
      }
    }
    
    // Parse existing permissions if editing
    if (existing != null && existing['permissions'] != null) {
      try {
        final rawPerms = existing['permissions'];
        // Skip decoding if the stored payload is unexpectedly large to prevent re-writing oversized data back to Firestore.
        if (rawPerms is String && rawPerms.length > 900000) {
          debugPrint('Skipping oversized permissions payload (${rawPerms.length}) for existing user.');
        } else {
          final perms = rawPerms is String ? jsonDecode(rawPerms) : rawPerms;
        selectedPermission = perms['permission']?.toString();
        selectedRole = perms['role']?.toString() ?? 'agent';
        final rawMap = perms['permissionsMap'];
        if (rawMap is Map) {
          rawMap.forEach((k, v) {
            final key = k.toString();
            final val = v?.toString() ?? '';
            if (modulePermissions.containsKey(key) && val.isNotEmpty) {
              modulePermissions[key] = val;
            }
          });
        } else {
          final legacy = PermissionHelper.getPermissionLevel(existing);
          final mapped = PermissionHelper.normalizeLegacyToModuleLevel(legacy);
          for (final k in modulePermissions.keys) {
            modulePermissions[k] = mapped;
          }
        }
        }
      } catch (e) {
        // Ignore parse errors
      }
    }

    // Force form to always be visible - removed _currentUser null check
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);
    // Removed: if (!isSuperAdmin && !isCompanyAdmin) return const SizedBox.shrink();
    final myCompanyId = RoleUtils.getUserCompanyId(_currentUser);
    if (isCompanyAdmin) {
      selectedRole = 'agent';
      selectedCompanyId = myCompanyId;
    }
    if (selectedRole == 'agent' && (selectedPermission == null || selectedPermission!.trim().isEmpty)) {
      selectedPermission = 'view_add';
    }
    
    final permissionOptions = [
      {'value': 'view_only', 'label': 'View Only - Can only view data'},
      {'value': 'view_add', 'label': 'View & Add - Can view and add data'},
      if (isSuperAdmin) {'value': 'full_access', 'label': 'Full Access - Can view, add, edit, and delete data'},
      {'value': 'no_access', 'label': 'No Access - Cannot view or add data'},
    ];

    const modulePermissionOptions = [
      {'value': 'no_access', 'label': 'No Access'},
      {'value': 'view_only', 'label': 'View Only'},
      {'value': 'view_add', 'label': 'View & Add'},
      {'value': 'view_add_edit', 'label': 'View, Add & Edit'},
    ];

    final roleOptions = const [
      {'value': 'agent', 'label': 'Agent'},
      {'value': 'manager', 'label': 'Manager'},
      {'value': 'admin', 'label': 'Admin'},
      {'value': 'company_admin', 'label': 'Company Admin'},
    ];

    return StatefulBuilder(
      builder: (context, setLocal) {
        if (!_limitInitDone && existing == null) {
          _limitInitDone = true;
          final cid = (isCompanyAdmin ? myCompanyId : selectedCompanyId);
          if (cid != null && cid.trim().isNotEmpty) {
            Future.microtask(() => _refreshUserLimit(companyId: cid, setLocal: setLocal));
          }
        }
        final cidForEmp = (isCompanyAdmin ? myCompanyId : selectedCompanyId);
        if (existing == null && cidForEmp != null && cidForEmp.trim().isNotEmpty) {
          Future.microtask(() => _autoGenerateUserId(companyId: cidForEmp, setLocal: setLocal));
        }
        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing == null ? 'Add New User' : 'Edit User',
                style: AppFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: userIdCtl,
                decoration: _fieldDecoration('User ID', isRequired: true).copyWith(errorText: _userIdError),
                readOnly: true,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'User ID is required';
                  if (v.length > 20) return 'Maximum 20 characters allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtl,
                decoration: _fieldDecoration('Name', isRequired: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.length > 100) {
                    return 'Maximum 100 characters allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtl,
                decoration: _fieldDecoration('E-mail', isRequired: true),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'E-mail is required';
                  }
                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (existing == null)
                TextFormField(
                  controller: usernameCtl,
                  decoration: _fieldDecoration('Username', isRequired: true, fieldIcon: Icons.person),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
              if (existing == null) const SizedBox(height: 16),
              TextFormField(
                controller: contactCtl,
                decoration: _fieldDecoration('Contact no.', isRequired: true),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Contact no. is required';
                  }
                  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digitsOnly.length != 11) {
                    return 'Contact no. must be exactly 11 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (existing == null)
                TextFormField(
                  controller: passwordCtl,
                  decoration: _fieldDecoration('Temporary Password', isRequired: true),
                  obscureText: true,
                  validator: validatePassword,
                ),
              if (existing == null) const SizedBox(height: 16),
              if (existing == null && isSuperAdmin)
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Role', isRequired: true, fieldIcon: Icons.badge_outlined),
                      value: roleOptions.map((o) => o['value']).contains(selectedRole) ? selectedRole : null,
                      items: roleOptions
                          .map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!)))
                          .toList(),
                      onChanged: (value) {
                        setLocal(() {
                          selectedRole = (value ?? 'agent').trim();
                          if (!roleOptions.map((o) => o['value']).contains(selectedRole)) {
                            selectedRole = 'agent';
                          }
                          if (selectedRole == 'agent') {
                          // Default agent perms: view & add everywhere
                          for (final m in moduleDefs) {
                            modulePermissions[m['key']!] = 'view_add';
                          }
                          selectedPermission = 'view_add';
                        } else if (selectedRole == 'company_admin' || selectedRole == 'admin' || selectedRole == 'super_admin') {
                          // Admin roles default to full_access
                          selectedPermission = 'full_access';
                          for (final m in moduleDefs) {
                            modulePermissions[m['key']!] = 'full_access';
                          }
                        }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please select role';
                        if (!roleOptions.map((o) => o['value']).contains(value)) return 'Invalid role';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
// Company selection (defaults to EasyRealtorsPro)
              FutureBuilder<List<Map<String, String>?>?>(
                future: _loadCompanies(),
                builder: (context, snapshot) {
                  try {
                    // Fix 1: Snapshot data ko safely handle kiya
                    final companies = snapshot.data ?? [];
                    
                    final items = companies
                        .where((c) => c != null) // Sirf non-null items rakhein
                        .map((c) => DropdownMenuItem<String>(
                              value: c!['id'], // Added ! for null safety
                              child: Text(c['name'] ?? ''),
                            ))
                        .toList();

                    final availableIds = items.map((e) => e.value).whereType<String>().toList();
                    final currentCompanyId = selectedCompanyId ?? _currentUser?['company_id']?.toString() ?? _currentUser?['companyId']?.toString();
                    
                    String? coercedCompany = currentCompanyId;
                    if (coercedCompany == null || !availableIds.contains(coercedCompany)) {
                      coercedCompany = null;
                    }
                    selectedCompanyId = coercedCompany;

                    return DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Company', isRequired: true, fieldIcon: Icons.business),
                      // Fix 2: companies list check mein null safety add ki
                      value: companies.any((c) => c != null && c['id'] == coercedCompany) ? coercedCompany : null,
                      hint: const Text('Select Company'),
                      items: items,
                      onChanged: isCompanyAdmin
                          ? null
                          : (value) {
                              setLocal(() {
                                selectedCompanyId = value;
                                _userIdError = null;
                                _userIdInitDone = false;
                                if (existing == null) {
                                  userIdCtl.text = '';
                                }
                              });
                              final cid = value;
                              if (existing == null && cid != null && cid.trim().isNotEmpty) {
                                _refreshUserLimit(companyId: cid, setLocal: setLocal);
                                _autoGenerateUserId(companyId: cid, setLocal: setLocal);
                              }
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please select company';
                        if (!availableIds.contains(value)) return 'Please select company';
                        return null;
                      },
                    );
                  } catch (e) {
                    debugPrint('Company dropdown build failed: $e');
                    return DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Company', isRequired: true, fieldIcon: Icons.business),
                      value: null,
                      hint: const Text('Select Company'),
                      items: const [],
                      onChanged: null,
                      validator: (_) => 'Please select company',
                    );
                  }
                },
              ),
              if (existing == null) const SizedBox(height: 16),
              if (selectedRole != 'agent')
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Restrictions/Permissions', isRequired: true),
                      value: selectedPermission,
                      items: permissionOptions.map((option) {
                        return DropdownMenuItem(
                          value: option['value'],
                          child: Text(option['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setLocal(() {
                          selectedPermission = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select permissions';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              if (selectedRole == 'agent')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module Permissions',
                      style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 520;
                        return Column(
                          children: moduleDefs.map((m) {
                            final moduleKey = m['key']!;
                            final moduleLabel = m['label']!;
                            final currentLevel = modulePermissions[moduleKey] ?? 'no_access';

                            final dropdown = DropdownButtonFormField<String>(
                              value: currentLevel,
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              items: modulePermissionOptions
                                  .map(
                                    (o) => DropdownMenuItem<String>(
                                      value: o['value'],
                                      child: Text(o['label']!),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setLocal(() {
                                  modulePermissions[moduleKey] = value ?? 'no_access';
                                });
                              },
                            );

                            if (isWide) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        moduleLabel,
                                        style: AppFonts.poppins(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: dropdown),
                                  ],
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(moduleLabel, style: AppFonts.poppins(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  dropdown,
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              if (existing == null && selectedCompanyId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _checkingUserLimit
                        ? 'Checking user limit...'
                        : (_maxUserLimit != null && _currentActiveUsers != null)
                            ? 'Active users: $_currentActiveUsers / $_maxUserLimit'
                            : 'User limit status: unknown',
                    style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _resetUserForm();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(
                      'Cancel',
                      style: AppFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PrimaryGradientButton(
                    text: 'Save',
                    icon: Icons.save,
                    onPressed: (existing == null && _userLimitReached)
                        ? null
                        : () async {
                            if (kDebugMode) {
                              debugPrint('AddUser: Save pressed existing=${existing != null} role=$selectedRole selectedCompanyId=$selectedCompanyId myCompanyId=$myCompanyId checking=$_checkingUserLimit reached=$_userLimitReached');
                            }
                            final isValid = formKey.currentState!.validate();
                            if (kDebugMode) {
                              debugPrint('AddUser: form validate -> $isValid');
                            }
                      if (!isValid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                        if (existing == null && passwordCtl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Temporary Password is required'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                            try {
                              // Use normalized email as canonical user ID
                              final email = emailCtl.text.trim();
                              final emailKey = email.toLowerCase();
                              final id = existing != null ? (existing!['id'] as String? ?? emailKey) : emailKey;
                              final nowIso = DateTime.now().toUtc().toIso8601String();
                              final createdIso = existing == null
                                  ? nowIso
                                  : (existing?['created_at']?.toString() ?? existing?['createdAt']?.toString() ?? nowIso);
                              final name = nameCtl.text.trim();
                              final userId = userIdCtl.text.trim();
                              final username = existing == null ? usernameCtl.text.trim() : (existing?['username']?.toString() ?? email);
                              final contactNo = contactCtl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                              final allowedRoles = roleOptions.map((o) => o['value']!).toSet();
                              if (!allowedRoles.contains(selectedRole)) {
                                selectedRole = 'agent';
                              }

                              // Hash the password if creating new user
                              String? hashedPassword;
                              String? salt;
                              int? iterations;
                              String? tempPassword;
                              if (existing == null) {
                                tempPassword = passwordCtl.text;
                                hashedPassword = PasswordHasher.hash(tempPassword);
                                final parts = hashedPassword.split(':');
                                iterations = int.parse(parts[0]);
                                salt = parts[1];
                              }

                              final effectiveCompanyId = isCompanyAdmin ? myCompanyId : selectedCompanyId;
                              if (effectiveCompanyId == null || effectiveCompanyId.trim().isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select company'), backgroundColor: Colors.red),
                                  );
                                }
                                return;
                              }

                              if (existing == null) {
                                try {
                                  await _ensureUniqueUserId(companyId: effectiveCompanyId, currentUserId: id, setLocal: setLocal);
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to generate unique User ID. Please try again.'), backgroundColor: Colors.red),
                                    );
                                  }
                                  return;
                                }
                              } else {
                                final unique = await _isUserIdUnique(
                                  companyId: effectiveCompanyId,
                                  userId: userIdCtl.text.trim(),
                                  currentUserId: id,
                                );
                                if (!unique) {
                                  setLocal(() => _userIdError = 'This User ID is already assigned.');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('This User ID is already assigned.'), backgroundColor: Colors.red),
                                    );
                                  }
                                  return;
                                }
                              }

                              if (existing == null) {
                                int? limit;
                                int? cnt;
                                String tier = 'Starter';

                                if (Firebase.apps.isNotEmpty) {
                                  try {
                                  final doc = await FirebaseFirestore.instance.collection('companies').doc(effectiveCompanyId.toString()).get();
                                    final data = doc.data();
                                    final raw = data?['max_user_limit'] ?? data?['maxUserLimit'];
                                    limit = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
                                    tier = normalizeSubscriptionTier(data?['subscription_tier'] ?? data?['subscriptionTier']);
                                  } catch (e) {
                                    if (kDebugMode) {
                                    debugPrint('UserLimit(final): Firestore company limit read failed for companyId=$effectiveCompanyId: $e');
                                    }
                                  }

                                  try {
                                    QuerySnapshot<Map<String, dynamic>> snap;
                                    snap = await FirebaseFirestore.instance.collection('users').where('company_id', isEqualTo: effectiveCompanyId).get();
                                    if (snap.docs.isEmpty) {
                                      snap = await FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: effectiveCompanyId).get();
                                    }
                                    final docs = snap.docs.map((d) => d.data()).toList();
                                    cnt = docs.where((u) {
                                      final status = (u['status'] ?? 'active').toString().trim().toLowerCase();
                                      final isDeleted = (u['isDeleted'] == true) || (u['is_deleted'] == true);
                                      final deletedAt = u['deleted_at'];
                                      if (isDeleted) return false;
                                      if (deletedAt != null && deletedAt.toString().trim().isNotEmpty) return false;
                                      if (status == 'inactive' || status == 'deleted') return false;
                                      if (status.isNotEmpty && status != 'active') return false;
                                      final role = (u['role'] ?? (u['permissions'] is Map ? (u['permissions'] as Map)['role'] : null))?.toString();
                                      return role != 'super_admin';
                                    }).length;
                                  } catch (e) {
                                    if (kDebugMode) {
                                      debugPrint('UserLimit(final): Firestore user count failed for companyId=$effectiveCompanyId: $e');
                                    }
                                  }
                                }

                                if (limit == null || cnt == null) {
                                  final limitRes = await widget.db.customSelect(
                                    'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',
                                    variables: [d.Variable.withString(effectiveCompanyId)],
                                  ).get();

                                  final row = limitRes.isNotEmpty ? limitRes.first.data : null;
                                  final limitRaw = row?['max_user_limit'];
                                  final tierRaw = row?['subscription_tier'];
                                  tier = normalizeSubscriptionTier(tierRaw ?? tier);
                                  limit ??= (limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? ''));
                                  limit ??= subscriptionLimitForTier(tier);

                                  final countRes = await widget.db.customSelect(
                                    "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL)",
                                    variables: [d.Variable.withString(effectiveCompanyId)],
                                  ).get();

                                  final cntRaw = countRes.isNotEmpty ? countRes.first.data['cnt'] : 0;
                                  cnt ??= cntRaw is int ? cntRaw : int.tryParse(cntRaw.toString()) ?? 0;
                                }

                                if (kDebugMode) {
                                  debugPrint('UserLimit(final): companyId=$effectiveCompanyId subscription_tier=$tier max_user_limit=$limit current_active_agents=$cnt');
                                }

                                if ((cnt ?? 0) >= (limit ?? 5)) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Limit reached: ${cnt ?? '?'} / ${limit ?? '?'} active users in use. Please contact Super Admin to upgrade your plan.')),
                                    );
                                  }
                                  return;
                                }
                              }

                              final isFirstLogin = existing == null && selectedRole == 'company_admin' ? 1 : 0;

                              if (!isSuperAdmin && selectedPermission == 'full_access') {
                                selectedPermission = 'view_add';
                              }

                              // Store permissions as JSON
                              final permissionsMap = _buildPermissionsPayload(roleOptions);
                              final permissionsJson = jsonEncode(permissionsMap);
                              Future<void> _deletePhoneDocIfExists() async {
                                final phoneId = contactNo.trim();
                                if (phoneId.isEmpty) return;
                                if (phoneId == emailKey) return;
                                try {
                                  await FirebaseFirestore.instance.collection('users').doc(phoneId).delete();
                                } catch (_) {}
                              }

                              // Firestore restore check: see if a deleted/old account exists for this email
                              String restoreUserId = id;
                              String restoreCreatedAt = createdIso;
                              bool restoreFound = false;
                              if (existing == null) {
                                try {
                                  if (Firebase.apps.isNotEmpty) {
                                    final snap = await FirebaseFirestore.instance
                                        .collection('users')
                                        .where('email', isEqualTo: emailKey)
                                        .limit(1)
                                        .get();
                                    if (snap.docs.isNotEmpty) {
                                      final doc = snap.docs.first;
                                      final data = doc.data();
                                      final wasDeleted = (data['isDeleted'] == true) || (data['is_deleted'] == true);
                                      final prevCreated = data['created_at'] ?? data['createdAt'];
                                      bool restore = false;
                                      if (wasDeleted) {
                                        restore = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Restore or Create Fresh?'),
                                                content: const Text('This email was used before and is marked deleted. Restore old data or create a fresh account with a new UID?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Create Fresh')),
                                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
                                                ],
                                              ),
                                            ) ??
                                            false;
                                      }
                                      if (restore) {
                                        restoreFound = true;
                                        restoreUserId = doc.id;
                                        if (prevCreated is String && prevCreated.isNotEmpty) {
                                          restoreCreatedAt = prevCreated;
                                        }
                                      } else {
                                        restoreFound = false;
                                        restoreUserId = id;
                                        restoreCreatedAt = createdIso;
                                      }
                                    }
                                  }
                                } catch (_) {}
                              }

                              // Insert or update user using raw SQL to include all new fields
                              if (existing == null) {
                                await widget.db.customStatement(
                                  'INSERT INTO users (id, username, password_hash, salt, iterations, user_id, name, email, contact_no, permissions, company_id, status, is_active, is_first_login, created_at, updated_at, is_synced) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
                                  [
                                    restoreUserId,
                                    username,
                                    hashedPassword,
                                    salt,
                                    iterations,
                                    userIdCtl.text.trim(),
                                    name,
                                    email,
                                    contactNo,
                                    permissionsJson,
                                    effectiveCompanyId,
                                    'active',
                                    1,
                                    isFirstLogin,
                                    restoreCreatedAt,
                                    nowIso
                                  ],
                                );
                                if (kDebugMode) {
                                  debugPrint('AddUser: inserted locally userId=$restoreUserId companyId=$effectiveCompanyId role=$selectedRole');
                                }

                                try {
                                  if (Firebase.apps.isNotEmpty) {
                                    final createdAtTs = Timestamp.fromDate(DateTime.tryParse(createdIso)?.toUtc() ?? DateTime.now().toUtc());
                                    await FirebaseFirestore.instance.collection('users').doc(emailKey).set({
                                      'id': restoreUserId,
                                      'user_uid': restoreUserId,
                                      'username': username,
                                      'user_id': userIdCtl.text.trim(),
                                      'userId': userIdCtl.text.trim(),
                                      'password_hash': hashedPassword,
                                      'salt': salt,
                                      'iterations': iterations,
                                      'name': name,
                                      'email': email,
                                      'contact_no': contactNo,
                                      'company_id': effectiveCompanyId,
                                      'companyId': effectiveCompanyId,
                                      'status': 'active',
                                      'isDeleted': false,
                                      'is_deleted': false,
                                      'role': selectedRole,
                                      'permissions': permissionsMap,
                                      'created_at': restoreCreatedAt.isNotEmpty ? restoreCreatedAt : createdAtTs,
                                      'updated_at': nowIso,
                                    }, SetOptions(merge: true));
                                    if (restoreUserId != emailKey && RegExp(r'^\\d+$').hasMatch(restoreUserId)) {
                                      try {
                                        await FirebaseFirestore.instance.collection('users').doc(restoreUserId).delete();
                                      } catch (_) {}
                                    }
                                    await _deletePhoneDocIfExists();
                                    final claimsOk = await _setUserClaims(
                                      uid: restoreUserId,
                                      role: selectedRole ?? '',
                                      companyId: effectiveCompanyId,
                                      perms: permissionsMap,
                                    );
                                    if (claimsOk && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('User created and claims updated'), backgroundColor: Colors.green),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('Firestore sync failed for users/$restoreUserId: $e');
                                  }
                                }
                                try {
                                  await AuthService().syncUserCacheFromDb(db: widget.db, userId: restoreUserId);
                                  if (kDebugMode) {
                                    debugPrint('USER CREATED AND SYNCED: $email');
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('Cache sync failed for new user $email: $e');
                                  }
                                }
                              } else {
                                debugPrint('DEBUG: SQLite Update Started (update user $id)');
                                // Update existing user (don't change password or is_first_login)
                                await widget.db.customStatement(
                                  'UPDATE users SET username = ?, user_id = ?, name = ?, email = ?, contact_no = ?, permissions = ?, company_id = ?, updated_at = ? WHERE id = ?',
                                  [username, userIdCtl.text.trim(), name, email, contactNo, permissionsJson, effectiveCompanyId, nowIso, id],
                                );
                                debugPrint('DEBUG: SQLite Update Finished (update user $id)');
                                if (kDebugMode) {
                                  debugPrint('AddUser: updated locally userId=$id companyId=$effectiveCompanyId role=$selectedRole');
                                }

                                try {
                                  if (Firebase.apps.isNotEmpty) {
                                    final rawExistingStatus = existing == null ? null : existing['status'];
                                    final existingStatus = ((rawExistingStatus?.toString().trim().isNotEmpty) ?? false)
                                        ? rawExistingStatus.toString()
                                        : 'active';
                                    final normalizedStatus = existingStatus.toString().trim().toLowerCase();
                                    final existingIsDeleted = normalizedStatus == 'inactive' || normalizedStatus == 'deleted';
                                    await FirebaseFirestore.instance.collection('users').doc(emailKey).set({
                                      'username': username,
                                      'user_id': userIdCtl.text.trim(),
                                      'userId': userIdCtl.text.trim(),
                                      if (hashedPassword != null) 'password_hash': hashedPassword,
                                      if (salt != null) 'salt': salt,
                                      if (iterations != null) 'iterations': iterations,
                                      'name': name,
                                      'email': email,
                                      'contact_no': contactNo,
                                      'company_id': effectiveCompanyId,
                                      'companyId': effectiveCompanyId,
                                      'status': existingStatus,
                                      'isDeleted': existingIsDeleted,
                                      'is_deleted': existingIsDeleted,
                                      'role': selectedRole,
                                      'permissions': permissionsMap,
                                      'updated_at': nowIso,
                                      'updatedAt': nowIso,
                                    }, SetOptions(merge: true));
                                    if (id != emailKey && RegExp(r'^\\d+$').hasMatch(id)) {
                                      try {
                                        await FirebaseFirestore.instance.collection('users').doc(id).delete();
                                      } catch (_) {}
                                    }
                                    await _deletePhoneDocIfExists();
                                    final claimsOk = await _setUserClaims(
                                      uid: id,
                                      role: selectedRole ?? '',
                                      companyId: effectiveCompanyId,
                                      perms: permissionsMap,
                                    );
                                    if (claimsOk && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('User updated and claims refreshed'), backgroundColor: Colors.green),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('Firestore sync failed for users/$id: $e');
                                  }
                                }
                              }

                              // Close modal immediately after save (matching trading form pattern)
                              if (mounted) {
                                final wasAdding = existing == null;
                                final navContext = dialogContext ?? context;
                                // Refresh list before closing to avoid snackbar on deactivated widget
                                await _load();
                                _resetUserForm();
                                if (mounted) {
                                  Navigator.of(navContext).pop();
                                }
                                if (wasAdding && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('User created successfully with active status')),
                                  );
                                  // Show credentials if Company Admin was created
                                  if (selectedRole == 'company_admin' && tempPassword != null) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                                            const SizedBox(width: 8),
                                            Text('Company Admin Credentials', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                        content: Builder(
                                          builder: (context) {
                                            final size = MediaQuery.of(context).size;
                                            final w = size.width < 560 ? size.width * 0.9 : 520.0;
                                            final maxH = size.height * 0.7;
                                            return ConstrainedBox(
                                              constraints: BoxConstraints(maxWidth: w, maxHeight: maxH),
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Please share these credentials with the Company Admin:',
                                                      style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.blue.shade200),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          _buildCredentialRow('Username:', username),
                                                          const SizedBox(height: 8),
                                                          _buildCredentialRow('Temporary Password:', tempPassword!),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.shade50,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.orange.shade200),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'The user will be required to change their password on first login.',
                                                              style: AppFonts.poppins(fontSize: 12, color: Colors.orange.shade900),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        actions: [
                                          TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: 'Username: $username\nPassword: $tempPassword'));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Credentials copied to clipboard')),
                                              );
                                            },
                                            icon: const Icon(Icons.copy),
                                            label: const Text('Copy'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User added successfully')),
                                    );
                                  }
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('User updated successfully')),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save user: $e')),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        );
    },
    );
  }

  
  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: confirmColor != null ? ElevatedButton.styleFrom(backgroundColor: confirmColor) : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _toggleUserStatus(String id, bool activate) async {
    final target = _rows.where((r) => (r['id']?.toString() ?? '') == id).toList();
    final targetCompanyId = target.isNotEmpty ? (target.first['company_id'] ?? target.first['companyId'])?.toString() : null;
    final targetEmail = target.isNotEmpty ? (target.first['email'] ?? target.first['username'])?.toString().trim().toLowerCase() : null;
    final targetDocId = (targetEmail != null && targetEmail.isNotEmpty) ? targetEmail : id;
    final targetPhone = target.isNotEmpty ? (target.first['contact_no'] ?? target.first['phone'] ?? target.first['mobile'])?.toString().trim() : null;
    Future<void> _deletePhoneDoc() async {
      if (targetPhone == null || targetPhone!.isEmpty || targetPhone == targetDocId) return;
      try {
        await FirebaseFirestore.instance.collection('users').doc(targetPhone!).delete();
      } catch (_) {}
    }
    final companyIdForUpdate = (targetCompanyId != null && targetCompanyId.isNotEmpty) ? targetCompanyId : '1768415476147';
    final nextStatus = activate ? 'active' : 'inactive';
    final ok = await _confirmAction(
      title: activate ? 'Activate user' : 'Deactivate user',
      message: 'Are you sure you want to mark this user as ${activate ? "active" : "inactive"}?',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      confirmColor: activate ? Colors.green : Colors.orange,
    );
    if (!ok) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    debugPrint('DEBUG: SQLite Update Started (toggle user $id -> $nextStatus)');
    await widget.db.customStatement(
      'UPDATE users SET status = ?, is_active = ?, updated_at = ? WHERE id = ?',
      [nextStatus, activate ? 1 : 0, nowIso, id],
    );
    debugPrint('DEBUG: SQLite Update Finished (toggle user $id)');
    
    // Mark record as unsynced for background sync
    await _syncHelper.markAsUnsynced('users', id);
    setState(() {}); // force repaint
    await _load(); // refresh UI immediately after local update

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(targetDocId).set({
          'status': nextStatus,
          'isDeleted': !activate,
          'is_deleted': !activate,
          'updated_at': nowIso,
          'updatedAt': nowIso,
          'updatedByEmail': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
          'company_id': companyIdForUpdate,
          'companyId': companyIdForUpdate,
        }, SetOptions(merge: true));
        await _deletePhoneDoc();
      }
    } catch (e) {
      debugPrint('Firestore update failed (users toggle): $e');
      if (mounted) {
        final msg = e.toString().toLowerCase().contains('permission-denied')
            ? 'Access Denied: Please check your admin privileges.'
            : 'Failed to update user status: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }

    await AuthService().syncUserCacheFromDb(db: widget.db, userId: id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${activate ? "activated" : "deactivated"}')),
      );
    }
  }

  Future<void> _deleteUser(String id) async {
    final target = _rows.where((r) => (r['id']?.toString() ?? '') == id).toList();
    final targetCompanyId = target.isEmpty ? null : target.first['company_id']?.toString();
    final targetEmail = target.isNotEmpty ? (target.first['email'] ?? target.first['username'])?.toString().trim().toLowerCase() : null;
    final targetDocId = (targetEmail != null && targetEmail.isNotEmpty) ? targetEmail : id;
    final targetPhone = target.isNotEmpty ? (target.first['contact_no'] ?? target.first['phone'] ?? target.first['mobile'])?.toString().trim() : null;
    Future<void> _deletePhoneDoc() async {
      if (targetPhone == null || targetPhone!.isEmpty || targetPhone == targetDocId) return;
      try {
        await FirebaseFirestore.instance.collection('users').doc(targetPhone!).delete();
      } catch (_) {}
    }

    String? targetRole;
    try {
      if (target.isNotEmpty) {
        final p = target.first['permissions'];
        final decoded = p is String ? jsonDecode(p) : p;
        if (decoded is Map) {
          targetRole = decoded['role']?.toString();
        }
      }
    } catch (_) {}
    final ok = await _confirmAction(
      title: 'Delete user',
      message: 'Delete this user from both SQLite and Firestore? This will archive the record.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (!ok) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    debugPrint('DEBUG: SQLite Update Started (delete user $id)');
    await widget.db.customStatement(
      "UPDATE users SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
      [nowIso, id],
    );
    debugPrint('DEBUG: SQLite Update Finished (delete user $id)');
    // Instant UI removal
    if (mounted) {
      setState(() {
        _rows.removeWhere((r) => (r['id']?.toString() ?? '') == id);
      });
    }
    await _load();

    try {
      await AuthService().revokeAllSessions(id);
    } catch (_) {}

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(targetDocId).set(
          {
            'status': 'archived',
            'is_active': 0,
            'isActive': 0,
            'isDeleted': true,
            'is_deleted': true,
            'updated_at': nowIso,
            'deleted_at': nowIso,
            'deleted_by_id': _currentUser?['id']?.toString(),
            'deleted_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
            'company_id': targetCompanyId,
            'companyId': targetCompanyId,
          },
          SetOptions(merge: true),
        );
        await _deletePhoneDoc();

        String _pad2(int v) => v.toString().padLeft(2, '0');
        final now = DateTime.now().toUtc();
        final logId =
            '${now.year}${_pad2(now.month)}${_pad2(now.day)}_${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}_${id.toString()}';
        final actorName = (_currentUser?['name'] ?? _currentUser?['email'] ?? _currentUser?['username'])?.toString();

        // Local audit log
        try {
          await widget.db.customStatement(
            'CREATE TABLE IF NOT EXISTS audit_logs (id TEXT PRIMARY KEY, action TEXT, target_id TEXT, target_type TEXT, actor_id TEXT, actor_name TEXT, company_id TEXT, created_at TEXT, metadata TEXT)',
          );
          await widget.db.customStatement(
            'INSERT OR REPLACE INTO audit_logs (id, action, target_id, target_type, actor_id, actor_name, company_id, created_at, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              logId,
              'User Deleted',
              id,
              'user',
              _currentUser?['id']?.toString(),
              actorName,
              targetCompanyId,
              nowIso,
              null
            ],
          );
        } catch (e) {
          debugPrint('Local audit log insert failed: $e');
        }

        await FirebaseFirestore.instance.collection('user_audit_logs').doc(logId).set(
          {
            'action': 'User Deleted',
            'target_user_id': id,
            'deleted_at': nowIso,
            'deleted_by_id': _currentUser?['id']?.toString(),
            'deleted_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
            'company_id': targetCompanyId,
            'companyId': targetCompanyId,
            'created_at': nowIso,
            'id': logId,
          },
        );
      }
    } catch (e) {
      debugPrint('Firestore archive failed for user $id: $e');
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User archived (soft deleted)')),
      );
    }
  }

  Future<void> _resetUserPassword(String userId, String username, String? email) async {
    final passwordCtl = TextEditingController();
    final confirmPasswordCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final target = _rows.where((r) => (r['id']?.toString() ?? '') == userId).toList();
    final targetPhone = target.isNotEmpty ? (target.first['contact_no'] ?? target.first['phone'] ?? target.first['mobile'])?.toString().trim() : null;
    Future<void> _deletePhoneDoc() async {
      if (targetPhone == null || targetPhone!.isEmpty) return;
      final emailKey = (email ?? username).toLowerCase();
      if (targetPhone == emailKey) return;
      try {
        await FirebaseFirestore.instance.collection('users').doc(targetPhone!).delete();
      } catch (_) {}
    }
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text('Reset Password', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset password for:',
                  style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Username: $username\nEmail: ${email ?? ''}',
                  style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Temporary Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != passwordCtl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will set a new temporary password. User will be required to change it on next login.',
                          style: AppFonts.poppins(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
    
    if (result != true) return;
    
    try {
      final target = _rows.where((r) => (r['id']?.toString() ?? '') == userId).toList();
      final targetCompanyId = target.isNotEmpty ? (target.first['company_id'] ?? target.first['companyId'])?.toString() : null;
      final companyIdForUpdate = (targetCompanyId != null && targetCompanyId.isNotEmpty) ? targetCompanyId : '1768415476147';
      final newPassword = passwordCtl.text.trim();
      final hashedPassword = PasswordHasher.hash(newPassword);
      final parts = hashedPassword.split(':');
      final iterations = int.parse(parts[0]);
      final salt = parts[1];
      
      // Update password and set is_first_login to true
      await widget.db.customStatement(
        'UPDATE users SET password_hash = ?, salt = ?, iterations = ?, is_first_login = ?, updated_at = ? WHERE id = ?',
        [
          hashedPassword,
          salt,
          iterations,
          1, // Set is_first_login to true (force password change)
          DateTime.now().toUtc().toIso8601String(),
          userId,
        ],
      );

      await AuthService().syncUserCacheFromDb(db: widget.db, userId: userId);
      try {
        if (Firebase.apps.isNotEmpty) {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          final emailKey = (email ?? username).trim().toLowerCase();
          final docId = emailKey.isNotEmpty ? emailKey : userId;
          await FirebaseFirestore.instance.collection('users').doc(docId).set({
            'password_hash': hashedPassword,
            'salt': salt,
            'iterations': iterations,
            'is_first_login': true,
            'isFirstLogin': true,
            'updated_at': nowIso,
            'updatedAt': nowIso,
            'company_id': companyIdForUpdate,
            'companyId': companyIdForUpdate,
          }, SetOptions(merge: true));
          await _deletePhoneDoc();
        }
      } catch (e) {
        if (mounted) {
          final msg = e.toString().toLowerCase().contains('permission-denied')
              ? 'Access Denied: Please check your admin privileges.'
              : 'Firestore password update failed: $e';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password reset successfully!', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('New password: $newPassword', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                const Text('User will be required to change password on next login.', style: TextStyle(fontSize: 11)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Username: $username\nPassword: $newPassword'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
    final isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);
    final rows = _q.isEmpty
        ? _rows
        : _rows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Users', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35),
                const Color(0xFF4A90E2),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (q) => setState(() => _q = q)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add New User'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.03),
              const Color(0xFF4A90E2).withOpacity(0.03),
            ],
          ),
        ),
        child: Stack(
          children: [
            rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: AppFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      final userId = r['id']?.toString() ?? '';
                      final username = r['username']?.toString() ?? '';
                      final email = r['email']?.toString() ?? username;
                      final displayUserId = r['user_id']?.toString();
                      final status = (r['status'] ?? 'active').toString();
                      final isInactive = status != 'active';
                      final name = r['name']?.toString() ?? r['username']?.toString() ?? 'N/A';
                      final normalizedUserId = (displayUserId ?? '').trim();
                      final nameWithUserId = normalizedUserId.isEmpty ? name : '$name ($normalizedUserId)';
                      final titleText = nameWithUserId;
                              final statusLabel = Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isInactive ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isInactive ? 'Inactive' : 'Active',
                                  style: AppFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isInactive ? Colors.red : Colors.green,
                                  ),
                                ),
                              );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),
                            child: Icon(Icons.person, color: const Color(0xFFFF6B35)),
                          ),
                          title: Text(
                            titleText,
                            style: AppFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: isInactive ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  statusLabel,
                                  if (normalizedUserId.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text('User ID: $normalizedUserId', style: AppFonts.poppins(fontSize: 12)),
                                  ],
                                ],
                              ),
                              if (r['email'] != null)
                                Text('Email: ${r['email']}', style: AppFonts.poppins(fontSize: 12)),
                              if (r['contact_no'] != null)
                                Text('Contact: ${r['contact_no']}', style: AppFonts.poppins(fontSize: 12)),
                              if (r['permissions'] != null)
                                Text(
                                  'Permissions: ${_getPermissionLabel(r['permissions'])}',
                                  style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                          trailing: (isSuperAdmin || isCompanyAdmin)
                              ? PopupMenuButton<String>(
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'reset',
                                      child: const Row(
                                        children: [
                                          Icon(Icons.lock_reset, size: 18, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Reset Password'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: isInactive ? 'activate' : 'deactivate',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isInactive ? Icons.toggle_on : Icons.toggle_off,
                                            size: 20,
                                            color: isInactive ? Colors.green : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isInactive ? 'Activate' : 'Deactivate'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    try {
                                      if (value == 'edit') {
                                        _showAddFormDialog(existing: r);
                                      } else if (value == 'reset') {
                                        await _resetUserPassword(userId, username, email);
                                      } else if (value == 'activate') {
                                        await _toggleUserStatus(userId, true);
                                      } else if (value == 'deactivate') {
                                        await _toggleUserStatus(userId, false);
                                      } else if (value == 'delete') {
                                        await _deleteUser(r['id'] as String);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Action failed: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
            if (_syncState.isLoading)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Companies Management Page - Super Admin Only
/// Allows Super Admin to create, edit, activate, and deactivate companies
