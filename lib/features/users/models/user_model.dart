import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
// Force refresh

class UserModel extends Equatable {
  final String id;
  final String username;
  final String userId;
  final String name;
  final String email;
  final String? contactNo;
  final String? permissions; // Changed from Map to String for database storage
  final String? companyId;
  final String? status;
  final bool isActive;
  final bool isSynced;
  final String? createdAt;
  final String? updatedAt;
  final String? passwordHash;
  final String? salt;
  final int? iterations;
  final bool? isFirstLogin;
  final String? profilePicturePath;

  const UserModel({
    required this.id,
    required this.username,
    required this.userId,
    required this.name,
    required this.email,
    this.contactNo,
    this.permissions,
    this.companyId,
    this.status,
    this.isActive = true,
    this.isSynced = true,
    this.createdAt,
    this.updatedAt,
    this.passwordHash,
    this.salt,
    this.iterations,
    this.isFirstLogin,
    this.profilePicturePath,
  });

  // Helper getter for role (derived from JSON permissions)
  // Fixed: Handle null check properly for type safety
  String get role {
    if (permissions != null && permissions!.isNotEmpty) {
      // Parse role from JSON permissions - this is the single source of truth
      try {
        final decoded = jsonDecode(permissions!) as Map<String, dynamic>;
        return decoded['role']?.toString() ?? 'agent';
      } catch (e) {
        debugPrint('UserModel.role: Error parsing JSON string permissions: $e');
        debugPrint('UserModel.role: Permissions string was: $permissions');
        
        // Try to extract role from malformed JSON
        try {
          final strValue = permissions!;
          if (strValue.contains('role')) {
            final roleMatch = RegExp(r'"role"\s*:\s*"([^"]+)"').firstMatch(strValue);
            if (roleMatch != null) {
              return roleMatch.group(1) ?? 'agent';
            }
          }
        } catch (regexError) {
          debugPrint('UserModel.role: Regex extraction failed: $regexError');
        }
      }
    }
    // Fallback to status field for legacy data
    return status ?? 'agent';
  }

