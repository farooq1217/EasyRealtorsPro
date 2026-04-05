import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, kDebugMode;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import '../login_page.dart';
import '../offline_sync_service.dart';
import '../shimmer_widgets.dart';
import 'services/app_storage.dart' show AppStorage;
import '../features/navigation/main_navigation_page.dart' show MainNavigationPage;
import 'services/auth_service.dart';
import 'services/permission_helper.dart';
import 'services/background_sync_manager.dart';
import 'services/network_sync_manager.dart';
import 'services/notification_service.dart';
import 'role_utils.dart' as local;

/// Main application widget with MaterialApp configuration
class AdminApp extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  
  const AdminApp({super.key, this.currentUser});
  @override
  State<AdminApp> createState() => _AdminAppState();
  
  /// Static method to toggle theme
  static void toggleTheme() {
    _AdminAppState.toggleTheme();
  }
  
  /// Static method to apply theme setting
  static void applyThemeSetting(String mode) {
    _AdminAppState.applyThemeSetting(mode);
  }
}

class _AdminAppState extends State<AdminApp> {
  ThemeMode _themeMode = ThemeMode.system;
  static _AdminAppState? _instance;

  void _applyThemeSetting(String mode) {
    if (!mounted) return;
    setState(() {
      _themeMode = _themeFrom(mode);
    });
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    _loadTheme();
    
    // If currentUser is provided, set it in AuthService
    if (widget.currentUser != null) {
      AuthService.currentUser = widget.currentUser;
    }
    
    // Initialize offline sync service
    OfflineSyncService().initialize();
    
    // Only initialize background sync if user is logged in
    // Enhanced with redundant call prevention
    if (AuthService.currentUser != null) {
      // CRITICAL: Check if Background Sync Manager is already initialized to prevent redundant calls
      if (!BackgroundSyncManager().hasBeenInitializedInSession) {
        BackgroundSyncManager().initialize().catchError((e) {
          debugPrint('[APP] Error initializing background sync manager: $e');
        });
        debugPrint('[APP] Background sync manager initialized');
      } else {
        // Reduced verbosity - only log in debug mode
        if (kDebugMode) {
          debugPrint('[APP] Background sync manager already initialized in this session, skipping...');
        }
      }
    } else {
      debugPrint('[APP] Skipping background sync initialization - no user logged in');
    }
    
    // Initialize notification service
    NotificationService().initialize().catchError((e) {
      debugPrint('[APP] Error initializing notification service: $e');
    });
    
    // Initialize Network Sync Manager for comprehensive offline-first support
    NetworkSyncManager.instance.initialize().catchError((e) {
      debugPrint('[APP] Error initializing network sync manager: $e');
    });
  }

  @override
  void dispose() {
    if (_instance == this) {
      _instance = null;
    }
    OfflineSyncService().dispose();
    BackgroundSyncManager().dispose().catchError((e) {
      debugPrint('[APP] Error disposing background sync manager: $e');
    });
    NetworkSyncManager.instance.dispose().catchError((e) {
      debugPrint('[APP] Error disposing network sync manager: $e');
    });
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final mode = (settings['theme'] as String?) ?? 'system';
    setState(() { _themeMode = _themeFrom(mode); });
  }

  Future<void> _toggleTheme() async {
    if (!mounted) return;
    
    final storage = AppStorage();
    final settings = await storage.readSettings();
    final currentMode = (settings['theme'] as String?) ?? 'system';
    
    // Toggle between light and dark
    String newMode;
    if (currentMode == 'light') {
      newMode = 'dark';
    } else if (currentMode == 'dark') {
      newMode = 'light';
    } else {
      // If system mode, toggle based on current ThemeMode
      newMode = _themeMode == ThemeMode.dark ? 'light' : 'dark';
    }
    
    await storage.writeSettings({...settings, 'theme': newMode});
    if (mounted) {
      setState(() { _themeMode = _themeFrom(newMode); });
    }
  }

  static void toggleTheme() {
    _instance?._toggleTheme();
  }

  static void applyThemeSetting(String mode) {
    _instance?._applyThemeSetting(mode);
  }

  ThemeMode _themeFrom(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTouch = (!kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) ||
        (kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS));

