import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../widgets/custom_sidebar.dart';
import '../../../widgets/platform_aware_image.dart';
import '../../../widgets/adaptive_dialog.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/role_utils.dart';
import '../../../core/services/permission_sync_service.dart';
import '../../../core/app.dart' show AdminApp;
import '../dashboard/dashboard_page.dart';
import '../inventory/pages/inventory_page.dart';
import '../agent_working/pages/agent_working_page.dart';
import '../agents/view_models/agent_view_model.dart';
import '../agents/repositories/agent_repository_impl.dart';
import '../rental/pages/rental_page.dart' show RentalItemsPage;
import '../todo/pages/todo_page.dart' show ToDoPage;
import '../settings/pages/settings_page.dart' show SettingsPageClean;
import '../trading/pages/trading_page.dart';
import '../trading/view_models/trading_view_model.dart';
import '../trading/repositories/trading_repository_impl.dart';
import '../expenditure/view_models/expenditure_view_model.dart';
import '../expenditure/repositories/expenditure_repository_impl.dart';
import '../inventory/view_models/inventory_view_model.dart';
import '../inventory/repositories/inventory_repository_impl.dart';
import '../settings/repositories/settings_repository_impl.dart';
import '../rental/view_models/rental_view_model.dart';
import '../rental/repositories/rental_repository_impl.dart';
import '../users/view_models/user_view_model.dart';
import '../users/repositories/user_repository_impl.dart';
import '../todo/view_models/todo_view_model.dart';
import '../todo/repositories/todo_repository_impl.dart';
import '../../../core/services/notification_service.dart';
import '../expenditure/pages/expenditure_page.dart';
import '../users/pages/users_page.dart';
import '../companies/pages/companies_page.dart';
import '../reports/pages/reports_page.dart';
import 'package:shared/shared.dart' show AppDatabase;

/// Main navigation page with sidebar and content area
class MainNavigationPage extends StatefulWidget {
  final AppDatabase db;
  final int initialIndex;

