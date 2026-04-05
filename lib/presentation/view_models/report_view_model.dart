// presentation/view_models/report_view_model.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/report_repository.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import 'package:shared/shared.dart' show WorkingProgressData, Expenditure;
import '../../core/role_utils.dart';

class ReportViewModel extends ChangeNotifier {
  final ReportRepository _repository;
  
  ReportViewModel(this._repository);

  // State
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _companyInfo;
  List<WorkingProgressData> _agentWorkingData = [];
  List<Map<String, dynamic>> _inventoryData = [];
  List<Expenditure> _expenditureData = [];
  Map<String, dynamic> _summary = {};
  
  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedSocietyId;
  String? _selectedBlockId;
  String? _selectedAgentId;
  String? _selectedCategory;
  String? _selectedKind;
  String? _selectedStatus;
  
  // UI state
  bool _loading = false;
  bool _generatingReceipt = false;
  bool _exportingPdf = false;
  bool _exportingCsv = false;
  String? _error;
  String _selectedReportType = 'agent_working'; // 'agent_working', 'inventory', 'expenditure'

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  Map<String, dynamic>? get companyInfo => _companyInfo;
  List<WorkingProgressData> get agentWorkingData => _agentWorkingData;
  List<Map<String, dynamic>> get inventoryData => _inventoryData;
  List<Expenditure> get expenditureData => _expenditureData;
  Map<String, dynamic> get summary => _summary;
  
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get selectedSocietyId => _selectedSocietyId;
  String? get selectedBlockId => _selectedBlockId;
  String? get selectedAgentId => _selectedAgentId;
  String? get selectedCategory => _selectedCategory;
  String? get selectedKind => _selectedKind;
  String? get selectedStatus => _selectedStatus;
  
  bool get loading => _loading;
  bool get generatingReceipt => _generatingReceipt;
  bool get exportingPdf => _exportingPdf;
  bool get exportingCsv => _exportingCsv;
  String? get error => _error;
  String get selectedReportType => _selectedReportType;

  // Initialize
  Future<void> initialize() async {
    await _loadCurrentUser();
    await _loadCompanyInfo();
    await _loadReportData();
  }

