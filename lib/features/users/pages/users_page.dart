import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey, FilteringTextInputFormatter, Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../view_models/user_view_model.dart';
import '../../../core/widgets/safe_dropdown.dart';
import '../../../shimmer_widgets.dart' show ShimmerPageLoading;
import '../../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
import '../../../core/professional_pdf_generator.dart' show ProfessionalPdfGenerator;
import '../../../core/phone_actions.dart' show showPhoneActionSheet;
import '../../../core/app_utils.dart';
import '../../../core/shared_utils.dart';
import '../../../image_cache_service.dart';
import '../../../responsive_widgets.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../models/user_model.dart';
import '../repositories/user_repository_impl.dart';
import '../widgets/user_card_widget.dart';
import '../../../widgets/custom_pagination_card.dart' show CustomPaginationCard;

class UsersPage extends StatefulWidget {
  final AppDatabase db;
  const UsersPage({super.key, required this.db});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late UserViewModel _viewModel;
  
  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCompany;
  String? _selectedRole;
  String? _selectedStatus;
  
  // Mock data for companies (replace with actual data from your database)
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _roles = [
    {'id': 'super_admin', 'name': 'Super Admin'},
    {'id': 'company_admin', 'name': 'Company Admin'},
    {'id': 'agent', 'name': 'Agent'},
    {'id': 'user', 'name': 'User'},
  ];
  
