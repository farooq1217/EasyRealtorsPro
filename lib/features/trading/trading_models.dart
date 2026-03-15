import 'package:flutter/material.dart';

/// Trading module models
class TradingDeal {
  final String id;
  final String clientId;
  final String propertyId;
  final String dealType; // 'sale' or 'purchase'
  final double dealAmount;
  final DateTime dealDate;
  final String status; // 'pending', 'completed', 'cancelled'
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  TradingDeal({
    required this.id,
    required this.clientId,
    required this.propertyId,
    required this.dealType,
    required this.dealAmount,
    required this.dealDate,
    required this.status,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TradingDeal.fromMap(Map<String, dynamic> map) {
    return TradingDeal(
      id: map['id'] ?? '',
      clientId: map['client_id'] ?? '',
      propertyId: map['property_id'] ?? '',
      dealType: map['deal_type'] ?? '',
      dealAmount: (map['deal_amount'] ?? 0.0).toDouble(),
      dealDate: DateTime.parse(map['deal_date'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'pending',
      metadata: map['metadata'] ?? {},
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'property_id': propertyId,
      'deal_type': dealType,
      'deal_amount': dealAmount,
      'deal_date': dealDate.toIso8601String(),
      'status': status,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TradingClient {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;

  TradingClient({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TradingClient.fromMap(Map<String, dynamic> map) {
    return TradingClient(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