  // Load current user
  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService.getCurrentUser(authToken);
        _currentUser = user;
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  // Load company information
  Future<void> _loadCompanyInfo() async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      if (companyId != null) {
        _companyInfo = await _repository.getCompanyInfo(companyId);
      }
    } catch (e) {
      debugPrint('Error loading company info: $e');
    }
  }

  // Load report data based on selected type and filters
  Future<void> _loadReportData() async {
    if (_currentUser == null) return;
    
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      
      switch (_selectedReportType) {
        case 'agent_working':
          _agentWorkingData = await _repository.getAgentWorkingReport(
            companyId: companyId,
            isSuperAdmin: isSuper,
            startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
            endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
            societyId: _selectedSocietyId,
            agentId: _selectedAgentId,
          );
          break;
        case 'inventory':
          _inventoryData = await _repository.getInventoryReport(
            companyId: companyId,
            isSuperAdmin: isSuper,
            startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
            endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
            societyId: _selectedSocietyId,
            blockId: _selectedBlockId,
          );
          break;
        case 'expenditure':
          _expenditureData = await _repository.getExpenditureReport(
            companyId: companyId,
            isSuperAdmin: isSuper,
            startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
            endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
            category: _selectedCategory,
            kind: _selectedKind,
          );
          break;
      }
      
      await _loadSummary();
    } catch (e, stackTrace) {
      debugPrint('Error loading report data: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load report data: ${e.toString()}';
      
      // Clear data on error to prevent showing stale data
      _agentWorkingData.clear();
      _inventoryData.clear();
      _expenditureData.clear();
      _summary.clear();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSummary() async {
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || 
                          PermissionHelper.isBypassUser(_currentUser);
      
      final startDateStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
      final endDateStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;
      
      _summary = await _repository.getReportSummary(
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        startDate: startDateStr,
        endDate: endDateStr,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading report summary: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load report summary: ${e.toString()}';
    }
  }

  // Filter setters
  void setStartDate(DateTime? date) {
    if (_startDate != date) {
      _startDate = date;
      notifyListeners();
      _loadReportData();
    }
  }

  void setEndDate(DateTime? date) {
    if (_endDate != date) {
      _endDate = date;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedSocietyId(String? societyId) {
    if (_selectedSocietyId != societyId) {
      _selectedSocietyId = societyId;
      // Reset block selection when society changes
      _selectedBlockId = null;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedBlockId(String? blockId) {
    if (_selectedBlockId != blockId) {
      _selectedBlockId = blockId;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedAgentId(String? agentId) {
    if (_selectedAgentId != agentId) {
      _selectedAgentId = agentId;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedCategory(String? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedKind(String? kind) {
    if (_selectedKind != kind) {
      _selectedKind = kind;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedStatus(String? status) {
    if (_selectedStatus != status) {
      _selectedStatus = status;
      notifyListeners();
      _loadReportData();
    }
  }

  void setSelectedReportType(String type) {
    if (_selectedReportType != type) {
      _selectedReportType = type;
      notifyListeners();
      _loadReportData();
    }
  }

  // Clear all filters
  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _selectedSocietyId = null;
    _selectedBlockId = null;
    _selectedAgentId = null;
    _selectedCategory = null;
    _selectedKind = null;
    _selectedStatus = null;
    notifyListeners();
    _loadReportData();
  }

  // Professional Receipt Generation
  Future<Uint8List?> generateProfessionalReceipt({
    required String entryId,
    required String entryType,
  }) async {
    if (_currentUser == null) return null;
    
    _generatingReceipt = true;
    _error = null;
    notifyListeners();
    
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final companyInfo = companyId != null ? await _repository.getCompanyInfo(companyId) : null;
      
      final pdfBytes = await _repository.generateProfessionalReceipt(
        entryId: entryId,
        entryType: entryType,
        companyInfo: companyInfo,
        logoPath: null, // TODO: Add logo path if available
      );
      
      _generatingReceipt = false;
      notifyListeners();
      
      return pdfBytes;
    } catch (e) {
      debugPrint('Error generating professional receipt: $e');
      _error = 'Failed to generate receipt: $e';
      _generatingReceipt = false;
      notifyListeners();
      return null;
    }
  }

  // Export to PDF
  Future<Uint8List?> exportToPdf() async {
    if (_currentUser == null) return null;
    
    _exportingPdf = true;
    _error = null;
    notifyListeners();
    
    try {
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || 
                          PermissionHelper.isBypassUser(_currentUser);
      final companyInfo = companyId != null ? await _repository.getCompanyInfo(companyId) : null;
      
      List<Map<String, dynamic>> data;
      switch (_selectedReportType) {
        case 'agent_working':
          data = _agentWorkingData.map((item) => {
            'name': item.name,
            'status': item.status,
            'fromUser': item.fromUser,
            'toUser': item.toUser,
            'transferDate': item.transferDate,
            'nextWorkingDate': item.nextWorkingDate,
            'category': item.category,
            'remarks': item.remarks,
          }).toList();
          break;
        case 'inventory':
          data = _inventoryData;
          break;
        case 'expenditure':
          data = _expenditureData.map((expenditure) => {
            'date': expenditure.date,
            'description': expenditure.description,
            'amount': expenditure.amount?.toString() ?? '0',
            'category': expenditure.category ?? '',
            'kind': expenditure.kind ?? '',
          }).toList();
          break;
        default:
          data = [];
      }
      
      if (data.isEmpty) {
        throw Exception('No data available to export');
      }
      
      final pdfBytes = await _repository.exportToPdf(
        data: data,
        reportType: _selectedReportType,
        companyInfo: companyInfo,
      );
      
      return pdfBytes;
    } catch (e, stackTrace) {
      debugPrint('Error exporting to PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to export PDF: ${e.toString()}';
      return null;
    } finally {
      _exportingPdf = false;
      notifyListeners();
    }
  }

  // Export to CSV
  Future<Uint8List?> exportToCsv() async {
    if (_currentUser == null) return null;
    
    _exportingCsv = true;
    _error = null;
    notifyListeners();
    
    try {
      List<Map<String, dynamic>> data;
      switch (_selectedReportType) {
        case 'agent_working':
          data = _agentWorkingData.map((e) => {
            'id': e.id,
            'name': e.name,
            'status': e.status,
            'category': e.category,
            'transferDate': e.transferDate,
            'remarks': e.remarks,
          }).toList();
          break;
        case 'inventory':
          data = _inventoryData;
          break;
        case 'expenditure':
          data = _expenditureData.map((e) => {
            'id': e.id,
            'date': e.date,
            'description': e.description,
            'amount': e.amount,
            'category': e.category,
            'kind': e.kind,
          }).toList();
          break;
        default:
          data = [];
      }
      
      if (data.isEmpty) {
        throw Exception('No data available to export');
      }
      
      final csvBytes = await _repository.exportToCsv(
        reportType: _selectedReportType,
        data: data,
      );
      
      return csvBytes;
    } catch (e, stackTrace) {
      debugPrint('Error exporting to CSV: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to export CSV: ${e.toString()}';
      return null;
    } finally {
      _exportingCsv = false;
      notifyListeners();
    }
  }

  // Get filtered data based on selected report type
  List<dynamic> get currentData {
    switch (_selectedReportType) {
      case 'agent_working':
        return _agentWorkingData;
      case 'inventory':
        return _inventoryData;
      case 'expenditure':
        return _expenditureData;
      default:
        return [];
    }
  }

  // Get data count for current report type
  int get currentDataCount {
    return currentData.length;
  }

  // Clear error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // Refresh data
  Future<void> refresh() async {
    await _loadReportData();
  }

  // Get formatted date range string
  String get dateRangeText {
    if (_startDate == null && _endDate == null) {
      return 'All Time';
    } else if (_startDate != null && _endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'From ${DateFormat('dd MMM yyyy').format(_startDate!)}';
    } else {
      return 'Until ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }
  }

  // Get summary statistics formatted for display
  Map<String, String> get formattedSummary {
    final formatted = <String, String>{};
    
    for (final entry in _summary.entries) {
      formatted[entry.key] = _formatSummaryValue(entry.key, entry.value);
    }
    
    return formatted;
  }

  String _formatSummaryValue(String key, dynamic value) {
    switch (key) {
      case 'totalExpenditure':
        return 'PKR ${value.toStringAsFixed(2)}';
      default:
        return value.toString();
    }
  }
}
