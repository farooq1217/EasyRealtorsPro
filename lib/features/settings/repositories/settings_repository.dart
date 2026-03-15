// domain/repositories/settings_repository.dart
import 'dart:async';
abstract class SettingsRepository {
  // Societies management
  Future<List<Map<String, String>>> getSocieties();
  Future<void> addSociety(String name);
  Future<void> updateSociety(String id, String name);
  Future<void> deleteSociety(String id);
  
  // Blocks management
  Future<List<Map<String, String>>> getBlocks();
  Future<List<Map<String, String>>> getBlocksBySociety(String societyId);
  Future<void> addBlock(String societyId, String name);
  Future<void> updateBlock(String id, String name);
  Future<void> deleteBlock(String id);
  
  // Stream-based methods for real-time updates
  Stream<List<Map<String, String>>> watchSocieties(String? companyId, bool isSuper);
  Stream<List<Map<String, String>>> watchBlocks(String? societyId);
  
  // User profile management
  Future<Map<String, dynamic>?> getCurrentUser();
  Future<void> updateProfile(Map<String, dynamic> userData);
  Future<void> updateProfileImage(String imagePath);
  
  // Data export
  Future<void> exportDataToCsv();
}
