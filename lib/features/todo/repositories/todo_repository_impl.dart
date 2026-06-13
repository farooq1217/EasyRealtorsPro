import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared/shared.dart';
import 'todo_repository.dart';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import '../../../core/services/firebase_threading_handler.dart';

class TodoRepositoryImpl implements TodoRepository {
  final AppDatabase _db;

  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  TodoRepositoryImpl(this._db);

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('TodoRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'TodoRepository $streamName',
      );
    }
    return stream;
  }

  @override
  Stream<List<Reminder>> getReminders(String userId, String? companyId) {
    Stream<List<Reminder>> stream;
    if (companyId == null) {
      stream = (_db.select(_db.reminders)
            ..where((tbl) => 
                tbl.agentId.equals(userId) &
                tbl.is_active.equals(true)))
          .watch();
    } else {
      stream = (_db.select(_db.reminders)
            ..where((tbl) => 
                tbl.agentId.equals(userId) &
                tbl.companyId.equals(companyId) &
                tbl.is_active.equals(true)))
          .watch();
    }
    return _wrapStreamWithThreadSafety(stream, 'getReminders');
  }

  @override
  Stream<List<Reminder>> getRemindersForDate(String userId, String? companyId, DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    Stream<List<Reminder>> stream;
    if (companyId == null) {
      stream = (_db.select(_db.reminders)
            ..where((tbl) => 
                tbl.agentId.equals(userId) &
                tbl.reminderDate.equals(dateStr) &
                tbl.is_active.equals(true)))
          .watch();
    } else {
      stream = (_db.select(_db.reminders)
            ..where((tbl) => 
                tbl.agentId.equals(userId) &
                tbl.companyId.equals(companyId) &
                tbl.reminderDate.equals(dateStr) &
                tbl.is_active.equals(true)))
          .watch();
    }
    return _wrapStreamWithThreadSafety(stream, 'getRemindersForDate');
  }

  @override
  Future<List<Reminder>> getRemindersForDateFuture(String userId, String? companyId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    if (companyId == null) {
      return await (_db.select(_db.reminders)
            ..where((tbl) => 
                tbl.agentId.equals(userId) &
                tbl.reminderDate.equals(dateStr) &
                tbl.is_active.equals(true)))
          .get();
    } else {
      return await (_db.select(_db.reminders)
            ..where((tbl) => 
                tbl.agentId.equals(userId) &
                tbl.companyId.equals(companyId) &
                tbl.reminderDate.equals(dateStr) &
                tbl.is_active.equals(true)))
          .get();
    }
  }

  @override
  Future<void> addReminder(Reminder reminder) async {
    try {
      debugPrint('TodoRepository: Inserting reminder - Title: ${reminder.reminderTitle}, Date: ${reminder.reminderDate}');
      
      await _db.into(_db.reminders).insert(
        RemindersCompanion.insert(
          agentId: reminder.agentId,
          companyId: d.Value(reminder.companyId),
          clientName: d.Value(reminder.clientName),
          clientPhone: d.Value(reminder.clientPhone),
          reminderTitle: reminder.reminderTitle,
          reminderDetails: d.Value(reminder.reminderDetails),
          reminderDate: reminder.reminderDate,
          reminderTime: reminder.reminderTime,
          notificationStatus: reminder.notificationStatus,
          is_active: d.Value(reminder.is_active),
          isSynced: d.Value(reminder.isSynced),
          createdAt: reminder.createdAt,
          updatedAt: reminder.updatedAt,
        ),
      );
      
      debugPrint('TodoRepository: Reminder inserted successfully');
    } catch (e) {
      debugPrint('TodoRepository: Error inserting reminder: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateReminder(Reminder reminder) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.reminderId.equals(reminder.reminderId)))
        .write(RemindersCompanion(
      clientName: d.Value(reminder.clientName),
      clientPhone: d.Value(reminder.clientPhone),
      reminderTitle: d.Value(reminder.reminderTitle),
      reminderDetails: d.Value(reminder.reminderDetails),
      reminderDate: d.Value(reminder.reminderDate),
      reminderTime: d.Value(reminder.reminderTime),
      notificationStatus: d.Value(reminder.notificationStatus),
      is_active: d.Value(reminder.is_active),
      isSynced: d.Value(reminder.isSynced),
      updatedAt: d.Value(DateTime.now().toIso8601String()),
    ));
  }

  @override
  Future<void> deleteReminder(int reminderId) async {
    await (_db.delete(_db.reminders)..where((tbl) => tbl.reminderId.equals(reminderId))).go();
  }

  @override
  Future<void> toggleReminderStatus(int reminderId, bool isActive) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.reminderId.equals(reminderId)))
        .write(RemindersCompanion(
      is_active: d.Value(isActive),
      updatedAt: d.Value(DateTime.now().toIso8601String()),
    ));
  }

  @override
  Future<void> markAsRead(int reminderId) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.reminderId.equals(reminderId)))
        .write(RemindersCompanion(

      updatedAt: d.Value(DateTime.now().toIso8601String()),
    ));
  }



  @override
  Future<void> updateReminderStatus(int reminderId, String newStatus) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.reminderId.equals(reminderId)))
        .write(RemindersCompanion(
      notificationStatus: d.Value(newStatus),
      updatedAt: d.Value(DateTime.now().toIso8601String()),
    ));
  }

  @override
  Future<List<Map<String, dynamic>>> getAggregatedTasksForDate(
    String userId,
    String? companyId,
    DateTime date,
  ) async {
    final selectedDateStr = date.toIso8601String().split('T')[0];
    debugPrint('TodoRepository: Getting aggregated tasks for date: $selectedDateStr');
    final tasks = <Map<String, dynamic>>[];

    // Check if user is super admin or agent
    final user = await (_db.select(_db.users)
          ..where((tbl) => tbl.id.equals(userId)))
        .getSingleOrNull();
    
    if (user == null) return tasks;

    final isSuperAdmin = user.role == 'super_admin';
    final isAgent = user.role == 'agent';
    final myUserId = user.id;
    final myAlias = user.userId ?? myUserId;

    // Load Trading Form entries
    try {
      final tradingFormResults = await _db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_entries WHERE date(date) = ? ORDER BY date ASC'
            : (isAgent
                ? 'SELECT * FROM trading_entries WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND date(date) = ? ORDER BY date ASC'
                : 'SELECT * FROM trading_entries WHERE company_id = ? AND date(date) = ? ORDER BY date ASC'),
        variables: <d.Variable<Object>>[
          if (!isSuperAdmin) d.Variable.withString(companyId ?? ''),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias),
          d.Variable.withString(selectedDateStr),
        ],
      ).get();
      
      for (final row in tradingFormResults) {
        final data = row.data;
        debugPrint('TodoRepository: Trading Form row data: ${data}');
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
          'date': data['date']?.toString(), // ← ADD DATE FIELD
          'module': 'trading_form',
          'originalId': data['id'],
        });
      }
    } catch (e) {
      // Table might not exist yet
    }

    // Load Trading File entries
    try {
      final tradingFileResults = await _db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM trading_file_entries WHERE date(date) = ? ORDER BY date ASC'
            : (isAgent
                ? 'SELECT * FROM trading_file_entries WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND date(date) = ? ORDER BY date ASC'
                : 'SELECT * FROM trading_file_entries WHERE company_id = ? AND date(date) = ? ORDER BY date ASC'),
        variables: <d.Variable<Object>>[
          if (!isSuperAdmin) d.Variable.withString(companyId ?? ''),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias),
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
          'date': data['date']?.toString(), // ← ADD DATE FIELD
          'module': 'trading_file',
          'originalId': data['id'],
        });
      }
    } catch (e) {
      // Table might not exist yet
    }

    // Load Agent Working entries
    try {
      final workingResults = await _db.customSelect(
        isSuperAdmin
            ? 'SELECT * FROM working_progress WHERE date(transfer_date) = ? ORDER BY transfer_date ASC'
            : 'SELECT * FROM working_progress WHERE company_id = ? AND date(transfer_date) = ? ORDER BY transfer_date ASC',
        variables: <d.Variable<Object>>[
          if (!isSuperAdmin) d.Variable.withString(companyId ?? ''),
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
          'date': data['transfer_date']?.toString(), // ← ADD DATE FIELD
          'module': 'working',
          'originalId': data['id'],
        });
      }
    } catch (e) {
      // Table might not exist yet
    }

    return tasks;
  }
}
