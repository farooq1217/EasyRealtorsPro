import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'foreground_sync_manager.dart';

/// ✅ App lifecycle observer - sync ko foreground tak limit karta hai
class AppLifecycleObserver with WidgetsBindingObserver {
  bool _isInForeground = false;
  
  AppLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
    _isInForeground = true; // App start par foreground mein hai
    debugPrint('🔄 AppLifecycleObserver: Initialized - App is in foreground');
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = _isInForeground;
    
    switch (state) {
      case AppLifecycleState.resumed:
        _isInForeground = true;
        debugPrint('🟢 AppLifecycleObserver: App RESUMED - Starting sync...');
        _onAppResumed();
        break;
        
      case AppLifecycleState.inactive:
        debugPrint('🟡 AppLifecycleObserver: App INACTIVE');
        break;
        
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _isInForeground = false;
        debugPrint('🔴 AppLifecycleObserver: App PAUSED - Stopping sync...');
        _onAppPaused();
        break;
    }
  }
  
  /// ✅ Jab app foreground mein aaye
  Future<void> _onAppResumed() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('⚠️ AppLifecycleObserver: Firebase not initialized, skipping sync');
      return;
    }
    
    try {
      // Foreground sync manager ko notify karein
      await ForegroundSyncManager.instance.syncNow();
      debugPrint('✅ AppLifecycleObserver: Foreground sync triggered');
    } catch (e) {
      debugPrint('❌ AppLifecycleObserver: Error triggering sync: $e');
    }
  }
  
  /// ✅ Jab app background mein jaye
  Future<void> _onAppPaused() async {
    try {
      // Active listeners ko pause karein
      await ForegroundSyncManager.instance.pauseSync();
      debugPrint('✅ AppLifecycleObserver: Sync paused');
    } catch (e) {
      debugPrint('❌ AppLifecycleObserver: Error pausing sync: $e');
    }
  }
  
  bool get isInForeground => _isInForeground;
  
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}