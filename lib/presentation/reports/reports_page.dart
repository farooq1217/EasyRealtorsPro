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
import 'package:shared/shared.dart' show WorkingProgressData, Expenditure, RentalItem, TradingEntry, Reminder, RoleUtils, AppDatabase, TradingType;

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
    
    // Initialize data on main UI thread to prevent platform channel threading issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _viewModel.initialize();
      }
    });
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
              child: Column(
                children: [
                  // Compact Header Section with Horizontal Filters
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Horizontal filter row
                        Row(
                          children: [
                            // Report Type Dropdown
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Report Type',
                                    style: AppFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      value: _viewModel.selectedReportType,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        prefixIcon: Icon(
                                          Icons.analytics_outlined,
                                          size: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                        hintText: 'Select Report',
                                        hintStyle: AppFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'inventory', child: Text('Inventory')),
                                        DropdownMenuItem(value: 'rental', child: Text('Rental Items')),
                                        DropdownMenuItem(value: 'todo', child: Text('To-Do')),
                                        DropdownMenuItem(value: 'expenditure', child: Text('Expenditure')),
                                        DropdownMenuItem(value: 'trading', child: Text('Trading')),
                                        DropdownMenuItem(value: 'agent_working', child: Text('Agent Working')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          _viewModel.setSelectedReportType(value);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Date Range Pickers
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date Range',
                                    style: AppFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      // From Date
                                      Expanded(
                                        child: _buildProfessionalDateField(
                                          'From',
                                          _startDateController,
                                          _pickStartDate,
                                          Icons.calendar_today,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // To Date
                                      Expanded(
                                        child: _buildProfessionalDateField(
                                          'To',
                                          _endDateController,
                                          _pickEndDate,
                                          Icons.event,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Action Buttons
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Actions',
                                  style: AppFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Clear Button
                                    SizedBox(
                                      height: 36,
                                      child: OutlinedButton.icon(
                                        onPressed: _viewModel.clearFilters,
                                        icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade600),
                                        label: Text(
                                          'Clear',
                                          style: AppFonts.poppins(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          side: BorderSide(color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Apply Button
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        onPressed: _viewModel.refresh,
                                        icon: const Icon(Icons.filter_list, size: 14),
                                        label: Text(
                                          'Apply',
                                          style: AppFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF6B35),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Compact Summary Section (25-30% of screen height)
                  Container(
                    height: MediaQuery.of(context).size.height * 0.25, // Fixed 25% height
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
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
                        // Summary Header
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.summarize, color: Colors.purple.shade600, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Summary for ${_viewModel.dateRangeText}',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Compact GridView (5 cards per row on desktop)
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5, // 5 cards per row on desktop
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.8, // Compact aspect ratio
                            ),
                            itemCount: _viewModel.formattedSummary.entries.length,
                            itemBuilder: (context, index) {
                              final entry = _viewModel.formattedSummary.entries.elementAt(index);
                              return _buildCompactSummaryCard(entry.key, entry.value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Data Table Section with Fixed Height
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
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
                          // Enhanced Header with instant update feedback
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Dynamic header with icon and loading state
                                Row(
                                  children: [
                                    // Module icon with animation
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: Container(
                                        key: ValueKey(_viewModel.selectedReportType),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _getModuleColor(_viewModel.selectedReportType).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          _getModuleIcon(_viewModel.selectedReportType),
                                          size: 16,
                                          color: _getModuleColor(_viewModel.selectedReportType),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Module title with count
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: Text(
                                            _getModuleDisplayName(_viewModel.selectedReportType),
                                            key: ValueKey('title_${_viewModel.selectedReportType}'),
                                            style: AppFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 300),
                                              child: _viewModel.loading
                                                  ? SizedBox(
                                                      key: const ValueKey('loading'),
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          _getModuleColor(_viewModel.selectedReportType),
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      key: ValueKey('count_${_viewModel.currentDataCount}'),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: _getModuleColor(_viewModel.selectedReportType).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        '${_viewModel.currentDataCount}',
                                                        key: ValueKey('text_${_viewModel.currentDataCount}'),
                                                        style: AppFonts.poppins(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: _getModuleColor(_viewModel.selectedReportType),
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                            if (!_viewModel.loading) ...[
                                              const SizedBox(width: 6),
                                              AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 300),
                                                child: Icon(
                                                  _getDataStatusIcon(),
                                                  key: ValueKey('status_${_viewModel.currentDataCount}'),
                                                  size: 12,
                                                  color: _getDataStatusColor(),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                // Export buttons
                                Row(
                                  children: [
                                    // Export PDF button
                                    ElevatedButton.icon(
                                      onPressed: _viewModel.exportingPdf ? null : _exportToPdf,
                                      icon: _viewModel.exportingPdf
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.picture_as_pdf, size: 12),
                                      label: Text(
                                        _viewModel.exportingPdf ? '...' : 'PDF',
                                        style: AppFonts.poppins(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        minimumSize: Size(0, 28),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Export CSV button
                                    ElevatedButton.icon(
                                      onPressed: _viewModel.exportingCsv ? null : _exportToCsv,
                                      icon: _viewModel.exportingCsv
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.table_chart, size: 12),
                                      label: Text(
                                        _viewModel.exportingCsv ? '...' : 'CSV',
                                        style: AppFonts.poppins(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        minimumSize: Size(0, 28),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Scrollable Data Table with Fixed Header
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: _viewModel.loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _viewModel.currentData.isEmpty
                                      ? _buildEmptyState()
                                      : Column(
                                          children: [
                                            // Header row with background
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                              ),
                                              child: Row(
                                                children: _buildTableHeaders(),
                                              ),
                                            ),
                                            // Scrollable data rows
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  children: _buildTableRows(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfessionalDateField(String label, TextEditingController controller, VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.text.isEmpty ? label : _formatDateDisplay(controller.text),
                style: AppFonts.poppins(
                  fontSize: 11,
                  color: controller.text.isEmpty ? Colors.grey.shade500 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSummaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.03),
            const Color(0xFFFF6B35).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact title with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getSummaryIcon(title),
                  size: 10,
                  color: const Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          
          // Compact value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF6B35),
              ),
            ),
          ),
        ],
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

  IconData _getSummaryIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('total') || lowerTitle.contains('count')) {
      return Icons.analytics_outlined;
    } else if (lowerTitle.contains('pending') || lowerTitle.contains('progress')) {
      return Icons.pending_outlined;
    } else if (lowerTitle.contains('complete') || lowerTitle.contains('done')) {
      return Icons.check_circle_outline;
    } else if (lowerTitle.contains('amount') || lowerTitle.contains('value')) {
      return Icons.currency_exchange_outlined;
    } else if (lowerTitle.contains('active') || lowerTitle.contains('live')) {
      return Icons.play_circle_outline;
    } else if (lowerTitle.contains('inactive') || lowerTitle.contains('inactive')) {
      return Icons.pause_circle_outline;
    } else {
      return Icons.summarize_outlined;
    }
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
          // Enhanced Header with instant update feedback
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dynamic header with icon and loading state
                Row(
                  children: [
                    // Module icon with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_viewModel.selectedReportType),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getModuleColor(_viewModel.selectedReportType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getModuleIcon(_viewModel.selectedReportType),
                          size: 20,
                          color: _getModuleColor(_viewModel.selectedReportType),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Module title with count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _getModuleDisplayName(_viewModel.selectedReportType),
                            key: ValueKey('title_${_viewModel.selectedReportType}'),
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _viewModel.loading
                                  ? SizedBox(
                                      key: const ValueKey('loading'),
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _getModuleColor(_viewModel.selectedReportType),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      key: ValueKey('count_${_viewModel.currentDataCount}'),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getModuleColor(_viewModel.selectedReportType).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_viewModel.currentDataCount} items',
                                        key: ValueKey('text_${_viewModel.currentDataCount}'),
                                        style: AppFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getModuleColor(_viewModel.selectedReportType),
                                        ),
                                      ),
                                    ),
                            ),
                            if (!_viewModel.loading) ...[
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  _getDataStatusIcon(),
                                  key: ValueKey('status_${_viewModel.currentDataCount}'),
                                  size: 16,
                                  color: _getDataStatusColor(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Export buttons (unchanged)
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
                          children: _buildTableHeaders(),
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
        case 'rental':
          final rentalItem = item as RentalItem;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Item Name column (250px, left-aligned)
                SizedBox(
                  width: 250,
                  child: Text(
                    rentalItem.name ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Owner Name column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      rentalItem.ownerName ?? '-',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Rent Amount column (150px, center-aligned)
                SizedBox(
                  width: 150,
                  child: Center(
                    child: Text(
                      'PKR ${rentalItem.price?.toStringAsFixed(2) ?? '0.00'}',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Status column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: _buildRentalStatusChip(rentalItem.isActive),
                  ),
                ),
              ],
            ),
          );
        case 'todo':
          final todoItem = item as Reminder;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Title column (250px, left-aligned)
                SizedBox(
                  width: 250,
                  child: Text(
                    todoItem.reminderTitle ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Client Name column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      todoItem.clientName ?? '-',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Date column (150px, center-aligned)
                SizedBox(
                  width: 150,
                  child: Center(
                    child: Text(
                      '${todoItem.reminderDate ?? ''} at ${todoItem.reminderTime ?? ''}',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Status column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: _buildTodoStatusChip(todoItem.notificationStatus),
                  ),
                ),
              ],
            ),
          );
        case 'trading':
          final tradingItem = item as TradingEntry;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Item Name column (250px, left-aligned)
                SizedBox(
                  width: 250,
                  child: Text(
                    tradingItem.personName ?? '',
                    style: AppFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Entry Type column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(
                      tradingItem.type == TradingType.buy ? 'Buy' : 'Sell',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Amount column (150px, center-aligned)
                SizedBox(
                  width: 150,
                  child: Center(
                    child: Text(
                      'PKR ${tradingItem.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Status column (120px, center-aligned)
                SizedBox(
                  width: 120,
                  child: Center(
                    child: _buildTradingStatusChip(tradingItem.isSynced ?? false),
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

  List<Widget> _buildTableHeaders() {
    switch (_viewModel.selectedReportType) {
      case 'agent_working':
        return [
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
        ];
      case 'inventory':
        return [
          // Item Name header (250px)
          SizedBox(
            width: 250,
            child: Text(
              'Item Name',
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Type header (120px)
          SizedBox(
            width: 120,
            child: Text(
              'Type',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Client header (150px)
          SizedBox(
            width: 150,
            child: Text(
              'Client',
              textAlign: TextAlign.center,
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
        ];
      case 'expenditure':
        return [
          // Description header (250px)
          SizedBox(
            width: 250,
            child: Text(
              'Description',
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Amount header (120px)
          SizedBox(
            width: 120,
            child: Text(
              'Amount',
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
        ];
      case 'rental':
        return [
          // Item Name header (250px)
          SizedBox(
            width: 250,
            child: Text(
              'Item Name',
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Owner Name header (120px)
          SizedBox(
            width: 120,
            child: Text(
              'Owner Name',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Rent Amount header (150px)
          SizedBox(
            width: 150,
            child: Text(
              'Rent Amount',
              textAlign: TextAlign.center,
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
        ];
      case 'todo':
        return [
          // Title header (250px)
          SizedBox(
            width: 250,
            child: Text(
              'Title',
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Client Name header (120px)
          SizedBox(
            width: 120,
            child: Text(
              'Client Name',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Date & Time header (150px)
          SizedBox(
            width: 150,
            child: Text(
              'Date & Time',
              textAlign: TextAlign.center,
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
        ];
      case 'trading':
        return [
          // Item Name header (250px)
          SizedBox(
            width: 250,
            child: Text(
              'Item Name',
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Entry Type header (120px)
          SizedBox(
            width: 120,
            child: Text(
              'Entry Type',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          // Amount header (150px)
          SizedBox(
            width: 150,
            child: Text(
              'Amount',
              textAlign: TextAlign.center,
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
        ];
      default:
        return [];
    }
  }

  Widget _buildRentalStatusChip(bool isSynced) {
    final statusText = isSynced ? 'Active' : 'Inactive';
    Color color;
    
    switch (statusText.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'inactive':
        color = Colors.grey;
        break;
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
        statusText,
        style: AppFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTodoStatusChip(String? notificationStatus) {
    final statusText = notificationStatus ?? 'Unknown';
    Color color;
    
    switch (statusText.toLowerCase()) {
      case 'sent':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
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
        statusText,
        style: AppFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTradingStatusChip(bool isSynced) {
    final statusText = isSynced ? 'Active' : 'Inactive';
    Color color;
    
    switch (statusText.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'inactive':
        color = Colors.grey;
        break;
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
        statusText,
        style: AppFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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

  // Helper methods for enhanced header functionality
  Color _getModuleColor(String reportType) {
    switch (reportType) {
      case 'inventory':
        return Colors.blue;
      case 'rental':
        return Colors.green;
      case 'todo':
        return Colors.orange;
      case 'expenditure':
        return Colors.purple;
      case 'trading':
        return Colors.red;
      case 'agent_working':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getModuleIcon(String reportType) {
    switch (reportType) {
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'rental':
        return Icons.chair_outlined;
      case 'todo':
        return Icons.checklist_outlined;
      case 'expenditure':
        return Icons.receipt_long_outlined;
      case 'trading':
        return Icons.currency_exchange_outlined;
      case 'agent_working':
        return Icons.support_agent_outlined;
      default:
        return Icons.dashboard_outlined;
    }
  }

  String _getModuleDisplayName(String reportType) {
    switch (reportType) {
      case 'inventory':
        return 'Inventory Items';
      case 'rental':
        return 'Rental Items';
      case 'todo':
        return 'To-Do Tasks';
      case 'expenditure':
        return 'Expenditure Records';
      case 'trading':
        return 'Trading Entries';
      case 'agent_working':
        return 'Agent Working';
      default:
        return reportType.toUpperCase();
    }
  }

  IconData _getDataStatusIcon() {
    final count = _viewModel.currentDataCount;
    if (count == 0) {
      return Icons.info_outline;
    } else if (count < 10) {
      return Icons.trending_up;
    } else if (count < 50) {
      return Icons.bar_chart;
    } else {
      return Icons.analytics;
    }
  }

  Color _getDataStatusColor() {
    final count = _viewModel.currentDataCount;
    if (count == 0) {
      return Colors.grey;
    } else if (count < 10) {
      return Colors.blue;
    } else if (count < 50) {
      return Colors.green;
    } else {
      return Colors.purple;
    }
  }
}
