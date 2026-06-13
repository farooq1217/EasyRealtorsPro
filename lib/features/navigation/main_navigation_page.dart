import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../widgets/custom_sidebar.dart';
import '../../../widgets/platform_aware_image.dart';
import '../../../widgets/adaptive_dialog.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/app_storage.dart' show AppStorage;
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
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
import '../todo/pages/notifications_page.dart' show NotificationsPage;
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
import '../follow_up/pages/follow_up_page.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../follow_up/view_models/follow_up_view_model.dart';
import 'dart:convert'; 
import 'dart:io' if (dart.library.html) '../../../platform_stubs/io_stub.dart' as io;
import 'package:easyrealtorspro/core/services/foreground_sync_manager.dart';

/// Main navigation page with sidebar and content area
class MainNavigationPage extends StatelessWidget {
  final AppDatabase db;
  final int initialIndex;

  const MainNavigationPage({
    super.key,
    required this.db,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TradingViewModel>(
          create: (context) => TradingViewModel.getInstance(TradingRepositoryImpl(
            db,
            companyId: RoleUtils.getUserCompanyId(AuthService.currentUser),
            isSuperAdmin: RoleUtils.isSuperAdmin(AuthService.currentUser),
          )),
          lazy: false,
        ),
        ChangeNotifierProvider<ExpenditureViewModel>(
          create: (context) {
            final user = AuthService.currentUser;
            final userId = user?['id']?.toString() ?? user?['userId']?.toString();
            final companyId = RoleUtils.getUserCompanyId(user);
            final isSuperAdmin = RoleUtils.isSuperAdmin(user);
            
            debugPrint('MainNavigationPage: ExpenditureViewModel created with userId: $userId, companyId: $companyId, isSuperAdmin: $isSuperAdmin');
            
            return ExpenditureViewModel(
              db,
              companyId: companyId,
              isSuperAdmin: isSuperAdmin,
              userId: userId,
            );
          },
          lazy: false,
        ),
        ChangeNotifierProvider<InventoryViewModel>(
          create: (context) => InventoryViewModel(
            InventoryRepositoryImpl(db, companyId: null, isSuperAdmin: false),
            SettingsRepositoryImpl(db, companyId: null, isSuperAdmin: false),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<FollowUpViewModel>(
          create: (context) => FollowUpViewModel(),
          lazy: false,
        ),
        ChangeNotifierProvider<RentalViewModel>(
          create: (context) => RentalViewModel(
            repository: RentalRepositoryImpl(db),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<UserViewModel>(
          create: (context) => UserViewModel(
            UserRepositoryImpl(db),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<TodoViewModel>(
          create: (context) => TodoViewModel(
            repository: TodoRepositoryImpl(db),
            notificationService: NotificationService(),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<AgentViewModel>(
          create: (context) => AgentViewModel(
            AgentRepositoryImpl(
              db,
              companyId: null,
              isSuperAdmin: false,
            ),
          ),
          lazy: false,
        ),
      ],
      child: _MainNavigationPageContent(
        db: db,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _MainNavigationPageContent extends StatefulWidget {
  final AppDatabase db;
  final int initialIndex;

  const _MainNavigationPageContent({
    required this.db,
    required this.initialIndex,
  });

  @override
  State<_MainNavigationPageContent> createState() => _MainNavigationPageContentState();
}

class _MainNavigationPageContentState extends State<_MainNavigationPageContent> {
  int _selectedIndex = 0;
  final ValueNotifier<bool> _isSidebarOpenNotifier = ValueNotifier(true);
  ThemeMode _themeMode = ThemeMode.system;
  final ValueNotifier<int?> _badgeFilesNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _badgeRentalsNotifier = ValueNotifier(null);
  StreamSubscription<Map<String, dynamic>?>? _userStreamSubscription;
  Timer? _periodicPermissionCheckTimer;
  
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initializePages();
    _loadUserData();
    _loadTheme();
    _loadBadges();
    
    _userStreamSubscription = AuthService.currentUserStream.listen((user) {
      if (mounted && user != null && user['email'] != null) {
        _forcePermissionRefreshIfNeeded(user);
      }
    });
    
    _startPeriodicPermissionCheck();
    
    // Windows par foreground sync manually trigger karein
    _triggerForegroundSyncOnWindows();
  }

  void _initializePages() {
    final user = AuthService.currentUser;
    final companyId = RoleUtils.getUserCompanyId(user);
    final isSuperAdmin = RoleUtils.isSuperAdmin(user);
    final userId = user?['id']?.toString() ?? user?['userId']?.toString();

    _pages = [
      DashboardPage(db: widget.db),
      InventoryPage(db: widget.db),
      AgentWorkingPage(db: widget.db),
      RentalItemsPage(db: widget.db),
      ToDoPage(db: widget.db),
      SettingsPageClean(db: widget.db),
      TradingPage(db: widget.db),
      TradingPage(db: widget.db),
      ReportsPage(db: widget.db),
      UsersPage(db: widget.db),
      ExpenditurePage(
        db: widget.db,
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
        userId: userId,
      ),
      CompaniesPage(db: widget.db),
    ];
  }

  Future<void> _loadUserData() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final token = settings['authToken'] as String?;
    if (token != null) {
      final user = await AuthService.getCurrentUser(token);
      if (mounted && user != null) {
        setState(() {
          _initializePages();
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
    _userStreamSubscription?.cancel();
    _periodicPermissionCheckTimer?.cancel();
    _isSidebarOpenNotifier.dispose();
    _badgeFilesNotifier.dispose();
    _badgeRentalsNotifier.dispose();
    super.dispose();
  }

  /// Start periodic permission check as fallback
  void _startPeriodicPermissionCheck() {
    int checkCount = 0;
    const maxChecks = 5;
    
    _periodicPermissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      checkCount++;
      
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final currentUser = AuthService.currentUser;
      if (currentUser != null && !PermissionSyncService.arePermissionsFullyLoaded(currentUser)) {
        debugPrint('MainNavigationPage: Periodic check #$checkCount - Permissions not loaded, forcing refresh...');
        await _forcePermissionRefreshIfNeeded(currentUser);
      }
      
      if (checkCount >= maxChecks || (currentUser != null && PermissionSyncService.arePermissionsFullyLoaded(currentUser))) {
        timer.cancel();
        debugPrint('MainNavigationPage: Periodic permission checks completed');
      }
    });
  }

  /// Force permission refresh if permissions are not loaded
  Future<void> _forcePermissionRefreshIfNeeded(Map<String, dynamic> user) async {
    if (!PermissionSyncService.arePermissionsFullyLoaded(user)) {
      debugPrint('MainNavigationPage: Permissions not loaded, forcing refresh...');
      
      try {
        final storage = AppStorage();
        final settings = await storage.readSettings();
        final token = settings['authToken'] as String?;
        
        if (token != null) {
          await PermissionSyncService.refreshUserPermissions(token);
          
          final refreshedUser = await AuthService.getCurrentUser(token);
          if (refreshedUser != null && mounted) {
            setState(() {
              _initializePages();
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
    try {
      final filesCount = await widget.db.customSelect(
        'SELECT COUNT(*) as count FROM files_table WHERE is_active = 1',
      ).getSingle();
      
      final rentalsCount = await widget.db.customSelect(
        'SELECT COUNT(*) as count FROM rental_items WHERE is_active = 1 AND status = "rented"',
      ).getSingle();
      
      if (mounted) {
        _badgeFilesNotifier.value = filesCount.data['count'] as int?;
        _badgeRentalsNotifier.value = rentalsCount.data['count'] as int?;
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
    setState(() {
      _selectedIndex = 6;
    });
  }

  void _onLogout() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final sessionId = settings['currentSessionId'] as String?;
    
    await PermissionSyncService.performLogout(sessionId);
    
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  void _onToggleSidebar() {
    _isSidebarOpenNotifier.value = !_isSidebarOpenNotifier.value;
  }

  void _onThemeChanged(String mode) {
    setState(() {
      _themeMode = _themeFrom(mode);
    });
    AdminApp.applyThemeSetting(mode);
  }

  // ✅ NEW METHOD: Windows par sync manually trigger karein
  Future<void> _triggerForegroundSyncOnWindows() async {
    final isWindows = !kIsWeb && io.Platform.isWindows;
    
    if (!isWindows) return;
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    try {
      debugPrint('🔄 MainNavigationPage: Triggering foreground sync for Windows...');
      await ForegroundSyncManager.instance.syncNow();
      debugPrint('✅ MainNavigationPage: Foreground sync triggered successfully');
    } catch (e) {
      debugPrint('❌ MainNavigationPage: Foreground sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _buildResponsiveLayout(),
    );
  }

  Widget _buildResponsiveLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 768;
        
        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthService.currentUserNotifier,
                builder: (context, effectiveUser, _) {
                  if (effectiveUser == null) return const SizedBox.shrink();
                  
                  return ValueListenableBuilder<int?>(
                    valueListenable: _badgeFilesNotifier,
                    builder: (context, filesBadge, _) {
                      return ValueListenableBuilder<int?>(
                        valueListenable: _badgeRentalsNotifier,
                        builder: (context, rentalsBadge, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isSidebarOpenNotifier,
                            builder: (context, isOpen, _) {
                              return ModernSidebar(
                                selectedIndex: _selectedIndex,
                                onDestinationSelected: _onDestinationSelected,
                                onTradingTap: _onTradingTap,
                                onLogout: _onLogout,
                                onToggle: _onToggleSidebar,
                                isOpen: isOpen,
                                currentUser: effectiveUser,
                                badgeFiles: filesBadge,
                                badgeRentals: rentalsBadge,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(width: 8),
              
              // Main Content Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    _buildHeaderBar(),
                    
                    const SizedBox(height: 12),
                    
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Mobile layout
          return Scaffold(
            body: _buildMobileContent(),
            drawer: _buildMobileDrawer(),
            appBar: AppBar(
              title: Text(_getNavigationTitle()),
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          );
        }
      },
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)],
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
          ValueListenableBuilder<bool>(
            valueListenable: _isSidebarOpenNotifier,
            builder: (context, isOpen, _) {
              return !isOpen ? const SizedBox(width: 16) : const SizedBox.shrink();
            },
          ),
          
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
          
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Picture
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthService.currentUserNotifier,
                builder: (context, user, _) {
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF805AD5),
                    child: Text(
                      (user?['name']?.isNotEmpty == true) 
                          ? user!['name'].substring(0, 1).toUpperCase() 
                          : 'U',
                      style: AppFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              
              // Notification Bell
              Consumer<TodoViewModel>(
                builder: (context, todoVM, child) {
                  final hasUnread = todoVM.unreadReminders.isNotEmpty;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: todoVM,
                                child: const NotificationsPage(),
                              ),
                            ),
                          );
                        },
                        style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                        tooltip: 'Notifications',
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              
              // Refresh Permissions Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  onPressed: () async {
                    final currentUser = AuthService.currentUser;
                    if (currentUser != null) {
                      await _forcePermissionRefreshIfNeeded(currentUser);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Permissions refreshed successfully'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                  tooltip: 'Refresh Permissions',
                ),
              ),
              const SizedBox(width: 8),
              
              // Theme Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  icon: Icon(
                    _themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
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
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                  tooltip: _themeMode == ThemeMode.dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C3E50),
      child: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: AuthService.currentUserNotifier,
        builder: (context, currentUser, _) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4A90E2).withOpacity(0.8),
                      const Color(0xFF2C3E50).withOpacity(0.95),
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
                            child: currentUser?['profile_picture_path'] == null
                                ? Text(
                                    (currentUser?['name']?.isNotEmpty == true)
                                        ? currentUser!['name'].substring(0, 1).toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : ClipOval(
                                    child: PlatformAwareImage(
                                      imagePath: currentUser?['profile_picture_path'],
                                      width: 48,
                                      height: 48,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser?['name'] ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  currentUser?['email'] ?? 'user@example.com',
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
                    ValueListenableBuilder<int?>(
                      valueListenable: _badgeFilesNotifier,
                      builder: (context, badgeVal, _) =>
                          _buildMobileDrawerItem('Inventory', Icons.insert_drive_file, 1, badge: badgeVal),
                    ),
                    _buildMobileDrawerItem('Agent Working', Icons.support_agent, 2),
                    ValueListenableBuilder<int?>(
                      valueListenable: _badgeRentalsNotifier,
                      builder: (context, badgeVal, _) =>
                          _buildMobileDrawerItem('Rental Items', Icons.chair, 3, badge: badgeVal),
                    ),
                    _buildMobileDrawerItem('To-Do', Icons.checklist, 4),
                    _buildMobileDrawerItem('Expenditure', Icons.payments, 10),
                    if (currentUser != null && currentUser['role'] == 'super_admin')
                      _buildMobileDrawerItem('User Management', Icons.people, 9),
                    if (currentUser != null && currentUser['role'] == 'super_admin')
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
          );
        },
      ),
    );
  }

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

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 0),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F9FA), Color(0xFFF1F3F4)],
              ),
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ),
      ],
    );
  }

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
