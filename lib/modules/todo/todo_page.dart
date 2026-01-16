import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import '../../core/services/auth_service.dart';
import '../../shimmer_widgets.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart' show InfoEntry, buildResponsiveInfoRow;
import '../../core/services/firestore_cache_service.dart';
import '../../firestore_sync_service.dart';
import '../../responsive_widgets.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../core/shared_utils.dart' show TopRightSearch;
import '../../core/phone_actions.dart';

class ToDoPage extends StatefulWidget {
  final AppDatabase db;
  const ToDoPage({super.key, required this.db});
  @override
  State<ToDoPage> createState() => _ToDoPageState();
}

class _ToDoPageState extends State<ToDoPage> {
  final List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  bool _firestoreReady = false;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _currentUser;
  FirestoreSyncState _syncState = FirestoreSyncState();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd MMM yyyy').format(_selectedDate);
    Future.microtask(() async {
      if (!mounted) return;
      await _loadCurrentUser();
      await _verifyFirestoreReady();
      await _loadTasks();
    });
  }

  /// Verify Firestore is ready (ToDo aggregates from multiple sources)
  Future<void> _verifyFirestoreReady() async {
    if (!mounted) return;
    if (!FirestoreSyncService().isAvailable) {
      if (!mounted) return;
      setState(() => _firestoreReady = true);
      return;
    }

    // For ToDo, we aggregate from trading_file_entries, trading_entries, and working_progress
    // Check if at least one source is accessible
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        if (!mounted) return;
        setState(() => _firestoreReady = true);
        return;
      }

      // Quick check to verify Firestore is accessible
      await FirebaseFirestore.instance
          .collection('trading_entries')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));
      
      if (!mounted) return;
      setState(() => _firestoreReady = true);
    } catch (e) {
      // If Firestore check fails, still allow UI to show (data may be in SQLite)
      if (!mounted) return;
      setState(() => _firestoreReady = true);
    }
  }

  Future<void> _loadCurrentUser() async {
    if (!mounted) return;
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final authService = AuthService();
        final user = await authService.getCurrentUser(authToken);
        if (!mounted) return;
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _pickDate() async {
    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      if (!mounted) return;
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd MMM yyyy').format(picked);
      });
      await _loadTasks();
    }
  }


  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final tasks = <Map<String, dynamic>>[];
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final isAgent = RoleUtils.isAgent(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final myUserId = _currentUser?['id']?.toString();
      final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;


      // Load Trading Form entries
      try {
        final tradingFormResults = await widget.db.customSelect(
          isSuperAdmin
              ? 'SELECT * FROM trading_entries WHERE date(date) = ? ORDER BY date ASC'
              : (isAgent
                  ? 'SELECT * FROM trading_entries WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND date(date) = ? ORDER BY date ASC'
                  : 'SELECT * FROM trading_entries WHERE company_id = ? AND date(date) = ? ORDER BY date ASC'),
          variables: [
            if (!isSuperAdmin) d.Variable.withString(companyId!),
            if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId ?? ''),
            if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias ?? myUserId ?? ''),
            d.Variable.withString(selectedDateStr),
          ],
        ).get();
        
        for (final row in tradingFormResults) {
          final data = row.data;
          final type = data['type'] == 'buy' ? 'Buy' : 'Sell';
          final status = data['status'] ?? 'Pending';
          tasks.add({
            'id': 'trading_form_${data['id']}',
            'source': 'Trading Form',
            'type': type,
            'title': '$type - ${data['estate_name'] ?? 'N/A'}',
            'mobile': data['mobile']?.toString(),
            'subtitle': 'Mobile: ${data['mobile'] ?? 'N/A'} | Payment: ${data['payment'] ?? 0} | Status: $status',
            'status': status,
            'module': 'trading_form',
            'originalId': data['id'],
          });
        }
      } catch (e) {
        // Table might not exist yet
      }

      // Load Trading File entries
      try {
        final tradingFileResults = await widget.db.customSelect(
          isSuperAdmin
              ? 'SELECT * FROM trading_file_entries WHERE date(date) = ? ORDER BY date ASC'
              : (isAgent
                  ? 'SELECT * FROM trading_file_entries WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND date(date) = ? ORDER BY date ASC'
                  : 'SELECT * FROM trading_file_entries WHERE company_id = ? AND date(date) = ? ORDER BY date ASC'),
          variables: [
            if (!isSuperAdmin) d.Variable.withString(companyId!),
            if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId ?? ''),
            if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias ?? myUserId ?? ''),
            d.Variable.withString(selectedDateStr),
          ],
        ).get();
        
        for (final row in tradingFileResults) {
          final data = row.data;
          final type = data['type'] == 'buy' ? 'Buy' : 'Sell';
          final status = data['status'] ?? 'Pending';
          tasks.add({
            'id': 'trading_file_${data['id']}',
            'source': 'Trading File',
            'type': type,
            'title': '$type - ${data['estate'] ?? 'N/A'}',
            'mobile': data['mobile']?.toString(),
            'subtitle': 'Mobile: ${data['mobile'] ?? 'N/A'} | Payment: ${data['payment'] ?? 0} | Status: $status',
            'status': status,
            'module': 'trading_file',
            'originalId': data['id'],
          });
        }
      } catch (e) {
        // Table might not exist yet
      }

      // Load Agent Working entries
      try {
        final workingResults = await widget.db.customSelect(
          isSuperAdmin
              ? 'SELECT * FROM working_progress WHERE date(transfer_date) = ? ORDER BY transfer_date ASC'
              : 'SELECT * FROM working_progress WHERE company_id = ? AND date(transfer_date) = ? ORDER BY transfer_date ASC',
          variables: [
            if (!isSuperAdmin) d.Variable.withString(companyId!),
            d.Variable.withString(selectedDateStr),
          ],
        ).get();
        
        for (final row in workingResults) {
          final data = row.data;
          final name = data['name'] ?? 'N/A';
          final status = data['status'] ?? 'Pending';
          tasks.add({
            'id': 'working_${data['id']}',
            'source': 'Agent Working',
            'type': 'Transfer',
            'title': name,
            'mobile': data['clientMobile']?.toString(),
            'subtitle': 'Mobile: ${data['clientMobile'] ?? 'N/A'} | Status: $status | From: ${data['from_user'] ?? 'N/A'} | To: ${data['to_user'] ?? 'N/A'}',
            'status': status,
            'module': 'working',
            'originalId': data['id'],
          });
        }
      } catch (e) {
        // Table might not exist yet
      }

      
      if (!mounted) return;
      setState(() {
        _tasks.clear();
        _tasks.addAll(tasks);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tasks: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    // Green for Closed/Completed/Done
    if (statusLower == 'closed' || statusLower == 'completed' || statusLower == 'done') {
      return Colors.green.shade700;
    }
    // Orange/Red for Open/Due Today/Pending
    if (statusLower == 'open' || statusLower == 'due today' || statusLower == 'pending' || statusLower == 'scheduled') {
      return Colors.orange.shade700;
    }
    return Colors.grey.shade700;
  }
  
  Color _getStatusBackgroundColor(String status) {
    final statusLower = status.toLowerCase();
    // Green background for Closed/Completed/Done
    if (statusLower == 'closed' || statusLower == 'completed' || statusLower == 'done') {
      return Colors.green.shade700;
    }
    // Orange/Red background for Open/Due Today/Pending
    if (statusLower == 'open' || statusLower == 'due today' || statusLower == 'pending' || statusLower == 'scheduled') {
      return Colors.orange.shade700;
    }
    return Colors.grey.shade700;
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'Trading Form':
        return Icons.receipt_long;
      case 'Trading File':
        return Icons.folder;
      case 'Agent Working':
        return Icons.work;
      default:
        return Icons.task;
    }
  }

  
  List<Map<String, dynamic>> get _filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    final query = _searchQuery.toLowerCase();
    return _tasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final subtitle = (task['subtitle'] ?? '').toString().toLowerCase();
      final source = (task['source'] ?? '').toString().toLowerCase();
      final type = (task['type'] ?? '').toString().toLowerCase();
      final status = (task['status'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          subtitle.contains(query) ||
          source.contains(query) ||
          type.contains(query) ||
          status.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
            child: TopRightSearch(
              hintText: 'Search tasks...',
              onChanged: (q) {
                if (!mounted) return;
                setState(() => _searchQuery = q.toLowerCase());
              },
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
              const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
              const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dateController,
                            readOnly: true,
                            onTap: _pickDate,
                            decoration: InputDecoration(
                              labelText: 'Select Date',
                              hintText: 'Tap to select date',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF23272E)
          : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Select Date'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2), // Blue
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.today),
                          tooltip: 'Today',
                          onPressed: () {
                            if (!mounted) return;
                            setState(() {
                              _selectedDate = DateTime.now();
                              _dateController.text = DateFormat('dd MMM yyyy').format(_selectedDate);
                            });
                            _loadTasks();
                          },
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final filteredTasks = _filteredTasks;
                      return Expanded(
                        child: Column(
                          children: [
                            if (_tasks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? '${_tasks.length} task${_tasks.length == 1 ? '' : 's'} scheduled for ${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                                      : '${filteredTasks.length} of ${_tasks.length} task${_tasks.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: filteredTasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isNotEmpty ? Icons.search_off : Icons.checklist,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No tasks found for "$_searchQuery"'
                                        : 'No tasks scheduled for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tasks from Trading and Agent Working modules will appear here',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filteredTasks.length,
                                itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              final status = task['status'] as String? ?? 'Pending';
                              final statusColor = _getStatusColor(status);
                              final sourceIcon = _getSourceIcon(task['source'] as String);
                              
                              final statusBgColor = _getStatusBackgroundColor(status);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title - Most prominent
                                      Text(
                                        task['title'] as String? ?? 'N/A',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Details - Smaller and lighter
                                      GestureDetector(
                                        onTap: () {
                                          final mobile = task['mobile']?.toString() ?? '';
                                          if (mobile.trim().isNotEmpty) {
                                            showPhoneActionSheet(context, mobile);
                                          }
                                        },
                                        child: Text(
                                          task['subtitle'] as String? ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w400,
                                            decoration: (task['mobile'] ?? '').toString().trim().isNotEmpty
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Status pills with high-contrast backgrounds
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          // Source badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.blue.shade200, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(sourceIcon, size: 14, color: Colors.blue.shade700),
                                                const SizedBox(width: 6),
                                                Text(
                                                  task['source'] as String? ?? '',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status badge with high-contrast background
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: statusBgColor,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              status,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            // Sync indicator - show only when syncing
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

class RemindersPage extends StatefulWidget {
  final AppDatabase db;
  const RemindersPage({super.key, required this.db});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _firestoreReady = false;
  List<Map<String, String>> _agents = [];
  bool _showAddSidebar = false;
  Map<String, dynamic>? _editingReminder;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _currentUser;
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  FirestoreSyncState _syncState = FirestoreSyncState();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await _loadCurrentUser();
      await _startFirestoreListener();
      await _load();
    });
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startFirestoreListener() async {
    if (!mounted) return;
    if (!FirestoreSyncService().isAvailable) {
      if (!mounted) return;
      setState(() => _firestoreReady = true);
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (!mounted) return;
      setState(() => _firestoreReady = true);
      return;
    }

    try {
      // Use secure query builder for role-based isolation with agent filtering
      Query query = buildSecureFirestoreQuery(
        collection: 'reminders',
        currentUser: _currentUser,
        orderBy: 'reminder_date',
        descending: true,
        limit: 50, // Paginated
        additionalAgentFilter: isAgent ? 'agent_id' : null,
      );

      try {
        _firestoreSub = query.snapshots().listen((snapshot) async {
          final changes = List<DocumentChange>.from(snapshot.docChanges);
          
          if (changes.isNotEmpty) {
            try {
              await widget.db.batch((batch) {
                for (final change in changes) {
                  final doc = change.doc;
                  final data = doc.data() as Map<String, dynamic>;
                  final id = (data['reminder_id'] ?? data['id'] ?? doc.id).toString();
                  
                  if (change.type == DocumentChangeType.removed) {
                    batch.customStatement(
                      'UPDATE reminders SET is_active = 0, updated_at = ? WHERE reminder_id = ?',
                      [DateTime.now().toUtc().toIso8601String(), id],
                    );
                    continue;
                  }

                  // Sync reminder data to SQLite
                  final agentId = (data['agent_id'] ?? '').toString();
                  final clientName = (data['client_name'] ?? '').toString();
                  final clientPhone = (data['client_phone'] ?? '').toString();
                  final reminderTitle = (data['reminder_title'] ?? '').toString();
                  final reminderDetails = (data['reminder_details'] ?? '').toString();
                  final reminderDate = (data['reminder_date'] ?? '').toString();
                  final reminderTime = (data['reminder_time'] ?? '').toString();
                  final notificationStatus = (data['notification_status'] ?? 'Pending').toString();
                  final cid = (data['company_id'] ?? data['companyId'])?.toString();
                  final createdAt = (data['created_at'] ?? data['createdAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
                  final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();
                  final isActiveRaw = data['is_active'] ?? data['isActive'];
                  final isActive = isActiveRaw == null ? 1 : ((isActiveRaw is bool ? (isActiveRaw ? 1 : 0) : int.tryParse(isActiveRaw.toString()) ?? 1));

                  batch.customStatement(
                    'INSERT OR REPLACE INTO reminders (reminder_id, agent_id, client_name, client_phone, reminder_title, reminder_details, reminder_date, reminder_time, notification_status, company_id, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    [id, agentId, clientName, clientPhone, reminderTitle, reminderDetails, reminderDate, reminderTime, notificationStatus, cid, isActive, createdAt, updatedAt],
                  );
                }
              });
              
              // Update UI on main thread
              Future.microtask(() async {
                if (!mounted) return;
                _syncState.startLoading();
                _syncState.finishLoading(synced: true);
                await _load(); // Reload from SQLite to reflect Firestore changes
                if (!mounted) return;
                setState(() => _firestoreReady = true);
              });
            } catch (e) {
              debugPrint('Error syncing reminders from Firestore: $e');
              Future.microtask(() {
                if (!mounted) return;
                _syncState.finishLoading(synced: false);
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
          debugPrint('Firestore listener error (reminders): $error');
          // Handle missing index errors gracefully
          final errorStr = error.toString().toLowerCase();
          if (errorStr.contains('index') || errorStr.contains('missing')) {
            debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
          }
          Future.microtask(() {
            if (!mounted) return;
            setState(() => _firestoreReady = true);
            _syncState.finishLoading(synced: false);
          });
        });
      } catch (e) {
        debugPrint('Error creating Firestore snapshots listener (reminders): $e');
        // Handle missing index errors gracefully
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
        if (!mounted) return;
        setState(() => _firestoreReady = true);
      }
    } catch (e) {
      debugPrint('Error starting Firestore listener (reminders): $e');
      // Handle missing index errors gracefully
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('index') || errorStr.contains('missing')) {
        debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
      }
      if (!mounted) return;
      setState(() => _firestoreReady = true);
    }
  }

  List<Map<String, dynamic>> get _filteredRows {
    if (_searchQuery.isEmpty) return _rows;
    final query = _searchQuery.toLowerCase();
    return _rows.where((reminder) {
      final title = (reminder['reminder_title'] ?? '').toString().toLowerCase();
      final clientName = (reminder['client_name'] ?? '').toString().toLowerCase();
      final clientPhone = (reminder['client_phone'] ?? '').toString().toLowerCase();
      final details = (reminder['reminder_details'] ?? '').toString().toLowerCase();
      final status = (reminder['notification_status'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          clientName.contains(query) ||
          clientPhone.contains(query) ||
          details.contains(query) ||
          status.contains(query);
    }).toList();
  }

  Future<void> _loadCurrentUser() async {
    if (!mounted) return;
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService().getCurrentUser(authToken);
        if (!mounted) return;
        setState(() {
          _currentUser = user;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      if (!mounted) return;
      setState(() => _loading = true);
      
      // Small delay to ensure database write is committed
      await Future.delayed(const Duration(milliseconds: 100));
      
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final isAgent = RoleUtils.isAgent(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final myUserId = _currentUser?['id']?.toString();

      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        if (!mounted) return;
        setState(() {
          _rows = [];
          _agents = [];
          _loading = false;
        });
        return;
      }

      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT reminder_id, agent_id, client_name, client_phone, reminder_title, reminder_details, reminder_date, reminder_time, notification_status, created_at, updated_at FROM reminders WHERE is_active = 1 ORDER BY reminder_date DESC, reminder_time DESC'
            : (isAgent
                ? 'SELECT reminder_id, agent_id, client_name, client_phone, reminder_title, reminder_details, reminder_date, reminder_time, notification_status, created_at, updated_at FROM reminders WHERE company_id = ? AND agent_id = ? AND is_active = 1 ORDER BY reminder_date DESC, reminder_time DESC'
                : 'SELECT reminder_id, agent_id, client_name, client_phone, reminder_title, reminder_details, reminder_date, reminder_time, notification_status, created_at, updated_at FROM reminders WHERE company_id = ? AND is_active = 1 ORDER BY reminder_date DESC, reminder_time DESC'),
        variables: isSuperAdmin
            ? []
            : [
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId ?? ''),
              ],
        readsFrom: {widget.db.reminders},
      ).get();

      final ag = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, username FROM users WHERE is_active = 1 ORDER BY username'
            : 'SELECT id, username FROM users WHERE company_id = ? AND is_active = 1 ORDER BY username',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],
        readsFrom: {widget.db.users},
      ).get();
      
      if (!mounted) return;
      setState(() {
        _rows = res.map((r) => r.data).toList();
        _agents = ag.map((r) => {'id': r.data['id'] as String, 'name': (r.data['username']?.toString()) ?? ''}).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading reminders: $e')),
      );
    }
  }

  void _toggleAddSidebar({Map<String, dynamic>? existing}) {
    final isAgent = RoleUtils.isAgent(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final can = existing == null
        ? PermissionHelper.canAddModule(_currentUser, 'reminders')
        : PermissionHelper.canEditModule(_currentUser, 'reminders');
    if (!can) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (existing != null && isAgent && myUserId != null && myUserId.isNotEmpty) {
      final existingAgentId = existing['agent_id']?.toString();
      if (existingAgentId != null && existingAgentId.isNotEmpty && existingAgentId != myUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _showAddSidebar = !_showAddSidebar;
      _editingReminder = existing;
    });
    // Ensure agents are loaded when opening sidebar
    if (_showAddSidebar && _agents.isEmpty) {
      _load();
    }
  }

  Widget _buildAddReminderSidebar() {
    final existing = _editingReminder;
    // PERMANENT REQUIREMENT: When editing, load ALL existing data exactly as saved
    final clientNameCtl = TextEditingController(text: existing?['client_name']?.toString() ?? '');
    final clientPhoneCtl = TextEditingController(text: existing?['client_phone']?.toString() ?? '');
    final titleCtl = TextEditingController(text: existing?['reminder_title']?.toString() ?? '');
    final detailsCtl = TextEditingController(text: existing?['reminder_details']?.toString() ?? '');
    final dateCtl = TextEditingController(text: existing?['reminder_date']?.toString() ?? '');
    final timeCtl = TextEditingController(text: existing?['reminder_time']?.toString() ?? '');
    
    // Focus nodes for Tab navigation
    final clientNameFocus = FocusNode();
    final clientPhoneFocus = FocusNode();
    final titleFocus = FocusNode();
    final detailsFocus = FocusNode();
    final dateFocus = FocusNode();
    final timeFocus = FocusNode();
    final agentFocus = FocusNode();
    final statusFocus = FocusNode();
    
    // Initialize state variables outside builder to persist across rebuilds
    final existingStatus = existing?['notification_status']?.toString() ?? 'Pending';
    final statusState = ValueNotifier<String>(existingStatus);
    // Initialize agentId - use existing if editing, otherwise default to first agent
    // Ensure we always have a valid agent ID if agents are available
    String? initialAgentId;
    if (existing != null && existing['agent_id'] != null) {
      initialAgentId = existing['agent_id']?.toString();
    } else if (_agents.isNotEmpty) {
      initialAgentId = _agents.first['id'];
    }
    final agentIdState = ValueNotifier<String?>(initialAgentId);
    
    return StatefulBuilder(
      builder: (context, setLocal) {
        
        return FocusScope(
          child: Container(
            width: 550,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    existing == null ? 'Add Reminder' : 'Edit Reminder',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: clientNameCtl,
                        focusNode: clientNameFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(clientPhoneFocus),
                        decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: clientPhoneCtl,
                        focusNode: clientPhoneFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(titleFocus),
                        decoration: const InputDecoration(labelText: 'Client Phone', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtl,
                        focusNode: titleFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(detailsFocus),
                        decoration: const InputDecoration(labelText: 'Reminder Title', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: detailsCtl,
                        focusNode: detailsFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(dateFocus),
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: dateCtl,
                        focusNode: dateFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(timeFocus),
                        decoration: const InputDecoration(labelText: 'Reminder Date (YYYY-MM-DD)', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: timeCtl,
                        focusNode: timeFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(agentFocus),
                        decoration: const InputDecoration(labelText: 'Reminder Time (HH:mm)', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      ),
                      const SizedBox(height: 6),
          Builder(
                        builder: (context) {
                          // Ensure agentIdState has a value if agents are available
                          if (agentIdState.value == null || agentIdState.value!.isEmpty) {
                            if (_agents.isNotEmpty) {
                              agentIdState.value = _agents.first['id'];
                            }
                          }
                          
                          if (_agents.isEmpty) {
                            return TextField(
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Agent *',
                                border: OutlineInputBorder(),
                                hintText: 'No agents available',
                                helperText: 'Please create a user/agent first',
                              ),
                            );
                          }
                          
                          return ValueListenableBuilder<String?>(
                            valueListenable: agentIdState,
                            builder: (context, currentAgentId, _) {
                              // Use current value or default to first agent
                              final selectedAgentId = currentAgentId ?? _agents.first['id'];
                              
                              return DropdownButtonFormField<String>(
                                value: selectedAgentId,
                                items: _agents.map((agent) {
                                  return DropdownMenuItem<String>(
                                    value: agent['id'],
                                    child: Text(agent['name'] ?? agent['id'] ?? ''),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    agentIdState.value = v;
                                    setLocal(() {});
                                    FocusScope.of(context).requestFocus(statusFocus);
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Agent *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                isExpanded: true,
                              );
                            },
                          );
                        },
          ),
                      const SizedBox(height: 12),
          ValueListenableBuilder<String>(
                        valueListenable: statusState,
                        builder: (context, status, _) {
                          return DropdownButtonFormField<String>(
                            value: status.isEmpty ? 'Pending' : status,
                            items: const [
                              DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'Sent', child: Text('Sent')),
                            ],
                            onChanged: (v) {
                              statusState.value = v ?? 'Pending';
                              setLocal(() {});
                              FocusScope.of(context).requestFocus(clientNameFocus);
                            },
                            decoration: const InputDecoration(labelText: 'Notification Status', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (!mounted) return;
                          setState(() { _showAddSidebar = false; _editingReminder = null; });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!mounted) return;
                          try {
                            final isAgentUser = RoleUtils.isAgent(_currentUser);
                            final myUserId = _currentUser?['id']?.toString();
                            final canSave = existing == null
                                ? PermissionHelper.canAddModule(_currentUser, 'reminders')
                                : PermissionHelper.canEditModule(_currentUser, 'reminders');
                            if (!canSave) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
                                );
                              }
                              return;
                            }
                            if (existing != null && isAgentUser && myUserId != null && myUserId.isNotEmpty) {
                              final existingAgentId = existing['agent_id']?.toString();
                              if (existingAgentId != null && existingAgentId.isNotEmpty && existingAgentId != myUserId) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
                                  );
                                }
                                return;
                              }
                            }
                            // PERMANENT REQUIREMENT: Data only saves when Save button is clicked, not on every change
    final nowIso = DateTime.now().toUtc().toIso8601String();
                            final currentStatus = statusState.value;
                            final currentAgentId = agentIdState.value;
                            
                            // Ensure agentId is set (required field)
                            // Get from state first, then try first agent, then existing
                            String? finalAgentId = currentAgentId;
                            
                            // If no agent selected, try to get from first available agent
                            if (finalAgentId == null || finalAgentId.isEmpty) {
                              if (_agents.isNotEmpty) {
                                finalAgentId = _agents.first['id']?.toString();
                              } else if (existing != null && existing['agent_id'] != null) {
                                finalAgentId = existing['agent_id']?.toString();
                              }
                            }
                            
                            // Final check - if still no agent, show error
                            if (finalAgentId == null || finalAgentId.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot save: No agents available. Please create a user/agent first.'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                              return;
                            }

                            if (isAgentUser) {
                              if (myUserId == null || myUserId.trim().isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
                                  );
                                }
                                return;
                              }
                              finalAgentId = myUserId;
                            }
                            
                            // Required fields must have values (use defaults if empty)
                            final reminderTitle = titleCtl.text.trim().isNotEmpty 
                                ? titleCtl.text.trim() 
                                : 'Untitled Reminder';
                            final reminderDate = dateCtl.text.trim().isNotEmpty 
                                ? dateCtl.text.trim() 
                                : DateTime.now().toIso8601String().split('T')[0];
                            final reminderTime = timeCtl.text.trim().isNotEmpty 
                                ? timeCtl.text.trim() 
                                : '00:00';
                            
                            // PERMANENT REQUIREMENT: Use insertOnConflictUpdate to UPDATE existing record, not create duplicate
                            final reminderId = existing?['reminder_id'] as int?;
                            final existingCreatedAt = existing?['created_at']?.toString() ?? nowIso;
                            final String? companyId = RoleUtils.getUserCompanyId(_currentUser)?.toString();
                            final d.Value<String?> companyValue = (!RoleUtils.isSuperAdmin(_currentUser) && companyId != null && companyId.isNotEmpty)
                                ? d.Value<String?>(companyId)
                                : const d.Value<String?>.absent();
                            
                            final companion = reminderId == null
                                ? RemindersCompanion.insert(
                                    agentId: finalAgentId,
                                    reminderTitle: reminderTitle,
                                    reminderDate: reminderDate,
                                    reminderTime: reminderTime,
                                    notificationStatus: currentStatus,
                                    companyId: companyValue,
                                    createdAt: nowIso,
                                    updatedAt: nowIso,
                                    // PERMANENT REQUIREMENT: Only save optional fields with data (don't save empty fields)
                                    clientName: clientNameCtl.text.trim().isNotEmpty 
                                        ? d.Value(clientNameCtl.text.trim()) 
                                        : const d.Value.absent(),
                                    clientPhone: clientPhoneCtl.text.trim().isNotEmpty 
                                        ? d.Value(clientPhoneCtl.text.trim()) 
                                        : const d.Value.absent(),
                                    reminderDetails: detailsCtl.text.trim().isNotEmpty 
                                        ? d.Value(detailsCtl.text.trim()) 
                                        : const d.Value.absent(),
                                  )
                                : RemindersCompanion(
                                    reminderId: d.Value(reminderId),
                                    agentId: d.Value(finalAgentId),
                                    reminderTitle: d.Value(reminderTitle),
                                    reminderDate: d.Value(reminderDate),
                                    reminderTime: d.Value(reminderTime),
                                    notificationStatus: d.Value(currentStatus),
                                    companyId: companyValue,
                                    createdAt: d.Value(existingCreatedAt), // Preserve original created_at
                                    updatedAt: d.Value(nowIso),
                                    // PERMANENT REQUIREMENT: Only update optional fields that have data (don't save empty fields)
                                    clientName: clientNameCtl.text.trim().isNotEmpty 
                                        ? d.Value(clientNameCtl.text.trim()) 
                                        : const d.Value.absent(),
                                    clientPhone: clientPhoneCtl.text.trim().isNotEmpty 
                                        ? d.Value(clientPhoneCtl.text.trim()) 
                                        : const d.Value.absent(),
                                    reminderDetails: detailsCtl.text.trim().isNotEmpty 
                                        ? d.Value(detailsCtl.text.trim()) 
                                        : const d.Value.absent(),
                                  );
                            
                            // Save to database
                            await widget.db.into(widget.db.reminders).insertOnConflictUpdate(companion);
                            
                            // Close sidebar and clear editing state
                            if (!mounted) return;
                            setState(() { 
                              _showAddSidebar = false; 
                              _editingReminder = null; 
                            });
                            
                            // Force a small delay to ensure database commit
                            await Future.delayed(const Duration(milliseconds: 50));
                            
                            // Reload data to refresh the list
                            if (!mounted) return;
                            await _load();
                            
                            // Show success message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(existing == null ? 'Reminder saved successfully' : 'Reminder updated successfully'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e, stackTrace) {
                            if (mounted) {
                              debugPrint('Error saving reminder: $e');
                              debugPrint('Stack trace: $stackTrace');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error saving reminder: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35), // Orange
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Save', style: TextStyle(color: Colors.white)),
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
    );
  }

  Future<void> _markDone(int id) async {
    if (!mounted) return;
    if (!PermissionHelper.canEditModule(_currentUser, 'reminders')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final check = await widget.db.customSelect(
      'SELECT agent_id, company_id FROM reminders WHERE reminder_id = ? LIMIT 1',
      variables: [d.Variable.withInt(id)],
      readsFrom: {widget.db.reminders},
    ).get();
    if (check.isEmpty) return;
    final m = check.first.data;
    final rowAgentId = (m['agent_id'] ?? '').toString();
    final rowCompanyId = (m['company_id'] ?? '').toString();
    if (!isSuperAdmin && companyId != null && companyId.isNotEmpty && rowCompanyId.isNotEmpty && rowCompanyId != companyId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (isAgent && myUserId != null && myUserId.isNotEmpty && rowAgentId.isNotEmpty && rowAgentId != myUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    await widget.db.customStatement('UPDATE reminders SET notification_status = ? WHERE reminder_id = ?', ['Sent', id]);
    await _load();
  }

  Future<void> _delete(int id) async {
    if (!mounted) return;
    if (!PermissionHelper.canDeleteModule(_currentUser, 'reminders')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final check = await widget.db.customSelect(
      'SELECT agent_id, company_id FROM reminders WHERE reminder_id = ? LIMIT 1',
      variables: [d.Variable.withInt(id)],
      readsFrom: {widget.db.reminders},
    ).get();
    if (check.isEmpty) return;
    final m = check.first.data;
    final rowAgentId = (m['agent_id'] ?? '').toString();
    final rowCompanyId = (m['company_id'] ?? '').toString();
    if (!isSuperAdmin && companyId != null && companyId.isNotEmpty && rowCompanyId.isNotEmpty && rowCompanyId != companyId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (isAgent && myUserId != null && myUserId.isNotEmpty && rowAgentId.isNotEmpty && rowAgentId != myUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.db.customStatement(
        'UPDATE reminders SET is_active = 0, updated_at = ? WHERE reminder_id = ?',
        [DateTime.now().toUtc().toIso8601String(), id],
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reminders', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
            child: TopRightSearch(
              hintText: 'Search reminders...',
              onChanged: (q) {
                if (!mounted) return;
                setState(() => _searchQuery = q.toLowerCase());
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _toggleAddSidebar(),
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          return Stack(
            children: [
              Row(
                children: [
                  if (_showAddSidebar && !isMobile) _buildAddReminderSidebar(),
                  Expanded(
                    child: Container(
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
                      child: Stack(
                        children: [
                          Builder(
                              builder: (context) {
                                final filtered = _filteredRows;
                                if (filtered.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.notifications_none,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No reminders found for "$_searchQuery"'
                                              : 'No reminders found',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final r = filtered[i];
                                    final TextStyle infoStyle = TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFFFF6B35),
                                    );
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
                                                    r['reminder_title']?.toString() ?? 'N/A',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (PermissionHelper.canEditModule(_currentUser, 'reminders') || PermissionHelper.canDeleteModule(_currentUser, 'reminders'))
                                                  PopupMenuButton(
                                                    icon: const Icon(Icons.more_vert),
                                                    itemBuilder: (context) => [
                                                      if (PermissionHelper.canEditModule(_currentUser, 'reminders'))
                                                        PopupMenuItem(
                                                          child: const Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                                                          onTap: () => Future.delayed(const Duration(milliseconds: 100), () {
                                                            if (!mounted) return;
                                                            _toggleAddSidebar(existing: r);
                                                          }),
                                                        ),
                                                      if (PermissionHelper.canDeleteModule(_currentUser, 'reminders'))
                                                        PopupMenuItem(
                                                          child: const Row(children: [Icon(Icons.delete_forever, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                                                          onTap: () => Future.delayed(const Duration(milliseconds: 100), () {
                                                            if (!mounted) return;
                                                            _delete(r['reminder_id'] as int);
                                                          }),
                                                        ),
                                                      if (PermissionHelper.canEditModule(_currentUser, 'reminders') && r['notification_status'] != 'Sent')
                                                        PopupMenuItem(
                                                          child: const Row(children: [Icon(Icons.done, size: 18), SizedBox(width: 8), Text('Mark as Done')]),
                                                          onTap: () => Future.delayed(const Duration(milliseconds: 100), () {
                                                            if (!mounted) return;
                                                            _markDone(r['reminder_id'] as int);
                                                          }),
                                                        ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            buildResponsiveInfoRow(
                                              context,
                                              [
                                                InfoEntry('Client', r['client_name'], style: infoStyle),
                                                InfoEntry('Phone', r['client_phone'], style: infoStyle),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            buildResponsiveInfoRow(
                                              context,
                                              [
                                                InfoEntry('Date', r['reminder_date'], style: const TextStyle(fontSize: 14)),
                                                InfoEntry('Time', r['reminder_time'], style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                            Text('Status: ${r['notification_status']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          // Sync indicator - show only when syncing
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
                    ),
                        ],
              ),
              if (_showAddSidebar && constraints.maxWidth < 900)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (!mounted) return;
                      setState(() => _showAddSidebar = false);
                    },
                    child: Container(color: Colors.black54),
                  ),
                ),
              if (_showAddSidebar && constraints.maxWidth < 900)
                Center(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildAddReminderSidebar(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

bool _isCompactCard(BoxConstraints constraints) => constraints.maxWidth < 640;

double _responsiveFieldWidth(BoxConstraints constraints) =>
    _isCompactCard(constraints) ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;

Widget _responsiveInfoBox(
  BoxConstraints constraints,
  String label,
  Object? value, {
  TextStyle? style,
}) {
  final rawValue = value?.toString();
  final displayValue = (rawValue == null || rawValue.trim().isEmpty) ? 'N/A' : rawValue.trim();
  final textStyle = style ??
      TextStyle(
        fontSize: 14,
        color: const Color(0xFFFF6B35),
      );
  return SizedBox(
    width: _responsiveFieldWidth(constraints),
    child: Text(
      '$label: $displayValue',
      style: textStyle,
    ),
  );
}

// _InfoEntry and buildResponsiveInfoRow moved to lib/core/shared_utils.dart