    final baseLight = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      useMaterial3: true,
      visualDensity: isTouch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: isTouch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        displaySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        headlineLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        titleLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        bodyLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(MaterialState.disabled)) return const Color(0xFFFF6B35).withOpacity(0.5);
              if (states.contains(MaterialState.hovered) || states.contains(MaterialState.pressed)) {
                return const Color(0xFFFF7C4F);
              }
              return const Color(0xFFFF6B35);
            },
          ),
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          overlayColor: MaterialStateProperty.all<Color>(Colors.white24),
          elevation: MaterialStateProperty.resolveWith<double>(
            (states) => states.contains(MaterialState.hovered) ? 6 : 4,
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
          textStyle: MaterialStateProperty.all<TextStyle>(
            const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: MaterialStateProperty.all<BorderSide>(const BorderSide(color: Color(0xFFFF6B35), width: 1.4)),
          foregroundColor: MaterialStateProperty.all<Color>(const Color(0xFFFF6B35)),
          overlayColor: MaterialStateProperty.all<Color>(const Color(0xFFFF6B35).withOpacity(0.08)),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: MaterialStateProperty.all<TextStyle>(
            const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 5,
        hoverElevation: 8,
      ),
    );
    final baseDark = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
      useMaterial3: true,
      visualDensity: isTouch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: isTouch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        displaySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        headlineLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        titleLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        bodyLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
      ),
    );
    final dark = baseDark.copyWith(
      scaffoldBackgroundColor: const Color(0xFF101214),
      cardColor: const Color(0xFF1B1F24),
      listTileTheme: const ListTileThemeData(textColor: Colors.white, iconColor: Colors.white70),
      textTheme: baseDark.textTheme.apply(bodyColor: Colors.white.withOpacity(0.98), displayColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF23272E),
        hintStyle: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        border: OutlineInputBorder(),
      ),
    );
    return MaterialApp(
      title: 'EasyRealtorsPro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: baseLight,
      darkTheme: dark,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
      home: const LoginPage(),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        // Map known routes to target nav indices and module keys for permission checks
        final routeToNavIndex = <String, int>{
          '/home': 0,
          '/inventory': 1,
          '/agent-working': 2,
          '/rental': 3,
          '/todo': 4,
          '/settings': 5,
          '/trading': 6, // unified trading (file)
          '/trading-form': 7, // unified trading (form)
          '/reports': 7, // NEW: Reports page
          '/users': 9,
          '/companies': 10,
          '/expenditure': 10,
        };
        final routeToModuleKey = <String, String>{
          '/home': 'dashboard',
          '/inventory': 'inventory',
          '/agent-working': 'agent_working',
          '/rental': 'rental_items',
          '/todo': 'todo',
          '/settings': 'settings',
          '/trading': 'trading',
          '/trading-form': 'trading',
          '/reports': 'reports', // NEW: Reports page
          '/users': 'users',
          '/companies': 'companies',
          '/expenditure': 'expenditure',
        };

        if (name == '/' || name.isEmpty) {
          return MaterialPageRoute(builder: (_) => const LoginPage());
        }

        if (routeToNavIndex.containsKey(name)) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => _GuardedEntry(
              targetNavIndex: routeToNavIndex[name],
              moduleKey: routeToModuleKey[name],
            ),
          );
        }

        // Unknown route: send to login
        return MaterialPageRoute(builder: (_) => const LoginPage());
      },
    );
  }
}

/// Guard widget that validates session and module permissions before navigation.
class _GuardedEntry extends StatefulWidget {
  final int? targetNavIndex;
  final String? moduleKey;
  const _GuardedEntry({required this.targetNavIndex, this.moduleKey});

  @override
  State<_GuardedEntry> createState() => _GuardedEntryState();
}

class _GuardedEntryState extends State<_GuardedEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runGuard();
    });
  }

  Future<void> _runGuard() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final token = settings['authToken'] as String?;
      final sessionId = settings['currentSessionId'] as String?;

      // Require valid auth token + session
      final hasValidToken = token != null && await AuthService.verifyToken(token);
      if (!hasValidToken) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        return;
      }

      final user = await AuthService.getCurrentUser(token);
      if (user == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        return;
      }

      // Authorized: proceed to Home with target nav
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationPage(
            db: AppDatabase.instanceIfInitialized!,
            initialIndex: widget.targetNavIndex ?? 0,
          ),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ShimmerPageLoading(itemCount: 8));
  }
}

class _RedirectToHome extends StatefulWidget {
  final int targetNavIndex;
  const _RedirectToHome({required this.targetNavIndex});

  @override
  State<_RedirectToHome> createState() => _RedirectToHomeState();
}

class _RedirectToHomeState extends State<_RedirectToHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.microtask(() async {
        try {
          final routeName = ModalRoute.of(context)?.settings.name;
          final s = await AppStorage().readSettings();
          final authToken = s['authToken'] as String?;
          Map<String, dynamic>? user;
          if (authToken != null && (routeName == '/users' || routeName == '/companies')) {
            if (local.RoleUtils.isAgent(user)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),
                );
              }
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/home');
              }
              return;
            }
          }
        } catch (_) {}

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainNavigationPage(
                db: AppDatabase.instanceIfInitialized!,
                initialIndex: widget.targetNavIndex,
              ),
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ShimmerPageLoading(itemCount: 8));
  }
}

