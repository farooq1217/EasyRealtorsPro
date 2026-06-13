import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // Add missing widgets import
import 'dart:async';
import 'package:shared/shared.dart';
import '../repositories/todo_repository.dart';
import '../repositories/todo_repository_impl.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/services/notification_service.dart';

enum TaskSortOption {
  latestFirst,
  priorityHigh,
  priorityLow,
  alphabetical,
}

class TodoViewModel extends ChangeNotifier {
  final TodoRepository _repository;
  final NotificationService _notificationService;
  
  // Stream subscriptions
  StreamSubscription<List<Reminder>>? _remindersSubscription;
  
  // Current user state
  Map<String, dynamic>? _currentUser;
  
  TodoViewModel({TodoRepository? repository, NotificationService? notificationService}) 
      : _repository = repository ?? TodoRepositoryImpl(AppDatabase.instanceIfInitialized!),
        _notificationService = notificationService ?? NotificationService() {
    _mounted = true;
  }

  // State
  List<Reminder> _reminders = [];
  List<Map<String, dynamic>> _aggregatedTasks = [];
  bool _loading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  TaskSortOption _sortOption = TaskSortOption.latestFirst;
  String _searchQuery = '';
  bool _mounted = false; // Add missing mounted field
  
  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  // Getters
  List<Reminder> get reminders => _reminders;
  List<Map<String, dynamic>> get aggregatedTasks => _aggregatedTasks;
  bool get loading => _loading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  TaskSortOption get sortOption => _sortOption;
  String get searchQuery => _searchQuery;

  // New getters for notification filtering
  List<Reminder> get unreadReminders => _reminders.where((r) => !(r.isRead ?? false)).toList();
  List<Reminder> get readReminders => _reminders.where((r) => r.isRead ?? false).toList();
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (allTasks.length / _itemsPerPage).ceil();
  List<dynamic> get paginatedTasks {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return allTasks.skip(startIndex).take(_itemsPerPage).toList();
  }
  
  // Combined and filtered tasks
  List<dynamic> get allTasks {
    final combined = <dynamic>[..._reminders, ..._aggregatedTasks];
    Logger.debug('TodoViewModel: allTasks getter - reminders: ${_reminders.length}, aggregated: ${_aggregatedTasks.length}, combined: ${combined.length}', tag: 'TodoViewModel');
    final filtered = _searchQuery.isEmpty 
        ? combined 
        : combined.where((task) => _matchesSearch(task)).toList();
    
    Logger.debug('TodoViewModel: allTasks getter - filtered: ${filtered.length}', tag: 'TodoViewModel');
    return _sortTasks(filtered);
  }

  bool _matchesSearch(dynamic task) {
    final query = _searchQuery.toLowerCase();
    
    if (task is Reminder) {
      return task.reminderTitle.toLowerCase().contains(query) ||
             (task.reminderDetails?.toLowerCase().contains(query) ?? false) ||
             (task.clientName?.toLowerCase().contains(query) ?? false);
    } else if (task is Map<String, dynamic>) {
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
    }
    
    return false;
  }

