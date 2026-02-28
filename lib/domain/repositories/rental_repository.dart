import 'dart:async';
import 'package:drift/drift.dart' as d;

/// Rental item status enum for type safety
enum RentalStatus {
  available('Available'),
  rented('Rented'),
  overdue('Overdue'),
  maintenance('Maintenance');

  const RentalStatus(this.displayName);
  final String displayName;

  static RentalStatus fromString(String? status) {
    switch (status) {
      case 'Rented':
        return RentalStatus.rented;
      case 'Overdue':
        return RentalStatus.overdue;
      case 'Maintenance':
        return RentalStatus.maintenance;
      case 'Available':
      default:
        return RentalStatus.available;
    }
  }
}

/// Repository interface for rental items operations
abstract class RentalRepository {
  /// Get stream of rental items with optional filtering
  Stream<List<Map<String, dynamic>>> watchRentalItems({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
  });

  /// Get rental items as future (one-time fetch)
  Future<List<Map<String, dynamic>>> getRentalItems({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
  });

  /// Get a single rental item by ID
  Future<Map<String, dynamic>?> getRentalItemById(String id);

  /// Add a new rental item
  Future<String> addRentalItem(Map<String, dynamic> item);

  /// Update an existing rental item
  Future<void> updateRentalItem(Map<String, dynamic> item);

  /// Update rental item status
  Future<void> updateRentalStatus(String id, RentalStatus status);

  /// Delete a rental item (soft delete)
  Future<void> deleteRentalItem(String id);

  /// Get rental items count by status
  Future<Map<RentalStatus, int>> getRentalStats(String? companyId);

  /// Search rental items with SQL LIKE
  Future<List<Map<String, dynamic>>> searchRentalItems(String query, {
    String? companyId,
    String? createdBy,
    RentalStatus? statusFilter,
  });

  /// Get rental items with pagination
  Future<List<Map<String, dynamic>>> getRentalItemsPaginated({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
    int page = 1,
    int limit = 20,
  });

  /// Check if more items are available for pagination
  Future<bool> hasMoreRentalItems({
    String? companyId,
    String? createdBy,
    String? searchQuery,
    RentalStatus? statusFilter,
    int currentPage = 1,
    int limit = 20,
  });
}
