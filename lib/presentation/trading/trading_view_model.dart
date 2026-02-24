// presentation/trading/trading_view_model.dart
import 'package:flutter/foundation.dart';
import '../../domain/models/trading_entry.dart';
import '../../domain/repositories/trading_repository.dart';

class TradingViewModel extends ChangeNotifier {
  final TradingRepository _repository;
  List<TradingEntry> _entries = [];
  bool _isLoading = false;

  TradingViewModel(this._repository);

  List<TradingEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> loadEntries() async {
    notifyListeners(); // Notify at start
    
    // Only show loading if we don't have data yet
    // if (_entries.isEmpty) {
    //   _isLoading = true;
    //   notifyListeners();
    // }
    
    try {
      _entries = await _repository.getAllEntries();
    } catch (e) {
      debugPrint('Error loading trading entries: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify at end
    }
  }

  Future<void> saveEntry(TradingEntry entry) async {
    try {
      await _repository.addEntry(entry);
      await loadEntries(); // Reload data
    } catch (e) {
      debugPrint('Error saving trading entry: $e');
      rethrow; // Let UI handle error
    }
  }

  Future<void> deleteEntry(String id) async {
    // _isLoading = true;
    // notifyListeners();
    
    try {
      await _repository.deleteEntry(id);
      await loadEntries(); // Reload data
    } catch (e) {
      debugPrint('Error deleting trading entry: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}