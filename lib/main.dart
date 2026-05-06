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
import 'core/app.dart';
import 'core/windows_accessibility_fix.dart';
import 'firestore_sync_service.dart';

/// Safe Firebase initialization with Windows support and graceful fallback
Future<void> _initializeFirebaseSafely(bool isWindows) async {
  Logger.info('Firebase: Starting safe initialization...', tag: 'Firebase');
  
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      Logger.info('Firebase: Already initialized', tag: 'Firebase');
      return;
    }

    // Windows-specific initialization checks
    if (isWindows) {
      Logger.info('Firebase: Windows platform detected, performing additional checks...', tag: 'Firebase');
      
      // Check for required Firebase files
      final hasGoogleServices = await _checkGoogleServicesFile();
      if (!hasGoogleServices) {
        Logger.warning('Firebase: google-services-desktop.json not found, using fallback mode', tag: 'Firebase');
        _initializeFallbackMode();
        return;
      }
      
      // Windows-specific timeout and retry logic
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
        Logger.info('Firebase: Successfully initialized on Windows', tag: 'Firebase');
      } catch (e) {
        Logger.warning('Firebase: Windows initialization failed, using fallback mode', tag: 'Firebase');
        debugPrint('Firebase: Error details: $e');
        _initializeFallbackMode();
        return;
      }
    } else {
      // Non-Windows platforms: normal initialization
      try {
        final options = DefaultFirebaseOptions.currentPlatform;
        
        // Validate options before initialization
        if (_validateFirebaseOptions(options)) {
          await Firebase.initializeApp(
            options: options,
          );
          Logger.info('Firebase: Successfully initialized with options', tag: 'Firebase');
        } else {
          Logger.warning('Firebase: Invalid options detected, using fallback mode', tag: 'Firebase');
          _initializeFallbackMode();
        }
        
      } catch (e) {
        Logger.error('Firebase: Initialization failed', tag: 'Firebase', error: e);
        _initializeFallbackMode();
      }
    }

  } catch (e) {
    Logger.error('Firebase: Critical initialization error', tag: 'Firebase', error: e);
    _initializeFallbackMode();
  }
}

/// Check if google-services-desktop.json exists (Windows specific)
Future<bool> _checkGoogleServicesFile() async {
  try {
    // Try to access the file that should exist for Windows Firebase setup
    final appDir = await getApplicationSupportDirectory();
    final googleServicesFile = io.File('${appDir.path}/google-services-desktop.json');
    return await googleServicesFile.exists();
  } catch (e) {
    Logger.error('Firebase: Could not check google-services file', tag: 'Firebase', error: e);
    return false;
  }
}

/// Validate Firebase options before initialization
bool _validateFirebaseOptions(FirebaseOptions options) {
  return options.apiKey.isNotEmpty && 
         options.appId.isNotEmpty && 
         options.projectId.isNotEmpty &&
         !options.apiKey.contains('TODO') &&
         !options.appId.contains('placeholder');
}

/// Initialize fallback mode when Firebase setup is incomplete
void _initializeFallbackMode() {
  Logger.info('Firebase: Initializing in offline-only mode', tag: 'Firebase');
  Logger.info('Firebase: Features disabled - Firestore, Auth, Storage', tag: 'Firebase');
  Logger.info('Firebase: Local SQLite database will be used exclusively', tag: 'Firebase');
  
  // Set global flag for Firebase availability
  _isFirebaseAvailable = false;
  
  // The app will continue to work with local SQLite database
  // NetworkSyncManager and other Firebase-dependent services should check Firebase.apps.isEmpty
}

/// Global flag for Firebase availability check
bool _isFirebaseAvailable = true;

/// Check if Firebase is properly initialized and available
bool isFirebaseAvailable() {
  return _isFirebaseAvailable && Firebase.apps.isNotEmpty;
}

