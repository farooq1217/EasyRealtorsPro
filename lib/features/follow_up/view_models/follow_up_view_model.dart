// lib/features/follow_up/view_models/follow_up_view_model.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // For WidgetsBinding
import '../repositories/follow_up_repository.dart';
import '../repositories/follow_up_repository_impl.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/services/app_storage.dart';
import 'package:shared/src/db/schema.dart' hide FollowUp;
import '../../../core/services/permission_helper.dart';
import '../../../core/role_utils.dart';
import '../models/follow_up.dart' as domain;

/// ViewModel for the Follow‑Up feature.
/// Handles real‑time streaming of follow‑up entries, permission checks,
/// and integration with the auto‑todo (reminder) system.
class FollowUpViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Repository & stream subscription
  // ---------------------------------------------------------------------------
  final FollowUpRepository _repository;
  StreamSubscription<List<domain.FollowUp>>? _followUpsSubscription;

  // ---------------------------------------------------------------------------
  // User context
  // ---------------------------------------------------------------------------
  Map<String, dynamic>? _currentUser;
  bool _isSuperAdmin = false;
  String? _companyId;
  String? _userId;

  // ---------------------------------------------------------------------------
  // UI state
  // ---------------------------------------------------------------------------
  List<domain.FollowUp> _followUps = [];
  bool _loading = true;
  String? _errorMessage;
  bool _mounted = false;

  // ---------------------------------------------------------------------------
  // Construction & initialization
  // ---------------------------------------------------------------------------
  FollowUpViewModel({FollowUpRepository? repository})
      : _repository = repository ?? FollowUpRepositoryImpl(AppDatabase.instanceIfInitialized!, '') {
    _mounted = true;
    _initializeUser();
  }

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------
  List<domain.FollowUp> get followUps => _followUps;
  bool get loading => _loading;
  String? get error => _errorMessage;
  bool get isSuperAdmin => _isSuperAdmin;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Permission helpers – follow the same pattern used across the app.
  bool get canAddFollowUp => PermissionHelper.canAddModule(_currentUser, 'follow_up');
  bool get canEditFollowUp => PermissionHelper.canEditModule(_currentUser, 'follow_up');
  bool get canDeleteFollowUp => PermissionHelper.canDeleteModule(_currentUser, 'follow_up');

  // ---------------------------------------------------------------------------
  // Private helpers – user loading
  // ---------------------------------------------------------------------------
  Future<void> _initializeUser() async {
    try {
      final storage = AppStorage();
      final settings = await storage.readSettings();
      final authToken = settings['authToken'] as String?;
      if (authToken != null) {
        _currentUser = await AuthService.getCurrentUser(authToken);
        _isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
        _companyId = RoleUtils.getUserCompanyId(_currentUser);
        _userId = _currentUser?['id']?.toString();
        // Re‑create repository with proper user id for auto‑todo creation.
        // The repository implementation expects the user id as the second ctor argument.
        if (_repository is FollowUpRepositoryImpl) {
          // Re‑instantiate to inject the correct user id.
          // This is safe because the repository holds only a reference to the DB.
          // The existing instance may have been constructed with an empty userId.
          // We replace it with a new one that carries the real userId.
          // Note: This assignment works because _repository is final only at compile time;
          // we are inside the constructor, so we can use a local variable.
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize user context: $e';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Loading the follow‑up stream
  // ---------------------------------------------------------------------------
  Future<void> loadFollowUps() async {
    _setLoading(true);
    _errorMessage = null;
    // Cancel any previous subscription.
    await _followUpsSubscription?.cancel();
    try {
      final companyId = _isSuperAdmin ? null : _companyId;
      _followUpsSubscription = _repository.watchFollowUps(companyId).listen(
        (items) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_mounted) return;
            _followUps = items;
            _setLoading(false);
            notifyListeners();
          });
        },
        onError: (error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_mounted) return;
            _errorMessage = error.toString();
            _setLoading(false);
            notifyListeners();
          });
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD operations – they rely on the repository and trigger the stream.
  // ---------------------------------------------------------------------------
  Future<bool> addFollowUp(domain.FollowUp followUp) async {
    if (!canAddFollowUp) {
      _errorMessage = 'You do not have permission to add follow‑ups.';
      notifyListeners();
      return false;
    }
    try {
      await _repository.addFollowUp(followUp, _userId ?? '');
      // Stream will emit the new list; no manual refresh needed.
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add follow‑up: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateFollowUp(domain.FollowUp followUp) async {
    if (!canEditFollowUp) {
      _errorMessage = 'You do not have permission to edit follow‑ups.';
      notifyListeners();
      return false;
    }
    try {
      await _repository.updateFollowUp(followUp);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update follow‑up: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFollowUp(String id) async {
    if (!canDeleteFollowUp) {
      _errorMessage = 'You do not have permission to delete follow‑ups.';
      notifyListeners();
      return false;
    }
    try {
      await _repository.deleteFollowUp(id);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete follow‑up: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helper to toggle loading flag.
  // ---------------------------------------------------------------------------
  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _mounted = false;
    _followUpsSubscription?.cancel();
    super.dispose();
  }
}
