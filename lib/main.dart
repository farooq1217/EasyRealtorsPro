import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:shared/shared.dart' show AppDatabase;
import 'core/database/db_executor.dart' show openAppExecutor;
import 'core/services/firebase_options.dart';
import 'core/services/auth_service.dart';
import 'core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  AppDatabase.configureOpener(() async {
    if (kIsWeb) {
      return openAppExecutor('desktop_admin');
    }

    final dir = await getApplicationSupportDirectory();
    final appDir = io.Directory('${dir.path}${io.Platform.pathSeparator}desktop_admin');
    if (!await appDir.exists()) await appDir.create(recursive: true);
    final dbFile = io.File(p.join(appDir.path, 'data.sqlite'));

    return openAppExecutor(dbFile.path);
  });

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AuthService.ensureFirebasePersistence();
    // Firestore persistence is enabled by default on desktop
  } catch (e) {
    // Firebase initialization failed (likely due to placeholder config)
    // App will continue to run but Firebase features won't work
    debugPrint('Firebase initialization failed: $e');
  }

  // One-time migration: force non-archived users to active (is_active = 1) so legacy records do not block login.
  await _activateNonArchivedUsers();

  runApp(const AdminApp());
}

Future<void> _activateNonArchivedUsers() async {
  if (kIsWeb) return;
  try {
    final db = await AppDatabase.instance();
    await db.customStatement(
      "UPDATE users SET is_active = 1, status = 'active' WHERE (status IS NULL OR LOWER(status) != 'archived') AND (is_active IS NULL OR is_active = 0)",
    );
  } catch (e) {
    debugPrint('Failed to normalize user active flags: $e');
  }
}
