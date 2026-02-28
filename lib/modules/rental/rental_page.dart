import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, compute;
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:path/path.dart' as p;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:drive_client/drive_client.dart';
import 'package:drive_client/retention.dart';
import 'package:http/http.dart' as http;
import 'package:system_tray/system_tray.dart' if (dart.library.html) '../../platform_stubs/system_tray_stub.dart' hide AppWindow;
import '../../platform_stubs/window_manager_stub.dart';
import '../../core/services/auth_service.dart';
import '../../login_page.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
import '../../core/professional_pdf_generator.dart';
import '../../core/phone_actions.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart';
import '../../core/services/firestore_cache_service.dart';
import '../../firestore_sync_service.dart';
import '../../image_cache_service.dart';
import '../../responsive_widgets.dart';
import '../../offline_sync_service.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../widgets/stat_card.dart' show StatCard;
import '../../widgets/performance_chart_card.dart' show PerformanceChartCard;
import '../../core/app.dart' show AdminApp;
import '../../core/shared_utils.dart' show TopRightSearch, buildResponsiveInfoRow, InfoEntry;
import '../../modules/inventory/inventory_page.dart' show FilesPage;
import '../../modules/todo/todo_page.dart' show ToDoPage;
import '../../modules/trading/trading_page.dart' show TradingPage;
import 'package:provider/provider.dart';
import '../../presentation/expenditure/expenditure_page.dart' show ExpenditurePage;
import '../../presentation/expenditure/expenditure_view_model.dart';
import '../../modules/users/users_page.dart' as users show UsersPage;
import '../../modules/companies/companies_page.dart' as companies show CompaniesPage;
import '../../presentation/reports/reports_page.dart' show ReportsPage;
import '../../modules/settings/settings_page.dart' show SettingsPage;
import '../../presentation/view_models/rental_view_model.dart';
import '../../domain/repositories/rental_repository.dart';
import '../../data/repositories/rental_repository_impl.dart';
import 'package:shared/shared.dart' show AppDatabase;
import 'package:shared/shared.dart' as shared;

class RentalItemsPage extends StatefulWidget {
  final AppDatabase db;
  final String? initialFilter; // 'Not Sold', 'Sold', 'Maintenance'
  final VoidCallback? onFilterCleared;
  const RentalItemsPage({
    super.key, 
    required this.db,
    this.initialFilter,
    this.onFilterCleared,
  });
  @override
  State<RentalItemsPage> createState() => _RentalItemsPageState();
}

class _RentalItemsPageState extends State<RentalItemsPage> {
  late RentalViewModel _viewModel;
  String? _currentFilter; // Current filter status

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    
    // Initialize ViewModel with database instance
    _viewModel = RentalViewModel(repository: RentalRepositoryImpl(widget.db));
    
