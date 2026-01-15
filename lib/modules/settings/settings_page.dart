import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_storage.dart' show AppStorage;
import '../../firestore_sync_service.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  const SettingsPage({super.key, required this.db});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _currentUser;
  String? _profileImagePath;
  StreamSubscription<QuerySnapshot>? _societiesSub;
  StreamSubscription<QuerySnapshot>? _blocksSub;
  List<Map<String, dynamic>> _societies = [];
  List<Map<String, dynamic>> _blocks = [];
  String? _selectedSocietyId;
  final TextEditingController _societyNameController = TextEditingController();
  final TextEditingController _blockNameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  bool _savingProfile = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCurrentUser();
      await _initFirestoreListeners();
    });
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (result == null) return;
      final path = result.path;
      final db = await AppDatabase.instance();
      final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().toLowerCase();
      final userId = (_currentUser?['id'] ?? _currentUser?['user_uid'] ?? _currentUser?['userId'] ?? _currentUser?['user_id'] ?? emailKey).toString();

      try {
        await db.customStatement(
          'UPDATE users SET profile_picture_path = ? WHERE id = ? OR email = ? OR username = ?',
          [path, userId, emailKey, emailKey],
        );
      } catch (e) {
        debugPrint('Failed to persist profile picture path: $e');
      }

      setState(() {
        _profileImagePath = path;
        _currentUser = {
          ...?_currentUser,
          'profile_picture_path': path,
        };
      });
      AuthService.currentUser = _currentUser;
      _syncProfileForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated locally'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Error picking profile photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _societiesSub?.cancel();
    _blocksSub?.cancel();
    _societyNameController.dispose();
    _blockNameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      Map<String, dynamic>? mergedUser = AuthService.currentUser;
      final authService = AuthService();
      if (authToken != null) {
        final user = await authService.getCurrentUser(authToken);
        mergedUser = user ?? mergedUser;
      }

      try {
        final db = await AppDatabase.instance();
        // Prefer email from mergedUser; fallback to cached settings if needed.
        final emailKey = (mergedUser?['email'] ?? mergedUser?['username'])?.toString().toLowerCase();
        if (emailKey != null && emailKey.isNotEmpty) {
          final dbResult = await db.customSelect(
            'SELECT id, username, email, name, contact_no, company_id, status, is_first_login, updated_at, created_at, profile_picture_path FROM users WHERE email = ? OR username = ?',
            variables: [
              d.Variable.withString(emailKey),
              d.Variable.withString(emailKey),
            ],
            readsFrom: {db.users},
          ).get();
          if (dbResult.isNotEmpty) {
            final row = dbResult.first.data;
            mergedUser = {
              ...?mergedUser,
              'id': row['id'],
              'user_uid': row['id'],
              'userId': row['id'],
              'email': row['email'] ?? mergedUser?['email'],
              'username': row['username'] ?? mergedUser?['username'],
              'name': row['name'] ?? mergedUser?['name'],
              'full_name': row['name'] ?? mergedUser?['full_name'],
              'fullName': row['name'] ?? mergedUser?['fullName'],
              'contact_no': row['contact_no'] ?? mergedUser?['contact_no'],
              'phone': row['contact_no'] ?? mergedUser?['phone'],
              'mobile': row['contact_no'] ?? mergedUser?['mobile'],
              'company_id': row['company_id'] ?? mergedUser?['company_id'],
              'companyId': row['company_id'] ?? mergedUser?['companyId'],
              'status': row['status'] ?? mergedUser?['status'],
              'is_first_login': row['is_first_login'] ?? mergedUser?['is_first_login'],
              'isFirstLogin': row['is_first_login'] ?? mergedUser?['isFirstLogin'],
              'updated_at': row['updated_at'] ?? mergedUser?['updated_at'],
              'updatedAt': row['updated_at'] ?? mergedUser?['updatedAt'],
              'created_at': row['created_at'] ?? mergedUser?['created_at'],
              'createdAt': row['created_at'] ?? mergedUser?['createdAt'],
              if (row['profile_picture_path'] != null) 'profile_picture_path': row['profile_picture_path'],
            };
          }
        }
      } catch (e) {
        debugPrint('Error refreshing user from DB: $e');
      }

      if (mounted) {
        setState(() {
          _currentUser = mergedUser;
          _loading = false;
        });
        _syncProfileForm();
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _syncProfileForm() {
    final companyName = _currentUser?['company_name']?.toString() ?? _currentUser?['companyName']?.toString() ?? '';
    final fullName = _currentUser?['name']?.toString() ?? _currentUser?['full_name']?.toString() ?? _currentUser?['fullName']?.toString() ?? '';
    final phone = _currentUser?['phone']?.toString() ?? _currentUser?['mobile']?.toString() ?? _currentUser?['contact_no']?.toString() ?? '';
    final email = _currentUser?['email']?.toString() ?? _currentUser?['gmail']?.toString() ?? '';
    _profileImagePath = _currentUser?['profile_picture_path']?.toString();

    _companyController.text = companyName == 'N/A' ? '' : companyName;
    _fullNameController.text = fullName == 'N/A' ? '' : fullName;
    _phoneController.text = phone == 'N/A' ? '' : phone;
    _emailController.text = email;
  }

  /// Initialize real-time Firestore listeners for societies and blocks
  Future<void> _initFirestoreListeners() async {
    if (Firebase.apps.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (_currentUser == null) {
      setState(() => _loading = false);
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      setState(() => _loading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Listen to societies collection
      Query societiesQuery = firestore.collection('societies');
      if (!isSuperAdmin) {
        societiesQuery = societiesQuery.where('companyId', isEqualTo: companyId);
      }
      societiesQuery = societiesQuery.orderBy('name');

      _societiesSub = societiesQuery.snapshots().listen((snapshot) async {
        try {
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final data = doc.data() as Map<String, dynamic>;
            final id = (data['id'] ?? doc.id).toString();

            if (change.type == DocumentChangeType.removed) {
              // Delete from SQLite
              await widget.db.customStatement(
                'DELETE FROM societies WHERE id = ?',
                [id],
              );
              // Also delete all blocks for this society
              await widget.db.customStatement(
                'DELETE FROM blocks WHERE society_id = ?',
                [id],
              );
            } else {
              // Insert or update in SQLite
              final name = (data['name'] ?? '').toString();
              final cid = (data['companyId'] ?? data['company_id'])?.toString();
              final metadata = (data['metadata'] ?? '').toString();
              final updatedAt = (data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();

              await widget.db.into(widget.db.societies).insertOnConflictUpdate(
                SocietiesCompanion(
                  id: d.Value(id),
                  name: d.Value(name),
                  companyId: d.Value(cid),
                  metadata: d.Value(metadata.isEmpty ? null : metadata),
                  updatedAt: d.Value(updatedAt),
                ),
              );
            }
          }

          // Update local list
          final allSocieties = await widget.db.customSelect(
            isSuperAdmin
                ? 'SELECT id, name FROM societies ORDER BY name'
                : 'SELECT id, name FROM societies WHERE company_id = ? ORDER BY name',
            variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],
            readsFrom: {widget.db.societies},
          ).get();

          // Update UI on main thread
          Future.microtask(() {
            if (!mounted) return;
            setState(() {
              _societies = allSocieties.map((r) => {
                'id': r.data['id'] as String,
                'name': (r.data['name']?.toString()) ?? '',
              }).toList();
              _loading = false;
            });
          });
        } catch (e) {
          debugPrint('Error processing societies changes: $e');
          Future.microtask(() {
            if (!mounted) return;
            setState(() => _loading = false);
          });
        }
      }, onError: (error) {
        debugPrint('Error in societies listener: $error');
        // Handle missing index errors gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _loading = false);
        });
      });

      // Listen to blocks collection
      Query blocksQuery = firestore.collection('blocks');
      if (!isSuperAdmin) {
        blocksQuery = blocksQuery.where('companyId', isEqualTo: companyId);
      }
      blocksQuery = blocksQuery.orderBy('name');

      _blocksSub = blocksQuery.snapshots().listen((snapshot) async {
        try {
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final data = doc.data() as Map<String, dynamic>;
            final id = (data['id'] ?? doc.id).toString();

            if (change.type == DocumentChangeType.removed) {
              // Delete from SQLite
              await widget.db.customStatement(
                'DELETE FROM blocks WHERE id = ?',
                [id],
              );
            } else {
              // Insert or update in SQLite
              final societyId = (data['societyId'] ?? data['society_id'] ?? '').toString();
              final name = (data['name'] ?? '').toString();
              final cid = (data['companyId'] ?? data['company_id'])?.toString();
              final metadata = (data['metadata'] ?? '').toString();
              final updatedAt = (data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();

              await widget.db.into(widget.db.blocks).insertOnConflictUpdate(
                BlocksCompanion(
                  id: d.Value(id),
                  societyId: d.Value(societyId),
                  name: d.Value(name),
                  companyId: d.Value(cid),
                  metadata: d.Value(metadata.isEmpty ? null : metadata),
                  updatedAt: d.Value(updatedAt),
                ),
              );
            }
          }

          // Update local blocks list on main thread
          Future.microtask(() async {
            if (!mounted) return;
            await _loadBlocksForSelectedSociety();
          });
        } catch (e) {
          debugPrint('Error processing blocks changes: $e');
        }
      }, onError: (error) {
        debugPrint('Error in blocks listener: $error');
        // Handle missing index errors gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
      });

      // Initial load from SQLite
      final allSocieties = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, name FROM societies ORDER BY name'
            : 'SELECT id, name FROM societies WHERE company_id = ? ORDER BY name',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],
        readsFrom: {widget.db.societies},
      ).get();

      if (mounted) {
        setState(() {
          _societies = allSocieties.map((r) => {
            'id': r.data['id'] as String,
            'name': (r.data['name']?.toString()) ?? '',
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize Firestore listeners: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user loaded'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (_profileFormKey.currentState?.validate() != true) return;

    final canEditCompany = RoleUtils.isSuperAdmin(_currentUser);
    final canEditNamePhone = canEditCompany || RoleUtils.isCompanyAdmin(_currentUser) || RoleUtils.isAgent(_currentUser);
    if (!canEditCompany && !canEditNamePhone) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to edit profile'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final name = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final companyName = _companyController.text.trim();
    final profilePicPath = (_profileImagePath ?? '').isNotEmpty ? File(_profileImagePath!).path : null;
    final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().toLowerCase();
    final userIdRaw = (_currentUser?['id'] ?? _currentUser?['user_uid'] ?? _currentUser?['userId'] ?? _currentUser?['user_id']);
    final userId = (userIdRaw == null || userIdRaw.toString().isEmpty) ? emailKey : userIdRaw.toString();
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    setState(() => _savingProfile = true);

    try {
      final db = await AppDatabase.instance();

      // Local-first explicit update with safe fallbacks
      bool primaryUpdated = false;
      try {
        await db.customStatement(
          'UPDATE users SET name = ?, full_name = ?, fullName = ?, contact_no = ?, phone = ?, company_name = ?, profile_picture_path = ?, updated_at = ?, is_first_login = 0 WHERE id = ? OR email = ? OR username = ?',
          [name, name, name, phone, phone, companyName, profilePicPath, nowIso, userId, emailKey, emailKey],
        );
        primaryUpdated = true;
      } catch (e) {
        debugPrint('Primary UPDATE failed (may be missing columns): $e');
      }

      final existing = await db.customSelect(
        'SELECT id FROM users WHERE id = ? OR email = ? OR username = ?',
        variables: [
          d.Variable.withString(userId),
          d.Variable.withString(emailKey),
          d.Variable.withString(emailKey),
        ],
        readsFrom: {db.users},
      ).get();

      final permissions = _currentUser?['permissions'];
      final permissionsJson = permissions == null ? null : (permissions is String ? permissions : jsonEncode(permissions));

      if (existing.isNotEmpty) {
        if (!primaryUpdated) {
          await db.customStatement(
            'UPDATE users SET name = ?, contact_no = ?, updated_at = ?, is_first_login = 0 WHERE id = ? OR email = ? OR username = ?',
            [name, phone, nowIso, userId, emailKey, emailKey],
          );
          // Best-effort additional columns if present
          try {
            await db.customStatement(
              'UPDATE users SET full_name = COALESCE(full_name, ?), fullName = COALESCE(fullName, ?), phone = COALESCE(phone, ?), company_name = COALESCE(company_name, ?), profile_picture_path = COALESCE(profile_picture_path, ?) WHERE id = ? OR email = ? OR username = ?',
              [name, name, phone, companyName, profilePicPath, userId, emailKey, emailKey],
            );
          } catch (e) {
            debugPrint('Optional user columns not updated: $e');
          }
        }
      } else {
        await db.customStatement(
          'INSERT OR REPLACE INTO users (id, username, email, name, contact_no, permissions, company_id, status, is_first_login, is_active, created_at, updated_at, profile_picture_path, full_name, fullName, phone, company_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            userId,
            emailKey,
            emailKey,
            name,
            phone,
            permissionsJson,
            companyId,
            _currentUser?['status'] ?? 'active',
            0,
            1,
            _currentUser?['created_at'] ?? nowIso,
            nowIso,
            profilePicPath,
            name,
            name,
            phone,
            companyName,
          ],
        );
      }

      if (canEditCompany && companyId != null && companyName.isNotEmpty) {
        await db.customStatement(
          'UPDATE companies SET name = ?, updated_at = ? WHERE id = ?',
          [companyName, nowIso, companyId],
        );
      }

      // Immediately refresh local state/UI
      if (mounted) {
        setState(() {
          _currentUser = {
            ...?_currentUser,
            'name': name,
            'full_name': name,
            'fullName': name,
            'contact_no': phone,
            'phone': phone,
            'mobile': phone,
            if (canEditCompany) 'company_name': companyName,
            if (canEditCompany) 'companyName': companyName,
            'is_first_login': 0,
            'isFirstLogin': 0,
            'updated_at': nowIso,
            'updatedAt': nowIso,
            'profile_picture_path': profilePicPath,
          };
        });
        AuthService.currentUser = _currentUser;
        _syncProfileForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      }

      // Refresh cached user (local storage) best-effort
      try {
        final storage = AppStorage();
        final s = await storage.readSettings();
        final authToken = s['authToken'] as String?;
        if (authToken != null) {
          final refreshed = await AuthService().getCurrentUser(authToken);
          AuthService.currentUser = refreshed ?? AuthService.currentUser;
        }
        await AuthService().syncUserCacheFromDb(db: db, userId: userId);
      } catch (_) {}

      // Firestore sync is best-effort and silent on permission issues
      try {
        if (Firebase.apps.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(userId).set(
            {
              'name': name,
              'full_name': name,
              'fullName': name,
              'contact_no': phone,
              'contactNo': phone,
              'phone': phone,
              'is_first_login': 0,
              'isFirstLogin': 0,
              'updated_at': nowIso,
              'updatedAt': nowIso,
              if (profilePicPath != null && profilePicPath.isNotEmpty) 'profile_picture_path': profilePicPath,
              if (canEditCompany && companyId != null && companyName.isNotEmpty) 'company_name': companyName,
              if (canEditCompany && companyId != null && companyName.isNotEmpty) 'companyName': companyName,
              if (companyId != null) 'company_id': companyId,
              if (companyId != null) 'companyId': companyId,
            },
            SetOptions(merge: true),
          );

          if (canEditCompany && companyId != null && companyName.isNotEmpty) {
            await firestore.collection('companies').doc(companyId).set(
              {
                'name': companyName,
                'updated_at': nowIso,
                'updatedAt': nowIso,
              },
              SetOptions(merge: true),
            );
          }
        }
      } catch (e) {
        debugPrint('Firestore profile sync skipped (non-fatal): $e');
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  String _convertToCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final headers = <String>{};
    for (final r in rows) {
      headers.addAll(r.keys.map((k) => k.toString()));
    }
    final headerList = headers.toList();
    final data = <List<dynamic>>[];
    data.add(headerList);
    for (final r in rows) {
      data.add(headerList.map((h) => r[h]).toList());
    }
    return const ListToCsvConverter().convert(data);
  }

  Future<void> _exportDataToCsv() async {
    try {
      final db = await AppDatabase.instance();
      final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      if (!isSuper && (companyId == null || companyId.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company not set. Cannot export data.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final users = await db.customSelect(
        isSuper ? 'SELECT * FROM users' : 'SELECT * FROM users WHERE company_id = ? OR companyId = ?',
        variables: isSuper ? [] : [d.Variable.withString(companyId!), d.Variable.withString(companyId)],
      ).get();

      final trades = await db.customSelect(
        isSuper
            ? 'SELECT * FROM trading_entries'
            : 'SELECT * FROM trading_entries WHERE company_id = ?',
        variables: isSuper ? [] : [d.Variable.withString(companyId!)],
      ).get();

      final tradeFiles = await db.customSelect(
        isSuper
            ? 'SELECT * FROM trading_file_entries'
            : 'SELECT * FROM trading_file_entries WHERE company_id = ?',
        variables: isSuper ? [] : [d.Variable.withString(companyId!)],
      ).get();

      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final dir = await AppStorage().appDir();

      final usersCsv = _convertToCsv(users.map((r) => r.data).toList());
      final tradesCsv = _convertToCsv([
        ...trades.map((r) => r.data)..forEach((r) => r['entry_type'] = 'form'),
        ...tradeFiles.map((r) => r.data)..forEach((r) => r['entry_type'] = 'file'),
      ]);

      final usersFile = File('${dir.path}/users_export_$ts.csv');
      final tradingFile = File('${dir.path}/trading_export_$ts.csv');
      await usersFile.writeAsString(usersCsv);
      await tradingFile.writeAsString(tradesCsv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved:\n${usersFile.path}\n${tradingFile.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadBlocksForSelectedSociety() async {
    if (_selectedSocietyId == null) {
      if (!mounted) return;
      setState(() => _blocks = []);
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    final blocks = await widget.db.customSelect(
      isSuperAdmin
          ? 'SELECT id, society_id, name FROM blocks WHERE society_id = ? ORDER BY name'
          : 'SELECT id, society_id, name FROM blocks WHERE society_id = ? AND company_id = ? ORDER BY name',
      variables: isSuperAdmin
          ? [d.Variable.withString(_selectedSocietyId!)]
          : [d.Variable.withString(_selectedSocietyId!), d.Variable.withString(companyId!)],
      readsFrom: {widget.db.blocks},
    ).get();

    if (!mounted) return;
    setState(() {
      _blocks = blocks.map((r) => {
        'id': r.data['id'] as String,
        'society_id': (r.data['society_id']?.toString()) ?? '',
        'name': (r.data['name']?.toString()) ?? '',
      }).toList();
    });
  }

  Future<void> _addSociety() async {
    final name = _societyNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a society name'), backgroundColor: Colors.red),
      );
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    try {
      // Generate ID
      final id = 'soc_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Save to SQLite first
      await widget.db.into(widget.db.societies).insertOnConflictUpdate(
        SocietiesCompanion(
          id: d.Value(id),
          name: d.Value(name),
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          metadata: const d.Value(null),
          updatedAt: d.Value(nowIso),
        ),
      );

      // Sync to Firestore
      if (Firebase.apps.isNotEmpty) {
        await FirestoreSyncService().syncDocument(
          collection: 'societies',
          documentId: id,
          data: {
            'id': id,
            'name': name,
            'companyId': isSuperAdmin ? null : companyId,
            'metadata': null,
            'updatedAt': nowIso,
          },
          merge: true,
        );
      }

      _societyNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error adding society: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding society: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addBlock() async {
    if (_selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a society first'), backgroundColor: Colors.red),
      );
      return;
    }

    final name = _blockNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a block name'), backgroundColor: Colors.red),
      );
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    try {
      // Generate ID
      final id = 'blk_${_selectedSocietyId}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Save to SQLite first
      await widget.db.into(widget.db.blocks).insertOnConflictUpdate(
        BlocksCompanion(
          id: d.Value(id),
          societyId: d.Value(_selectedSocietyId!),
          name: d.Value(name),
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          metadata: const d.Value(null),
          updatedAt: d.Value(nowIso),
        ),
      );

      // Sync to Firestore
      if (Firebase.apps.isNotEmpty) {
        await FirestoreSyncService().syncDocument(
          collection: 'blocks',
          documentId: id,
          data: {
            'id': id,
            'societyId': _selectedSocietyId!,
            'name': name,
            'companyId': isSuperAdmin ? null : companyId,
            'metadata': null,
            'updatedAt': nowIso,
          },
          merge: true,
        );
      }

      _blockNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error adding block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSociety(String societyId) async {
    // Check if society has active files or properties
    final filesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM files_table WHERE society_id = ?',
      variables: [d.Variable.withString(societyId)],
      readsFrom: {widget.db.filesTable},
    ).getSingle();

    final propertiesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM properties WHERE society_id = ?',
      variables: [d.Variable.withString(societyId)],
      readsFrom: {widget.db.properties},
    ).getSingle();

    final files = filesCount.read<int>('count') ?? 0;
    final properties = propertiesCount.read<int>('count') ?? 0;

    if (files > 0 || properties > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning: Active Records Found'),
          content: Text(
            'This society has $files file(s) and $properties property(ies) linked to it.\n\n'
            'Deleting this society will also delete all its blocks. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Society'),
          content: const Text('Are you sure you want to delete this society? All its blocks will also be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      // Delete from Firestore first (before SQLite to preserve block IDs)
      if (Firebase.apps.isNotEmpty) {
        // Delete all blocks for this society first from Firestore
        final blocksSnapshot = await FirebaseFirestore.instance
            .collection('blocks')
            .where('societyId', isEqualTo: societyId)
            .get();

        for (final blockDoc in blocksSnapshot.docs) {
          await FirestoreSyncService().deleteDocument(
            collection: 'blocks',
            documentId: blockDoc.id,
          );
        }

        await FirestoreSyncService().deleteDocument(
          collection: 'societies',
          documentId: societyId,
        );
      }

      // Delete from SQLite (blocks will be deleted by the Firestore listener)
      await widget.db.customStatement('DELETE FROM blocks WHERE society_id = ?', [societyId]);
      await widget.db.customStatement('DELETE FROM societies WHERE id = ?', [societyId]);

      // Clear selection if deleted society was selected
      if (_selectedSocietyId == societyId) {
        setState(() {
          _selectedSocietyId = null;
          _blocks = [];
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error deleting society: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting society: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    // Check if block has active files or properties
    final filesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM files_table WHERE block_id = ?',
      variables: [d.Variable.withString(blockId)],
      readsFrom: {widget.db.filesTable},
    ).getSingle();

    final propertiesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM properties WHERE block_id = ?',
      variables: [d.Variable.withString(blockId)],
      readsFrom: {widget.db.properties},
    ).getSingle();

    final files = filesCount.read<int>('count') ?? 0;
    final properties = propertiesCount.read<int>('count') ?? 0;

    if (files > 0 || properties > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning: Active Records Found'),
          content: Text(
            'This block has $files file(s) and $properties property(ies) linked to it.\n\n'
            'Are you sure you want to delete this block?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Block'),
          content: const Text('Are you sure you want to delete this block?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      // Delete from SQLite
      await widget.db.customStatement('DELETE FROM blocks WHERE id = ?', [blockId]);

      // Delete from Firestore
      if (Firebase.apps.isNotEmpty) {
        await FirestoreSyncService().deleteDocument(
          collection: 'blocks',
          documentId: blockId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error deleting block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildProfileField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final companyName = _currentUser?['company_name']?.toString() ?? 
                       _currentUser?['companyName']?.toString() ?? 
                       'N/A';
    final fullName = _currentUser?['name']?.toString() ?? 
                    _currentUser?['full_name']?.toString() ?? 
                    _currentUser?['fullName']?.toString() ?? 
                    'N/A';
    final phone = _currentUser?['phone']?.toString() ?? 
                 _currentUser?['mobile']?.toString() ?? 
                 'N/A';
    final email = _currentUser?['email']?.toString() ?? 
                 _currentUser?['gmail']?.toString() ?? 
                 'N/A';
    final isAgentRole = RoleUtils.isAgent(_currentUser) ||
        (RoleUtils.getUserRole(_currentUser)?.toLowerCase() == 'agent') ||
        ((_currentUser?['role'] ?? '').toString().toLowerCase() == 'user');
    final canEditCompany = RoleUtils.isSuperAdmin(_currentUser);
    final canEditNamePhone = canEditCompany || RoleUtils.isCompanyAdmin(_currentUser) || isAgentRole;

    Widget profileCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.1),
            const Color(0xFF4A90E2).withOpacity(0.1),
          ],
        ),
      ),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _profileFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFFF6B35),
                          backgroundImage: (_profileImagePath != null && _profileImagePath!.isNotEmpty && File(_profileImagePath!).existsSync())
                              ? FileImage(File(_profileImagePath!))
                              : null,
                          child: (_profileImagePath == null || _profileImagePath!.isEmpty || !File(_profileImagePath!).existsSync())
                              ? Text(
                                  fullName.isNotEmpty && fullName != 'N/A'
                                      ? fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: IconButton(
                              iconSize: 20,
                              padding: const EdgeInsets.all(6),
                              onPressed: _pickProfilePhoto,
                              icon: const Icon(Icons.camera_alt, color: Color(0xFFFF6B35)),
                              tooltip: 'Upload profile picture',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Profile',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Update your profile details. Email stays read-only.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyController,
                            enabled: canEditCompany,
                            decoration: InputDecoration(
                              labelText: 'Company Name',
                              hintText: 'Enter company name',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _fullNameController,
                            enabled: canEditNamePhone,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!canEditNamePhone) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Full name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            enabled: canEditNamePhone,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              hintText: 'Enter your phone number',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (!canEditNamePhone) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone is required';
                              }
                              if (value.trim().length < 6) {
                                return 'Phone looks too short';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Email (read-only)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _savingProfile ? null : _saveProfile,
                              icon: _savingProfile
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_savingProfile ? 'Saving...' : 'Update Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isAgentRole) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: const Color(0xFFFF6B35),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              profileCard,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _exportDataToCsv,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Export Data to CSV'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'System settings are restricted for your role. Update your name and phone here to keep your profile complete.',
                  style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final panelsHeight = MediaQuery.of(context).size.height * 0.6;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFFF6B35),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Section
            profileCard,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _exportDataToCsv,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Export Data to CSV'),
                ),
              ),
            ),
            // System Config Section (Societies & Blocks)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Societies
                  Flexible(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Societies',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _societyNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Society Name',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) => _addSociety(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _addSociety,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF6B35),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          SizedBox(
                            height: panelsHeight * 0.6,
                            child: _societies.isEmpty
                                ? const Center(child: Text('No societies found. Add one to get started.'))
                                : ListView.builder(
                                    itemCount: _societies.length,
                                    shrinkWrap: true,
                                    itemBuilder: (context, index) {
                                      final society = _societies[index];
                                      final isSelected = _selectedSocietyId == society['id'];
                                      return ListTile(
                                        title: Text(society['name'] ?? ''),
                                        selected: isSelected,
                                        selectedTileColor: const Color(0xFFFF6B35).withOpacity(0.1),
                                        onTap: () {
                                          setState(() {
                                            _selectedSocietyId = society['id'];
                                          });
                                          _loadBlocksForSelectedSociety();
                                        },
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteSociety(society['id']),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right side - Blocks
                  Flexible(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Blocks',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                if (_selectedSocietyId == null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Text(
                                      'Please select a society to manage its blocks',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _blockNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Block Name',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              onSubmitted: (_) => _addBlock(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: _addBlock,
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFF6B35),
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const Divider(),
                          SizedBox(
                            height: panelsHeight * 0.6,
                            child: _selectedSocietyId == null
                                ? const Center(child: Text('Select a society to view its blocks'))
                                : _blocks.isEmpty
                                    ? const Center(child: Text('No blocks found for this society. Add one to get started.'))
                                    : ListView.builder(
                                        itemCount: _blocks.length,
                                        shrinkWrap: true,
                                        itemBuilder: (context, index) {
                                          final block = _blocks[index];
                                          return ListTile(
                                            title: Text(block['name'] ?? ''),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteBlock(block['id']),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