  List<Map<String, dynamic>> _statuses = [
    {'id': 'active', 'name': 'Active'},
    {'id': 'inactive', 'name': 'Inactive'},
    {'id': 'archived', 'name': 'Archived'},
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = UserViewModel(UserRepositoryImpl(widget.db));
    
    debugPrint('UsersPage: initState called, widget mounted: $mounted');
    
    // Initialize ViewModel but defer stream setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('UsersPage: PostFrameCallback - widget mounted: $mounted');
      _viewModel.initialize();
      _loadCompanies();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('UsersPage: didChangeDependencies called, widget mounted: $mounted');
    // Set mounted state when dependencies change
    _viewModel.setMounted(mounted);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    // Load companies from database - this is a placeholder
    // Replace with actual company loading logic
    setState(() {
      _companies = [
        {'id': '1', 'name': 'EasyRealtors'},
        {'id': '2', 'name': 'Property Plus'},
        {'id': '3', 'name': 'Real Estate Pro'},
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: _viewModel,
      child: Consumer<UserViewModel>(
        builder: (context, viewModel, child) {
          // Show loading state but keep buttons visible
          if (viewModel.loading) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Users Management', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
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
                    Text('Loading users...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: Column(
              children: [
                // Scrollable Content Area (Header, Filters, Stats, Grid)
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
                          child: _buildStatsDashboard(),
                        ),
                        const SizedBox(height: 24),
                        
                        // User Grid (Non-scrollable within scrollable parent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildUserGrid(),
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
            'User Management',
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E), // Deep indigo
            ),
          ),
        ),
        const SizedBox(width: 16),
      // "Add New User" Button (Filled)
      ElevatedButton(
        onPressed: () => _showAddUserDialog(context, _viewModel),
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
            const Icon(Icons.add, size: 18),
            const SizedBox(width: 8),
            Text(
              'Add New User',
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
                hintText: 'Search users by name, CNIC, or email...',
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
                _viewModel.setSearchQuery(value);
              },
            ),
            const SizedBox(height: 16),
            
            // Filter Dropdowns and Action Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1200) {
                  // Desktop layout: Row
                  return Row(
                    children: [
                      Expanded(child: _buildCompanyDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRoleDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatusDropdown()),
                      const SizedBox(width: 12),
                      _buildFilterActions(),
                    ],
                  );
                } else {
                  // Mobile layout: Column
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildCompanyDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRoleDropdown()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildStatusDropdown()),
                          const SizedBox(width: 12),
                          _buildFilterActions(),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCompany,
      decoration: InputDecoration(
        labelText: 'Company',
        hintText: 'All companies',
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
      items: [
        const DropdownMenuItem(value: null, child: Text('All companies')),
        ..._companies.map((company) => DropdownMenuItem(
          value: company['id'],
          child: Text(company['name']),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCompany = value;
        });
        // Apply filter logic using existing search functionality
        _applyAllFilters();
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: InputDecoration(
        labelText: 'Role',
        hintText: 'All roles',
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
      items: [
        const DropdownMenuItem(value: null, child: Text('All roles')),
        ..._roles.map((role) => DropdownMenuItem(
          value: role['id'],
          child: Text(role['name']),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
        });
        // Apply filter logic using existing search functionality
        _applyAllFilters();
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        hintText: 'All statuses',
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
      items: [
        const DropdownMenuItem(value: null, child: Text('All statuses')),
        ..._statuses.map((status) => DropdownMenuItem(
          value: status['id'],
          child: Text(status['name']),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
        });
        // Apply filter logic using existing search functionality
        _applyAllFilters();
      },
    );
  }

  Widget _buildFilterActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Refresh Button
        IconButton(
          onPressed: () {
            _viewModel.initialize();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data refreshed')),
            );
          },
          icon: const Icon(Icons.refresh, color: Color(0xFF4A90E2)),
          tooltip: 'Refresh',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Sync Button
        IconButton(
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Syncing from Firestore...')),
            );
            try {
              await _viewModel.syncFromFirestore();
              await _viewModel.initialize(); // Refresh data
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Firestore sync completed!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.cloud_download, color: Color(0xFF4A90E2)),
          tooltip: 'Sync from Firestore',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Clear Button
        TextButton(
          onPressed: () {
            setState(() {
              _searchController.clear();
              _selectedCompany = null;
              _selectedRole = null;
              _selectedStatus = null;
            });
            _viewModel.setSearchQuery('');
          },
          child: Text(
            'Clear',
            style: AppFonts.poppins(
              color: const Color(0xFF4A90E2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsDashboard() {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        return FutureBuilder<Map<String, dynamic>>(
          future: viewModel.getUserStatistics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final stats = snapshot.data!;
            
            return LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: Grid on mobile, Row on desktop
                if (constraints.maxWidth > 768) {
                  // Desktop: Row layout
                  return Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Users', stats['total_users'].toString(), Icons.people, Colors.blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Active', stats['active_users'].toString(), Icons.person, Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Inactive', stats['inactive_users'].toString(), Icons.person_off, Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Archived', stats['archived_users'].toString(), Icons.archive, Colors.red)),
                    ],
                  );
                } else {
                  // Mobile: Grid layout
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard('Total Users', stats['total_users'].toString(), Icons.people, Colors.blue),
                      _buildStatCard('Active', stats['active_users'].toString(), Icons.person, Colors.green),
                      _buildStatCard('Inactive', stats['inactive_users'].toString(), Icons.person_off, Colors.orange),
                      _buildStatCard('Archived', stats['archived_users'].toString(), Icons.archive, Colors.red),
                    ],
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildUserGrid() {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.loading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading users...'),
              ],
            ),
          );
        }

        // Use viewModel.paginatedUsers for pagination
        if (viewModel.paginatedUsers.isEmpty) {
          return _buildEmptyState();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid: 1 column on mobile, 2-3 on desktop
            int crossAxisCount;
            if (constraints.maxWidth > 1200) {
              crossAxisCount = 3; // Desktop: 3 cards per row
            } else if (constraints.maxWidth > 800) {
              crossAxisCount = 2; // Tablet: 2 cards per row
            } else {
              crossAxisCount = 1; // Mobile: 1 card per row
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1, // Further reduced to prevent bottom overflow
              ),
              itemCount: viewModel.paginatedUsers.length,
              itemBuilder: (context, index) {
                final user = viewModel.paginatedUsers[index];
                return UserCard(
                  user: user,
                  onEditUser: (user) => _showEditUserDialog(context, user),
                  onUpdatePassword: (user) => _showUpdatePasswordDialog(context, user),
                  onManageRoles: (user) => _showManageRolesDialog(context, user),
                  onDeleteUser: (user) => _showDeleteConfirmation(context, user),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "No Users Found",
            style: AppFonts.poppins(
              fontSize: 20,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters",
            style: AppFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationCard() {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        return CustomPaginationCard(
          currentPage: viewModel.currentPage,
          totalItems: viewModel.filteredUsers.length,
          itemsPerPage: viewModel.itemsPerPage,
          onPageChanged: (page) => viewModel.setPage(page),
          onItemsPerPageChanged: (limit) => viewModel.setItemsPerPage(limit),
        );
      },
    );
  }

  void _applyAllFilters() {
    // Build search query based on all filters
    String searchQuery = _searchController.text;
    
    // Add company filter if selected
    if (_selectedCompany != null) {
      final company = _companies.firstWhere(
        (c) => c['id'] == _selectedCompany,
        orElse: () => {'name': 'Unknown'},
      );
      searchQuery += ' ${company['name']}';
    }
    
    // Add role filter if selected
    if (_selectedRole != null) {
      final role = _roles.firstWhere(
        (r) => r['id'] == _selectedRole,
        orElse: () => {'name': 'Unknown'},
      );
      searchQuery += ' ${role['name']}';
    }
    
    // Add status filter if selected
    if (_selectedStatus != null) {
      final status = _statuses.firstWhere(
        (s) => s['id'] == _selectedStatus,
        orElse: () => {'name': 'Unknown'},
      );
      searchQuery += ' ${status['name']}';
    }
    
    // Apply the combined search query
    _viewModel.setSearchQuery(searchQuery.trim());
  }

  void _showAddUserDialog(BuildContext context, UserViewModel viewModel) {
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
          child: _buildAddUserDialogContent(dialogContext, viewModel),
        ),
      ),
    );
  }

  Widget _buildAddUserDialogContent(BuildContext context, UserViewModel viewModel) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildUserForm(context, viewModel),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    _viewModel.setEditingUser(user);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<UserViewModel>.value(
        value: _viewModel,
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.6,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
            ),
            child: _buildEditUserDialogContent(dialogContext),
          ),
        ),
      ),
    );
  }

  Widget _buildEditUserDialogContent(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFF4A90E2)),
                  const SizedBox(width: 12),
                  Text(
                    'Edit User',
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Form Fields
              TextFormField(
                controller: viewModel.nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: viewModel.emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: viewModel.contactController,
                decoration: InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      viewModel.clearEditingUser();
                    },
                    child: Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: viewModel.saving ? null : () async {
                      await viewModel.updateUser();
                      if (viewModel.error.isEmpty) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('User updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(viewModel.error),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: viewModel.saving 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Update User'),
                  ),
                ],
              ),
            ],
          ),
        ),
        ); // Close SingleChildScrollView and Padding
      },
    );
  }

  // Step 3: Update Password Dialog
  void _showUpdatePasswordDialog(BuildContext context, UserModel user) {
    _viewModel.setEditingUser(user);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<UserViewModel>.value(
        value: _viewModel,
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.5,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
            ),
            child: _buildUpdatePasswordDialogContent(dialogContext),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatePasswordDialogContent(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.lock, color: Color(0xFF4A90E2)),
                  const SizedBox(width: 12),
                  Text(
                    'Update Password',
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Form Fields
              TextFormField(
                controller: viewModel.passwordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: viewModel.confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      viewModel.clearEditingUser();
                    },
                    child: Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: viewModel.saving ? null : () async {
                      final newPassword = viewModel.passwordController.text;
                      final confirmPassword = viewModel.confirmPasswordController.text;
                      
                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password must be at least 6 characters'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      await viewModel.updateUserPassword(newPassword);
                      if (viewModel.error.isEmpty) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(viewModel.error),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: viewModel.saving 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Update Password'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserForm(BuildContext context, UserViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name field
        Text(
          'Full Name',
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
            hintText: 'Enter full name',
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

        // Email field
        Text(
          'Email',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.emailController,
          decoration: InputDecoration(
            hintText: 'Enter email address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Username field
        Text(
          'Username',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.usernameController,
          decoration: InputDecoration(
            hintText: 'Enter username',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // User ID field
        Text(
          'User ID',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: viewModel.userIdController,
          decoration: InputDecoration(
            hintText: 'Leave blank to auto-generate',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
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

        // Company dropdown
        Text(
          'Company',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: viewModel.selectedCompanyId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            labelText: 'Company',
            hintText: 'Select Company',
          ),
          items: _buildCompanyDropdownItems(viewModel.companies, viewModel.isCurrentUserSuperAdmin),
          onChanged: (value) {
            viewModel.selectedCompanyId = value;
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
        const SizedBox(height: 16),

        // Password fields (only for new users)
        if (viewModel.editingUser == null) ...[
          Text(
            'Password',
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: viewModel.passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF6B35)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Confirm Password',
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: viewModel.confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF6B35)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

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
                    final success = await viewModel.saveUser();
                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            viewModel.editingUser == null ? 'User added successfully!' : 'User updated successfully!',
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
                          viewModel.editingUser == null ? "Add User" : "Update User",
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

  // Helper method to build company dropdown items with GLOBAL_ADMIN option for Super Admins
  List<DropdownMenuItem<String>> _buildCompanyDropdownItems(List<Map<String, dynamic>> companies, bool isCurrentUserSuperAdmin) {
    final List<DropdownMenuItem<String>> items = [];
    
    // Add GLOBAL_ADMIN option for Super Admins
    if (isCurrentUserSuperAdmin) {
      items.add(DropdownMenuItem<String>(
        value: 'GLOBAL_ADMIN',
        child: Text('Global Admin (No Company)'),
      ));
    }
    
    // Add actual companies
    for (final company in companies) {
      items.add(DropdownMenuItem<String>(
        value: company['id'],
        child: Text(company['name']!),
      ));
    }
    
    return items;
  }

  void _editUser(UserViewModel viewModel, UserModel user) {
    viewModel.editUser(user);
    _showAddUserDialog(context, viewModel);
  }

  void _toggleUserStatus(UserViewModel viewModel, UserModel user) {
    // Toggle based on isActive field, not status string
    viewModel.toggleUserActiveStatus(user.id, !user.isActive);
  }

  void _deleteUser(UserViewModel viewModel, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User?"),
        content: Text("Are you sure you want to delete ${user.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              final success = await viewModel.deleteUser(user.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'User deleted successfully!',
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

  // Step 4: Manage Roles Dialog
  void _showManageRolesDialog(BuildContext context, UserModel user) {
    _viewModel.setEditingUser(user);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<UserViewModel>.value(
        value: _viewModel,
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.5,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
            ),
            child: _buildManageRolesDialogContent(dialogContext),
          ),
        ),
      ),
    );
  }

  Widget _buildManageRolesDialogContent(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? selectedRole;
            
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Color(0xFF4A90E2)),
                      const SizedBox(width: 12),
                      Text(
                        'Manage User Roles',
                        style: AppFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Role Selection
                  Text(
                    'Select Role:',
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'company admin', child: Text('Company Admin')),
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'super admin', child: Text('Super Admin')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          viewModel.clearEditingUser();
                        },
                        child: Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: viewModel.saving || selectedRole == null ? null : () async {
                          await viewModel.assignRole(selectedRole!);
                          if (viewModel.error.isEmpty) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Role assigned successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(viewModel.error),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: viewModel.saving 
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Assign Role'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Step 5: Delete Confirmation
  void _showDeleteConfirmation(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Archive User?"),
        content: Text("Are you sure you want to archive ${user.name}? This will remove them from the active list."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await _viewModel.archiveUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'User archived successfully!',
                      style: AppFonts.poppins(),
                    ),
                    backgroundColor: Colors.orange.shade600,
                  ),
                );
              }
            },
            child: const Text("Archive", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

}
