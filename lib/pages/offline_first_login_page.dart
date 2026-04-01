import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared/shared.dart';
import '../../core/services/offline_first_auth_service.dart';
import '../core/services/network_sync_manager.dart';
import '../widgets/sync_status_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

/// Offline-First Login Page
/// 
/// This login page implements the offline-first authentication flow:
/// 1. First-time login requires internet and Firebase Auth
/// 2. Subsequent logins work completely offline
/// 3. Shows sync status and connectivity information
/// 4. Handles password changes with background sync
class OfflineFirstLoginPage extends StatefulWidget {
  const OfflineFirstLoginPage({Key? key}) : super(key: key);

  @override
  State<OfflineFirstLoginPage> createState() => _OfflineFirstLoginPageState();
}

class _OfflineFirstLoginPageState extends State<OfflineFirstLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  AuthState _authState = AuthState.uninitialized;
  bool _isOnline = false;
  String? _errorMessage;
  List<String> _infoMessages = [];

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    try {
      // Initialize offline-first auth service
      await OfflineFirstAuthService.initialize();
      
      // Initialize network sync manager
      await NetworkSyncManager.instance.initialize();
      
      // Listen to auth state changes
      OfflineFirstAuthService.authStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _authState = state;
            if (state == AuthState.authenticated) {
              _navigateToDashboard();
            }
          });
        }
      });

      // Check connectivity
      await _checkConnectivity();

      // Check if this is first-time login
      final hasStoredAuth = await _hasStoredAuthentication();
      if (!hasStoredAuth) {
        setState(() {
          _infoMessages.add('First-time login requires internet connection');
        });
      } else {
        setState(() {
          _infoMessages.add('Offline login available');
        });
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      // For now, assume online status since connectivity_plus was removed
      final isOnline = true; // TODO: Replace with HTTP ping check
      
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          if (!isOnline) {
            _infoMessages.add('No internet connection - offline mode');
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
    }
  }

  Future<bool> _hasStoredAuthentication() async {
    try {
      final authState = await OfflineFirstAuthService.getStoredAuthentication();
      return authState != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessages.clear();
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      AuthResult result;

      // Try local authentication first
      if (await _hasStoredAuthentication()) {
        setState(() {
          _infoMessages.add('Attempting offline authentication...');
        });

        result = await OfflineFirstAuthService.authenticateLocally(
          email: email,
          password: password,
        );

        if (result.success) {
          setState(() {
            _infoMessages.add('Offline authentication successful');
          });
          _navigateToDashboard();
          return;
        } else {
          setState(() {
            _infoMessages.add('Offline authentication failed, trying online...');
          });
        }
      }

      // If offline auth failed or not available, try Firebase
      if (!_isOnline) {
        setState(() {
          _errorMessage = 'Internet connection required for first-time login';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _infoMessages.add('Connecting to Firebase...');
      });

      result = await OfflineFirstAuthService.signInWithFirebase(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      if (result.success) {
        setState(() {
          _infoMessages.add('Firebase authentication successful');
        });
        _navigateToDashboard();
      } else {
        setState(() {
          _errorMessage = result.error;
        });
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToDashboard() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Title
                    _buildHeader(),
                    
                    const SizedBox(height: 32),
                    
                    // Sync Status Indicator
                    _buildSyncStatus(),
                    
                    const SizedBox(height: 24),
                    
                    // Connection Status
                    _buildConnectionStatus(),
                    
                    const SizedBox(height: 24),
                    
                    // Info Messages
                    if (_infoMessages.isNotEmpty) ..._buildInfoMessages(),
                    
                    // Error Message
                    if (_errorMessage != null) ..._buildErrorMessage(),
                    
                    const SizedBox(height: 24),
                    
                    // Email Field
                    _buildEmailField(),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    _buildPasswordField(),
                    
                    const SizedBox(height: 16),
                    
                    // Remember Me Checkbox
                    _buildRememberMeCheckbox(),
                    
                    const SizedBox(height: 24),
                    
                    // Sign In Button
                    _buildSignInButton(),
                    
                    const SizedBox(height: 16),
                    
                    // Forgot Password Link
                    _buildForgotPasswordLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.real_estate_agent,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'EasyRealtorsPro',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Offline-First Real Estate Management',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF718096),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSyncStatus() {
    return StreamBuilder<SyncStatus>(
      stream: NetworkSyncManager.instance.syncStatusStream,
      initialData: NetworkSyncManager.instance.getCurrentStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data!;
        return SyncStatusIndicator(status: status);
      },
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isOnline ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: _isOnline ? Colors.green.shade600 : Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _isOnline ? Colors.green.shade600 : Colors.orange.shade600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInfoMessages() {
    return _infoMessages.map((message) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    )).toList();
  }

  List<Widget> _buildErrorMessage() {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Email Address',
        labelStyle: const TextStyle(color: Color(0xFF718096)),
        hintText: 'Enter your email',
        hintStyle: const TextStyle(color: Color(0xFFA0AEC0)),
        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF718096)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53E3E)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      style: GoogleFonts.poppins(color: const Color(0xFF2D3748)),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email address';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _signIn(),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: Color(0xFF718096)),
        hintText: 'Enter your password',
        hintStyle: const TextStyle(color: Color(0xFFA0AEC0)),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF718096)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF718096),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53E3E)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      style: GoogleFonts.poppins(color: const Color(0xFF2D3748)),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your password';
        }
        if (value.trim().length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? true;
            });
          },
          activeColor: const Color(0xFFFF6B35),
        ),
        Text(
          'Remember me for offline access',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF4A5568),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Signing In...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                'Sign In',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return Center(
      child: TextButton(
        onPressed: _showForgotPasswordDialog,
        child: Text(
          'Forgot Password?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFFFF6B35),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Password reset requires internet connection. Please connect to the internet and try again.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: const Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }
}
