// domain/models/trading_entry.dart

class TradingEntry {
  final String id;
  final String entryType; // HP, KP, MP, NMP, NNMP, BOP, SOP, AEMP
  final DateTime date;
  final String personName;
  final String mobileNo;
  final String estateName;
  final double quantity;
  final double unitPrice; // Unit price for calculation
  final String? imagePath;
  final String companyId;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // Status field for filtering

  const TradingEntry({
    required this.id,
    required this.entryType,
    required this.date,
    required this.personName,
    required this.mobileNo,
    required this.estateName,
    required this.quantity,
    required this.unitPrice,
    this.imagePath,
    required this.companyId,
    this.isActive = true,
    this.isSynced = true,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active', // Default status
  });

  // Getter for calculated total price
  double get totalPrice => quantity * unitPrice;

  // Data save karne ke liye Map mein convert karna
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_type': entryType,
      'date': date.toIso8601String(),
      'person_name': personName,
      'mobile_no': mobileNo,
      'estate_name': estateName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'image_path': imagePath,
      'company_id': companyId,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status, // Status field
    };
  }

  // Database se data read karne ke liye Map se TradingEntry banana
  factory TradingEntry.fromMap(Map<String, dynamic> map) {
    return TradingEntry(
      id: map['id']?.toString() ?? '',
      entryType: map['entry_type']?.toString() ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      personName: map['person_name']?.toString() ?? '',
      mobileNo: map['mobile_no']?.toString() ?? '',
      estateName: map['estate_name']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
      imagePath: map['image_path']?.toString(),
      companyId: map['company_id']?.toString() ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'active', // Status field
    );
  }
}