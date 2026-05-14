import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'core/utils/logger.dart';
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart' show AppDatabase;
import 'core/database/db_executor.dart';
import 'core/services/firebase_options.dart';
import 'core/services/auth_service.dart';
import 'core/services/update_manager.dart';
import 'core/app.dart';          // ✅ Sirf EK baar import
import 'core/windows_accessibility_fix.dart';
import 'firestore_sync_service.dart';
import 'core/services/log_service.dart'; // ✅ LogService import

/// Safe Firebase initialization with Windows support and graceful fallback
Future<void> _initializeFirebaseSafely(bool isWindows) async {
  Logger.info('Firebase: Starting safe initialization...', tag: 'Firebase');
  try {
    if (Firebase.apps.isNotEmpty) {
      Logger.info('Firebase: Already initialized', tag: 'Firebase');
      return;
    }
    if (isWindows) {
      Logger.info('Firebase: Windows platform detected', tag: 'Firebase');
      final hasGoogleServices = await _checkGoogleServicesFile();
      if (!hasGoogleServices) {
        Logger.warning('Firebase: google-services-desktop.json not found', tag: 'Firebase');
        _initializeFallbackMode();
        return;
      }
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
        Logger.info('Firebase: Successfully initialized on Windows', tag: 'Firebase');
      } catch (e) {
        Logger.warning('Firebase: Windows initialization failed', tag: 'Firebase');
        _initializeFallbackMode();
      }
    } else {
      try {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (_validateFirebaseOptions(options)) {
          await Firebase.initializeApp(options: options);
          Logger.info('Firebase: Successfully initialized', tag: 'Firebase');
        } else {
          _initializeFallbackMode();
        }
      } catch (e) {
        Logger.error('Firebase: Initialization failed', tag: 'Firebase', error: e);
        _initializeFallbackMode();
      }
    }
  } catch (e) {
    Logger.error('Firebase: Critical error', tag: 'Firebase', error: e);
    _initializeFallbackMode();
  }
}

Future<bool> _checkGoogleServicesFile() async {
  try {
    final appDir = await getApplicationSupportDirectory();
    final file = io.File('${appDir.path}/google-services-desktop.json');
    return await file.exists();
  } catch (e) {
    return false;
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

Future<T?> safeFirebaseOperation<T>(Future<T> Function() operation, {T? fallbackValue}) async {
  if (!isFirebaseAvailable()) return fallbackValue;
  try {
    return await operation().timeout(const Duration(seconds: 15));
  } catch (e) {
    Logger.error('Firebase: Operation failed', tag: 'Firebase', error: e);
    return fallbackValue;
  }
}

// ✅ SINGLE main() FUNCTION - CORRECTED
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Initialize Logging FIRST
  await LogService.init();
  await LogService.write('✅ App Started');
  
  tzdata.initializeTimeZones();
  final isWindows = !kIsWeb && io.Platform.isWindows;

  await runZonedGuarded(() async {
    // 1. Database
    AppDatabase.configureOpener(() async {
      final appDir = await getApplicationSupportDirectory();
      final dbFile = io.File(p.join(appDir.path, 'data.sqlite'));
      return openAppExecutor(dbFile.path);
    });

    // Dev mode: schema check
    if (kDebugMode) {
      try {
        final db = await AppDatabase.instance();
        final tableInfo = await db.customSelect(
          'PRAGMA table_info(trading_entries)', 
          variables: <d.Variable<Object>>[]
        ).get();
        final columns = tableInfo.map((row) => row.data['name'] as String).toSet();
        final requiredColumns = {
          'id', 'entry_type', 'date', 'person_name', 'mobile_no', 
          'estate_name', 'quantity', 'unit_price', 'image_path',
          'company_id', 'is_active', 'is_synced', 'created_at', 'updated_at', 'status'
        };
        final missingColumns = requiredColumns.where((col) => !columns.contains(col));
        if (missingColumns.isNotEmpty) {
          Logger.warning('Missing columns: $missingColumns', tag: 'MAIN');
          await AppDatabase.closeInstance();
          await AppDatabase.resetDatabaseInDevMode();
        }
      } catch (e) {
        Logger.error('Schema check failed', tag: 'MAIN', error: e);
        await AppDatabase.resetDatabaseInDevMode();
      }
    }

    // 2. Firebase
    await _initializeFirebaseSafely(isWindows);

    // 3. Firestore settings
    if (Firebase.apps.isNotEmpty) {
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    }

    // 4. Update check
    if (isWindows && Firebase.apps.isNotEmpty) {
      UpdateManager().checkForUpdate();
    }
    
    // ✅ RUN APP HERE (End of first main function)
runApp(const AdminApp());    
  }, (error, stack) {
    // Error handler
    final criticalPatterns = [
      'channel sent a message', 'non-platform thread', 'firebase_auth_plugin',
      'id-token', 'Platform channel message', 'Announce message', 'viewId',
      'FlutterViewId', 'accessibility', 'semantics',
    ];
    final shouldSilence = criticalPatterns.any((p) => error.toString().contains(p));
    if (!shouldSilence) {
      Logger.error('Global error', tag: 'Global', error: error);
    }
  });

  // 5. Windows fixes
  if (isWindows) {
    WindowsAccessibilityFix.initialize();
  }
}