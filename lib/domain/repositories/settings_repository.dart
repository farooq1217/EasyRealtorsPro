// domain/repositories/settings_repository.dart
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
  
  // User profile management
  Future<Map<String, dynamic>?> getCurrentUser();
  Future<void> updateProfile(Map<String, dynamic> userData);
  Future<void> updateProfileImage(String imagePath);
  
  // Data export
  Future<void> exportDataToCsv();
}
