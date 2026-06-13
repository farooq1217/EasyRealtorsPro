import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shared/shared.dart';
import '../login_page.dart';
import '../offline_sync_service.dart';
import '../shimmer_widgets.dart';
import 'services/app_storage.dart' show AppStorage;
import '../features/navigation/main_navigation_page.dart' show MainNavigationPage;
import 'package:provider/provider.dart';
import 'services/auth/jwt_service.dart';
import 'services/auth/password_hashing_service.dart';
import 'services/auth/local_auth_storage.dart';
import 'services/auth/drift_user_dao.dart';
import 'services/auth/firestore_auth_sync.dart';
import 'services/auth/auth_repository.dart';
import 'services/auth/auth_service.dart';
import 'services/permission_helper.dart';
import 'services/background_sync_manager.dart';
import 'services/network_sync_manager.dart';
import 'services/notification_service.dart';
import 'role_utils.dart' as local;

/// Main application widget with MaterialApp configuration
class AdminApp extends StatelessWidget {
  final Map<String, dynamic>? currentUser;
  final JwtService? jwtService;
  
  const AdminApp({super.key, this.currentUser, this.jwtService});

  /// Static method to toggle theme
  static void toggleTheme() {
    _AdminAppContentState.toggleTheme();
  }
  
  /// Static method to apply theme setting
  static void applyThemeSetting(String mode) {
    _AdminAppContentState.applyThemeSetting(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Independent services FIRST
        Provider<JwtService>(create: (_) => JwtService()),
        Provider<LocalAuthStorage>(create: (_) => LocalAuthStorage()),
        Provider<DriftUserDao>(create: (_) => DriftUserDao()),
        Provider<FirestoreAuthSync>(create: (_) => FirestoreAuthSync()),

        // 2. Repository (depends on services above)
        ChangeNotifierProvider<AuthRepository>(
          create: (context) => AuthRepository(
            jwt: context.read<JwtService>(),
            localStore: context.read<LocalAuthStorage>(),
            driftDao: context.read<DriftUserDao>(),
            fsSync: context.read<FirestoreAuthSync>(),
          ),
        ),

        // 3. AuthService Facade LAST (depends on repository)
        ChangeNotifierProvider<AuthService>(
          lazy: false,
          create: (context) => AuthService(
            repository: context.read<AuthRepository>(),
            jwt: context.read<JwtService>(),
            localStore: context.read<LocalAuthStorage>(),
          ),
        ),
      ],
      child: const _AdminAppContent(),
    );
  }
}

class _AdminAppContent extends StatefulWidget {
  const _AdminAppContent();
  @override
  State<_AdminAppContent> createState() => _AdminAppContentState();
}

class _AdminAppContentState extends State<_AdminAppContent> {
  ThemeMode _themeMode = ThemeMode.system;
  static _AdminAppContentState? _instance;

  void _applyThemeSetting(String mode) {
    if (!mounted) return;
    setState(() { _themeMode = _themeFrom(mode); });
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    _loadTheme();
    if (AuthService.currentUser != null) {
      if (!BackgroundSyncManager().hasBeenInitializedInSession) {
        BackgroundSyncManager().initialize().catchError((e) {
          debugPrint('[APP] Error initializing background sync manager: $e');
        });
        debugPrint('[APP] Background sync manager initialized');
      }
    }
    NotificationService().initialize().catchError((e) {
      debugPrint('[APP] Error initializing notification service: $e');
    });
    NetworkSyncManager.instance.initialize().catchError((e) {
      debugPrint('[APP] Error initializing network sync manager: $e');
    });
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
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
    String newMode;
    if (currentMode == 'light') {
      newMode = 'dark';
    } else if (currentMode == 'dark') {
      newMode = 'light';
    } else {
      newMode = _themeMode == ThemeMode.dark ? 'light' : 'dark';
    }
    await storage.writeSettings({...settings, 'theme': newMode});
    if (mounted) setState(() { _themeMode = _themeFrom(newMode); });
  }

