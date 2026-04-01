import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_first_auth_service.dart';
import '../../pages/offline_first_login_page.dart';

/// Basic Offline-First App
/// 
/// This version focuses only on core offline functionality
/// without any complex sync management or Firebase dependencies
class OfflineFirstAppBasic extends StatefulWidget {
  final Widget Function(BuildContext, Map<String, dynamic>?) authenticatedBuilder;

  const OfflineFirstAppBasic({
    Key? key,
    required this.authenticatedBuilder,
  }) : super(key: key);

  @override
  State<OfflineFirstAppBasic> createState() => _OfflineFirstAppBasicState();
}

class _OfflineFirstAppBasicState extends State<OfflineFirstAppBasic> {
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
      debugPrint('OfflineFirstAppBasic: Initializing offline-first app...');

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

      debugPrint('OfflineFirstAppBasic: Initialization complete');

    } catch (e) {
      debugPrint('OfflineFirstAppBasic: Initialization error: $e');
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
      return widget.authenticatedBuilder(context, _currentUser);
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
}
