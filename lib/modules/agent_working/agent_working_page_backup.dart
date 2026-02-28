import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
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
import '../../core/services/firestore_cache_service.dart';
import '../../firestore_sync_service.dart';
import '../../image_cache_service.dart';
import '../../responsive_widgets.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../core/shared_utils.dart' show TopRightSearch, buildResponsiveInfoRow, InfoEntry, showCustomTimePicker;
import '../../presentation/agent_working/agent_working_page_clean.dart' as clean_arch;

class AgentWorkingPage extends StatefulWidget {
  final AppDatabase db;
  
  const AgentWorkingPage({super.key, required this.db});
  
  @override
  State<AgentWorkingPage> createState() => _AgentWorkingPageState();

  Widget build(BuildContext context) {
    return clean_arch.AgentWorkingPageClean(db: db);
  }
}

class _WorkNote {
  final String id;
  final String text;
  final DateTime createdAt;
  const _WorkNote({required this.id, required this.text, required this.createdAt});
}

class _AgentWorkingPageState extends State<AgentWorkingPage> {
  final _transferFormKey = GlobalKey<FormState>();
  final _clientRequirementFormKey = GlobalKey<FormState>();
  final _officeNotesFormKey = GlobalKey<FormState>();
  final _otherNotesFormKey = GlobalKey<FormState>();
  final TextEditingController _dateCtl = TextEditingController();
  final TextEditingController _plotCtl = TextEditingController();
  final TextEditingController _clientNameCtl = TextEditingController();
  final TextEditingController _clientMobileCtl = TextEditingController();
  final TextEditingController _timeCtl = TextEditingController();
  final TextEditingController _registryCtl = TextEditingController();
  final TextEditingController _commentsCtl = TextEditingController();
  final TextEditingController _reqDateCtl = TextEditingController();
  final TextEditingController _reqPlotCtl = TextEditingController();
  final TextEditingController _reqClientNameCtl = TextEditingController();
  final TextEditingController _reqClientMobileCtl = TextEditingController();
  final TextEditingController _reqTimeCtl = TextEditingController();
  final TextEditingController _reqRegistryCtl = TextEditingController();
  final TextEditingController _reqCommentsCtl = TextEditingController();
  final TextEditingController _officeNotesCtl = TextEditingController();
  final TextEditingController _otherNotesCtl = TextEditingController();
  final TextEditingController _nextWorkingDateCtl = TextEditingController();
  final TextEditingController _reqNextWorkingDateCtl = TextEditingController();
  final TextEditingController _transferOtherCategoryCtl = TextEditingController();
  final TextEditingController _transferOtherSizeCtl = TextEditingController();
  String? _transferCategory;
  String? _transferSize; // Size field for plot sizes (2 Marla, 3 Marla, 5 Marla, 8 Marla, Other)
  String? _requirementCategory;
  String? _requirementSource;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _reqSelectedDate;
  TimeOfDay? _reqSelectedTime;
  DateTime? _nextWorkingDate;
  DateTime? _reqNextWorkingDate;
  final List<_WorkNote> _officeNotes = [];
  final List<_WorkNote> _otherNotes = [];
  CollectionReference? _officeNotesRef;
  CollectionReference? _otherNotesRef;
  StreamSubscription<QuerySnapshot>? _officeNotesSub;
  StreamSubscription<QuerySnapshot>? _otherNotesSub;
  bool _officeNotesLoading = true;
  bool _otherNotesLoading = true;
  String? _officeNotesError;
  String? _otherNotesError;
  List<Map<String, dynamic>> _savedEntries = [];
  bool _loadingEntries = false;
  String _selectedType = 'Transfer'; // 'Transfer' or 'Client Requirements'
  String _q = ''; // Search query
  List<String> _transferImages = [];
  List<String> _clientRequirementImages = []; // Reset images
  Map<String, dynamic>? _currentUser; // Current logged-in user for permission checks
  
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