  // Helper getter to access permissions as Map for UI compatibility
  Map<String, dynamic> get permissionsMap {
    if (permissions == null || permissions!.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(permissions!);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (e) {
      debugPrint('UserModel.permissionsMap: Error parsing permissions: $e');
      return {};
    }
  }

  // Helper method to handle permissions field conversion in fromMap
  static String? _handlePermissionsField(dynamic permissionsData) {
    if (permissionsData == null) return null;
    
    if (permissionsData is String) {
      // Already a string, validate and return as-is
      final strValue = permissionsData.toString().trim();
      if (strValue.isEmpty) return null;
      
      // Validate JSON format if it looks like JSON
      if (strValue.startsWith('{') && strValue.endsWith('}')) {
        try {
          jsonDecode(strValue); // Validate JSON
          return strValue;
        } catch (e) {
          debugPrint('UserModel._handlePermissionsField: Invalid JSON string, treating as simple string: $e');
          return strValue; // Return as simple string even if invalid JSON
        }
      }
      return strValue;
    } else if (permissionsData is Map) {
      // Convert Map to JSON string
      try {
        return jsonEncode(permissionsData);
      } catch (e) {
        debugPrint('UserModel._handlePermissionsField: Error encoding Map to JSON: $e');
        return jsonEncode({'role': 'agent'});
      }
    } else {
      // Unknown type, try to convert to string
      try {
        final strValue = permissionsData.toString().trim();
        if (strValue.isEmpty) return null;
        
        // Check if it's already JSON
        if (strValue.startsWith('{') && strValue.endsWith('}')) {
          try {
            jsonDecode(strValue); // Validate JSON
            return strValue;
          } catch (e) {
            debugPrint('UserModel._handlePermissionsField: Invalid JSON in unknown type: $e');
          }
        }
        // Otherwise, treat as simple string
        return strValue;
      } catch (e) {
        debugPrint('UserModel._handlePermissionsField: Error converting permissions to string: $e');
        return null;
      }
    }
  }

  // Empty constructor for search fallback
  UserModel.empty()
      : id = '',
        username = '',
        userId = '',
        name = '',
        email = '',
        contactNo = null,
        permissions = null,
        companyId = null,
        status = null,
        isActive = false,
        isSynced = false,
        createdAt = null,
        updatedAt = null,
        passwordHash = null,
        salt = null,
        iterations = null,
        isFirstLogin = null,
        profilePicturePath = null;

  UserModel copyWith({
    String? id,
    String? username,
    String? userId,
    String? name,
    String? email,
    String? contactNo,
    String? permissions, // Changed from Map to String
    String? companyId,
    String? status,
    bool? isActive,
    bool? isSynced,
    String? createdAt,
    String? updatedAt,
    String? passwordHash,
    String? salt,
    int? iterations,
    bool? isFirstLogin,
    String? profilePicturePath,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      contactNo: contactNo ?? this.contactNo,
      permissions: permissions ?? this.permissions,
      companyId: companyId ?? this.companyId,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      iterations: iterations ?? this.iterations,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'user_id': userId,
      'name': name,
      'email': email,
      'contact_no': contactNo,
      'permissions': permissions, // Already a String, no encoding needed
      'company_id': companyId,
      'status': status,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'password_hash': passwordHash,
      'salt': salt,
      'iterations': iterations,
      'is_first_login': isFirstLogin == true ? 1 : 0,
      'profile_picture_path': profilePicturePath,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    try {
      debugPrint('UserModel.fromMap: Input map keys: ${map.keys.toList()}');
      debugPrint('UserModel.fromMap: Input map data: $map');
      
      // Handle empty/null critical fields with fallbacks
      final email = (map['email'] ?? '').toString().trim();
      final name = (map['name'] ?? '').toString().trim();
      final username = (map['username'] ?? '').toString().trim();
      
      // If email is empty, use id as fallback identifier
      final finalEmail = email.isEmpty ? (map['id'] ?? '').toString() : email;
      
      // If name is empty, use email or username as fallback
      final finalName = name.isEmpty ? 
        (email.isNotEmpty ? email.split('@')[0] : 
        (username.isNotEmpty ? username : 'Unknown User')) : name;
      
      // If username is empty, use email as fallback
      final finalUsername = username.isEmpty ? 
        (email.isNotEmpty ? email.split('@')[0] : 'user_${map['id'] ?? ''}') : username;
      
      final user = UserModel(
        id: (map['id'] ?? '').toString(),
        username: finalUsername,
        userId: (map['user_id'] ?? '').toString(),
        name: finalName,
        email: finalEmail,
        contactNo: map['contact_no']?.toString(),
        permissions: _handlePermissionsField(map['permissions']),
        companyId: (map['company_id'] ?? map['companyId'])?.toString(),
        status: map['status']?.toString(),
        isActive: (map['is_active'] is int ? map['is_active'] == 1 : map['is_active'] == true) ?? true,
        isSynced: (map['is_synced'] is int ? map['is_synced'] == 1 : map['is_synced'] == true) ?? true,
        createdAt: map['created_at']?.toString(),
        updatedAt: map['updated_at']?.toString(),
        passwordHash: map['password_hash']?.toString(),
        salt: map['salt']?.toString(),
        iterations: map['iterations'] is int ? map['iterations'] : int.tryParse(map['iterations']?.toString() ?? ''),
        isFirstLogin: (map['is_first_login'] is int ? map['is_first_login'] == 1 : map['is_first_login'] == true),
        profilePicturePath: map['profile_picture_path']?.toString(),
      );
      
      debugPrint('UserModel.fromMap: Successfully created user: ${user.name} (${user.email})');
      return user;
    } catch (e) {
      debugPrint('UserModel.fromMap: Error creating user from map: $e');
      debugPrint('UserModel.fromMap: Map that caused error: $map');
      // Return empty user as fallback
      return UserModel.empty();
    }
  }

  // Helper methods for permissions encoding/decoding
  static String _encodePermissions(Map<String, dynamic> permissions) {
    try {
      return jsonEncode(permissions);
    } catch (e) {
      debugPrint('UserModel._encodePermissions: Error encoding permissions: $e');
      return jsonEncode({'role': 'agent'});
    }
  }

  static Map<String, dynamic> _decodePermissions(String encoded) {
    try {
      if (encoded.trim().isEmpty) return {};
      // Try JSON decode first
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      // Fallback to legacy comma-separated format
      final Map<String, dynamic> permissions = {};
      final entries = encoded.split(',');
      for (final entry in entries) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          permissions[parts[0]] = parts[1];
        }
      }
      return permissions;
    } catch (e) {
      debugPrint('UserModel._decodePermissions: Error decoding permissions: $e');
      return {};
    }
  }

  // Public static methods for repository use
  static String encodePermissions(Map<String, dynamic> permissions) {
    return _encodePermissions(permissions);
  }

  static Map<String, dynamic> decodePermissions(String encoded) {
    return _decodePermissions(encoded);
  }

  @override
  List<Object?> get props => [
        id,
        username,
        userId,
        name,
        email,
        contactNo,
        permissions,
        companyId,
        status,
        isActive,
        isSynced,
        createdAt,
        updatedAt,
        passwordHash,
        salt,
        iterations,
        isFirstLogin,
        profilePicturePath,
      ];
}
