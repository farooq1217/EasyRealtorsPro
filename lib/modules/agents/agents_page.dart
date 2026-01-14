import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, KeyDownEvent, LogicalKeyboardKey, FilteringTextInputFormatter, Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../core/services/auth_service.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
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
import '../../core/shared_utils.dart' show TopRightSearch, buildResponsiveInfoRow, InfoEntry, validatePassword, normalizeSubscriptionTier, subscriptionLimitForTier, showCustomTimePicker;

class AgentWorkingPage extends StatefulWidget {
  final AppDatabase db;
  const AgentWorkingPage({super.key, required this.db});

  @override
  State<AgentWorkingPage> createState() => _AgentWorkingPageState();
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
      final snap = await FirebaseFirestore.instance.collection('companies').get();
      debugPrint('Firestore docs found: ${snap.docs.length}');
      if (snap.docs.isEmpty) return;

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
      await _loadSavedEntries();
      _checkAndShowNotifications();
    });
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
        if (Firebase.apps.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));
          // Invalidate cache after successful sync
          FirestoreCacheService().invalidateCache(collection, docId);
        }
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
        // Sync will retry automatically when connectivity is restored
      }
    });
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                style: GoogleFonts.poppins(fontSize: 14),
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
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Date: ${entry['transfer_date'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(fontSize: 11),
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
          .listen((snapshot) => _handleNotesEvent(snapshot, isOffice: true), onError: (error) {
        setState(() {
          _officeNotesError = error.toString();
          _officeNotesLoading = false;
        });
      });
      _otherNotesSub = _otherNotesRef!
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) => _handleNotesEvent(snapshot, isOffice: false), onError: (error) {
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
      final id = DateTime.now().millisecondsSinceEpoch.toString();
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
      final id = DateTime.now().millisecondsSinceEpoch.toString();
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
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                        style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
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
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        builder: (context) => AgentWorkingDetailPage(
                          entryData: entry,
                          db: widget.db,
                          onUpdate: () => _loadSavedEntries(),
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

class AgentWorkingDetailPage extends StatefulWidget {
  final Map<String, dynamic> entryData;
  final AppDatabase db;
  final VoidCallback onUpdate;

  const AgentWorkingDetailPage({
    super.key,
    required this.entryData,
    required this.db,
    required this.onUpdate,
  });

  @override
  State<AgentWorkingDetailPage> createState() => _AgentWorkingDetailPageState();
}

class _AgentWorkingDetailPageState extends State<AgentWorkingDetailPage> {
  DateTime? _selectedNextDate;

  @override
  void initState() {
    super.initState();
    // Initialize next date from existing data
    final nextDateStr = widget.entryData['nextWorkingDate']?.toString() ?? 
                        widget.entryData['next_working_date']?.toString();
    if (nextDateStr != null && nextDateStr.isNotEmpty) {
      try {
        // Try parsing ISO format first
        _selectedNextDate = DateTime.tryParse(nextDateStr);
        // If that fails, try yyyy-MM-dd format
        if (_selectedNextDate == null) {
          _selectedNextDate = DateFormat('yyyy-MM-dd').parse(nextDateStr);
        }
      } catch (e) {
        debugPrint('Failed to parse next date: $e');
      }
    }
  }

  Future<void> _updateStatus(String status, {DateTime? nextDate}) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final id = widget.entryData['id'] as String;
      // Use yyyy-MM-dd format to match the rest of the codebase
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

      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
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

  Future<void> _printDocument() async {
    final entry = widget.entryData;
    final isTransfer = entry['type']?.toString() == 'transfer' ||
        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final title = 'Agent Working Details';
    final serial = generateReportSerial(prefix: 'RPT');
    final generatedAt = DateTime.now();

    final currentUser = await loadCurrentUserFromStorage();
    final entityId = entry['id']?.toString();
    final fields = _getAllFields(entry, isTransfer);

    await logReportHistory(
      db: widget.db,
      currentUser: currentUser,
      companyId: RoleUtils.getUserCompanyId(currentUser),
      module: 'agent_working',
      entityId: entityId,
      reportType: title,
      action: 'print',
      serialNumber: serial,
      generatedAt: generatedAt,
    );

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildKeyValueReportPdf(
          format: a4Format,
          db: widget.db,
          currentUser: currentUser,
          module: 'agent_working',
          entityId: entityId,
          title: title,
          action: 'print',
          fields: fields,
          serialNumber: serial,
          generatedAt: generatedAt,
          logHistory: false,
        );
      },
    );
  }

  Future<void> _downloadPdf() async {
    try {
      final entry = widget.entryData;
      final isTransfer = entry['type']?.toString() == 'transfer' ||
          (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
      final title = 'Agent Working Details';
      
      // Show immediate feedback dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Generating PDF...', style: GoogleFonts.poppins(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
      
      // Pre-load ALL data BEFORE compute() to prevent blocking
      final preloadFutures = await Future.wait([
        _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf'),
        _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf'),
        loadCurrentUserFromStorage(),
      ]);

      final baseFontBytes = (preloadFutures[0] as Uint8List?) ?? Uint8List(0);
      final boldFontBytes = (preloadFutures[1] as Uint8List?) ?? Uint8List(0);
      final currentUser = preloadFutures[2] as Map<String, dynamic>?;

      // Load branding (database query - must be done before isolate)
      final branding = await loadReportBranding(db: widget.db, currentUser: currentUser);
      
      // Prepare data for isolate - convert to serializable format
      final entryData = {
        'id': entry['id']?.toString(),
        'type': entry['type']?.toString(),
        'category': entry['category']?.toString(),
        'status': entry['status']?.toString(),
        'name': entry['name']?.toString(),
        'clientMobile': entry['clientMobile']?.toString(),
        'plotNo': entry['plotNo']?.toString(),
        'registryNumber': entry['registryNumber']?.toString(),
        'transferDate': entry['transferDate']?.toString(),
        'transfer_date': entry['transfer_date']?.toString(),
        'nextWorkingDate': entry['nextWorkingDate']?.toString(),
        'next_working_date': entry['next_working_date']?.toString(),
        'fromUser': entry['fromUser']?.toString(),
        'toUser': entry['toUser']?.toString(),
        'companyId': entry['companyId']?.toString(),
        'updated_at': entry['updated_at']?.toString(),
        'updatedAt': entry['updatedAt']?.toString(),
        'remarks': entry['remarks']?.toString(),
      };
      
      // Build fields in isolate to keep UI responsive
      final fields = await compute(_buildAgentFieldsInIsolate, {
        'entry': entryData,
        'isTransfer': isTransfer,
      });
      
      final entityId = entry['id']?.toString();
      final bytes = await buildKeyValueReportPdf(
        format: PdfPageFormat.a4,
        db: widget.db,
        currentUser: currentUser,
        module: 'agent_working',
        entityId: entityId,
        title: title,
        action: 'download',
        fields: fields,
        preloadedBaseFontBytes: baseFontBytes,
        preloadedBoldFontBytes: boldFontBytes,
        preloadedBranding: branding,
      );
      
      if (context != null && context.mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      
      await savePdfBytesToDisk(
        pdfBytes: bytes,
        suggestedBaseName: 'agent_working_${entityId ?? 'detail'}_${fmtTs(DateTime.now())}',
      );
      
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported successfully')),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  
  /// Helper to load font bytes
  Future<Uint8List?> _tryLoadRobotoBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
  
  /// Builds agent fields in isolate to prevent UI blocking
  static List<MapEntry<String, String>> _buildAgentFieldsInIsolate(Map<String, dynamic> args) {
    final entry = args['entry'] as Map<String, dynamic>;
    final isTransfer = args['isTransfer'] as bool;
    
    final fields = <MapEntry<String, String>>[];
    
    fields.add(MapEntry('ID', entry['id']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirements'));
    fields.add(MapEntry('Status', entry['status']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Category', entry['category']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'));
    
    if (entry['transferDate'] != null || entry['transfer_date'] != null) {
      final dateStr = (entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '';
      fields.add(MapEntry('Date', dateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Date', 'N/A'));
    }
    
    if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null) {
      final nextDateStr = (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '';
      fields.add(MapEntry('Next Working Date', nextDateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Next Working Date', 'N/A'));
    }
    
    fields.add(MapEntry('From User', entry['fromUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('To User', entry['toUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Company ID', entry['companyId']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'));
    fields.add(MapEntry('Remarks', entry['remarks']?.toString() ?? 'N/A'));
    
    return fields;
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final entry = widget.entryData;
    final isTransfer = entry['type']?.toString() == 'transfer' ||
        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final title = 'Agent Working Details';
    
    // Prepare data for isolate - convert to serializable format
    final entryData = {
      'id': entry['id']?.toString(),
      'type': entry['type']?.toString(),
      'category': entry['category']?.toString(),
      'status': entry['status']?.toString(),
      'name': entry['name']?.toString(),
      'clientMobile': entry['clientMobile']?.toString(),
      'plotNo': entry['plotNo']?.toString(),
      'registryNumber': entry['registryNumber']?.toString(),
      'transferDate': entry['transferDate']?.toString(),
      'transfer_date': entry['transfer_date']?.toString(),
      'nextWorkingDate': entry['nextWorkingDate']?.toString(),
      'next_working_date': entry['next_working_date']?.toString(),
      'fromUser': entry['fromUser']?.toString(),
      'toUser': entry['toUser']?.toString(),
      'companyId': entry['companyId']?.toString(),
      'updated_at': entry['updated_at']?.toString(),
      'updatedAt': entry['updatedAt']?.toString(),
      'remarks': entry['remarks']?.toString(),
    };
    
    // Build fields in isolate to keep UI responsive
    final fields = await compute(_buildAgentFieldsInIsolate, {
      'entry': entryData,
      'isTransfer': isTransfer,
    });
    
    final currentUser = await loadCurrentUserFromStorage();
    final entityId = entry['id']?.toString();
    return buildKeyValueReportPdf(
      format: format,
      db: widget.db,
      currentUser: currentUser,
      module: 'agent_working',
      entityId: entityId,
      title: title,
      action: 'print',
      fields: fields,
      logHistory: false,
    );
  }

  pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _getAllFields(Map<String, dynamic> entry, bool isTransfer) {
    final fields = <MapEntry<String, String>>[];
    
    fields.add(MapEntry('ID', entry['id']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirements'));
    fields.add(MapEntry('Status', entry['status']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Category', entry['category']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'));
    
    if (entry['transferDate'] != null || entry['transfer_date'] != null) {
      final dateStr = (entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '';
      fields.add(MapEntry('Date', dateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Date', 'N/A'));
    }
    
    if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null) {
      final nextDateStr = (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '';
      fields.add(MapEntry('Next Working Date', nextDateStr.split('T').first.split(' ').first));
    } else {
      fields.add(MapEntry('Next Working Date', 'N/A'));
    }
    
    fields.add(MapEntry('From User', entry['fromUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('To User', entry['toUser']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Company ID', entry['companyId']?.toString() ?? 'N/A'));
    fields.add(MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'));
    fields.add(MapEntry('Remarks', entry['remarks']?.toString() ?? 'N/A'));
    
    return fields;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, IconData icon, List<Widget> children, bool isMobile) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFFFF6B35)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entryData;
    final status = entry['status']?.toString() ?? 'Pending';
    final isTransfer = entry['type']?.toString() == 'transfer' || 
                       (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);
    final statusColor = status == 'Done' 
        ? Colors.green.shade700 
        : status == 'Closed' 
            ? Colors.orange.shade700 
            : Colors.blue.shade700;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back (ESC)',
          ),
          title: Text(
            'Agent Working Details',
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
                colors: [Colors.purple.shade500, Colors.purple.shade400, Colors.purple.shade300],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPdf,
              tooltip: 'Download PDF',
            ),
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printDocument,
              tooltip: 'Print',
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
            border: Border.all(
              color: Colors.grey.shade300.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isMobile = maxWidth < 600;

              final allFields = _getAllFields(entry, isTransfer);
              
              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Center(
                              child: Text(
                                'Agent Working Details',
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 20 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF6B35),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            
                            // Data Table - Use ListView.separated instead of Table.map() to prevent UI blocking
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  // Header row
                                  Container(
                                    decoration: BoxDecoration(color: Colors.grey.shade200),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Field',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Value',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Data rows using ListView.separated for better performance
                                  SizedBox(
                                    height: allFields.length * 50.0 < 400 ? allFields.length * 50.0 : 400,
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: allFields.length,
                                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
                                      itemBuilder: (context, index) {
                                        final field = allFields[index];
                                        final isEven = index % 2 == 0;
                                        return Container(
                                          color: isEven ? Colors.white : Colors.grey.shade50,
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  field.key,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  field.value,
                                                  style: GoogleFonts.poppins(fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

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
  bool _firestoreReady = false;
  Map<String, dynamic>? _editingUser;
  List<Map<String, String>> _companies = [];
  Map<String, dynamic>? _currentUser;
  bool _backfillingUserIds = false;
  bool _backfillUserIdsDone = false;
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  FirestoreSyncState _syncState = FirestoreSyncState();
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
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _guardUnauthorized();
      await _ensureActiveColumns();
      await _loadCurrentUser();
      await _syncUsersFromFirestore();
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
    _firestoreSub?.cancel();
    super.dispose();
  }

  /// Start Firestore listener with pagination for real-time sync
  Future<void> _startFirestoreListener() async {
    if (!FirestoreSyncService().isAvailable) {
      if (mounted) {
        setState(() => _firestoreReady = true);
      }
      return;
    }

    final isSuperAdmin = true;
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) {
        setState(() => _firestoreReady = true);
      }
      return;
    }

    try {
      // Use secure query builder for role-based isolation
      Query query = buildSecureFirestoreQuery(
        collection: 'users',
        currentUser: _currentUser,
        orderBy: 'updatedAt',
        descending: true,
        limit: 50, // Paginated
      );

      _firestoreSub = query.snapshots().listen((snapshot) async {
        final changes = List<DocumentChange>.from(snapshot.docChanges);
        
        if (changes.isNotEmpty) {
          try {
            // Pre-process changes to respect local archived/inactive state
            final processed = <Map<String, dynamic>>[];
            for (final change in changes) {
              final doc = change.doc;
              final data = doc.data() as Map<String, dynamic>;
              final id = (data['id'] ?? doc.id).toString();

              if (change.type == DocumentChangeType.removed) {
                processed.add({
                  'type': 'remove',
                  'id': id,
                  'updatedAt': DateTime.now().toUtc().toIso8601String(),
                });
                continue;
              }

              final status = (data['status'] ?? 'active').toString();
              final cid = (data['company_id'] ?? data['companyId'])?.toString();
              final createdAt = (data['created_at'] ?? data['createdAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
              final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();

              // Check local status to avoid resurrecting archived/inactive records
              String? localStatus;
              try {
                final local = await widget.db.customSelect(
                  'SELECT status FROM users WHERE id = ? LIMIT 1',
                  variables: [d.Variable.withString(id)],
                ).get();
                if (local.isNotEmpty) {
                  localStatus = (local.first.data['status'] ?? '').toString();
                }
              } catch (_) {}

              if (localStatus != null && localStatus.toLowerCase() == 'archived') {
                // Do not overwrite archived locally
                continue;
              }

              // Keep local inactive if remote is active but local was inactive
              final effectiveStatus = (localStatus != null && localStatus.toLowerCase() == 'inactive' && status.toLowerCase() == 'active')
                  ? localStatus
                  : status;

              processed.add({
                'type': 'upsert',
                'id': id,
                'data': data,
                'status': effectiveStatus,
                'cid': cid,
                'createdAt': createdAt,
                'updatedAt': updatedAt,
              });
            }

            await widget.db.batch((batch) {
              for (final item in processed) {
                if (item['type'] == 'remove') {
                  batch.customStatement(
                    'UPDATE users SET is_active = 0, updated_at = ? WHERE id = ?',
                    [item['updatedAt'] as String, item['id'] as String],
                  );
                  continue;
                }

                final data = item['data'] as Map<String, dynamic>;
                final id = item['id'] as String;
                final username = (data['username'] ?? '').toString();
                final userId = (data['user_id'] ?? data['userId'] ?? '').toString();
                final name = (data['name'] ?? '').toString();
                final email = (data['email'] ?? '').toString();
                final contactNo = (data['contact_no'] ?? data['contactNo'] ?? '').toString();
                final permissions = data['permissions'];
                final status = (item['status'] ?? 'active').toString();
                if (status.toLowerCase() == 'archived') {
                  batch.customStatement(
                    "UPDATE users SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                    [item['updatedAt'] as String, id],
                  );
                  continue;
                }
                final cid = item['cid'] as String?;
                final createdAt = item['createdAt'] as String;
                final updatedAt = item['updatedAt'] as String;
                final isActiveRaw = data['is_active'] ?? data['isActive'];
                final isActive = isActiveRaw == null ? 1 : ((isActiveRaw is bool ? (isActiveRaw ? 1 : 0) : int.tryParse(isActiveRaw.toString()) ?? 1));

                batch.customStatement(
                  'INSERT OR REPLACE INTO users (id, username, user_id, name, email, contact_no, permissions, company_id, status, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                  [id, username, userId, name, email, contactNo, permissions != null ? jsonEncode(permissions) : null, cid, status, isActive, createdAt, updatedAt],
                );
              }
            });
            
            // Update UI on main thread
            Future.microtask(() async {
              if (!mounted) return;
              _syncState.startLoading();
              _syncState.finishLoading(synced: true);
              await _load(); // Reload to show updated data
              if (!mounted) return;
              setState(() => _firestoreReady = true);
            });
          } catch (e) {
            debugPrint('Error syncing Firestore changes to SQLite (users): $e');
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
        debugPrint('Firestore listener error (users): $error');
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
      debugPrint('Error starting Firestore listener (users): $e');
      // Handle missing index errors gracefully
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('index') || errorStr.contains('missing')) {
        debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
      }
      if (mounted) {
        setState(() => _firestoreReady = true);
      }
    }
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

  Future<void> _loadCompanies() async {
    try {
      // Ensure required column exists to avoid "no such column" errors
      try {
        await widget.db.customStatement('ALTER TABLE companies ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (_) {}

      if (_currentUser == null) {
        setState(() => _companies = []);
        return;
      }

      final result = await widget.db.customSelect(
        "SELECT id, name FROM companies WHERE status IS NULL OR (status != 'archived' AND status != 'deleted') ORDER BY name",
        readsFrom: {widget.db.companies},
      ).get();
      setState(() {
        _companies = result.map((r) => {
          'id': r.data['id'] as String,
          'name': r.data['name']?.toString() ?? '',
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading companies: $e');
    }
  }

  Future<List<Map<String, String>>> _loadCompaniesForForm() async {
    try {
      // Defensive: ensure column exists before reading
      try {
        await widget.db.customStatement('ALTER TABLE companies ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (_) {}

      if (_currentUser == null) return [];

      final result = await widget.db.customSelect(
        "SELECT id, name FROM companies WHERE status IS NULL OR (status != 'archived' AND status != 'deleted') ORDER BY name",
        readsFrom: {widget.db.companies},
      ).get();
      return result.map((r) => {
        'id': r.data['id'] as String,
        'name': r.data['name']?.toString() ?? '',
      }).toList();
    } catch (e) {
      debugPrint('Error loading companies for form: $e');
      return [];
    }
  }

  // Test method to query user by email
  Future<void> _testQueryUserByEmail(String email) async {
    try {
      debugPrint('\nðŸ” Querying user with email: $email');
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      
      final result = await widget.db.customSelect(
        'SELECT * FROM users WHERE email = ?',
        variables: [d.Variable.withString(email)],
        readsFrom: {widget.db.users},
      ).get();
      
      if (result.isEmpty) {
        debugPrint('âŒ No user found with email: $email');
        debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
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
      
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      
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
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
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
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      
      final result = await widget.db.customSelect(
        'SELECT id, username, email, password_hash, salt, iterations, is_first_login, company_id FROM users WHERE email = ?',
        variables: [d.Variable.withString(email)],
        readsFrom: {widget.db.users},
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
      
      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');
      
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _syncUsersFromFirestore();
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final result = await widget.db.customSelect(
        isSuperAdmin
            ? "SELECT * FROM users WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC"
            : "SELECT * FROM users WHERE company_id = ? AND (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC",
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
        readsFrom: {widget.db.users},
      ).get();
      final rows = result.map((r) => Map<String, dynamic>.from(r.data)).toList();
      await _backfillMissingUserIds(rows);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e2) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        // Fallback if column missing: load without filter to keep UI alive
        try {
          final fallback = await widget.db.customSelect(
            "SELECT * FROM users WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC",
            readsFrom: {widget.db.users},
          ).get();
          final rows = fallback.map((r) => Map<String, dynamic>.from(r.data)).toList();
          await _backfillMissingUserIds(rows);
          setState(() {
            _rows = rows;
          });
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading users: $e2')),
          );
        }
      }
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
        readsFrom: {widget.db.users},
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
            await FirebaseFirestore.instance.collection('users').doc(id).set({
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
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: GoogleFonts.poppins(
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
    String? selectedCompanyId = existing?['company_id']?.toString();
    String selectedRole = 'agent';
    final Map<String, String> modulePermissions = {
      'inventory': 'view_add',
      'agent_working': 'view_add',
      'rental_items': 'view_add',
      'todo': 'view_add',
      'trading': 'view_add',
      'expenditure': 'view_add',
    };
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
          readsFrom: {widget.db.users},
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
          readsFrom: {widget.db.users},
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
          readsFrom: {widget.db.users},
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
        readsFrom: {widget.db.users},
      ).getSingle();
      final cRaw = res.data['c'];
      final c = cRaw is int ? cRaw : int.tryParse(cRaw?.toString() ?? '0') ?? 0;
      return c == 0;
    }

    Future<void> _refreshUserLimit({required String companyId, required StateSetter setLocal}) async {
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
            readsFrom: {widget.db.companies},
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
            readsFrom: {widget.db.users},
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
        final perms = jsonDecode(existing['permissions'].toString());
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

    const moduleDefs = [
      {'key': 'inventory', 'label': 'Inventory'},
      {'key': 'agent_working', 'label': 'Agent Working'},
      {'key': 'rental_items', 'label': 'Rental Items'},
      {'key': 'todo', 'label': 'To-Do'},
      {'key': 'trading', 'label': 'Trading'},
      {'key': 'expenditure', 'label': 'Expenditure'},
    ];

    final roleOptions = const [
      {'value': 'agent', 'label': 'Agent'},
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
                style: GoogleFonts.poppins(
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
                  decoration: _fieldDecoration('Username', isRequired: true, icon: Icons.person),
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
                      decoration: _fieldDecoration('Role', isRequired: true, icon: Icons.badge_outlined),
                      value: selectedRole,
                      items: roleOptions
                          .map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!)))
                          .toList(),
                      onChanged: (value) {
                        setLocal(() {
                          selectedRole = value ?? 'agent';
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
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Company selection (forced to current company for Company Admin)
              if (existing == null)
                FutureBuilder<List<Map<String, String>>>(
                  future: _loadCompaniesForForm(),
                  builder: (context, snapshot) {
                    final companies = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Company', isRequired: true, icon: Icons.business),
                      value: selectedCompanyId,
                      items: [
                        ...companies.map((c) => DropdownMenuItem(
                              value: c['id'],
                              child: Text(c['name'] ?? ''),
                            )),
                      ],
                      onChanged: isCompanyAdmin
                          ? null
                          : (value) {
                              setLocal(() {
                                selectedCompanyId = value;
                                // Regenerate User ID when company changes (new user only)
                                if (existing == null) {
                                  _userIdError = null;
                                  _userIdInitDone = false;
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
                        return null;
                      },
                    );
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
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
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
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                                  Text(moduleLabel, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                              final id = existing != null ? (existing!['id'] as String) : DateTime.now().millisecondsSinceEpoch.toString();
                              final nowIso = DateTime.now().toUtc().toIso8601String();
                              final createdIso = existing == null
                                  ? nowIso
                                  : (existing?['created_at']?.toString() ?? existing?['createdAt']?.toString() ?? nowIso);
                              final name = nameCtl.text.trim();
                              final userId = userIdCtl.text.trim();
                              final email = emailCtl.text.trim();
                              final username = existing == null ? usernameCtl.text.trim() : (existing?['username']?.toString() ?? email);
                              final contactNo = contactCtl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

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
                                    readsFrom: {widget.db.companies},
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
                                    readsFrom: {widget.db.users},
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
                              final modulePermissionsMap = <String, String>{};
                              if (selectedRole == 'agent') {
                                for (final m in moduleDefs) {
                                  final k = m['key']!;
                                  modulePermissionsMap[k] = modulePermissions[k] ?? 'no_access';
                                }
                              }

                              if (selectedRole == 'agent') {
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
                              final permissionsJson = jsonEncode(permissionsMap);

                              // Firestore restore check: see if a deleted/old account exists for this email
                              String restoreUserId = id;
                              String restoreCreatedAt = createdIso;
                              bool restoreFound = false;
                              if (existing == null) {
                                try {
                                  if (Firebase.apps.isNotEmpty) {
                                    final snap = await FirebaseFirestore.instance
                                        .collection('users')
                                        .where('email', isEqualTo: email.toLowerCase())
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
                                  'INSERT INTO users (id, username, password_hash, salt, iterations, user_id, name, email, contact_no, permissions, company_id, status, is_active, is_first_login, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
                                    await FirebaseFirestore.instance.collection('users').doc(restoreUserId).set({
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
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('Firestore sync failed for users/$restoreUserId: $e');
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
                                    final createdAtTs = Timestamp.fromDate(DateTime.tryParse(createdIso)?.toUtc() ?? DateTime.now().toUtc());
                                    final rawExistingStatus = existing == null ? null : existing['status'];
                                    final existingStatus = ((rawExistingStatus?.toString().trim().isNotEmpty) ?? false)
                                        ? rawExistingStatus.toString()
                                        : 'active';
                                    final normalizedStatus = existingStatus.toString().trim().toLowerCase();
                                    final existingIsDeleted = normalizedStatus == 'inactive' || normalizedStatus == 'deleted';
                                    await FirebaseFirestore.instance.collection('users').doc(id).set({
                                      'id': id,
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
                                      'created_at': createdAtTs,
                                      'updated_at': nowIso,
                                    }, SetOptions(merge: true));
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
                                            Text('Company Admin Credentials', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
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
                                                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade900),
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

  InputDecoration _fieldDecoration(
    String label, {
    bool isRequired = false,
    Widget? suffixIcon,
    IconData? icon,
    IconData? fieldIcon,
  }) {
    fieldIcon = fieldIcon ?? icon;
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
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
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
    setState(() {}); // force repaint
    await _load(); // refresh UI immediately after local update

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(id).set(
          {
            'status': nextStatus,
            'isDeleted': !activate,
            'is_deleted': !activate,
            'updated_at': nowIso,
            'updatedByEmail': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Firestore update failed (users toggle): $e');
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
        await FirebaseFirestore.instance.collection('users').doc(id).set(
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
        await FirebaseFirestore.instance.collection('user_audit_logs').add(
          {
            'action': 'user_deleted',
            'target_user_id': id,
            'deleted_at': nowIso,
            'deleted_by_id': _currentUser?['id']?.toString(),
            'deleted_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
            'company_id': targetCompanyId,
            'companyId': targetCompanyId,
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
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text('Reset Password', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Username: $username\nEmail: ${email ?? ''}',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
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
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900),
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
    final isSuperAdmin = true;
    final rows = _q.isEmpty
        ? _rows
        : _rows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Users', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
          // Test buttons - Remove in production
          PopupMenuButton<String>(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Test Queries',
            onSelected: (value) {
              if (value == 'query') {
                _testQueryUserByEmail('ali@gmail.com');
              } else if (value == 'password') {
                _checkUserPasswordInfo('ali@gmail.com');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'query',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18),
                    SizedBox(width: 8),
                    Text('Query User'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 18),
                    SizedBox(width: 8),
                    Text('Check Password Info'),
                  ],
                ),
              ),
            ],
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
                          style: GoogleFonts.poppins(
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
                                  style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
                                    Text('User ID: $normalizedUserId', style: GoogleFonts.poppins(fontSize: 12)),
                                  ],
                                ],
                              ),
                              if (r['email'] != null)
                                Text('Email: ${r['email']}', style: GoogleFonts.poppins(fontSize: 12)),
                              if (r['contact_no'] != null)
                                Text('Contact: ${r['contact_no']}', style: GoogleFonts.poppins(fontSize: 12)),
                              if (r['permissions'] != null)
                                Text(
                                  'Permissions: ${_getPermissionLabel(r['permissions'])}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
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
                              if (value == 'edit') {
                                _showAddFormDialog(existing: r);
                              } else if (value == 'reset') {
                                _resetUserPassword(userId, username, email);
                              } else if (value == 'activate') {
                                await _toggleUserStatus(userId, true);
                              } else if (value == 'deactivate') {
                                await _toggleUserStatus(userId, false);
                              } else if (value == 'delete') {
                                await _deleteUser(r['id'] as String);
                              }
                            },
                          ),
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
}

/// Companies Management Page - Super Admin Only
/// Allows Super Admin to create, edit, activate, and deactivate companies
class CompaniesPage extends StatefulWidget {
  final AppDatabase db;
  const CompaniesPage({super.key, required this.db});
  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  List<Map<String, dynamic>> _rows = [];
  String _q = '';
  bool _loading = true;
  Map<String, dynamic>? _editingCompany;
  Map<String, dynamic>? _currentUser;
  bool _companiesSynced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _guardUnauthorizedCompanies();
      await _ensureActiveColumns();
      await _loadCurrentUser();
      await _load(forceSync: true); // initial sync once, later loads rely on local data unless forced
    });
  }

  void _guardUnauthorizedCompanies() {
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
            content: const Text('You are not authorized to view Companies.'),
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

  Future<void> _ensureActiveColumns() async {
    // Defensive: ensure columns exist to avoid missing-column crashes on filtered queries
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
  }

  Future<void> _loadCurrentUser() async {
    try {
      final s = await AppStorage().readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService().getCurrentUser(authToken);
        if (mounted) {
          setState(() => _currentUser = user);
          _guardUnauthorizedCompanies();
        }
      }
    } catch (_) {}
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

  Future<void> _load({bool forceSync = false}) async {
    setState(() => _loading = true);
    try {
      if (forceSync || !_companiesSynced) {
        await _syncCompaniesFromFirestore(); // keep SQLite fresh before reading
        _companiesSynced = true;
      }

      final result = await widget.db.customSelect(
        "SELECT * FROM companies WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC",
        readsFrom: {widget.db.companies},
      ).get();
      final rows = result.map((r) => r.data).toList();

      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      // Fallback if new columns (e.g., is_active) are missing: load minimal data so UI is not blank
      try {
        final fallback = await widget.db.customSelect(
          "SELECT * FROM companies WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC",
          readsFrom: {widget.db.companies},
        ).get();
        final rows = fallback.map((r) => r.data).toList();
        if (mounted) {
          setState(() {
            _rows = rows;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading companies: $e')),
          );
        }
      }
    }
  }

  void _showAddFormDialog({Map<String, dynamic>? existing}) {
    setState(() {
      _editingCompany = existing;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              _editingCompany = null;
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
                          child: _buildAddCompanyForm(setDialogState, dialogContext),
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
                                _editingCompany = null;
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

  void _resetCompanyForm() {
    setState(() {
      _editingCompany = null;
    });
  }

  Widget _buildAddCompanyForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {
    final existing = _editingCompany;
    final nameCtl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final metadataCtl = TextEditingController(text: existing?['metadata']?.toString() ?? '');
    final logoCtl = TextEditingController(text: existing?['logo_url']?.toString() ?? '');
    final addressCtl = TextEditingController(text: existing?['address']?.toString() ?? '');
    final contactCtl = TextEditingController(text: existing?['contact']?.toString() ?? '');

    final existingTierRaw = existing?['subscription_tier'];
    final existingLimitRaw = existing?['max_user_limit'];
    final existingLimit = existingLimitRaw is int ? existingLimitRaw : int.tryParse(existingLimitRaw?.toString() ?? '');
    String selectedTier = normalizeSubscriptionTier(existingTierRaw);
    if ((existingTierRaw == null || existingTierRaw.toString().trim().isEmpty) && existingLimit != null) {
      if (existingLimit == 5) selectedTier = 'Starter';
      if (existingLimit == 10) selectedTier = 'Professional';
      if (existingLimit == 15) selectedTier = 'Business';
      if (existingLimit >= 16 && existingLimit <= 50) selectedTier = 'Enterprise';
    }
    final enterpriseLimitCtl = TextEditingController(text: (selectedTier == 'Enterprise' ? (existingLimit ?? 15) : 15).toString());

    final rawExistingStatus = existing == null ? null : existing['status'];
    String selectedStatus = rawExistingStatus?.toString() ?? 'active';
    final formKey = GlobalKey<FormState>();

    return StatefulBuilder(
      builder: (context, setLocal) {
        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing == null ? 'Add New Company' : 'Edit Company',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: nameCtl,
                decoration: _fieldDecoration('Company Name', isRequired: true, icon: Icons.business),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Company name is required';
                  }
                  if (value.length > 200) {
                    return 'Maximum 200 characters allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: _fieldDecoration('Status', isRequired: true, icon: Icons.info_outline),
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  setLocal(() {
                    selectedStatus = value ?? 'active';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select status';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: metadataCtl,
                decoration: _fieldDecoration('Metadata (Optional)', icon: Icons.description_outlined),
                maxLines: 3,
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Maximum 500 characters allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: logoCtl,
                decoration: _fieldDecoration('Company Logo URL/Path (Optional)', icon: Icons.image_outlined),
                validator: (value) {
                  if (value != null && value.length > 500) return 'Maximum 500 characters allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressCtl,
                decoration: _fieldDecoration('Company Address (Optional)', icon: Icons.location_on_outlined),
                maxLines: 2,
                validator: (value) {
                  if (value != null && value.length > 500) return 'Maximum 500 characters allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contactCtl,
                decoration: _fieldDecoration('Company Contact (Optional)', icon: Icons.phone_outlined),
                validator: (value) {
                  if (value != null && value.length > 200) return 'Maximum 200 characters allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: _fieldDecoration('Subscription Package', isRequired: true, icon: Icons.workspace_premium_outlined),
                value: selectedTier,
                items: const [
                  DropdownMenuItem(value: 'Starter', child: Text('Starter (Max 5 Agents)')),
                  DropdownMenuItem(value: 'Professional', child: Text('Professional (Max 10 Agents)')),
                  DropdownMenuItem(value: 'Business', child: Text('Business (Max 15 Agents)')),
                  DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise (15 to 50 Agents)')),
                ],
                onChanged: (value) {
                  setLocal(() {
                    selectedTier = normalizeSubscriptionTier(value);
                    if (selectedTier != 'Enterprise') {
                      enterpriseLimitCtl.text = '15';
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please select a package';
                  return null;
                },
              ),
              if (selectedTier == 'Enterprise') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: enterpriseLimitCtl,
                  decoration: _fieldDecoration('Enterprise Agent Limit (15 - 50)', isRequired: true, icon: Icons.people_outline),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enterprise agent limit is required';
                    }
                    final v = int.tryParse(value.trim());
                    if (v == null) return 'Please enter a valid number';
                    if (v < 15 || v > 50) return 'Enterprise limit must be between 15 and 50';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _resetCompanyForm();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                    text: existing == null ? 'Save Company' : 'Update Company',
                    icon: Icons.save,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      
                      try {
                        final id = existing != null 
                            ? (existing!['id'] as String)
                            : DateTime.now().millisecondsSinceEpoch.toString();
                        final nowIso = DateTime.now().toUtc().toIso8601String();
                        final name = nameCtl.text.trim();
                        final metadata = metadataCtl.text.trim();
                        final logoUrl = logoCtl.text.trim();
                        final address = addressCtl.text.trim();
                        final contact = contactCtl.text.trim();
                        final tier = normalizeSubscriptionTier(selectedTier);
                        final enterpriseLimit = int.tryParse(enterpriseLimitCtl.text.trim());
                        final maxUserLimit = subscriptionLimitForTier(tier, enterpriseLimit: enterpriseLimit);
                        final createdAt = existing != null 
                            ? (existing!['created_at']?.toString() ?? nowIso)
                            : nowIso;
                        
                        // Insert or update company using raw SQL
                        if (existing == null) {
                          await widget.db.customStatement(
                            'INSERT INTO companies (id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                            [
                              id,
                              name,
                              selectedStatus,
                              metadata.isEmpty ? null : metadata,
                              logoUrl.isEmpty ? null : logoUrl,
                              address.isEmpty ? null : address,
                              contact.isEmpty ? null : contact,
                              maxUserLimit,
                              tier,
                              createdAt,
                              nowIso,
                            ],
                          );
                        } else {
                          await widget.db.customStatement(
                            'UPDATE companies SET name = ?, status = ?, metadata = ?, logo_url = ?, address = ?, contact = ?, max_user_limit = ?, subscription_tier = ?, updated_at = ? WHERE id = ?',
                            [
                              name,
                              selectedStatus,
                              metadata.isEmpty ? null : metadata,
                              logoUrl.isEmpty ? null : logoUrl,
                              address.isEmpty ? null : address,
                              contact.isEmpty ? null : contact,
                              maxUserLimit,
                              tier,
                              nowIso,
                              id,
                            ],
                          );
                        }

                        try {
                          if (Firebase.apps.isNotEmpty) {
                            await FirebaseFirestore.instance.collection('companies').doc(id).set({
                              'id': id,
                              'name': name,
                              'status': selectedStatus,
                              'metadata': metadata.isEmpty ? null : metadata,
                              'logoUrl': logoUrl.isEmpty ? null : logoUrl,
                              'logo_url': logoUrl.isEmpty ? null : logoUrl,
                              'address': address.isEmpty ? null : address,
                              'contact': contact.isEmpty ? null : contact,
                              'max_user_limit': maxUserLimit,
                              'maxUserLimit': maxUserLimit,
                              'subscription_tier': tier,
                              'subscriptionTier': tier,
                              'created_at': createdAt,
                              'updated_at': nowIso,
                            }, SetOptions(merge: true));
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint('Firestore sync failed for companies/$id: $e');
                          }
                        }
                        
                        // Close modal immediately after save (matching trading form pattern)
                        if (mounted) {
                          final wasAdding = existing == null;
                          final navContext = dialogContext ?? context;
                          Navigator.of(navContext).pop();
                          _resetCompanyForm();
                          await _load();
                          if (wasAdding && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Company added successfully')),
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Company updated successfully')),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save company: $e')),
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

  InputDecoration _fieldDecoration(String label, {IconData? icon, bool isRequired = false}) {
    IconData? fieldIcon = icon ?? Icons.edit_outlined;
    
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
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
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

  Future<void> _deleteCompany(String id) async {
    final ok = await _confirmAction(
      title: 'Delete company',
      message: 'Delete this company from both SQLite and Firestore? This will archive the record and its users.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (!ok) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await widget.db.customStatement(
        "UPDATE companies SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
        [nowIso, id],
      );
      await widget.db.customStatement(
        "UPDATE users SET status = 'archived', is_active = 0, updated_at = ? WHERE company_id = ?",
        [nowIso, id],
      );
    } catch (e) {
      debugPrint('Local archive failed for company $id: $e');
    }

    if (mounted) {
      setState(() {
        _rows.removeWhere((r) => (r['id']?.toString() ?? '') == id);
      });
    }
    await _load();

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(id).set(
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
          },
          SetOptions(merge: true),
        );
        await FirebaseFirestore.instance.collection('company_audit_logs').add({
          'action': 'company_deleted',
          'company_id': id,
          'deleted_at': nowIso,
          'deleted_by_id': _currentUser?['id']?.toString(),
          'deleted_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
        });
      }
    } catch (e) {
      debugPrint('Firestore archive failed for company $id: $e');
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company archived (soft deleted)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final rows = _q.isEmpty
        ? _rows
        : _rows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Companies', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
        label: const Text('Add New Company'),
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
        child: _loading
            ? const ShimmerPageLoading(itemCount: 10)
            : rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No companies found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click the + button to add a new company',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      final status = r['status']?.toString() ?? 'active';
                      final isActive = status == 'active';
                      final companyId = r['id']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            child: Icon(
                              Icons.business,
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: Text(
                            r['name']?.toString() ?? 'N/A',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Inactive',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isActive ? Colors.green : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (r['metadata'] != null && (r['metadata'] as String).isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Metadata available',
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                              if (r['created_at'] != null)
                                Text(
                                  'Created: ${DateFormat('dd MMM yyyy').format(DateTime.parse(r['created_at']))}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: const [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: isActive ? 'deactivate' : 'activate',
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive ? Icons.toggle_off : Icons.toggle_on,
                                      size: 20,
                                      color: isActive ? Colors.orange : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isActive ? 'Deactivate' : 'Activate'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: const [
                                    Icon(Icons.delete, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showAddFormDialog(existing: r);
                              } else if (value == 'activate') {
                                await _toggleCompanyStatus(companyId, true);
                              } else if (value == 'deactivate') {
                                await _toggleCompanyStatus(companyId, false);
                              } else if (value == 'delete') {
                                await _deleteCompany(companyId);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _toggleCompanyStatus(String id, bool activate) async {
    final ok = await _confirmAction(
      title: activate ? 'Activate company' : 'Deactivate company',
      message: 'Are you sure you want to ${activate ? "activate" : "deactivate"} this company?',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      confirmColor: activate ? Colors.green : Colors.orange,
    );
    if (!ok) return;

    final newStatus = activate ? 'active' : 'inactive';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Always update local SQLite first so UI reflects change even if remote fails
    try {
      await widget.db.customStatement(
        'UPDATE companies SET status = ?, is_active = ?, updated_at = ? WHERE id = ?',
        [newStatus, activate ? 1 : 0, nowIso, id],
      );
    } catch (_) {}

    // Attempt Firestore, but do not block UI if it fails
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(id).set(
          {
            'status': newStatus,
            'is_active': activate ? 1 : 0,
            'isDeleted': !activate,
            'is_deleted': !activate,
            'updated_at': nowIso,
            'updated_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Swallow Firestore errors to avoid red banners; local state already updated.
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company ${activate ? "activated" : "deactivated"} successfully')),
      );
    }
  }
}
