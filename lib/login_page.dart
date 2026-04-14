import 'package:flutter/material.dart';
import '../core/font_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'core/services/auth_service.dart';
import 'core/services/permission_sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_sync_service.dart';
// import 'force_password_change_page.dart'; // REMOVED - Force password change logic disabled

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
            // Show 2FA setup dialog after first login
            setState(() {
              _show2FASetup = true;
            });
            _show2FASetupDialog();
            return;
          }

          // CRITICAL FIX: Wait for permissions to be fully loaded before navigation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login successful, loading permissions...'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
            );
            
            // CRITICAL: Force refresh permissions and wait for them to be fully loaded
            setState(() { _isLoading = true; });
            
            try {
              final token = result['token'] as String?;
              if (token != null) {
                debugPrint('LoginPage: Refreshing user permissions...');
                
                // Force permission refresh
                await PermissionSyncService.refreshUserPermissions(token);
                
                // Wait for permissions to be fully loaded with timeout
                final userWithPermissions = await PermissionSyncService.waitForPermissionsToLoad(
                  token,
                  timeout: const Duration(seconds: 2), // OPTIMIZATION: Reduced timeout
                );
                
                if (userWithPermissions != null) {
                  debugPrint('LoginPage: Permissions loaded successfully, navigating to dashboard...');
                  
                  if (mounted) {
                    final navArgs = result['requiresProfileCompletion'] == true
                        ? {
                            'initialNavIndex': 5,
                            'initialNotice': (result['profileRedirectMessage'] as String?) ??
                                'Please complete your profile to continue',
                          }
                        : null;
                    
                    // THREAD SAFETY: Wrap navigation in proper UI thread callbacks
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/home', arguments: navArgs);
                      
                      // TRIGGER BACKGROUND SYNC AFTER NAVIGATION - Thread Safe
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Future.delayed(const Duration(seconds: 3), () async {
                          debugPrint('LoginPage: Triggering background sync after navigation...');
                          await AuthService.triggerBackgroundSyncAfterLogin();
                        });
                      });
                    });
                  }
                } else {
                  debugPrint('LoginPage: Timeout loading permissions, proceeding with navigation anyway...');
                  if (mounted) {
                    // Navigate anyway after timeout
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
              debugPrint('LoginPage: Error loading permissions: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading permissions: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
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
        if (kDebugMode) {
          print('Login error: $e');
        }
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
              // Continue to home
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Skip for now'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Generate 2FA secret
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
                  // Validate email
                  final emailError = _validateEmail(emailCtl.text.trim());
                  if (emailError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(emailError)),
                    );
                    return;
                  }
                  
                  // Validate other fields
                  if (fullNameCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Full name is required')),
                    );
                    return;
                  }
                  
                  // Validate password
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
                    // Auto-fill email in login form
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
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _resetEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_resetCodeController.text.isEmpty)
                    ElevatedButton(
                      onPressed: () async {
                        final result = await AuthService.requestPasswordReset(
                          _resetEmailController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Reset code sent'),
                              backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                            ),
                          );
                          if (result['success'] == true && result['code'] != null) {
                            // Show code for testing (remove in production)
                            setDialogState(() {
                              _resetCodeController.text = result['code'] as String;
                            });
                          }
                        }
                      },
                      child: const Text('Send Reset Code'),
                    )
                  else ...[
                    TextField(
                      controller: _resetCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Reset Code',
                        hintText: 'Enter 6-digit code',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetEmailController.clear();
                  _resetCodeController.clear();
                  _newPasswordController.clear();
                },
                child: const Text('Cancel'),
              ),
              if (_resetCodeController.text.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    final result = await AuthService.resetPassword(
                      _resetEmailController.text.trim(),
                      _resetCodeController.text.trim(),
                      _newPasswordController.text.trim(),
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Password reset'),
                          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                        ),
                      );
                      if (result['success'] == true) {
                        _resetEmailController.clear();
                        _resetCodeController.clear();
                        _newPasswordController.clear();
                      }
                    }
                  },
                  child: const Text('Reset Password'),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35), // Orange
              const Color(0xFF4A90E2), // Blue
            ],
          ),
          border: Border.all(
            color: Colors.grey.shade300.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: SafeArea(
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Welcome section with logo
        Expanded(
          flex: 1,
          child: _buildWelcomeSection(),
        ),
        // Right side - Login form
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildLoginForm(),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 32),
          _buildLoginForm(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo space
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

  Widget _buildLoginForm() {
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
                      color: const Color(0xFFFF6B35), // Orange
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
                  // Use Wrap or Column for smaller screens to prevent overflow
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 350) {
                        // Stack vertically on very small screens
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
                                  activeColor: const Color(0xFFFF6B35),
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
                                    color: const Color(0xFFFF6B35),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Use Row for larger screens
                        return Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFFFF6B35),
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
                                    color: const Color(0xFFFF6B35),
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
                        backgroundColor: const Color(0xFFFF6B35), // Orange
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
