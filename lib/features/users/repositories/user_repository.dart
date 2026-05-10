import 'dart:async';
import '../../users/models/user_model.dart';

abstract class UserRepository {
  // Basic CRUD operations
  Future<List<UserModel>> getUsers(String? companyId);
  Future<UserModel?> getUserById(String id);
  Future<UserModel?> getUserByEmail(String email);
  Future<void> addUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(String id); // Soft delete
  
  // Stream operations for real-time updates
  Stream<List<UserModel>> watchUsers(String? companyId);
  Stream<UserModel?> watchUserById(String id);
  
  // Authentication and password management
  Future<bool> validateUser(String email, String password);
  Future<void> updatePassword(String userId, String newPassword);
  Future<bool> isFirstLogin(String userId);
  Future<void> markFirstLoginComplete(String userId);
  
  // User ID management
  Future<String> generateUniqueUserId(String companyId);
  Future<void> backfillUserIds(String companyId);
  Future<bool> isUserIdUnique(String companyId, String userId, {String? excludeUserId});
  Future<UserModel?> getUserByUsername(String username);
  
  // Company-specific operations
  Future<List<UserModel>> getUsersByCompany(String companyId);
  Future<int> getActiveUserCount(String companyId);
  Future<bool> canAddMoreUsers(String companyId);
  
  // Profile management
  Future<void> updateProfilePicture(String userId, String imagePath);
  Future<void> updatePermissions(String userId, Map<String, dynamic> permissions);
  
  // Search functionality
  Future<List<UserModel>> searchUsers(String? companyId, String query);
  Stream<List<UserModel>> watchSearchUsers(String? companyId, String query);
  
  // Database schema management
  Future<void> ensureUserTableColumns();
  
  // Sync operations
  Future<void> syncUsersFromFirestore();
  Future<void> markUserAsUnsynced(String userId);
  Future<void> markUserAsSynced(String userId);
  
  // User management operations
  Future<void> updateUserPassword(String userId, String newPassword);
  Future<void> updateUserRole(String userId, String newRole, Map<String, bool> selectedModules);
  Future<void> updateUserPermissions({
    required String userId,
    required String userEmail,
    required String? companyId,
    required Map<String, String> permissionsMap,
  });
  Future<void> archiveUser(String userId);
  
  // User statistics
  Future<Map<String, dynamic>> getUserStatistics(String? companyId);
}
