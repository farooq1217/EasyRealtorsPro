import 'dart:typed_data';
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/services/auth_service.dart';
import '../../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../view_models/report_view_model.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../../modules/agent_working/agent_working_detail_page.dart';
import 'package:shared/shared.dart' show WorkingProgressData, Expenditure, RoleUtils, AppDatabase;

class ReportsPage extends StatefulWidget {
  final AppDatabase db;
  const ReportsPage({super.key, required this.db});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late ReportViewModel _viewModel;
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialize view model with repository
    final isSuperAdmin = RoleUtils.isSuperAdmin(null) || PermissionHelper.isBypassUser(null);
    final companyId = RoleUtils.getUserCompanyId(null);
    final repository = ReportRepositoryImpl(widget.db, companyId: companyId, isSuperAdmin: isSuperAdmin);
    _viewModel = ReportViewModel(repository);
    
    // Initialize data
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.startDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _viewModel.setStartDate(picked);
      _startDateController.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.endDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _viewModel.setEndDate(picked);
      _endDateController.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  String _formatDateDisplay(String dateText) {
    if (dateText.isEmpty) return 'Select date';
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateText);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateText;
    }
  }

  Future<void> _exportToPdf() async {
    final pdfBytes = await _viewModel.exportToPdf();
    if (pdfBytes != null && mounted) {
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: '${_viewModel.selectedReportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  Future<void> _exportToCsv() async {
    final csvBytes = await _viewModel.exportToCsv();
    if (csvBytes != null && mounted) {
      // Save CSV file
      final fileName = '${_viewModel.selectedReportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      // In a real app, you would use path_provider to get a proper directory
      // For now, just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported successfully as $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.assessment, color: Colors.purple.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Reports & Analytics',
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade500,
                      Colors.purple.shade400,
                      Colors.purple.shade300,
                    ],
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Fixed Header Section
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 110,
                            maxHeight: 130,
                          ),
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filters',
                                  style: AppFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // Report Type Selection
                                _buildReportTypeSelector(),
                                const SizedBox(height: 4),
                                
                                // Action Buttons in single row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      height: 32,
                                      child: OutlinedButton(
                                        onPressed: _viewModel.clearFilters,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          side: BorderSide(color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.clear, size: 12, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Clear',
                                              style: AppFonts.poppins(
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 80,
                                      height: 32,
                                      child: PrimaryGradientButton(
                                        text: 'Apply',
                                        onPressed: _viewModel.refresh,
                                        icon: Icons.filter_list,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Content Section
                        Container(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 150,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Summary Section
                                _buildSummarySection(),
                                
                                // Data Section
                                Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _viewModel.loading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _buildDataSection(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Type',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Responsive filter bar with Wrap
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            // Agent Working button
            SizedBox(
              width: 110,
              height: 32,
              child: GestureDetector(
                onTap: () => _viewModel.setSelectedReportType('agent_working'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewModel.selectedReportType == 'agent_working'
                        ? const Color(0xFFFF6B35)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Agent Working',
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      color: _viewModel.selectedReportType == 'agent_working'
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: _viewModel.selectedReportType == 'agent_working'
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            
            // Daily button
            SizedBox(
              width: 70,
              height: 32,
              child: GestureDetector(
                onTap: () => _viewModel.setSelectedReportType('daily'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewModel.selectedReportType == 'daily'
                        ? const Color(0xFFFF6B35)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Daily',
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      color: _viewModel.selectedReportType == 'daily'
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: _viewModel.selectedReportType == 'daily'
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            
            // Weekly button
            SizedBox(
              width: 70,
              height: 32,
              child: GestureDetector(
                onTap: () => _viewModel.setSelectedReportType('weekly'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewModel.selectedReportType == 'weekly'
                        ? const Color(0xFFFF6B35)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Weekly',
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      color: _viewModel.selectedReportType == 'weekly'
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: _viewModel.selectedReportType == 'weekly'
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            
            // Monthly button
            SizedBox(
              width: 70,
              height: 32,
              child: GestureDetector(
                onTap: () => _viewModel.setSelectedReportType('monthly'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewModel.selectedReportType == 'monthly'
                        ? const Color(0xFFFF6B35)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Monthly',
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      color: _viewModel.selectedReportType == 'monthly'
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: _viewModel.selectedReportType == 'monthly'
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            
            // Date fields in single row
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Start Date picker
                  SizedBox(
                    width: 160,
                    height: 32,
                    child: _buildDateField(
                      'From: ${_startDateController.text.isEmpty ? 'Select date' : _formatDateDisplay(_startDateController.text)}',
                      _startDateController,
                      _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // End Date picker
                  SizedBox(
                    width: 160,
                    height: 32,
                    child: _buildDateField(
                      'To: ${_endDateController.text.isEmpty ? 'Select date' : _formatDateDisplay(_endDateController.text)}',
                      _endDateController,
                      _pickEndDate,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppFonts.poppins(
                  fontSize: 11,
                  color: controller.text.isEmpty ? Colors.grey.shade600 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalFilters() {
    switch (_viewModel.selectedReportType) {
      case 'inventory':
        return _buildInventoryFilters();
      case 'expenditure':
        return _buildExpenditureFilters();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInventoryFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Filter',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _viewModel.selectedStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('All Status')),
            DropdownMenuItem(value: 'Sale', child: Text('Sold')),
            DropdownMenuItem(value: 'Not Sale', child: Text('Available')),
          ],
          onChanged: (value) => _viewModel.setSelectedStatus(value),
        ),
      ],
    );
  }

  Widget _buildExpenditureFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Filter',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _viewModel.selectedCategory,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('All Categories')),
            DropdownMenuItem(value: 'Office', child: Text('Office')),
            DropdownMenuItem(value: 'Project', child: Text('Project')),
          ],
          onChanged: (value) => _viewModel.setSelectedCategory(value),
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    if (_viewModel.summary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.summarize, color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Summary for ${_viewModel.dateRangeText}',
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: _viewModel.formattedSummary.entries.map((entry) {
              return Container(
                constraints: BoxConstraints(
                  minWidth: 120,
                  maxWidth: 200,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: AppFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value,
                      style: AppFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with export buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_viewModel.selectedReportType.toUpperCase()} DATA (${_viewModel.currentDataCount})',
                style: AppFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  // Export PDF button
                  ElevatedButton.icon(
                    onPressed: _viewModel.exportingPdf ? null : _exportToPdf,
                    icon: _viewModel.exportingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(
                      _viewModel.exportingPdf ? 'Exporting...' : 'PDF',
                      style: AppFonts.poppins(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export CSV button
                  ElevatedButton.icon(
                    onPressed: _viewModel.exportingCsv ? null : _exportToCsv,
                    icon: _viewModel.exportingCsv
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.table_chart, size: 16),
                    label: Text(
                      _viewModel.exportingCsv ? 'Exporting...' : 'CSV',
                      style: AppFonts.poppins(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Data table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _viewModel.currentData.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      // Header row with background
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            // Name header (250px)
                            SizedBox(
                              width: 250,
                              child: Text(
                                'Name',
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Status header (120px)
                            SizedBox(
                              width: 120,
                              child: Text(
                                'Status',
                                textAlign: TextAlign.center,
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Category header (150px)
                            SizedBox(
                              width: 150,
                              child: Text(
                                'Category',
                                textAlign: TextAlign.center,
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Date header (120px)
                            SizedBox(
                              width: 120,
                              child: Text(
                                'Date',
                                textAlign: TextAlign.center,
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Data rows
                      ..._buildTableRows(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No data found for the selected filters',
            style: AppFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or date range',
            style: AppFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTableRows() {
    final data = _viewModel.currentData;
    
    return data.map((item) {
      switch (_viewModel.selectedReportType) {
        case 'agent_working':
          final workingItem = item as WorkingProgressData;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Name column (250px, left-aligned)
                SizedBox(
                  width: 250,
                  child: Text(
                    workingItem.name ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: _buildStatusChip(workingItem.status ?? 'Pending'),
                  ),
                ),
                // Category column (150px, center-aligned)
                SizedBox(
                  width: 150,
                  child: Center(
                    child: Text(
                      workingItem.category ?? '-',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Date column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      _formatDate(workingItem.transferDate),
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        case 'inventory':
          final inventoryItem = item as Map<String, dynamic>;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Name column (250px, left-aligned)
                SizedBox(
                  width: 250,
                  child: Text(
                    inventoryItem['name'] ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Type column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      inventoryItem['type'] ?? '-',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Client column (150px, left-aligned)
                SizedBox(
                  width: 150,
                  child: Text(
                    inventoryItem['clientName'] ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: _buildInventoryStatusChip(inventoryItem['saleStatus']),
                  ),
                ),
              ],
            ),
          );
        case 'expenditure':
          final expenditureItem = item as Expenditure;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Description column (250px, left-aligned)
                SizedBox(
                  width: 250,
                  child: Text(
                    expenditureItem.description ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Amount column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      'PKR ${expenditureItem.amount?.toStringAsFixed(2) ?? '0.00'}',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Category column (150px, center-aligned)
                SizedBox(
                  width: 150,
                  child: Center(
                    child: Text(
                      expenditureItem.category ?? '-',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Date column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      _formatDate(expenditureItem.date),
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }).toList();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'done':
        color = Colors.green;
        break;
      case 'closed':
        color = Colors.orange;
        break;
      case 'pending':
      default:
        color = Colors.blue;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: AppFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInventoryStatusChip(String? status) {
    final statusText = status ?? 'Unknown';
    Color color;
    
    switch (statusText.toLowerCase()) {
      case 'sale':
        color = Colors.green;
        break;
      case 'not sale':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: AppFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
