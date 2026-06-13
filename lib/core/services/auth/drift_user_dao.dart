import 'package:drift/drift.dart';
import 'package:shared/shared.dart';

class DriftUserDao {
  final AppDatabase? _db;

  DriftUserDao([this._db]);

  AppDatabase get db => _db ?? AppDatabase.instanceIfInitialized!;

  /// Find user by ID
  Future<User?> getUserById(String id) async {
    final query = db.select(db.users)..where((t) => t.id.equals(id));
    return await query.getSingleOrNull();
  }

  /// Find user by email or username
  Future<User?> getUserByEmailOrUsername(String emailOrUsername) async {
    final query = db.select(db.users)
      ..where((t) => t.email.equals(emailOrUsername.toLowerCase()) | t.username.equals(emailOrUsername));
    return await query.getSingleOrNull();
  }

  /// Upsert user from a User object
  Future<void> upsertUser(User user) async {
    await db.into(db.users).insertOnConflictUpdate(user);
  }

  /// Update password hash, salt, iterations for a user
  Future<void> updatePasswordHash({
    required String emailOrUsername,
    required String passwordHash,
    required String? salt,
    required int? iterations,
  }) async {
    await (db.update(db.users)
          ..where((t) => t.email.equals(emailOrUsername.toLowerCase()) | t.username.equals(emailOrUsername)))
        .write(
      UsersCompanion(
        passwordHash: Value(passwordHash),
        salt: Value(salt),
        iterations: Value(iterations),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }

  /// Update status and isActive flag for a user
  Future<void> updateUserStatus({
    required String emailOrUsername,
    required String status,
    required bool isActive,
  }) async {
    await (db.update(db.users)
          ..where((t) => t.email.equals(emailOrUsername.toLowerCase()) | t.username.equals(emailOrUsername)))
        .write(
      UsersCompanion(
        status: Value(status),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }

  /// Clear user cache by deleting all users
  Future<void> clearUserCache() async {
    await db.delete(db.users).go();
  }
}
