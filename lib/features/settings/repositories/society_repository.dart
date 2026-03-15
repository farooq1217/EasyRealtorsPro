// domain/repositories/society_repository.dart
abstract class SocietyRepository {
  // Get all societies
  Future<List<Map<String, String>>> getSocieties();
  
  // Get all blocks
  Future<List<Map<String, String>>> getBlocks();
  
  // Get blocks by society
  Future<List<Map<String, String>>> getBlocksBySociety(String societyId);
}
