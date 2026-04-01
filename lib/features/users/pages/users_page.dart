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
import '../../companies/view_models/company_view_model.dart';
import '../../companies/repositories/company_repository_impl.dart';
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
  late UserViewModel _userViewModel;
  late CompanyViewModel _companyViewModel;
  
  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  
  // Filter state
  String? _selectedCompanyId;
  String? _selectedRole;
  String? _selectedStatus;
  
  // Role options (hardcoded as required)
  List<Map<String, dynamic>> _roles = [
    {'id': null, 'name': 'All roles'},
    {'id': 'super_admin', 'name': 'Super Admin'},
    {'id': 'company_admin', 'name': 'Company Admin'},
    {'id': 'agent', 'name': 'Agent'},
  ];

  // Get filtered role options based on current user's role
  List<Map<String, dynamic>> get _filteredRoles {
    if (_userViewModel.isCurrentUserSuperAdmin) {
      // Super Admin can see all roles
      return _roles;
    } else {
      // Company Admin can only assign Agent role
      return [
        {'id': null, 'name': 'All roles'},
        {'id': 'agent', 'name': 'Agent'},
      ];
    }
  }
  
  // Status options (hardcoded as required)
  List<Map<String, dynamic>> _statuses = [
    {'id': null, 'name': 'All statuses'},
    {'id': 'active', 'name': 'Active'},
    {'id': 'inactive', 'name': 'Inactive'},
  ];

  @override
  void initState() {
    super.initState();
    _userViewModel = UserViewModel(UserRepositoryImpl(widget.db));
    _companyViewModel = CompanyViewModel(CompanyRepositoryImpl(widget.db));
    
    debugPrint('UsersPage: initState called, widget mounted: $mounted');
    
    // Initialize ViewModels but defer stream setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('UsersPage: PostFrameCallback - widget mounted: $mounted');
      _userViewModel.initialize();
      _companyViewModel.initialize();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('UsersPage: didChangeDependencies called, widget mounted: $mounted');
    // Set mounted state when dependencies change
    _userViewModel.setMounted(mounted);
  }

  @override
  void dispose() {
    _userViewModel.dispose();
    _companyViewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: _userViewModel,
      child: Consumer<UserViewModel>(
        builder: (context, userViewModel, child) {
          // Show loading state but keep buttons visible
          if (userViewModel.loading) {
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

          return ChangeNotifierProvider<CompanyViewModel>.value(
            value: _companyViewModel,
            child: Consumer<CompanyViewModel>(
              builder: (context, companyViewModel, child) {
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
                                child: _buildHeaderSection(userViewModel),
                              ),
                              const SizedBox(height: 24),
                              
                              // Search and Filter Section
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildSearchAndFilterSection(userViewModel, companyViewModel),
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
        },
      ),
    );
  }

  Widget _buildHeaderSection(UserViewModel userViewModel) {
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
        onPressed: () => _showAddUserDialog(context, userViewModel),
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

  Widget _buildSearchAndFilterSection(UserViewModel userViewModel, CompanyViewModel companyViewModel) {
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
                hintText: 'Search users by name, email, or username...',
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
                userViewModel.setSearchQuery(value);
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
                      Expanded(child: _buildCompanyDropdown(userViewModel, companyViewModel)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRoleDropdown(userViewModel)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatusDropdown(userViewModel)),
                      const SizedBox(width: 12),
                      _buildFilterActions(userViewModel),
                    ],
                  );
                } else {
                  // Mobile layout: Column
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildCompanyDropdown(userViewModel, companyViewModel)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRoleDropdown(userViewModel)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildStatusDropdown(userViewModel)),
                          const SizedBox(width: 12),
                          _buildFilterActions(userViewModel),
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

  Widget _buildCompanyDropdown(UserViewModel userViewModel, CompanyViewModel companyViewModel) {
    // Build companies list with "All" option
    List<Map<String, dynamic>> companies = [
      {'id': null, 'name': 'All companies'},
      ...companyViewModel.companies.map((company) => {
        'id': company.id,
        'name': company.name,
      }).toList(),
    ];
    
    return DropdownButtonFormField<String>(
      value: _selectedCompanyId,
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
      items: companies.map((company) => DropdownMenuItem<String>(
        value: company['id'] as String?,
        child: Text(company['name']),
      )).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCompanyId = value;
        });
        // Apply filters using ViewModel's new filtering system
        userViewModel.applyFilters(value, _selectedRole, _selectedStatus);
      },
    );
  }

  Widget _buildRoleDropdown(UserViewModel userViewModel) {
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
      items: _filteredRoles.map((role) => DropdownMenuItem<String>(
        value: role['id'] as String?,
        child: Text(role['name']),
      )).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
        });
        // Apply filters using ViewModel's new filtering system
        userViewModel.applyFilters(_selectedCompanyId, value, _selectedStatus);
      },
    );
  }

  Widget _buildStatusDropdown(UserViewModel userViewModel) {
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
      items: _statuses.map((status) => DropdownMenuItem<String>(
        value: status['id'] as String?,
        child: Text(status['name']),
      )).toList(),
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
        });
        // Apply filters using ViewModel's new filtering system
        userViewModel.applyFilters(_selectedCompanyId, _selectedRole, value);
      },
    );
  }

  Widget _buildFilterActions(UserViewModel userViewModel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clear Filters Button
        IconButton(
          onPressed: () {
            setState(() {
              _selectedCompanyId = null;
              _selectedRole = null;
              _selectedStatus = null;
            });
            userViewModel.clearAllFilters();
          },
          icon: const Icon(Icons.clear_all, color: Color(0xFF4A90E2)),
          tooltip: 'Clear All Filters',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            padding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(width: 8),
        // Refresh Button
        IconButton(
          onPressed: () => userViewModel.refreshData(),
          icon: const Icon(Icons.refresh, color: Color(0xFF4A90E2)),
          tooltip: 'Refresh Users',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            padding: const EdgeInsets.all(8),
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

        // Use viewModel.filteredUsers for data check
        if (viewModel.filteredUsers.isEmpty) {
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
                // Responsive aspect ratio based on screen width and column count
                childAspectRatio: _getResponsiveAspectRatio(constraints.maxWidth, crossAxisCount),
              ),
              itemCount: viewModel.filteredUsers.length,
              itemBuilder: (context, index) {
                final user = viewModel.filteredUsers[index];
                return UserCard(
                  user: user,
                  onEditUser: (user) => _showEditUserDialog(context, user, viewModel),
                  onUpdatePassword: (user) => _showUpdatePasswordDialog(context, user, viewModel),
                  onManageRoles: (user) => _showManageRolesDialog(context, user, viewModel),
                  onDeleteUser: (user) => _showDeleteConfirmation(context, user, viewModel),
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


  // Calculate responsive aspect ratio to prevent overflow
  double _getResponsiveAspectRatio(double screenWidth, int crossAxisCount) {
    // Base aspect ratios for different column counts - give much more vertical space
    switch (crossAxisCount) {
      case 1: // Mobile
        return 2.5; // Much taller cards for single column
      case 2: // Tablet
        return 2.2; // Much taller for two columns
      case 3: // Desktop
        return 2.0; // Much taller for three columns
      default:
        return 2.3; // Default fallback
    }
  }

  void _showAddUserDialog(BuildContext context, UserViewModel viewModel) {
    // CRITICAL: Auto-generate User ID when opening the dialog
    _generateUserIdForNewUser(viewModel);
    
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

  // Helper method to generate User ID for new users
  void _generateUserIdForNewUser(UserViewModel viewModel) {
    // Generate a unique User ID based on current timestamp and random suffix
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final randomSuffix = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    final generatedUserId = 'USR$timestamp$randomSuffix';
    
    // Set the generated User ID in the controller
    viewModel.userIdController.text = generatedUserId;
  }

  Widget _buildAddUserDialogContent(BuildContext context, UserViewModel viewModel) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildUserForm(context, viewModel),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, UserModel user, UserViewModel userViewModel) {
    userViewModel.setEditingUser(user);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<UserViewModel>.value(
        value: userViewModel,
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
  void _showUpdatePasswordDialog(BuildContext context, UserModel user, UserViewModel userViewModel) {
    userViewModel.setEditingUser(user);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<UserViewModel>.value(
        value: userViewModel,
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
        // Form Title
        Center(
          child: Text(
            'Add New User',
            style: AppFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
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

        // Role dropdown
        Text(
          'Role',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: viewModel.selectedRole,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            labelText: 'Role',
            hintText: 'Select Role',
          ),
          items: _filteredRoles.map((role) => DropdownMenuItem<String>(
            value: role['id'] as String?,
            child: Text(role['name']),
          )).toList(),
          onChanged: (value) {
            viewModel.selectedRole = value;
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

        // Password field (only for new users)
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
  void _showManageRolesDialog(BuildContext context, UserModel user, UserViewModel userViewModel) {
    userViewModel.setEditingUser(user);
    
    // 1. Declare state variables OUTSIDE builder but INSIDE method
    String? localSelectedRole = user.role;
    Map<String, bool> localModuleAccess = {
      'agent_working': false, 
      'inventory': false, 
      'rental_items': false, 
      'trading': false, 
      'expenditure': false, 
      'reports': false
    };
    
    // Pre-fill localModuleAccess from existing user.permissions['permissionsMap'] if it exists
    if (user.permissionsMap != null) {
      final permissionsMap = user.permissionsMap!;
      localModuleAccess = localModuleAccess.map((key, value) {
        return MapEntry(key, permissionsMap.containsKey(key));
      });
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ChangeNotifierProvider<UserViewModel>.value(
          value: userViewModel,
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(dialogContext).size.width * 0.6,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.maxFinite,
                  child: StatefulBuilder(
                    // 2. Use StatefulBuilder and specifically name its setter 'setStateDialog'
                    builder: (BuildContext context, StateSetter setStateDialog) {
                      return Column(
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
                          
                          // Current user info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User: ${user.name ?? 'Unknown'}',
                                  style: AppFonts.poppins(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Email: ${user.email ?? 'Unknown'}',
                                  style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Text(
                                  'Current Role: ${user.role ?? 'Unknown'}',
                                  style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Role Selection
                          Text(
                            'Select New Role:',
                            style: AppFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // DROPDOWN
                          DropdownButtonFormField<String>(
                            value: localSelectedRole,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: _filteredRoles.map((role) => DropdownMenuItem<String>(
                              value: role['id'] as String?,
                              child: Text(role['name']),
                            )).toList(),
                            onChanged: (newValue) {
                              // CRITICAL: Use setStateDialog here!
                              setStateDialog(() { 
                                localSelectedRole = newValue; 
                              });
                            },
                            // ✨ FIX: Validate value against available roles to prevent crashes ✨
                            validator: (value) {
                              final validRoles = ['super_admin', 'company_admin', 'agent'];
                              if (value == null || !validRoles.contains(value)) {
                                return 'Please select a valid role';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Module Access Section
                          Text(
                            'Module Access:',
                            style: AppFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // CHECKBOXES
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: localModuleAccess.keys.map((key) {
                                  return CheckboxListTile(
                                    title: Text(
                                      _getModuleDisplayName(key),
                                      style: AppFonts.poppins(fontSize: 14),
                                    ),
                                    value: localModuleAccess[key],
                                    onChanged: (bool? checked) {
                                      // CRITICAL: Use setStateDialog here!
                                      setStateDialog(() {
                                        localModuleAccess[key] = checked ?? false;
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  userViewModel.clearEditingUser();
                                },
                                child: Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: userViewModel.saving || localSelectedRole == null ? null : () async {
                                  // CRITICAL: Add debug logging
                                  debugPrint('Sending Role: $localSelectedRole to ViewModel');
                                  debugPrint('Sending Modules: $localModuleAccess to ViewModel');
                                  
                                  // Pass LOCAL variables to viewmodel
                                  await userViewModel.assignRole(localSelectedRole!, localModuleAccess);
                                  if (userViewModel.error.isEmpty) {
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Role and permissions assigned successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(userViewModel.error),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: userViewModel.saving 
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
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to get display name for module keys
  String _getModuleDisplayName(String moduleKey) {
    switch (moduleKey) {
      case 'agent_working':
        return 'Agent Working';
      case 'inventory':
        return 'Inventory';
      case 'rental_items':
        return 'Rental Items';
      case 'trading':
        return 'Trading';
      case 'expenditure':
        return 'Expenditure';
      case 'reports':
        return 'Reports';
      default:
        return moduleKey;
    }
  }

  // Step 5: Delete Confirmation
  void _showDeleteConfirmation(BuildContext context, UserModel user, UserViewModel userViewModel) {
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
              await userViewModel.archiveUser(user.id);
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
