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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10), // Further reduced from 12 to 10
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Make card wrap content tightly
            children: [
            // Header: Avatar, Name/ID, Action Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Align to top
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 18, // Further reduced from 20
                  backgroundColor: user.isActive ? Colors.green : Colors.grey,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Reduced from 16
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Reduced from 12
                
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
                          fontSize: 12, // Further reduced from 13
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${user.userId.isNotEmpty ? user.userId : 'No ID'}',
                        style: AppFonts.poppins(
                          fontSize: 10, // Further reduced from 11
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons - Compact layout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        onEditUser?.call(user);
                      },
                      icon: const Icon(Icons.edit, size: 14), // Reduced from 16
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(4), // Reduced padding
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        onUpdatePassword?.call(user);
                      },
                      icon: const Icon(Icons.lock, size: 14), // Reduced from 16
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(4), // Reduced padding
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        onDeleteUser?.call(user);
                      },
                      icon: const Icon(Icons.delete, size: 14), // Reduced from 16
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(4), // Reduced padding
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 10), // Increased from 6 to give more space
            
            // Content Sections - Compact layout with flexible spacing
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Contact Information
                Flexible(
                  child: _buildContactInfo(),
                ),
                const SizedBox(height: 2), // Further reduced from 4
                
                // Roles Section with settings button
                Flexible(
                  child: _buildRolesSection(),
                ),
                const SizedBox(height: 2), // Further reduced from 4
                
                // Company Section
                Flexible(
                  child: _buildCompanySection(),
                ),
              ],
            ),
          ],
          ),
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
        const SizedBox(height: 2), // Further reduced from 4
        // Contact Number
        _buildInfoRow(Icons.phone, 'Contact', user.contactNo?.isNotEmpty == true ? user.contactNo! : 'Not provided'),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600), // Reduced from 16
        const SizedBox(width: 6), // Reduced from 8
        Expanded(
          child: Text(
            value,
            style: AppFonts.poppins(
              fontSize: 10, // Further reduced from 11
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
                  fontSize: 11, // Reduced from 12
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3), // Reduced from 4
              Chip(
                label: Text(
                  role.isNotEmpty ? role.toUpperCase() : 'NO ROLE', // CRITICAL: Dynamic uppercase role text
                  style: AppFonts.poppins(
                    fontSize: 10, // Reduced from 11
                    color: Colors.white,
                  ),
                ),
                backgroundColor: role.isNotEmpty ? _getRoleDisplayColor(role) : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Reduced padding
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            onManageRoles?.call(user);
          },
          icon: const Icon(Icons.settings, size: 14), // Reduced from 16
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(4), // Reduced padding
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
            fontSize: 11, // Reduced from 12
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3), // Reduced from 4
        Chip(
          label: Text(
            company,
            style: AppFonts.poppins(
              fontSize: 10, // Reduced from 11
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: user.companyId?.isNotEmpty == true ? const Color(0xFFFF6B35) : Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Reduced padding
        ),
      ],
    );
  }

  String _getRoleDisplay(UserModel user) {
    // CRITICAL FIX: Use the new JSON role format instead of boolean flags
    final role = user.role; // This uses the UserModel.role getter which parses JSON correctly
    debugPrint('UserCard: User ${user.name} - Raw permissions: ${user.permissions}');
    debugPrint('UserCard: User ${user.name} - Parsed role: $role');
    
    switch (role.toLowerCase()) {
      case 'super_admin':
        return 'Super Admin';
      case 'company_admin':
        return 'Company Admin';
      case 'agent':
        return 'Agent';
      case 'user':
      default:
        return 'User';
    }
  }

  Color _getRoleDisplayColor(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin': // Updated to match JSON format
        return Colors.purple;
      case 'company_admin': // Updated to match JSON format
        return Colors.blue;
      case 'agent':
        return Colors.green;
      case 'user':
      default:
        return Colors.grey;
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