  List<dynamic> _sortTasks(List<dynamic> tasks) {
    switch (_sortOption) {
      case TaskSortOption.latestFirst:
        tasks.sort((a, b) {
          DateTime? dateA, dateB;
          
          if (a is Reminder) {
            // Safely parse reminder date and time (handles "9:00 AM" format)
            final datePart = DateTime.tryParse(a.reminderDate);
            DateTime? timePart;
            final match = RegExp(r'(\d{1,2}):(\d{2})\s*([APMapm]{2})?').firstMatch(a.reminderTime);
            if (datePart != null && match != null) {
              int hour = int.parse(match.group(1)!);
              int minute = int.parse(match.group(2)!);
              final meridiem = match.group(3);
              if (meridiem != null) {
                final lower = meridiem.toLowerCase();
                if (lower == 'pm' && hour < 12) hour += 12;
                if (lower == 'am' && hour == 12) hour = 0;
              }
              timePart = DateTime(datePart.year, datePart.month, datePart.day, hour, minute);
            }
            dateA = timePart ?? datePart;
          } else if (a is Map<String, dynamic>) {
            // Try to extract date from aggregated task
            final dateStr = a['date']?.toString() ?? a['transfer_date']?.toString();
            if (dateStr != null) {
              dateA = DateTime.tryParse(dateStr);
            }
          }
          
          if (b is Reminder) {
            // Safely parse reminder date and time (handles "9:00 AM" format)
            final datePart = DateTime.tryParse(b.reminderDate);
            DateTime? timePart;
            final match = RegExp(r'(\d{1,2}):(\d{2})\s*([APMapm]{2})?').firstMatch(b.reminderTime);
            if (datePart != null && match != null) {
              int hour = int.parse(match.group(1)!);
              int minute = int.parse(match.group(2)!);
              final meridiem = match.group(3);
              if (meridiem != null) {
                final lower = meridiem.toLowerCase();
                if (lower == 'pm' && hour < 12) hour += 12;
                if (lower == 'am' && hour == 12) hour = 0;
              }
              timePart = DateTime(datePart.year, datePart.month, datePart.day, hour, minute);
            }
            dateB = timePart ?? datePart;
          } else if (b is Map<String, dynamic>) {
            // Try to extract date from aggregated task
            final dateStr = b['date']?.toString() ?? b['transfer_date']?.toString();
            if (dateStr != null) {
              dateB = DateTime.tryParse(dateStr);
            }
          }
          
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          
          return dateB.compareTo(dateA); // Latest first
        });
        break;
        
      case TaskSortOption.priorityHigh:
        // For reminders, we could add priority field later
        // For now, keep original order
        break;
        
      case TaskSortOption.priorityLow:
        // For reminders, we could add priority field later
        // For now, keep original order
        break;
        
      case TaskSortOption.alphabetical:
        tasks.sort((a, b) {
          String titleA, titleB;
          
          if (a is Reminder) {
            titleA = a.reminderTitle;
          } else if (a is Map<String, dynamic>) {
            titleA = a['title']?.toString() ?? '';
          } else {
            titleA = '';
          }
          
          if (b is Reminder) {
            titleB = b.reminderTitle;
          } else if (b is Map<String, dynamic>) {
            titleB = b['title']?.toString() ?? '';
          } else {
            titleB = '';
          }
          
          return titleA.compareTo(titleB);
        });
        break;
    }
    
    return tasks;
  }

