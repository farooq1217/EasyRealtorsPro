// domain/models/inventory_item.dart

// Required for JSON encoding/decoding
import 'dart:convert';

enum InventoryType { file, property }

class InventoryItem {
  final String id;
  final InventoryType type;
  final String clientName;
  final String referenceNo;
  final String societyId;
  final String? blockId;
  final String saleStatus;
  final String remarks;
  final String? cnic;
  final String companyId;
  final DateTime updatedAt;
  
  // File-specific fields
  final String? fileNo;
  final String? mobileNo;
  final String? path; // Size for files
  
  // Property-specific fields  
  final String? propertyName;
  final int? demand;
  final int? price;
  
  // Image URLs (stored as JSON in remarks field)
  final List<String> imageUrls;

  const InventoryItem({
    required this.id,
    required this.type,
    required this.clientName,
    required this.referenceNo,
    required this.societyId,
    this.blockId,
    this.saleStatus = 'Not Sold',
    this.remarks = '',
    this.cnic,
    required this.companyId,
    required this.updatedAt,
    this.fileNo,
    this.mobileNo,
    this.path,
    this.propertyName,
    this.demand,
    this.price,
    this.imageUrls = const [],
  });

  // Factory constructor for File items
  factory InventoryItem.file({
    required String id,
    required String clientName,
    required String referenceNo,
    required String societyId,
    String? blockId,
    String saleStatus = 'Not Sold',
    String remarks = '',
    String? cnic,
    required String companyId,
    required DateTime updatedAt,
    String? fileNo,
    String? mobileNo,
    String? path,
    List<String> imageUrls = const [],
  }) {
    return InventoryItem(
      id: id,
      type: InventoryType.file,
      clientName: clientName,
      referenceNo: referenceNo,
      societyId: societyId,
      blockId: blockId,
      saleStatus: saleStatus,
      remarks: remarks,
      cnic: cnic,
      companyId: companyId,
      updatedAt: updatedAt,
      fileNo: fileNo,
      mobileNo: mobileNo,
      path: path,
      imageUrls: imageUrls,
    );
  }

  // Factory constructor for Property items
  factory InventoryItem.property({
    required String id,
    required String clientName,
    required String referenceNo,
    required String societyId,
    String? blockId,
    String saleStatus = 'Not Sold',
    String remarks = '',
    String? cnic,
    required String companyId,
    required DateTime updatedAt,
    String? propertyName,
    int? demand,
    int? price,
    List<String> imageUrls = const [],
  }) {
    return InventoryItem(
      id: id,
      type: InventoryType.property,
      clientName: clientName,
      referenceNo: referenceNo,
      societyId: societyId,
      blockId: blockId,
      saleStatus: saleStatus,
      remarks: remarks,
      cnic: cnic,
      companyId: companyId,
      updatedAt: updatedAt,
      propertyName: propertyName,
      demand: demand,
      price: price,
      imageUrls: imageUrls,
    );
  }

