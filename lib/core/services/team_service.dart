import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service that centralizes user management authorization and actions.
class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns true if the current user is allowed to manage [targetUserEmail].
  /// All Firestore user documents are keyed by the user's lowercase email.
  Future<bool> canManageUser(String targetUserEmail) async {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    if (currentUserEmail == null) return false;

    final DocumentSnapshot<Map<String, dynamic>> currentUserDoc =
        await _firestore.collection('users').doc(currentUserEmail).get();
    final currentUserData = currentUserDoc.data();
    if (!currentUserDoc.exists || currentUserData == null) return false;

    final currentUserRole = (currentUserData['role'] ?? '').toString();
    final currentUserCompanyId = (currentUserData['companyId'] ?? '').toString();

    // Super Admin can manage anyone
    if (currentUserRole == 'super_admin') return true;

    // Admin can only manage users in the same company
    if (currentUserRole == 'admin') {
      final DocumentSnapshot<Map<String, dynamic>> targetUserDoc =
          await _firestore.collection('users').doc(targetUserEmail.toLowerCase()).get();
      final targetUserData = targetUserDoc.data();
      if (!targetUserDoc.exists || targetUserData == null) return false;

      final targetCompanyId = (targetUserData['companyId'] ?? '').toString();
      return currentUserCompanyId == targetCompanyId;
    }

    return false;
  }

  Future<void> updateUser(String userEmail, Map<String, dynamic> data, {String? phoneNumber}) async {
    final emailKey = userEmail.trim().toLowerCase();
    if (await canManageUser(emailKey)) {
      await _firestore.collection('users').doc(emailKey).set(data, SetOptions(merge: true));
      final phoneId = phoneNumber?.trim().isNotEmpty == true
          ? phoneNumber!.trim()
          : (data['contact_no'] ?? data['phone'] ?? data['mobile'])?.toString().trim();
      if (phoneId != null && phoneId.isNotEmpty && phoneId != emailKey) {
        try {
          await _firestore.collection('users').doc(phoneId).delete();
        } catch (_) {}
      }
    } else {
      throw Exception('Unauthorized: You do not have permission to edit this user.');
    }
  }

  Future<void> deleteUser(String userEmail, {String? phoneNumber}) async {
    final emailKey = userEmail.trim().toLowerCase();
    if (await canManageUser(emailKey)) {
      // Instead of deleting, mark as inactive for safety
      await _firestore.collection('users').doc(emailKey).set({
        'status': 'inactive',
        'is_active': 0,
      }, SetOptions(merge: true));
      final phoneId = phoneNumber?.trim();
      if (phoneId != null && phoneId.isNotEmpty && phoneId != emailKey) {
        try {
          await _firestore.collection('users').doc(phoneId).delete();
        } catch (_) {}
      }
    } else {
      throw Exception('Unauthorized: You do not have permission to delete this user.');
    }
  }

  /// Note: Production password resets should go through Firebase Auth flows.
  Future<void> resetUserPassword(String userEmail, String newPassword, {String? phoneNumber}) async {
    final emailKey = userEmail.trim().toLowerCase();
    if (await canManageUser(emailKey)) {
      await _firestore.collection('users').doc(emailKey).set({
        'password': newPassword, // Prefer sendPasswordResetEmail for real apps
      }, SetOptions(merge: true));
      // Cleanup any legacy phone-based doc
      final phoneId = phoneNumber?.trim();
      if (phoneId != null && phoneId.isNotEmpty && phoneId != emailKey) {
        try {
          await _firestore.collection('users').doc(phoneId).delete();
        } catch (_) {}
      }
    } else {
      throw Exception('Unauthorized');
    }
  }
}
