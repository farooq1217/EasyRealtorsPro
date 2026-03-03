import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String username;
  final String userId;
  final String name;
  final String email;
  final String? contactNo;
  final Map<String, dynamic>? permissions;
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

  // Helper getter for role (derived from status or permissions)
  String get role {
    return status ?? 'user';
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
    Map<String, dynamic>? permissions,
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
      'permissions': permissions != null ? _encodePermissions(permissions!) : null,
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
    return UserModel(
      id: (map['id'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      contactNo: map['contact_no']?.toString(),
      permissions: map['permissions'] != null ? _decodePermissions(map['permissions']) : null,
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
  }

  // Helper methods for permissions encoding/decoding
  static String _encodePermissions(Map<String, dynamic> permissions) {
    try {
      return permissions.entries.map((e) => '${e.key}:${e.value}').join(',');
    } catch (e) {
      return '';
    }
  }

  static Map<String, dynamic> _decodePermissions(String encoded) {
    try {
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
