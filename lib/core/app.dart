import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import '../login_page.dart';
import '../offline_sync_service.dart';
import '../shimmer_widgets.dart';
import 'services/app_storage.dart' show AppStorage;
import '../modules/rental/rental_page.dart' show HomeScreen;
import 'services/auth_service.dart';

/// Main application widget with MaterialApp configuration
class AdminApp extends StatefulWidget {
  const AdminApp({super.key});
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
    // Initialize offline sync service
    OfflineSyncService().initialize();
  }

  @override
  void dispose() {
    if (_instance == this) {
      _instance = null;
    }
    OfflineSyncService().dispose();
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
    );
    final baseDark = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
      useMaterial3: true,
      visualDensity: isTouch ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: isTouch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
    );
    final dark = baseDark.copyWith(
      scaffoldBackgroundColor: const Color(0xFF101214),
      cardColor: const Color(0xFF1B1F24),
      listTileTheme: const ListTileThemeData(textColor: Colors.white, iconColor: Colors.white70),
      textTheme: baseDark.textTheme.apply(bodyColor: Colors.white.withOpacity(0.98), displayColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF23272E),
        hintStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
      ),
    );
    return MaterialApp(
      title: 'Desktop Admin',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: baseLight,
      darkTheme: dark,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
      home: const LoginPage(),
      routes: {
        '/home': (_) => HomeScreen(
              storage: AppStorage(),
              initialCreds: null,
              folderId: 'LOCAL',
              bypassDrive: true,
            ),
        '/users': (_) => const _RedirectToHome(targetNavIndex: 9),
        '/companies': (_) => const _RedirectToHome(targetNavIndex: 10),
      },
    );
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
            user = await AuthService().getCurrentUser(authToken);
            if (RoleUtils.isAgent(user)) {
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
              builder: (_) => HomeScreen(
                storage: AppStorage(),
                initialCreds: null,
                folderId: 'LOCAL',
                bypassDrive: true,
                initialNavIndex: widget.targetNavIndex,
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

