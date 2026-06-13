import 'package:shared/shared.dart';
import 'package:easyrealtorspro/features/follow_up/models/follow_up.dart' as domain;
import 'package:shared/src/db/schema.dart' hide FollowUp;

abstract class FollowUpRepository {
  /// Watch all follow ups for a company (or all if null)
  Stream<List<domain.FollowUp>> watchFollowUps(String? companyId);

  /// Watch follow ups for a specific date
  Stream<List<domain.FollowUp>> watchFollowUpsForDate(String? companyId, DateTime date);

  /// Get follow ups for a date (future based)
  Future<List<domain.FollowUp>> getFollowUpsForDateFuture(String? companyId, DateTime date);

  /// Add a new follow up and create a corresponding auto‑todo reminder
  Future<void> addFollowUp(domain.FollowUp followUp, String userId);

  /// Update an existing follow up
  Future<void> updateFollowUp(domain.FollowUp followUp);

  /// Delete (soft‑delete) a follow up
  Future<void> deleteFollowUp(String id);
}