  Future<void> _syncCompaniesFromFirestore() async {
    debugPrint('STRIKE 1: Entering sync function');
    debugPrint('STRIKE 2: Firebase apps count: ${Firebase.apps.length}');
    debugPrint('DB PATH (companies sync): ${widget.db.executor}');
    if (Firebase.apps.isEmpty) {
      debugPrint('STRIKE 3: Firebase is NOT initialized!');
      return;
    }
    try {
      debugPrint('DEBUG: syncCompaniesFromFirestore started...');
      final firestore = FirebaseFirestore.instance;
      final snap = await firestore.collection('companies').get();
      debugPrint('Firestore docs found: ${snap.docs.length}');
      if (snap.docs.isEmpty) {
        final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
        if (isSuper) {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          final cid = RoleUtils.getUserCompanyId(_currentUser) ?? 'default_company';
          final cname = (_currentUser?['company_name'] ?? _currentUser?['companyName'] ?? 'Default Company').toString();
          final tier = (_currentUser?['subscription_tier'] ?? _currentUser?['subscriptionTier'] ?? 'Starter').toString();
          final status = (_currentUser?['status'] ?? 'active').toString();
          try {
            debugPrint('No companies found; creating default company $cid');
            await firestore.collection('companies').doc(cid).set({
              'id': cid,
              'name': cname,
              'status': status,
              'subscription_tier': tier,
              'max_user_limit': _currentUser?['max_user_limit'] ?? 5,
              'created_at': nowIso,
              'updated_at': nowIso,
            }, SetOptions(merge: true));
          } on FirebaseException catch (e) {
            debugPrint('Failed to auto-create default company: $e');
          }
        }
        return;
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await widget.db.batch((batch) {
        for (final doc in snap.docs) {
          debugPrint('Attempting to sync company ID: ${doc.id}');
          final data = doc.data();
          debugPrint('Writing to SQLite: ${doc.id} - ${data['name']}');
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

          try {
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
          } catch (e) {
            debugPrint('SQLite Insert Error for $id: $e');
          }
        }
      });
      try {
        final countRes = await widget.db.customSelect('SELECT COUNT(*) AS c FROM companies').getSingle();
        debugPrint('SQLite companies row count: ${countRes.data['c']}');
      } catch (e) {
        debugPrint('SQLite count error: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Companies Firestore sync (users page) failed: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initNoteStreams();
    Future.microtask(() async {
      await _loadCurrentUser();
      await _backfillLocalCompanyIds();
      await _ensureFirebaseAuth();
      await _cleanupNumericUserDocsOnce();
      await _loadSavedEntries();
      await _forceSyncLocalUsersToFirestore();
      _checkAndShowNotifications();
    });
  }

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

  /// Background sync to Firestore (non-blocking, doesn't delay UI)
  void _syncToFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    if (!kIsWeb && io.Platform.isWindows) return;
    // RootIsolateToken check removed - not available in this Flutter version
    // Run in background without blocking
    Future.microtask(() async {
      try {
        if (Firebase.apps.isNotEmpty) {
          await _ensureFirebaseAuth();
          debugPrint('Attempting write to: $collection/$docId');
          final firestore = FirebaseFirestore.instance;
          await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));
          // Invalidate cache after successful sync
          FirestoreCacheService().invalidateCache(collection, docId);
        }
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

  Future<void> _forceSyncLocalUsersToFirestore() async {
    if (Firebase.apps.isEmpty) return;
    await _ensureFirebaseAuth();
    final uid = AuthService.currentUser?['uid'] ??
        AuthService.currentUser?['user_uid'] ??
        AuthService.currentUser?['userId'] ??
        AuthService.currentUser?['user_id'] ??
        _currentUser?['uid'] ??
        _currentUser?['id'];
    if (uid == null || uid.toString().isEmpty) {
      debugPrint('Force sync users skipped: no Firebase UID');
      return;
    }
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (companyId == null || companyId.toString().isEmpty) {
      debugPrint('Force sync users skipped: missing companyId');
      return;
    }
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final users = await widget.db.customSelect(
        isSuperAdmin ? 'SELECT * FROM users' : 'SELECT * FROM users WHERE company_id = ?',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      final firestore = FirebaseFirestore.instance;
      for (final u in users) {
        final data = u.data;
        final idRaw = data['id']?.toString() ?? '';
        final emailId = (data['email'] ?? '').toString().toLowerCase();
        final docId = emailId.isNotEmpty ? emailId : idRaw;
        if (docId.isEmpty) continue;
        // Enforce company_id presence before upload
        final cid = (data['company_id'] ?? data['companyId'])?.toString();
        if (cid == null || cid.isEmpty) {
          debugPrint("Skipping user ${data['email']} - missing company_id");
          continue;
        }
        debugPrint("Uploading User ${data['email']} with Company ID: ${cid}");
        debugPrint('Attempting write to: users/$docId');
        await firestore.collection('users').doc(docId).set(
          {
            ...data,
            'company_id': cid,
            'updated_at': data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Force sync users failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Force sync users failed: $e')),
        );
      }
    }
  }

  Future<void> _backfillLocalCompanyIds() async {
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (companyId == null || companyId.isEmpty) return;
    try {
      await widget.db.customStatement(
        "UPDATE users SET company_id = ? WHERE company_id IS NULL OR company_id = ''",
        [companyId],
      );
      await widget.db.customStatement(
        "UPDATE trading_entries SET company_id = ? WHERE company_id IS NULL OR company_id = ''",
        [companyId],
      );
      await widget.db.customStatement(
        "UPDATE trading_file_entries SET company_id = ? WHERE company_id IS NULL OR company_id = ''",
        [companyId],
      );
      debugPrint('Backfilled company_id to local users/trading for company: $companyId');
    } catch (e) {
      debugPrint('Backfill company_id failed: $e');
    }
  }

  // One-time cleanup: delete numeric-id user docs (likely phone-based).
  static bool _didCleanupNumericDocs = false;
  Future<void> _cleanupNumericUserDocsOnce() async {
    if (_didCleanupNumericDocs) return;
    if (!RoleUtils.isSuperAdmin(_currentUser)) return;
    if (Firebase.apps.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final futures = <Future>[];
      for (final doc in snap.docs) {
        final id = doc.id;
        if (RegExp(r'^\d+$').hasMatch(id)) {
          futures.add(FirebaseFirestore.instance.collection('users').doc(id).delete());
        }
      }
      await Future.wait(futures);
    } catch (_) {}
    _didCleanupNumericDocs = true;
  }

  Future<void> _checkAndShowNotifications() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);

      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        return;
      }
      final results = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM working_progress WHERE next_working_date = ? AND status NOT IN (?, ?)'
            : 'SELECT * FROM working_progress WHERE company_id = ? AND next_working_date = ? AND status NOT IN (?, ?)',
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          d.Variable.withString(today),
          d.Variable.withString('Done'),
          d.Variable.withString('Closed'),
        ],
      ).get();
      
      if (results.isNotEmpty && mounted) {
        final entries = results.map((r) => r.data).toList();
        _showNotificationDialog(entries);
      }
    } catch (e) {
      // Silently handle errors - notification is not critical
    }
  }

