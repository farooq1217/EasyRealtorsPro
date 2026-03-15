import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey, FilteringTextInputFormatter, Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'package:provider/provider.dart';
import '../../core/font_utils.dart';
import '../../core/services/auth_service.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
import '../../core/professional_pdf_generator.dart';
import '../../core/phone_actions.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart';
import '../../image_cache_service.dart';
import '../../responsive_widgets.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../core/shared_utils.dart' show TopRightSearch;
import '../companies/company_view_model.dart';
import '../companies/models/company_model.dart';
import 'repositories/company_repository_impl.dart';

class CompaniesPage extends StatefulWidget {
  final AppDatabase db;
  const CompaniesPage({super.key, required this.db});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  late CompanyViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    
    // Initialize ViewModel with Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel = CompanyViewModel(CompanyRepositoryImpl(widget.db));
      _viewModel.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CompanyViewModel>.value(
      value: _viewModel,
      child: Consumer<CompanyViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('Companies Management', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              actions: [
                // Add button
                if (viewModel.canAdd)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddCompanyDialog(context, viewModel),
                    tooltip: 'Add Company',
                  ),
                // Global Search
                TopRightSearch(
                  onChanged: (query) => viewModel.setSearchQuery(query),
                  hintText: 'Search companies...',
                ),
              ],
            ),
            body: Column(
              children: [
                // Statistics Cards
                _buildStatisticsCards(context, viewModel),
                
                // Company List
                Expanded(
                  child: viewModel.filteredCompanies.isEmpty
                      ? _buildEmptyState(context, viewModel)
                      : _buildCompanyList(context, viewModel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, CompanyViewModel viewModel) {
    return FutureBuilder<Map<String, dynamic>>(
      future: viewModel.getCompanyStatistics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        return Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Companies',
                  stats['total_companies'].toString(),
                  Icons.business,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Active',
                  stats['active_companies'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Inactive',
                  stats['inactive_companies'].toString(),
                  Icons.pause_circle,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Archived',
                  stats['archived_companies'].toString(),
                  Icons.archive,
                  Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, CompanyViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "No Companies Found",
            style: AppFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (viewModel.canAdd)
            Text(
              "Tap the + button to add your first company",
              style: AppFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompanyList(BuildContext context, CompanyViewModel viewModel) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: viewModel.filteredCompanies.length,
      itemBuilder: (context, index) {
        final company = viewModel.filteredCompanies[index];
        return _buildCompanyCard(context, company, viewModel);
      },
    );
  }

  Widget _buildCompanyCard(BuildContext context, CompanyModel company, CompanyViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: company.isActive ? Colors.blue : Colors.grey,
          child: Text(
            company.name.isNotEmpty ? company.name[0].toUpperCase() : 'C',
            style: AppFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          company.name,
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${company.maxUserLimit ?? 5} users',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  company.subscriptionTier ?? 'Starter',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (company.address != null)
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      company.address!,
                      style: AppFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            if (company.contact != null)
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      company.contact!,
                      style: AppFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(company.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                company.status ?? 'active',
                style: AppFonts.poppins(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Action menu
            if (viewModel.canEdit || viewModel.canDelete)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    viewModel.editCompany(company);
                    _showAddCompanyDialog(context, viewModel);
                  } else if (value == 'toggle_status') {
                    final newStatus = company.status == 'active' ? 'inactive' : 'active';
                    viewModel.toggleCompanyStatus(company.id, newStatus);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(context, company, viewModel);
                  }
                },
                itemBuilder: (context) => [
                  if (viewModel.canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  if (viewModel.canEdit)
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(company.status == 'active' ? Icons.pause : Icons.play_arrow),
                          const SizedBox(width: 8),
                          Text(company.status == 'active' ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                  if (viewModel.canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'archived':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  void _showAddCompanyDialog(BuildContext context, CompanyViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.8,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                    const Spacer(),
                    Text(
                      viewModel.editingCompany == null ? 'Add Company' : 'Edit Company',
                      style: AppFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCompanyForm(dialogContext, viewModel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyForm(BuildContext context, CompanyViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name field
        Text(
          'Company Name',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.nameController,
          decoration: InputDecoration(
            hintText: 'Enter company name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),

        // Address field
        Text(
          'Address',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.addressController,
          decoration: InputDecoration(
            hintText: 'Enter company address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Contact field
        Text(
          'Contact Number',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.contactController,
          decoration: InputDecoration(
            hintText: 'Enter contact number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        // Max User Limit field
        Text(
          'Max User Limit',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.maxUserLimitController,
          decoration: InputDecoration(
            hintText: 'Leave blank for default based on subscription',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        // Subscription tier dropdown
        Text(
          'Subscription Tier',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: viewModel.selectedSubscriptionTier,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          items: viewModel.subscriptionTiers.map((tier) {
            return DropdownMenuItem<String>(
              value: tier,
              child: Text('$tier (${viewModel.getUserLimitForTier(tier)} users)'),
            );
          }).toList(),
          onChanged: (value) {
            viewModel.selectedSubscriptionTier = value;
          },
        ),
        const SizedBox(height: 16),

        // Status dropdown
        Text(
          'Status',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: viewModel.selectedStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            DropdownMenuItem(value: 'archived', child: Text('Archived')),
          ],
          onChanged: (value) {
            viewModel.selectedStatus = value;
          },
        ),
        const SizedBox(height: 24),

        // Error message
        if (viewModel.error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    viewModel.error,
                    style: AppFonts.poppins(
                      color: Colors.red.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  viewModel.clearForm();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Cancel",
                  style: AppFonts.poppins(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await viewModel.saveCompany();
                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            viewModel.editingCompany == null ? 'Company added successfully!' : 'Company updated successfully!',
                            style: AppFonts.poppins(),
                          ),
                          backgroundColor: const Color(0xFFFF6B35),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: viewModel.saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          viewModel.editingCompany == null ? "Add Company" : "Update Company",
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, CompanyModel company, CompanyViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Company?"),
        content: Text("Are you sure you want to delete ${company.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              final success = await viewModel.deleteCompany(company.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Company deleted successfully!',
                      style: AppFonts.poppins(),
                    ),
                    backgroundColor: Colors.red.shade600,
                  ),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
