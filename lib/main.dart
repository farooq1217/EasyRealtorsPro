import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
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

  // 1. Database Configuration (Theek hai)
  AppDatabase.configureOpener(() async {
    final appDir = await getApplicationSupportDirectory();
    final dbFile = io.File(p.join(appDir.path, 'data.sqlite'));
    return openAppExecutor(dbFile.path);
  });

  // 2. Firebase Initialization - Wrapped in postFrame callback to avoid threading issues
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 3. Firestore Settings (Initialization ke BAAD)
      await runZonedGuarded(() async {
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
      }, (error, stack) {
        debugPrint('Firestore settings skipped: $error');
      });
    } catch (e) {
      debugPrint('Firebase Error: $e');
    }
  });

  runApp(const AdminApp());
}