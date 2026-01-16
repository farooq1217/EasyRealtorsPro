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

// One-time migration to add companyId to all existing documents.
Future<void> addCompanyIdToAllDocs() async {
  const companyId = '1768415476147';
  if (Firebase.apps.isEmpty) return;
  try {
    // Ensure current user doc (by email) has companyId
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'mayof286@gmail.com')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(snap.docs.first.id)
            .set({'companyId': companyId}, SetOptions(merge: true));
      }
    } catch (_) {}

    final collections = <String>[
      'users',
      'inventory',
      'files',
      'rental_items',
      'working_progress',
      'blocks',
      'societies',
      'expenditures',
      'projects',
      'project_expenditures',
      'trading_entries',
      'trading_file_entries',
    ];

    for (final col in collections) {
      final snap = await FirebaseFirestore.instance.collection(col).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        final slice = snap.docs.skip(i).take(400);
        for (final doc in slice) {
          batch.set(doc.reference, {'companyId': companyId}, SetOptions(merge: true));
        }
        await batch.commit();
      }
    }
    debugPrint('MIGRATION COMPLETE');
  } catch (e) {
    debugPrint('Migration failed: $e');
  }
}
