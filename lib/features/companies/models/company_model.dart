import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class CompanyModel extends Equatable {
  final String id;
  final String name;
  final String? status;
  final Map<String, dynamic>? metadata;
  final String? logoUrl;
  final String? address;
  final String? contact;
  final int? maxUserLimit;
  final String? subscriptionTier;
  final bool isActive;
  final bool isSynced;
  final String? createdAt;
  final String? updatedAt;

  const CompanyModel({
    required this.id,
    required this.name,
    this.status,
    this.metadata,
    this.logoUrl,
    this.address,
    this.contact,
    this.maxUserLimit,
    this.subscriptionTier,
    this.isActive = true,
    this.isSynced = true,
    this.createdAt,
    this.updatedAt,
  });

  CompanyModel copyWith({
    String? id,
    String? name,
    String? status,
    Map<String, dynamic>? metadata,
    String? logoUrl,
    String? address,
    String? contact,
    int? maxUserLimit,
    String? subscriptionTier,
    bool? isActive,
    bool? isSynced,
    String? createdAt,
    String? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      logoUrl: logoUrl ?? this.logoUrl,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      maxUserLimit: maxUserLimit ?? this.maxUserLimit,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status ?? 'active',
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
      'logo_url': logoUrl,
      'address': address,
      'contact': contact,
      'max_user_limit': maxUserLimit,
      'subscription_tier': subscriptionTier,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    try {
      debugPrint('CompanyModel.fromMap: Input map keys: ${map.keys.toList()}');
      debugPrint('CompanyModel.fromMap: Input map data: $map');
      
      final company = CompanyModel(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        status: map['status']?.toString(),
        metadata: map['metadata'] != null ? _decodeMetadata(map['metadata']) : null,
        logoUrl: map['logo_url']?.toString(),
        address: map['address']?.toString(),
        contact: map['contact']?.toString(),
        maxUserLimit: map['max_user_limit'] is int ? map['max_user_limit'] : int.tryParse(map['max_user_limit']?.toString() ?? ''),
        subscriptionTier: map['subscription_tier']?.toString(),
        isActive: (map['is_active'] is int ? map['is_active'] == 1 : map['is_active'] == true) ?? true,
        isSynced: (map['is_synced'] is int ? map['is_synced'] == 1 : map['is_synced'] == true) ?? true,
        createdAt: map['created_at']?.toString(),
        updatedAt: map['updated_at']?.toString(),
      );
      
      debugPrint('CompanyModel.fromMap: Successfully created company: ${company.name}');
      return company;
    } catch (e) {
      debugPrint('CompanyModel.fromMap: Error creating company from map: $e');
      debugPrint('CompanyModel.fromMap: Map that caused error: $map');
      // Return empty company as fallback
      return const CompanyModel(
        id: '',
        name: 'Error Loading Company',
        status: 'error',
      );
    }
  }

  // Helper methods for metadata encoding/decoding
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    try {
      return metadata.entries.map((e) => '${e.key}:${e.value}').join(',');
    } catch (e) {
      return '';
    }
  }

  static Map<String, dynamic> _decodeMetadata(String encoded) {
    try {
      final Map<String, dynamic> metadata = {};
      final entries = encoded.split(',');
      for (final entry in entries) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          metadata[parts[0]] = parts[1];
        }
      }
      return metadata;
    } catch (e) {
      return {};
    }
  }

  // Public static methods for repository use
  static String encodeMetadata(Map<String, dynamic> metadata) {
    return _encodeMetadata(metadata);
  }

  static Map<String, dynamic> decodeMetadata(String encoded) {
    return _decodeMetadata(encoded);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        status,
        metadata,
        logoUrl,
        address,
        contact,
        maxUserLimit,
        subscriptionTier,
        isActive,
        isSynced,
        createdAt,
        updatedAt,
      ];
}