  static void toggleTheme() { _instance?._toggleTheme(); }
  static void applyThemeSetting(String mode) { _instance?._applyThemeSetting(mode); }

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
        (kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS));
    final baseLight = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      useMaterial3: true,
      visualDensity: isTouch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: isTouch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
      fontFamily: 'Poppins',
    );
    final baseDark = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
      useMaterial3: true,
      visualDensity: isTouch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: isTouch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
      fontFamily: 'Poppins',
    );
    final dark = baseDark.copyWith(
      scaffoldBackgroundColor: const Color(0xFF101214),
      cardColor: const Color(0xFF1B1F24),
      listTileTheme: const ListTileThemeData(textColor: Colors.white, iconColor: Colors.white70),
      textTheme: baseDark.textTheme.apply(bodyColor: Colors.white.withOpacity(0.98), displayColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF23272E),
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
      builder: (context, child) => child ?? const SizedBox.shrink(),
      home: const LoginPage(),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final routeToNavIndex = <String, int>{
          '/home': 0, '/inventory': 1, '/agent-working': 2, '/rental': 3,
          '/todo': 4, '/settings': 5, '/trading': 6, '/trading-form': 7,
          '/reports': 7, '/users': 9, '/companies': 10, '/expenditure': 10,
        };
        final routeToModuleKey = <String, String>{
          '/home': 'dashboard', '/inventory': 'inventory', '/agent-working': 'agent_working',
          '/rental': 'rental_items', '/todo': 'todo', '/settings': 'settings',
          '/trading': 'trading', '/trading-form': 'trading', '/reports': 'reports',
          '/users': 'users', '/companies': 'companies', '/expenditure': 'expenditure',
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
        return MaterialPageRoute(builder: (_) => const LoginPage());
      },
    );
  }
}

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
      if (mounted && context.mounted) _runGuard();
    });
  }

  Future<void> _runGuard() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final token = settings['authToken'] as String?;
      final sessionId = settings['currentSessionId'] as String?;
      final hasValidToken = token != null && await AuthService.verifyToken(token);
      
      if (!hasValidToken) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
        return;
      }
      
      final user = await AuthService.getCurrentUser(token);
      if (user == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
        return;
      }
      
      // ✅ CRITICAL FIX: Check if database is initialized before using it
      final db = AppDatabase.instanceIfInitialized;
      if (db == null) {
        debugPrint('[GUARD] Database not initialized, waiting...');
        // Wait for database to initialize
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Try again
        final dbRetry = AppDatabase.instanceIfInitialized;
        if (dbRetry == null) {
          debugPrint('[GUARD] Database still not initialized, showing error');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database initialization failed. Please restart the app.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
          return;
        }
      }
      
      if (!mounted) return;
      
      // ✅ SAFE: Now we know db is not null
      final safeDb = AppDatabase.instanceIfInitialized!;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationPage(
            db: safeDb,
            initialIndex: widget.targetNavIndex ?? 0,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[GUARD] Error in _runGuard: $e');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
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
      if (!mounted || !context.mounted) return;
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
                  const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red));
              }
              if (mounted) Navigator.of(context).pushReplacementNamed('/home');
              return;
            }
          }
        } catch (_) {}
        
        // ✅ CRITICAL FIX: Check if database is initialized
        final db = AppDatabase.instanceIfInitialized;
        if (db == null) {
          debugPrint('[REDIRECT] Database not initialized, waiting...');
          await Future.delayed(const Duration(milliseconds: 500));
          
          final dbRetry = AppDatabase.instanceIfInitialized;
          if (dbRetry == null) {
            debugPrint('[REDIRECT] Database still not initialized');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Database initialization failed'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.of(context).pushReplacementNamed('/home');
            }
            return;
          }
        }
        
        if (mounted) {
          // ✅ SAFE: Now we know db is not null
          final safeDb = AppDatabase.instanceIfInitialized!;
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainNavigationPage(
                db: safeDb,
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