  // Convert from database Map (for both files_table and properties)
  factory InventoryItem.fromMap(Map<String, dynamic> map, InventoryType type) {
    // Extract image URLs from remarks if it's JSON
    List<String> extractedImageUrls = [];
    final remarks = map['remarks']?.toString() ?? '';
    if (remarks.isNotEmpty) {
      try {
        final decoded = jsonDecode(remarks);
        if (decoded is List) {
          extractedImageUrls = List<String>.from(decoded);
        }
      } catch (_) {
        // Not JSON, treat as regular remarks
      }
    }

    if (type == InventoryType.file) {
      return InventoryItem.file(
        id: map['id']?.toString() ?? '',
        clientName: map['client_name']?.toString() ?? '',
        referenceNo: map['reference_no']?.toString() ?? '',
        societyId: map['society_id']?.toString() ?? '',
        blockId: map['block_id']?.toString(),
        saleStatus: map['sale_status']?.toString() ?? 'Not Sold',
        remarks: extractedImageUrls.isEmpty ? remarks : '', // Use empty remarks if images exist
        cnic: map['cnic']?.toString(),
        companyId: map['company_id']?.toString() ?? '',
        updatedAt: DateTime.parse(map['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
        fileNo: map['file_no']?.toString(),
        mobileNo: map['mobile_no']?.toString(),
        path: map['path']?.toString(),
        imageUrls: extractedImageUrls,
      );
    } else {
      return InventoryItem.property(
        id: map['id']?.toString() ?? '',
        clientName: map['client_name']?.toString() ?? '',
        referenceNo: map['reference_no']?.toString() ?? '',
        societyId: map['society_id']?.toString() ?? '',
        blockId: map['block_id']?.toString(),
        saleStatus: map['sale_status']?.toString() ?? 'Not Sold',
        remarks: extractedImageUrls.isEmpty ? remarks : '', // Use empty remarks if images exist
        cnic: map['cnic']?.toString(),
        companyId: map['company_id']?.toString() ?? '',
        updatedAt: DateTime.parse(map['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
        propertyName: map['property_name']?.toString(),
        demand: int.tryParse(map['demand']?.toString() ?? '0'),
        price: int.tryParse(map['price']?.toString() ?? '0'),
        imageUrls: extractedImageUrls,
      );
    }
  }

  // Convert to database Map
  Map<String, dynamic> toMap() {
    final baseMap = {
      'id': id,
      'client_name': clientName,
      'reference_no': referenceNo,
      'society_id': societyId,
      'block_id': blockId,
      'sale_status': saleStatus,
      'cnic': cnic,
      'company_id': companyId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };

    // Handle remarks vs image URLs
    if (imageUrls.isNotEmpty) {
      baseMap['remarks'] = jsonEncode(imageUrls);
    } else {
      baseMap['remarks'] = remarks;
    }

    if (type == InventoryType.file) {
      return {
        ...baseMap,
        'file_no': fileNo,
        'mobile_no': mobileNo,
        'path': path,
        'name': clientName, // Required field for files_table
      };
    } else {
      return {
        ...baseMap,
        'property_name': propertyName,
        'demand': demand,
        'price': price,
      };
    }
  }

  // Copy with method for updates
  InventoryItem copyWith({
    String? id,
    InventoryType? type,
    String? clientName,
    String? referenceNo,
    String? societyId,
    String? blockId,
    String? saleStatus,
    String? remarks,
    String? cnic,
    String? companyId,
    DateTime? updatedAt,
    String? fileNo,
    String? mobileNo,
    String? path,
    String? propertyName,
    int? demand,
    int? price,
    List<String>? imageUrls,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      type: type ?? this.type,
      clientName: clientName ?? this.clientName,
      referenceNo: referenceNo ?? this.referenceNo,
      societyId: societyId ?? this.societyId,
      blockId: blockId ?? this.blockId,
      saleStatus: saleStatus ?? this.saleStatus,
      remarks: remarks ?? this.remarks,
      cnic: cnic ?? this.cnic,
      companyId: companyId ?? this.companyId,
      updatedAt: updatedAt ?? this.updatedAt,
      fileNo: fileNo ?? this.fileNo,
      mobileNo: mobileNo ?? this.mobileNo,
      path: path ?? this.path,
      propertyName: propertyName ?? this.propertyName,
      demand: demand ?? this.demand,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryItem &&
        other.id == id &&
        other.type == type &&
        other.clientName == clientName &&
        other.referenceNo == referenceNo &&
        other.societyId == societyId &&
        other.blockId == blockId &&
        other.saleStatus == saleStatus &&
        other.remarks == remarks &&
        other.cnic == cnic &&
        other.companyId == companyId &&
        other.updatedAt == updatedAt &&
        other.fileNo == fileNo &&
        other.mobileNo == mobileNo &&
        other.path == path &&
        other.propertyName == propertyName &&
        other.demand == demand &&
        other.price == price &&
        other.imageUrls.length == imageUrls.length;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      clientName,
      referenceNo,
      societyId,
      blockId,
      saleStatus,
      remarks,
      cnic,
      companyId,
      updatedAt,
      fileNo,
      mobileNo,
      path,
      propertyName,
      demand,
      price,
      imageUrls,
    );
  }
}
