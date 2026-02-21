import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// REMOVED: Firestore dependencies for SQLite-only operation
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
// Add back minimal Firebase imports for helper methods to work
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import '../../core/services/auth_service.dart';
import '../../shimmer_widgets.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart' show InfoEntry, buildResponsiveInfoRow;
// REMOVED: Firestore services for SQLite-only operation
// import '../../core/services/firestore_cache_service.dart';
// import '../../firestore_sync_service.dart';
// Add back FirestoreSyncService for helper methods to work
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
  // REMOVED: Firestore-related state variables for SQLite-only operation
  // bool _firestoreReady = false;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _currentUser;
  // Firestore sync state for SQLite-only operation
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

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd MMM yyyy').format(_selectedDate);
    Future.microtask(() async {
      if (!mounted) return;
      await _loadCurrentUser();
      // REMOVED: Firestore verification for SQLite-only operation
      // await _verifyFirestoreReady();
      await _loadTasks();
    });
  }

  /// Verify Firestore is ready (ToDo aggregates from multiple sources)
  Future<void> _verifyFirestoreReady() async {
    if (!mounted) return;
    if (!FirestoreSyncService().isAvailable) {
      if (!mounted) return;
      // REMOVED: Firestore state for SQLite-only operation
                // setState(() => _firestoreReady = true);
      return;
    }

    // For ToDo, we aggregate from trading_file_entries, trading_entries, and working_progress
    // Check if at least one source is accessible
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
        if (!mounted) return;
        // REMOVED: Firestore state for SQLite-only operation
                // setState(() => _firestoreReady = true);
        return;
      }

      // Quick check to verify Firestore is accessible
      await FirebaseFirestore.instance
          .collection('trading_entries')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));
      
      if (!mounted) return;
      // REMOVED: Firestore state for SQLite-only operation
                // setState(() => _firestoreReady = true);
    } catch (e) {
      // If Firestore check fails, still allow UI to show (data may be in SQLite)
      if (!mounted) return;
      // REMOVED: Firestore state for SQLite-only operation
                // setState(() => _firestoreReady = true);
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
