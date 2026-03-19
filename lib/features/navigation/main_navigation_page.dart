import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../widgets/custom_sidebar.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/services/auth_service.dart';
import '../../../core/services/permission_helper.dart';
import '../../../core/app.dart' show AdminApp;
import '../dashboard/dashboard_page.dart';
import '../inventory/pages/inventory_page.dart';
import '../agent_working/pages/agent_working_page.dart';
import '../rental/pages/rental_page.dart' show RentalItemsPage;
import '../todo/pages/todo_page.dart' show ToDoPage;
import '../settings/pages/settings_page.dart' show SettingsPageClean;
import '../trading/pages/trading_page.dart';
import '../trading/view_models/trading_view_model.dart';
import '../trading/repositories/trading_repository_impl.dart';
import '../expenditure/pages/expenditure_page.dart';
import '../users/pages/users_page.dart';
import '../companies/pages/companies_page.dart';
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
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserData();
    _loadTheme();
    _loadBadges();
  }

  Future<void> _loadUserData() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final token = settings['authToken'] as String?;
    if (token != null) {
      final user = await AuthService().getCurrentUser(token);
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
    await storage.writeSettings({'authToken': null, 'currentSessionId': null});
    await AuthService().logout(sessionId);
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
        return SettingsPageClean(db: widget.db);
      case 6:
        return TradingPage(db: widget.db);
      case 7:
        return TradingPage(db: widget.db); // Trading Form
      case 8:
        return ReportsPage(db: widget.db);
      case 9:
        return UsersPage(db: widget.db);
      case 10:
        return ExpenditurePage(db: widget.db);
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
          create: (context) => TradingViewModel.getInstance(TradingRepositoryImpl(widget.db)),
          lazy: false, // Ensure ViewModel is created immediately and stays alive
        ),
        // Add other providers here as needed for different pages
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar
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
                              Text(
                                'Real Estate Management System',
                                style: AppFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Dark Mode Toggle - Positioned in top-right corner
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
                  ),
                  
                  // 12px vertical gap separator
                  const SizedBox(height: 12),
                  
                  // Page Content - Removed breadcrumb sub-header for cleaner UI
                  Expanded(
                    child: Container(
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
        ),
      ),
    );
  }
}

/// Reports page placeholder
class ReportsPage extends StatelessWidget {
  final AppDatabase db;
  const ReportsPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2D3748),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assessment,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Reports Module',
              style: AppFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics and reports coming soon',
              style: AppFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
