# Create Super Admin Account - Quick Start

## Your Super Admin Credentials

- **Email**: `mayof286@gmail.com`
- **Password**: `Bhalo&1217`
- **Name**: Super Admin

## How to Create the Account

### Step 1: Navigate to the desktop_admin directory

```bash
cd packages/desktop_admin
```

### Step 2: Run the setup script

```bash
dart run bin/setup_super_admin.dart
```

### Step 3: Verify the output

You should see:
```
============================================================
Creating Super Admin Account
============================================================

Email: mayof286@gmail.com
Name: Super Admin

✓ SUCCESS: Super Admin account created successfully!

Account Details:
  User ID: [generated ID]
  Email: mayof286@gmail.com
  Name: Super Admin

============================================================
You can now log in with:
  Email: mayof286@gmail.com
  Password: Bhalo&1217
============================================================
```

## After Creation

1. **Log in** to the application using:
   - Email: `mayof286@gmail.com`
   - Password: `Bhalo&1217`

2. **Verify Super Admin access** - You should have:
   - Full access to all modules
   - Ability to create companies
   - Ability to create Company Admin accounts
   - No restrictions on any operations

## If Account Already Exists

If you see "User with this email already exists", the account is already created. You can:
- Log in directly with the credentials above
- Or verify the account exists by checking the users.json file

## Troubleshooting

### Error: "Package not found"
Make sure you're in the `packages/desktop_admin` directory and run:
```bash
flutter pub get
```

### Error: "File not found"
Ensure the script exists at `packages/desktop_admin/bin/setup_super_admin.dart`

### Error: "Permission denied"
On Windows, you may need to run as administrator or check file permissions.

---

**Note**: This Super Admin account has full system access. Keep the credentials secure!

