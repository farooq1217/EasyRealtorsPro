import 'package:flutter/material.dart';
import '../models/trading_models.dart';

/// Trading page for property deal tracking
class TradingPage extends StatefulWidget {
  const TradingPage({super.key});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Trading'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B35),
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Deals'),
            Tab(text: 'Clients'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TradingDealsTab(),
          TradingClientsTab(),
          TradingAnalyticsTab(),
        ],
      ),
    );
  }
}

/// Deals tab for managing property deals
class TradingDealsTab extends StatelessWidget {
  const TradingDealsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.handshake,
            size: 64,
            color: Color(0xFF2C3E50),
          ),
          SizedBox(height: 16),
          Text(
            'Property Deals',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Track and manage property transactions',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clients tab for managing trading clients
class TradingClientsTab extends StatelessWidget {
  const TradingClientsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 64,
            color: Color(0xFF2C3E50),
          ),
          SizedBox(height: 16),
          Text(
            'Trading Clients',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage buyer and seller information',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Analytics tab for trading insights
class TradingAnalyticsTab extends StatelessWidget {
  const TradingAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 64,
            color: Color(0xFF2C3E50),
          ),
          SizedBox(height: 16),
          Text(
            'Trading Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Insights and performance metrics',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
