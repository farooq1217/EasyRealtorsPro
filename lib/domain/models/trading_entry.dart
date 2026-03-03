// domain/models/trading_entry.dart

enum TradingType { buy, sell }
enum TradingEntryType { file, form }

class TradingEntry {
  final String id;
  final TradingType type; // Buy ya Sell
  final TradingEntryType entryType; // 'file' ya 'form'
  final DateTime date;
  final String personName;
  final String mobile;
  final String estateName;
  final String? plotNo; // Form entries mein plot number, file entries mein null
  final String? block; // Form entries mein block, file entries mein null
  final int quantity;
  final double? rate; // Form entries mein rate, file entries mein null
  final double? totalAmount; // Form entries mein total_amount, file entries mein null
  final double? commission; // Sirf form entries mein commission
  final double? tax; // Sirf form entries mein tax
  final double? netAmount; // Calculated field
  final String status;
  final String? comments;
  final String? companyId; // Company ID for role-based access
  final String? createdBy; // User ID who created this entry

  const TradingEntry({
    required this.id,
    required this.type,
    required this.entryType,
    required this.date,
    required this.personName,
    required this.mobile,
    required this.estateName,
    this.plotNo,
    this.block,
    required this.quantity,
    this.rate,
    this.totalAmount,
    this.commission,
    this.tax,
    this.netAmount,
    this.status = 'Pending',
    this.comments,
    this.companyId,
    this.createdBy,
  });

  // Data save karne ke liye Map mein convert karna (Duplication khatam karne ke liye)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId, // Will be set by repository
      'created_by': createdBy, // Will be set by repository
      'type': type == TradingType.buy ? 'buy' : 'sell',
      'entry_type': entryType == TradingEntryType.file ? 'file' : 'form',
      'date': date.toIso8601String(),
      'person_name': personName,
      'mobile': mobile,
      'estate_name': estateName,
      'plot_no': plotNo,
      'block': block,
      'quantity': quantity,
      'rate': rate,
      'total_amount': totalAmount,
      'status': status,
      'comments': comments,
      'commission': commission,
      'tax': tax,
      'net_amount': netAmount,
    };
  }
}