    Future.microtask(() async {
      await _viewModel.initialize();
      
      // Apply initial filter if provided
      if (_currentFilter != null) {
        switch (_currentFilter) {
          case 'Not Sold':
            await _viewModel.filterByStatus(RentalStatus.available);
            break;
          case 'Sold':
            await _viewModel.filterByStatus(RentalStatus.rented);
            break;
          case 'Maintenance':
            await _viewModel.filterByStatus(RentalStatus.maintenance);
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showAddFormDialog({Map<String, dynamic>? existing}) {
    // TODO: Implement form dialog with ViewModel integration
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Rental Item' : 'Edit Rental Item'),
        content: const Text('Form dialog will be implemented with ViewModel integration'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkAsSold(Map<String, dynamic> entry) async {
    final success = await _viewModel.updateRentalStatus(entry['id'].toString(), RentalStatus.rented);
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.errorMessage ?? 'Failed to update rental item'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleMarkAsNotSold(Map<String, dynamic> entry) async {
    final success = await _viewModel.updateRentalStatus(entry['id'].toString(), RentalStatus.available);
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.errorMessage ?? 'Failed to update rental item'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('Delete rental item $id?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    
    final success = await _viewModel.deleteRentalItem(id);
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.errorMessage ?? 'Failed to delete rental item'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RentalViewModel>.value(
      value: _viewModel,
      child: Consumer<RentalViewModel>(
        builder: (context, viewModel, child) {
          // Apply filter first, then search
          List<Map<String, dynamic>> filteredItems = viewModel.rentalItems;
          if (_currentFilter != null) {
            if (_currentFilter == 'Not Sold') {
              filteredItems = viewModel.rentalItems.where((r) => (r['sale_status']?.toString() ?? 'Available') == 'Available').toList();
            } else if (_currentFilter == 'Sold') {
              filteredItems = viewModel.rentalItems.where((r) => (r['sale_status']?.toString() ?? 'Available') == 'Rented').toList();
            } else if (_currentFilter == 'Maintenance') {
              // Filter by remarks containing maintenance-related keywords
              filteredItems = viewModel.rentalItems.where((r) {
                final remarks = (r['remarks']?.toString() ?? '').toLowerCase();
                return remarks.contains('maintenance') || remarks.contains('repair') || remarks.contains('fix');
              }).toList();
            }
          }
          final rows = viewModel.searchQuery.isEmpty
              ? filteredItems
              : filteredItems.where((r) => 
                  (r['name']?.toString() ?? '').toLowerCase().contains(viewModel.searchQuery.toLowerCase()) ||
                  (r['location']?.toString() ?? '').toLowerCase().contains(viewModel.searchQuery.toLowerCase()) ||
                  (r['owner_name']?.toString() ?? '').toLowerCase().contains(viewModel.searchQuery.toLowerCase()) ||
                  (r['remarks']?.toString() ?? '').toLowerCase().contains(viewModel.searchQuery.toLowerCase()) ||
                  (r['contact_no']?.toString() ?? '').toLowerCase().contains(viewModel.searchQuery.toLowerCase())
                ).toList();
          
          final showActionMenu = viewModel.canEditRental || viewModel.canDeleteRental;
          
          return Scaffold(
            appBar: AppBar(
              title: Text('Rental Items', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF6B35), // Orange
                      const Color(0xFF4A90E2), // Blue
                    ],
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: TopRightSearch(onChanged: (q) => viewModel.searchRentalItems(q)),
                ),
              ],
            ),
            floatingActionButton: viewModel.canAddRental
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddFormDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Rental Item'),
                  )
                : null,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 900;
                return Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
                                  const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
                                ],
                              ),
                              border: Border.all(
                                color: Colors.grey.shade300.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                viewModel.loading
                                    ? const Center(child: CircularProgressIndicator())
                                    : rows.isEmpty
                                        ? const Center(child: Text('No rental items found'))
                                        : ListView.builder(
                                            padding: const EdgeInsets.all(12),
                                            itemCount: rows.length,
                                            itemBuilder: (ctx, i) {
                                              final r = rows[i];
                                              final TextStyle infoStyle = TextStyle(
                                                fontSize: 14,
                                                color: const Color(0xFFFF6B35),
                                              );
                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                elevation: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              r['name']?.toString() ?? 'N/A',
                                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                                            ),
                                                          ),
                                                          FilledButton.icon(
                                                            icon: const Icon(Icons.visibility, size: 16),
                                                            label: const Text('Details'),
                                                            style: FilledButton.styleFrom(
                                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                              textStyle: const TextStyle(fontSize: 12),
                                                            ),
                                                            onPressed: () {
                                                              // TODO: Navigate to detail page
                                                            },
                                                          ),
                                                          const SizedBox(width: 8),
                                                          if (showActionMenu)
                                                            PopupMenuButton<String>(
                                                              icon: const Icon(Icons.more_vert),
                                                              itemBuilder: (context) => [
                                                                if (viewModel.canEditRental)
                                                                  PopupMenuItem<String>(
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                                                                        const SizedBox(width: 8),
                                                                        const Text('Mark as Sold'),
                                                                      ],
                                                                    ),
                                                                    onTap: () async {
                                                                      await Future.delayed(const Duration(milliseconds: 100));
                                                                      if (mounted) {
                                                                        await _handleMarkAsSold(r);
                                                                      }
                                                                    },
                                                                  ),
                                                                if (viewModel.canEditRental)
                                                                  PopupMenuItem<String>(
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.close, size: 18, color: Colors.orange.shade700),
                                                                        const SizedBox(width: 8),
                                                                        const Text('Mark as Not Sold'),
                                                                      ],
                                                                    ),
                                                                    onTap: () async {
                                                                      await Future.delayed(const Duration(milliseconds: 100));
                                                                      if (mounted) {
                                                                        await _handleMarkAsNotSold(r);
                                                                      }
                                                                    },
                                                                  ),
                                                                if (viewModel.canEditRental) const PopupMenuDivider(),
                                                                if (viewModel.canEditRental)
                                                                  PopupMenuItem<String>(
                                                                    child: const Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                                                                    onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _showAddFormDialog(existing: r)),
                                                                  ),
                                                                if (viewModel.canDeleteRental)
                                                                  PopupMenuItem<String>(
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.delete, size: 18, color: Colors.red.shade700),
                                                                        const SizedBox(width: 8),
                                                                        const Text('Delete'),
                                                                      ],
                                                                    ),
                                                                    onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _delete(r['id']?.toString() ?? '')),
                                                                  ),
                                                              ],
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      buildResponsiveInfoRow(
                                                        context,
                                                        [
                                                          InfoEntry('Property Type', r['name']?.toString() ?? 'N/A', style: infoStyle),
                                                          InfoEntry('Price', r['price'] != null ? 'Rs ${r['price']}' : 'N/A', style: infoStyle),
                                                        ],
                                                      ),
                                                      buildResponsiveInfoRow(
                                                        context,
                                                        [
                                                          InfoEntry('Owner Name', r['owner_name']?.toString() ?? 'N/A', style: infoStyle),
                                                          InfoEntry('Contact No', r['contact_no']?.toString() ?? 'N/A', style: infoStyle),
                                                        ],
                                                      ),
                                                      buildResponsiveInfoRow(
                                                        context,
                                                        [
                                                          InfoEntry('Security', r['security'] != null ? 'Rs ${r['security']}' : 'N/A', style: infoStyle),
                                                        ],
                                                      ),
                                                      buildResponsiveInfoRow(
                                                        context,
                                                        [
                                                          InfoEntry('Location', r['location']?.toString() ?? 'N/A', style: infoStyle),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      buildResponsiveInfoRow(
                                                        context,
                                                        [
                                                          InfoEntry('Status', r['sale_status']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 14)),
                                                          InfoEntry('Remarks', r['remarks']?.toString() ?? 'N/A', style: infoStyle),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text('Updated: ${r['updated_at']?.toString().split('T').first ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
