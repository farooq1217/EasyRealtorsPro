import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:easyrealtorspro/core/utils/logger.dart';
import 'package:easyrealtorspro/core/database/database_connection.dart';
import 'package:easyrealtorspro/core/services/firebase_options.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import 'package:easyrealtorspro/core/app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easyrealtorspro/core/services/auth/jwt_service.dart';

/// Web-specific main entrypoint that properly initializes the real application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  tzdata.initializeTimeZones();

  debugPrint('Starting web build with full application features');

  // Enhanced error handling for web platform
  await runZonedGuarded(() async {
    // 1. Database Configuration - Use abstracted database layer
    debugPrint('Web: Initializing database with abstracted layer...');
    await DatabaseConnection.instance.initialize();
    debugPrint('Web: Database initialized successfully');

    // 2. Firebase Initialization - Graceful fallback for web
    try {
      if (Firebase.apps.isEmpty) {
        // Check if Firebase options are valid (not placeholders)
        final options = DefaultFirebaseOptions.currentPlatform;
        final isValidOptions = options.apiKey.isNotEmpty && 
                              !options.apiKey.contains('TODO') &&
                              !options.appId.contains('placeholder') &&
                              !options.projectId.contains('todo-project-id');
        
        if (isValidOptions) {
          await Firebase.initializeApp(options: options);
          debugPrint('Web: Firebase initialized successfully');
        } else {
          debugPrint('Web: Firebase options are placeholders, skipping Firebase initialization');
          debugPrint('Web: App will run in offline-only mode');
        }
      } else {
        debugPrint('Web: Firebase already initialized');
      }
    } catch (e) {
      debugPrint('Web: Firebase initialization failed: $e');
      debugPrint('Web: App will run in offline-only mode');
    }

    // 3. Firestore Settings - Optimized for web (only if Firebase is initialized)
    if (Firebase.apps.isNotEmpty) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true, // Enable persistence for web
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('Web: Firestore settings configured with persistence');
      } catch (e) {
        debugPrint('Web: Firestore settings failed: $e');
      }
    } else {
      debugPrint('Web: Firebase not initialized - running in offline mode');
    }

    // 4. Run the real AdminApp - Same as desktop version
    debugPrint('Web: Starting AdminApp with full features');
    final jwtService = JwtService();
    await jwtService.initialize();
    runApp(AdminApp(jwtService: jwtService));
    
  }, (error, stack) {
    // Comprehensive error handler for web
    debugPrint('Web: Global error - $error');
    if (kDebugMode) {
      debugPrint('Web: Stack trace - $stack');
    }
    
    // Fallback: Show error screen with retry option
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Application Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to initialize the application.\nError: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => main(), // Retry initialization
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  });
}
