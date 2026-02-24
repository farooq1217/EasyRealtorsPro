// data/mappers/trading_mapper.dart
import '../../domain/models/trading_entry.dart';

class TradingMapper {
  // Database object ko Model mein badalna
  static TradingEntry fromMap(Map<String, dynamic> map) {
    return TradingEntry(
      id: map['id'],
      type: map['type'] == 'buy' ? TradingType.buy : TradingType.sell,
      entryType: map['entry_type'] == 'file' ? TradingEntryType.file : TradingEntryType.form,
      date: DateTime.parse(map['date']),
      personName: map['person_name'],
      mobile: map['mobile'],
      estateName: map['estate_name'],
      plotNo: map['plot_no'],
      quantity: map['quantity']?.toDouble() ?? 0.0,
      rate: map['rate']?.toDouble() ?? 0.0,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Pending',
      comments: map['comments'],
      commission: map['commission']?.toDouble() ?? 0.0,
      tax: map['tax']?.toDouble() ?? 0.0,
      netAmount: map['net_amount']?.toDouble() ?? 0.0,
    );
  }
}