  // Actions
  Future<void> loadTasks(String userId, String? companyId) async {
    _setLoading(true);
    _error = null;
    
    Logger.debug('TodoViewModel: Loading tasks for user: $userId, company: $companyId, date: $_selectedDate', tag: 'TodoViewModel');
    
    // Cancel existing subscription
    await _remindersSubscription?.cancel();
    
    try {
      // Set up stream for reminders with thread-safe UI updates
      _remindersSubscription = _repository.getRemindersForDate(userId, companyId, _selectedDate).listen(
        (reminders) {
          // THREAD SAFETY: Wrap UI updates in postFrameCallback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_mounted) return;
            
            Logger.debug('TodoViewModel: Stream update received - ${reminders.length} reminders', tag: 'TodoViewModel');
            for (final reminder in reminders) {
              Logger.debug('TodoViewModel: Reminder - ${reminder.reminderTitle} at ${reminder.reminderDate}', tag: 'TodoViewModel');
            }
            _reminders = reminders;
            Logger.debug('TodoViewModel: _reminders assigned with ${reminders.length} items', tag: 'TodoViewModel');
            notifyListeners();
            Logger.debug('TodoViewModel: UI notified of update', tag: 'TodoViewModel');
          });
        },
        onError: (e, stackTrace) {
          // THREAD SAFETY: Wrap error handling in postFrameCallback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_mounted) return;
            
            Logger.error('TodoViewModel: Stream error', tag: 'TodoViewModel', error: e, stackTrace: stackTrace);
            _error = e.toString();
            notifyListeners();
          });
        },
      );
      
      Logger.debug('TodoViewModel: Stream subscription set up', tag: 'TodoViewModel');
      
      // Load aggregated tasks (one-time load)
      await _loadAggregatedTasks(userId, companyId);
    } catch (e) {
      Logger.error('TodoViewModel: Error loading tasks', tag: 'TodoViewModel', error: e);
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadAggregatedTasks(String userId, String? companyId) async {
    try {
      Logger.debug('TodoViewModel: Loading aggregated tasks for user: $userId, company: $companyId, date: $_selectedDate', tag: 'TodoViewModel');
      _aggregatedTasks = await _repository.getAggregatedTasksForDate(
        userId, 
        companyId, 
        _selectedDate,
      );
      Logger.debug('TodoViewModel: _aggregatedTasks assigned with ${_aggregatedTasks.length} items', tag: 'TodoViewModel');
      for (final task in _aggregatedTasks) {
        Logger.debug('TodoViewModel: Task - ${task['title']} at ${task['date']}', tag: 'TodoViewModel');
      }
      notifyListeners();
      Logger.debug('TodoViewModel: UI notified after aggregated tasks load', tag: 'TodoViewModel');
    } catch (e) {
      Logger.error('TodoViewModel: Error loading aggregated tasks', tag: 'TodoViewModel', error: e);
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Mark a reminder as read
  Future<void> markAsRead(int reminderId) async {
    try {
      await _repository.markAsRead(reminderId);
      // The stream should emit updated reminders; ensure UI refresh
      Logger.debug('TodoViewModel: Marked reminder $reminderId as read', tag: 'TodoViewModel');
    } catch (e) {
      Logger.error('TodoViewModel: Error marking reminder as read', tag: 'TodoViewModel', error: e);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addReminder({
    required String userId,
    required String? companyId,
    required String title,
    String? description,
    required DateTime reminderDate,
    required TimeOfDay reminderTime,
    String? clientName,
    String? clientPhone,
    String priority = 'Medium',
  }) async {
    try {
      Logger.debug('TodoViewModel: Adding reminder - Title: $title, Date: $reminderDate, Time: $reminderTime', tag: 'TodoViewModel');
      
      final reminder = Reminder(
        reminderId: -1, // Will be set by database
        agentId: userId,
        companyId: companyId,
        clientName: clientName,
        clientPhone: clientPhone,
        reminderTitle: title,
        reminderDetails: description,
        reminderDate: reminderDate.toIso8601String().split('T')[0],
        reminderTime: '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}',
        notificationStatus: 'Pending',
        is_active: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        isRead: false,
        isSynced: true,
      );

      Logger.debug('TodoViewModel: Calling repository.addReminder', tag: 'TodoViewModel');
      await _repository.addReminder(reminder);
      Logger.debug('TodoViewModel: Repository.addReminder completed successfully', tag: 'TodoViewModel');
      
      // FOOLPROOF FIX: Manually fetch fresh data and update state
      // Refresh both reminders and aggregated tasks
      final freshAggregatedTasks = await _repository.getAggregatedTasksForDate(
        userId,
        companyId,
        _selectedDate,
      );
      
      _aggregatedTasks = freshAggregatedTasks;
      Logger.debug('TodoViewModel: Manual refresh completed after addReminder - aggregated: ${freshAggregatedTasks.length} items', tag: 'TodoViewModel');
      
      // Also refresh reminders to ensure the new reminder appears
      final freshReminders = await _repository.getRemindersForDateFuture(userId, companyId, _selectedDate);
      _reminders = freshReminders;
      Logger.debug('TodoViewModel: Manual refresh completed after addReminder - reminders: ${freshReminders.length} items', tag: 'TodoViewModel');
      
      notifyListeners(); // Force UI rebuild immediately
      
      // Schedule notification
      try {
        // Generate a unique notification ID based on reminder data
        final notificationId = reminderDate.millisecondsSinceEpoch;
        
        await _notificationService.scheduleReminder(
          id: notificationId,
          title: title,
          body: description ?? '',
          scheduledDate: reminderDate,
          scheduledTime: reminderTime,
        );
        Logger.debug('TodoViewModel: Notification scheduled successfully', tag: 'TodoViewModel');
      } catch (e) {
        Logger.error('TodoViewModel: Failed to schedule notification', tag: 'TodoViewModel', error: e);
      }
      Logger.debug('TodoViewModel: Add reminder process completed - waiting for stream update', tag: 'TodoViewModel');
      // Note: No need to manually reload tasks since the stream will automatically update
      // The database insert will trigger the stream to emit new data
    } catch (e) {
      Logger.error('TodoViewModel: Error adding reminder', tag: 'TodoViewModel', error: e);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    try {
      await _repository.updateReminder(reminder);
      
      // FOOLPROOF FIX: Manually fetch fresh data and update state
      final freshTasks = await _repository.getAggregatedTasksForDate(
        reminder.agentId,
        reminder.companyId,
        _selectedDate,
      );
      
      _aggregatedTasks = freshTasks;
      Logger.debug('TodoViewModel: Manual refresh completed after updateReminder - ${freshTasks.length} items', tag: 'TodoViewModel');
      notifyListeners(); // Force UI rebuild immediately
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteReminder(int reminderId) async {
    try {
      await _repository.deleteReminder(reminderId);
      
      // FOOLPROOF FIX: Manually fetch fresh data and update state
      // Refresh both reminders and aggregated tasks
      final freshAggregatedTasks = await _repository.getAggregatedTasksForDate(
        _currentUser?['id']?.toString() ?? '',
        _currentUser?['companyId']?.toString(),
        _selectedDate,
      );
      
      _aggregatedTasks = freshAggregatedTasks;
      Logger.debug('TodoViewModel: Manual refresh completed after deleteReminder - aggregated: ${freshAggregatedTasks.length} items', tag: 'TodoViewModel');
      
      // Also refresh reminders to ensure the deleted reminder is removed
      final freshReminders = await _repository.getRemindersForDateFuture(
        _currentUser?['id']?.toString() ?? '',
        _currentUser?['companyId']?.toString(),
        _selectedDate,
      );
      
      _reminders = freshReminders;
      Logger.debug('TodoViewModel: Manual refresh completed after deleteReminder - reminders: ${freshReminders.length} items', tag: 'TodoViewModel');
      
      notifyListeners(); // Force UI rebuild immediately
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleReminderStatus(int reminderId, bool isActive) async {
    try {
      await _repository.toggleReminderStatus(reminderId, isActive);
      
      // FOOLPROOF FIX: Manually fetch fresh data and update state
      final freshTasks = await _repository.getAggregatedTasksForDate(
        _currentUser?['id']?.toString() ?? '',
        _currentUser?['companyId']?.toString(),
        _selectedDate,
      );
      
      _aggregatedTasks = freshTasks;
      Logger.debug('TodoViewModel: Manual refresh completed after toggleReminderStatus - ${freshTasks.length} items', tag: 'TodoViewModel');
      notifyListeners(); // Force UI rebuild immediately
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Update reminder status (Pending/Active/Inactive)
  Future<void> updateReminderStatus(int reminderId, String newStatus) async {
    try {
      await _repository.updateReminderStatus(reminderId, newStatus);
      
      // FOOLPROOF FIX: Manually fetch fresh data and update state
      // Refresh both reminders and aggregated tasks
      final freshAggregatedTasks = await _repository.getAggregatedTasksForDate(
        _currentUser?['id']?.toString() ?? '',
        _currentUser?['companyId']?.toString(),
        _selectedDate,
      );
      
      _aggregatedTasks = freshAggregatedTasks;
      Logger.debug('TodoViewModel: Manual refresh completed after updateReminderStatus - aggregated: ${freshAggregatedTasks.length} items', tag: 'TodoViewModel');
      
      // Also refresh reminders to ensure the updated reminder status is reflected
      final freshReminders = await _repository.getRemindersForDateFuture(
        _currentUser?['id']?.toString() ?? '',
        _currentUser?['companyId']?.toString(),
        _selectedDate,
      );
      
      _reminders = freshReminders;
      Logger.debug('TodoViewModel: Manual refresh completed after updateReminderStatus - reminders: ${freshReminders.length} items', tag: 'TodoViewModel');
      
      notifyListeners(); // Force UI rebuild immediately
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1; // Reset to page 1 when search changes
    notifyListeners();
  }

  void setSortOption(TaskSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  // Pagination methods
  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  void setItemsPerPage(int limit) {
    if (_itemsPerPage != limit) {
      _itemsPerPage = limit;
      _currentPage = 1; // Reset to page 1 when items per page changes
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _remindersSubscription?.cancel();
    super.dispose();
  }
}