  const MainNavigationPage({
    super.key,
    required this.db,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;
  Map<String, dynamic>? _currentUser;
  ThemeMode _themeMode = ThemeMode.system;
  int? _badgeFiles;
  int? _badgeRentals;
  StreamSubscription<Map<String, dynamic>?>? _userStreamSubscription;
  Timer? _periodicPermissionCheckTimer;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserData();
    _loadTheme();
    _loadBadges();
    
    // CRITICAL: Listen to user stream for reactive sidebar updates
    _userStreamSubscription = AuthService.currentUserStream.listen((user) {
      if (mounted) {
        // Only log and update when a valid user is detected (prevent redundant null logs)
        if (user != null && user['email'] != null) {
          debugPrint('MainNavigationPage: User stream update received - ${user['email']}');
          setState(() {
            _currentUser = user;
          });
          
          // CRITICAL: Force permission refresh when user changes to ensure sidebar modules show up
          _forcePermissionRefreshIfNeeded(user);
        } else if (user == null && _currentUser != null) {
          // Log when user is explicitly logged out (but not on initial null)
          debugPrint('MainNavigationPage: User logged out, clearing current user');
          setState(() {
            _currentUser = user;
          });
        }
      }
    });
    
    // CRITICAL: Add periodic check as fallback to ensure permissions are loaded
    _startPeriodicPermissionCheck();
  }

  Future<void> _loadUserData() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final token = settings['authToken'] as String?;
    if (token != null) {
      final user = await AuthService.getCurrentUser(token);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  Future<void> _loadTheme() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final mode = (settings['theme'] as String?) ?? 'system';
    if (mounted) {
      setState(() {
        _themeMode = _themeFrom(mode);
      });
    }
  }

  @override
  void dispose() {
    // CRITICAL: Clean up stream subscription and timer to prevent memory leaks
    _userStreamSubscription?.cancel();
    _periodicPermissionCheckTimer?.cancel();
    super.dispose();
  }

  /// Start periodic permission check as fallback
  void _startPeriodicPermissionCheck() {
    // Check permissions every 2 seconds for the first 10 seconds after login
    int checkCount = 0;
    const maxChecks = 5; // 5 checks over 10 seconds
    
    _periodicPermissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      checkCount++;
      
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_currentUser != null && !PermissionSyncService.arePermissionsFullyLoaded(_currentUser)) {
        debugPrint('MainNavigationPage: Periodic check #$checkCount - Permissions not loaded, forcing refresh...');
        await _forcePermissionRefreshIfNeeded(_currentUser!);
      }
      
      // Stop after max checks or when permissions are loaded
      if (checkCount >= maxChecks || PermissionSyncService.arePermissionsFullyLoaded(_currentUser)) {
        timer.cancel();
        debugPrint('MainNavigationPage: Periodic permission checks completed');
      }
    });
  }

  /// Force permission refresh if permissions are not loaded
  Future<void> _forcePermissionRefreshIfNeeded(Map<String, dynamic> user) async {
    // Check if permissions are loaded
    if (!PermissionSyncService.arePermissionsFullyLoaded(user)) {
      debugPrint('MainNavigationPage: Permissions not loaded, forcing refresh...');
      
      try {
        final storage = AppStorage();
        final settings = await storage.readSettings();
        final token = settings['authToken'] as String?;
        
        if (token != null) {
          // Force refresh permissions
          await PermissionSyncService.refreshUserPermissions(token);
          
          // Update current user with fresh permissions
          final refreshedUser = await AuthService.getCurrentUser(token);
          if (refreshedUser != null && mounted) {
            setState(() {
              _currentUser = refreshedUser;
            });
            debugPrint('MainNavigationPage: Permissions refreshed and UI updated');
          }
        }
      } catch (e) {
        debugPrint('MainNavigationPage: Error refreshing permissions: $e');
      }
    }
  }

  Future<void> _loadBadges() async {
    // Load badge counts for inventory and rentals
    try {
      final filesCount = await widget.db.customSelect(
        'SELECT COUNT(*) as count FROM files_table WHERE is_active = 1',
      ).getSingle();
      
      final rentalsCount = await widget.db.customSelect(
        'SELECT COUNT(*) as count FROM rental_items WHERE is_active = 1 AND status = "rented"',
      ).getSingle();
      
      if (mounted) {
        setState(() {
          _badgeFiles = filesCount.data['count'] as int?;
          _badgeRentals = rentalsCount.data['count'] as int?;
        });
      }
    } catch (e) {
      // Silent fail for badge loading
    }
  }

  ThemeMode _themeFrom(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onTradingTap() {
    // Navigate to trading module
    setState(() {
      _selectedIndex = 6; // Trading index
    });
  }

  void _onLogout() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final sessionId = settings['currentSessionId'] as String?;
    
    // CRITICAL: Use PermissionSyncService for comprehensive logout
    await PermissionSyncService.performLogout(sessionId);
    
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  void _onToggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _onThemeChanged(String mode) {
    setState(() {
      _themeMode = _themeFrom(mode);
    });
    AdminApp.applyThemeSetting(mode);
  }

  
  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(db: widget.db);
      case 1:
        return InventoryPage(db: widget.db);
      case 2:
        return AgentWorkingPage(db: widget.db);
      case 3:
        return RentalItemsPage(db: widget.db);
      case 4:
        return ToDoPage(db: widget.db);
      case 5:
        // PRE-FETCH CHECK: Get user context for SettingsPageClean
        final user = AuthService.currentUser;
        final companyId = RoleUtils.getUserCompanyId(user);
        final isSuperAdmin = RoleUtils.isSuperAdmin(user);
        debugPrint('MainNavigationPage: PRE-FETCH CHECK - Passing user context to Settings - CompanyId: $companyId, IsSuperAdmin: $isSuperAdmin');
        return SettingsPageClean(db: widget.db); // Note: SettingsPageClean handles its own user context loading
      case 6:
        return TradingPage(db: widget.db);
      case 7:
        return TradingPage(db: widget.db); // Trading Form
      case 8:
        return ReportsPage(db: widget.db);
      case 9:
        return UsersPage(db: widget.db);
      case 10:
        // Get user context for ExpenditurePage
        final user = AuthService.currentUser;
        final companyId = RoleUtils.getUserCompanyId(user);
        final isSuperAdmin = RoleUtils.isSuperAdmin(user);
        final userId = user?['id']?.toString() ?? user?['userId']?.toString();
        return ExpenditurePage(
          db: widget.db,
          companyId: companyId,
          isSuperAdmin: isSuperAdmin,
          userId: userId,
        );
      case 11:
        return CompaniesPage(db: widget.db);
      default:
        return DashboardPage(db: widget.db);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TradingViewModel>(
          create: (context) => TradingViewModel.getInstance(TradingRepositoryImpl(
            widget.db,
            companyId: RoleUtils.getUserCompanyId(AuthService.currentUser),
            isSuperAdmin: RoleUtils.isSuperAdmin(AuthService.currentUser),
          )),
          lazy: false, // Ensure ViewModel is created immediately and stays alive
        ),
        ChangeNotifierProvider<ExpenditureViewModel>(
          create: (context) {
            // Get current user for Agent filtering
            final user = AuthService.currentUser;
            final userId = user?['id']?.toString() ?? user?['userId']?.toString();
            final companyId = RoleUtils.getUserCompanyId(user);
            final isSuperAdmin = RoleUtils.isSuperAdmin(user);
            
            debugPrint('MainNavigationPage: ExpenditureViewModel created with userId: $userId, companyId: $companyId, isSuperAdmin: $isSuperAdmin');
            
            return ExpenditureViewModel(
              widget.db,
              companyId: companyId,
              isSuperAdmin: isSuperAdmin,
              userId: userId, // Pass userId for Agent filtering
            );
          },
          lazy: false, // Ensure ViewModel is created immediately and stays alive
        ),
        ChangeNotifierProvider<InventoryViewModel>(
          create: (context) => InventoryViewModel(
            InventoryRepositoryImpl(widget.db, companyId: null, isSuperAdmin: false),
            SettingsRepositoryImpl(widget.db, companyId: null, isSuperAdmin: false),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<RentalViewModel>(
          create: (context) => RentalViewModel(
            repository: RentalRepositoryImpl(widget.db),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<UserViewModel>(
          create: (context) => UserViewModel(
            UserRepositoryImpl(widget.db),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<TodoViewModel>(
          create: (context) => TodoViewModel(
            repository: TodoRepositoryImpl(widget.db),
            notificationService: NotificationService(),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<AgentViewModel>(
          create: (context) => AgentViewModel(
            AgentRepositoryImpl(
              widget.db,
              companyId: null,
              isSuperAdmin: false,
            ),
          ),
          lazy: false,
        ),
        // Add other providers here as needed for different pages
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: _buildResponsiveLayout(),
      ),
    );
  }

  /// Build responsive layout with original sidebar
  Widget _buildResponsiveLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use original sidebar on desktop, drawer on mobile
        final isDesktop = constraints.maxWidth > 768;
        
        if (isDesktop) {
          // Original desktop layout with custom sidebar
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Original Sidebar
              ModernSidebar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                onTradingTap: _onTradingTap,
                onLogout: _onLogout,
                onToggle: _onToggleSidebar,
                isOpen: _isSidebarOpen,
                currentUser: _currentUser,
                badgeFiles: _badgeFiles,
                badgeRentals: _badgeRentals,
              ),
              
              // Separation Gap
              const SizedBox(width: 8),
              
              // Main Content Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFFFF6B35), // Orange on left
                            const Color(0xFF4A90E2), // Blue on right
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Spacer for centering
                          if (!_isSidebarOpen) const SizedBox(width: 16),
                          
                          // Branding - Centered (vertically centered)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Real Estate Management System',
                                    style: AppFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Dark Mode Toggle - Positioned in top-right corner
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Profile Picture
                              PlatformAwareImage(
                                imagePath: _currentUser?['profile_picture_path'],
                                width: 32,
                                height: 32,
                                builder: (context, imageWidget) {
                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF805AD5),
                                    backgroundImage: _currentUser?['profile_picture_path'] != null
                                        ? null
                                        : null,
                                    child: _currentUser?['profile_picture_path'] == null
                                        ? Text(
                                            (_currentUser?['name']?.isNotEmpty == true) 
                                                ? _currentUser!['name'].substring(0, 1).toUpperCase() 
                                                : 'U',
                                            style: AppFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          )
                                        : ClipOval(child: imageWidget),
                                  );
                                },
                                placeholder: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF805AD5),
                                  child: Text(
                                    (_currentUser?['name']?.isNotEmpty == true) 
                                        ? _currentUser!['name'].substring(0, 1).toUpperCase() 
                                        : 'U',
                                    style: AppFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF805AD5),
                                  child: Text(
                                    (_currentUser?['name']?.isNotEmpty == true) 
                                        ? _currentUser!['name'].substring(0, 1).toUpperCase() 
                                        : 'U',
                                    style: AppFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Notification Bell
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      // Handle notifications
                                    },
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(32, 32),
                                      padding: EdgeInsets.zero,
                                    ),
                                    tooltip: 'Notifications',
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Container(
                                margin: const EdgeInsets.only(top: 0, right: 0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 0.5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: IconButton(
                                      icon: Icon(
                                        _themeMode == ThemeMode.dark 
                                          ? Icons.light_mode 
                                          : Icons.dark_mode,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      onPressed: () async {
                                        final newMode = _themeMode == ThemeMode.dark ? 'light' : 'dark';
                                        final s = await AppStorage().readSettings();
                                        s['theme'] = newMode;
                                        await AppStorage().writeSettings(s);
                                        _onThemeChanged(newMode);
                                      },
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size(32, 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                      tooltip: _themeMode == ThemeMode.dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 12px vertical gap separator
                    const SizedBox(height: 12),
                    
                    // Page Content - Fixed layout constraints
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFF8F9FA),
                              const Color(0xFFF1F3F4),
                            ],
                          ),
                        ),
                        child: _buildCurrentPage(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Mobile layout with drawer
          return Scaffold(
            body: _buildMobileContent(),
            drawer: _buildMobileDrawer(),
            appBar: AppBar(
              title: Text(
                _getNavigationTitle(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          );
        }
      },
    );
  }

  /// Build mobile drawer with same styling as sidebar
  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C3E50),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A90E2).withOpacity(0.8),
                  Color(0xFF2C3E50).withOpacity(0.95),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: _currentUser?['profile_picture_path'] != null
                            ? null
                            : null,
                        child: _currentUser?['profile_picture_path'] == null
                            ? Text(
                                (_currentUser?['name']?.isNotEmpty == true)
                                    ? _currentUser!['name'].substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser?['name'] ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _currentUser?['email'] ?? 'user@example.com',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EasyRealtorsPro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation Items (simplified version of sidebar)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMobileDrawerItem('Dashboard', Icons.dashboard, 0),
                _buildMobileDrawerItem('Inventory', Icons.insert_drive_file, 1, badge: _badgeFiles),
                _buildMobileDrawerItem('Agent Working', Icons.support_agent, 2),
                _buildMobileDrawerItem('Rental Items', Icons.chair, 3, badge: _badgeRentals),
                _buildMobileDrawerItem('To-Do', Icons.checklist, 4),
                _buildMobileDrawerItem('Expenditure', Icons.payments, 10),
                if (_currentUser != null && _currentUser!['role'] == 'super_admin')
                  _buildMobileDrawerItem('User Management', Icons.people, 9),
                if (_currentUser != null && _currentUser!['role'] == 'super_admin')
                  _buildMobileDrawerItem('Company Management', Icons.business, 11),
                _buildMobileDrawerItem('Reports', Icons.bar_chart, 8),
                _buildMobileDrawerItem('Settings', Icons.settings, 5),
              ],
            ),
          ),
          
          // Logout
          Container(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _onLogout,
            ),
          ),
        ],
      ),
    );
  }

  /// Build mobile drawer item
  Widget _buildMobileDrawerItem(String title, IconData icon, int index, {int? badge}) {
    final isSelected = _selectedIndex == index;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFFFF6B35) : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFF6B35) : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: badge != null && badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      selected: isSelected,
      selectedTileColor: const Color(0xFFFF6B35).withOpacity(0.1),
      onTap: () {
        _onDestinationSelected(index);
        Navigator.of(context).pop(); // Close drawer
      },
    );
  }

  /// Build mobile content (same as desktop content)
  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Bar (hidden on mobile since we have AppBar)
        const SizedBox(height: 0),
        
        // Page Content
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF8F9FA),
                  const Color(0xFFF1F3F4),
                ],
              ),
            ),
            child: _buildCurrentPage(),
          ),
        ),
      ],
    );
  }

  /// Get navigation title for mobile app bar
  String _getNavigationTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Inventory';
      case 2: return 'Agent Working';
      case 3: return 'Rental Items';
      case 4: return 'To-Do';
      case 5: return 'Settings';
      case 8: return 'Reports';
      case 9: return 'User Management';
      case 10: return 'Expenditure';
      case 11: return 'Company Management';
      default: return 'EasyRealtorsPro';
    }
  }
}
