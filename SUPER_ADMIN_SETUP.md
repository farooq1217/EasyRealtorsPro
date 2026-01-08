# Super Admin Setup Guide

## Overview

Super Admin is the highest-level role in the system with full system-wide access. Super Admin accounts:
- Have access to all companies and data
- Can create, edit, activate, and deactivate companies
- Can create, manage, and deactivate Company Admin accounts
- Have no restrictions on any operations
- Can log in on multiple devices simultaneously (no session limits)
- **Cannot be created by Company Admins** - only manually by system administrators

## Creating a Super Admin Account

### Method 1: Using the Command-Line Script (Recommended)

1. Navigate to the desktop_admin package directory:
   ```bash
   cd packages/desktop_admin
   ```

2. Run the creation script:
   ```bash
   dart run bin/create_super_admin.dart <email> <password> [name] [contactNo]
   ```

   **Example:**
   ```bash
   dart run bin/create_super_admin.dart admin@example.com SecurePassword123! "Super Admin" "+1234567890"
   ```

   **Parameters:**
   - `email` (required): Email address for the Super Admin
   - `password` (required): Password for the Super Admin
   - `name` (optional): Display name (defaults to "Super Admin")
   - `contactNo` (optional): Contact number

3. The script will output:
   - Success message with User ID
   - Confirmation that the account was created
   - Instructions to log in

### Method 2: Using the Dart Code Directly

You can also create a Super Admin programmatically:

```dart
import 'package:desktop_admin/create_super_admin.dart';

void main() async {
  final result = await SuperAdminCreator.createSuperAdmin(
    email: 'admin@example.com',
    password: 'SecurePassword123!',
    name: 'Super Admin',
    contactNo: '+1234567890',
  );
  
  if (result['success'] == true) {
    print('Super Admin created: ${result['email']}');
  } else {
    print('Error: ${result['message']}');
  }
}
```

## Super Admin Capabilities

Once logged in as Super Admin, you have:

### Company Management
- ✅ Create new companies
- ✅ Edit company details
- ✅ Activate/deactivate companies
- ✅ View all companies

### User Management
- ✅ Create Company Admin accounts
- ✅ Create Agent accounts
- ✅ Manage all users across all companies
- ✅ Assign permissions
- ✅ Activate/deactivate users

### Data Access
- ✅ View all data across all companies
- ✅ Create, update, and delete any data
- ✅ No company-level restrictions
- ✅ Override all role-based restrictions

### System Administration
- ✅ Configure system-wide settings
- ✅ Control application-level Light/Dark mode
- ✅ Manage dashboards
- ✅ View audit logs
- ✅ System maintenance tools

### Session Management
- ✅ Log in on multiple devices simultaneously
- ✅ No session limitations
- ✅ Unlimited concurrent sessions

## Security Notes

1. **Super Admin accounts are powerful** - Use them only for system administration
2. **Keep credentials secure** - Super Admin passwords should be strong and stored securely
3. **Limit Super Admin accounts** - Only create as many as necessary
4. **Regular audits** - Review Super Admin access regularly
5. **Cannot be created by Company Admins** - This prevents unauthorized elevation of privileges

## Verifying Super Admin Status

To verify if a user is a Super Admin:

```dart
import 'package:desktop_admin/create_super_admin.dart';

final isSuperAdmin = await SuperAdminCreator.verifySuperAdmin('admin@example.com');
print('Is Super Admin: $isSuperAdmin');
```

Or using RoleUtils:

```dart
import 'package:shared/shared.dart';

final user = await getUserData(); // Get user data from your source
final isSuperAdmin = RoleUtils.isSuperAdmin(user);
```

## Role Hierarchy

```
Super Admin (System Level)
    ↓
Company Admin (Company Level)
    ↓
Agent (Company Level)
```

- **Super Admin**: System-wide access, no company restrictions
- **Company Admin**: Full access within their company
- **Agent**: Limited access within their company

## Troubleshooting

### "User with this email already exists"
- The email is already registered
- Use a different email or check if the user already exists

### "Error creating Super Admin"
- Check file permissions
- Ensure the application support directory is accessible
- Check console for detailed error messages

### Cannot log in after creation
- Verify the email and password are correct
- Check that the user file was created successfully
- Ensure the permissions JSON is valid

## Next Steps

After creating a Super Admin account:

1. Log in with the Super Admin credentials
2. Create companies as needed
3. Create Company Admin accounts for each company
4. Company Admins can then create Agent accounts

---

**Important**: Super Admin accounts should be created only by authorized system administrators. Never share Super Admin credentials with regular users.

