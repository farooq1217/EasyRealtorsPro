import 'package:shared/shared.dart';

abstract class TodoRepository {
  /// Get all reminders for a specific user
  Stream<List<Reminder>> getReminders(String userId, String? companyId);
  
  /// Get all reminders for a specific date
  Stream<List<Reminder>> getRemindersForDate(String userId, String? companyId, DateTime date);
  
  /// Get all reminders for a specific date (Future-based for manual refresh)
  Future<List<Reminder>> getRemindersForDateFuture(String userId, String? companyId, DateTime date);
  
  /// Add a new reminder
  Future<void> addReminder(Reminder reminder);
  
  /// Update an existing reminder
  Future<void> updateReminder(Reminder reminder);
  
  /// Delete a reminder
  Future<void> deleteReminder(int reminderId);
  
  /// Toggle reminder status (active/inactive)
  Future<void> toggleReminderStatus(int reminderId, bool isActive);
  
  /// Update reminder status (Pending/Active/Inactive)
  Future<void> updateReminderStatus(int reminderId, String newStatus);
  
  /// Get aggregated tasks from multiple sources for a specific date
  Future<List<Map<String, dynamic>>> getAggregatedTasksForDate(
    String userId, 
    String? companyId, 
    DateTime date,
  );
}
