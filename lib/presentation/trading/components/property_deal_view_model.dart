import 'package:flutter/material.dart';
import '../models/trading_models.dart';

/// Property deal tracking view model
class PropertyDealViewModel extends ChangeNotifier {
  List<TradingDeal> _deals = [];
  List<TradingClient> _clients = [];
  bool _loading = false;
  String? _error;

  List<TradingDeal> get deals => List.unmodifiable(_deals);
  List<TradingClient> get clients => List.unmodifiable(_clients);
  bool get loading => _loading;
  String? get error => _error;

  /// Load all property deals
  Future<void> loadDeals() async {
    _setLoading(true);
    _error = null;
    
    try {
      // TODO: Implement actual data loading from database/repository
      // For now, using mock data
      _deals = [
        TradingDeal(
          id: '1',
          clientId: 'client1',
          propertyId: 'prop1',
          dealType: 'sale',
          dealAmount: 250000.0,
          dealDate: DateTime.now().subtract(const Duration(days: 5)),
          status: 'pending',
          metadata: {'commission': 2.5},
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          updatedAt: DateTime.now(),
        ),
        TradingDeal(
          id: '2',
          clientId: 'client2',
          propertyId: 'prop2',
          dealType: 'purchase',
          dealAmount: 180000.0,
          dealDate: DateTime.now().subtract(const Duration(days: 10)),
          status: 'completed',
          metadata: {'commission': 3.0},
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Load all trading clients
  Future<void> loadClients() async {
    _setLoading(true);
    _error = null;
    
    try {
      // TODO: Implement actual data loading from database/repository
      // For now, using mock data
      _clients = [
        TradingClient(
          id: 'client1',
          name: 'John Doe',
          phone: '+1234567890',
          email: 'john.doe@example.com',
          address: '123 Main St, City, State',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        TradingClient(
          id: 'client2',
          name: 'Jane Smith',
          phone: '+0987654321',
          email: 'jane.smith@example.com',
          address: '456 Oak Ave, Town, State',
          createdAt: DateTime.now().subtract(const Duration(days: 45)),
          updatedAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new property deal
  Future<void> addDeal(TradingDeal deal) async {
    try {
      // TODO: Implement actual database insertion
      _deals.add(deal);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Update an existing property deal
  Future<void> updateDeal(TradingDeal deal) async {
    try {
      // TODO: Implement actual database update
      final index = _deals.indexWhere((d) => d.id == deal.id);
      if (index != -1) {
        _deals[index] = deal;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a property deal
  Future<void> deleteDeal(String dealId) async {
    try {
      // TODO: Implement actual database deletion
      _deals.removeWhere((d) => d.id == dealId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a new trading client
  Future<void> addClient(TradingClient client) async {
    try {
      // TODO: Implement actual database insertion
      _clients.add(client);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Update an existing trading client
  Future<void> updateClient(TradingClient client) async {
    try {
      // TODO: Implement actual database update
      final index = _clients.indexWhere((c) => c.id == client.id);
      if (index != -1) {
        _clients[index] = client;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a trading client
  Future<void> deleteClient(String clientId) async {
    try {
      // TODO: Implement actual database deletion
      _clients.removeWhere((c) => c.id == clientId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get deals by status
  List<TradingDeal> getDealsByStatus(String status) {
    return _deals.where((deal) => deal.status == status).toList();
  }

  /// Get deals by type
  List<TradingDeal> getDealsByType(String type) {
    return _deals.where((deal) => deal.dealType == type).toList();
  }

  /// Calculate total deal amount
  double getTotalDealAmount({String? status, String? type}) {
    var filteredDeals = _deals;
    
    if (status != null) {
      filteredDeals = filteredDeals.where((deal) => deal.status == status).toList();
    }
    
    if (type != null) {
      filteredDeals = filteredDeals.where((deal) => deal.dealType == type).toList();
    }
    
    return filteredDeals.fold(0.0, (sum, deal) => sum + deal.dealAmount);
  }

  void _setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
