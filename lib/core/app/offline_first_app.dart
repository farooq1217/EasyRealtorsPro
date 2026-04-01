import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_first_auth_service.dart';
import '../services/network_sync_manager.dart';
import '../../pages/offline_first_login_page.dart';
import '../../widgets/sync_status_indicator.dart';
import '../../data/repositories/offline_first_repository_simple.dart';

/// Offline-First App Integration
/// 
/// This class integrates the offline-first architecture with the main app.
/// It handles initialization, authentication flow, and provides
/// the necessary widgets for the offline-first experience.
class OfflineFirstApp extends StatefulWidget {
  final Widget Function(BuildContext, Map<String, dynamic>?) authenticatedBuilder;

  const OfflineFirstApp({
    Key? key,
    required this.authenticatedBuilder,
  }) : super(key: key);

  @override
  State<OfflineFirstApp> createState() => _OfflineFirstAppState();
}

class _OfflineFirstAppState extends State<OfflineFirstApp> {
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
    NetworkSyncManager.instance.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('OfflineFirstApp: Initializing offline-first app...');

      // Initialize the offline-first auth service
      await OfflineFirstAuthService.initialize();

      // Initialize the network sync manager
      await NetworkSyncManager.instance.initialize();

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

      debugPrint('OfflineFirstApp: Initialization complete');

    } catch (e) {
      debugPrint('OfflineFirstApp: Initialization error: $e');
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
            // Compact sync status indicator in app bar
            StreamBuilder<SyncStatus>(
              stream: NetworkSyncManager.instance.syncStatusStream,
              initialData: NetworkSyncManager.instance.getCurrentStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data!;
                return CompactSyncStatusIndicator(
                  status: status,
                  onTap: () => _showSyncDetails(context),
                );
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        actions: [
          // Sync status button
          StreamBuilder<SyncStatus>(
            stream: NetworkSyncManager.instance.syncStatusStream,
            initialData: NetworkSyncManager.instance.getCurrentStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data!;
              return SyncStatusButton(
                status: status,
                onForceSync: () => _forceSync(),
              );
            },
          ),
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
              PopupMenuItem(
                value: 'sync_info',
                child: Row(
                  children: [
                    const Icon(Icons.sync_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Sync Information',
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
        onPressed: _showQuickSyncInfo,
        backgroundColor: const Color(0xFFFF6B35),
        child: const Icon(Icons.sync),
        tooltip: 'Sync Status',
      ),
    );
  }

  void _handleUserMenuAction(String action) async {
    switch (action) {
      case 'profile':
        _showProfileDialog();
        break;
      case 'sync_info':
        _showSyncDetails(context);
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
        title: Text(
          'User Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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

  void _showSyncDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sync),
            const SizedBox(width: 8),
            Text(
              'Sync Status',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: StreamBuilder<SyncStatus>(
            stream: NetworkSyncManager.instance.syncStatusStream,
            initialData: NetworkSyncManager.instance.getCurrentStatus(),
            builder: (context, snapshot) {
              final currentStatus = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow('Status', currentStatus.isSyncing ? 'Syncing' : currentStatus.isSynced ? 'Synced' : 'Pending'),
                  if (currentStatus.operation != null)
                    _buildStatusRow('Operation', currentStatus.operation!),
                  if (currentStatus.lastSyncTime != null)
                    _buildStatusRow('Last Sync', _formatDateTime(currentStatus.lastSyncTime!)),
                  if (currentStatus.pendingOperations != null && currentStatus.pendingOperations! > 0)
                    _buildStatusRow('Pending Operations', currentStatus.pendingOperations.toString()),
                ],
              );
            },
          ),
        ),
        actions: [
          StreamBuilder<SyncStatus>(
            stream: NetworkSyncManager.instance.syncStatusStream,
            initialData: NetworkSyncManager.instance.getCurrentStatus(),
            builder: (context, snapshot) {
              final buttonStatus = snapshot.data!;
              if (!buttonStatus.isSyncing)
                return TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _forceSync();
                  },
                  child: Text(
                    'Force Sync',
                    style: GoogleFonts.poppins(color: const Color(0xFFFF6B35)),
                  ),
                );
              else
                return const SizedBox.shrink();
            },
          ),
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

  void _showQuickSyncInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Quick Sync Info',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: StreamBuilder<SyncStats>(
          stream: NetworkSyncManager.instance.syncStatsStream,
          initialData: NetworkSyncManager.instance.getSyncStats(),
          builder: (context, snapshot) {
            final stats = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow('Last Sync', stats.lastSyncTime != null 
                  ? _formatDateTime(stats.lastSyncTime!) 
                  : 'Never'),
                _buildStatsRow('Pending Operations', stats.pendingOperations.toString()),
                _buildStatsRow('Total Syncs', stats.totalSyncs.toString()),
                _buildStatsRow('Current Status', stats.isSyncing ? 'Syncing' : 'Idle'),
              ],
            );
          },
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

  Widget _buildStatsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Future<void> _forceSync() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Starting sync...',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFF6B35),
        ),
      );

      await NetworkSyncManager.instance.forceSyncAll();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync completed',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync failed: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await OfflineFirstAuthService.signOut();
      // The auth state stream will handle navigation back to login
    } catch (e) {
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

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

/// Extension to add sync stats stream to NetworkSyncManager
extension NetworkSyncManagerExtension on NetworkSyncManager {
  Stream<SyncStats> get syncStatsStream {
    // This would ideally be a real stream, but for now we'll use a timer-based approach
    return Stream.periodic(const Duration(seconds: 5), (_) => getSyncStats());
  }
}
