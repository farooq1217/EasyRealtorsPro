import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// REMOVED: Firestore dependencies for SQLite-only operation
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// Add back minimal Firebase imports for helper methods to work
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../core/services/auth_service.dart';
import '../../firestore_sync_service.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart';
import '../../core/professional_pdf_generator.dart';
// REMOVED: Firestore-related utilities for SQLite-only operation
// import '../../core/app_utils.dart' show fmtTs, buildSecureFirestoreQuery, creatorFields;
import '../../core/app_utils.dart' show fmtTs, creatorFields, buildSecureFirestoreQuery;
import '../../core/phone_actions.dart';
import '../../core/shared_utils.dart';
// REMOVED: Firestore services for SQLite-only operation
import '../../core/services/firestore_cache_service.dart';
import '../../image_cache_service.dart';
import '../../responsive_widgets.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../core/shared_utils.dart' show TopRightSearch;

class TradingFilePage extends StatefulWidget {
  final AppDatabase db;
  const TradingFilePage({super.key, required this.db});
  @override
  State<TradingFilePage> createState() => _TradingFilePageState();
}

enum _TradingFileFormType { buy, sell }

class _TradingFileEntry {
  final String id;
  final _TradingFileFormType type;
  final String? buyOption;
  final String? sellOption;
  final DateTime date;
  final String mobile;
  final String personName;
  final String estate;
  final int quantity;
  final double payment;
  final String status; // 'Pending', 'Close', or 'Done'
  final String comments;
  final bool isActive;
  const _TradingFileEntry({
    required this.id,
    required this.type,
    required this.buyOption,
    required this.sellOption,
    required this.date,
    required this.mobile,
    required this.personName,
    required this.estate,
    required this.quantity,
    required this.payment,
    required this.status,
    required this.comments,
    required this.isActive,
  });
  
  bool get isDone => status == 'Done';
  bool get isClose => status == 'Close' || status == 'Done';
  bool get isPending => status == 'Pending';
}

class _TradingFilePageState extends State<TradingFilePage> {
  static const List<String> _tradeOptions = ['HP', 'KP', 'MP', 'NMP', 'NNMP', 'BOP', 'SOP', 'AEMP'];

  final _buyFormKey = GlobalKey<FormState>();
  final _sellFormKey = GlobalKey<FormState>();

  String? _buySelection;
  String? _sellSelection;
  String _q = '';

  final TextEditingController _buyDateCtl = TextEditingController();
  final TextEditingController _buyMobileCtl = TextEditingController();
  final TextEditingController _buyPersonNameCtl = TextEditingController();
  final TextEditingController _buyEstateCtl = TextEditingController();
  final TextEditingController _buyQuantityCtl = TextEditingController();
  final TextEditingController _buyPaymentCtl = TextEditingController();
  final TextEditingController _buyCommentsCtl = TextEditingController();

  final TextEditingController _sellDateCtl = TextEditingController();
  final TextEditingController _sellMobileCtl = TextEditingController();
  final TextEditingController _sellPersonNameCtl = TextEditingController();
  final TextEditingController _sellEstateCtl = TextEditingController();
  final TextEditingController _sellQuantityCtl = TextEditingController();
  final TextEditingController _sellPaymentCtl = TextEditingController();
  final TextEditingController _sellCommentsCtl = TextEditingController();

  final List<_TradingFileEntry> _entries = [];
  DateTime? _buySelectedDate;
  DateTime? _sellSelectedDate;
  bool _buyDateLocked = false; // Tracks if date is auto-filled and locked
  bool _sellDateLocked = false; // Tracks if date is auto-filled and locked
  bool _loading = false;
  // Firestore-related state variables for SQLite-only operation
  bool _firestoreReady = false;
  _TradingFileFormType? _selectedFormType;
  List<String> _buyImages = [];
  List<String> _sellImages = [];
  String _dateRangeFilter = 'Today'; // Default filter
  String _transactionTypeFilter = 'All'; // Default: All, Buy, Sell
  Map<String, dynamic>? _currentUser; // Current logged-in user for permission checks
  // Firestore subscription and sync state for SQLite-only operation
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
  
  /// Get current user from AuthService
  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final authService = AuthService();
        final user = await authService.getCurrentUser(authToken);
        if (mounted) {
          setState(() {
            _currentUser = user;
            AuthService.currentUser = user;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCurrentUser();
      // REMOVED: Firebase Auth for SQLite-only operation
      // await _ensureFirebaseAuth();
      await _initializeTable();
      await _backfillTradingCompanyIds();
      // REMOVED: Firestore sync for SQLite-only operation
      // await _maybeForceSyncLocalTrading();
      // await _startFirestoreListener();
      await _loadEntries();
    });
  }

