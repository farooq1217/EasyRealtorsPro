// lib/features/follow_up/models/follow_up.dart

/// Simple data class representing a Follow‑Up entry.
/// This mirrors the columns defined in `follow_up_table.dart`.
class FollowUp {
  final String id;
  final String clientName;
  final DateTime followUpDate;
  final String followUpTime;
  final String? note;
  final String status;
  final String companyId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final bool isSynced;

  FollowUp({
    required this.id,
    required this.clientName,
    required this.followUpDate,
    required this.followUpTime,
    this.note,
    this.status = 'pending',
    required this.companyId,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    this.isSynced = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
