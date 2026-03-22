import 'package:flutter/material.dart';
import 'package:shared/shared.dart' show RoleUtils;
import '../../../core/font_utils.dart';
import '../models/user_model.dart';

class UserCard extends StatelessWidget {
  final UserModel user;
  final Function(UserModel)? onEditUser;
  final Function(UserModel)? onUpdatePassword;
  final Function(UserModel)? onManageRoles;
  final Function(UserModel)? onDeleteUser;

  const UserCard({
    super.key,
    required this.user,
    this.onEditUser,
    this.onUpdatePassword,
    this.onManageRoles,
    this.onDeleteUser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Make card compact
          children: [
            // Header: Avatar, Name/ID, Action Buttons
            Row(
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: user.isActive ? Colors.green : Colors.grey,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // User Name and ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Make compact
                    children: [
                      Text(
                        user.name.isNotEmpty ? user.name : 'Unknown User',
                        style: AppFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${user.userId.isNotEmpty ? user.userId : 'No ID'}',
                        style: AppFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Flexible(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                    IconButton(
                      onPressed: () {
                        onEditUser?.call(user);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        onUpdatePassword?.call(user);
                      },
                      icon: const Icon(Icons.lock, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        onDeleteUser?.call(user);
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                  ), // Close Flexible
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Contact Information
            Padding(
              padding: const EdgeInsets.all(12), // Reduced padding from 16 to 12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Make column compact
                children: [
                  // Contact Info Section
                  _buildContactInfo(),
                  const SizedBox(height: 8), // Reduced from 12 to 8
                  
                  // Roles Section
                  _buildRolesSection(),
                  const SizedBox(height: 8), // Reduced from 12 to 8
                  
                  // Company & Department Section
                  _buildCompanySection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min, // Make column compact
      children: [
        // Email
        _buildInfoRow(Icons.email, 'Email', user.email.isNotEmpty ? user.email : 'No Email'),
        const SizedBox(height: 8),
        // Contact Number
        _buildInfoRow(Icons.phone, 'Contact', user.contactNo?.isNotEmpty == true ? user.contactNo! : 'Not provided'),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRolesSection() {
    final role = _getRoleDisplay(user);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Make column compact
            children: [
              Text(
                'Roles',
                style: AppFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Chip(
                label: Text(
                  role.isNotEmpty ? role : 'No Role',
                  style: AppFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: role.isNotEmpty ? _getRoleDisplayColor(role) : Colors.grey,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            onManageRoles?.call(user);
          },
          icon: const Icon(Icons.settings, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySection() {
    final company = user.companyId?.isNotEmpty == true ? user.companyId! : 'Not Assigned';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Company & Department',
          style: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Chip(
          label: Text(
            company,
            style: AppFonts.poppins(
              fontSize: 11,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: user.companyId?.isNotEmpty == true ? const Color(0xFFFF6B35) : Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
      ],
    );
  }

  String _getRoleDisplay(UserModel user) {
    final permissions = user.permissionsMap;
    final userMap = user.toMap();
    
    if (RoleUtils.isSuperAdmin(userMap) || 
        (permissions['super_admin'] == true || permissions['super_admin'] == 'true')) {
      return 'Super Admin';
    }
    
    if (permissions['company_admin'] == true || permissions['company_admin'] == 'true') {
      return 'Company Admin';
    }
    
    if (permissions['agent'] == true || permissions['agent'] == 'true') {
      return 'Agent';
    }
    
    return 'User';
  }

  Color _getRoleDisplayColor(String role) {
    switch (role.toLowerCase()) {
      case 'super admin':
        return Colors.purple;
      case 'company admin':
        return Colors.blue;
      case 'agent':
        return Colors.green;
      case 'user':
      default:
        return Colors.orange;
    }
  }

  // Dialog methods - these will be passed from parent
  void _showEditUserDialog(BuildContext context, UserModel user) {
    // This will be handled by the parent widget
    // For now, we'll use a callback approach
    onEditUser?.call(user);
  }

  void _showUpdatePasswordDialog(BuildContext context, UserModel user) {
    // This will be handled by the parent widget
    onUpdatePassword?.call(user);
  }

  void _showManageRolesDialog(BuildContext context, UserModel user) {
    // This will be handled by the parent widget
    onManageRoles?.call(user);
  }

  void _showDeleteConfirmation(BuildContext context, UserModel user) {
    // This will be handled by the parent widget
    onDeleteUser?.call(user);
  }
}
