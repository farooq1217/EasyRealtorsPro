import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_first_auth_service.dart';
import '../../pages/offline_first_login_page.dart';

/// Working Offline-First App
/// 
/// This version bypasses complex sync management issues
/// and focuses on core offline functionality
class OfflineFirstAppWorking extends StatefulWidget {
  final Widget Function(BuildContext, Map<String, dynamic>?) authenticatedBuilder;

  const OfflineFirstAppWorking({
    Key? key,
    required this.authenticatedBuilder,
  }) : super(key: key);

  @override
  State<OfflineFirstAppWorking> createState() => _OfflineFirstAppWorkingState();
}

class _OfflineFirstAppWorkingState extends State<OfflineFirstAppWorking> {
  AuthState _authState = AuthState.uninitialized;
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('OfflineFirstAppWorking: Initializing offline-first app...');

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

      debugPrint('OfflineFirstAppWorking: Initialization complete');

    } catch (e) {
      debugPrint('OfflineFirstAppWorking: Initialization error: $e');
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
              'Working Offline-First Mode',
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