  Future<void> _ensureFirebaseAuth() async {
    if (Firebase.apps.isEmpty) return;
    if (!kIsWeb && io.Platform.isWindows) return;
    // REMOVED: Firebase Auth for SQLite-only operation
    // await AuthService.ensureFirebasePersistence();
    // final auth = FirebaseAuth.instance;
    // if (auth.currentUser == null) {
    //   try {
    //     await auth.signInAnonymously();
    //   } catch (e) {
    //     debugPrint('FirebaseAuth sign-in failed: $e');
    //   }
    // }
    // debugPrint('FirebaseAuth UID: ${auth.currentUser?.uid ?? 'none'}');
    await AuthService.ensureFirebasePersistence();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        debugPrint('FirebaseAuth sign-in failed: $e');
      }
    }
    debugPrint('FirebaseAuth UID: ${auth.currentUser?.uid ?? 'none'}');
  }

  Future<void> _maybeForceSyncLocalTrading() async {
    if (_currentUser == null) return;
    await _ensureFirebaseAuth();
    await _forceSyncLocalTradingToFirestoreFile();
  }

  Future<void> _forceSyncLocalTradingToFirestoreFile() async {
    if (Firebase.apps.isEmpty) return;
    await _ensureFirebaseAuth();
    final uid = FirebaseAuth.instance.currentUser?.uid ??
        AuthService.currentUser?['uid'] ??
        AuthService.currentUser?['user_uid'] ??
        AuthService.currentUser?['userId'] ??
        AuthService.currentUser?['user_id'] ??
        _currentUser?['uid'] ??
        _currentUser?['id'];
    if (uid == null || uid.toString().isEmpty) {
      debugPrint('Force sync trading skipped: no Firebase UID');
      return;
    }
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (companyId == null || companyId.toString().isEmpty) {
      debugPrint('Force sync trading skipped: missing companyId');
      return;
    }
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final fileRows = await widget.db.customSelect(
        isSuperAdmin ? 'SELECT * FROM trading_file_entries' : 'SELECT * FROM trading_file_entries WHERE company_id = ?',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      final formRows = await widget.db.customSelect(
        isSuperAdmin ? 'SELECT * FROM trading_entries' : 'SELECT * FROM trading_entries WHERE company_id = ?',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      final firestore = FirebaseFirestore.instance;
      for (final r in fileRows) {
        final data = r.data;
        final id = data['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        debugPrint('Attempting write to: trading_file_entries/$id');
        await firestore.collection('trading_file_entries').doc(id).set(
          {
            ...data,
            'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
      for (final r in formRows) {
        final data = r.data;
        final id = data['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        debugPrint('Attempting write to: trading_entries/$id');
        await firestore.collection('trading_entries').doc(id).set(
          {
            ...data,
            'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Force sync trading failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Force sync trading failed: $e')),
        );
      }
    }
  }

  Future<void> _backfillTradingCompanyIds() async {
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (companyId == null || companyId.isEmpty) return;
    try {
      await widget.db.customStatement(
        "UPDATE trading_file_entries SET company_id = ? WHERE company_id IS NULL OR company_id = ''",
        [companyId],
      );
      await widget.db.customStatement(
        "UPDATE trading_entries SET company_id = ? WHERE company_id IS NULL OR company_id = ''",
        [companyId],
      );
      debugPrint('Backfilled company_id on trading tables for company: $companyId');
    } catch (e) {
      debugPrint('Backfill trading company_id failed: $e');
    }
  }


  @override
  void dispose() {
    // REMOVED: Firestore subscription cancellation for SQLite-only operation
    // _firestoreSub?.cancel();
    _buyDateCtl.dispose();
    _buyMobileCtl.dispose();
    _buyPersonNameCtl.dispose();
    _buyEstateCtl.dispose();
    _buyQuantityCtl.dispose();
    _buyPaymentCtl.dispose();
    _buyCommentsCtl.dispose();

    _sellDateCtl.dispose();
    _sellMobileCtl.dispose();
    _sellPersonNameCtl.dispose();
    _sellEstateCtl.dispose();
    _sellQuantityCtl.dispose();
    _sellPaymentCtl.dispose();
    _sellCommentsCtl.dispose();
    super.dispose();
  }

  Future<void> _generateReceiptPdf(_TradingClientEntry entry) async {
    try {
      final bytes = await _buildTradingReceiptBytes(entry: entry, user: _currentUser);
      await savePdfBytesToDisk(
        pdfBytes: bytes,
        suggestedBaseName: 'receipt_${entry.id}_${fmtTs(DateTime.now())}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt generated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate receipt: $e')),
        );
      }
    }
  }

  /// Start Firestore listener with pagination for real-time sync
  Future<void> _startFirestoreListener() async {
    if (!FirestoreSyncService().isAvailable) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      });
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      });
      return;
    }

    try {
      // Use secure query builder for role-based isolation with agent filtering
      Query query = buildSecureFirestoreQuery(
        collection: 'trading_file_entries',
        currentUser: _currentUser,
        orderBy: 'date',
        descending: true,
        limit: 50, // Paginated
        additionalAgentFilter: null,
      );

      _firestoreSub = query.snapshots().listen((snapshot) async {
        Future.microtask(() async {
          try {
          final changes = List<DocumentChange>.from(snapshot.docChanges);
          
          if (changes.isNotEmpty) {
            try {
              await widget.db.batch((batch) {
                for (final change in changes) {
                  try {
                    final doc = change.doc;
                    final data = doc.data() as Map<String, dynamic>;
                    final id = (data['id'] ?? doc.id).toString();
                    
                    if (change.type == DocumentChangeType.removed) {
                      batch.customStatement(
                        "UPDATE trading_file_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                        [DateTime.now().toUtc().toIso8601String(), id],
                      );
                      continue;
                    }

                    // Sync trading file entry data to SQLite
                    final type = (data['type'] ?? '').toString();
                    final buyOption = (data['buy_option'] ?? data['buyOption'] ?? '').toString();
                    final sellOption = (data['sell_option'] ?? data['sellOption'] ?? '').toString();
                    final date = (data['date'] ?? '').toString();
                    final mobile = (data['mobile'] ?? '').toString();
                    final personName = (data['person_name'] ?? data['personName'] ?? '').toString();
                    final estate = (data['estate'] ?? '').toString();
                    final quantity = (data['quantity'] ?? '').toString();
                    final payment = (data['payment'] is num) ? (data['payment'] as num).toDouble() : double.tryParse(data['payment']?.toString() ?? '') ?? 0.0;
                    final status = (data['status'] ?? 'Pending').toString();
                    final comments = (data['comments'] ?? '').toString();
                    final createdBy = (data['created_by'] ?? data['createdBy'])?.toString();
                    final cid = (data['company_id'] ?? data['companyId'])?.toString();
                    final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();

                    batch.customStatement(
                      'INSERT OR REPLACE INTO trading_file_entries (id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, estate, quantity, payment, status, is_active, comments, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, 1), ?, ?)',
                      [id, cid, createdBy, type, buyOption, sellOption, date, mobile, personName, estate, quantity, payment, status, data['is_active'] ?? data['isActive'], comments, updatedAt],
                    );
                  } catch (e) {
                    debugPrint('Skipping trading_file_entries change due to error: $e');
                  }
                }
              });
              
              // Update UI on main thread
              Future.microtask(() async {
                if (!mounted) return;
                _syncState.startLoading();
                _syncState.finishLoading(synced: true);
                await _loadEntries(); // Reload to show updated data
                if (!mounted) return;
                setState(() => _firestoreReady = true);
              });
            } catch (e) {
              debugPrint('Error syncing Firestore changes to SQLite (trading_file_entries): $e');
              Future.microtask(() {
                if (!mounted) return;
                _syncState.finishLoading(synced: false, errorMessage: e.toString());
                setState(() => _firestoreReady = true);
              });
            }
          } else {
            Future.microtask(() {
              if (!mounted) return;
              setState(() => _firestoreReady = true);
            });
          }
          } catch (e) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              debugPrint('Firestore permission denied for trading_file_entries sync (ignored)');
            } else {
              debugPrint('Firestore snapshot handling error (trading_file_entries): $e');
            }
            Future.microtask(() {
              if (!mounted) return;
              _syncState.finishLoading(synced: false, errorMessage: null);
              setState(() => _firestoreReady = true);
            });
          }
        });
      }, onError: (error) {
        final isPerm = error is FirebaseException && error.code == 'permission-denied';
        if (isPerm) {
          debugPrint('Firestore permission denied for trading_file_entries listener (ignored)');
        } else {
          debugPrint('Firestore listener error (trading_file_entries): $error');
        }
        Future.microtask(() {
          if (!mounted) return;
          _syncState.finishLoading(synced: false, errorMessage: null);
          setState(() => _firestoreReady = true);
        });
      });
    } catch (e) {
      debugPrint('Error starting Firestore listener (trading_file_entries): $e');
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      });
    }
  }

  Future<void> _initializeTable() async {
    try {
      // Create table if it does not exist yet (new installs)
      await widget.db.customStatement('''
        CREATE TABLE IF NOT EXISTS trading_file_entries (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          created_by TEXT,
          type TEXT NOT NULL,
          buy_option TEXT,
          sell_option TEXT,
          date TEXT NOT NULL,
          mobile TEXT,
          person_name TEXT,
          estate TEXT,
          quantity INTEGER,
          payment REAL,
          status TEXT NOT NULL DEFAULT 'Pending',
          is_active INTEGER NOT NULL DEFAULT 1,
          comments TEXT,
          updated_at TEXT NOT NULL
        )
      ''');

      // Ensure company_id column exists for existing databases
      try {
        final columns = await widget.db
            .customSelect('PRAGMA table_info(trading_file_entries)')
            .get();
        final hasCompanyId = columns.any(
          (row) => (row.data['name'] as String?) == 'company_id',
        );
        if (!hasCompanyId) {
          await widget.db.customStatement(
            'ALTER TABLE trading_file_entries ADD COLUMN company_id TEXT',
          );
        }

        final hasCreatedBy = columns.any(
          (row) => (row.data['name'] as String?) == 'created_by',
        );
        if (!hasCreatedBy) {
          await widget.db.customStatement(
            'ALTER TABLE trading_file_entries ADD COLUMN created_by TEXT',
          );
        }
      } catch (_) {
        // Ignore
      }

      // Ensure person_name column exists for existing databases
      try {
        final columns = await widget.db
            .customSelect('PRAGMA table_info(trading_file_entries)')
            .get();
        final hasPersonName = columns.any(
          (row) => (row.data['name'] as String?) == 'person_name',
        );
        if (!hasPersonName) {
          await widget.db.customStatement(
            'ALTER TABLE trading_file_entries ADD COLUMN person_name TEXT',
          );
        }
      } catch (_) {
        // Ignore
      }

      // For existing databases created before "status" was added, ensure the column exists.
      try {
        final columns = await widget.db
            .customSelect('PRAGMA table_info(trading_file_entries)')
            .get();
        final hasStatus = columns.any(
          (row) => (row.data['name'] as String?) == 'status',
        );
        if (!hasStatus) {
          // Older DB â€“ add the status column with default 'Pending'
          await widget.db.customStatement(
            "ALTER TABLE trading_file_entries ADD COLUMN status TEXT NOT NULL DEFAULT 'Pending'",
          );
        }
        final hasIsActive = columns.any(
          (row) => (row.data['name'] as String?) == 'is_active',
        );
        if (!hasIsActive) {
          await widget.db.customStatement(
            'ALTER TABLE trading_file_entries ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
        }
      } catch (_) {
        // If PRAGMA or ALTER fails, ignore â€“ worst case status updates will still fail
        // but the rest of the screen will continue to work.
      }

      // Optional one-time migration from legacy is_close column (if it exists)
      try {
        await widget.db.customStatement('''
          UPDATE trading_file_entries 
          SET status = CASE 
            WHEN is_close = 1 THEN 'Done' 
            ELSE 'Pending' 
          END 
          WHERE (status IS NULL OR status = '')
        ''');
      } catch (_) {
        // Old column might not exist, safe to ignore.
      }

      // Add index to speed up status/is_active filtered queries
      try {
        await widget.db.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_file_entries_active ON trading_file_entries(status, is_active, updated_at)',
        );
      } catch (_) {}
      try {
        await widget.db.customStatement(
          'UPDATE trading_file_entries SET is_active = 1 WHERE is_active IS NULL',
        );
      } catch (_) {}
    } catch (e) {
      // Table might already exist, ignore
    }
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isAgent = RoleUtils.isAgent(_currentUser);
      final myUserId = _currentUser?['id']?.toString();
      final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;


      if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
        setState(() {
          _entries.clear();
          _loading = false;
        });
        return;
      }

      final activeFilter = " (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1) ";
      final results = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_file_entries WHERE $activeFilter ORDER BY updated_at DESC'
            : 'SELECT * FROM trading_file_entries WHERE company_id = ? AND $activeFilter ORDER BY updated_at DESC',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      
      final loadedEntries = results.map((row) {
        final data = row.data;
        // Handle migration from is_close to status
        String status = data['status'] as String? ?? 'Pending';
        if (status.isEmpty) {
          final isClose = (data['is_close'] as int? ?? 0) == 1;
          status = isClose ? 'Done' : 'Pending';
        }
        return _TradingFileEntry(
          id: data['id'] as String,
          type: (data['type'] as String) == 'buy' ? _TradingFileFormType.buy : _TradingFileFormType.sell,
          buyOption: data['buy_option'] as String?,
          sellOption: data['sell_option'] as String?,
          date: DateTime.parse(data['date'] as String),
          mobile: data['mobile'] as String? ?? '',
          personName: data['person_name'] as String? ?? '',
          estate: data['estate'] as String? ?? '',
          quantity: data['quantity'] as int? ?? 0,
          payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
          status: status,
          comments: data['comments'] as String? ?? '',
          isActive: (data['is_active'] as int? ?? 1) == 1,
        );
      }).toList();
      
      debugPrint('LOCAL DB: Found ${loadedEntries.length} trading entries total');
      setState(() {
        _entries.clear();
        _entries.addAll(loadedEntries);
        _loading = false;
      });
    } catch (e) {
      // Fallback if is_active column missing: fetch without filter so UI still shows data
      try {
        final fallback = await widget.db.customSelect(
          'SELECT * FROM trading_file_entries ORDER BY updated_at DESC',
        ).get();
        debugPrint('LOCAL DB (fallback): Found ${fallback.length} trading entries total');
        final loadedEntries = fallback.map((row) {
          final data = row.data;
          return _TradingFileEntry(
            id: data['id'] as String,
            type: (data['type'] as String) == 'buy' ? _TradingFileFormType.buy : _TradingFileFormType.sell,
            buyOption: data['buy_option'] as String?,
            sellOption: data['sell_option'] as String?,
            date: DateTime.parse(data['date'] as String),
            mobile: data['mobile'] as String? ?? '',
            personName: data['person_name'] as String? ?? '',
            estate: data['estate'] as String? ?? '',
            quantity: data['quantity'] as int? ?? 0,
            payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
            status: data['status']?.toString() ?? 'Pending',
            comments: data['comments'] as String? ?? '',
            isActive: (data['is_active'] as int? ?? 1) == 1,
          );
        }).toList();
        setState(() {
          _entries
            ..clear()
            ..addAll(loadedEntries);
          _loading = false;
        });
      } catch (_) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveEntry(_TradingFileEntry entry) async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        debugPrint('Save cancelled: missing companyId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company ID missing. Please re-login.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final myUserId = creatorFields(_currentUser)['creator_user_id_alias']?.toString();
      final creatorEmail = (_currentUser?['email'] ?? _currentUser?['username'])?.toString().trim().toLowerCase();
      String? createdBy = creatorEmail?.isNotEmpty == true ? creatorEmail : myUserId;
      try {
        final res = await widget.db.customSelect(
          'SELECT created_by FROM trading_file_entries WHERE id = ? LIMIT 1',
          variables: [d.Variable.withString(entry.id)],
        ).get();
        if (res.isNotEmpty) {
          final existingCreator = res.first.data['created_by']?.toString();
          if (existingCreator != null && existingCreator.isNotEmpty) {
            createdBy = existingCreator.trim().toLowerCase();
          }
        }
      } catch (_) {}

      await widget.db.customStatement('''
        INSERT OR REPLACE INTO trading_file_entries (
          id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, estate,
          quantity, payment, status, is_active, comments, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        entry.id,
        companyId,
        createdBy,
        entry.type == _TradingFileFormType.buy ? 'buy' : 'sell',
        entry.buyOption,
        entry.sellOption,
        entry.date.toIso8601String(),
        entry.mobile,
        entry.personName,
        entry.estate,
        entry.quantity,
        entry.payment,
        entry.status,
        1,
        entry.comments,
        DateTime.now().toUtc().toIso8601String(),
      ]);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _updateEntryStatus(String entryId, String newStatus) async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (isSuperAdmin) {
        await widget.db.customStatement(
          'UPDATE trading_file_entries SET status = ?, updated_at = ? WHERE id = ?',
          [newStatus, nowIso, entryId],
        );
      } else {
        await widget.db.customStatement(
          'UPDATE trading_file_entries SET status = ?, updated_at = ? WHERE id = ? AND company_id = ?',
          [newStatus, nowIso, entryId, companyId],
        );
      }

      // RootIsolateToken check removed - not available in this Flutter version
      Future.microtask(() async {
        try {
          await _executeFirestoreOperation(() async {
            if (Firebase.apps.isNotEmpty) {
              String? localCreatedBy;
              String? localCompanyId;
              try {
                final row = await widget.db.customSelect(
                  'SELECT created_by, company_id FROM trading_file_entries WHERE id = ? LIMIT 1',
                  variables: [d.Variable.withString(entryId)],
                ).get();
                if (row.isNotEmpty) {
                  localCreatedBy = row.first.data['created_by']?.toString();
                  localCompanyId = row.first.data['company_id']?.toString();
                }
              } catch (_) {}

              Map<String, dynamic>? creatorUser;
              if (localCreatedBy != null && localCreatedBy!.isNotEmpty) {
                try {
                  final u = await widget.db.customSelect(
                    'SELECT * FROM users WHERE user_id = ? OR id = ? LIMIT 1',
                    variables: [
                      d.Variable.withString(localCreatedBy!),
                      d.Variable.withString(localCreatedBy!),
                    ],
                  ).get();
                  if (u.isNotEmpty) creatorUser = Map<String, dynamic>.from(u.first.data);
                } catch (_) {}
              }

              final creator = creatorFields(
                creatorUser ??
                    {
                      'id': localCreatedBy,
                      'user_id': localCreatedBy,
                      'name': localCreatedBy,
                    },
              );
              final creatorAlias = creator['creator_user_id_alias']?.toString() ?? localCreatedBy;

              await FirebaseFirestore.instance.collection('trading_file_entries').doc(entryId).set(
                {
                  'id': entryId,
                  'companyId': localCompanyId ?? companyId,
                  'createdBy': creatorAlias,
                  'created_by': creatorAlias,
                  ...creator,
                  'status': newStatus,
                  'updatedAt': nowIso,
                  'updated_at': nowIso,
                },
                SetOptions(merge: true),
              );
              FirestoreCacheService().invalidateCache('trading_file_entries', entryId);
            }
          });
        } catch (_) {}
      });
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(String entryId) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
        final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
        final companyId = RoleUtils.getUserCompanyId(_currentUser);
      if (isSuperAdmin) {
        await widget.db.customStatement(
          "UPDATE trading_file_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
          [nowIso, entryId],
        );
      } else {
        await widget.db.customStatement(
          "UPDATE trading_file_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ? AND company_id = ?",
          [nowIso, entryId, companyId],
        );
      }

      Future.microtask(() async {
        try {
          await _executeFirestoreOperation(() async {
            if (Firebase.apps.isNotEmpty) {
              await FirebaseFirestore.instance.collection('trading_file_entries').doc(entryId).set(
                {
                  'status': 'archived',
                  'is_active': 0,
                  'isActive': 0,
                  'updated_at': nowIso,
                  'deleted_at': nowIso,
                },
                SetOptions(merge: true),
              );
              FirestoreCacheService().invalidateCache('trading_file_entries', entryId);
            }
          });
        } catch (_) {}
      });
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry archived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive entry: $e')),
        );
      }
    }
  }

  Widget _addPromptCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.blueGrey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(color: Colors.blueGrey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon, Widget? suffixIcon, bool isRequired = false}) {
    // Map labels to appropriate icons for better visual clarity
    IconData? fieldIcon = icon;
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name') || lowerLabel.contains('client') || lowerLabel.contains('owner')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone') || lowerLabel.contains('contact')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('email')) {
        fieldIcon = Icons.email_outlined;
      } else if (lowerLabel.contains('date') || lowerLabel.contains('time')) {
        fieldIcon = Icons.calendar_today_outlined;
      } else if (lowerLabel.contains('cnic') || lowerLabel.contains('id')) {
        fieldIcon = Icons.badge_outlined;
      } else if (lowerLabel.contains('plot') || lowerLabel.contains('file no') || lowerLabel.contains('reference')) {
        fieldIcon = Icons.numbers_outlined;
      } else if (lowerLabel.contains('size') || lowerLabel.contains('path')) {
        fieldIcon = Icons.straighten_outlined;
      } else if (lowerLabel.contains('price') || lowerLabel.contains('demand') || lowerLabel.contains('payment') || lowerLabel.contains('rent') || lowerLabel.contains('security')) {
        fieldIcon = null; // Will use "Rs" text widget instead
      } else if (lowerLabel.contains('category')) {
        fieldIcon = Icons.category_outlined;
      } else if (lowerLabel.contains('status')) {
        fieldIcon = Icons.info_outline;
      } else if (lowerLabel.contains('comment') || lowerLabel.contains('note')) {
        fieldIcon = Icons.note_outlined;
      } else if (lowerLabel.contains('address') || lowerLabel.contains('location')) {
        fieldIcon = Icons.location_on_outlined;
      } else if (lowerLabel.contains('registry') || lowerLabel.contains('transfer')) {
        fieldIcon = Icons.description_outlined;
      } else if (lowerLabel.contains('society') || lowerLabel.contains('block')) {
        fieldIcon = Icons.apartment_outlined;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }
    
    // Add red asterisk for required fields
    Widget? labelWidget;
    if (isRequired) {
      labelWidget = RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.poppins(
            color: Colors.grey.shade700,
          ),
          children: [
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Use "Rs" text widget for currency fields instead of dollar icon
    Widget? prefixWidget;
    if (fieldIcon == null && (label.toLowerCase().contains('price') || label.toLowerCase().contains('demand') || label.toLowerCase().contains('payment') || label.toLowerCase().contains('rent') || label.toLowerCase().contains('security'))) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text(
          'Rs',
          style: GoogleFonts.poppins(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );
    } else if (fieldIcon != null) {
      prefixWidget = Icon(fieldIcon, color: Colors.grey.shade700);
    }
    
    return InputDecoration(
      labelText: isRequired ? null : label,
      label: labelWidget,
      prefixIcon: prefixWidget,
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
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF23272E)
          : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.poppins(
        color: Colors.grey.shade700,
      ),
    );
  }

  /// Calculates the date based on payment option
  DateTime _calculateDateFromOption(String? option) {
    if (option == null) return DateTime.now();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (option) {
      case 'HP':
        // Today's date
        return today;
        
      case 'KP':
        // Tomorrow's date
        return today.add(const Duration(days: 1));
        
      case 'MP':
        // The coming Monday
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7; // If today is Monday, get next Monday
        return today.add(Duration(days: daysUntilMonday));
        
      case 'NMP':
        // The Monday after skipping one Monday (next-to-next Monday)
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday + 7)); // Skip one week
        
      case 'NNMP':
        // The Monday after skipping two Mondays (3rd upcoming Monday)
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday + 14)); // Skip two weeks
        
      case 'BOP':
      case 'SOP':
        // 30 days from today
        return today.add(const Duration(days: 30));
        
      case 'AEMP':
        // After the upcoming Eid, the first Monday following that Eid
        final nextEid = _getNextEidDate(now);
        // Find the first Monday after Eid
        int daysUntilMonday = (DateTime.monday - nextEid.weekday + 7) % 7;
        if (daysUntilMonday == 0) {
          // If Eid is on Monday, return the next Monday
          return nextEid.add(const Duration(days: 7));
        } else {
          return nextEid.add(Duration(days: daysUntilMonday));
        }
        
      default:
        return today;
    }
  }
  
  /// Gets the date of the next upcoming Eid (Eid-ul-Fitr or Eid-ul-Azha)
  /// This is an approximation - actual dates vary by lunar calendar
  DateTime _getNextEidDate(DateTime fromDate) {
    // Approximate Eid dates for common years (these should be updated annually)
    // Eid-ul-Fitr typically falls in April-May, Eid-ul-Azha in June-July
    final year = fromDate.year;
    final month = fromDate.month;
    final day = fromDate.day;
    
    // Approximate dates (these are examples and should be updated with actual dates)
    // For 2024-2026, approximate dates:
    final eidDates = <DateTime>[];
    
    // Add Eid dates for current and next year
    if (year == 2024) {
      eidDates.addAll([
        DateTime(2024, 4, 10), // Approximate Eid-ul-Fitr 2024
        DateTime(2024, 6, 16), // Approximate Eid-ul-Azha 2024
      ]);
    }
    if (year >= 2024) {
      eidDates.addAll([
        DateTime(2025, 3, 31), // Approximate Eid-ul-Fitr 2025
        DateTime(2025, 6, 6), // Approximate Eid-ul-Azha 2025
        DateTime(2026, 3, 20), // Approximate Eid-ul-Fitr 2026
        DateTime(2026, 5, 26), // Approximate Eid-ul-Azha 2026
      ]);
    }
    
    // Find the next Eid date
    final currentDate = DateTime(year, month, day);
    for (final eidDate in eidDates) {
      if (eidDate.isAfter(currentDate)) {
        return eidDate;
      }
    }
    
    // If no future Eid found in the list, approximate: assume next Eid is ~3 months away
    // This is a fallback - should be updated with actual dates
    return currentDate.add(const Duration(days: 90));
  }

  Future<void> _pickDate(_TradingFileFormType type) async {
    final now = DateTime.now();
    final initialDate = type == _TradingFileFormType.buy
        ? (_buySelectedDate ?? now)
        : (_sellSelectedDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        final formatted = DateFormat('dd MMM yyyy').format(picked);
        if (type == _TradingFileFormType.buy) {
          _buySelectedDate = picked;
          _buyDateCtl.text = formatted;
        } else {
          _sellSelectedDate = picked;
          _sellDateCtl.text = formatted;
        }
      });
    }
  }
  
  /// Sets the date automatically based on payment option
  void _setDateFromOption(_TradingFileFormType type, String? option) {
    if (option == null) return;
    
    final calculatedDate = _calculateDateFromOption(option);
    final formatted = DateFormat('dd MMM yyyy').format(calculatedDate);
    
    setState(() {
      if (type == _TradingFileFormType.buy) {
        _buySelectedDate = calculatedDate;
        _buyDateCtl.text = formatted;
        _buyDateLocked = true; // Lock the date field after auto-filling
      } else {
        _sellSelectedDate = calculatedDate;
        _sellDateCtl.text = formatted;
        _sellDateLocked = true; // Lock the date field after auto-filling
      }
    });
  }

  void _resetForm(_TradingFileFormType type) {
    if (type == _TradingFileFormType.buy) {
      _buyFormKey.currentState?.reset();
      setState(() {
        _buySelection = null;
        _buySelectedDate = null;
        _buyDateLocked = false; // Reset date lock flag
        _buyImages = []; // Reset images
      });
      _buyDateCtl.clear();
      _buyMobileCtl.clear();
      _buyPersonNameCtl.clear();
      _buyEstateCtl.clear();
      _buyQuantityCtl.clear();
      _buyPaymentCtl.clear();
      _buyCommentsCtl.clear();
    } else {
      _sellFormKey.currentState?.reset();
      setState(() {
        _sellSelection = null;
        _sellSelectedDate = null;
        _sellImages = []; // Reset images
      });
      _sellDateCtl.clear();
      _sellMobileCtl.clear();
      _sellPersonNameCtl.clear();
      _sellEstateCtl.clear();
      _sellQuantityCtl.clear();
      _sellPaymentCtl.clear();
      _sellCommentsCtl.clear();
    }
  }

  void _showAddFormDialog(_TradingFileFormType type) {
    setState(() {
      _selectedFormType = type;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by clicking outside
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _resetForm(type);
            setState(() {
              _selectedFormType = null;
            });
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Stack(
                  children: [
                    // Form content with padding for back button
                    Padding(
                      padding: const EdgeInsets.only(top: 56), // Space for back button
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == _TradingFileFormType.buy ? 'Buy Entry' : 'Sell Entry',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 24),
                                _buildTradeForm(type, setDialogState),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Back button at top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _resetForm(type);
                          setState(() {
                            _selectedFormType = null;
                          });
                          Navigator.of(context).pop();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          elevation: 2,
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
    );
  }

  /// Background sync to Firestore (non-blocking, doesn't delay UI)
  void _syncToFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    // RootIsolateToken check removed - not available in this Flutter version
    // Run in background without blocking
    Future.microtask(() async {
      try {
        await _executeFirestoreOperation(() async {
          if (Firebase.apps.isNotEmpty) {
            final firestore = FirebaseFirestore.instance;
            await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));
            // Invalidate cache after successful sync
            FirestoreCacheService().invalidateCache(collection, docId);
          }
        });
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
        // Sync will retry automatically when connectivity is restored
      }
    });
  }

 Future<void> _addEntryForType(_TradingFileFormType type, {BuildContext? dialogContext}) async {
    final formKey = type == _TradingFileFormType.buy ? _buyFormKey : _sellFormKey;
    if (!formKey.currentState!.validate()) return;

    final option = type == _TradingFileFormType.buy ? _buySelection : _sellSelection;
    final selectedDate = type == _TradingFileFormType.buy ? _buySelectedDate : _sellSelectedDate;
    if (option == null || selectedDate == null) return;

    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = _TradingFileEntry(
      id: entryId,
      type: type,
      buyOption: type == _TradingFileFormType.buy ? option : null,
      sellOption: type == _TradingFileFormType.sell ? option : null,
      date: selectedDate,
      mobile: (type == _TradingFileFormType.buy ? _buyMobileCtl : _sellMobileCtl).text.trim(),
      personName: (type == _TradingFileFormType.buy ? _buyPersonNameCtl : _sellPersonNameCtl).text.trim(),
      estate: (type == _TradingFileFormType.buy ? _buyEstateCtl : _sellEstateCtl).text.trim(),
      quantity: int.tryParse((type == _TradingFileFormType.buy ? _buyQuantityCtl : _sellQuantityCtl).text) ?? 0,
      payment: double.tryParse((type == _TradingFileFormType.buy ? _buyPaymentCtl : _sellPaymentCtl).text) ?? 0.0,
      status: 'Pending',
      comments: (type == _TradingFileFormType.buy ? _buyCommentsCtl : _sellCommentsCtl).text.trim(),
      isActive: true, // FIXED: Added isActive
    );
    
    await _saveEntry(entry);
    _loadEntries();
    _resetForm(type);
    
    final ctx = dialogContext ?? context;
    if (mounted && Navigator.canPop(ctx)) Navigator.pop(ctx);
  }

  List<DropdownMenuItem<String>> get _tradeDropdownItems => _tradeOptions
      .map((option) => DropdownMenuItem<String>(value: option, child: Text(option)))
      .toList(growable: false);

  int get _totalQuantity => _entries.fold(0, (sum, e) => sum + e.quantity);
  double get _totalPayment => _entries.fold(0.0, (sum, e) => sum + e.payment);

  /// Gets the start and end dates for the selected date range filter
  ({DateTime start, DateTime end}) _getDateRange() {
    // If "All" is selected, return a very wide range to show all records
    if (_dateRangeFilter == 'All') {
      return (start: DateTime(1970, 1, 1), end: DateTime(2100, 12, 31));
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_dateRangeFilter) {
      case 'Today':
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      
      case 'Tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        return (start: tomorrow, end: tomorrow.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      
      case 'After Tomorrow':
        final afterTomorrow = today.add(const Duration(days: 2));
        return (start: afterTomorrow, end: afterTomorrow.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      
      case 'This Week':
        // Get Monday of current week (Monday = 1, Sunday = 7)
        // If today is Thursday, show from the preceding Monday to the coming Sunday
        int daysFromMonday = now.weekday - DateTime.monday;
        if (daysFromMonday < 0) daysFromMonday += 7;
        final monday = today.subtract(Duration(days: daysFromMonday));
        final sunday = monday.add(const Duration(days: 6));
        return (start: monday, end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999));
      
      case 'Next Week':
        // Get Monday of current week
        int daysFromMonday = (now.weekday - DateTime.monday) % 7;
        if (daysFromMonday < 0) daysFromMonday += 7;
        final thisMonday = today.subtract(Duration(days: daysFromMonday));
        final nextMonday = thisMonday.add(const Duration(days: 7));
        final nextSunday = nextMonday.add(const Duration(days: 6));
        return (start: nextMonday, end: DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59, 999));
      
      case 'This Month':
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return (start: firstDay, end: lastDay);
      
      case 'Next Month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final lastDay = DateTime(now.year, now.month + 2, 0, 23, 59, 59, 999);
        return (start: nextMonth, end: lastDay);
      
      default:
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
    }
  }

  /// Filters entries based on the selected date range AND transaction type
  List<_TradingFileEntry> _getFilteredEntries() {
    final dateRange = _getDateRange();
    final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final endDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
    
    return _entries.where((entry) {
      // Filter by date range
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final isInDateRange = !entryDate.isBefore(startDate) && !entryDate.isAfter(endDate);
      
      // Filter by transaction type
      bool matchesTransactionType = true;
      if (_transactionTypeFilter == 'Buy') {
        matchesTransactionType = entry.type == _TradingFileFormType.buy;
      } else if (_transactionTypeFilter == 'Sell') {
        matchesTransactionType = entry.type == _TradingFileFormType.sell;
      }
      // If "All" is selected, matchesTransactionType remains true
      
      return isInDateRange && matchesTransactionType;
    }).toList();
  }

  /// Gets total payment for filtered entries
  double _getFilteredTotalPayment() {
    final filtered = _getFilteredEntries();
    return filtered.fold(0.0, (sum, e) => sum + e.payment);
  }

  /// Gets total quantity for filtered entries
  int _getFilteredTotalQuantity() {
    final filtered = _getFilteredEntries();
    return filtered.fold(0, (sum, e) => sum + e.quantity);
  }

  /// Gets the label for the summary based on transaction type
  String _getSummaryLabel() {
    switch (_transactionTypeFilter) {
      case 'Buy':
        return 'Total Purchases';
      case 'Sell':
        return 'Total Sales';
      default:
        return 'Total Payment';
    }
  }

  /// Gets unified summary from both trading_file_entries and trading_entries tables
  Future<Map<String, dynamic>> _getUnifiedSummary() async {
    try {
      // Get date range for filtering
      final dateRange = _getDateRange();
      final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
      final endDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
      final startDateStr = startDate.toIso8601String();
      final endDateStr = endDate.add(const Duration(days: 1)).toIso8601String();

      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);

      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        return {
          'totalBuy': 0.0,
          'totalSell': 0.0,
          'quantityBuy': 0,
          'quantitySell': 0,
          'totalCombined': 0.0,
          'quantityCombined': 0,
        };
      }

      // Query trading_file_entries (File module)
      final fileResults = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
                'FROM trading_file_entries '
                'WHERE date >= ? AND date < ? '
                'GROUP BY type'
            : 'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
                'FROM trading_file_entries '
                'WHERE company_id = ? AND date >= ? AND date < ? '
                'GROUP BY type',
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          d.Variable.withString(startDateStr),
          d.Variable.withString(endDateStr),
        ],
      ).get();

      // Query trading_entries (Form module)
      final formResults = isSuperAdmin
          ? await widget.db.customSelect(
              'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
              'FROM trading_entries '
              'WHERE date >= ? AND date < ? '
              'GROUP BY type',
              variables: [
                d.Variable.withString(startDateStr),
                d.Variable.withString(endDateStr),
              ],
            ).get()
          : await widget.db.customSelect(
              'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
              'FROM trading_entries '
              'WHERE company_id = ? AND date >= ? AND date < ? '
              'GROUP BY type',
              variables: [
                d.Variable.withString(companyId!),
                d.Variable.withString(startDateStr),
                d.Variable.withString(endDateStr),
              ],
            ).get();

      double totalBuy = 0.0;
      double totalSell = 0.0;
      int quantityBuy = 0;
      int quantitySell = 0;

      // Aggregate File module data
      for (final row in fileResults) {
        final data = row.data;
        final type = data['type'] as String?;
        final payment = (data['total_payment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (data['total_quantity'] as num?)?.toInt() ?? 0;

        if (type == 'buy') {
          totalBuy += payment;
          quantityBuy += quantity;
        } else if (type == 'sell') {
          totalSell += payment;
          quantitySell += quantity;
        }
      }

      // Aggregate Form module data
      for (final row in formResults) {
        final data = row.data;
        final type = data['type'] as String?;
        final payment = (data['total_payment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (data['total_quantity'] as num?)?.toInt() ?? 0;

        if (type == 'buy') {
          totalBuy += payment;
          quantityBuy += quantity;
        } else if (type == 'sell') {
          totalSell += payment;
          quantitySell += quantity;
        }
      }

      return {
        'totalBuy': totalBuy,
        'totalSell': totalSell,
        'quantityBuy': quantityBuy,
        'quantitySell': quantitySell,
        'totalCombined': totalBuy + totalSell,
        'quantityCombined': quantityBuy + quantitySell,
      };
    } catch (e) {
      debugPrint('Error getting unified summary: $e');
      return {
        'totalBuy': 0.0,
        'totalSell': 0.0,
        'quantityBuy': 0,
        'quantitySell': 0,
        'totalCombined': 0.0,
        'quantityCombined': 0,
      };
    }
  }

  Widget _dropdownWithSelection({
    required String label,
    required String? value,
    required String emptyMessage,
    required ValueChanged<String?> onChanged,
    required List<DropdownMenuItem<String>> items,
    bool isRequired = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: value,
          decoration: _fieldDecoration(label, isRequired: isRequired),
          items: items,
          onChanged: onChanged,
          validator: (selected) => selected == null ? emptyMessage : null,
        ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Selected: $value',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
      ],
    );
  }

  Widget _formDropdown({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: child,
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeForm(_TradingFileFormType type, [StateSetter? dialogSetState]) {
    final isBuy = type == _TradingFileFormType.buy;
    final formKey = isBuy ? _buyFormKey : _sellFormKey;
    final dateCtl = isBuy ? _buyDateCtl : _sellDateCtl;
    final mobileCtl = isBuy ? _buyMobileCtl : _sellMobileCtl;
    final personNameCtl = isBuy ? _buyPersonNameCtl : _sellPersonNameCtl;
    final estateCtl = isBuy ? _buyEstateCtl : _sellEstateCtl;
    final quantityCtl = isBuy ? _buyQuantityCtl : _sellQuantityCtl;
    final paymentCtl = isBuy ? _buyPaymentCtl : _sellPaymentCtl;
    final commentsCtl = isBuy ? _buyCommentsCtl : _sellCommentsCtl;
    final selectedDate = isBuy ? _buySelectedDate : _sellSelectedDate;
    final selection = isBuy ? _buySelection : _sellSelection;
    final isDateLocked = isBuy ? _buyDateLocked : _sellDateLocked;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final columns = maxWidth > 1100
              ? 3
              : maxWidth > 720
                  ? 2
                  : 1;
          final double fieldWidth = columns == 1 ? maxWidth : (maxWidth - (16 * (columns - 1))) / columns;
          Widget fieldBox(Widget child, {int span = 1}) {
            if (columns == 1) return SizedBox(width: double.infinity, child: child);
            final effectiveSpan = span > columns ? columns : span;
            final width = (fieldWidth * effectiveSpan) + (16 * (effectiveSpan - 1));
            return SizedBox(width: width, child: child);
          }

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              fieldBox(
                _dropdownWithSelection(
                  label: isBuy ? 'Payment Option' : 'Payment Option',
                  value: selection,
                  emptyMessage: 'Please select ${isBuy ? 'Payment' : 'Payment'} option',
                  isRequired: true,
                  onChanged: (value) {
                    if (dialogSetState != null) {
                      dialogSetState(() {
                        if (isBuy) {
                          _buySelection = value;
                        } else {
                          _sellSelection = value;
                        }
                      });
                    } else {
                      setState(() {
                        if (isBuy) {
                          _buySelection = value;
                        } else {
                          _sellSelection = value;
                        }
                      });
                    }
                    // Automatically set date based on payment option
                    if (value != null) {
                      _setDateFromOption(type, value);
                    }
                  },
                  items: _tradeDropdownItems,
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: dateCtl,
                  readOnly: true,
                  enabled: !isDateLocked,
                  decoration: _fieldDecoration('Date', isRequired: true).copyWith(
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: isDateLocked ? null : () => _pickDate(type),
                  validator: (_) => selectedDate == null ? 'Select a date' : null,
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: mobileCtl,
                  decoration: _fieldDecoration('Mobile No.', isRequired: true),
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [mobileNoFormatter],
                  validator: validateMobileNo,
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: personNameCtl,
                  decoration: _fieldDecoration('Person Name', isRequired: true),
                  maxLength: 100,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter Person Name';
                    return null;
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: estateCtl,
                  decoration: _fieldDecoration('Estate Name', isRequired: true),
                  maxLength: 50,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [estateNameFormatter],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter Estate Name';
                    return validateEstateName(value);
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: quantityCtl,
                  decoration: _fieldDecoration('Quantity', isRequired: true),
                  keyboardType: TextInputType.number,
                  maxLength: 50,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter quantity';
                    final validation = validateQuantity(value);
                    if (validation != null) return validation;
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return 'Enter valid quantity';
                    return null;
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: paymentCtl,
                  decoration: _fieldDecoration('Price', isRequired: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 100,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [priceFormatter],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter price';
                    final validation = validatePrice(value);
                    if (validation != null) return validation;
                    final pay = double.tryParse(value);
                    if (pay == null || pay <= 0) return 'Enter valid price';
                    return null;
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: commentsCtl,
                  decoration: _fieldDecoration('Remarks'),
                  maxLines: 3,
                  maxLength: 200,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [commentFormatter],
                  validator: validateComment,
                ),
                span: columns,
              ),
              fieldBox(
                ImageUploadWidget(
                  imagePaths: isBuy ? _buyImages : _sellImages,
                  onImagesChanged: (images) {
                    if (dialogSetState != null) {
                      dialogSetState(() {
                        if (isBuy) {
                          _buyImages = images;
                        } else {
                          _sellImages = images;
                        }
                      });
                    } else {
                      setState(() {
                        if (isBuy) {
                          _buyImages = images;
                        } else {
                          _sellImages = images;
                        }
                      });
                    }
                  },
                  maxImages: 3,
                ),
                span: columns,
              ),
              fieldBox(
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _resetForm(type);
                        setState(() {
                          _selectedFormType = null;
                        });
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: Icon(isBuy ? Icons.shopping_cart : Icons.work),
                      label: Text(isBuy ? 'Save Buy' : 'Save Sell'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isBuy ? const Color(0xFFFF6B35) : const Color(0xFF4A90E2),
                      ),
                      onPressed: () async {
                        // Save entry and close modal - pass dialog context
                        await _addEntryForType(type, dialogContext: context);
                      },
                    ),
                  ],
                ),
                span: columns,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _clientStatusCard(String Function(double) formatPayment, List<_TradingFileEntry> entries) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Status Overview',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
        decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('No client entries yet.'),
              )
            else
              SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    final table = DataTable(
                      headingRowHeight: 48,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 76,
                      columnSpacing: 24,
                      horizontalMargin: 16,
                      columns: const [
                        DataColumn(label: Text('Type'), numeric: false),
                        DataColumn(label: Text('Payment'), numeric: false),
                        DataColumn(label: Text('Date'), numeric: false),
                        DataColumn(label: Text('Mobile No.'), numeric: false),
                        DataColumn(label: Text('Person Name'), numeric: false),
                        DataColumn(label: Text('Estate Name'), numeric: false),
                        DataColumn(label: Text('Quantity'), numeric: true),
                        DataColumn(label: Text('Price (Rs)'), numeric: true),
                        DataColumn(label: Text('Remarks'), numeric: false),
                        DataColumn(label: Text('Action'), numeric: false),
                      ],
                      rows: entries
                          .map(
                            (entry) => DataRow(
                              color: MaterialStateProperty.resolveWith(
                                (states) => entry.isDone ? Colors.green.withOpacity(0.2) : null,
                              ),
                              cells: [
                                DataCell(Text(entry.type == _TradingFileFormType.buy ? 'Buy' : 'Sell')),
                                DataCell(Text(entry.buyOption ?? entry.sellOption ?? '-')),
                                DataCell(Text(DateFormat('dd MMM yyyy').format(entry.date))),
                                DataCell(Text(entry.mobile)),
                                DataCell(Text(entry.personName.isEmpty ? '-' : entry.personName)),
                                DataCell(Text(entry.estate)),
                                DataCell(Text(entry.quantity.toString())),
                                DataCell(Text(formatPayment(entry.payment))),
                                DataCell(Text(entry.comments.isEmpty ? '-' : entry.comments)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      entry.isDone
                                          // Once Done, status is locked; show a non-interactive chip
                                          ? _buildStatusChip(entry.status)
                                          : PopupMenuButton<String>(
                                              child: _buildStatusChip(entry.status),
                                              onSelected: (value) {
                                                // When user selects Close, we permanently move to Done
                                                if (value == 'Close') {
                                                  _updateEntryStatus(entry.id, 'Done');
                                                } else {
                                                  _updateEntryStatus(entry.id, value);
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: 'Pending',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.pending, size: 18),
                                                      SizedBox(width: 8),
                                                      Text('Pending'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'Close',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.close, size: 18),
                                                      SizedBox(width: 8),
                                                      Text('Close'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'Done',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.check_circle, size: 18, color: Colors.green),
                                                      SizedBox(width: 8),
                                                      Text('Done', style: TextStyle(color: Colors.green)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    );
                    if (!isNarrow) return table;
                    return Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 980),
                          child: table,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            // Global Overview Card (when All is selected) or Filtered Summary Card
            FutureBuilder<Map<String, dynamic>>(
              future: _getUnifiedSummary(),
              builder: (context, snapshot) {
                final summary = snapshot.data ?? {
                  'totalBuy': 0.0,
                  'totalSell': 0.0,
                  'quantityBuy': 0,
                  'quantitySell': 0,
                  'totalCombined': 0.0,
                  'quantityCombined': 0,
                };

                // Show Global Overview when "All" is selected, otherwise show filtered summary
                final isGlobalOverview = _transactionTypeFilter == 'All';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isGlobalOverview ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGlobalOverview ? Colors.green.shade200 : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isGlobalOverview ? Icons.dashboard : Icons.filter_alt,
                            size: 20,
                            color: isGlobalOverview ? Colors.green.shade900 : Colors.blue.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isGlobalOverview 
                                  ? 'Global Data Overview (${_dateRangeFilter})'
                                  : 'Summary (${_dateRangeFilter} - $_transactionTypeFilter)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isGlobalOverview ? Colors.green.shade900 : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isGlobalOverview) ...[
                        // Global Overview: Show Total In (Buy) and Total Out (Sell) side-by-side
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_downward, size: 16, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Total In (Buy)',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      summary['quantityBuy'] == 0 
                                          ? 'Qty: 0'
                                          : 'Qty: ${summary['quantityBuy']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      summary['totalBuy'] == 0 
                                          ? 'Rs 0'
                                          : 'Rs ${formatPayment(summary['totalBuy'] as double)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_upward, size: 16, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Total Out (Sell)',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      summary['quantitySell'] == 0 
                                          ? 'Qty: 0'
                                          : 'Qty: ${summary['quantitySell']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      summary['totalSell'] == 0 
                                          ? 'Rs 0'
                                          : 'Rs ${formatPayment(summary['totalSell'] as double)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Combined Total
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                                'Net Total',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                ),
                Text(
                                summary['totalCombined'] == 0 
                                    ? 'Rs 0'
                                    : 'Rs ${formatPayment(summary['totalCombined'] as double)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Filtered Summary: Show single filtered total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Quantity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_getFilteredTotalQuantity()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _getSummaryLabel(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getFilteredTotalPayment() == 0 
                                      ? 'Rs 0'
                                      : 'Rs ${formatPayment(_getFilteredTotalPayment())}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                ),
              ],
                            ),
                          ],
                        ),
                      ],
                    ],
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

  /// Builds a pill-style status chip used in the Action column.
  /// Colors:
  /// - Pending: blue (softer action color for follow-up)
  /// - Close: orange
  /// - Done: green (successful/finalizing action)
  Widget _buildStatusChip(String status) {
    Color bg;
    Color border;
    Color fg;

    switch (status) {
      case 'Done':
        // Green for successful/finalizing actions
        bg = Colors.green.shade100;
        border = Colors.green.shade300;
        fg = Colors.green.shade700;
        break;
      case 'Close':
        bg = Colors.orange.shade100;
        border = Colors.orange.shade300;
        fg = Colors.orange.shade700;
        break;
      case 'Pending':
      default:
        // Blue for pending status (softer action color, requires follow-up)
        bg = Colors.blue.shade100;
        border = Colors.blue.shade300;
        fg = Colors.blue.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hardcode isSuperAdmin to always allow access
    final isSuperAdmin = true;
    
    // Format numbers with commas for better readability
    String formatPayment(double value) {
      if (value == 0) return 'Rs 0';
      // Use NumberFormat to add commas as thousand separators
      // If it's a whole number, don't show decimals
      if (value == value.truncateToDouble()) {
        return NumberFormat('#,##0').format(value.toInt());
      } else {
        return NumberFormat('#,##0.##').format(value);
      }
    }

    // First filter by date range
    final dateFilteredEntries = _getFilteredEntries();
    
    // Then filter by search query if provided
    final q = _q.toLowerCase();
    final entries = q.isEmpty
        ? dateFilteredEntries
        : dateFilteredEntries.where((entry) {
            bool contains(String? v) => v != null && v.toLowerCase().contains(q);
            final dateStr = DateFormat('dd MMM yyyy').format(entry.date).toLowerCase();
            return contains(entry.buyOption) ||
                contains(entry.sellOption) ||
                contains(entry.mobile) ||
                contains(entry.personName) ||
                contains(entry.estate) ||
                contains(entry.comments) ||
                contains(entry.status) ||
                dateStr.contains(q) ||
                entry.quantity.toString().contains(q) ||
                entry.payment.toString().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Trading - File', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35), // Orange
                const Color(0xFF4A90E2), // Blue
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (q) {
              if (!mounted) return;
              setState(() => _q = q);
            }),
          ),
        ],
      ),
      floatingActionButton: (PermissionHelper.isBypassUser(_currentUser) || PermissionHelper.canAddModule(_currentUser, 'trading'))
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  onPressed: () => _showAddFormDialog(_TradingFileFormType.buy),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFFF6B35),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  onPressed: () => _showAddFormDialog(_TradingFileFormType.sell),
                  icon: const Icon(Icons.work),
                  label: const Text('Sell', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.blue,
                ),
              ],
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
              colors: [
              const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
              const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
            ],
          ),
        ),
        child: Stack(
          children: [
            RefreshIndicator(
                onRefresh: _loadEntries,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Filter Dropdowns Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: Row(
                        children: [
                          // Date Range Filter Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dateRangeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Date Range',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Today', child: Text('Today')),
                                DropdownMenuItem(value: 'Tomorrow', child: Text('Tomorrow')),
                                DropdownMenuItem(value: 'After Tomorrow', child: Text('After Tomorrow')),
                                DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                                DropdownMenuItem(value: 'Next Week', child: Text('Next Week')),
                                DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                                DropdownMenuItem(value: 'Next Month', child: Text('Next Month')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _dateRangeFilter = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Transaction Type Filter Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _transactionTypeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Transaction Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_horiz),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Buy', child: Text('Buy')),
                                DropdownMenuItem(value: 'Sell', child: Text('Sell')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _transactionTypeFilter = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entries.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _clientStatusCard(formatPayment, entries),
                    ] else if (!_loading && dateFilteredEntries.isEmpty) ...[
                      const SizedBox(height: 32),
                      _addPromptCard(
                        icon: Icons.calendar_today,
                        title: 'No entries found',
                        message: 'No entries found for the selected ${_dateRangeFilter.toLowerCase()}${_transactionTypeFilter != 'All' ? ' and $_transactionTypeFilter' : ''} filter.',
                      ),
                    ],
                  ],
                ),
              ),
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
class TradingFormPage extends StatefulWidget {
  final AppDatabase db;
  const TradingFormPage({super.key, required this.db});
  @override
  State<TradingFormPage> createState() => _TradingFormPageState();
}

enum _TradingFormType { buy, sell }

class _TradingClientEntry {
  final String id;
  final _TradingFormType type;
  final String? buyOption;
  final String? sellOption;
  final DateTime date;
  final String mobile;
  final String personName;
  final String buyerName;
  final String sellerName;
  final String estateName;
  final String plotNo;
  final String block;
  final double commission;
  final int quantity;
  final double payment;
  final String status; // 'Pending', 'Close', or 'Done'
  final String comments;
  final bool isActive;
  const _TradingClientEntry({
    required this.id,
    required this.type,
    required this.buyOption,
    required this.sellOption,
    required this.date,
    required this.mobile,
    required this.personName,
    required this.buyerName,
    required this.sellerName,
    required this.estateName,
    required this.plotNo,
    required this.block,
    required this.commission,
    required this.quantity,
    required this.payment,
    required this.status,
    required this.comments,
    required this.isActive,
  });

  bool get isDone => status == 'Done';
  bool get isPending => status == 'Pending';
}

Future<Uint8List> _buildTradingReceiptBytes({
  required _TradingClientEntry entry,
  required Map<String, dynamic>? user,
}) async {
  final companyName = (user?['company_name'] ??
          user?['companyName'] ??
          user?['company'] ??
          'Company')
      .toString();
  final doc = sfpdf.PdfDocument();
  final page = doc.pages.add();
  final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final grid = sfpdf.PdfGrid();
  grid.columns.add(count: 2);
  grid.headers.add(1);
  final header = grid.headers[0];
  header.cells[0].value = 'Field';
  header.cells[1].value = 'Value';
  final rows = <List<String>>[
    ['Company', companyName],
    ['Receipt Date', dateStr],
    ['Type', entry.type == _TradingFormType.buy ? 'Buy' : 'Sell'],
    ['Person', entry.personName],
    ['Mobile', entry.mobile],
    ['Estate', entry.estateName],
    ['Plot', entry.plotNo],
    ['Block', entry.block],
    ['Buyer', entry.buyerName],
    ['Seller', entry.sellerName],
    ['Quantity', entry.quantity.toString()],
    ['Payment', entry.payment.toStringAsFixed(2)],
    ['Deal Date', DateFormat('yyyy-MM-dd').format(entry.date)],
    ['Status', entry.status],
    ['Comments', entry.comments],
  ];
  for (final r in rows) {
    final row = grid.rows.add();
    row.cells[0].value = r[0];
    row.cells[1].value = r[1];
  }
  grid.style = sfpdf.PdfGridStyle(
    font: sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 12),
    cellPadding: sfpdf.PdfPaddings(left: 4, right: 4, top: 6, bottom: 6),
  );
  page.graphics.drawString(
    'Trading Receipt',
    sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 18, style: sfpdf.PdfFontStyle.bold),
    bounds: const Rect.fromLTWH(0, 0, 500, 30),
  );
  page.graphics.drawString(
    '$companyName • $dateStr',
    sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(0, 28, 500, 20),
  );
  grid.draw(
    page: page,
    bounds: Rect.fromLTWH(0, 60, page.getClientSize().width, 0),
  );
  final bytes = await doc.save();
  doc.dispose();
  return Uint8List.fromList(bytes);
}

class _TradingFormPageState extends State<TradingFormPage> {
  static const List<String> _tradeOptions = ['HP', 'KP', 'MP', 'NMP', 'NNMP', 'BOP', 'SOP', 'AEMP'];

  final _buyFormKey = GlobalKey<FormState>();
  final _sellFormKey = GlobalKey<FormState>();

  String? _buySelection;
  String? _sellSelection;
  String _q = '';

  final TextEditingController _buyDateCtl = TextEditingController();
  final TextEditingController _buyMobileCtl = TextEditingController();
  final TextEditingController _buyPersonNameCtl = TextEditingController();
  final TextEditingController _buyBuyerNameCtl = TextEditingController();
  final TextEditingController _buySellerNameCtl = TextEditingController();
  final TextEditingController _buyEstateCtl = TextEditingController();
  final TextEditingController _buyPlotNoCtl = TextEditingController();
  final TextEditingController _buyBlockCtl = TextEditingController();
  final TextEditingController _buyCommissionCtl = TextEditingController();
  final TextEditingController _buyQuantityCtl = TextEditingController();
  final TextEditingController _buyPaymentCtl = TextEditingController();
  final TextEditingController _buyCommentsCtl = TextEditingController();

  final TextEditingController _sellDateCtl = TextEditingController();
  final TextEditingController _sellMobileCtl = TextEditingController();
  final TextEditingController _sellPersonNameCtl = TextEditingController();
  final TextEditingController _sellBuyerNameCtl = TextEditingController();
  final TextEditingController _sellSellerNameCtl = TextEditingController();
  final TextEditingController _sellEstateCtl = TextEditingController();
  final TextEditingController _sellPlotNoCtl = TextEditingController();
  final TextEditingController _sellBlockCtl = TextEditingController();
  final TextEditingController _sellCommissionCtl = TextEditingController();
  final TextEditingController _sellQuantityCtl = TextEditingController();
  final TextEditingController _sellPaymentCtl = TextEditingController();
  final TextEditingController _sellCommentsCtl = TextEditingController();

  final List<_TradingClientEntry> _entries = [];
  DateTime? _buySelectedDate;
  DateTime? _sellSelectedDate;
  bool _buyDateLocked = false; // Tracks if date is auto-filled and locked
  bool _sellDateLocked = false; // Tracks if date is auto-filled and locked
  bool _loading = false;
  bool _firestoreReady = false;
  _TradingFormType? _selectedFormType;
  List<String> _buyImages = [];
  List<String> _sellImages = [];
  String _dateRangeFilter = 'Today'; // Default filter
  String _transactionTypeFilter = 'All'; // Default: All, Buy, Sell
  Map<String, dynamic>? _currentUser; // Current logged-in user for permission checks
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

  /// Get current user from AuthService
  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final authService = AuthService();
        final user = await authService.getCurrentUser(authToken);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCurrentUser();
      await _initializeTable();
      await _startFirestoreListener();
      await _loadEntries();
    });
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _buyDateCtl.dispose();
    _buyMobileCtl.dispose();
    _buyPersonNameCtl.dispose();
    _buyBuyerNameCtl.dispose();
    _buySellerNameCtl.dispose();
    _buyEstateCtl.dispose();
    _buyPlotNoCtl.dispose();
    _buyBlockCtl.dispose();
    _buyCommissionCtl.dispose();
    _buyQuantityCtl.dispose();
    _buyPaymentCtl.dispose();
    _buyCommentsCtl.dispose();

    _sellDateCtl.dispose();
    _sellMobileCtl.dispose();
    _sellPersonNameCtl.dispose();
    _sellBuyerNameCtl.dispose();
    _sellSellerNameCtl.dispose();
    _sellEstateCtl.dispose();
    _sellPlotNoCtl.dispose();
    _sellBlockCtl.dispose();
    _sellCommissionCtl.dispose();
    _sellQuantityCtl.dispose();
    _sellPaymentCtl.dispose();
    _sellCommentsCtl.dispose();
    super.dispose();
  }

  /// Start Firestore listener with pagination for real-time sync
  Future<void> _startFirestoreListener() async {
    if (!FirestoreSyncService().isAvailable) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      });
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      });
      return;
    }

    try {
      // Use secure query builder for role-based isolation with agent filtering
      Query query = buildSecureFirestoreQuery(
        collection: 'trading_entries',
        currentUser: _currentUser,
        orderBy: 'date',
        descending: true,
        limit: 50, // Paginated
        additionalAgentFilter: null,
      );

      _firestoreSub = query.snapshots().listen((snapshot) async {
        final changes = List<DocumentChange>.from(snapshot.docChanges);
        
        if (changes.isNotEmpty) {
          try {
            await widget.db.batch((batch) {
              for (final change in changes) {
                final doc = change.doc;
                final data = doc.data() as Map<String, dynamic>;
                final id = (data['id'] ?? doc.id).toString();
                
                if (change.type == DocumentChangeType.removed) {
                  batch.customStatement(
                    "UPDATE trading_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                    [DateTime.now().toUtc().toIso8601String(), id],
                  );
                  continue;
                }

                // Sync trading entry data to SQLite
                final type = (data['type'] ?? '').toString();
                final buyOption = (data['buy_option'] ?? data['buyOption'] ?? '').toString();
                final sellOption = (data['sell_option'] ?? data['sellOption'] ?? '').toString();
                final date = (data['date'] ?? '').toString();
                final mobile = (data['mobile'] ?? '').toString();
                final personName = (data['person_name'] ?? data['personName'] ?? '').toString();
                final buyerName = (data['buyer_name'] ?? data['buyerName'] ?? '').toString();
                final sellerName = (data['seller_name'] ?? data['sellerName'] ?? '').toString();
                final estateName = (data['estate_name'] ?? data['estateName'] ?? '').toString();
                final plotNo = (data['plot_no'] ?? data['plotNo'] ?? '').toString();
                final block = (data['block'] ?? '').toString();
                final commission = (data['commission'] is num) ? (data['commission'] as num).toDouble() : double.tryParse(data['commission']?.toString() ?? '') ?? 0.0;
                final quantity = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : int.tryParse(data['quantity']?.toString() ?? '') ?? 0;
                final payment = (data['payment'] is num) ? (data['payment'] as num).toDouble() : double.tryParse(data['payment']?.toString() ?? '') ?? 0.0;
                final status = (data['status'] ?? 'Pending').toString();
                final comments = (data['comments'] ?? '').toString();
                final createdBy = (data['created_by'] ?? data['createdBy'])?.toString();
                final cid = (data['company_id'] ?? data['companyId'])?.toString();
                final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();

                batch.customStatement(
                  'INSERT OR REPLACE INTO trading_entries (id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, buyer_name, seller_name, estate_name, plot_no, block, commission, quantity, payment, status, is_active, comments, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, 1), ?)',
                  [id, cid, createdBy, type, buyOption, sellOption, date, mobile, personName, buyerName, sellerName, estateName, plotNo, block, commission, quantity, payment, status, data['is_active'] ?? data['isActive'], comments, updatedAt],
                );
              }
            });
            
            // Update UI on main thread
            Future.microtask(() async {
              if (!mounted) return;
              _syncState.startLoading();
              _syncState.finishLoading(synced: true);
              await _loadEntries(); // Reload to show updated data
              if (!mounted) return;
              setState(() => _firestoreReady = true);
            });
          } catch (e) {
            debugPrint('Error syncing Firestore changes to SQLite (trading_entries): $e');
            Future.microtask(() {
              if (!mounted) return;
              _syncState.finishLoading(synced: false, errorMessage: e.toString());
              setState(() => _firestoreReady = true);
            });
          }
        } else {
          Future.microtask(() {
            if (!mounted) return;
            setState(() => _firestoreReady = true);
          });
        }
      }, onError: (error) {
        debugPrint('Firestore listener error (trading_entries): $error');
        // Handle missing index errors gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
        Future.microtask(() {
          if (!mounted) return;
          _syncState.finishLoading(synced: false, errorMessage: error.toString());
          setState(() => _firestoreReady = true);
        });
      });
    } catch (e) {
      debugPrint('Error starting Firestore listener (trading_entries): $e');
      // Handle missing index errors gracefully
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('index') || errorStr.contains('missing')) {
        debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
      }
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      });
    }
  }

  Future<void> _initializeTable() async {
    try {
      // Create table if it does not exist yet (new installs)
      await widget.db.customStatement('''
        CREATE TABLE IF NOT EXISTS trading_entries (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          created_by TEXT,
          type TEXT NOT NULL,
          buy_option TEXT,
          sell_option TEXT,
          date TEXT NOT NULL,
          mobile TEXT,
          person_name TEXT,
          buyer_name TEXT,
          seller_name TEXT,
          estate_name TEXT,
          plot_no TEXT,
          block TEXT,
          commission REAL,
          quantity INTEGER,
          payment REAL,
          status TEXT NOT NULL DEFAULT 'Pending',
          is_active INTEGER NOT NULL DEFAULT 1,
          comments TEXT,
          updated_at TEXT NOT NULL
        )
      ''');

      // Ensure company_id column exists for existing databases
      try {
        final columns = await widget.db
            .customSelect('PRAGMA table_info(trading_entries)')
            .get();
        final hasCompanyId = columns.any(
          (row) => (row.data['name'] as String?) == 'company_id',
        );
        if (!hasCompanyId) {
          await widget.db.customStatement(
            'ALTER TABLE trading_entries ADD COLUMN company_id TEXT',
          );
        }

        final hasCreatedBy = columns.any(
          (row) => (row.data['name'] as String?) == 'created_by',
        );
        if (!hasCreatedBy) {
          await widget.db.customStatement(
            'ALTER TABLE trading_entries ADD COLUMN created_by TEXT',
          );
        }
      } catch (_) {
        // Ignore
      }
      // Add person_name column if it doesn't exist (for existing databases)
      try {
        await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN person_name TEXT');
      } catch (e) {
        // Column already exists, ignore
      }

      // Ensure report-specific columns exist (backward compatible)
      try {
        await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN buyer_name TEXT');
      } catch (_) {}
      try {
        await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN seller_name TEXT');
      } catch (_) {}
      try {
        await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN plot_no TEXT');
      } catch (_) {}
      try {
        await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN block TEXT');
      } catch (_) {}
      try {
        await widget.db.customStatement('ALTER TABLE trading_entries ADD COLUMN commission REAL');
      } catch (_) {}

      // For existing databases created before "status" was added, ensure the column exists.
      try {
        final columns = await widget.db
            .customSelect('PRAGMA table_info(trading_entries)')
            .get();
        final hasStatus = columns.any(
          (row) => (row.data['name'] as String?) == 'status',
        );
        if (!hasStatus) {
          // Older DB â€“ add the status column with default 'Pending'
          await widget.db.customStatement(
            "ALTER TABLE trading_entries ADD COLUMN status TEXT NOT NULL DEFAULT 'Pending'",
          );
        }
        final hasIsActive = columns.any(
          (row) => (row.data['name'] as String?) == 'is_active',
        );
        if (!hasIsActive) {
          await widget.db.customStatement(
            'ALTER TABLE trading_entries ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
        }
      } catch (_) {
        // If PRAGMA or ALTER fails, ignore â€“ worst case status updates will still fail
        // but the rest of the screen will continue to work.
      }

      // Optional one-time migration from legacy is_close column (if it exists)
      try {
        await widget.db.customStatement('''
          UPDATE trading_entries 
          SET status = CASE 
            WHEN is_close = 1 THEN 'Done' 
            ELSE 'Pending' 
          END 
          WHERE (status IS NULL OR status = '')
        ''');
      } catch (_) {
        // Old column might not exist, safe to ignore.
      }

      // Add index to speed up status/is_active filtered queries
      try {
        await widget.db.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_entries_active ON trading_entries(status, is_active, updated_at)',
        );
      } catch (_) {}
      try {
        await widget.db.customStatement(
          'UPDATE trading_entries SET is_active = 1 WHERE is_active IS NULL',
        );
      } catch (_) {}
    } catch (e) {
      // Table might already exist, ignore
    }
  }

 Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final results = await widget.db.customSelect(
        isSuperAdmin
            ? "SELECT * FROM trading_entries WHERE (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1) ORDER BY updated_at DESC"
            : "SELECT * FROM trading_entries WHERE company_id = ? AND (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1) ORDER BY updated_at DESC",
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      
      final loadedEntries = results.map((row) {
        final data = row.data;
        String status = data['status'] as String? ?? 'Pending';
        if (status.isEmpty) {
          final isClose = (data['is_close'] as int? ?? 0) == 1;
          status = isClose ? 'Done' : 'Pending';
        }
        return _TradingClientEntry(
          id: data['id'] as String,
          type: (data['type'] as String) == 'buy' ? _TradingFormType.buy : _TradingFormType.sell,
          buyOption: data['buy_option'] as String?,
          sellOption: data['sell_option'] as String?,
          date: DateTime.parse(data['date'] as String),
          mobile: data['mobile'] as String? ?? '',
          personName: data['person_name'] as String? ?? '',
          buyerName: data['buyer_name'] as String? ?? '',
          sellerName: data['seller_name'] as String? ?? '',
          estateName: data['estate_name'] as String? ?? '',
          plotNo: data['plot_no'] as String? ?? '',
          block: data['block'] as String? ?? '',
          commission: (data['commission'] as num?)?.toDouble() ?? 0.0,
          quantity: data['quantity'] as int? ?? 0,
          payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
          status: status,
          comments: data['comments'] as String? ?? '',
          isActive: (data['is_active'] as int? ?? 1) == 1, // FIXED: Added isActive
        );
      }).toList();
      
      setState(() {
        _entries.clear();
        _entries.addAll(loadedEntries);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry(_TradingClientEntry entry) async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

      final creatorEmail = (_currentUser?['email'] ?? _currentUser?['username'])?.toString().trim().toLowerCase();
      final myUserId = creatorFields(_currentUser)['creator_user_id_alias']?.toString();
      String? createdBy = creatorEmail?.isNotEmpty == true ? creatorEmail : myUserId;
      try {
        final res = await widget.db.customSelect(
          'SELECT created_by FROM trading_entries WHERE id = ? LIMIT 1',
          variables: [d.Variable.withString(entry.id)],
        ).get();
        if (res.isNotEmpty) {
          final existingCreator = res.first.data['created_by']?.toString();
          if (existingCreator != null && existingCreator.isNotEmpty) {
            createdBy = existingCreator.trim().toLowerCase();
          }
        }
      } catch (_) {}

      await widget.db.customStatement('''
        INSERT OR REPLACE INTO trading_entries (
          id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, buyer_name, seller_name, estate_name, plot_no, block, commission,
          quantity, payment, status, is_active, comments, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        entry.id,
        companyId,
        createdBy,
        entry.type == _TradingFormType.buy ? 'buy' : 'sell',
        entry.buyOption,
        entry.sellOption,
        entry.date.toIso8601String(),
        entry.mobile,
        entry.personName,
        entry.buyerName,
        entry.sellerName,
        entry.estateName,
        entry.plotNo,
        entry.block,
        entry.commission,
        entry.quantity,
        entry.payment,
        entry.status,
        1,
        entry.comments,
        DateTime.now().toUtc().toIso8601String(),
      ]);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _updateEntryStatus(String entryId, String newStatus) async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (isSuperAdmin) {
        await widget.db.customStatement(
          'UPDATE trading_entries SET status = ?, updated_at = ? WHERE id = ?',
          [newStatus, nowIso, entryId],
        );
      } else {
        await widget.db.customStatement(
          'UPDATE trading_entries SET status = ?, updated_at = ? WHERE id = ? AND company_id = ?',
          [newStatus, nowIso, entryId, companyId],
        );
      }

      // RootIsolateToken check removed - not available in this Flutter version
      Future.microtask(() async {
        try {
          await _executeFirestoreOperation(() async {
            if (Firebase.apps.isNotEmpty) {
              String? localCreatedBy;
              String? localCompanyId;
              try {
                final row = await widget.db.customSelect(
                  'SELECT created_by, company_id FROM trading_entries WHERE id = ? LIMIT 1',
                  variables: [d.Variable.withString(entryId)],
                ).get();
                if (row.isNotEmpty) {
                  localCreatedBy = row.first.data['created_by']?.toString();
                  localCompanyId = row.first.data['company_id']?.toString();
                }
              } catch (_) {}

              Map<String, dynamic>? creatorUser;
              if (localCreatedBy != null && localCreatedBy!.isNotEmpty) {
                try {
                  final u = await widget.db.customSelect(
                    'SELECT * FROM users WHERE user_id = ? OR id = ? LIMIT 1',
                    variables: [
                      d.Variable.withString(localCreatedBy!),
                      d.Variable.withString(localCreatedBy!),
                    ],
                  ).get();
                  if (u.isNotEmpty) creatorUser = Map<String, dynamic>.from(u.first.data);
                } catch (_) {}
              }

              final creator = creatorFields(
                creatorUser ??
                    {
                      'id': localCreatedBy,
                      'user_id': localCreatedBy,
                      'name': localCreatedBy,
                    },
              );
              final creatorAlias = creator['creator_user_id_alias']?.toString() ?? localCreatedBy;

              await FirebaseFirestore.instance.collection('trading_entries').doc(entryId).set(
                {
                  'id': entryId,
                  'companyId': localCompanyId ?? companyId,
                  'createdBy': creatorAlias,
                  'created_by': creatorAlias,
                  ...creator,
                  'status': newStatus,
                  'updatedAt': nowIso,
                  'updated_at': nowIso,
                },
                SetOptions(merge: true),
              );
              FirestoreCacheService().invalidateCache('trading_entries', entryId);
            }
          });
        } catch (_) {}
      });
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(String entryId) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      if (isSuperAdmin) {
        await widget.db.customStatement(
          "UPDATE trading_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
          [nowIso, entryId],
        );
      } else {
        await widget.db.customStatement(
          "UPDATE trading_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ? AND company_id = ?",
          [nowIso, entryId, companyId],
        );
      }

      Future.microtask(() async {
        try {
          await _executeFirestoreOperation(() async {
            if (Firebase.apps.isNotEmpty) {
              await FirebaseFirestore.instance.collection('trading_entries').doc(entryId).set(
                {
                  'status': 'archived',
                  'is_active': 0,
                  'isActive': 0,
                  'updated_at': nowIso,
                  'deleted_at': nowIso,
                },
                SetOptions(merge: true),
              );
              FirestoreCacheService().invalidateCache('trading_entries', entryId);
            }
          });
        } catch (_) {}
      });
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry archived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive entry: $e')),
        );
      }
    }
  }
  Widget _addPromptCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.blueGrey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(color: Colors.blueGrey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  InputDecoration _fieldDecoration(String label, {IconData? icon, Widget? suffixIcon, bool isRequired = false}) {
    // Map labels to appropriate icons for better visual clarity
    IconData? fieldIcon = icon;
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name') || lowerLabel.contains('client') || lowerLabel.contains('owner')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone') || lowerLabel.contains('contact')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('email')) {
        fieldIcon = Icons.email_outlined;
      } else if (lowerLabel.contains('date') || lowerLabel.contains('time')) {
        fieldIcon = Icons.calendar_today_outlined;
      } else if (lowerLabel.contains('cnic') || lowerLabel.contains('id')) {
        fieldIcon = Icons.badge_outlined;
      } else if (lowerLabel.contains('plot') || lowerLabel.contains('file no') || lowerLabel.contains('reference')) {
        fieldIcon = Icons.numbers_outlined;
      } else if (lowerLabel.contains('size') || lowerLabel.contains('path')) {
        fieldIcon = Icons.straighten_outlined;
      } else if (lowerLabel.contains('price') || lowerLabel.contains('demand') || lowerLabel.contains('payment') || lowerLabel.contains('rent') || lowerLabel.contains('security')) {
        fieldIcon = null; // Will use "Rs" text widget instead
      } else if (lowerLabel.contains('category')) {
        fieldIcon = Icons.category_outlined;
      } else if (lowerLabel.contains('status')) {
        fieldIcon = Icons.info_outline;
      } else if (lowerLabel.contains('comment') || lowerLabel.contains('note')) {
        fieldIcon = Icons.note_outlined;
      } else if (lowerLabel.contains('address') || lowerLabel.contains('location')) {
        fieldIcon = Icons.location_on_outlined;
      } else if (lowerLabel.contains('registry') || lowerLabel.contains('transfer')) {
        fieldIcon = Icons.description_outlined;
      } else if (lowerLabel.contains('society') || lowerLabel.contains('block')) {
        fieldIcon = Icons.apartment_outlined;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }
    
    // Add red asterisk for required fields
    Widget? labelWidget;
    if (isRequired) {
      labelWidget = RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.poppins(
            color: Colors.grey.shade700,
          ),
          children: [
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Use "Rs" text widget for currency fields instead of dollar icon
    Widget? prefixWidget;
    if (fieldIcon == null && (label.toLowerCase().contains('price') || label.toLowerCase().contains('demand') || label.toLowerCase().contains('payment') || label.toLowerCase().contains('rent') || label.toLowerCase().contains('security'))) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text(
          'Rs',
          style: GoogleFonts.poppins(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );
    } else if (fieldIcon != null) {
      prefixWidget = Icon(fieldIcon, color: Colors.grey.shade700);
    }
    
    return InputDecoration(
      labelText: isRequired ? null : label,
      label: labelWidget,
      prefixIcon: prefixWidget,
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
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF23272E)
          : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.poppins(
        color: Colors.grey.shade700,
      ),
    );
  }

  /// Calculates the date based on payment option
  DateTime _calculateDateFromOption(String? option) {
    if (option == null) return DateTime.now();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (option) {
      case 'HP':
        return today;
      case 'KP':
        return today.add(const Duration(days: 1));
      case 'MP':
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday));
      case 'NMP':
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday + 7));
      case 'NNMP':
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday + 14));
      case 'BOP':
      case 'SOP':
        return today.add(const Duration(days: 30));
      case 'AEMP':
        final nextEid = _getNextEidDate(now);
        int daysUntilMonday = (DateTime.monday - nextEid.weekday + 7) % 7;
        if (daysUntilMonday == 0) {
          return nextEid.add(const Duration(days: 7));
        } else {
          return nextEid.add(Duration(days: daysUntilMonday));
        }
      default:
        return today;
    }
  }

  /// Gets the date of the next upcoming Eid (Eid-ul-Fitr or Eid-ul-Azha)
  /// This is an approximation - actual dates vary by lunar calendar
  DateTime _getNextEidDate(DateTime fromDate) {
    // Approximate Eid dates for common years (these should be updated annually)
    // Eid-ul-Fitr typically falls in April-May, Eid-ul-Azha in June-July
    final year = fromDate.year;
    final month = fromDate.month;
    final day = fromDate.day;
    
    // Approximate dates (these are examples and should be updated with actual dates)
    // For 2024-2026, approximate dates:
    final eidDates = <DateTime>[];
    
    // Add Eid dates for current and next year
    if (year == 2024) {
      eidDates.addAll([
        DateTime(2024, 4, 10), // Approximate Eid-ul-Fitr 2024
        DateTime(2024, 6, 16), // Approximate Eid-ul-Azha 2024
      ]);
    }
    if (year >= 2024) {
      eidDates.addAll([
        DateTime(2025, 3, 31), // Approximate Eid-ul-Fitr 2025
        DateTime(2025, 6, 6), // Approximate Eid-ul-Azha 2025
        DateTime(2026, 3, 20), // Approximate Eid-ul-Fitr 2026
        DateTime(2026, 5, 26), // Approximate Eid-ul-Azha 2026
      ]);
    }
    
    // Find the next Eid date
    final currentDate = DateTime(year, month, day);
    for (final eidDate in eidDates) {
      if (eidDate.isAfter(currentDate)) {
        return eidDate;
      }
    }
    
    // If no future Eid found in the list, approximate: assume next Eid is ~3 months away
    // This is a fallback - should be updated with actual dates
    return currentDate.add(const Duration(days: 90));
  }

  Future<void> _pickDate(_TradingFormType type) async {
    final now = DateTime.now();
    final initialDate = type == _TradingFormType.buy
        ? (_buySelectedDate ?? now)
        : (_sellSelectedDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        final formatted = DateFormat('dd MMM yyyy').format(picked);
        if (type == _TradingFormType.buy) {
          _buySelectedDate = picked;
          _buyDateCtl.text = formatted;
        } else {
          _sellSelectedDate = picked;
          _sellDateCtl.text = formatted;
        }
      });
    }
  }
  
  /// Sets the date automatically based on payment option
  void _setDateFromOption(_TradingFormType type, String? option) {
    if (option == null) return;
    
    final calculatedDate = _calculateDateFromOption(option);
    final formatted = DateFormat('dd MMM yyyy').format(calculatedDate);
    
    setState(() {
      if (type == _TradingFormType.buy) {
        _buySelectedDate = calculatedDate;
        _buyDateCtl.text = formatted;
        _buyDateLocked = true; // Lock the date field after auto-filling
      } else {
        _sellSelectedDate = calculatedDate;
        _sellDateCtl.text = formatted;
        _sellDateLocked = true; // Lock the date field after auto-filling
      }
    });
  }

  void _resetForm(_TradingFormType type) {
    if (type == _TradingFormType.buy) {
      _buyFormKey.currentState?.reset();
      setState(() {
        _buySelection = null;
        _buySelectedDate = null;
        _buyDateLocked = false; // Reset date lock flag
        _buyImages = []; // Reset images
      });
      _buyDateCtl.clear();
      _buyMobileCtl.clear();
      _buyPersonNameCtl.clear();
      _buyBuyerNameCtl.clear();
      _buySellerNameCtl.clear();
      _buyEstateCtl.clear();
      _buyPlotNoCtl.clear();
      _buyBlockCtl.clear();
      _buyCommissionCtl.clear();
      _buyQuantityCtl.clear();
      _buyPaymentCtl.clear();
      _buyCommentsCtl.clear();
    } else {
      _sellFormKey.currentState?.reset();
      setState(() {
        _sellSelection = null;
        _sellSelectedDate = null;
        _sellDateLocked = false; // Reset date lock flag
        _sellImages = []; // Reset images
      });
      _sellDateCtl.clear();
      _sellMobileCtl.clear();
      _sellPersonNameCtl.clear();
      _sellBuyerNameCtl.clear();
      _sellSellerNameCtl.clear();
      _sellEstateCtl.clear();
      _sellPlotNoCtl.clear();
      _sellBlockCtl.clear();
      _sellCommissionCtl.clear();
      _sellQuantityCtl.clear();
      _sellPaymentCtl.clear();
      _sellCommentsCtl.clear();
    }
  }

  List<DropdownMenuItem<String>> get _tradeDropdownItems => _tradeOptions
      .map((option) => DropdownMenuItem<String>(value: option, child: Text(option)))
      .toList(growable: false);

  Widget _dropdownWithSelection({
    required String label,
    required String? value,
    required String emptyMessage,
    required ValueChanged<String?> onChanged,
    required List<DropdownMenuItem<String>> items,
    bool isRequired = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: value,
          decoration: _fieldDecoration(label, isRequired: isRequired),
          items: items,
          onChanged: onChanged,
          validator: (selected) => selected == null ? emptyMessage : null,
        ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Selected: $value',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
      ],
    );
  }

  void _showAddFormDialog(_TradingFormType type) {
    setState(() {
      _selectedFormType = type;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by clicking outside
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _resetForm(type);
            setState(() {
              _selectedFormType = null;
            });
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Stack(
                  children: [
                    // Form content with padding for back button
                    Padding(
                      padding: const EdgeInsets.only(top: 56), // Space for back button
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == _TradingFormType.buy ? 'Buy Entry' : 'Sell Entry',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 24),
                                _buildTradeForm(type, setDialogState),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Back button at top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _resetForm(type);
                          setState(() {
                            _selectedFormType = null;
                          });
                          Navigator.of(context).pop();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          elevation: 2,
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
    );
  }

  /// Background sync to Firestore (non-blocking, doesn't delay UI)
  void _syncToFirestoreTradingForm({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    // RootIsolateToken check removed - not available in this Flutter version
    // Run in background without blocking
    Future.microtask(() async {
      try {
        await _executeFirestoreOperation(() async {
          if (Firebase.apps.isNotEmpty) {
            final firestore = FirebaseFirestore.instance;
            await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));
            // Invalidate cache after successful sync
            FirestoreCacheService().invalidateCache(collection, docId);
          }
        });
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
        // Sync will retry automatically when connectivity is restored
      }
    });
  }

  Future<void> _addEntryForType(_TradingFormType type, {BuildContext? dialogContext}) async {
    final formKey = type == _TradingFormType.buy ? _buyFormKey : _sellFormKey;
    if (!formKey.currentState!.validate()) {
      setState(() {});
      return;
    }
    final option = type == _TradingFormType.buy ? _buySelection : _sellSelection;
    final selectedDate = type == _TradingFormType.buy ? _buySelectedDate : _sellSelectedDate;
    if (option == null || selectedDate == null) {
      setState(() {});
      return;
    }
    final quantityCtl = type == _TradingFormType.buy ? _buyQuantityCtl : _sellQuantityCtl;
    final paymentCtl = type == _TradingFormType.buy ? _buyPaymentCtl : _sellPaymentCtl;
    final mobileCtl = type == _TradingFormType.buy ? _buyMobileCtl : _sellMobileCtl;
    final personNameCtl = type == _TradingFormType.buy ? _buyPersonNameCtl : _sellPersonNameCtl;
    final buyerNameCtl = type == _TradingFormType.buy ? _buyBuyerNameCtl : _sellBuyerNameCtl;
    final sellerNameCtl = type == _TradingFormType.buy ? _buySellerNameCtl : _sellSellerNameCtl;
    final estateCtl = type == _TradingFormType.buy ? _buyEstateCtl : _sellEstateCtl;
    final plotNoCtl = type == _TradingFormType.buy ? _buyPlotNoCtl : _sellPlotNoCtl;
    final blockCtl = type == _TradingFormType.buy ? _buyBlockCtl : _sellBlockCtl;
    final commissionCtl = type == _TradingFormType.buy ? _buyCommissionCtl : _sellCommissionCtl;
    final commentsCtl = type == _TradingFormType.buy ? _buyCommentsCtl : _sellCommentsCtl;

    // Capture images BEFORE saving
    final imagePaths = List<String>.from(type == _TradingFormType.buy ? _buyImages : _sellImages);

    final quantity = int.tryParse(quantityCtl.text.trim()) ?? 0;
    final payment = double.tryParse(paymentCtl.text.trim()) ?? 0.0;
    final commission = double.tryParse(commissionCtl.text.trim()) ?? 0.0;

    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = _TradingClientEntry(
      id: entryId,
      type: type,
      buyOption: type == _TradingFormType.buy ? option : null,
      sellOption: type == _TradingFormType.sell ? option : null,
      date: selectedDate,
      mobile: mobileCtl.text.trim(),
      personName: personNameCtl.text.trim(),
      buyerName: buyerNameCtl.text.trim(),
      sellerName: sellerNameCtl.text.trim(),
      estateName: estateCtl.text.trim(),
      plotNo: plotNoCtl.text.trim(),
      block: blockCtl.text.trim(),
      commission: commission,
      quantity: quantity,
      payment: payment,
      status: 'Pending', // Default status
      comments: commentsCtl.text.trim(),
      isActive: true,
    );
    
    // OFFLINE-FIRST: Save to local database FIRST
    await _saveEntry(entry);

    final creator = creatorFields(_currentUser);
    final creatorAlias = creator['creator_user_id_alias']?.toString();

    // Background sync to Firestore with images (non-blocking)
    _syncToFirestoreTradingForm(
      collection: 'trading_entries',
      docId: entryId,
      data: {
        'id': entryId,
        'companyId': RoleUtils.getUserCompanyId(_currentUser),
        'createdBy': creatorAlias,
        'created_by': creatorAlias,
        ...creator,
        'type': type == _TradingFormType.buy ? 'buy' : 'sell',
        'buyOption': entry.buyOption,
        'sellOption': entry.sellOption,
        'date': selectedDate.toIso8601String(),
        'mobile': mobileCtl.text.trim(),
        'personName': personNameCtl.text.trim(),
        'buyerName': buyerNameCtl.text.trim(),
        'buyer_name': buyerNameCtl.text.trim(),
        'sellerName': sellerNameCtl.text.trim(),
        'seller_name': sellerNameCtl.text.trim(),
        'estateName': estateCtl.text.trim(),
        'plotNo': plotNoCtl.text.trim(),
        'plot_no': plotNoCtl.text.trim(),
        'block': blockCtl.text.trim(),
        'commission': commission,
        'quantity': quantity,
        'payment': payment,
        'status': 'Pending',
        'comments': commentsCtl.text.trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'imagePaths': imagePaths.isNotEmpty ? imagePaths : null, // Save image paths
      },
    );
    
    // Reload entries in background (non-blocking)
    _loadEntries();
    
    // Reset form and close modal
    _resetForm(type);
    setState(() {
      _selectedFormType = null;
    });
    
    // Use dialog context if provided, otherwise use widget context
    final ctx = dialogContext ?? context;
    if (mounted && ctx.mounted) {
      Navigator.of(ctx).pop(); // Close the modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == _TradingFormType.buy ? 'Buy' : 'Sell'} entry saved')),
      );
    }
  }

  int get _totalQuantity => _entries.fold(0, (sum, entry) => sum + entry.quantity);
  double get _totalPayment => _entries.fold(0.0, (sum, entry) => sum + entry.payment);

  /// Gets the start and end dates for the selected date range filter
  ({DateTime start, DateTime end}) _getDateRange() {
    // If "All" is selected, return a very wide range to show all records
    if (_dateRangeFilter == 'All') {
      return (start: DateTime(1970, 1, 1), end: DateTime(2100, 12, 31));
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_dateRangeFilter) {
      case 'Today':
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      
      case 'Tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        return (start: tomorrow, end: tomorrow.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      
      case 'After Tomorrow':
        final afterTomorrow = today.add(const Duration(days: 2));
        return (start: afterTomorrow, end: afterTomorrow.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      
      case 'This Week':
        // Get Monday of current week (Monday = 1, Sunday = 7)
        // If today is Thursday, show from the preceding Monday to the coming Sunday
        int daysFromMonday = now.weekday - DateTime.monday;
        if (daysFromMonday < 0) daysFromMonday += 7;
        final monday = today.subtract(Duration(days: daysFromMonday));
        final sunday = monday.add(const Duration(days: 6));
        return (start: monday, end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999));
      
      case 'Next Week':
        // Get Monday of current week
        int daysFromMonday = (now.weekday - DateTime.monday) % 7;
        if (daysFromMonday < 0) daysFromMonday += 7;
        final thisMonday = today.subtract(Duration(days: daysFromMonday));
        final nextMonday = thisMonday.add(const Duration(days: 7));
        final nextSunday = nextMonday.add(const Duration(days: 6));
        return (start: nextMonday, end: DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59, 999));
      
      case 'This Month':
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return (start: firstDay, end: lastDay);
      
      case 'Next Month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final lastDay = DateTime(now.year, now.month + 2, 0, 23, 59, 59, 999);
        return (start: nextMonth, end: lastDay);
      
      default:
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
    }
  }

  /// Filters entries based on the selected date range AND transaction type
  List<_TradingClientEntry> _getFilteredEntries() {
    final dateRange = _getDateRange();
    final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final endDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
    
    return _entries.where((entry) {
      // Filter by date range
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final isInDateRange = !entryDate.isBefore(startDate) && !entryDate.isAfter(endDate);
      
      // Filter by transaction type
      bool matchesTransactionType = true;
      if (_transactionTypeFilter == 'Buy') {
        matchesTransactionType = entry.type == _TradingFormType.buy;
      } else if (_transactionTypeFilter == 'Sell') {
        matchesTransactionType = entry.type == _TradingFormType.sell;
      }
      // If "All" is selected, matchesTransactionType remains true
      
      return isInDateRange && matchesTransactionType;
    }).toList();
  }

  /// Gets total payment for filtered entries
  double _getFilteredTotalPayment() {
    final filtered = _getFilteredEntries();
    return filtered.fold(0.0, (sum, e) => sum + e.payment);
  }

  /// Gets total quantity for filtered entries
  int _getFilteredTotalQuantity() {
    final filtered = _getFilteredEntries();
    return filtered.fold(0, (sum, e) => sum + e.quantity);
  }

  /// Gets the label for the summary based on transaction type
  String _getSummaryLabel() {
    switch (_transactionTypeFilter) {
      case 'Buy':
        return 'Total Purchases';
      case 'Sell':
        return 'Total Sales';
      default:
        return 'Total Payment';
    }
  }

  /// Gets unified summary from both trading_file_entries and trading_entries tables
  Future<Map<String, dynamic>> _getUnifiedSummary() async {
    try {
      // Get date range for filtering
      final dateRange = _getDateRange();
      final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
      final endDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
      final startDateStr = startDate.toIso8601String();
      final endDateStr = endDate.add(const Duration(days: 1)).toIso8601String();

      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);

      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        return {
          'totalBuy': 0.0,
          'totalSell': 0.0,
          'quantityBuy': 0,
          'quantitySell': 0,
          'totalCombined': 0.0,
          'quantityCombined': 0,
        };
      }

      // Query trading_file_entries (File module)
      final fileResults = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
                'FROM trading_file_entries '
                'WHERE date >= ? AND date < ? '
                'GROUP BY type'
            : 'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
                'FROM trading_file_entries '
                'WHERE company_id = ? AND date >= ? AND date < ? '
                'GROUP BY type',
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          d.Variable.withString(startDateStr),
          d.Variable.withString(endDateStr),
        ],
      ).get();

      // Query trading_entries (Form module)
      final formResults = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
                'FROM trading_entries '
                'WHERE date >= ? AND date < ? '
                'GROUP BY type'
            : 'SELECT type, SUM(payment) as total_payment, SUM(quantity) as total_quantity, COUNT(*) as count '
                'FROM trading_entries '
                'WHERE company_id = ? AND date >= ? AND date < ? '
                'GROUP BY type',
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          d.Variable.withString(startDateStr),
          d.Variable.withString(endDateStr),
        ],
      ).get();

      double totalBuy = 0.0;
      double totalSell = 0.0;
      int quantityBuy = 0;
      int quantitySell = 0;

      // Aggregate File module data
      for (final row in fileResults) {
        final data = row.data;
        final type = data['type'] as String?;
        final payment = (data['total_payment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (data['total_quantity'] as int?) ?? 0;
        
        if (type == 'buy') {
          totalBuy += payment;
          quantityBuy += quantity;
        } else if (type == 'sell') {
          totalSell += payment;
          quantitySell += quantity;
        }
      }

      // Aggregate Form module data
      for (final row in formResults) {
        final data = row.data;
        final type = data['type'] as String?;
        final payment = (data['total_payment'] as num?)?.toDouble() ?? 0.0;
        final quantity = (data['total_quantity'] as int?) ?? 0;
        
        if (type == 'buy') {
          totalBuy += payment;
          quantityBuy += quantity;
        } else if (type == 'sell') {
          totalSell += payment;
          quantitySell += quantity;
        }
      }

      return {
        'totalBuy': totalBuy,
        'totalSell': totalSell,
        'quantityBuy': quantityBuy,
        'quantitySell': quantitySell,
        'totalCombined': totalBuy + totalSell,
        'quantityCombined': quantityBuy + quantitySell,
      };
    } catch (e) {
      debugPrint('Error getting unified summary: $e');
      return {
        'totalBuy': 0.0,
        'totalSell': 0.0,
        'quantityBuy': 0,
        'quantitySell': 0,
        'totalCombined': 0.0,
        'quantityCombined': 0,
      };
    }
  }

  Widget _formDropdown({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: Row(
                      children: [
                        Text(
                    title,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: child,
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeForm(_TradingFormType type, [StateSetter? dialogSetState]) {
    final isBuy = type == _TradingFormType.buy;
    final formKey = isBuy ? _buyFormKey : _sellFormKey;
    final dateCtl = isBuy ? _buyDateCtl : _sellDateCtl;
    final mobileCtl = isBuy ? _buyMobileCtl : _sellMobileCtl;
    final personNameCtl = isBuy ? _buyPersonNameCtl : _sellPersonNameCtl;
    final buyerNameCtl = isBuy ? _buyBuyerNameCtl : _sellBuyerNameCtl;
    final sellerNameCtl = isBuy ? _buySellerNameCtl : _sellSellerNameCtl;
    final estateCtl = isBuy ? _buyEstateCtl : _sellEstateCtl;
    final plotNoCtl = isBuy ? _buyPlotNoCtl : _sellPlotNoCtl;
    final blockCtl = isBuy ? _buyBlockCtl : _sellBlockCtl;
    final commissionCtl = isBuy ? _buyCommissionCtl : _sellCommissionCtl;
    final quantityCtl = isBuy ? _buyQuantityCtl : _sellQuantityCtl;
    final paymentCtl = isBuy ? _buyPaymentCtl : _sellPaymentCtl;
    final commentsCtl = isBuy ? _buyCommentsCtl : _sellCommentsCtl;
    final selectedDate = isBuy ? _buySelectedDate : _sellSelectedDate;
    final selection = isBuy ? _buySelection : _sellSelection;
    final isDateLocked = isBuy ? _buyDateLocked : _sellDateLocked;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final columns = maxWidth > 1100
              ? 3
              : maxWidth > 720
                  ? 2
                  : 1;
          final double fieldWidth = columns == 1 ? maxWidth : (maxWidth - (16 * (columns - 1))) / columns;
          Widget fieldBox(Widget child, {int span = 1}) {
            if (columns == 1) return SizedBox(width: double.infinity, child: child);
            final effectiveSpan = span > columns ? columns : span;
            final width = (fieldWidth * effectiveSpan) + (16 * (effectiveSpan - 1));
            return SizedBox(width: width, child: child);
          }

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              fieldBox(
                _dropdownWithSelection(
                  label: isBuy ? 'Payment Option' : 'Payment Option',
                  value: selection,
                  emptyMessage: isBuy ? 'Select a Payment option' : 'Select a Payment option',
                  isRequired: true,
                  onChanged: (value) {
                    if (dialogSetState != null) {
                      dialogSetState(() {
                        if (isBuy) {
                          _buySelection = value;
                        } else {
                          _sellSelection = value;
                        }
                      });
                    } else {
                      setState(() {
                        if (isBuy) {
                          _buySelection = value;
                        } else {
                          _sellSelection = value;
                        }
                      });
                    }
                    // Automatically set date based on payment option
                    if (value != null) {
                      _setDateFromOption(type, value);
                    }
                  },
                  items: _tradeDropdownItems,
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: dateCtl,
                  readOnly: true,
                  enabled: !isDateLocked,
                  decoration: _fieldDecoration('Date', isRequired: true).copyWith(
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: isDateLocked ? null : () => _pickDate(type),
                  validator: (_) => selectedDate == null ? 'Select a date' : null,
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: mobileCtl,
                  decoration: _fieldDecoration('Mobile No.', isRequired: true),
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [mobileNoFormatter],
                  validator: validateMobileNo,
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: personNameCtl,
                  decoration: _fieldDecoration('Person Name', isRequired: true),
                  maxLength: 100,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter Person Name';
                    return null;
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: estateCtl,
                  decoration: _fieldDecoration('Estate Name', isRequired: true),
                  maxLength: 50,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [estateNameFormatter],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter Estate Name';
                    return validateEstateName(value);
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: quantityCtl,
                  decoration: _fieldDecoration('Quantity', isRequired: true),
                  keyboardType: TextInputType.number,
                  maxLength: 50,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter quantity';
                    final validation = validateQuantity(value);
                    if (validation != null) return validation;
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return 'Enter valid quantity';
                    return null;
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: paymentCtl,
                  decoration: _fieldDecoration('Price', isRequired: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 100,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [priceFormatter],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter price';
                    final validation = validatePrice(value);
                    if (validation != null) return validation;
                    final pay = double.tryParse(value);
                    if (pay == null || pay <= 0) return 'Enter valid price';
                    return null;
                  },
                ),
              ),
              fieldBox(
                TextFormField(
                  controller: commentsCtl,
                  decoration: _fieldDecoration('Remarks'),
                  maxLines: 3,
                  maxLength: 200,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [commentFormatter],
                  validator: validateComment,
                        ),
                span: columns,
              ),
              fieldBox(
                ImageUploadWidget(
                  imagePaths: isBuy ? _buyImages : _sellImages,
                  onImagesChanged: (images) {
                    if (dialogSetState != null) {
                      dialogSetState(() {
                        if (isBuy) {
                          _buyImages = images;
                        } else {
                          _sellImages = images;
                        }
                      });
                    } else {
                      setState(() {
                        if (isBuy) {
                          _buyImages = images;
                        } else {
                          _sellImages = images;
                        }
                      });
                    }
                  },
                  maxImages: 3,
                ),
                span: columns,
              ),
              fieldBox(
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _resetForm(type);
                        setState(() {
                          _selectedFormType = null;
                        });
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: Icon(isBuy ? Icons.shopping_cart : Icons.work),
                      label: Text(isBuy ? 'Save Buy' : 'Save Sell'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isBuy ? const Color(0xFFFF6B35) : const Color(0xFF4A90E2),
                      ),
                      onPressed: () async {
                        // Save entry and close modal - pass dialog context
                        await _addEntryForType(type, dialogContext: context);
                      },
                    ),
                  ],
                ),
                span: columns,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _clientStatusCard(String Function(double) formatPayment, List<_TradingClientEntry> entries) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Status Overview',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('No client entries yet.'),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final table = DataTable(
                    headingRowHeight: 48,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 76,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('Type'), numeric: false),
                      DataColumn(label: Text('Payment'), numeric: false),
                      DataColumn(label: Text('Date'), numeric: false),
                      DataColumn(label: Text('Mobile No.'), numeric: false),
                      DataColumn(label: Text('Person Name'), numeric: false),
                      DataColumn(label: Text('Estate Name'), numeric: false),
                      DataColumn(label: Text('Quantity'), numeric: true),
                      DataColumn(label: Text('Price (Rs)'), numeric: true),
                      DataColumn(label: Text('Remarks'), numeric: false),
                      DataColumn(label: Text('Action'), numeric: false),
                    ],
                    rows: entries
                        .map(
                          (entry) => DataRow(
                            color: MaterialStateProperty.resolveWith(
                              (states) => entry.isDone ? Colors.green.withOpacity(0.2) : null,
                            ),
                            cells: [
                              DataCell(Text(entry.type == _TradingFormType.buy ? 'Buy' : 'Sell')),
                              DataCell(Text(entry.buyOption ?? entry.sellOption ?? '-')),
                              DataCell(Text(DateFormat('dd MMM yyyy').format(entry.date))),
                              DataCell(Text(entry.mobile)),
                              DataCell(Text(entry.personName.isEmpty ? '-' : entry.personName)),
                              DataCell(Text(entry.estateName)),
                              DataCell(Text(entry.quantity.toString())),
                              DataCell(Text(formatPayment(entry.payment))),
                              DataCell(Text(entry.comments.isEmpty ? '-' : entry.comments)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    entry.isDone
                                        ? _buildStatusChip(entry.status)
                                        : PopupMenuButton<String>(
                                            child: _buildStatusChip(entry.status),
                                            onSelected: (value) {
                                              if (value == 'Close') {
                                                _updateEntryStatus(entry.id, 'Done');
                                              } else {
                                                _updateEntryStatus(entry.id, value);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'Pending',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.pending, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Pending'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'Close',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.close, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Close'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'Done',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                                                    SizedBox(width: 8),
                                                    Text('Done', style: TextStyle(color: Colors.green)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                    const SizedBox(width: 8),
                                    if (PermissionHelper.canDeleteModule(_currentUser, 'trading'))
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Entry'),
                                              content: const Text('Are you sure you want to delete this entry?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _deleteEntry(entry.id);
                                                  },
                                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        tooltip: 'Delete entry',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.receipt_long),
                                      tooltip: 'Generate Receipt',
                                      onPressed: () async {
                                        try {
                                          final bytes = await _buildTradingReceiptBytes(entry: entry, user: _currentUser);
                                          await savePdfBytesToDisk(
                                            pdfBytes: bytes,
                                            suggestedBaseName: 'receipt_${entry.id}_${fmtTs(DateTime.now())}',
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Receipt generated')),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to generate receipt: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  );

                  if (!isNarrow) return table;
                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 980),
                        child: table,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            // Global Overview Card (when All is selected) or Filtered Summary Card
            FutureBuilder<Map<String, dynamic>>(
              future: _getUnifiedSummary(),
              builder: (context, snapshot) {
                final summary = snapshot.data ?? {
                  'totalBuy': 0.0,
                  'totalSell': 0.0,
                  'quantityBuy': 0,
                  'quantitySell': 0,
                  'totalCombined': 0.0,
                  'quantityCombined': 0,
                };

                // Show Global Overview when "All" is selected, otherwise show filtered summary
                final isGlobalOverview = _transactionTypeFilter == 'All';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isGlobalOverview ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGlobalOverview ? Colors.green.shade200 : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isGlobalOverview ? Icons.dashboard : Icons.filter_alt,
                            size: 20,
                            color: isGlobalOverview ? Colors.green.shade900 : Colors.blue.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isGlobalOverview
                                  ? 'Global Data Overview (${_dateRangeFilter})'
                                  : 'Summary (${_dateRangeFilter} - $_transactionTypeFilter)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isGlobalOverview ? Colors.green.shade900 : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isGlobalOverview) ...[
                        // Global Overview: Show Total In (Buy) and Total Out (Sell) side-by-side
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_downward, size: 16, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Total In (Buy)',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      summary['quantityBuy'] == 0 
                                          ? 'Qty: 0'
                                          : 'Qty: ${summary['quantityBuy']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      summary['totalBuy'] == 0 
                                          ? 'Rs 0'
                                          : 'Rs ${formatPayment(summary['totalBuy'] as double)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_upward, size: 16, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Total Out (Sell)',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      summary['quantitySell'] == 0 
                                          ? 'Qty: 0'
                                          : 'Qty: ${summary['quantitySell']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      summary['totalSell'] == 0 
                                          ? 'Rs 0'
                                          : 'Rs ${formatPayment(summary['totalSell'] as double)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Combined Total
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                                'Net Total',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                  ),
                Text(
                                summary['totalCombined'] == 0 
                                    ? 'Rs 0'
                                    : 'Rs ${formatPayment(summary['totalCombined'] as double)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Filtered Summary: Show single filtered total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Quantity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_getFilteredTotalQuantity()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _getSummaryLabel(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getFilteredTotalPayment() == 0 
                                      ? 'Rs 0'
                                      : 'Rs ${formatPayment(_getFilteredTotalPayment())}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hardcode isSuperAdmin to always allow access
    final isSuperAdmin = true;
    
    // Format numbers with commas for better readability
    String formatPayment(double value) {
      if (value == 0) return 'Rs 0';
      // Use NumberFormat to add commas as thousand separators
      // If it's a whole number, don't show decimals
      if (value == value.truncateToDouble()) {
        return NumberFormat('#,##0').format(value.toInt());
      } else {
        return NumberFormat('#,##0.##').format(value);
      }
    }

    // First filter by date range and transaction type
    final dateFilteredEntries = _getFilteredEntries();
    
    // Then filter by search query if provided
    final q = _q.toLowerCase();
    final entries = q.isEmpty
        ? dateFilteredEntries
        : dateFilteredEntries.where((entry) {
            bool contains(String? v) => v != null && v.toLowerCase().contains(q);
            final dateStr = DateFormat('dd MMM yyyy').format(entry.date).toLowerCase();
            return contains(entry.buyOption) ||
                contains(entry.sellOption) ||
                contains(entry.mobile) ||
                contains(entry.personName) ||
                contains(entry.estateName) ||
                contains(entry.comments) ||
                contains(entry.status) ||
                dateStr.contains(q) ||
                entry.quantity.toString().contains(q) ||
                entry.payment.toString().contains(q);
          }).toList();
    final double fabSafeBottom = MediaQuery.of(context).padding.bottom + 180;

    return Scaffold(
      appBar: AppBar(
        title: Text('Trading - Form', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35), // Orange
                const Color(0xFF4A90E2), // Blue
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (q) {
              if (!mounted) return;
              setState(() => _q = q);
            }),
          ),
        ],
      ),
      floatingActionButton: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  onPressed: () => _showAddFormDialog(_TradingFormType.buy),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFFF6B35),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  onPressed: () => _showAddFormDialog(_TradingFormType.sell),
                  icon: const Icon(Icons.work),
                  label: const Text('Sell', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.blue,
                ),
              ],
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
              const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
            ],
          ),
        ),
        child: Stack(
          children: [
            RefreshIndicator(
                onRefresh: _loadEntries,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, fabSafeBottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Filter Dropdowns Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: Row(
                        children: [
                          // Date Range Filter Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dateRangeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Date Range',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Today', child: Text('Today')),
                                DropdownMenuItem(value: 'Tomorrow', child: Text('Tomorrow')),
                                DropdownMenuItem(value: 'After Tomorrow', child: Text('After Tomorrow')),
                                DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                                DropdownMenuItem(value: 'Next Week', child: Text('Next Week')),
                                DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                                DropdownMenuItem(value: 'Next Month', child: Text('Next Month')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _dateRangeFilter = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Transaction Type Filter Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _transactionTypeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Transaction Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_horiz),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Buy', child: Text('Buy')),
                                DropdownMenuItem(value: 'Sell', child: Text('Sell')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _transactionTypeFilter = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 16),
                _clientStatusCard(formatPayment, entries),
              ] else if (!_loading && dateFilteredEntries.isEmpty) ...[
                const SizedBox(height: 32),
                _addPromptCard(
                  icon: Icons.calendar_today,
                  title: 'No entries found',
                  message: 'No entries found for the selected ${_dateRangeFilter.toLowerCase()}${_transactionTypeFilter != 'All' ? ' and $_transactionTypeFilter' : ''} filter.',
                ),
              ],
            ],
          ),
        ),
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

  /// Builds a pill-style status chip used in the Action column.
  /// Colors:
  /// - Pending: blue (softer action color for follow-up)
  /// - Close: orange
  /// - Done: green
  Widget _buildStatusChip(String status) {
    Color bg;
    Color border;
    Color fg;

    switch (status) {
      case 'Done':
        bg = Colors.green.shade100;
        border = Colors.green.shade300;
        fg = Colors.green.shade700;
        break;
      case 'Close':
        bg = Colors.orange.shade100;
        border = Colors.orange.shade300;
        fg = Colors.orange.shade700;
        break;
      case 'Pending':
      default:
        // Blue for pending status (softer action color, requires follow-up)
        bg = Colors.blue.shade100;
        border = Colors.blue.shade300;
        fg = Colors.blue.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

}

// Unified Trading Page with Tab System
class TradingPage extends StatefulWidget {
  final AppDatabase db;
  const TradingPage({super.key, required this.db});
  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTab = 'File'; // 'File' or 'Form'
  String _q = '';
  String _dateRangeFilter = 'Today';
  String _transactionTypeFilter = 'All';
  Map<String, dynamic>? _currentUser;
  
  // Firestore subscription and sync state
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  FirestoreSyncState _syncState = FirestoreSyncState();
  bool _firestoreReady = false;
  final Map<String, int> _tabPages = {'File': 0, 'Form': 0};
  final Map<String, ScrollController> _tabScrollControllers = {};

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
  static const int _itemsPerPage = 100; // Items per page (50-200 range)
  final Set<int> _loadedTabs = {0}; // Start with first tab loaded
  
  // File tab state (TradingFilePage)
  final List<_TradingFileEntry> _fileEntries = [];
  bool _fileLoading = false;
  bool _fileFirestoreReady = false;
  StreamSubscription<QuerySnapshot>? _fileFirestoreSub;
  
  // Form tab state (TradingFormPage)
  final List<_TradingClientEntry> _formEntries = [];
  bool _formLoading = false;
  bool _formFirestoreReady = false;
  StreamSubscription<QuerySnapshot>? _formFirestoreSub;
  
  // Form controllers for File tab
  static const List<String> _tradeOptions = ['HP', 'KP', 'MP', 'NMP', 'NNMP', 'BOP', 'SOP', 'AEMP'];
  final _fileBuyFormKey = GlobalKey<FormState>();
  final _fileSellFormKey = GlobalKey<FormState>();
  String? _fileBuySelection;
  String? _fileSellSelection;
  final TextEditingController _fileBuyDateCtl = TextEditingController();
  final TextEditingController _fileBuyMobileCtl = TextEditingController();
  final TextEditingController _fileBuyPersonNameCtl = TextEditingController();
  final TextEditingController _fileBuyEstateCtl = TextEditingController();
  final TextEditingController _fileBuyQuantityCtl = TextEditingController();
  final TextEditingController _fileBuyPaymentCtl = TextEditingController();
  final TextEditingController _fileBuyCommentsCtl = TextEditingController();
  final TextEditingController _fileSellDateCtl = TextEditingController();
  final TextEditingController _fileSellMobileCtl = TextEditingController();
  final TextEditingController _fileSellPersonNameCtl = TextEditingController();
  final TextEditingController _fileSellEstateCtl = TextEditingController();
  final TextEditingController _fileSellQuantityCtl = TextEditingController();
  final TextEditingController _fileSellPaymentCtl = TextEditingController();
  final TextEditingController _fileSellCommentsCtl = TextEditingController();
  DateTime? _fileBuySelectedDate;
  DateTime? _fileSellSelectedDate;
  bool _fileBuyDateLocked = false; // Tracks if date is auto-filled and locked
  bool _fileSellDateLocked = false; // Tracks if date is auto-filled and locked
  List<String> _fileBuyImages = [];
  List<String> _fileSellImages = [];
  _TradingFileFormType? _fileSelectedFormType;
  
  // Form controllers for Form tab
  final _formBuyFormKey = GlobalKey<FormState>();
  final _formSellFormKey = GlobalKey<FormState>();
  String? _formBuySelection;
  String? _formSellSelection;
  final TextEditingController _formBuyDateCtl = TextEditingController();
  final TextEditingController _formBuyMobileCtl = TextEditingController();
  final TextEditingController _formBuyPersonNameCtl = TextEditingController();
  final TextEditingController _formBuyBuyerNameCtl = TextEditingController();
  final TextEditingController _formBuySellerNameCtl = TextEditingController();
  final TextEditingController _formBuyEstateCtl = TextEditingController();
  final TextEditingController _formBuyPlotNoCtl = TextEditingController();
  final TextEditingController _formBuyBlockCtl = TextEditingController();
  final TextEditingController _formBuyCommissionCtl = TextEditingController();
  final TextEditingController _formBuyQuantityCtl = TextEditingController();
  final TextEditingController _formBuyPaymentCtl = TextEditingController();
  final TextEditingController _formBuyCommentsCtl = TextEditingController();
  final TextEditingController _formSellDateCtl = TextEditingController();
  final TextEditingController _formSellMobileCtl = TextEditingController();
  final TextEditingController _formSellPersonNameCtl = TextEditingController();
  final TextEditingController _formSellBuyerNameCtl = TextEditingController();
  final TextEditingController _formSellSellerNameCtl = TextEditingController();
  final TextEditingController _formSellEstateCtl = TextEditingController();
  final TextEditingController _formSellPlotNoCtl = TextEditingController();
  final TextEditingController _formSellBlockCtl = TextEditingController();
  final TextEditingController _formSellCommissionCtl = TextEditingController();
  final TextEditingController _formSellQuantityCtl = TextEditingController();
  final TextEditingController _formSellPaymentCtl = TextEditingController();
  final TextEditingController _formSellCommentsCtl = TextEditingController();
  DateTime? _formBuySelectedDate;
  DateTime? _formSellSelectedDate;
  bool _formBuyDateLocked = false; // Tracks if date is auto-filled and locked
  bool _formSellDateLocked = false; // Tracks if date is auto-filled and locked
  List<String> _formBuyImages = [];
  List<String> _formSellImages = [];
  _TradingFormType? _formSelectedFormType;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Initialize scroll controllers for both tabs
    _tabScrollControllers['File'] = ScrollController()..addListener(() => _onTabScroll('File'));
    _tabScrollControllers['Form'] = ScrollController()..addListener(() => _onTabScroll('Form'));
    
    // Set initial tab to File
    _tabController.index = 0;
    _loadedTabs.add(0);
    
    Future.microtask(() async {
      await _loadCurrentUser();
      await _initializeFileTable();
      await _initializeFormTable();
      await _startFileFirestoreListener();
      await _startFormFirestoreListener();
      await _loadFileEntries();
      await _loadFormEntries();
    });
  }
  
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final newTab = _tabController.index == 0 ? 'File' : 'Form';
      if (_selectedTab != newTab) {
        setState(() {
          _selectedTab = newTab;
        });
        // Mark tab as loaded
        _loadedTabs.add(_tabController.index);
      }
    }
  }
  
  void _onTabScroll(String tabType) {
    final controller = _tabScrollControllers[tabType];
    if (controller != null && controller.hasClients && controller.position.pixels > 0) {
      // Load more when near bottom (80% scrolled)
      if (controller.position.maxScrollExtent > 0 && 
          controller.position.pixels >= controller.position.maxScrollExtent * 0.8) {
        final filtered = _getFilteredEntriesForTab(tabType);
        final currentPage = _tabPages[tabType] ?? 0;
        final totalItems = filtered.length;
        final displayedItems = (currentPage + 1) * _itemsPerPage;
        
        if (displayedItems < totalItems) {
          setState(() {
            _tabPages[tabType] = currentPage + 1;
          });
        }
      }
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _fileFirestoreSub?.cancel();
    _formFirestoreSub?.cancel();
    for (var controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    _tabScrollControllers.clear();
    
    // Dispose File tab controllers
    _fileBuyDateCtl.dispose();
    _fileBuyMobileCtl.dispose();
    _fileBuyPersonNameCtl.dispose();
    _fileBuyEstateCtl.dispose();
    _fileBuyQuantityCtl.dispose();
    _fileBuyPaymentCtl.dispose();
    _fileBuyCommentsCtl.dispose();
    _fileSellDateCtl.dispose();
    _fileSellMobileCtl.dispose();
    _fileSellPersonNameCtl.dispose();
    _fileSellEstateCtl.dispose();
    _fileSellQuantityCtl.dispose();
    _fileSellPaymentCtl.dispose();
    _fileSellCommentsCtl.dispose();
    
    // Dispose Form tab controllers
    _formBuyDateCtl.dispose();
    _formBuyMobileCtl.dispose();
    _formBuyPersonNameCtl.dispose();
    _formBuyBuyerNameCtl.dispose();
    _formBuySellerNameCtl.dispose();
    _formBuyEstateCtl.dispose();
    _formBuyPlotNoCtl.dispose();
    _formBuyBlockCtl.dispose();
    _formBuyCommissionCtl.dispose();
    _formBuyQuantityCtl.dispose();
    _formBuyPaymentCtl.dispose();
    _formBuyCommentsCtl.dispose();
    _formSellDateCtl.dispose();
    _formSellMobileCtl.dispose();
    _formSellPersonNameCtl.dispose();
    _formSellBuyerNameCtl.dispose();
    _formSellSellerNameCtl.dispose();
    _formSellEstateCtl.dispose();
    _formSellPlotNoCtl.dispose();
    _formSellBlockCtl.dispose();
    _formSellCommissionCtl.dispose();
    _formSellQuantityCtl.dispose();
    _formSellPaymentCtl.dispose();
    _formSellCommentsCtl.dispose();
    
    super.dispose();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final authService = AuthService();
        final user = await authService.getCurrentUser(authToken);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }
  
  // File tab methods (from TradingFilePage)
  Future<void> _initializeFileTable() async {
    try {
      await widget.db.customStatement('''
        CREATE TABLE IF NOT EXISTS trading_file_entries (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          created_by TEXT,
          type TEXT NOT NULL,
          buy_option TEXT,
          sell_option TEXT,
          date TEXT NOT NULL,
          mobile TEXT,
          person_name TEXT,
          estate TEXT,
          quantity INTEGER,
          payment REAL,
          status TEXT NOT NULL DEFAULT 'Pending',
          comments TEXT,
          updated_at TEXT NOT NULL
        )
      ''');
      // Add migration logic if needed (similar to original)
    } catch (e) {
      // Table might already exist, ignore
    }
  }
  
  Future<void> _startFileFirestoreListener() async {
    if (!FirestoreSyncService().isAvailable) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _fileFirestoreReady = true);
      });
      return;
    }
    
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _fileFirestoreReady = true);
      });
      return;
    }
    
    try {
      Query query = buildSecureFirestoreQuery(
        collection: 'trading_file_entries',
        currentUser: _currentUser,
        orderBy: 'date',
        descending: true,
        limit: 50,
        additionalAgentFilter: isAgent ? 'createdBy' : null,
      );
      
      _fileFirestoreSub = query.snapshots().listen((snapshot) async {
        final changes = List<DocumentChange>.from(snapshot.docChanges);
        
        if (changes.isNotEmpty) {
          try {
            await widget.db.batch((batch) {
              for (final change in changes) {
                final doc = change.doc;
                final data = doc.data() as Map<String, dynamic>;
                final id = (data['id'] ?? doc.id).toString();
                
                if (change.type == DocumentChangeType.removed) {
                  batch.customStatement(
                    "UPDATE trading_file_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                    [DateTime.now().toUtc().toIso8601String(), id],
                  );
                  continue;
                }
                
                final type = (data['type'] ?? '').toString();
                final buyOption = (data['buy_option'] ?? data['buyOption'] ?? '').toString();
                final sellOption = (data['sell_option'] ?? data['sellOption'] ?? '').toString();
                final date = (data['date'] ?? '').toString();
                final mobile = (data['mobile'] ?? '').toString();
                final personName = (data['person_name'] ?? data['personName'] ?? '').toString();
                final estate = (data['estate'] ?? '').toString();
                final quantity = (data['quantity'] ?? '').toString();
                final payment = (data['payment'] is num) ? (data['payment'] as num).toDouble() : double.tryParse(data['payment']?.toString() ?? '') ?? 0.0;
                final status = (data['status'] ?? 'Pending').toString();
                final comments = (data['comments'] ?? '').toString();
                final createdBy = (data['created_by'] ?? data['createdBy'])?.toString();
                final cid = (data['company_id'] ?? data['companyId'])?.toString();
                final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
                
                batch.customStatement(
                  'INSERT OR REPLACE INTO trading_file_entries (id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, estate, quantity, payment, status, is_active, comments, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, 1), ?, ?)',
                  [id, cid, createdBy, type, buyOption, sellOption, date, mobile, personName, estate, quantity, payment, status, data['is_active'] ?? data['isActive'], comments, updatedAt],
                );
              }
            });
            
            // Update UI on main thread
            Future.microtask(() async {
              if (!mounted) return;
              await _loadFileEntries();
              if (!mounted) return;
              setState(() => _fileFirestoreReady = true);
            });
          } catch (e) {
            debugPrint('Error syncing Firestore changes to SQLite (trading_file_entries): $e');
            Future.microtask(() {
              if (!mounted) return;
              setState(() => _fileFirestoreReady = true);
            });
          }
        } else {
          Future.microtask(() {
            if (!mounted) return;
            setState(() => _fileFirestoreReady = true);
          });
        }
      }, onError: (error) {
        debugPrint('Firestore listener error (trading_file_entries): $error');
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _fileFirestoreReady = true);
        });
      });
    } catch (e) {
      debugPrint('Error starting Firestore listener (trading_file_entries): $e');
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _fileFirestoreReady = true);
      });
    }
  }
  
  Future<void> _loadFileEntries() async {
    setState(() => _fileLoading = true);
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final isAgent = RoleUtils.isAgent(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final myUserId = _currentUser?['id']?.toString();
      final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;
      
      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        setState(() => _fileLoading = false);
        return;
      }
      
      if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
        setState(() {
          _fileEntries.clear();
          _fileLoading = false;
        });
        return;
      }
      
      final activeFilter = " (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1) ";
      final results = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_file_entries WHERE $activeFilter ORDER BY updated_at DESC'
            : (isAgent
                ? 'SELECT * FROM trading_file_entries WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND $activeFilter ORDER BY updated_at DESC'
                : 'SELECT * FROM trading_file_entries WHERE company_id = ? AND $activeFilter ORDER BY updated_at DESC'),
        variables: isSuperAdmin
            ? []
            : [
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent) d.Variable.withString(myAlias ?? myUserId!),
              ],
      ).get();
      
      final loadedEntries = results.map((row) {
        final data = row.data;
        String status = data['status'] as String? ?? 'Pending';
        if (status.isEmpty) {
          final isClose = (data['is_close'] as int? ?? 0) == 1;
          status = isClose ? 'Done' : 'Pending';
        }
        return _TradingFileEntry(
          id: data['id'] as String,
          type: (data['type'] as String) == 'buy' ? _TradingFileFormType.buy : _TradingFileFormType.sell,
          buyOption: data['buy_option'] as String?,
          sellOption: data['sell_option'] as String?,
          date: DateTime.parse(data['date'] as String),
          mobile: data['mobile'] as String? ?? '',
          personName: data['person_name'] as String? ?? '',
          estate: data['estate'] as String? ?? '',
          quantity: data['quantity'] as int? ?? 0,
          payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
          status: status,
          comments: data['comments'] as String? ?? '',
          isActive: (data['is_active'] as int? ?? 1) == 1,
        );
      }).toList();
      
      setState(() {
        _fileEntries.clear();
        _fileEntries.addAll(loadedEntries);
        _fileLoading = false;
      });
    } catch (e) {
      // Fallback if is_active column missing: fetch without filter
      try {
        final fallback = await widget.db.customSelect(
          'SELECT * FROM trading_file_entries ORDER BY updated_at DESC',
        ).get();
        final loadedEntries = fallback.map((row) {
          final data = row.data;
          return _TradingFileEntry(
            id: data['id'] as String,
            type: (data['type'] as String) == 'buy' ? _TradingFileFormType.buy : _TradingFileFormType.sell,
            buyOption: data['buy_option'] as String?,
            sellOption: data['sell_option'] as String?,
            date: DateTime.parse(data['date'] as String),
            mobile: data['mobile'] as String? ?? '',
            personName: data['person_name'] as String? ?? '',
            estate: data['estate'] as String? ?? '',
            quantity: data['quantity'] as int? ?? 0,
            payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
            status: data['status']?.toString() ?? 'Pending',
            comments: data['comments'] as String? ?? '',
            isActive: (data['is_active'] as int? ?? 1) == 1,
          );
        }).toList();
        setState(() {
          _fileEntries
            ..clear()
            ..addAll(loadedEntries);
          _fileLoading = false;
        });
      } catch (_) {
        setState(() => _fileLoading = false);
      }
    }
  }
  
  // Form tab methods (from TradingFormPage) - similar structure
  Future<void> _initializeFormTable() async {
    try {
      await widget.db.customStatement('''
        CREATE TABLE IF NOT EXISTS trading_entries (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          created_by TEXT,
          type TEXT NOT NULL,
          buy_option TEXT,
          sell_option TEXT,
          date TEXT NOT NULL,
          mobile TEXT,
          person_name TEXT,
          buyer_name TEXT,
          seller_name TEXT,
          estate_name TEXT,
          plot_no TEXT,
          block TEXT,
          commission REAL,
          quantity INTEGER,
          payment REAL,
          status TEXT NOT NULL DEFAULT 'Pending',
          is_active INTEGER NOT NULL DEFAULT 1,
          comments TEXT,
          updated_at TEXT NOT NULL
        )
      ''');
      try {
        final columns = await widget.db.customSelect('PRAGMA table_info(trading_entries)').get();
        final hasIsActive = columns.any((row) => (row.data['name'] as String?) == 'is_active');
        if (!hasIsActive) {
          await widget.db.customStatement(
            'ALTER TABLE trading_entries ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
        }
      } catch (_) {}
    } catch (e) {
      // Table might already exist, ignore
    }
  }
  
  Future<void> _startFormFirestoreListener() async {
    if (!FirestoreSyncService().isAvailable) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _formFirestoreReady = true);
      });
      return;
    }
    
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _formFirestoreReady = true);
      });
      return;
    }
    
    try {
      Query query = buildSecureFirestoreQuery(
        collection: 'trading_entries',
        currentUser: _currentUser,
        orderBy: 'date',
        descending: true,
        limit: 50,
        additionalAgentFilter: isAgent ? 'createdBy' : null,
      );
      
      _formFirestoreSub = query.snapshots().listen((snapshot) async {
        try {
          final changes = List<DocumentChange>.from(snapshot.docChanges);
          
          if (changes.isNotEmpty) {
            try {
              await widget.db.batch((batch) {
                for (final change in changes) {
                  try {
                    final doc = change.doc;
                    final data = doc.data() as Map<String, dynamic>;
                    final id = (data['id'] ?? doc.id).toString();
                    
                    if (change.type == DocumentChangeType.removed) {
                      batch.customStatement(
                        "UPDATE trading_entries SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                        [DateTime.now().toUtc().toIso8601String(), id],
                      );
                      continue;
                    }
                    
                    final type = (data['type'] ?? '').toString();
                    final buyOption = (data['buy_option'] ?? data['buyOption'] ?? '').toString();
                    final sellOption = (data['sell_option'] ?? data['sellOption'] ?? '').toString();
                    final date = (data['date'] ?? '').toString();
                    final mobile = (data['mobile'] ?? '').toString();
                    final personName = (data['person_name'] ?? data['personName'] ?? '').toString();
                    final buyerName = (data['buyer_name'] ?? data['buyerName'] ?? '').toString();
                    final sellerName = (data['seller_name'] ?? data['sellerName'] ?? '').toString();
                    final estateName = (data['estate_name'] ?? data['estateName'] ?? '').toString();
                    final plotNo = (data['plot_no'] ?? data['plotNo'] ?? '').toString();
                    final block = (data['block'] ?? '').toString();
                    final commission = (data['commission'] is num) ? (data['commission'] as num).toDouble() : double.tryParse(data['commission']?.toString() ?? '') ?? 0.0;
                    final quantity = (data['quantity'] is num) ? (data['quantity'] as num).toInt() : int.tryParse(data['quantity']?.toString() ?? '') ?? 0;
                    final payment = (data['payment'] is num) ? (data['payment'] as num).toDouble() : double.tryParse(data['payment']?.toString() ?? '') ?? 0.0;
                    final status = (data['status'] ?? 'Pending').toString();
                    final comments = (data['comments'] ?? '').toString();
                    final createdBy = (data['created_by'] ?? data['createdBy'])?.toString();
                    final cid = (data['company_id'] ?? data['companyId'])?.toString();
                    final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
                    
                batch.customStatement(
                  'INSERT OR REPLACE INTO trading_entries (id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, buyer_name, seller_name, estate_name, plot_no, block, commission, quantity, payment, status, is_active, comments, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, 1), ?)',
                  [id, cid, createdBy, type, buyOption, sellOption, date, mobile, personName, buyerName, sellerName, estateName, plotNo, block, commission, quantity, payment, status, data['is_active'] ?? data['isActive'], comments, updatedAt],
                );
                  } catch (e) {
                    debugPrint('Skipping trading_entries change due to error: $e');
                  }
                }
              });
              
              // Update UI on main thread
              Future.microtask(() async {
                if (!mounted) return;
                await _loadFormEntries();
                if (!mounted) return;
                setState(() => _formFirestoreReady = true);
              });
            } catch (e) {
              debugPrint('Error syncing Firestore changes to SQLite (trading_entries): $e');
              Future.microtask(() {
                if (!mounted) return;
                setState(() => _formFirestoreReady = true);
              });
            }
          } else {
            Future.microtask(() {
              if (!mounted) return;
              setState(() => _formFirestoreReady = true);
            });
          }
        } catch (e) {
          debugPrint('Firestore snapshot handling error (trading_entries): $e');
          Future.microtask(() {
            if (!mounted) return;
            setState(() => _formFirestoreReady = true);
          });
        }
      }, onError: (error) {
        debugPrint('Firestore listener error (trading_entries form): $error');
        // Handle missing index errors gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _formFirestoreReady = true);
        });
      });
    } catch (e) {
      debugPrint('Error starting Firestore listener (trading_entries): $e');
      // Handle missing index errors gracefully
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('index') || errorStr.contains('missing')) {
        debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
      }
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _formFirestoreReady = true);
      });
    }
  }
  
  Future<void> _loadFormEntries() async {
    setState(() => _formLoading = true);
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final isAgent = RoleUtils.isAgent(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final myUserId = _currentUser?['id']?.toString();
      final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;
      
      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        setState(() => _formLoading = false);
        return;
      }
      
      if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
        setState(() {
          _formEntries.clear();
          _formLoading = false;
        });
        return;
      }
      
      final activeFilter = " (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1) ";
      final results = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_entries WHERE $activeFilter ORDER BY updated_at DESC'
            : (isAgent
                ? 'SELECT * FROM trading_entries WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND $activeFilter ORDER BY updated_at DESC'
                : 'SELECT * FROM trading_entries WHERE company_id = ? AND $activeFilter ORDER BY updated_at DESC'),
        variables: isSuperAdmin
            ? []
            : [
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent) d.Variable.withString(myAlias ?? myUserId!),
              ],
      ).get();
      
      final loadedEntries = results.map((row) {
        final data = row.data;
        String status = data['status'] as String? ?? 'Pending';
        if (status.isEmpty) {
          final isClose = (data['is_close'] as int? ?? 0) == 1;
          status = isClose ? 'Done' : 'Pending';
        }
        return _TradingClientEntry(
          id: data['id'] as String,
          type: (data['type'] as String) == 'buy' ? _TradingFormType.buy : _TradingFormType.sell,
          buyOption: data['buy_option'] as String?,
          sellOption: data['sell_option'] as String?,
          date: DateTime.parse(data['date'] as String),
          mobile: data['mobile'] as String? ?? '',
          personName: data['person_name'] as String? ?? '',
          buyerName: data['buyer_name'] as String? ?? '',
          sellerName: data['seller_name'] as String? ?? '',
          estateName: data['estate_name'] as String? ?? '',
          plotNo: data['plot_no'] as String? ?? '',
          block: data['block'] as String? ?? '',
          commission: (data['commission'] as num?)?.toDouble() ?? 0.0,
          quantity: data['quantity'] as int? ?? 0,
          payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
          status: status,
          comments: data['comments'] as String? ?? '',
          isActive: data['is_active'] ?? data['isActive'] ?? true,
        );
      }).toList();
      
      setState(() {
        _formEntries.clear();
        _formEntries.addAll(loadedEntries);
        _formLoading = false;
      });
    } catch (e) {
      // Fallback if is_active column missing: fetch without filter
      try {
        final fallback = await widget.db.customSelect(
          'SELECT * FROM trading_entries ORDER BY updated_at DESC',
        ).get();
        final loadedEntries = fallback.map((row) {
          final data = row.data;
          return _TradingClientEntry(
            id: data['id'] as String,
            type: (data['type'] as String) == 'buy' ? _TradingFormType.buy : _TradingFormType.sell,
            buyOption: data['buy_option'] as String?,
            sellOption: data['sell_option'] as String?,
            date: DateTime.parse(data['date'] as String),
            mobile: data['mobile'] as String? ?? '',
            personName: data['person_name'] as String? ?? '',
            buyerName: data['buyer_name'] as String? ?? '',
            sellerName: data['seller_name'] as String? ?? '',
            estateName: data['estate_name'] as String? ?? '',
            plotNo: data['plot_no'] as String? ?? '',
            block: data['block'] as String? ?? '',
            commission: (data['commission'] as num?)?.toDouble() ?? 0.0,
            quantity: data['quantity'] as int? ?? 0,
            payment: (data['payment'] as num?)?.toDouble() ?? 0.0,
            status: data['status']?.toString() ?? 'Pending',
            comments: data['comments'] as String? ?? '',
            isActive: (data['is_active'] as int? ?? 1) == 1,
          );
        }).toList();
        setState(() {
          _formEntries
            ..clear()
            ..addAll(loadedEntries);
          _formLoading = false;
        });
      } catch (_) {
        setState(() => _formLoading = false);
      }
    }
  }
  
  // Filtering and pagination methods
  ({DateTime start, DateTime end}) _getDateRange() {
    if (_dateRangeFilter == 'All') {
      // Return a very wide range for "All" option
      return (start: DateTime(1970, 1, 1), end: DateTime(2100, 12, 31));
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_dateRangeFilter) {
      case 'Today':
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      case 'Tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        return (start: tomorrow, end: tomorrow.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      case 'After Tomorrow':
        final afterTomorrow = today.add(const Duration(days: 2));
        return (start: afterTomorrow, end: afterTomorrow.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
      case 'This Week':
        int daysFromMonday = now.weekday - DateTime.monday;
        if (daysFromMonday < 0) daysFromMonday += 7;
        final monday = today.subtract(Duration(days: daysFromMonday));
        final sunday = monday.add(const Duration(days: 6));
        return (start: monday, end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999));
      case 'Next Week':
        int daysFromMonday = (now.weekday - DateTime.monday) % 7;
        if (daysFromMonday < 0) daysFromMonday += 7;
        final thisMonday = today.subtract(Duration(days: daysFromMonday));
        final nextMonday = thisMonday.add(const Duration(days: 7));
        final nextSunday = nextMonday.add(const Duration(days: 6));
        return (start: nextMonday, end: DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59, 999));
      case 'This Month':
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return (start: firstDay, end: lastDay);
      case 'Next Month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final lastDay = DateTime(now.year, now.month + 2, 0, 23, 59, 59, 999);
        return (start: nextMonth, end: lastDay);
      default:
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)));
    }
  }
  
  List<dynamic> _getFilteredEntriesForTab(String tabType) {
    final dateRange = _getDateRange();
    final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final endDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
    
    if (tabType == 'File') {
      return _fileEntries.where((entry) {
        final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
        final isInDateRange = !entryDate.isBefore(startDate) && !entryDate.isAfter(endDate);
        
        bool matchesTransactionType = true;
        if (_transactionTypeFilter == 'Buy') {
          matchesTransactionType = entry.type == _TradingFileFormType.buy;
        } else if (_transactionTypeFilter == 'Sell') {
          matchesTransactionType = entry.type == _TradingFileFormType.sell;
        }
        
        return isInDateRange && matchesTransactionType;
      }).toList();
    } else {
      return _formEntries.where((entry) {
        final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
        final isInDateRange = !entryDate.isBefore(startDate) && !entryDate.isAfter(endDate);
        
        bool matchesTransactionType = true;
        if (_transactionTypeFilter == 'Buy') {
          matchesTransactionType = entry.type == _TradingFormType.buy;
        } else if (_transactionTypeFilter == 'Sell') {
          matchesTransactionType = entry.type == _TradingFormType.sell;
        }
        
        return isInDateRange && matchesTransactionType;
      }).toList();
    }
  }
  
  List<dynamic> _getPaginatedEntriesForTab(String tabType) {
    final filtered = _getFilteredEntriesForTab(tabType);
    final currentPage = _tabPages[tabType] ?? 0;
    final startIndex = 0;
    final endIndex = ((currentPage + 1) * _itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }
  
  bool _hasMoreEntriesForTab(String tabType) {
    final filtered = _getFilteredEntriesForTab(tabType);
    final currentPage = _tabPages[tabType] ?? 0;
    return (currentPage + 1) * _itemsPerPage < filtered.length;
  }
  
  // Helper methods for forms
  InputDecoration _fieldDecoration(String label, {IconData? icon, Widget? suffixIcon, bool isRequired = false}) {
    IconData? fieldIcon = icon;
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name') || lowerLabel.contains('client') || lowerLabel.contains('owner')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone') || lowerLabel.contains('contact')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('email')) {
        fieldIcon = Icons.email_outlined;
      } else if (lowerLabel.contains('date') || lowerLabel.contains('time')) {
        fieldIcon = Icons.calendar_today_outlined;
      } else if (lowerLabel.contains('price') || lowerLabel.contains('demand') || lowerLabel.contains('payment') || lowerLabel.contains('rent') || lowerLabel.contains('security')) {
        fieldIcon = null;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }
    
    Widget? labelWidget;
    if (isRequired) {
      labelWidget = RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.poppins(color: Colors.grey.shade700),
          children: [
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    
    Widget? prefixWidget;
    if (fieldIcon == null && (label.toLowerCase().contains('price') || label.toLowerCase().contains('demand') || label.toLowerCase().contains('payment') || label.toLowerCase().contains('rent') || label.toLowerCase().contains('security'))) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text('Rs', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 16)),
      );
    } else if (fieldIcon != null) {
      prefixWidget = Icon(fieldIcon, color: Colors.grey.shade700);
    }
    
    return InputDecoration(
      labelText: isRequired ? null : label,
      label: labelWidget,
      prefixIcon: prefixWidget,
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
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
    );
  }
  
  Widget _dropdownWithSelection({
    required String label,
    required String? value,
    required String emptyMessage,
    required ValueChanged<String?> onChanged,
    required List<DropdownMenuItem<String>> items,
    bool isRequired = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: value,
          decoration: _fieldDecoration(label, isRequired: isRequired),
          items: items,
          onChanged: onChanged,
          validator: (selected) => selected == null ? emptyMessage : null,
        ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Selected: $value', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
          ),
      ],
    );
  }
  
  List<DropdownMenuItem<String>> get _tradeDropdownItems => _tradeOptions
      .map((option) => DropdownMenuItem<String>(value: option, child: Text(option)))
      .toList(growable: false);
  
  // File tab helper methods
  DateTime _calculateDateFromOption(String? option) {
    if (option == null) return DateTime.now();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (option) {
      case 'HP': return today;
      case 'KP': return today.add(const Duration(days: 1));
      case 'MP':
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday));
      case 'NMP':
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday + 7));
      case 'NNMP':
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        return today.add(Duration(days: daysUntilMonday + 14));
      case 'BOP':
      case 'SOP': return today.add(const Duration(days: 30));
      case 'AEMP':
        final nextEid = _getNextEidDate(now);
        int daysUntilMonday = (DateTime.monday - nextEid.weekday + 7) % 7;
        if (daysUntilMonday == 0) return nextEid.add(const Duration(days: 7));
        return nextEid.add(Duration(days: daysUntilMonday));
      default: return today;
    }
  }
  
  DateTime _getNextEidDate(DateTime fromDate) {
    final year = fromDate.year;
    final eidDates = <DateTime>[];
    if (year == 2024) {
      eidDates.addAll([DateTime(2024, 4, 10), DateTime(2024, 6, 16)]);
    }
    if (year >= 2024) {
      eidDates.addAll([
        DateTime(2025, 3, 31), DateTime(2025, 6, 6),
        DateTime(2026, 3, 20), DateTime(2026, 5, 26),
      ]);
    }
    final currentDate = DateTime(year, fromDate.month, fromDate.day);
    for (final eidDate in eidDates) {
      if (eidDate.isAfter(currentDate)) return eidDate;
    }
    return currentDate.add(const Duration(days: 90));
  }
  
  Future<void> _filePickDate(_TradingFileFormType type) async {
    final now = DateTime.now();
    final initialDate = type == _TradingFileFormType.buy
        ? (_fileBuySelectedDate ?? now)
        : (_fileSellSelectedDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        final formatted = DateFormat('dd MMM yyyy').format(picked);
        if (type == _TradingFileFormType.buy) {
          _fileBuySelectedDate = picked;
          _fileBuyDateCtl.text = formatted;
        } else {
          _fileSellSelectedDate = picked;
          _fileSellDateCtl.text = formatted;
        }
      });
    }
  }
  
  void _fileSetDateFromOption(_TradingFileFormType type, String? option) {
    if (option == null) return;
    final calculatedDate = _calculateDateFromOption(option);
    final formatted = DateFormat('dd MMM yyyy').format(calculatedDate);
    setState(() {
      if (type == _TradingFileFormType.buy) {
        _fileBuySelectedDate = calculatedDate;
        _fileBuyDateCtl.text = formatted;
        _fileBuyDateLocked = true; // Lock the date field after auto-filling
      } else {
        _fileSellSelectedDate = calculatedDate;
        _fileSellDateCtl.text = formatted;
        _fileSellDateLocked = true; // Lock the date field after auto-filling
      }
    });
  }
  
  void _fileResetForm(_TradingFileFormType type) {
    if (type == _TradingFileFormType.buy) {
      _fileBuyFormKey.currentState?.reset();
      setState(() {
        _fileBuySelection = null;
        _fileBuySelectedDate = null;
        _fileBuyDateLocked = false; // Reset date lock flag
        _fileBuyImages = [];
      });
      _fileBuyDateCtl.clear();
      _fileBuyMobileCtl.clear();
      _fileBuyPersonNameCtl.clear();
      _fileBuyEstateCtl.clear();
      _fileBuyQuantityCtl.clear();
      _fileBuyPaymentCtl.clear();
      _fileBuyCommentsCtl.clear();
    } else {
      _fileSellFormKey.currentState?.reset();
      setState(() {
        _fileSellSelection = null;
        _fileSellSelectedDate = null;
        _fileSellDateLocked = false; // Reset date lock flag
        _fileSellImages = [];
      });
      _fileSellDateCtl.clear();
      _fileSellMobileCtl.clear();
      _fileSellPersonNameCtl.clear();
      _fileSellEstateCtl.clear();
      _fileSellQuantityCtl.clear();
      _fileSellPaymentCtl.clear();
      _fileSellCommentsCtl.clear();
    }
  }
  
  Future<void> _fileSaveEntry(_TradingFileEntry entry) async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final creatorEmail = (_currentUser?['email'] ?? _currentUser?['username'])?.toString().trim().toLowerCase();
      final myUserId = creatorFields(_currentUser)['creator_user_id_alias']?.toString();
      String? createdBy = creatorEmail?.isNotEmpty == true ? creatorEmail : myUserId;
      try {
        final res = await widget.db.customSelect(
          'SELECT created_by FROM trading_file_entries WHERE id = ? LIMIT 1',
          variables: [d.Variable.withString(entry.id)],
        ).get();
        if (res.isNotEmpty) {
          final existingCreator = res.first.data['created_by']?.toString();
          if (existingCreator != null && existingCreator.isNotEmpty) {
            createdBy = existingCreator.trim().toLowerCase();
          }
        }
      } catch (_) {}
      await widget.db.customStatement('''
        INSERT OR REPLACE INTO trading_file_entries (
          id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, estate,
          quantity, payment, status, is_active, comments, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        entry.id, companyId, createdBy,
        entry.type == _TradingFileFormType.buy ? 'buy' : 'sell',
        entry.buyOption, entry.sellOption, entry.date.toIso8601String(),
        entry.mobile, entry.personName, entry.estate, entry.quantity, entry.payment,
        entry.status, 1, entry.comments, DateTime.now().toUtc().toIso8601String(),
      ]);
    } catch (e) {
      debugPrint('Error saving entry: $e');
    }
  }
  
  void _fileSyncToFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    Future.microtask(() async {
      try {
        await _executeFirestoreOperation(() async {
          if (Firebase.apps.isNotEmpty) {
            await FirebaseFirestore.instance.collection(collection).doc(docId).set(data, SetOptions(merge: true));
            FirestoreCacheService().invalidateCache(collection, docId);
          }
        });
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
        // Sync will retry automatically when connectivity is restored
      }
    });
  }

  Future<void> _addFileEntryForType(_TradingFileFormType type, {BuildContext? dialogContext}) async {
    final formKey = type == _TradingFileFormType.buy ? _fileBuyFormKey : _fileSellFormKey;
    if (!formKey.currentState!.validate()) {
      setState(() {});
      return;
    }
    final option = type == _TradingFileFormType.buy ? _fileBuySelection : _fileSellSelection;
    final selectedDate = type == _TradingFileFormType.buy ? _fileBuySelectedDate : _fileSellSelectedDate;
    if (option == null || selectedDate == null) {
      setState(() {});
      return;
    }
    final quantityCtl = type == _TradingFileFormType.buy ? _fileBuyQuantityCtl : _fileSellQuantityCtl;
    final paymentCtl = type == _TradingFileFormType.buy ? _fileBuyPaymentCtl : _fileSellPaymentCtl;
    final mobileCtl = type == _TradingFileFormType.buy ? _fileBuyMobileCtl : _fileSellMobileCtl;
    final personNameCtl = type == _TradingFileFormType.buy ? _fileBuyPersonNameCtl : _fileSellPersonNameCtl;
    final estateCtl = type == _TradingFileFormType.buy ? _fileBuyEstateCtl : _fileSellEstateCtl;
    final commentsCtl = type == _TradingFileFormType.buy ? _fileBuyCommentsCtl : _fileSellCommentsCtl;
    final imagePaths = List<String>.from(type == _TradingFileFormType.buy ? _fileBuyImages : _fileSellImages);
    final quantity = int.tryParse(quantityCtl.text.trim()) ?? 0;
    final payment = double.tryParse(paymentCtl.text.trim()) ?? 0.0;
    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Define creator fields for Firestore sync
    final creator = creatorFields(_currentUser);
    final creatorAlias = creator['creator_user_id_alias']?.toString();
    
    final entry = _TradingFileEntry(
      id: entryId,
      type: type,
      buyOption: type == _TradingFileFormType.buy ? option : null,
      sellOption: type == _TradingFileFormType.sell ? option : null,
      date: selectedDate,
      mobile: mobileCtl.text.trim(),
      personName: personNameCtl.text.trim(),
      estate: estateCtl.text.trim(),
      quantity: quantity,
      payment: payment,
      status: 'Pending',
      comments: commentsCtl.text.trim(),
      isActive: true,
    );
    _fileSyncToFirestore(
      collection: 'trading_file_entries',
      docId: entryId,
      data: {
        'id': entryId, 'companyId': RoleUtils.getUserCompanyId(_currentUser),
        'createdBy': creatorAlias, 'created_by': creatorAlias, ...creator,
        'type': type == _TradingFileFormType.buy ? 'buy' : 'sell',
        'buyOption': entry.buyOption, 'sellOption': entry.sellOption,
        'date': selectedDate.toIso8601String(), 'mobile': mobileCtl.text.trim(),
        'personName': personNameCtl.text.trim(), 'estate': estateCtl.text.trim(),
        'quantity': quantity, 'payment': payment, 'status': 'Pending',
        'comments': commentsCtl.text.trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'imagePaths': imagePaths.isNotEmpty ? imagePaths : null,
      },
    );
    _loadFileEntries();
    _fileResetForm(type);
    setState(() => _fileSelectedFormType = null);
    final ctx = dialogContext ?? context;
    if (mounted && ctx.mounted) {
      Navigator.of(ctx).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == _TradingFileFormType.buy ? 'Buy' : 'Sell'} entry saved')),
      );
    }
  }
  
  Widget _fileBuildTradeForm(_TradingFileFormType type, [StateSetter? dialogSetState]) {
    final isBuy = type == _TradingFileFormType.buy;
    final formKey = isBuy ? _fileBuyFormKey : _fileSellFormKey;
    final dateCtl = isBuy ? _fileBuyDateCtl : _fileSellDateCtl;
    final mobileCtl = isBuy ? _fileBuyMobileCtl : _fileSellMobileCtl;
    final personNameCtl = isBuy ? _fileBuyPersonNameCtl : _fileSellPersonNameCtl;
    final estateCtl = isBuy ? _fileBuyEstateCtl : _fileSellEstateCtl;
    final quantityCtl = isBuy ? _fileBuyQuantityCtl : _fileSellQuantityCtl;
    final paymentCtl = isBuy ? _fileBuyPaymentCtl : _fileSellPaymentCtl;
    final commentsCtl = isBuy ? _fileBuyCommentsCtl : _fileSellCommentsCtl;
    final selectedDate = isBuy ? _fileBuySelectedDate : _fileSellSelectedDate;
    final selection = isBuy ? _fileBuySelection : _fileSellSelection;
    final isDateLocked = isBuy ? _fileBuyDateLocked : _fileSellDateLocked;
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final columns = maxWidth > 1100 ? 3 : maxWidth > 720 ? 2 : 1;
          final double fieldWidth = columns == 1 ? maxWidth : (maxWidth - (16 * (columns - 1))) / columns;
          Widget fieldBox(Widget child, {int span = 1}) {
            if (columns == 1) return SizedBox(width: double.infinity, child: child);
            final effectiveSpan = span > columns ? columns : span;
            final width = (fieldWidth * effectiveSpan) + (16 * (effectiveSpan - 1));
            return SizedBox(width: width, child: child);
          }
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              fieldBox(_dropdownWithSelection(
                label: 'Payment Option', value: selection,
                emptyMessage: 'Please select Payment option', isRequired: true,
                onChanged: (value) {
                  if (dialogSetState != null) {
                    dialogSetState(() {
                      if (isBuy) _fileBuySelection = value;
                      else _fileSellSelection = value;
                    });
                  } else {
                    setState(() {
                      if (isBuy) _fileBuySelection = value;
                      else _fileSellSelection = value;
                    });
                  }
                  if (value != null) _fileSetDateFromOption(type, value);
                },
                items: _tradeDropdownItems,
              )),
              fieldBox(TextFormField(
                controller: dateCtl,
                readOnly: true,
                enabled: !isDateLocked,
                decoration: _fieldDecoration('Date', isRequired: true).copyWith(
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: isDateLocked ? null : () => _filePickDate(type),
                validator: (_) => selectedDate == null ? 'Select a date' : null,
              )),
              fieldBox(TextFormField(
                controller: mobileCtl,
                decoration: _fieldDecoration('Mobile No.', isRequired: true),
                keyboardType: TextInputType.phone, maxLength: 11,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [mobileNoFormatter],
                validator: validateMobileNo,
              )),
              fieldBox(TextFormField(
                controller: personNameCtl,
                decoration: _fieldDecoration('Person Name', isRequired: true),
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter Person Name' : null,
              )),
              fieldBox(TextFormField(
                controller: estateCtl,
                decoration: _fieldDecoration('Estate Name', isRequired: true),
                maxLength: 50,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [estateNameFormatter],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter Estate Name';
                  return validateEstateName(value);
                },
              )),
              fieldBox(TextFormField(
                controller: quantityCtl,
                decoration: _fieldDecoration('Quantity', isRequired: true),
                keyboardType: TextInputType.number, maxLength: 50,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter quantity';
                  final validation = validateQuantity(value);
                  if (validation != null) return validation;
                  final qty = int.tryParse(value);
                  if (qty == null || qty <= 0) return 'Enter valid quantity';
                  return null;
                },
              )),
              fieldBox(TextFormField(
                controller: paymentCtl,
                decoration: _fieldDecoration('Price', isRequired: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [priceFormatter],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter price';
                  final validation = validatePrice(value);
                  if (validation != null) return validation;
                  final pay = double.tryParse(value);
                  if (pay == null || pay <= 0) return 'Enter valid price';
                  return null;
                },
              )),
              fieldBox(TextFormField(
                controller: commentsCtl,
                decoration: _fieldDecoration('Remarks'),
                maxLines: 3, maxLength: 200,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [commentFormatter],
                validator: validateComment,
              ), span: columns),
              fieldBox(ImageUploadWidget(
                imagePaths: isBuy ? _fileBuyImages : _fileSellImages,
                onImagesChanged: (images) {
                  if (dialogSetState != null) {
                    dialogSetState(() {
                      if (isBuy) _fileBuyImages = images;
                      else _fileSellImages = images;
                    });
                  } else {
                    setState(() {
                      if (isBuy) _fileBuyImages = images;
                      else _fileSellImages = images;
                    });
                  }
                },
                maxImages: 3,
              ), span: columns),
              fieldBox(Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _fileResetForm(type);
                      setState(() => _fileSelectedFormType = null);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: Icon(isBuy ? Icons.shopping_cart : Icons.work),
                    label: Text(isBuy ? 'Save Buy' : 'Save Sell'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isBuy ? const Color(0xFFFF6B35) : const Color(0xFF4A90E2),
                    ),
                    onPressed: () => _fileAddEntryForType(type, dialogContext: context),
                  ),
                ],
              ), span: columns),
            ],
          );
        },
      ),
    );
  }
  
  // Placeholder method for file entry addition
  void _fileAddEntryForType(_TradingFileFormType type, {BuildContext? dialogContext}) {
    // This method should delegate to the appropriate file page method
    // For now, show a placeholder implementation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File entry addition not implemented in unified view')),
      );
    }
  }
  
  void _fileShowAddFormDialog(_TradingFileFormType type) {
    setState(() => _fileSelectedFormType = type);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _fileResetForm(type);
            setState(() => _fileSelectedFormType = null);
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == _TradingFileFormType.buy ? 'Buy Entry' : 'Sell Entry',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 24),
                                _fileBuildTradeForm(type, setDialogState),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _fileResetForm(type);
                          setState(() => _fileSelectedFormType = null);
                          Navigator.of(context).pop();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          elevation: 2,
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
    );
  }
  
  // Form tab helper methods
  Future<void> _formPickDate(_TradingFormType type) async {
    final now = DateTime.now();
    final initialDate = type == _TradingFormType.buy
        ? (_formBuySelectedDate ?? now)
        : (_formSellSelectedDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        final formatted = DateFormat('dd MMM yyyy').format(picked);
        if (type == _TradingFormType.buy) {
          _formBuySelectedDate = picked;
          _formBuyDateCtl.text = formatted;
        } else {
          _formSellSelectedDate = picked;
          _formSellDateCtl.text = formatted;
        }
      });
    }
  }
  
  void _formSetDateFromOption(_TradingFormType type, String? option) {
    if (option == null) return;
    final calculatedDate = _calculateDateFromOption(option);
    final formatted = DateFormat('dd MMM yyyy').format(calculatedDate);
    setState(() {
      if (type == _TradingFormType.buy) {
        _formBuySelectedDate = calculatedDate;
        _formBuyDateCtl.text = formatted;
        _formBuyDateLocked = true; // Lock the date field after auto-filling
      } else {
        _formSellSelectedDate = calculatedDate;
        _formSellDateCtl.text = formatted;
        _formSellDateLocked = true; // Lock the date field after auto-filling
      }
    });
  }
  
  void _formResetForm(_TradingFormType type) {
    if (type == _TradingFormType.buy) {
      _formBuyFormKey.currentState?.reset();
      setState(() {
        _formBuySelection = null;
        _formBuySelectedDate = null;
        _formBuyDateLocked = false; // Reset date lock flag
        _formBuyImages = [];
      });
      _formBuyDateCtl.clear();
      _formBuyMobileCtl.clear();
      _formBuyPersonNameCtl.clear();
      _formBuyBuyerNameCtl.clear();
      _formBuySellerNameCtl.clear();
      _formBuyEstateCtl.clear();
      _formBuyPlotNoCtl.clear();
      _formBuyBlockCtl.clear();
      _formBuyCommissionCtl.clear();
      _formBuyQuantityCtl.clear();
      _formBuyPaymentCtl.clear();
      _formBuyCommentsCtl.clear();
    } else {
      _formSellFormKey.currentState?.reset();
      setState(() {
        _formSellSelection = null;
        _formSellSelectedDate = null;
        _formSellDateLocked = false; // Reset date lock flag
        _formSellImages = [];
      });
      _formSellDateCtl.clear();
      _formSellMobileCtl.clear();
      _formSellPersonNameCtl.clear();
      _formSellBuyerNameCtl.clear();
      _formSellSellerNameCtl.clear();
      _formSellEstateCtl.clear();
      _formSellPlotNoCtl.clear();
      _formSellBlockCtl.clear();
      _formSellCommissionCtl.clear();
      _formSellQuantityCtl.clear();
      _formSellPaymentCtl.clear();
      _formSellCommentsCtl.clear();
    }
  }
  
  Future<void> _formSaveEntry(_TradingClientEntry entry) async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        debugPrint('Form save cancelled: missing companyId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company ID missing. Please re-login.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final creatorEmail = (_currentUser?['email'] ?? _currentUser?['username'])?.toString().trim().toLowerCase();
      final myUserId = creatorFields(_currentUser)['creator_user_id_alias']?.toString();
      String? createdBy = creatorEmail?.isNotEmpty == true ? creatorEmail : myUserId;
      try {
        final res = await widget.db.customSelect(
          'SELECT created_by FROM trading_entries WHERE id = ? LIMIT 1',
          variables: [d.Variable.withString(entry.id)],
        ).get();
        if (res.isNotEmpty) {
          final existingCreator = res.first.data['created_by']?.toString();
          if (existingCreator != null && existingCreator.isNotEmpty) {
            createdBy = existingCreator.trim().toLowerCase();
          }
        }
      } catch (_) {}
      await widget.db.customStatement('''
        INSERT OR REPLACE INTO trading_entries (
          id, company_id, created_by, type, buy_option, sell_option, date, mobile, person_name, buyer_name, seller_name, estate_name, plot_no, block, commission,
          quantity, payment, status, is_active, comments, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        entry.id,
        companyId,
        createdBy,
        entry.type == _TradingFormType.buy ? 'buy' : 'sell',
        entry.buyOption,
        entry.sellOption,
        entry.date.toIso8601String(),
        entry.mobile, entry.personName, entry.buyerName, entry.sellerName,
        entry.estateName, entry.plotNo, entry.block, entry.commission,
        entry.quantity,
        entry.payment,
        entry.status,
        1, // ensure is_active is set explicitly
        entry.comments,
        DateTime.now().toUtc().toIso8601String(),
      ]);
    } catch (e) {
      debugPrint('Error saving entry: $e');
    }
  }
  
  void _formSyncToFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    if (!kIsWeb && io.Platform.isWindows) return;
    Future.microtask(() async {
      try {
        await _executeFirestoreOperation(() async {
          if (Firebase.apps.isNotEmpty) {
            await _ensureFirebaseAuthForm();
            debugPrint('Attempting write to: $collection/$docId');
            await FirebaseFirestore.instance.collection(collection).doc(docId).set(data, SetOptions(merge: true));
            FirestoreCacheService().invalidateCache(collection, docId);
          }
        });
      } catch (e) {
        debugPrint('Firestore sync failed for $collection/$docId: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Firestore sync failed: $e')),
          );
        }
      }
    });
  }

  Future<void> _ensureFirebaseAuthForm() async {
    if (Firebase.apps.isEmpty) return;
    if (!kIsWeb && io.Platform.isWindows) return;
    await AuthService.ensureFirebasePersistence();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        debugPrint('FirebaseAuth sign-in failed (form): $e');
      }
    }
    debugPrint('FirebaseAuth UID (form): ${auth.currentUser?.uid ?? 'none'}');
  }

  Future<void> _forceSyncLocalTradingToFirestore() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final fileRows = await widget.db.customSelect(
        isSuperAdmin ? 'SELECT * FROM trading_file_entries' : 'SELECT * FROM trading_file_entries WHERE company_id = ?',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      final formRows = await widget.db.customSelect(
        isSuperAdmin ? 'SELECT * FROM trading_entries' : 'SELECT * FROM trading_entries WHERE company_id = ?',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();

      final firestore = FirebaseFirestore.instance;
      for (final r in fileRows) {
        final data = r.data;
        final id = data['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await firestore.collection('trading_file_entries').doc(id).set({
          ...data,
          'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      }
      for (final r in formRows) {
        final data = r.data;
        final id = data['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await firestore.collection('trading_entries').doc(id).set({
          ...data,
          'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Force sync trading failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Force sync trading failed: $e')),
        );
      }
    }
  }
  
  Future<void> _formAddEntryForType(_TradingFormType type, {BuildContext? dialogContext}) async {
    final formKey = type == _TradingFormType.buy ? _formBuyFormKey : _formSellFormKey;
    if (!formKey.currentState!.validate()) {
      setState(() {});
      return;
    }
    final option = type == _TradingFormType.buy ? _formBuySelection : _formSellSelection;
    final selectedDate = type == _TradingFormType.buy ? _formBuySelectedDate : _formSellSelectedDate;
    if (option == null || selectedDate == null) {
      setState(() {});
      return;
    }
    final quantityCtl = type == _TradingFormType.buy ? _formBuyQuantityCtl : _formSellQuantityCtl;
    final paymentCtl = type == _TradingFormType.buy ? _formBuyPaymentCtl : _formSellPaymentCtl;
    final mobileCtl = type == _TradingFormType.buy ? _formBuyMobileCtl : _formSellMobileCtl;
    final personNameCtl = type == _TradingFormType.buy ? _formBuyPersonNameCtl : _formSellPersonNameCtl;
    final buyerNameCtl = type == _TradingFormType.buy ? _formBuyBuyerNameCtl : _formSellBuyerNameCtl;
    final sellerNameCtl = type == _TradingFormType.buy ? _formBuySellerNameCtl : _formSellSellerNameCtl;
    final estateCtl = type == _TradingFormType.buy ? _formBuyEstateCtl : _formSellEstateCtl;
    final plotNoCtl = type == _TradingFormType.buy ? _formBuyPlotNoCtl : _formSellPlotNoCtl;
    final blockCtl = type == _TradingFormType.buy ? _formBuyBlockCtl : _formSellBlockCtl;
    final commissionCtl = type == _TradingFormType.buy ? _formBuyCommissionCtl : _formSellCommissionCtl;
    final commentsCtl = type == _TradingFormType.buy ? _formBuyCommentsCtl : _formSellCommentsCtl;
    final imagePaths = List<String>.from(type == _TradingFormType.buy ? _formBuyImages : _formSellImages);
    final quantity = int.tryParse(quantityCtl.text.trim()) ?? 0;
    final payment = double.tryParse(paymentCtl.text.trim()) ?? 0.0;
    final commission = double.tryParse(commissionCtl.text.trim()) ?? 0.0;
    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = _TradingClientEntry(
      id: entryId, type: type,
      buyOption: type == _TradingFormType.buy ? option : null,
      sellOption: type == _TradingFormType.sell ? option : null,
      date: selectedDate, mobile: mobileCtl.text.trim(),
      personName: personNameCtl.text.trim(), buyerName: buyerNameCtl.text.trim(),
      sellerName: sellerNameCtl.text.trim(), estateName: estateCtl.text.trim(),
      plotNo: plotNoCtl.text.trim(), block: blockCtl.text.trim(),
      commission: commission, quantity: quantity, payment: payment,
      status: 'Pending', comments: commentsCtl.text.trim(),
      isActive: true,
    );
    await _formSaveEntry(entry);
    final creator = creatorFields(_currentUser);
    final creatorAlias = creator['creator_user_id_alias']?.toString();
    _formSyncToFirestore(
      collection: 'trading_entries',
      docId: entryId,
      data: {
        'id': entryId, 'companyId': RoleUtils.getUserCompanyId(_currentUser),
        'createdBy': creatorAlias, 'created_by': creatorAlias, ...creator,
        'type': type == _TradingFormType.buy ? 'buy' : 'sell',
        'buyOption': entry.buyOption, 'sellOption': entry.sellOption,
        'date': selectedDate.toIso8601String(), 'mobile': mobileCtl.text.trim(),
        'personName': personNameCtl.text.trim(), 'buyerName': buyerNameCtl.text.trim(),
        'buyer_name': buyerNameCtl.text.trim(), 'sellerName': sellerNameCtl.text.trim(),
        'seller_name': sellerNameCtl.text.trim(), 'estateName': estateCtl.text.trim(),
        'plotNo': plotNoCtl.text.trim(), 'plot_no': plotNoCtl.text.trim(),
        'block': blockCtl.text.trim(), 'commission': commission,
        'quantity': quantity, 'payment': payment, 'status': 'Pending',
        'comments': commentsCtl.text.trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'imagePaths': imagePaths.isNotEmpty ? imagePaths : null,
      },
    );
    _loadFormEntries();
    _formResetForm(type);
    setState(() => _formSelectedFormType = null);
    final ctx = dialogContext ?? context;
    if (mounted && ctx.mounted) {
      Navigator.of(ctx).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == _TradingFormType.buy ? 'Buy' : 'Sell'} entry saved')),
      );
    }
  }
  
  Widget _formBuildTradeForm(_TradingFormType type, [StateSetter? dialogSetState]) {
    final isBuy = type == _TradingFormType.buy;
    final formKey = isBuy ? _formBuyFormKey : _formSellFormKey;
    final dateCtl = isBuy ? _formBuyDateCtl : _formSellDateCtl;
    final mobileCtl = isBuy ? _formBuyMobileCtl : _formSellMobileCtl;
    final personNameCtl = isBuy ? _formBuyPersonNameCtl : _formSellPersonNameCtl;
    final buyerNameCtl = isBuy ? _formBuyBuyerNameCtl : _formSellBuyerNameCtl;
    final sellerNameCtl = isBuy ? _formBuySellerNameCtl : _formSellSellerNameCtl;
    final estateCtl = isBuy ? _formBuyEstateCtl : _formSellEstateCtl;
    final plotNoCtl = isBuy ? _formBuyPlotNoCtl : _formSellPlotNoCtl;
    final blockCtl = isBuy ? _formBuyBlockCtl : _formSellBlockCtl;
    final commissionCtl = isBuy ? _formBuyCommissionCtl : _formSellCommissionCtl;
    final quantityCtl = isBuy ? _formBuyQuantityCtl : _formSellQuantityCtl;
    final paymentCtl = isBuy ? _formBuyPaymentCtl : _formSellPaymentCtl;
    final commentsCtl = isBuy ? _formBuyCommentsCtl : _formSellCommentsCtl;
    final selectedDate = isBuy ? _formBuySelectedDate : _formSellSelectedDate;
    final selection = isBuy ? _formBuySelection : _formSellSelection;
    final isDateLocked = isBuy ? _formBuyDateLocked : _formSellDateLocked;
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final columns = maxWidth > 1100 ? 3 : maxWidth > 720 ? 2 : 1;
          final double fieldWidth = columns == 1 ? maxWidth : (maxWidth - (16 * (columns - 1))) / columns;
          Widget fieldBox(Widget child, {int span = 1}) {
            if (columns == 1) return SizedBox(width: double.infinity, child: child);
            final effectiveSpan = span > columns ? columns : span;
            final width = (fieldWidth * effectiveSpan) + (16 * (effectiveSpan - 1));
            return SizedBox(width: width, child: child);
          }
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              fieldBox(_dropdownWithSelection(
                label: 'Payment Option', value: selection,
                emptyMessage: 'Please select Payment option', isRequired: true,
                onChanged: (value) {
                  if (dialogSetState != null) {
                    dialogSetState(() {
                      if (isBuy) _formBuySelection = value;
                      else _formSellSelection = value;
                    });
                  } else {
                    setState(() {
                      if (isBuy) _formBuySelection = value;
                      else _formSellSelection = value;
                    });
                  }
                  if (value != null) _formSetDateFromOption(type, value);
                },
                items: _tradeDropdownItems,
              )),
              fieldBox(TextFormField(
                controller: dateCtl,
                readOnly: true,
                enabled: !isDateLocked,
                decoration: _fieldDecoration('Date', isRequired: true).copyWith(
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: isDateLocked ? null : () => _formPickDate(type),
                validator: (_) => selectedDate == null ? 'Select a date' : null,
              )),
              fieldBox(TextFormField(
                controller: mobileCtl,
                decoration: _fieldDecoration('Mobile No.', isRequired: true),
                keyboardType: TextInputType.phone, maxLength: 11,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [mobileNoFormatter],
                validator: validateMobileNo,
              )),
              fieldBox(TextFormField(
                controller: personNameCtl,
                decoration: _fieldDecoration('Person Name', isRequired: true),
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter Person Name' : null,
              )),
              fieldBox(TextFormField(
                controller: buyerNameCtl,
                decoration: _fieldDecoration('Buyer Name'),
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              )),
              fieldBox(TextFormField(
                controller: sellerNameCtl,
                decoration: _fieldDecoration('Seller Name'),
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              )),
              fieldBox(TextFormField(
                controller: estateCtl,
                decoration: _fieldDecoration('Estate Name', isRequired: true),
                maxLength: 50,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [estateNameFormatter],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter Estate Name';
                  return validateEstateName(value);
                },
              )),
              fieldBox(TextFormField(
                controller: plotNoCtl,
                decoration: _fieldDecoration('Plot No.'),
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [plotNoFormatter],
                validator: validatePlotNo,
              )),
              fieldBox(TextFormField(
                controller: blockCtl,
                decoration: _fieldDecoration('Block'),
                maxLength: 50,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              )),
              fieldBox(TextFormField(
                controller: commissionCtl,
                decoration: _fieldDecoration('Commission'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [priceFormatter],
                validator: validatePrice,
              )),
              fieldBox(TextFormField(
                controller: quantityCtl,
                decoration: _fieldDecoration('Quantity', isRequired: true),
                keyboardType: TextInputType.number, maxLength: 50,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter quantity';
                  final validation = validateQuantity(value);
                  if (validation != null) return validation;
                  final qty = int.tryParse(value);
                  if (qty == null || qty <= 0) return 'Enter valid quantity';
                  return null;
                },
              )),
              fieldBox(TextFormField(
                controller: paymentCtl,
                decoration: _fieldDecoration('Price', isRequired: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [priceFormatter],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter price';
                  final validation = validatePrice(value);
                  if (validation != null) return validation;
                  final pay = double.tryParse(value);
                  if (pay == null || pay <= 0) return 'Enter valid price';
                  return null;
                },
              )),
              fieldBox(TextFormField(
                controller: commentsCtl,
                decoration: _fieldDecoration('Remarks'),
                maxLines: 3, maxLength: 200,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [commentFormatter],
                validator: validateComment,
              ), span: columns),
              fieldBox(ImageUploadWidget(
                imagePaths: isBuy ? _formBuyImages : _formSellImages,
                onImagesChanged: (images) {
                  if (dialogSetState != null) {
                    dialogSetState(() {
                      if (isBuy) _formBuyImages = images;
                      else _formSellImages = images;
                    });
                  } else {
                    setState(() {
                      if (isBuy) _formBuyImages = images;
                      else _formSellImages = images;
                    });
                  }
                },
                maxImages: 3,
              ), span: columns),
              fieldBox(Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _formResetForm(type);
                      setState(() => _formSelectedFormType = null);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: Icon(isBuy ? Icons.shopping_cart : Icons.work),
                    label: Text(isBuy ? 'Save Buy' : 'Save Sell'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isBuy ? const Color(0xFFFF6B35) : const Color(0xFF4A90E2),
                    ),
                    onPressed: () => _formAddEntryForType(type, dialogContext: context),
                  ),
                ],
              ), span: columns),
            ],
          );
        },
      ),
    );
  }
  
  void _formShowAddFormDialog(_TradingFormType type) {
    setState(() => _formSelectedFormType = type);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _formResetForm(type);
            setState(() => _formSelectedFormType = null);
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == _TradingFormType.buy ? 'Buy Entry' : 'Sell Entry',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 24),
                                _formBuildTradeForm(type, setDialogState),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _formResetForm(type);
                          setState(() => _formSelectedFormType = null);
                          Navigator.of(context).pop();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          elevation: 2,
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
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Hardcode isSuperAdmin to always allow access
    final isSuperAdmin = true;
    
    final isLoading = (_selectedTab == 'File' ? (_fileLoading || !_fileFirestoreReady) : (_formLoading || !_formFirestoreReady));
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Trading', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35), // Orange
                const Color(0xFF4A90E2), // Blue
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (q) {
              setState(() {
                _q = q;
                // Reset pagination for current tab on search
                _tabPages[_selectedTab] = 0;
              });
            }),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'File'),
            Tab(text: 'Form'),
          ],
          onTap: (index) {
            setState(() {
              _selectedTab = index == 0 ? 'File' : 'Form';
              _tabPages[_selectedTab] = 0;
            });
            _loadedTabs.add(index);
          },
        ),
      ),
      floatingActionButton: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  onPressed: () {
                    if (_selectedTab == 'File') {
                      _fileShowAddFormDialog(_TradingFileFormType.buy);
                    } else {
                      _formShowAddFormDialog(_TradingFormType.buy);
                    }
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFFF6B35), // Orange from gradient
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  onPressed: () {
                    if (_selectedTab == 'File') {
                      _fileShowAddFormDialog(_TradingFileFormType.sell);
                    } else {
                      _formShowAddFormDialog(_TradingFormType.sell);
                    }
                  },
                  icon: const Icon(Icons.work),
                  label: const Text('Sell', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFF4A90E2), // Blue from gradient
                ),
              ],
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
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filter Dropdowns Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: Row(
                        children: [
                          // Date Range Filter Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dateRangeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Date Range',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Today', child: Text('Today')),
                                DropdownMenuItem(value: 'Tomorrow', child: Text('Tomorrow')),
                                DropdownMenuItem(value: 'After Tomorrow', child: Text('After Tomorrow')),
                                DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                                DropdownMenuItem(value: 'Next Week', child: Text('Next Week')),
                                DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                                DropdownMenuItem(value: 'Next Month', child: Text('Next Month')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _dateRangeFilter = value;
                                    _tabPages[_selectedTab] = 0;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Transaction Type Filter Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _transactionTypeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Transaction Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_horiz),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Buy', child: Text('Buy')),
                                DropdownMenuItem(value: 'Sell', child: Text('Sell')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _transactionTypeFilter = value;
                                    _tabPages[_selectedTab] = 0;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab content with IndexedStack
                    Expanded(
                      child: IndexedStack(
                        index: _tabController.index,
                        children: [
                          // File tab
                          _buildTabContent('File'),
                          // Form tab
                          _buildTabContent('Form'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Sync indicator - show only when syncing
            if (false) // No sync state in main TradingPage, so always false
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
  
  Widget _buildTabContent(String tabType) {
    // Only build content if tab has been loaded (lazy loading)
    if (!_loadedTabs.contains(tabType == 'File' ? 0 : 1)) {
      return const SizedBox.shrink();
    }
    
    final allFiltered = _getFilteredEntriesForTab(tabType);
    final paginatedEntries = _getPaginatedEntriesForTab(tabType);
    final scrollController = _tabScrollControllers[tabType];
    
    // Apply search filter
    final q = _q.toLowerCase();
    final searchFiltered = q.isEmpty
        ? paginatedEntries
        : paginatedEntries.where((entry) {
            bool contains(String? v) => v != null && v.toLowerCase().contains(q);
            if (tabType == 'File') {
              final fileEntry = entry as _TradingFileEntry;
              final dateStr = DateFormat('dd MMM yyyy').format(fileEntry.date).toLowerCase();
              return contains(fileEntry.buyOption) ||
                  contains(fileEntry.sellOption) ||
                  contains(fileEntry.mobile) ||
                  contains(fileEntry.personName) ||
                  contains(fileEntry.estate) ||
                  contains(fileEntry.comments) ||
                  contains(fileEntry.status) ||
                  dateStr.contains(q) ||
                  fileEntry.quantity.toString().contains(q) ||
                  fileEntry.payment.toString().contains(q);
            } else {
              final formEntry = entry as _TradingClientEntry;
              final dateStr = DateFormat('dd MMM yyyy').format(formEntry.date).toLowerCase();
              return contains(formEntry.buyOption) ||
                  contains(formEntry.sellOption) ||
                  contains(formEntry.mobile) ||
                  contains(formEntry.personName) ||
                  contains(formEntry.estateName) ||
                  contains(formEntry.comments) ||
                  contains(formEntry.status) ||
                  dateStr.contains(q) ||
                  formEntry.quantity.toString().contains(q) ||
                  formEntry.payment.toString().contains(q);
            }
          }).toList();
    
    if (allFiltered.isEmpty) {
      return Center(
        child: Text('No Trading Records Found'),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final summaryRowHeight = isMobile ? 70.0 : 65.0;
        const fabPadding = 88.0;
        final listBottomPadding = summaryRowHeight + fabPadding + MediaQuery.of(context).padding.bottom + 24;
        
        return Stack(
          children: [
            ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: isMobile ? 8 : 12,
                right: isMobile ? 8 : 12,
                bottom: listBottomPadding, // Extra space for summary + FAB row
              ),
              itemCount: searchFiltered.length + (_hasMoreEntriesForTab(tabType) ? 1 : 0),
              itemBuilder: (ctx, i) {
        if (i == searchFiltered.length) {
          // Show shimmer effect while loading more
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ShimmerListPlaceholder(itemCount: 3, itemHeight: 100),
          );
        }
        final entry = searchFiltered[i];
        // Build card for entry
        if (tabType == 'File') {
          final fileEntry = entry as _TradingFileEntry;
          return LayoutBuilder(
            builder: (context, cardConstraints) {
              final isMobileCard = cardConstraints.maxWidth < 600;
              return Card(
                margin: EdgeInsets.only(bottom: isMobileCard ? 8 : 12),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TradingDetailPage(
                          entry: fileEntry,
                          tabType: 'File',
                          db: widget.db,
                          currentUser: _currentUser,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.all(isMobileCard ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                fileEntry.personName.isNotEmpty ? fileEntry.personName : 'N/A',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobileCard ? 14 : 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: fileEntry.type == _TradingFileFormType.buy 
                              ? Colors.green.shade100 
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: fileEntry.type == _TradingFileFormType.buy 
                                ? Colors.green.shade300 
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Text(
                          fileEntry.type == _TradingFileFormType.buy ? 'Buy' : 'Sell',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: fileEntry.type == _TradingFileFormType.buy 
                                ? Colors.green.shade700 
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobileCard ? 8 : 12),
                  isMobileCard
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow('Date', DateFormat('dd MMM yyyy').format(fileEntry.date), isMobileCard),
                                      const SizedBox(height: 8),
                                      _buildInfoRow('Mobile', fileEntry.mobile.isNotEmpty ? fileEntry.mobile : 'N/A', isMobileCard),
                                      const SizedBox(height: 8),
                                      _buildInfoRow('Payment', 'Rs ${NumberFormat('#,##0').format(fileEntry.payment.toInt())}', isMobileCard, isBold: true),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Date',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(fileEntry.date),
                                              style: GoogleFonts.poppins(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Mobile',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              fileEntry.mobile.isNotEmpty ? fileEntry.mobile : 'N/A',
                                              style: GoogleFonts.poppins(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Payment',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Rs ${NumberFormat('#,##0').format(fileEntry.payment.toInt())}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFFF6B35),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                  if (fileEntry.estate.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Estate: ${fileEntry.estate}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                  if (fileEntry.comments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Comments: ${fileEntry.comments}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity: ${fileEntry.quantity}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: fileEntry.status == 'Done' 
                              ? Colors.green.shade100 
                              : fileEntry.status == 'Close' 
                                  ? Colors.orange.shade100 
                                  : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: fileEntry.status == 'Done' 
                                ? Colors.green.shade300 
                                : fileEntry.status == 'Close' 
                                    ? Colors.orange.shade300 
                                    : Colors.blue.shade300,
                          ),
                        ),
                        child: Text(
                          fileEntry.status,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: fileEntry.status == 'Done' 
                                ? Colors.green.shade700 
                                : fileEntry.status == 'Close' 
                                    ? Colors.orange.shade700 
                                    : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
            );
          },
          );
        } else {
          final formEntry = entry as _TradingClientEntry;
          return LayoutBuilder(
            builder: (context, cardConstraints) {
              final isMobileCard = cardConstraints.maxWidth < 600;
              return Card(
                margin: EdgeInsets.only(bottom: isMobileCard ? 8 : 12),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TradingDetailPage(
                          entry: formEntry,
                          tabType: 'Form',
                          db: widget.db,
                          currentUser: _currentUser,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.all(isMobileCard ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                formEntry.personName.isNotEmpty ? formEntry.personName : 'N/A',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobileCard ? 14 : 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: isMobileCard ? 8 : 12, vertical: isMobileCard ? 4 : 6),
                              decoration: BoxDecoration(
                                color: formEntry.type == _TradingFormType.buy 
                                    ? Colors.green.shade100 
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: formEntry.type == _TradingFormType.buy 
                                      ? Colors.green.shade300 
                                      : Colors.orange.shade300,
                                ),
                              ),
                              child: Text(
                                formEntry.type == _TradingFormType.buy ? 'Buy' : 'Sell',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobileCard ? 10 : 12,
                                  color: formEntry.type == _TradingFormType.buy 
                                      ? Colors.green.shade700 
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                  SizedBox(height: isMobileCard ? 8 : 12),
                  isMobileCard
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Date', DateFormat('dd MMM yyyy').format(formEntry.date), isMobileCard),
                            const SizedBox(height: 8),
                            _buildInfoRow('Mobile', formEntry.mobile.isNotEmpty ? formEntry.mobile : 'N/A', isMobileCard),
                            const SizedBox(height: 8),
                            _buildInfoRow('Payment', 'Rs ${NumberFormat('#,##0').format(formEntry.payment.toInt())}', isMobileCard, isBold: true),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(formEntry.date),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mobile',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formEntry.mobile.isNotEmpty ? formEntry.mobile : 'N/A',
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs ${NumberFormat('#,##0').format(formEntry.payment.toInt())}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFF6B35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  if (formEntry.estateName.isNotEmpty) ...[
                    SizedBox(height: isMobileCard ? 8 : 12),
                    Text(
                      'Estate: ${formEntry.estateName}',
                      style: GoogleFonts.poppins(fontSize: isMobileCard ? 12 : 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (formEntry.comments.isNotEmpty) ...[
                    SizedBox(height: isMobileCard ? 6 : 8),
                    Text(
                      'Comments: ${formEntry.comments}',
                      style: GoogleFonts.poppins(
                        fontSize: isMobileCard ? 11 : 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: isMobileCard ? 8 : 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity: ${formEntry.quantity}',
                        style: GoogleFonts.poppins(fontSize: isMobileCard ? 12 : 14),
                      ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobileCard ? 8 : 12, vertical: isMobileCard ? 4 : 6),
                          decoration: BoxDecoration(
                            color: formEntry.status == 'Done' 
                                ? Colors.green.shade100 
                                : formEntry.status == 'Close' 
                                    ? Colors.orange.shade100 
                                    : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: formEntry.status == 'Done' 
                                  ? Colors.green.shade300 
                                  : formEntry.status == 'Close' 
                                      ? Colors.orange.shade300 
                                      : Colors.blue.shade300,
                            ),
                          ),
                          child: Text(
                            formEntry.status,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: isMobileCard ? 10 : 12,
                              color: formEntry.status == 'Done' 
                                  ? Colors.green.shade700 
                                  : formEntry.status == 'Close' 
                                      ? Colors.orange.shade700 
                                      : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          },
          );
        }
      },
    ),
            // Sticky summary row at bottom - responsive positioning
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: fabPadding),
                  child: _buildSummaryRow(tabType, _transactionTypeFilter),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Helper method to calculate totals for summary
  Map<String, dynamic> _calculateSummaryForTab(String tabType) {
    final allFiltered = _getFilteredEntriesForTab(tabType);
    int totalQuantity = 0;
    double totalPayment = 0.0;
    
    for (final entry in allFiltered) {
      if (tabType == 'File') {
        final fileEntry = entry as _TradingFileEntry;
        // Filter by transaction type if needed
        if (_transactionTypeFilter == 'Buy' && fileEntry.type != _TradingFileFormType.buy) continue;
        if (_transactionTypeFilter == 'Sell' && fileEntry.type != _TradingFileFormType.sell) continue;
        totalQuantity += fileEntry.quantity;
        totalPayment += fileEntry.payment;
      } else {
        final formEntry = entry as _TradingClientEntry;
        // Filter by transaction type if needed
        if (_transactionTypeFilter == 'Buy' && formEntry.type != _TradingFormType.buy) continue;
        if (_transactionTypeFilter == 'Sell' && formEntry.type != _TradingFormType.sell) continue;
        totalQuantity += formEntry.quantity;
        totalPayment += formEntry.payment;
      }
    }
    
    return {
      'totalQuantity': totalQuantity,
      'totalPayment': totalPayment,
    };
  }

  // Helper method to build info rows for mobile cards
  Widget _buildInfoRow(String label, String value, bool isMobile, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 11 : 12,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 12 : 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: isBold ? const Color(0xFFFF6B35) : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ],
    );
  }
  
  // Build sticky summary row with responsive design
  Widget _buildSummaryRow(String tabType, String transactionTypeFilter) {
    final summary = _calculateSummaryForTab(tabType);
    final formatPayment = (double amount) => NumberFormat('#,##0').format(amount.toInt());
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Quantity',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${summary['totalQuantity']}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              transactionTypeFilter == 'Buy' 
                                  ? 'Total Purchases'
                                  : transactionTypeFilter == 'Sell'
                                      ? 'Total Sales'
                                      : 'Total Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs ${formatPayment((summary['totalPayment'] ?? 0).toDouble())}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Quantity',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${summary['totalQuantity']}',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              transactionTypeFilter == 'Buy' 
                                  ? 'Total Purchases'
                                  : transactionTypeFilter == 'Sell'
                                      ? 'Total Sales'
                                      : 'Total Payment',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs ${formatPayment((summary['totalPayment'] ?? 0).toDouble())}',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// Trading Detail Page
class TradingDetailPage extends StatelessWidget {
  final dynamic entry; // Can be _TradingFileEntry or _TradingClientEntry
  final String tabType; // 'File' or 'Form'
  final AppDatabase db;
  final Map<String, dynamic>? currentUser;

  const TradingDetailPage({
    super.key,
    required this.entry,
    required this.tabType,
    required this.db,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isFileEntry = tabType == 'File';
    final formatPayment = (double amount) => NumberFormat('#,##0').format(amount.toInt());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trading Details',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35), // Orange
                const Color(0xFF4A90E2), // Blue
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _generateProfessionalReceipt(context),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: const Text(
              'Generate Professional Receipt',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Type Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction Details',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isFileEntry 
                              ? (entry as _TradingFileEntry).type == _TradingFileFormType.buy
                              : (entry as _TradingClientEntry).type == _TradingFormType.buy)
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isFileEntry
                                ? (entry as _TradingFileEntry).type == _TradingFileFormType.buy
                                : (entry as _TradingClientEntry).type == _TradingFormType.buy)
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Text(
                          isFileEntry
                              ? (entry as _TradingFileEntry).type == _TradingFileFormType.buy ? 'Buy' : 'Sell'
                              : (entry as _TradingClientEntry).type == _TradingFormType.buy ? 'Buy' : 'Sell',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: (isFileEntry
                                ? (entry as _TradingFileEntry).type == _TradingFileFormType.buy
                                : (entry as _TradingClientEntry).type == _TradingFormType.buy)
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Details Table
                  _buildDetailTable(isFileEntry, formatPayment),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTable(bool isFileEntry, String Function(double) formatPayment) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        if (isFileEntry) {
          final fileEntry = entry as _TradingFileEntry;
          
          if (isMobile) {
            // Use vertical card layout for mobile
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableRow(context, 'Date', DateFormat('dd MMM yyyy').format(fileEntry.date), isMobile),
                _buildTableRow(context, 'Payment Option', fileEntry.buyOption ?? fileEntry.sellOption ?? 'N/A', isMobile),
                _buildTableRow(context, 'Mobile No.', fileEntry.mobile, isMobile),
                _buildTableRow(context, 'Person Name', fileEntry.personName.isNotEmpty ? fileEntry.personName : 'N/A', isMobile),
                _buildTableRow(context, 'Estate Name', fileEntry.estate, isMobile),
                _buildTableRow(context, 'Quantity', fileEntry.quantity.toString(), isMobile),
                _buildTableRow(context, 'Payment', 'Rs ${formatPayment(fileEntry.payment)}', isMobile),
                _buildTableRow(context, 'Status', fileEntry.status, isMobile),
                _buildTableRow(context, 'Comments', fileEntry.comments.isNotEmpty ? fileEntry.comments : 'N/A', isMobile),
              ],
            );
          }
          
          // Desktop: table layout
          return Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
            },
            children: [
              _buildTableRow(context, 'Date', DateFormat('dd MMM yyyy').format(fileEntry.date), isMobile) as TableRow,
              _buildTableRow(context, 'Payment Option', fileEntry.buyOption ?? fileEntry.sellOption ?? 'N/A', isMobile) as TableRow,
              _buildTableRow(context, 'Mobile No.', fileEntry.mobile, isMobile) as TableRow,
              _buildTableRow(context, 'Person Name', fileEntry.personName.isNotEmpty ? fileEntry.personName : 'N/A', isMobile) as TableRow,
              _buildTableRow(context, 'Estate Name', fileEntry.estate, isMobile) as TableRow,
              _buildTableRow(context, 'Quantity', fileEntry.quantity.toString(), isMobile) as TableRow,
              _buildTableRow(context, 'Payment', 'Rs ${formatPayment(fileEntry.payment)}', isMobile) as TableRow,
              _buildTableRow(context, 'Status', fileEntry.status, isMobile) as TableRow,
              _buildTableRow(context, 'Comments', fileEntry.comments.isNotEmpty ? fileEntry.comments : 'N/A', isMobile) as TableRow,
            ],
          );
        } else {
          final formEntry = entry as _TradingClientEntry;
          
          if (isMobile) {
            // Use vertical card layout for mobile
            final mobileRows = <Widget>[
              _buildTableRow(context, 'Date', DateFormat('dd MMM yyyy').format(formEntry.date), isMobile),
              _buildTableRow(context, 'Payment Option', formEntry.buyOption ?? formEntry.sellOption ?? 'N/A', isMobile),
              _buildTableRow(context, 'Mobile No.', formEntry.mobile, isMobile),
              _buildTableRow(context, 'Person Name', formEntry.personName.isNotEmpty ? formEntry.personName : 'N/A', isMobile),
              _buildTableRow(context, 'Buyer Name', formEntry.buyerName.isNotEmpty ? formEntry.buyerName : 'N/A', isMobile),
              _buildTableRow(context, 'Seller Name', formEntry.sellerName.isNotEmpty ? formEntry.sellerName : 'N/A', isMobile),
              _buildTableRow(context, 'Estate Name', formEntry.estateName, isMobile),
              if (formEntry.plotNo.isNotEmpty) _buildTableRow(context, 'Plot No.', formEntry.plotNo, isMobile),
              if (formEntry.block.isNotEmpty) _buildTableRow(context, 'Block', formEntry.block, isMobile),
              _buildTableRow(context, 'Quantity', formEntry.quantity.toString(), isMobile),
              _buildTableRow(context, 'Payment', 'Rs ${formatPayment(formEntry.payment)}', isMobile),
              if (formEntry.commission > 0) _buildTableRow(context, 'Commission', 'Rs ${formatPayment(formEntry.commission)}', isMobile),
              _buildTableRow(context, 'Status', formEntry.status, isMobile),
              _buildTableRow(context, 'Comments', formEntry.comments.isNotEmpty ? formEntry.comments : 'N/A', isMobile),
            ];
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: mobileRows,
            );
          }
          
          // Desktop: table layout
          final tableRows = <TableRow>[
            _buildTableRow(context, 'Date', DateFormat('dd MMM yyyy').format(formEntry.date), isMobile) as TableRow,
            _buildTableRow(context, 'Payment Option', formEntry.buyOption ?? formEntry.sellOption ?? 'N/A', isMobile) as TableRow,
            _buildTableRow(context, 'Mobile No.', formEntry.mobile, isMobile) as TableRow,
            _buildTableRow(context, 'Person Name', formEntry.personName.isNotEmpty ? formEntry.personName : 'N/A', isMobile) as TableRow,
            _buildTableRow(context, 'Buyer Name', formEntry.buyerName.isNotEmpty ? formEntry.buyerName : 'N/A', isMobile) as TableRow,
            _buildTableRow(context, 'Seller Name', formEntry.sellerName.isNotEmpty ? formEntry.sellerName : 'N/A', isMobile) as TableRow,
            _buildTableRow(context, 'Estate Name', formEntry.estateName, isMobile) as TableRow,
            if (formEntry.plotNo.isNotEmpty) _buildTableRow(context, 'Plot No.', formEntry.plotNo, isMobile) as TableRow,
            if (formEntry.block.isNotEmpty) _buildTableRow(context, 'Block', formEntry.block, isMobile) as TableRow,
            _buildTableRow(context, 'Quantity', formEntry.quantity.toString(), isMobile) as TableRow,
            _buildTableRow(context, 'Payment', 'Rs ${formatPayment(formEntry.payment)}', isMobile) as TableRow,
            if (formEntry.commission > 0) _buildTableRow(context, 'Commission', 'Rs ${formatPayment(formEntry.commission)}', isMobile) as TableRow,
            _buildTableRow(context, 'Status', formEntry.status, isMobile) as TableRow,
            _buildTableRow(context, 'Comments', formEntry.comments.isNotEmpty ? formEntry.comments : 'N/A', isMobile) as TableRow,
          ];
          
          return Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
            },
            children: tableRows,
          );
        }
      },
    );
  }
  
  dynamic _buildTableRow(BuildContext context, String label, String value, bool isMobile) {
    final isPhone = label.toLowerCase().contains('mobile') || label.toLowerCase().contains('contact');
    if (isMobile) {
      // Mobile: vertical card layout
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isPhone && value.trim().isNotEmpty
                    ? () => showPhoneActionSheet(context, value)
                    : null,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isPhone ? Colors.blue.shade700 : Colors.grey.shade900,
                    decoration: isPhone ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Desktop: table row
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: GestureDetector(
            onTap: isPhone && value.trim().isNotEmpty
                ? () => showPhoneActionSheet(context, value)
                : null,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isPhone ? Colors.blue.shade700 : null,
                decoration: isPhone ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final entryMap = _buildEntryMap();
      final bytes = await buildTradingDealSummaryPdf(
        format: PdfPageFormat.a4,
        db: db,
        currentUser: currentUser,
        entry: entryMap,
        action: 'download',
      );
      
      // Use platform-specific PDF handling
      if (kIsWeb || (!kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS))) {
        // For Web, Android, and iOS, use Printing.layoutPdf which opens native save/print dialog
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt ready for download/print')),
          );
        }
      } else {
        // For desktop (Windows, macOS, Linux), save directly to disk
        await savePdfBytesToDisk(
          pdfBytes: bytes,
          suggestedBaseName: 'trading_${entryMap['id']}_${fmtTs(DateTime.now())}',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF downloaded successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e')),
        );
      }
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final serial = generateReportSerial(prefix: 'TD');
      final generatedAt = DateTime.now();
      final entryMap = _buildEntryMap();

      await logReportHistory(
        db: db,
        currentUser: currentUser,
        companyId: RoleUtils.getUserCompanyId(currentUser),
        module: 'trading',
        entityId: entryMap['id'] as String,
        reportType: 'Trading Detail',
        action: 'print',
        serialNumber: serial,
        generatedAt: generatedAt,
      );

      await Printing.layoutPdf(
        onLayout: (_) async {
          return buildTradingDealSummaryPdf(
            format: PdfPageFormat.a4,
            db: db,
            currentUser: currentUser,
            entry: entryMap,
            action: 'print',
            serialNumber: serial,
            generatedAt: generatedAt,
            logHistory: false,
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing: $e')),
        );
      }
    }
  }

  Future<void> _generateProfessionalReceipt(BuildContext context) async {
    final entryMap = _buildEntryMap();
    final dealType = (entryMap['type']?.toString() ?? '').toLowerCase() == 'buy' ? 'Buy' : 'Sell';
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Deal ID', entryMap['id']?.toString() ?? 'N/A'),
      MapEntry('Deal Type', dealType),
      MapEntry('Option', (entryMap['buy_option'] ?? entryMap['sell_option'] ?? 'N/A').toString()),
      MapEntry('Date', entryMap['date']?.toString() ?? 'N/A'),
      MapEntry('Contact', entryMap['mobile']?.toString() ?? 'N/A'),
      MapEntry('Person', entryMap['person_name']?.toString() ?? 'N/A'),
      MapEntry('Buyer', entryMap['buyer_name']?.toString() ?? (entryMap['person_name']?.toString() ?? 'N/A')),
      MapEntry('Seller', entryMap['seller_name']?.toString() ?? 'N/A'),
      MapEntry('Estate', entryMap['estate_name']?.toString() ?? 'N/A'),
      MapEntry('Status', entryMap['status']?.toString() ?? 'N/A'),
      if (entryMap['commission'] != null) MapEntry('Commission', entryMap['commission'].toString()),
      if (entryMap['comments'] != null && entryMap['comments'].toString().isNotEmpty) MapEntry('Remarks', entryMap['comments'].toString()),
    ];

    final gridRows = <Map<String, String>>[
      {
        'Plot/Block': (entryMap['plot_no'] ?? entryMap['block'] ?? entryMap['estate_name'] ?? '-').toString(),
        'Quantity': (entryMap['quantity'] ?? '-').toString(),
        'Payment': entryMap['payment'] != null ? 'Rs ${entryMap['payment']}' : 'N/A',
        'Status': entryMap['status']?.toString() ?? 'N/A',
      },
    ];

    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: db,
      module: 'Trading',
      title: 'Trading Receipt',
      entityId: entryMap['id']?.toString(),
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }

  Map<String, dynamic> _buildEntryMap() {
    final isFileEntry = tabType == 'File';
    if (isFileEntry) {
      final fileEntry = entry as _TradingFileEntry;
      return {
        'id': fileEntry.id,
        'type': fileEntry.type == _TradingFileFormType.buy ? 'buy' : 'sell',
        'buy_option': fileEntry.buyOption,
        'sell_option': fileEntry.sellOption,
        'date': DateFormat('dd MMM yyyy').format(fileEntry.date),
        'mobile': fileEntry.mobile,
        'person_name': fileEntry.personName,
        'estate_name': fileEntry.estate,
        'quantity': fileEntry.quantity,
        'payment': fileEntry.payment,
        'status': fileEntry.status,
        'comments': fileEntry.comments,
      };
    } else {
      final formEntry = entry as _TradingClientEntry;
      return {
        'id': formEntry.id,
        'type': formEntry.type == _TradingFormType.buy ? 'buy' : 'sell',
        'buy_option': formEntry.buyOption,
        'sell_option': formEntry.sellOption,
        'date': DateFormat('dd MMM yyyy').format(formEntry.date),
        'mobile': formEntry.mobile,
        'person_name': formEntry.personName,
        'buyer_name': formEntry.buyerName,
        'seller_name': formEntry.sellerName,
        'estate_name': formEntry.estateName,
        'plot_no': formEntry.plotNo,
        'block': formEntry.block,
        'quantity': formEntry.quantity,
        'payment': formEntry.payment,
        'status': formEntry.status,
        'commission': formEntry.commission,
        'comments': formEntry.comments,
      };
    }
  }
}