/// Safe Firebase operation wrapper
Future<T?> safeFirebaseOperation<T>(Future<T> Function() operation, {T? fallbackValue}) async {
  if (!isFirebaseAvailable()) {
    Logger.warning('Firebase: Operation skipped - Firebase not available', tag: 'Firebase');
    return fallbackValue;
  }
  
  try {
    return await operation().timeout(const Duration(seconds: 15));
  } catch (e) {
    Logger.error('Firebase: Operation failed', tag: 'Firebase', error: e);
    return fallbackValue;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  final isWindows = !kIsWeb && io.Platform.isWindows;

  // Enhanced error handling for platform channel threading issues and Windows accessibility
  await runZonedGuarded(() async {
    // 1. Database Configuration (Theek hai)
    AppDatabase.configureOpener(() async {
      final appDir = await getApplicationSupportDirectory();
      final dbFile = io.File(p.join(appDir.path, 'data.sqlite'));
      return openAppExecutor(dbFile.path);
    });

    // Development mode: Reset database if schema issues detected
    if (kDebugMode) {
      try {
        // Try to access the database to check if it's working
        final db = await AppDatabase.instance();
        
        // Check table schema directly to detect all missing columns
        try {
          final tableInfo = await db.customSelect('PRAGMA table_info(trading_entries)', variables: <d.Variable<Object>>[]).get();
          final columns = tableInfo.map((row) => row.data['name'] as String).toSet();
          
          Logger.debug('Current trading_entries columns: ${columns.toList()}', tag: 'MAIN');
          
          final requiredColumns = {
            'id', 'entry_type', 'date', 'person_name', 'mobile_no', 
            'estate_name', 'quantity', 'unit_price', 'image_path',
            'company_id', 'is_active', 'is_synced', 'created_at', 'updated_at', 'status'
          };
          
          final missingColumns = requiredColumns.where((col) => !columns.contains(col));
          
          if (missingColumns.isNotEmpty) {
            Logger.warning('Missing columns detected: $missingColumns', tag: 'MAIN');
            Logger.info('Resetting database in development mode...', tag: 'MAIN');
            await AppDatabase.closeInstance();
            await AppDatabase.resetDatabaseInDevMode();
          } else {
            Logger.debug('Database schema validation passed', tag: 'MAIN');
          }
        } catch (e) {
          // If schema check fails, reset the database
          Logger.error('Database schema check failed', tag: 'MAIN', error: e);
          Logger.info('Resetting database in development mode...', tag: 'MAIN');
          await AppDatabase.closeInstance();
          await AppDatabase.resetDatabaseInDevMode();
        }
      } catch (e) {
        Logger.error('Database initialization failed', tag: 'MAIN', error: e);
        Logger.info('Resetting database in development mode...', tag: 'MAIN');
        await AppDatabase.resetDatabaseInDevMode();
      }
    }

    // 2. Firebase Initialization - Enhanced Windows Support with Graceful Fallback
    await _initializeFirebaseSafely(isWindows);

    // 3. Firestore Settings (Initialization ke BAAD)
    if (Firebase.apps.isNotEmpty) {
      if (isWindows) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        Logger.debug('Windows Firestore: Persistence Disabled', tag: 'Firestore');
      } else {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      }
    }

    // 3. Check for updates after Firebase initialization (if successful)
    if (isWindows && Firebase.apps.isNotEmpty) {
      Logger.debug('Windows Platform: Checking for updates...', tag: 'Update');
      UpdateManager().checkForUpdate();
    }
  }, (error, stack) {
    // Comprehensive global error handler for platform channel issues and Windows accessibility errors
    // CRITICAL: Enhanced filtering of platform-specific warnings to eliminate console noise
    final criticalPatterns = [
      'channel sent a message',
      'non-platform thread',
      'firebase_auth_plugin',
      'id-token',
      'Platform channel message',
      'Announce message',
      'viewId',
      'FlutterViewId',
      'accessibility',
      'semantics',
      'firebase_auth_plugin',
      'id-token',
      'Platform channel message',
      'background_fetch',
      'flutter_background_fetch',
      'path_provider',
      'sqflite',
      'shared_preferences',
      'firebase_storage',
      'firebase_messaging',
      'fluttertoast',
      'fluttertoast_web',
      'fluttertoast_platform_interface',
      'fluttertoast_web_platform_interface',
      'firebase_auth',
      'firebase_core',
      'cloud_firestore',
    ];
    
    // Windows-specific accessibility error patterns
    final windowsAccessibilityPatterns = [
      'viewId property must be a FlutterViewId',
      'Announce message',
      'SemanticsService.announce',
      'Tooltip',
      'Accessibility',
      'Windows accessibility',
      'viewId',
      'FlutterViewId',
    ];
    
    // Check if error should be silenced
    final shouldSilence = criticalPatterns.any((pattern) => error.toString().contains(pattern)) ||
                         (isWindows && windowsAccessibilityPatterns.any((pattern) => error.toString().contains(pattern)));
    
    if (shouldSilence) {
      // Only log in debug mode for development
      if (kDebugMode) {
        Logger.debug('Platform/Accessibility warning silenced: ${error.runtimeType}', tag: 'Platform');
      }
    } else {
      Logger.error('Global error', tag: 'Global', error: error);
      if (kDebugMode) {
        Logger.debug('Stack trace: $stack', tag: 'Global');
      }
    }
  });

  // 4. Initialize Windows-specific fixes
  if (isWindows) {
    // Windows: Add connection stability handling
    Logger.debug('Windows Platform: Applying connection stability fixes', tag: 'Platform');
    
    // Initialize Windows accessibility fixes to prevent viewId errors
    WindowsAccessibilityFix.initialize();
  }
  
  // Use original AdminApp to avoid build issues
  runApp(const AdminApp());
}