  void _showNotificationDialog(List<Map<String, dynamic>> entries) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'Scheduled Work Due Today',
              style: AppFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have ${entries.length} item(s) scheduled for today:',
                style: AppFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: 1,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.work, color: Colors.purple.shade600),
                    title: Text(
                      entry['name']?.toString() ?? 'N/A',
                      style: AppFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Date: ${entry['transfer_date'] ?? 'N/A'}',
                      style: AppFonts.poppins(fontSize: 11),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionally scroll to saved entries section
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedEntries() async {
    setState(() => _loadingEntries = true);
    try {
      // Load from SQLite FIRST - show data instantly
      final results = await widget.db.customSelect(
        'SELECT * FROM working_progress ORDER BY updated_at DESC',
      ).get();
      
      List<Map<String, dynamic>> entries = results.map((row) => row.data).toList();
      
      // Show SQLite data immediately (no delay)
      setState(() {
        _savedEntries = entries;
        _loadingEntries = false;
      });
      
      // Load from Firestore in background and merge (non-blocking)
      if (Firebase.apps.isNotEmpty) {
        _mergeFirestoreData(entries).then((mergedEntries) {
          if (mounted) {
            setState(() {
              _savedEntries = mergedEntries;
            });
          }
        }).catchError((e) {
          debugPrint('Firestore merge failed: $e');
          // Keep SQLite data if Firestore fails
        });
      }
    } catch (e) {
      setState(() => _loadingEntries = false);
    }
  }

  /// Merge Firestore data in background (non-blocking)
  Future<List<Map<String, dynamic>>> _mergeFirestoreData(
      List<Map<String, dynamic>> sqliteEntries) async {
    try {
      final entryIds = sqliteEntries
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (entryIds.isEmpty) return sqliteEntries;

      // Use cached batch fetch
      final firestoreData = await FirestoreCacheService()
          .getCachedDocuments('working_progress', entryIds);

      // Merge Firestore data with SQLite data
      return sqliteEntries.map((entry) {
        final id = entry['id']?.toString();
        if (id != null && firestoreData.containsKey(id)) {
          final firestoreEntry = firestoreData[id]!;
          return {
            ...entry,
            'id': entry['id'],
            'name': entry['name'],
            'status': entry['status'],
            'transfer_date': entry['transfer_date'] ?? firestoreEntry['transferDate'],
            'next_working_date':
                entry['next_working_date'] ?? firestoreEntry['nextWorkingDate'],
            'updated_at': entry['updated_at'],
            ...firestoreEntry,
          };
        }
        return entry;
      }).toList();
    } catch (e) {
      debugPrint('Error merging Firestore data: $e');
      return sqliteEntries; // Return SQLite data if merge fails
    }
  }

  List<Map<String, dynamic>> _getFilteredEntries() {
    Iterable<Map<String, dynamic>> entries = _savedEntries;
    
    // Filter by type (Transfer or Client Requirements)
    if (_selectedType == 'Transfer') {
      entries = entries.where((e) {
        final type = e['type']?.toString() ?? '';
        final category = e['category']?.toString();
        // Transfer entries have type='transfer' or have category field (from Firestore)
        // If type is missing but category exists, it's likely a Transfer entry
        return type == 'transfer' || (type.isEmpty && category != null && category.isNotEmpty);
      });
    } else if (_selectedType == 'Client Requirements') {
      entries = entries.where((e) {
        final type = e['type']?.toString() ?? '';
        final source = e['source']?.toString();
        // Client Requirements entries have type='client_requirement' or have source field
        // If type is missing but source exists, it's likely a Client Requirement entry
        return type == 'client_requirement' || (type.isEmpty && source != null && source.isNotEmpty);
      });
    }
    
    
    // Filter by search query
    if (_q.isNotEmpty) {
      entries = entries.where((e) {
        return e.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()));
      });
    }
    
    // Sort entries
    List<Map<String, dynamic>> sortedEntries = entries.toList();
    // Sort by updated date (most recent first)
    sortedEntries.sort((a, b) {
      final dateA = a['updated_at']?.toString() ?? '';
      final dateB = b['updated_at']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });
    
    // Additional sorting by plot size if needed
    if (false) { // Disabled - no block filter
      sortedEntries.sort((a, b) {
        final sizeA = _getSizeSortOrder(a['size']?.toString());
        final sizeB = _getSizeSortOrder(b['size']?.toString());
        return sizeA.compareTo(sizeB); // Smaller sizes first
      });
    }
    
    return sortedEntries;
  }

  @override
  void dispose() {
    _dateCtl.dispose();
    _plotCtl.dispose();
    _clientNameCtl.dispose();
    _clientMobileCtl.dispose();
    _timeCtl.dispose();
    _registryCtl.dispose();
    _commentsCtl.dispose();
    _reqDateCtl.dispose();
    _reqPlotCtl.dispose();
    _reqClientNameCtl.dispose();
    _reqClientMobileCtl.dispose();
    _reqTimeCtl.dispose();
    _reqRegistryCtl.dispose();
    _reqCommentsCtl.dispose();
    _officeNotesCtl.dispose();
    _otherNotesCtl.dispose();
    _nextWorkingDateCtl.dispose();
    _reqNextWorkingDateCtl.dispose();
    _transferOtherCategoryCtl.dispose();
    _transferOtherSizeCtl.dispose();
    _officeNotesSub?.cancel();
    _otherNotesSub?.cancel();
    super.dispose();
  }

  void _initNoteStreams() {
    try {
      final isWindows = !kIsWeb && io.Platform.isWindows;
      if (isWindows) {
        Future.microtask(() async {
          await _loadNotesOnce();
        });
        return;
      }
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        setState(() {
          _officeNotesError = 'Firebase not initialized';
          _otherNotesError = 'Firebase not initialized';
          _officeNotesLoading = false;
          _otherNotesLoading = false;
        });
        return;
      }
      final firestore = FirebaseFirestore.instance;
      _officeNotesRef = firestore.collection('agent_working').doc('office_notes').collection('notes');
      _otherNotesRef = firestore.collection('agent_working').doc('other_notes').collection('notes');
      
      _officeNotesSub = _officeNotesRef!
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) => Future.microtask(() => _handleNotesEvent(snapshot, isOffice: true)), onError: (error) {
        setState(() {
          _officeNotesError = error.toString();
          _officeNotesLoading = false;
        });
      });
      _otherNotesSub = _otherNotesRef!
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) => Future.microtask(() => _handleNotesEvent(snapshot, isOffice: false)), onError: (error) {
        setState(() {
          _otherNotesError = error.toString();
          _otherNotesLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        final msg = 'Failed to connect to Firebase: $e';
        _officeNotesError = msg;
        _otherNotesError = msg;
        _officeNotesLoading = false;
        _otherNotesLoading = false;
      });
    }
  }

  Future<void> _loadNotesOnce() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (!mounted) return;
        setState(() {
          _officeNotesError = 'Firebase not initialized';
          _otherNotesError = 'Firebase not initialized';
          _officeNotesLoading = false;
          _otherNotesLoading = false;
        });
        return;
      }

      // Wait briefly for auth to become available (Windows startup race)
      for (var i = 0; i < 10; i++) {
        if (!mounted) return;
        if (FirebaseAuth.instance.currentUser != null) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (FirebaseAuth.instance.currentUser == null) {
        if (!mounted) return;
        setState(() {
          _officeNotesError = 'Not authenticated';
          _otherNotesError = 'Not authenticated';
          _officeNotesLoading = false;
          _otherNotesLoading = false;
        });
        return;
      }
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (_) {}

      final firestore = FirebaseFirestore.instance;
      _officeNotesRef = firestore.collection('agent_working').doc('office_notes').collection('notes');
      _otherNotesRef = firestore.collection('agent_working').doc('other_notes').collection('notes');

      final officeSnap = await _officeNotesRef!.orderBy('createdAt', descending: true).get();
      final otherSnap = await _otherNotesRef!.orderBy('createdAt', descending: true).get();

      if (!mounted) return;
      _handleNotesEvent(officeSnap, isOffice: true);
      _handleNotesEvent(otherSnap, isOffice: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = 'Failed to connect to Firebase: $e';
        _officeNotesError = msg;
        _otherNotesError = msg;
        _officeNotesLoading = false;
        _otherNotesLoading = false;
      });
    }
  }

  void _handleNotesEvent(QuerySnapshot snapshot, {required bool isOffice}) {
    final notes = _parseNotes(snapshot.docs);
    setState(() {
      if (isOffice) {
        _officeNotes
          ..clear()
          ..addAll(notes);
        _officeNotesLoading = false;
        _officeNotesError = null;
      } else {
        _otherNotes
          ..clear()
          ..addAll(notes);
        _otherNotesLoading = false;
        _otherNotesError = null;
      }
    });
  }

  List<_WorkNote> _parseNotes(List<QueryDocumentSnapshot> docs) {
    final notes = <_WorkNote>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final text = data['text']?.toString() ?? '';
      final createdAt = _decodeTimestamp(data['createdAt']);
      notes.add(_WorkNote(id: doc.id, text: text, createdAt: createdAt));
    }
    // Already sorted by orderBy('createdAt', descending: true)
    return notes;
  }

  DateTime _decodeTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showCustomDatePicker(
      context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showCustomTimePicker(
      context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeCtl.text = picked.format(context);
      });
    }
  }

  Future<void> _pickRequirementDate() async {
    final now = DateTime.now();
    final picked = await showCustomDatePicker(
      context,
      initialDate: _reqSelectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _reqSelectedDate = picked;
        _reqDateCtl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _pickRequirementTime() async {
    final picked = await showCustomTimePicker(
      context,
      initialTime: _reqSelectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _reqSelectedTime = picked;
        _reqTimeCtl.text = picked.format(context);
      });
    }
  }

  Future<void> _pickNextWorkingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextWorkingDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _nextWorkingDate = picked;
        _nextWorkingDateCtl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _pickReqNextWorkingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reqNextWorkingDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _reqNextWorkingDate = picked;
        _reqNextWorkingDateCtl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _submitTransfer({required String action, BuildContext? dialogContext}) async {
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final formValid = _transferFormKey.currentState?.validate() ?? false;
    if (!formValid) return;
    
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    // Capture images BEFORE closing dialog and clearing state
    final imagesToSave = List<String>.from(_transferImages);
    
    // Close dialog immediately when Save is clicked
    if (mounted && dialogContext != null) {
      // Use dialogContext which is the correct dialog context from StatefulBuilder
      Navigator.of(dialogContext).pop(); // Close the popup dialog immediately
    }

    try {
      final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().trim().toLowerCase();
      final safeEmail = emailKey.replaceAll('/', '_');
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final id = safeEmail.isNotEmpty ? '${safeEmail}_$ts' : ts;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final transferDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final nextWorkingDateStr = _nextWorkingDate != null 
          ? DateFormat('yyyy-MM-dd').format(_nextWorkingDate!)
          : null;
      
      // Determine status based on action
      final status = 'Pending'; // Always save as Pending when using Save button
      
      // Use custom category if "Other" is selected and custom value is provided
      final categoryToSave = _transferCategory == 'other' && _transferOtherCategoryCtl.text.trim().isNotEmpty
          ? _transferOtherCategoryCtl.text.trim()
          : _transferCategory;
      
      // Use custom size if "Other" is selected - must use custom value (validation ensures it's not empty)
      final sizeToSave = _transferSize == 'other'
          ? _transferOtherSizeCtl.text.trim() // Always use custom text when "Other" is selected
          : _transferSize;
      
      // OFFLINE-FIRST: Save to local database FIRST
      await widget.db.into(widget.db.workingProgress).insertOnConflictUpdate(
        WorkingProgressCompanion.insert(
          id: id,
          companyId: RoleUtils.isSuperAdmin(_currentUser)
              ? const d.Value.absent()
              : d.Value(RoleUtils.getUserCompanyId(_currentUser)),
          name: _clientNameCtl.text.trim(),
          status: d.Value(status),
          remarks: _commentsCtl.text.trim().isEmpty 
              ? const d.Value.absent() 
              : d.Value(_commentsCtl.text.trim()),
          fromUser: const d.Value.absent(),
          toUser: const d.Value.absent(),
          transferDate: d.Value(transferDate),
          nextWorkingDate: nextWorkingDateStr != null ? d.Value(nextWorkingDateStr) : const d.Value.absent(),
          category: categoryToSave != null && categoryToSave.isNotEmpty ? d.Value(categoryToSave) : const d.Value.absent(),
          updatedAt: nowIso,
        ),
      );

      // Background sync to Firestore (non-blocking)
      _syncToFirestore(
        collection: 'working_progress',
        docId: id,
        data: {
          'id': id,
          'companyId': RoleUtils.getUserCompanyId(_currentUser),
          'name': _clientNameCtl.text.trim(),
          'status': status,
          'remarks': _commentsCtl.text.trim().isEmpty ? null : _commentsCtl.text.trim(),
          'transferDate': transferDate,
          'nextWorkingDate': nextWorkingDateStr,
          'updatedAt': nowIso,
          'type': 'transfer',
          'category': categoryToSave,
          'plotNo': _plotCtl.text.trim(),
          'size': sizeToSave, // Size field (2 Marla, 3 Marla, 5 Marla, 8 Marla, or custom)
          'clientMobile': _clientMobileCtl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''), // PERMANENT: Clean mobile - digits only
          'registryNumber': _registryCtl.text.trim(), // PERMANENT: Validated by form validator
          'imagePaths': imagesToSave.isNotEmpty ? imagesToSave : null, // Save image paths
          'createdBy': emailKey,
        },
      );

      // Reset form
      _transferFormKey.currentState?.reset();
      _dateCtl.clear();
      _plotCtl.clear();
      _clientNameCtl.clear();
      _clientMobileCtl.clear();
      _timeCtl.clear();
      _registryCtl.clear();
      _commentsCtl.clear();
      _nextWorkingDateCtl.clear();
      _transferOtherCategoryCtl.clear();
      _transferOtherSizeCtl.clear();
      _transferCategory = null;
      _transferSize = null;
      _selectedDate = null;
      _selectedTime = null;
      _nextWorkingDate = null;
      _transferImages = [];

      // Reload entries after save completes
      if (mounted) {
        await _loadSavedEntries();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer details saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save transfer: $e')),
        );
      }
    }
  }

  Future<void> _submitClientRequirement({required String action, BuildContext? dialogContext}) async {
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final formValid = _clientRequirementFormKey.currentState?.validate() ?? false;
    if (!formValid) return;
    
    if (_reqSelectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    // Capture images BEFORE closing dialog and clearing state
    final imagesToSave = List<String>.from(_clientRequirementImages);
    
    // Close dialog immediately when Save is clicked
    if (mounted && dialogContext != null) {
      // Use dialogContext which is the correct dialog context from StatefulBuilder
      Navigator.of(dialogContext).pop(); // Close the popup dialog immediately
    }

    try {
      final emailKey = (_currentUser?['email'] ?? _currentUser?['username'] ?? '').toString().trim().toLowerCase();
      final safeEmail = emailKey.replaceAll('/', '_');
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final id = safeEmail.isNotEmpty ? '${safeEmail}_$ts' : ts;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final transferDate = DateFormat('yyyy-MM-dd').format(_reqSelectedDate!);
      final nextWorkingDateStr = _reqNextWorkingDate != null 
          ? DateFormat('yyyy-MM-dd').format(_reqNextWorkingDate!)
          : null;
      
      // Combine client name with category and source for the name field
      final name = '${_reqClientNameCtl.text.trim()} (${_requirementCategory ?? 'N/A'}, ${_requirementSource ?? 'N/A'})';
      
      // Determine status based on action
      final status = 'Pending'; // Always save as Pending when using Save button
      
      // OFFLINE-FIRST: Save to local database FIRST
      await widget.db.into(widget.db.workingProgress).insertOnConflictUpdate(
        WorkingProgressCompanion.insert(
          id: id,
          companyId: RoleUtils.isSuperAdmin(_currentUser)
              ? const d.Value.absent()
              : d.Value(RoleUtils.getUserCompanyId(_currentUser)),
          name: name,
          status: d.Value(status),
          remarks: _reqCommentsCtl.text.trim().isEmpty 
              ? const d.Value.absent() 
              : d.Value(_reqCommentsCtl.text.trim()),
          fromUser: const d.Value.absent(),
          toUser: const d.Value.absent(),
          transferDate: d.Value(transferDate),
          nextWorkingDate: nextWorkingDateStr != null ? d.Value(nextWorkingDateStr) : const d.Value.absent(),
          updatedAt: nowIso,
        ),
      );

      // Background sync to Firestore (non-blocking)
      _syncToFirestore(
        collection: 'working_progress',
        docId: id,
        data: {
          'id': id,
          'companyId': RoleUtils.getUserCompanyId(_currentUser),
          'name': name,
          'status': status,
          'remarks': _reqCommentsCtl.text.trim().isEmpty ? null : _reqCommentsCtl.text.trim(),
          'transferDate': transferDate,
          'nextWorkingDate': nextWorkingDateStr,
          'updatedAt': nowIso,
          'type': 'client_requirement',
          'category': _requirementCategory,
          'source': _requirementSource,
          'plotNo': _reqPlotCtl.text.trim(),
          'clientMobile': _reqClientMobileCtl.text.trim(),
          'registryNumber': _reqRegistryCtl.text.trim(),
          'imagePaths': imagesToSave.isNotEmpty ? imagesToSave : null, // Save image paths
          'createdBy': emailKey,
        },
      );

      // Reset form
      _clientRequirementFormKey.currentState?.reset();
      _reqDateCtl.clear();
      _reqPlotCtl.clear();
      _reqClientNameCtl.clear();
      _reqClientMobileCtl.clear();
      _reqTimeCtl.clear();
      _reqRegistryCtl.clear();
      _reqCommentsCtl.clear();
      _reqNextWorkingDateCtl.clear();
      _requirementCategory = null;
      _requirementSource = null;
      _reqSelectedDate = null;
      _reqSelectedTime = null;
      _reqNextWorkingDate = null;
      _clientRequirementImages = [];

      // Reload entries after save completes
      if (mounted) {
        await _loadSavedEntries();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client requirements saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save client requirement: $e')),
        );
      }
    }
  }

  void _saveOfficeNote() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final valid = _officeNotesFormKey.currentState?.validate() ?? false;
    if (!valid || _officeNotesRef == null) return;
    final text = _officeNotesCtl.text.trim();
    try {
      await _officeNotesRef!.add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _officeNotesCtl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Office note added.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save office note: $e')),
        );
      }
    }
  }

  void _saveOtherNote() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final valid = _otherNotesFormKey.currentState?.validate() ?? false;
    if (!valid || _otherNotesRef == null) return;
    final text = _otherNotesCtl.text.trim();
    try {
      await _otherNotesRef!.add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _otherNotesCtl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other work note added.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save note: $e')),
        );
      }
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint, IconData? icon, Widget? suffixIcon, bool isRequired = false}) {
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
    
    // Add asterisk for required fields
    final labelText = isRequired ? '$label *' : label;
    
    // Use "Rs" text widget for currency fields instead of dollar icon
    Widget? prefixWidget;
    if (fieldIcon == null && (label.toLowerCase().contains('price') || label.toLowerCase().contains('demand') || label.toLowerCase().contains('payment') || label.toLowerCase().contains('rent') || label.toLowerCase().contains('security'))) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text(
          'Rs',
          style: AppFonts.poppins(
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
      labelText: labelText,
      hintText: hint,
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
      labelStyle: AppFonts.poppins(color: Colors.grey.shade700),
    );
  }

  Widget _buildSectionCard({required String title, required Widget body, bool initiallyExpanded = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          title,
          style: AppFonts.poppins(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _buildTransferForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {
    return Form(
      key: _transferFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
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

              // Helper function to build section headers
              Widget _buildSectionHeader(String title, IconData icon) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: const Color(0xFFFF6B35)),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transfer Form',
                      style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    
                    // Section 1: Property Details
                    _buildSectionHeader('Property Details', Icons.home_work),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        fieldBox(
                          DropdownButtonFormField<String>(
                            value: _transferCategory,
                            decoration: _fieldDecoration('Category', isRequired: true),
                            items: const [
                              DropdownMenuItem(value: 'plot', child: Text('Plot')),
                              DropdownMenuItem(value: 'house', child: Text('House')),
                              DropdownMenuItem(value: 'shop', child: Text('Shop')),
                              DropdownMenuItem(value: 'file', child: Text('File')),
                              DropdownMenuItem(value: 'plaza', child: Text('Plaza')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (value) {
                              if (dialogSetState != null) {
                                dialogSetState(() {
                                  _transferCategory = value;
                                  if (value != 'other') {
                                    _transferOtherCategoryCtl.clear();
                                  }
                                });
                              } else {
                                setState(() {
                                  _transferCategory = value;
                                  if (value != 'other') {
                                    _transferOtherCategoryCtl.clear();
                                  }
                                });
                              }
                            },
                            validator: (value) => value == null || value.isEmpty ? 'Select category' : null,
                          ),
                        ),
                        if (_transferCategory == 'other')
                          fieldBox(
                            TextFormField(
                              controller: _transferOtherCategoryCtl,
                              decoration: _fieldDecoration('Custom Category', hint: 'Enter custom category name'),
                              maxLength: 100,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              validator: (value) {
                                if (_transferCategory == 'other') {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter custom category';
                                  }
                                  if (value.length > 100) {
                                    return 'Maximum 100 characters allowed';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        fieldBox(
                          DropdownButtonFormField<String>(
                            value: _transferSize,
                            decoration: _fieldDecoration('Size'),
                            items: const [
                              DropdownMenuItem(value: '2 Marla', child: Text('2 Marla')),
                              DropdownMenuItem(value: '3 Marla', child: Text('3 Marla')),
                              DropdownMenuItem(value: '5 Marla', child: Text('5 Marla')),
                              DropdownMenuItem(value: '8 Marla', child: Text('8 Marla')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (value) {
                              if (dialogSetState != null) {
                                dialogSetState(() {
                                  _transferSize = value;
                                  if (value != 'other') {
                                    _transferOtherSizeCtl.clear();
                                  }
                                });
                              } else {
                                setState(() {
                                  _transferSize = value;
                                  if (value != 'other') {
                                    _transferOtherSizeCtl.clear();
                                  }
                                });
                              }
                            },
                            validator: (value) => value == null || value.isEmpty ? 'Select size' : null,
                          ),
                        ),
                        if (_transferSize == 'other')
                          fieldBox(
                            TextFormField(
                              controller: _transferOtherSizeCtl,
                              decoration: _fieldDecoration('Custom Size', hint: 'Enter custom size'),
                              maxLength: 100,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              validator: (value) {
                                if (_transferSize == 'other') {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter custom size';
                                  }
                                  if (value.length > 100) {
                                    return 'Maximum 100 characters allowed';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        fieldBox(
                          TextFormField(
                            controller: _plotCtl,
                            decoration: _fieldDecoration('Plot No.'),
                            maxLength: 100,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [plotNoFormatter],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter plot number';
                              return validatePlotNo(value);
                            },
                          ),
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _registryCtl,
                            decoration: _fieldDecoration('Registry/Transfer Number'),
                            maxLength: 50,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [registryTransferNoFormatter],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter registry or transfer number';
                              return validateRegistryTransferNo(value);
                            },
                          ),
                        ),
                      ],
                    ),

                    // Section 2: Client Information
                    _buildSectionHeader('Client Information', Icons.person),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        fieldBox(
                          TextFormField(
                            controller: _clientNameCtl,
                            decoration: _fieldDecoration('Client Name'),
                            maxLength: 100,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [clientNameFormatter],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter client name';
                              return validateClientName(value);
                            },
                          ),
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _clientMobileCtl,
                            keyboardType: TextInputType.phone,
                            decoration: _fieldDecoration('Client Mobile No.', hint: '03XX-XXXXXXX'),
                            maxLength: 11,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [mobileNoFormatter],
                            validator: validateClientMobileNo,
                          ),
                        ),
                      ],
                    ),

                    // Section 3: Timeline & Follow-up
                    _buildSectionHeader('Timeline & Follow-up', Icons.schedule),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        fieldBox(
                          TextFormField(
                            controller: _dateCtl,
                            readOnly: true,
                            onTap: _pickDate,
                            decoration: _fieldDecoration('Date', icon: Icons.calendar_today, suffixIcon: const Icon(Icons.calendar_today), isRequired: true),
                            validator: (value) => value == null || value.isEmpty ? 'Select a date' : null,
                          ),
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _timeCtl,
                            readOnly: true,
                            onTap: _pickTime,
                            decoration: _fieldDecoration('Time', icon: Icons.schedule, suffixIcon: const Icon(Icons.schedule), isRequired: true),
                            validator: (value) => value == null || value.isEmpty ? 'Select time' : null,
                          ),
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _nextWorkingDateCtl,
                            readOnly: true,
                            onTap: _pickNextWorkingDate,
                            decoration: _fieldDecoration('Next Working Date', suffixIcon: const Icon(Icons.calendar_today), hint: 'Select next working date for reminder'),
                          ),
                        ),
                      ],
                    ),

                    // Section 4: Attachments & Notes
                    _buildSectionHeader('Attachments & Notes', Icons.attach_file),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        fieldBox(
                          ImageUploadWidget(
                            imagePaths: _transferImages,
                            onImagesChanged: (images) {
                              if (dialogSetState != null) {
                                dialogSetState(() {
                                  _transferImages = images;
                                });
                              } else {
                                setState(() {
                                  _transferImages = images;
                                });
                              }
                            },
                            maxImages: 3,
                          ),
                          span: columns,
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _commentsCtl,
                            decoration: _fieldDecoration('Remarks'),
                            maxLines: 5,
                            minLines: 3,
                            maxLength: 200,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [commentFormatter],
                            validator: validateComment,
                          ),
                          span: columns,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _resetTransferForm();
                          final navContext = dialogContext ?? context;
                          Navigator.of(navContext).pop();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      const Spacer(),
                      if (PermissionHelper.canAddModule(_currentUser, 'agent_working'))
                        PrimaryGradientButton(
                          text: 'Save',
                          icon: Icons.save,
                          onPressed: () => _submitTransfer(action: 'Save', dialogContext: dialogContext),
                        ),
                    ],
                  ),
                ],
              ),
            );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildClientRequirementForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {
    return Form(
      key: _clientRequirementFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client Requirement Form',
                    style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      fieldBox(
                        DropdownButtonFormField<String>(
                          value: _requirementCategory,
                          decoration: _fieldDecoration('Category'),
                          items: const [
                            DropdownMenuItem(value: 'plot', child: Text('Plot')),
                            DropdownMenuItem(value: 'house', child: Text('House')),
                            DropdownMenuItem(value: 'shop', child: Text('Shop')),
                            DropdownMenuItem(value: 'file', child: Text('File')),
                            DropdownMenuItem(value: 'plaza', child: Text('Plaza')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            if (dialogSetState != null) {
                              dialogSetState(() => _requirementCategory = value);
                            } else {
                              setState(() => _requirementCategory = value);
                            }
                          },
                          validator: (value) => value == null || value.isEmpty ? 'Select category' : null,
                        ),
                      ),
                        fieldBox(
                          TextFormField(
                            controller: _reqDateCtl,
                            readOnly: true,
                            onTap: _pickRequirementDate,
                            decoration: _fieldDecoration('Date', suffixIcon: const Icon(Icons.calendar_today), isRequired: true),
                            validator: (value) => value == null || value.isEmpty ? 'Select a date' : null,
                          ),
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _reqPlotCtl,
                            decoration: _fieldDecoration('Plot No.', isRequired: true),
                            validator: (value) => value == null || value.isEmpty ? 'Enter plot number' : null,
                          ),
                        ),
                        fieldBox(
                          TextFormField(
                            controller: _reqClientNameCtl,
                            decoration: _fieldDecoration('Client Name', isRequired: true),
                            maxLength: 100,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [clientNameFormatter],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter client name';
                              return validateClientName(value);
                            },
                          ),
                        ),
                      fieldBox(
                        TextFormField(
                          controller: _reqClientMobileCtl,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration('Client Mobile No.', hint: '03XX-XXXXXXX', isRequired: true),
                          maxLength: 11,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: [mobileNoFormatter],
                          validator: validateClientMobileNo,
                        ),
                      ),
                      fieldBox(
                        TextFormField(
                          controller: _reqTimeCtl,
                          readOnly: true,
                          onTap: _pickRequirementTime,
                          decoration: _fieldDecoration('Time', suffixIcon: const Icon(Icons.schedule), isRequired: true),
                          validator: (value) => value == null || value.isEmpty ? 'Select time' : null,
                        ),
                      ),
                      fieldBox(
                        DropdownButtonFormField<String>(
                          value: _requirementSource,
                          decoration: _fieldDecoration('Source'),
                          items: const [
                            DropdownMenuItem(value: 'website', child: Text('Website')),
                            DropdownMenuItem(value: 'referral', child: Text('Referral')),
                            DropdownMenuItem(value: 'walk-in', child: Text('Walk-in')),
                            DropdownMenuItem(value: 'social-media', child: Text('Social Media')),
                            DropdownMenuItem(value: 'advertisement', child: Text('Advertisement')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            if (dialogSetState != null) {
                              dialogSetState(() => _requirementSource = value);
                            } else {
                              setState(() => _requirementSource = value);
                            }
                          },
                          validator: (value) => value == null || value.isEmpty ? 'Select source' : null,
                        ),
                      ),
                      fieldBox(
                        TextFormField(
                          controller: _reqRegistryCtl,
                          decoration: _fieldDecoration('Registry/Transfer Number'),
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: [registryTransferNoFormatter],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter registry or transfer number';
                            return validateRegistryTransferNo(value);
                          },
                        ),
                      ),
                      fieldBox(
                        TextFormField(
                          controller: _reqNextWorkingDateCtl,
                          readOnly: true,
                          onTap: _pickReqNextWorkingDate,
                          decoration: _fieldDecoration('Next Working Date', suffixIcon: const Icon(Icons.calendar_today), hint: 'Select next working date for reminder'),
                        ),
                      ),
                      fieldBox(
                        TextFormField(
                          controller: _reqCommentsCtl,
                          decoration: _fieldDecoration('Remarks'),
                          maxLines: 1,
                          maxLength: 200,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: [commentFormatter],
                          validator: validateComment,
                        ),
                        span: columns,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ImageUploadWidget(
                    imagePaths: _clientRequirementImages,
                    onImagesChanged: (images) {
                      setState(() {
                        _clientRequirementImages = images;
                      });
                    },
                    maxImages: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _resetClientRequirementForm();
                          final navContext = dialogContext ?? context;
                          Navigator.of(navContext).pop();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      const Spacer(),
                      if (PermissionHelper.canAddModule(_currentUser, 'agent_working'))
                        PrimaryGradientButton(
                          text: 'Save',
                          icon: Icons.save,
                          onPressed: () => _submitClientRequirement(action: 'Save', dialogContext: dialogContext),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection({
    required String label,
    required TextEditingController controller,
    required GlobalKey<FormState> formKey,
    required VoidCallback onSave,
    required List<_WorkNote> notes,
    required bool isLoading,
    required String? error,
  }) {
    final noteFormat = DateFormat('dd MMM yyyy â€¢ hh:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: controller,
                maxLines: 4,
                decoration: _fieldDecoration('Notes', hint: 'Add notes for $label'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter notes' : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PermissionHelper.canAddModule(_currentUser, 'agent_working')
                    ? FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Save Note'),
                        onPressed: onSave,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: Colors.blueGrey.shade100),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: ShimmerBox(width: 140, height: 14)),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Unable to load notes: $error',
              style: TextStyle(color: Colors.red.shade400),
            ),
          )
        else if (notes.isEmpty)
          Text(
            'No notes yet.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          Column(
            children: notes
                .map(
                  (entry) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    child: ListTile(
                      key: ValueKey(entry.id),
                      leading: const Icon(Icons.note_alt, color: Colors.indigo),
                      title: Text(entry.text),
                      subtitle: Text(noteFormat.format(entry.createdAt)),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildComingSoon(String title) {
    return _buildSectionCard(
      title: title,
      body: const Text(
        'This form will be available soon.',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }

  Widget _buildDataDisplaySection() {
    if (_loadingEntries) {
      return const ShimmerPageLoading(itemCount: 10);
    }

    final filteredEntries = _getFilteredEntries();

    if (filteredEntries.isEmpty) {
      return Center(
        child: Text('No ${_selectedType.toLowerCase()} entries found'),
      );
    }

    final TextStyle infoStyle = TextStyle(
      fontSize: 14,
      color: const Color(0xFFFF6B35),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      items: const [
                        DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                        DropdownMenuItem(value: 'Client Requirements', child: Text('Client Requirements')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedType = v;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 116),
            itemCount: filteredEntries.length,
            itemBuilder: (ctx, i) {
              final entry = filteredEntries[i];
              final status = entry['status'] ?? 'Pending';
              final statusColor = status == 'Done' 
                  ? Colors.green.shade700 
                  : status == 'Closed' 
                      ? Colors.orange.shade700 
                      : Colors.blue.shade700;
              
              // Build title similar to Inventory module
              final category = entry['category']?.toString() ?? '';
              final title = category.isNotEmpty 
                  ? '${entry['name'] ?? 'N/A'} â€¢ $category'
                  : entry['name'] ?? 'N/A';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                          FilledButton.icon(
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Action'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              // Can add detail view later if needed
                            },
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              if (PermissionHelper.canDeleteModule(_currentUser, 'agent_working'))
                                PopupMenuItem(
                                  child: const Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Delete')]),
                                  onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _deleteEntry(entry['id'] as String)),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      buildResponsiveInfoRow(
                        context,
                        [
                          InfoEntry('Owner Name', entry['name'], style: infoStyle),
                        ],
                      ),
                      // Size field with color coding
                      if (entry['size'] != null && entry['size'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                'Size: ',
                                style: infoStyle,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getSizeColor(entry['size']?.toString() ?? '').withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getSizeColor(entry['size']?.toString() ?? ''),
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  entry['size']?.toString() ?? '',
                                  style: _getSizeStyle(entry['size']?.toString() ?? ''),
                                ),
                              ),
                            ],
                          ),
                        ),
                      buildResponsiveInfoRow(
                        context,
                        [
                          InfoEntry('Status', status, style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          )),
                        ],
                      ),
                      // Load and display images from Firestore (with caching)
                      FutureBuilder<Map<String, dynamic>?>(
                        future: entry['id'] != null
                            ? FirestoreCacheService().getCachedDocument(
                                'working_progress',
                                entry['id']?.toString() ?? '',
                              )
                            : Future<Map<String, dynamic>?>.value(null),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const SizedBox.shrink();
                          }
                          final data = snapshot.data!;
                          final imagePaths = data['imagePaths'];
                          if (imagePaths == null) {
                            return const SizedBox.shrink();
                          }
                          // Handle both List<dynamic> and List<String>
                          List<String> paths = [];
                          if (imagePaths is List) {
                            paths = imagePaths.map((p) => p.toString()).toList();
                          } else if (imagePaths is String) {
                            paths = [imagePaths];
                          }
                          if (paths.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Images:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: paths.take(3).map((path) {
                                  return GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          child: Stack(
                                            children: [
                                              Container(
                                                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
                                                              child: CachedImageWidget(
                                                                imagePath: path.toString(),
                                                                fit: BoxFit.contain,
                                                              ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.white),
                                                  onPressed: () => Navigator.pop(ctx),
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: Colors.black54,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedImageWidget(
                                          imagePath: path.toString(),
                                          fit: BoxFit.cover,
                                          width: 60,
                                          height: 60,
                                          errorWidget: const Icon(Icons.broken_image, size: 24),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updated: ${entry['updated_at']?.toString().split('T').first ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _updateEntryStatus(String id, String status, {DateTime? nextDate}) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final nextDateStr = nextDate != null ? DateFormat('yyyy-MM-dd').format(nextDate) : null;

      // Update in SQLite
      await widget.db.customStatement(
        'UPDATE working_progress SET status = ?, next_working_date = ?, updated_at = ? WHERE id = ?',
        [status, nextDateStr ?? '', nowIso, id],
      );

      // Update in Firestore if available
      try {
        if (Firebase.apps.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('working_progress').doc(id).update({
            'status': status,
            'nextWorkingDate': nextDateStr,
            'updatedAt': nowIso,
          });
        }
      } catch (e) {
        debugPrint('Firestore update failed: $e');
      }

      await _loadSavedEntries();
      if (mounted) {
        final dateMsg = nextDateStr != null ? ' (Next Date: ${DateFormat('dd MMM yyyy').format(nextDate!)})' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status$dateMsg')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _handleDone(Map<String, dynamic> entry) async {
    await _updateEntryStatus(entry['id'] as String, 'Done');
  }

  Future<void> _handleNextDate(Map<String, dynamic> entry) async {
    final existingNextDate = entry['nextWorkingDate']?.toString() ?? entry['next_working_date']?.toString();
    DateTime? initialDate;
    if (existingNextDate != null && existingNextDate.isNotEmpty) {
      try {
        initialDate = DateTime.tryParse(existingNextDate);
        if (initialDate == null) {
          initialDate = DateFormat('yyyy-MM-dd').parse(existingNextDate);
        }
      } catch (e) {
        initialDate = DateTime.now();
      }
    } else {
      initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      await _updateEntryStatus(entry['id'] as String, entry['status']?.toString() ?? 'Pending', nextDate: picked);
    }
  }

  Future<void> _handleCloseIncomplete(Map<String, dynamic> entry) async {
    await _updateEntryStatus(entry['id'] as String, 'Closed');
  }

  Future<void> _deleteEntry(String id) async {
    // Permission check: Only allow delete if user has full_access
    if (!PermissionHelper.canDeleteModule(_currentUser, 'agent_working')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to delete entries.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      try {
        await widget.db.customStatement(
          "UPDATE working_progress SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
          [nowIso, id],
        );
        await _loadSavedEntries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete entry: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _getFilteredEntries();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Agent Working',
          style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (q) => setState(() => _q = q)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFormDialog,
        icon: const Icon(Icons.add),
        label: Text(_selectedType == 'Transfer' ? 'Add Transfer' : 'Add Client Requirement'),
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
        child: _loadingEntries
            ? const ShimmerPageLoading(itemCount: 10)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dropdowns and data display
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  items: const [
                                    DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                                    DropdownMenuItem(value: 'Client Requirements', child: Text('Client Requirements')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedType = v;
                                      });
                                      _loadSavedEntries();
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Type',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Data display
                    _loadingEntries
                        ? const ShimmerPageLoading(itemCount: 10)
                        : filteredEntries.isEmpty
                            ? Center(child: Text('No ${_selectedType.toLowerCase()} entries found'))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: filteredEntries.length,
                                itemBuilder: (ctx, i) {
                                  return _buildEntryCard(filteredEntries[i]);
                                },
                              ),
                  ],
                ),
              ),
        ),
    );
  }

  void _resetTransferForm() {
    _transferFormKey.currentState?.reset();
    _dateCtl.clear();
    _plotCtl.clear();
    _clientNameCtl.clear();
    _clientMobileCtl.clear();
    _timeCtl.clear();
    _registryCtl.clear();
    _commentsCtl.clear();
    _nextWorkingDateCtl.clear();
    _transferOtherCategoryCtl.clear();
    _transferOtherSizeCtl.clear();
    _transferCategory = null;
    _transferSize = null;
    _selectedDate = null;
    _selectedTime = null;
    _nextWorkingDate = null;
    _transferImages = []; // Reset images
  }

  void _resetClientRequirementForm() {
    _clientRequirementFormKey.currentState?.reset();
    _reqDateCtl.clear();
    _reqPlotCtl.clear();
    _reqClientNameCtl.clear();
    _reqClientMobileCtl.clear();
    _reqTimeCtl.clear();
    _reqRegistryCtl.clear();
    _reqCommentsCtl.clear();
    _reqNextWorkingDateCtl.clear();
    _requirementCategory = null;
    _requirementSource = null;
    _reqSelectedDate = null;
    _reqSelectedTime = null;
    _reqNextWorkingDate = null;
    _clientRequirementImages = []; // Reset images
  }

  void _showAddFormDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by clicking outside
      builder: (dialogBuilderContext) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (_selectedType == 'Transfer') {
              _resetTransferForm();
            } else {
              _resetClientRequirementForm();
            }
            Navigator.of(dialogBuilderContext).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(dialogBuilderContext).size.width * 0.9,
            height: MediaQuery.of(dialogBuilderContext).size.height * 0.9,
            child: StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                return Stack(
                  children: [
                    // Form content with padding for back button
                    Padding(
                      padding: const EdgeInsets.only(top: 56), // Space for back button
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _selectedType == 'Transfer' 
                            ? _buildTransferForm(setDialogState, dialogContext) 
                            : _buildClientRequirementForm(setDialogState, dialogContext),
                      ),
                    ),
                    // Back button at top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (_selectedType == 'Transfer') {
                            _resetTransferForm();
                          } else {
                            _resetClientRequirementForm();
                          }
                          // Use dialogContext which is the correct dialog context
                          Navigator.of(dialogContext).pop();
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

  // Helper function to get color for Size field based on Marla value
  Color _getSizeColor(String size) {
    final sizeLower = size.toLowerCase();
    
    if (sizeLower.contains('2 marla')) {
      return const Color(0xFFD2B48C); // Light beige/tan
    } else if (sizeLower.contains('3 marla')) {
      return const Color(0xFFE6E6FA); // Light purple/lavender
    } else if (sizeLower.contains('5 marla')) {
      return const Color(0xFF90EE90); // Light green
    } else if (sizeLower.contains('8 marla')) {
      return const Color(0xFFFFB6C1); // Light pink
    } else {
      return const Color(0xFFFF6B35); // Orange - default color
    }
  }

  // Helper function to get style for Size field based on Marla value
  TextStyle _getSizeStyle(String size) {
    final sizeColor = _getSizeColor(size);
    
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: sizeColor,
    );
  }

  // Helper function to get sort order for plot sizes
  int _getSizeSortOrder(String? size) {
    if (size == null || size.isEmpty) return 999; // Put empty sizes at the end
    final sizeLower = size.toLowerCase();
    if (sizeLower.contains('2 marla')) return 1;
    if (sizeLower.contains('3 marla')) return 2;
    if (sizeLower.contains('5 marla')) return 3;
    if (sizeLower.contains('8 marla')) return 4;
    // Custom sizes (Other) should come after standard sizes but before empty
    return 500; // Custom sizes in the middle
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final status = entry['status'] ?? 'Pending';
    final statusColor = status == 'Done' 
        ? Colors.green.shade700 
        : status == 'Closed' 
            ? Colors.orange.shade700 
            : Colors.blue.shade700;
    
    final TextStyle infoStyle = TextStyle(
      fontSize: 14,
      color: const Color(0xFFFF6B35),
    );
    
    // Build title similar to Inventory module
    final category = entry['category']?.toString() ?? '';
    final title = category.isNotEmpty 
        ? '${entry['name'] ?? 'N/A'} â€¢ $category'
        : entry['name'] ?? 'N/A';
    
    // Get background color based on size
    // Check multiple possible field names for size
    final sizeValue = (entry['size']?.toString() ?? 
                       entry['Size']?.toString() ?? 
                       '').trim();
    final sizeColor = sizeValue.isNotEmpty ? _getSizeColor(sizeValue) : null;
    
    // Get image paths from entry
    final imagePaths = entry['imagePaths'] != null 
        ? List<String>.from(entry['imagePaths'] is List ? entry['imagePaths'] : [])
        : <String>[];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text('Entry Details')),
                          body: const Center(
                            child: Text('Detail page not implemented yet'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text('Done'),
                        ],
                      ),
                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _handleDone(entry)),
                    ),
                    PopupMenuItem<String>(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text('Next Date'),
                        ],
                      ),
                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _handleNextDate(entry)),
                    ),
                    PopupMenuItem<String>(
                      child: Row(
                        children: [
                          Icon(Icons.close, size: 18, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text('Close Incomplete'),
                        ],
                      ),
                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _handleCloseIncomplete(entry)),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          const Text('Delete'),
                        ],
                      ),
                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _deleteEntry(entry['id'] as String)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            buildResponsiveInfoRow(
              context,
              [
                InfoEntry('Owner Name', entry['name'], style: infoStyle),
              ],
            ),
            // Size field with color coding
            if (entry['size'] != null && entry['size'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Size: ',
                      style: infoStyle,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSizeColor(entry['size']?.toString() ?? '').withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getSizeColor(entry['size']?.toString() ?? ''),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        entry['size']?.toString() ?? '',
                        style: _getSizeStyle(entry['size']?.toString() ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
            buildResponsiveInfoRow(
              context,
              [
                InfoEntry('Status', status, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                )),
              ],
            ),
            Text(
              'Updated: ${entry['updated_at']?.toString().split('T').first ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            // Image thumbnails
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Images:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: imagePaths.take(3).map((imagePath) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: Stack(
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
                                child: CachedImageWidget(
                                  imagePath: imagePath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(ctx),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImageWidget(
                          imagePath: imagePath,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                          errorWidget: const Icon(Icons.broken_image, size: 30),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

