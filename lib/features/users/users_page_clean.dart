import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
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
import '../users/user_view_model.dart';
import '../users/models/user_model.dart';
import 'repositories/user_repository_impl.dart';

class UsersPage extends StatefulWidget {
  final AppDatabase db;
  const UsersPage({super.key, required this.db});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late UserViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = UserViewModel(UserRepositoryImpl(widget.db));
    
    // Initialize ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: _viewModel,
      child: Consumer<UserViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('Users Management', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              actions: [
                // Backfill User IDs button
                if (RoleUtils.isSuperAdmin(viewModel.currentUser) || PermissionHelper.isBypassUser(viewModel.currentUser))
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'backfill_ids') {
                        viewModel.backfillUserIds();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'backfill_ids',
                        child: Row(
                          children: [
                            Icon(Icons.format_list_numbered),
                            SizedBox(width: 8),
                            Text('Backfill User IDs'),
                          ],
                        ),
                      ),
                    ],
                  ),
                // Add button
                if (viewModel.canAdd)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddUserDialog(context, viewModel),
                    tooltip: 'Add User',
                  ),
                // Global Search
                TopRightSearch(
                  onChanged: (query) => viewModel.setSearchQuery(query),
                  hintText: 'Search users...',
                ),
              ],
            ),
            body: Column(
              children: [
                // Statistics Cards
                _buildStatisticsCards(context, viewModel),
                
                // Backfill progress
                if (viewModel.backfillingUserIds)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Backfilling user IDs... Please wait.',
                            style: AppFonts.poppins(color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // User List
                Expanded(
                  child: viewModel.filteredUsers.isEmpty
                      ? _buildEmptyState(context, viewModel)
                      : _buildUserList(context, viewModel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, UserViewModel viewModel) {
    return FutureBuilder<Map<String, dynamic>>(
      future: viewModel.getUserStatistics(),
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
                  'Total Users',
                  stats['total_users'].toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Active',
                  stats['active_users'].toString(),
                  Icons.person,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Inactive',
                  stats['inactive_users'].toString(),
                  Icons.person_off,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Archived',
                  stats['archived_users'].toString(),
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

  Widget _buildEmptyState(BuildContext context, UserViewModel viewModel) {
    return Center(
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
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (viewModel.canAdd)
            Text(
              "Tap the + button to add your first user",
              style: AppFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList(BuildContext context, UserViewModel viewModel) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: viewModel.filteredUsers.length,
      itemBuilder: (context, index) {
        final user = viewModel.filteredUsers[index];
        return _buildUserCard(context, user, viewModel);
      },
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel user, UserViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.green : Colors.grey,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
            style: AppFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              user.email,
              style: AppFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    user.userId,
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            if (user.contactNo != null)
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
                      user.contactNo!,
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
                color: _getStatusColor(user.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.status ?? 'active',
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
                    viewModel.editUser(user);
                    _showAddUserDialog(context, viewModel);
                  } else if (value == 'toggle_status') {
                    final newStatus = user.status == 'active' ? 'inactive' : 'active';
                    viewModel.toggleUserStatus(user.id, newStatus);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(context, user, viewModel);
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
                          Icon(user.status == 'active' ? Icons.person_off : Icons.person),
                          const SizedBox(width: 8),
                          Text(user.status == 'active' ? 'Deactivate' : 'Activate'),
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
                      viewModel.editingUser == null ? 'Add User' : 'Edit User',
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
                  child: _buildUserForm(dialogContext, viewModel),
                ),
              ),
            ],
          ),
        ),
      ),
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
          ),
          items: viewModel.companies.map((company) {
            return DropdownMenuItem<String>(
              value: company['id'],
              child: Text(company['name']!),
            );
          }).toList(),
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

  void _showDeleteConfirmation(BuildContext context, UserModel user, UserViewModel viewModel) {
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
}
