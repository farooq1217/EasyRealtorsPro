import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:shared/shared.dart' show AppDatabase;
import 'core/database/db_executor.dart' show openAppExecutor;
import 'core/services/firebase_options.dart';
import 'core/services/auth_service.dart';
import 'core/app.dart';
import 'firestore_sync_service.dart';

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

    // 2. Firebase Initialization - Wrapped in postFrame callback to avoid threading issues
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await runZonedGuarded(() async {
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }

          // 3. Firestore Settings (Initialization ke BAAD)
          if (Firebase.apps.isNotEmpty) {
            if (isWindows) {
              FirebaseFirestore.instance.settings = const Settings(
                persistenceEnabled: false,
                cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
              );
              debugPrint('Windows Firestore: Persistence Disabled');
            } else {
              FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
            }
          }
        } catch (e) {
          debugPrint('Firebase Error: $e');
        }
      }, (error, stack) {
        // Enhanced silence for non-blocking native plugin warnings
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
          'background_fetch',
          'flutter_background_fetch',
        ];
        
        if (criticalPatterns.any((pattern) => error.toString().contains(pattern))) {
          debugPrint('Platform warning silenced: ${error.runtimeType}');
        } else {
          debugPrint('Firebase initialization error: $error');
        }
      });
    });
  }, (error, stack) {
    // Comprehensive global error handler for platform channel issues and Windows accessibility errors
    // CRITICAL: Enhanced filtering of platform-specific warnings to eliminate console noise
    final criticalPatterns = [
      'channel sent a message',
      'non-platform thread',
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
      'connectivity_plus',
      'path_provider',
      'sqflite',
      'shared_preferences',
    ];
    
    if (criticalPatterns.any((pattern) => error.toString().contains(pattern))) {
      debugPrint('Platform warning silenced: ${error.runtimeType}');
    } else {
      debugPrint('Global error: $error');
      if (kDebugMode) {
        debugPrint('Stack trace: $stack');
      }
    }
  });

  // 4. Run App
  runApp(const AdminApp());
}