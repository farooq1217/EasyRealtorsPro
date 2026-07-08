import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/utils/logger.dart';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart' show AppDatabase;
import 'core/database/db_executor.dart';
import 'core/services/firebase_options.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import 'core/services/update_manager.dart';
import 'core/app.dart';
import 'core/windows_accessibility_fix.dart';
import 'firestore_sync_service.dart';
import 'core/services/log_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easyrealtorspro/core/services/auth/jwt_service.dart';
import 'core/services/foreground_sync_manager.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';


/// Safe Firebase initialization with Windows support
Future<void> _initializeFirebaseSafely(bool isWindows) async {
  Logger.info('Firebase: Starting safe initialization...', tag: 'Firebase');
  try {
    if (Firebase.apps.isNotEmpty) {
      Logger.info('Firebase: Already initialized', tag: 'Firebase');
      return;
    }
    
    final options = DefaultFirebaseOptions.currentPlatform;
    if (_validateFirebaseOptions(options)) {
      await Firebase.initializeApp(options: options);
      Logger.info('Firebase: Successfully initialized', tag: 'Firebase');
      
      // ✅ Updated: Enable persistence on Windows for background sync
      if (isWindows) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true, // Enable offline persistence
        );
        Logger.info('Firebase: Windows - Firestore enabled persistence for background sync', tag: 'Firebase');
        // Enable network for background sync
        await FirebaseFirestore.instance.enableNetwork();
        Logger.info('Firebase: Network enabled for Firestore', tag: 'Firebase');
      }
    } else {
      Logger.warning('Firebase: Invalid options, initializing fallback mode', tag: 'Firebase');
      _initializeFallbackMode();
    }
  } catch (e) {
    Logger.error('Firebase: Initialization failed', tag: 'Firebase', error: e);
    _initializeFallbackMode();
  }
}

// Remote config setup function
Future<void> setupRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;

  // Settings: App kitni der baad Firebase se naya data check kare
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(minutes: 15), // Har 15 minute baad check karega
  ));

  // Agar internet na ho toh default value kya ho
  await remoteConfig.setDefaults(const {
    "show_new_banner": false,
  });

  // Firebase se values fetch aur activate karein
  try {
    await remoteConfig.fetchAndActivate();
    debugPrint('Remote Config updated!');
  } catch (e) {
    debugPrint('Remote Config error: $e');
  }
}

bool _validateFirebaseOptions(FirebaseOptions options) {
  return options.apiKey.isNotEmpty && 
         options.appId.isNotEmpty && 
         options.projectId.isNotEmpty &&
         !options.apiKey.contains('TODO') &&
         !options.appId.contains('placeholder');
}

void _initializeFallbackMode() {
  Logger.info('Firebase: Offline-only mode', tag: 'Firebase');
  _isFirebaseAvailable = false;
}

bool _isFirebaseAvailable = true;
bool isFirebaseAvailable() => _isFirebaseAvailable && Firebase.apps.isNotEmpty;

void main() async {
  final isWindows = !kIsWeb && io.Platform.isWindows;

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();


    
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('⚠️ Warning: Failed to load .env file: $e');
      dotenv.loadFromString(envString: 'DUMMY=true');
    }
    await LogService.init();
    await LogService.write('✅ App Started');
    
    tzdata.initializeTimeZones();
    
    // 1. Database
    AppDatabase.configureOpener(() async {
      if (kIsWeb) {
        return openAppExecutor(':memory:');
      } else {
        final appDir = await getApplicationSupportDirectory();
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        final dbFile = io.File(p.join(appDir.path, 'data.sqlite'));
        return openAppExecutor(dbFile.path);
      }
    });

    try {
      debugPrint('🔧 Initializing database...');
      final db = await AppDatabase.instance();
      debugPrint('✅ Database initialized successfully');
      
      if (!kIsWeb) {
        await db.customStatement('PRAGMA journal_mode=WAL');
        await db.customStatement('PRAGMA synchronous=NORMAL');
        debugPrint('✅ SQLite WAL mode enabled');
      }
    } catch (e) {
      debugPrint('❌ Database initialization failed: $e');
    }

    // 2. Firebase
    await _initializeFirebaseSafely(isWindows);

    // 3. Firestore settings
    if (Firebase.apps.isNotEmpty) {
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    }

  

    // 5. Update check
    if (isWindows && Firebase.apps.isNotEmpty) {
      UpdateManager().checkForUpdate();
    }
    
    final jwtService = JwtService();
    await jwtService.initialize();
    
    runApp(const AdminApp());  
  }, (error, stack) {
    // Error handler - Firebase threading errors ko gracefully handle karein
    final criticalPatterns = [
      'channel sent a message', 
      'non-platform thread', 
      'firebase_auth_plugin',
      'id-token',
    ];
    final shouldSilence = criticalPatterns.any((p) => error.toString().contains(p));
    
    if (!shouldSilence) {
      Logger.error('Global error', tag: 'Global', error: error);
    } else {
      debugPrint('⚠️ Silenced Firebase threading error (non-critical): $error');
    }
  });

  if (isWindows) {
    WindowsAccessibilityFix.initialize();
  }
}