import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_selector/file_selector.dart';
import '../../../../core/font_utils.dart';
import '../../../../core/services/permission_helper.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/app_storage.dart';
import '../view_models/reports_view_model.dart';
import '../../../widgets/custom_pagination_card.dart' show CustomPaginationCard;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;

class ReportsPage extends StatefulWidget {
  final AppDatabase db;
  const ReportsPage({super.key, required this.db});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late ReportsViewModel _viewModel;
  
  // Search controller
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _viewModel = ReportsViewModel(widget.db);
    
    // Initialize ViewModel but defer data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.initialize();
    });
  }
  

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportsViewModel>.value(
      value: _viewModel,
      child: Consumer<ReportsViewModel>(
        builder: (context, viewModel, child) {
          // Show loading state but keep buttons visible
          if (viewModel.loading) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Reports & Analytics', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
                actions: [
                  // Show placeholder buttons during loading to maintain UI consistency
                  const SizedBox(width: 48), // Placeholder for more_vert button
                  const SizedBox(width: 48), // Placeholder for add button
                  const SizedBox(width: 48), // Placeholder for search
                ],
              ),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading reports...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: Column(
              children: [
                // Scrollable Content Area (Header, Filters, Stats, Table)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Action Buttons
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: _buildHeaderSection(),
                        ),
                        const SizedBox(height: 24),
                        
                        // Search and Filter Section
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSearchAndFilterSection(),
                        ),
                        const SizedBox(height: 24),
                        
                        // Summary Dashboard (Stats Cards)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSummaryCards(),
                        ),
                        const SizedBox(height: 24),
                        
                        // Data Table (Non-scrollable within scrollable parent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildDataTable(),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Pagination (Fixed at bottom)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildPaginationCard(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Reports & Analytics',
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E), // Deep indigo
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Clear Filters Button
        ElevatedButton(
          onPressed: () {
            _viewModel.clearFilters();
            _searchController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Filters cleared')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.clear, size: 18),
              const SizedBox(width: 8),
              Text(
                'Clear Filters',
                style: AppFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Consumer<ReportsViewModel>(
      builder: (context, viewModel, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4A90E2)),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    viewModel.searchQuery = value;
                  },
                ),
                const SizedBox(height: 16),
                
                // Module and Date Range Filters
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      // Desktop layout: Row
                      return Row(
                        children: [
                          Expanded(child: _buildModuleDropdown(viewModel)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDateRangeDropdown(viewModel)),
                        ],
                      );
                    } else {
                      // Mobile layout: Column
                      return Column(
                        children: [
                          _buildModuleDropdown(viewModel),
                          const SizedBox(height: 12),
                          _buildDateRangeDropdown(viewModel),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleDropdown(ReportsViewModel viewModel) {
    return DropdownButtonFormField<String>(
      value: viewModel.selectedModule,
      decoration: InputDecoration(
        labelText: 'Report Type',
        hintText: 'Select module',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4A90E2)),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: viewModel.modules.map((module) => DropdownMenuItem(
        value: module,
        child: Text(module),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          viewModel.selectedModule = value;
        }
      },
    );
  }

  Widget _buildDateRangeDropdown(ReportsViewModel viewModel) {
    return DropdownButtonFormField<String>(
      value: viewModel.dateRange,
      decoration: InputDecoration(
        labelText: 'Date Range',
        hintText: 'Select range',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4A90E2)),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: viewModel.dateRanges.map((range) => DropdownMenuItem(
        value: range,
        child: Text(range),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          viewModel.dateRange = value;
        }
      },
    );
  }
  Widget _buildSummaryCards() {
    return Consumer<ReportsViewModel>(
      builder: (context, viewModel, child) {
        final stats = viewModel.getSummaryStatistics();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary for ${viewModel.dateRange}',
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Horizontal scrollable row of cards
            SizedBox(
              height: 120,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildSummaryCardsList(viewModel, stats),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSummaryCardsList(ReportsViewModel viewModel, Map<String, dynamic> stats) {
    final module = viewModel.selectedModule;
    
    switch (module) {
      case 'Agent Working':
        return [
          _buildSummaryCard(
            title: 'Total Transfers',
            value: stats['total'] ?? '0',
            icon: Icons.swap_horiz,
            color: Colors.blue.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
          _buildSummaryCard(
            title: 'Pending Transfers',
            value: stats['pending'] ?? '0',
            icon: Icons.pending,
            color: Colors.orange.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
        ];
      case 'Inventory':
        return [
          _buildSummaryCard(
            title: 'Total Inventory',
            value: stats['total'] ?? '0',
            icon: Icons.inventory,
            color: Colors.purple.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
          _buildSummaryCard(
            title: 'Sold Items',
            value: stats['sold'] ?? '0',
            icon: Icons.sell,
            color: Colors.green.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
          _buildSummaryCard(
            title: 'Available Items',
            value: stats['available'] ?? '0',
            icon: Icons.check_circle,
            color: Colors.teal.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
        ];
      case 'Expenditure':
        return [
          _buildSummaryCard(
            title: 'Total Expenditure',
            value: stats['total'] ?? 'Rs 0',
            icon: Icons.receipt_long,
            color: Colors.red.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
        ];
      case 'Trading':
        return [
          _buildSummaryCard(
            title: 'Total Buying',
            value: stats['buying'] ?? 'Rs 0',
            icon: Icons.shopping_cart,
            color: Colors.green.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
          _buildSummaryCard(
            title: 'Total Selling',
            value: stats['selling'] ?? 'Rs 0',
            icon: Icons.sell,
            color: Colors.orange.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
        ];
      default:
        return [
          _buildSummaryCard(
            title: 'Total Records',
            value: stats['total'] ?? '0',
            icon: Icons.analytics,
            color: Colors.blue.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
        ];
    }
  }

  Widget _buildDataTable() {
    return Consumer<ReportsViewModel>(
      builder: (context, viewModel, child) {
        final data = viewModel.paginatedReportsData;
        final moduleName = viewModel.selectedModule;
        final columns = viewModel.getTableColumns();
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and export buttons
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$moduleName DATA (${viewModel.filteredReportsData.length})',
                      style: AppFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // PDF Export Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _exportToPDF(viewModel.filteredReportsData, moduleName),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      tooltip: 'Export to PDF',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // CSV Export Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _exportToCSV(viewModel.filteredReportsData, moduleName),
                      icon: const Icon(Icons.table_chart, color: Colors.white),
                      tooltip: 'Export to CSV',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Data Table
              if (data.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No data found for $moduleName',
                          style: AppFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildDataTableContent(data, columns),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataTableContent(List<Map<String, dynamic>> data, List<Map<String, dynamic>> columns) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length + 1, // +1 for header
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header row
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: columns.map((column) {
                  return Expanded(
                    flex: column['flex'] ?? 1,
                    child: Text(
                      column['title'],
                      style: AppFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }
          
          final item = data[index - 1];
          return Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: columns.map((column) {
                final value = item[column['key']]?.toString() ?? '-';
                return Expanded(
                  flex: column['flex'] ?? 1,
                  child: Text(
                    value,
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: backgroundColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationCard() {
    return Consumer<ReportsViewModel>(
      builder: (context, viewModel, child) {
        return CustomPaginationCard(
          currentPage: viewModel.currentPage,
          totalItems: viewModel.filteredReportsData.length,
          itemsPerPage: viewModel.itemsPerPage,
          onPageChanged: (page) => viewModel.setPage(page),
          onItemsPerPageChanged: (limit) => viewModel.setItemsPerPage(limit),
        );
      },
    );
  }


  // Export Methods
  Future<void> _exportToCSV(List<Map<String, dynamic>> data, String moduleName) async {
    try {
      final viewModel = _viewModel;
      final columns = viewModel.getTableColumns();
      final List<List<String>> csvData = [];
      
      // Add header
      csvData.add(columns.map((col) => col['title'] as String).toList());
      
      // Add data rows
      for (final item in data) {
        final row = columns.map((col) => item[col['key']]?.toString() ?? '').toList();
        csvData.add(row);
      }
      
      final csv = const ListToCsvConverter().convert(csvData);
      
      // Save file
      final fileName = '${moduleName.toLowerCase().replaceAll(' ', '_')}_report.csv';
      final result = await getSaveLocation(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'CSV files',
            extensions: ['csv'],
            mimeTypes: ['text/csv'],
          ),
        ],
        suggestedName: fileName,
      );
      
      if (result != null && mounted) {
        final file = XFile.fromData(Uint8List.fromList(csv.codeUnits));
        await file.saveTo(result.path);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(List<Map<String, dynamic>> data, String moduleName) async {
    try {
      final viewModel = _viewModel;
      final columns = viewModel.getTableColumns();
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('$moduleName Report', 
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: columns.map((col) => col['title'] as String).toList(),
                  data: data.map((item) => 
                    columns.map((col) => item[col['key']]?.toString() ?? '').toList()
                  ).toList(),
                  border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(),
                  cellPadding: const pw.EdgeInsets.all(5),
                ),
              ],
            );
          },
        ),
      );
      
      final bytes = await pdf.save();
      
      // Save file
      final fileName = '${moduleName.toLowerCase().replaceAll(' ', '_')}_report.pdf';
      final result = await getSaveLocation(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'PDF files',
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
          ),
        ],
        suggestedName: fileName,
      );
      
      if (result != null && mounted) {
        final file = XFile.fromData(bytes);
        await file.saveTo(result.path);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
