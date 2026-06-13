// lib/features/follow_up/repositories/follow_up_repository_impl.dart

import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'package:shared/shared.dart';
import 'package:easyrealtorspro/features/follow_up/models/follow_up.dart' as domain;
import 'package:shared/src/db/schema.dart' hide FollowUp;
import 'follow_up_repository.dart';
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import '../../../core/services/firebase_threading_handler.dart';



class FollowUpRepositoryImpl implements FollowUpRepository {
  final AppDatabase _db;
  final String _userId; // user performing actions, for createdBy and auto‑todo

  // Platform detection for thread safety
  static bool get _isWindows => !kIsWeb && io.Platform.isWindows;

  FollowUpRepositoryImpl(this._db, this._userId);

  // Helper method to wrap streams with platform thread safety
  Stream<T> _wrapStreamWithThreadSafety<T>(Stream<T> stream, String streamName) {
    if (_isWindows) {
      debugPrint('FollowUpRepository: Wrapping $streamName with Windows thread safety');
      return FirebaseThreadingHandler.wrapStreamWithThreadSafety(
        stream,
        streamName: 'FollowUpRepository $streamName',
      );
    }
    return stream;
  }

  @override
  Stream<List<domain.FollowUp>> watchFollowUps(String? companyId) {
    final query = _db.select(_db.followUps)
      ..where((tbl) => tbl.isActive.equals(true));
    if (companyId != null) {
      query.where((tbl) => tbl.companyId.equals(companyId));
    }
    final stream = query.watch().map((rows) => rows.map((row) => domain.FollowUp(
      id: row.id,
      clientName: row.clientName,
      followUpDate: row.followUpDate,
      followUpTime: row.followUpTime,
      note: row.note,
      status: row.status,
      companyId: row.companyId,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isActive: row.isActive,
      isSynced: row.isSynced,
    )).toList());
    return _wrapStreamWithThreadSafety(stream, 'watchFollowUps');
  }

  @override
  Stream<List<domain.FollowUp>> watchFollowUpsForDate(String? companyId, DateTime date) {
    final query = _db.select(_db.followUps)
      ..where((tbl) => tbl.isActive.equals(true))
      ..where((tbl) => tbl.followUpDate.equals(date));
    if (companyId != null) {
      query.where((tbl) => tbl.companyId.equals(companyId));
    }
    final stream = query.watch().map((rows) => rows.map((row) => domain.FollowUp(
      id: row.id,
      clientName: row.clientName,
      followUpDate: row.followUpDate,
      followUpTime: row.followUpTime,
      note: row.note,
      status: row.status,
      companyId: row.companyId,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isActive: row.isActive,
      isSynced: row.isSynced,
    )).toList());
    return _wrapStreamWithThreadSafety(stream, 'watchFollowUpsForDate');
  }

  @override
  Future<List<domain.FollowUp>> getFollowUpsForDateFuture(String? companyId, DateTime date) async {
    final query = _db.select(_db.followUps)
      ..where((tbl) => tbl.isActive.equals(true))
      ..where((tbl) => tbl.followUpDate.equals(date));
    if (companyId != null) {
      query.where((tbl) => tbl.companyId.equals(companyId));
    }
    final rows = await query.get();
    return rows.map((row) => domain.FollowUp(
      id: row.id,
      clientName: row.clientName,
      followUpDate: row.followUpDate,
      followUpTime: row.followUpTime,
      note: row.note,
      status: row.status,
      companyId: row.companyId,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isActive: row.isActive,
      isSynced: row.isSynced,
    )).toList();
  }

  @override
  Future<void> addFollowUp(domain.FollowUp followUp, String userId) async {
    // Insert follow‑up entry
    await _db.into(_db.followUps).insert(FollowUpsCompanion.insert(
      id: followUp.id,
      clientName: followUp.clientName,
      followUpDate: followUp.followUpDate,
      followUpTime: followUp.followUpTime,
      note: d.Value(followUp.note),
      status: d.Value(followUp.status),
      companyId: followUp.companyId,
      createdBy: userId,
      createdAt: followUp.createdAt,
      updatedAt: followUp.updatedAt,
      isActive: d.Value(true),
      isSynced: d.Value(true),
    ));

    // Auto‑todo: create a reminder entry for the same date
    final reminder = Reminder(
      reminderId: 0, // auto‑increment
      agentId: userId,
      companyId: followUp.companyId,
      clientName: followUp.clientName,
      clientPhone: null,
      reminderTitle: 'Follow up: ${followUp.clientName}',
      reminderDetails: followUp.note,
      reminderDate: followUp.followUpDate.toIso8601String().split('T')[0], // YYYY‑MM‑DD
      reminderTime: followUp.followUpTime,
      notificationStatus: 'pending',
      is_active: true,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      isSynced: true,
      isRead: false,
    );
    await _db.into(_db.reminders).insert(RemindersCompanion.insert(
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
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
      isSynced: d.Value(reminder.isSynced),
    ));
  }

  @override
  Future<void> updateFollowUp(domain.FollowUp followUp) async {
    await (_db.update(_db.followUps)
          ..where((tbl) => tbl.id.equals(followUp.id)))
        .write(FollowUpsCompanion(
      clientName: d.Value(followUp.clientName),
      followUpDate: d.Value(followUp.followUpDate),
      followUpTime: d.Value(followUp.followUpTime),
      note: d.Value(followUp.note),
      status: d.Value(followUp.status),
      updatedAt: d.Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteFollowUp(String id) async {
    await (_db.update(_db.followUps)..where((tbl) => tbl.id.equals(id)))
        .write(FollowUpsCompanion(isActive: d.Value(false)));
  }
}
