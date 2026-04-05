import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart';
// REMOVED: Firestore dependencies for SQLite-only operation
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
// Add back minimal Firebase imports for helper methods to work
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../../../core/role_utils.dart' as local;
import 'package:drift/drift.dart' as d;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import '../../../core/services/auth_service.dart';
import '../../../shimmer_widgets.dart';
import '../../../core/app_utils.dart';
import '../../../core/shared_utils.dart' show InfoEntry, buildResponsiveInfoRow;
// REMOVED: Firestore services for SQLite-only operation
// import '../../core/services/firestore_cache_service.dart';
// import '../../firestore_sync_service.dart';
// Add back FirestoreSyncService for helper methods to work
import '../../../firestore_sync_service.dart';
import '../../../responsive_widgets.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../../../core/phone_actions.dart';
import '../view_models/todo_view_model.dart';
import '../repositories/todo_repository_impl.dart';
import '../widgets/reminder_dialog.dart';

class ToDoPage extends StatefulWidget {
  final AppDatabase db;
  const ToDoPage({super.key, required this.db});
  @override
  State<ToDoPage> createState() => _ToDoPageState();
}

class _ToDoPageState extends State<ToDoPage> {
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
    
    // Load current user first, then trigger initial data fetch
    _loadCurrentUser().then((_) {
      if (mounted) {
        _triggerInitialDataLoad();
      }
    });
  }

  /// Trigger initial data load for TodoViewModel
  void _triggerInitialDataLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (_currentUser == null) {
        debugPrint('TodoPage: Cannot load tasks - no current user');
        return;
      }
      
      final userId = _currentUser!['id']?.toString() ?? '';
      final companyId = local.RoleUtils.getUserCompanyId(_currentUser);
      
      debugPrint('TodoPage: Triggering initial data load for user: $userId, company: $companyId, date: $_selectedDate');
      
      // Trigger initial data fetch on the global TodoViewModel instance
      Provider.of<TodoViewModel>(context, listen: false).loadTasks(userId, companyId);
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
      final isSuperAdmin = local.RoleUtils.isSuperAdmin(_currentUser);
      final companyId = local.RoleUtils.getUserCompanyId(_currentUser);
      
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
        _currentUser = await AuthService.getCurrentUser(authToken);
        if (!mounted) return;
        setState(() {
          _currentUser = _currentUser;
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
      // Update ViewModel with new date before loading tasks
      Provider.of<TodoViewModel>(context, listen: false).setSelectedDate(_selectedDate);
      await _loadTasks();
    }
  }


  Future<void> _loadTasks() async {
    if (!mounted) return;
    if (_currentUser == null) return;
    
    final userId = _currentUser!['id']?.toString() ?? '';
    final companyId = local.RoleUtils.getUserCompanyId(_currentUser);
    
    debugPrint('TodoPage: Loading tasks for user: $userId, company: $companyId, date: $_selectedDate');
    
    // Call the global TodoViewModel's loadTasks method
    await Provider.of<TodoViewModel>(context, listen: false).loadTasks(userId, companyId);
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

  

  @override
  void dispose() {
    _dateController.dispose();
    _searchController.dispose();
    // TODO: Dispose TodoViewModel from global provider if needed
    super.dispose();
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => ReminderDialog(
        selectedDate: _selectedDate,
        onAddReminder: ({
          required String title,
          String? description,
          required DateTime reminderDate,
          required TimeOfDay reminderTime,
          String? clientName,
          String? clientPhone,
          String priority = 'Medium',
        }) async {
          final userId = _currentUser!['id']?.toString() ?? '';
          final companyId = local.RoleUtils.getUserCompanyId(_currentUser);
          
          await Provider.of<TodoViewModel>(context, listen: false).addReminder(
            userId: userId,
            companyId: companyId,
            title: title,
            description: description,
            reminderDate: reminderDate,
            reminderTime: reminderTime,
            clientName: clientName,
            clientPhone: clientPhone,
            priority: priority,
          );
        },
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
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
            // Title with delete button
            Row(
              children: [
                Expanded(
                  child: Text(
                    reminder.reminderTitle,
                    style: AppFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await Provider.of<TodoViewModel>(context, listen: false).deleteReminder(reminder.reminderId);
                    } else if (value == 'toggle') {
                      await Provider.of<TodoViewModel>(context, listen: false).toggleReminderStatus(
                        reminder.reminderId, 
                        !reminder.is_active,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(reminder.is_active ? 'Mark Inactive' : 'Mark Active'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            if (reminder.reminderDetails != null && reminder.reminderDetails!.isNotEmpty)
              Text(
                reminder.reminderDetails!,
                style: AppFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            const SizedBox(height: 8),
            // Date, Time, and Client info
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${reminder.reminderDate} at ${reminder.reminderTime}',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (reminder.clientName != null || reminder.clientPhone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${reminder.clientName ?? 'N/A'} | ${reminder.clientPhone ?? 'N/A'}',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Status badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Manual reminder badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_alert, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Manual Reminder',
                        style: AppFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: reminder.is_active ? Colors.green.shade700 : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    reminder.is_active ? 'Active' : 'Inactive',
                    style: AppFonts.poppins(
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
  }

  Widget _buildAggregatedTaskCard(Map<String, dynamic> task) {
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
            // Title with menu button
            Row(
              children: [
                Expanded(
                  child: Text(
                    task['title'] as String? ?? 'N/A',
                    style: AppFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) async {
                    final taskId = task['id'];
                    final category = task['category'] ?? task['source'];
                    
                    if (value == 'delete') {
                      // For aggregated tasks, show a message directing to original module
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please delete this $category task from the original module'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else if (value == 'toggle') {
                      // For aggregated tasks, show a message directing to original module
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please update status from the original $category module'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text('Update Status'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
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
                style: AppFonts.poppins(
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
                        style: AppFonts.poppins(
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
                    style: AppFonts.poppins(
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Vertical Separator "Cut" - Creates the separation line between main header and module
        const SizedBox(height: 12),
        
        // To-Do Module Content
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              title: Text('To-Do', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
                      Provider.of<TodoViewModel>(context, listen: false).setSearchQuery(q);
                    },
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // 1. MUST wrap the scroll view in Expanded to prevent bottom overflow
                Expanded(
                  child: SingleChildScrollView(
                    // 2. Makes the entire page scrollable
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Your Date Picker / Header UI goes here
                        _buildHeader(),
                        
                        // 3. The inner ListView MUST be shrink-wrapped
                        _buildTaskList(),
                      ],
                    ),
                  ),
                ),
                // 4. Pagination stays safely at the bottom, outside the scroll view
                _buildPaginationCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
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
                Provider.of<TodoViewModel>(context, listen: false).setSelectedDate(_selectedDate);
                _loadTasks();
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _showAddReminderDialog,
              icon: const Icon(Icons.add_alert),
              label: const Text('Add Task'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35), // Orange
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Consumer<TodoViewModel>(
          builder: (context, viewModel, child) {
            final allTasks = viewModel.allTasks;
            
            if (allTasks.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  viewModel.searchQuery.isEmpty
                      ? '${allTasks.length} task${allTasks.length == 1 ? '' : 's'} scheduled for ${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                      : '${allTasks.length} task${allTasks.length == 1 ? '' : 's'} found',
                  style: AppFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    return Consumer<TodoViewModel>(
      builder: (context, viewModel, child) {
        final allTasks = viewModel.allTasks;
        
        if (allTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  viewModel.searchQuery.isNotEmpty ? Icons.search_off : Icons.checklist,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.searchQuery.isNotEmpty
                      ? 'No tasks found for "${viewModel.searchQuery}"'
                      : 'No tasks scheduled for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                  style: AppFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (viewModel.searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tasks from Trading and Agent Working modules will appear here',
                    style: AppFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true, // CRITICAL
          physics: const NeverScrollableScrollPhysics(), // CRITICAL
          itemCount: allTasks.length,
          itemBuilder: (context, index) {
            final task = allTasks[index];
            
            if (task is Reminder) {
              return _buildReminderCard(task);
            } else if (task is Map<String, dynamic>) {
              return _buildAggregatedTaskCard(task);
            }
            
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildPaginationCard() {
    // Placeholder for pagination - can be implemented later
    return const SizedBox.shrink();
  }
}
