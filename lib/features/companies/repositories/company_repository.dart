import 'dart:async';
import '../../companies/models/company_model.dart';

abstract class CompanyRepository {
  // Basic CRUD operations
  Future<List<CompanyModel>> getCompanies();
  Future<CompanyModel?> getCompanyById(String id);
  Future<void> addCompany(CompanyModel company);
  Future<void> updateCompany(CompanyModel company);
  Future<void> deleteCompany(String id); // Soft delete
  
  // Stream operations for real-time updates
  Stream<List<CompanyModel>> watchCompanies();
  Stream<CompanyModel?> watchCompanyById(String id);
  
  // Company status management
  Future<void> activateCompany(String id);
  Future<void> deactivateCompany(String id);
  Future<void> archiveCompany(String id);
  
  // User limit management
  Future<bool> canAddMoreUsers(String companyId);
  Future<int> getCurrentUserCount(String companyId);
  Future<int> getMaxUserLimit(String companyId);
  Future<void> updateUserLimit(String companyId, int newLimit);
  
  // Subscription management
  Future<String?> getSubscriptionTier(String companyId);
  Future<void> updateSubscriptionTier(String companyId, String tier);
  Future<int> getUserLimitForTier(String tier);
  
  // Search functionality
  Future<List<CompanyModel>> searchCompanies(String query);
  Stream<List<CompanyModel>> watchSearchCompanies(String query);
  
  // Database schema management
  Future<void> ensureCompanyTableColumns();
  
  // Sync operations
  Future<void> syncCompaniesFromFirestore();
  Future<void> markCompanyAsUnsynced(String companyId);
  Future<void> markCompanyAsSynced(String companyId);
  
  // Company statistics
  Future<Map<String, dynamic>> getCompanyStatistics();
  Future<Map<String, dynamic>> getCompanyStatisticsById(String companyId);
  
  // Company validation
  Future<bool> isCompanyNameUnique(String name, {String? excludeCompanyId});
  Future<bool> isCompanyActive(String companyId);
}
