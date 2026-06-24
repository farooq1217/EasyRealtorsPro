import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import '../core/font_utils.dart';
import '../core/utils/logger.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import 'package:easyrealtorspro/core/services/app_storage.dart';
import '../core/services/permission_sync_service.dart';
import '../core/services/permission_debug_helper.dart';
import '../core/role_utils.dart' as local;
import '../core/services/firebase_threading_handler.dart';
import '../core/windows_platform_fix.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_sync_service.dart';
import 'package:provider/provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/theme/app_themes.dart';
import 'core/services/auth/password_hashing_service.dart';

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'This field is required';
  return null;
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _requires2FA = false;
  bool _show2FASetup = false;
  final TextEditingController _twoFactorCodeController = TextEditingController();
  final TextEditingController _resetEmailController = TextEditingController();
  final TextEditingController _resetCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  void _showResetPasswordDialog() {
    final emailController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final db = await AppDatabase.instance();
                final salt = DateTime.now().millisecondsSinceEpoch.toString();
                final newHash = '10000:$salt:${_simpleHash(newPasswordController.text + salt)}';
                
                await db.customStatement(
                  'UPDATE users SET password_hash = ?, salt = ?, is_first_login = 0 WHERE email = ?',
                  [newHash, salt, emailController.text.trim()],
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset successful!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = (hash * 31 + input.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _twoFactorCodeController.dispose();
    _resetEmailController.dispose();
    _resetCodeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.contains('.')) return 'Please enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final isWindows = !kIsWeb && io.Platform.isWindows;
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await AuthService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          rememberMe: _rememberMe,
          twoFactorCode: _requires2FA ? _twoFactorCodeController.text.trim() : null,
        );

        setState(() { _isLoading = false; });

        if (result['success'] == true) {
          if ((result['synced'] == true || result['security_updated'] == true) && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account Synced Successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
            );
          }
          if (result['requires2FASetup'] == true) {
            setState(() {
              _show2FASetup = true;
            });
            _show2FASetupDialog();
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login successful, loading permissions...'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
            );
            
            setState(() { _isLoading = true; });
            
            try {
              final token = result['token'] as String?;
              final sessionId = result['sessionId'] as String?;
              if (token != null) {
                final storage = AppStorage();
                final settings = await storage.readSettings();
                settings['authToken'] = token;
                if (sessionId != null) {
                  settings['currentSessionId'] = sessionId;
                }
                await storage.writeSettings(settings);
                debugPrint('LoginPage: Saved token and sessionId to AppStorage settings');

                debugPrint('LoginPage: Starting HYBRID permission loading...');
                setState(() { _isLoading = true; });
                
                final userWithPermissions = await PermissionSyncService.loadPermissionsSmart(token);
                
                if (userWithPermissions != null && PermissionSyncService.arePermissionsFullyLoaded(userWithPermissions)) {
                  debugPrint('LoginPage: ✅ HYBRID permission loading successful!');
                  debugPrint('LoginPage: Available modules: ${userWithPermissions['permissionsMap']?.keys?.toList() ?? []}');
                  
                  if (mounted) {
                    final navArgs = result['requiresProfileCompletion'] == true
                        ? {
                            'initialNavIndex': 5,
                            'initialNotice': (result['profileRedirectMessage'] as String?) ??
                                'Please complete your profile to continue',
                          }
                        : null;
                    
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/home', arguments: navArgs);
                      
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Future.delayed(const Duration(seconds: 8), () async {
                          if (isWindows) {
                            debugPrint('LoginPage: Skipping post-login background sync on Windows platform');
                            return;
                          }
                          debugPrint('LoginPage: Triggering background sync for HYBRID mode...');
                          await AuthService.triggerBackgroundSyncAfterLogin();
                        });
                      });
                    });
                  }
                } else {
                  debugPrint('LoginPage: ❌ HYBRID permission loading failed');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Unable to load permissions. Please check your internet connection and try again.'), 
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 10),
                        action: SnackBarAction(
                          label: 'RETRY',
                          textColor: Colors.white,
                          onPressed: () async {
                            debugPrint('LoginPage: User requested retry...');
                            setState(() { _isLoading = true; });
                            
                            final retryUser = await PermissionSyncService.loadPermissionsSmart(token);
                            if (retryUser != null && PermissionSyncService.arePermissionsFullyLoaded(retryUser)) {
                              setState(() { _isLoading = false; });
                              Navigator.of(context).pushReplacementNamed('/home', arguments: result['requiresProfileCompletion'] == true ? {
                                'initialNavIndex': 5,
                                'initialNotice': (result['profileRedirectMessage'] as String?) ?? 'Please complete your profile to continue',
                              } : null);
                            } else {
                              setState(() { _isLoading = false; });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Retry failed. Please contact support if the issue persists.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                    
                    final navArgs = result['requiresProfileCompletion'] == true
                        ? {
                            'initialNavIndex': 5,
                            'initialNotice': (result['profileRedirectMessage'] as String?) ??
                                'Please complete your profile to continue',
                          }
                        : null;
                    
                    Navigator.of(context).pushReplacementNamed('/home', arguments: navArgs);
                  }
                }
              }
            } catch (e) {
              debugPrint('LoginPage: Error in HYBRID permission loading: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('System error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.of(context).pushReplacementNamed('/home');
              }
            } finally {
              if (mounted) {
                setState(() { _isLoading = false; });
              }
            }
          }
        } else if (result['requires2FA'] == true) {
          setState(() {
            _requires2FA = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter your 2FA code'), backgroundColor: Colors.orange),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Login failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        Logger.error('Login error', tag: 'Login', error: e);
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An error occurred: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _show2FASetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Two-Factor Authentication'),
        content: const Text(
          'For enhanced security, we recommend enabling two-factor authentication. '
          'This will require a verification code each time you log in.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _show2FASetup = false;
              });
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Skip for now'),
          ),
          ElevatedButton(
            onPressed: () async {
              final secret = AuthService.generate2FASecret();
              final result = await AuthService.setup2FA(_emailController.text.trim(), secret);
              
              if (result['success'] == true) {
                Navigator.pop(context);
                setState(() {
                  _show2FASetup = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('2FA enabled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pushReplacementNamed('/home');
                }
              }
            },
            child: const Text('Enable 2FA'),
          ),
        ],
      ),
    );
  }

  void _showCreateAccountDialog() {
    final emailCtl = TextEditingController();
    final passwordCtl = TextEditingController();
    final confirmPasswordCtl = TextEditingController();
    final fullNameCtl = TextEditingController();
    final cnicCtl = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fullNameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cnicCtl,
                    decoration: const InputDecoration(
                      labelText: 'CNIC',
                      hintText: '12345-1234567-1',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 15,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final emailError = _validateEmail(emailCtl.text.trim());
                  if (emailError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(emailError)),
                    );
                    return;
                  }
                  
                  if (fullNameCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Full name is required')),
                    );
                    return;
                  }
                  
                  final passwordError = _validatePassword(passwordCtl.text);
                  if (passwordError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(passwordError)),
                    );
                    return;
                  }
                  
                  if (passwordCtl.text != confirmPasswordCtl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')),
                    );
                    return;
                  }
                  
                  setDialogState(() => isLoading = true);
                  
                  final result = await AuthService.register(
                    email: emailCtl.text.trim(),
                    password: passwordCtl.text,
                    fullName: fullNameCtl.text.trim(),
                    cnic: cnicCtl.text.trim().isEmpty ? '00000-0000000-0' : cnicCtl.text.trim(),
                  );
                  
                  setDialogState(() => isLoading = false);
                  
                  if (!mounted) return;
                  
                  if (result['success'] == true) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account created successfully! You can now login.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _emailController.text = emailCtl.text.trim();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Registration failed'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

 
 void _showForgotPasswordDialog() {
  final emailController = TextEditingController();
  bool isLoading = false;
  bool emailSent = false;
  
  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: const Color(0xFFFF6B35)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Reset Password'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!emailSent) ...[
                const Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your registered email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Password reset email sent successfully! Please check your inbox and follow the instructions.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Note: If you don\'t see the email, please check your spam folder.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (!emailSent)
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      
                      // Validation
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your email'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      if (!email.contains('@') || !email.contains('.')) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid email'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      setDialogState(() => isLoading = true);
                      
                      try {
                        final result = await AuthService.sendPasswordResetEmail(email);
                        
                        setDialogState(() => isLoading = false);
                        
                        if (result['success'] == true) {
                          setDialogState(() => emailSent = true);
                          
                          // Auto-fill email in login form
                          if (mounted) {
                            _emailController.text = email;
                          }
                        } else {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Failed to send email'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(isLoading ? 'Sending...' : 'Send Reset Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    ),
  );
}

  void _showSetupAdminDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: const Color(0xFFFF6B35)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Create Admin Account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No users found in local database. Please create your first admin account to get started.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter password (min 6 characters)',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your full name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final emailError = _validateEmail(emailController.text.trim());
                      if (emailError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(emailError), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final passwordError = _validatePassword(passwordController.text);
                      if (passwordError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(passwordError), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      if (passwordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        final result = await AuthService.createLocalAdmin(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          name: nameController.text.trim(),
                        );

                        setDialogState(() => isLoading = false);

                        if (!mounted) return;

                        if (result['success'] == true) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(result['message'] ?? 'Admin account created successfully!')),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          _emailController.text = emailController.text.trim();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Failed to create admin account'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Admin'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 900;

    // ✅ NEW: Wrap with Consumer<ThemeProvider>
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final primaryColor = themeProvider.currentThemeData.primaryColor;
        
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withOpacity(0.7),
                ],
              ),
              border: Border.all(
                color: Colors.grey.shade300.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Main content
                  isMobile ? _buildMobileLayout(themeProvider) : _buildDesktopLayout(themeProvider),
                  
                  // ✅ NEW: Theme Selector Button (Top Right)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: _buildThemeSelector(context, themeProvider),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ NEW: Theme Selector Widget
  Widget _buildThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.palette, color: Colors.white, size: 24),
        tooltip: 'Change Theme',
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        offset: const Offset(0, 40),
        onSelected: (value) {
          final themeType = ThemeType.values.firstWhere(
            (e) => e.name == value,
          );
          themeProvider.setTheme(themeType);
        },
        itemBuilder: (context) {
          return ThemeList.getThemes().map((theme) {
            final isSelected = theme.type == themeProvider.currentTheme;
            return PopupMenuItem<String>(
              value: theme.type.name,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black26 : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Icon(theme.icon, color: theme.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    theme.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildWelcomeSection(themeProvider),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildLoginForm(themeProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60), // Space for theme selector
          _buildWelcomeSection(themeProvider),
          const SizedBox(height: 32),
          _buildLoginForm(themeProvider),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome!',
              style: AppFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Real Estate Management System',
              style: AppFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.95),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Manage your properties, files, and rental items efficiently. Track sales, monitor inventory, and streamline your real estate business operations.',
              style: AppFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '© 2026 Real Estate Management',
              style: AppFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeProvider themeProvider) {
    final primaryColor = themeProvider.currentThemeData.primaryColor;
    
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          elevation: 12,
          shadowColor: Colors.black.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Login',
                    style: AppFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor, // ✅ Changed to theme color
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading && _formKey.currentState?.validate() == true) {
                        _login();
                      }
                    },
                    validator: _requiredValidator,
                  ),
                  if (_requires2FA) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _twoFactorCodeController,
                      decoration: InputDecoration(
                        labelText: 'Two-Factor Authentication Code',
                        hintText: 'Enter 6-digit code',
                        prefixIcon: const Icon(Icons.security),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    ),
                  ],
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 350) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  activeColor: primaryColor, // ✅ Changed to theme color
                                ),
                                Flexible(
                                  child: Text(
                                    'Remember Me (7 days)',
                                    style: AppFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  'Forgot Password?',
                                  style: AppFonts.poppins(
                                    color: primaryColor, // ✅ Changed to theme color
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: primaryColor, // ✅ Changed to theme color
                            ),
                            Flexible(
                              child: Text(
                                'Remember Me (7 days)',
                                style: AppFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  'Forgot Password?',
                                  style: AppFonts.poppins(
                                    color: primaryColor, // ✅ Changed to theme color
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, // ✅ Changed to theme color
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Authenticating...',
                                  style: AppFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'LOGIN',
                              style: AppFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _showSetupAdminDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'First Time? Create Admin Account',
                            style: AppFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}