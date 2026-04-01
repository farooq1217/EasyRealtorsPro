import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_first_auth_service.dart';
import '../../pages/offline_first_login_page.dart';
import '../../data/repositories/offline_first_repository_simple.dart';
import 'package:shared/shared.dart';

/// Simple Offline-First App Integration
/// 
/// This is a simplified version that focuses on core offline functionality
/// without complex sync management for now.
class OfflineFirstAppSimple extends StatefulWidget {
  final Widget Function(BuildContext, Map<String, dynamic>?) authenticatedBuilder;

  const OfflineFirstAppSimple({
    Key? key,
    required this.authenticatedBuilder,
  }) : super(key: key);

  @override
  State<OfflineFirstAppSimple> createState() => _OfflineFirstAppSimpleState();
}

class _OfflineFirstAppSimpleState extends State<OfflineFirstAppSimple> {
  AuthState _authState = AuthState.uninitialized;
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    // Clean up services
    OfflineFirstAuthService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('OfflineFirstAppSimple: Initializing offline-first app...');

      // Initialize the offline-first auth service
      await OfflineFirstAuthService.initialize();

      // Listen to authentication state changes
      OfflineFirstAuthService.authStateStream.listen((authState) {
        if (mounted) {
          setState(() {
            _authState = authState;
          });
        }
      });

      // Listen to user data changes
      OfflineFirstAuthService.userStream.listen((user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      });

      // Set initialization complete
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      debugPrint('OfflineFirstAppSimple: Initialization complete');

    } catch (e) {
      debugPrint('OfflineFirstAppSimple: Initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen during initialization
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    // Show login page if not authenticated
    if (_authState == AuthState.unauthenticated) {
      return const OfflineFirstLoginPage();
    }

    // Show authenticated content
    if (_authState == AuthState.authenticated && _currentUser != null) {
      return _buildAuthenticatedApp();
    }

    // Default to loading screen for other states
    return _buildLoadingScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 24),
            Text(
              'EasyRealtorsPro',
              style: GoogleFonts.poppins(
                fontSize: 24,
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
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedApp() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'EasyRealtorsPro',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            // Simple status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_done,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Offline Mode',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        actions: [
          // User menu
          PopupMenuButton<String>(
            onSelected: _handleUserMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Text(
                      _currentUser?['name'] ?? 'User',
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'sign_out',
                child: Row(
                  children: [
                    const Icon(Icons.logout),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: widget.authenticatedBuilder(context, _currentUser),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOfflineInfo,
        backgroundColor: const Color(0xFFFF6B35),
        child: const Icon(Icons.info),
        tooltip: 'Offline Mode Info',
      ),
    );
  }

  void _handleUserMenuAction(String action) async {
    switch (action) {
      case 'profile':
        _showProfileDialog();
        break;
      case 'sign_out':
        await _signOut();
        break;
    }
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 8),
            Text(
              'User Profile',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Name', _currentUser?['name'] ?? 'N/A'),
            _buildProfileRow('Email', _currentUser?['email'] ?? 'N/A'),
            _buildProfileRow('Company', _currentUser?['company_name'] ?? 'N/A'),
            _buildProfileRow('Role', _currentUser?['role'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud_off),
            const SizedBox(width: 8),
            Text(
              'Offline Mode',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EasyRealtorsPro is running in Offline-First mode.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              '• All data is stored locally on your device',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 4),
            Text(
              '• App works instantly without internet connection',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 4),
            Text(
              '• Changes sync automatically when internet is available',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 4),
            Text(
              '• Your data is always accessible and secure',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await OfflineFirstAuthService.signOut();
      // The auth state stream will handle navigation back to login
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign out failed: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
