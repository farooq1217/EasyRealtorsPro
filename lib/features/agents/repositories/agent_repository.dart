import 'package:shared/shared.dart' show WorkingProgressData, WorkingComment;

/// Repository interface for Agent Working module operations
abstract class AgentRepository {
  // Transfer operations
  Future<List<WorkingProgressData>> getTransfers({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  });
  
  Future<List<WorkingProgressData>> getClientRequirements({
    String? companyId,
    bool isSuperAdmin = false,
    String? searchQuery,
  });
  
  Future<void> addTransfer({
    required String id,
    String? companyId,
    required String name,
    required String status,
    String? remarks,
    required String transferDate,
    String? nextWorkingDate,
    String? category,
    List<String>? images,
  });
  
  Future<void> addClientRequirement({
    required String id,
    String? companyId,
    required String name,
    required String status,
    String? remarks,
    required String transferDate,
    String? nextWorkingDate,
    String? source,
    List<String>? images,
  });
  
  Future<void> updateStatus({
    required String id,
    required String status,
    String? nextWorkingDate,
  });
  
  // Comments operations
  Future<List<WorkingComment>> getComments(String parentId);
  
  Future<void> addComment({
    required String id,
    required String parentId,
    String? companyId,
    required String comment,
  });
  
  Future<void> deleteComment(String id);
  
  // Image operations
  Future<List<String>> getImages(String parentId);
  
  Future<void> updateImages({
    required String parentId,
    required List<String> images,
  });
  
  // Notes operations (for office/other notes)
  Future<List<Map<String, dynamic>>> getOfficeNotes();
  Future<List<Map<String, dynamic>>> getOtherNotes();
  
  Future<void> addOfficeNote({
    required String id,
    required String text,
    required DateTime createdAt,
  });
  
  Future<void> addOtherNote({
    required String id,
    required String text,
    required DateTime createdAt,
  });
  
  // Notifications
  Future<List<WorkingProgressData>> getTasksDueToday({
    String? companyId,
    bool isSuperAdmin = false,
  });
  
  // Receipt generation
  Future<void> generateProfessionalReceipt(String entryId);
}
