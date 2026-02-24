// presentation/inventory/inventory_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../domain/models/inventory_item.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../core/services/app_storage.dart' show AppStorage;
import '../../core/services/auth_service.dart';
import '../../core/shared_utils.dart' show TopRightSearch;
import '../../core/services/permission_helper.dart' show PermissionHelper;
import 'package:shared/shared.dart' show RoleUtils;
import '../../core/app_utils.dart';
import 'inventory_view_model.dart';
import 'widgets/inventory_list.dart';
import 'widgets/inventory_form.dart';

class InventoryPage extends StatefulWidget {
  final dynamic db; // Using dynamic to avoid import issues with AppDatabase
  
  const InventoryPage({super.key, required this.db});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  InventoryViewModel? _viewModel;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (!mounted) return;
        final type = _tabController.index == 0 ? InventoryType.file : InventoryType.property;
        if (_viewModel != null && _viewModel!.initialized) {
          _viewModel!.setSelectedType(type);
        }
      }
    });
    _initializeViewModel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize view model if not already done
    if (_viewModel == null) {
      _initializeViewModel();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _initializeViewModel() async {
    final storage = AppStorage();
    final s = await storage.readSettings();
    final token = s['authToken'] as String?;
    if (token != null) {
      _currentUser = await AuthService().getCurrentUser(token);
    }
    
    final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
    final companyId = isSuper ? await _getFirstCompanyIdFromUtils(widget.db) : (RoleUtils.getUserCompanyId(_currentUser) ?? '');
    
    _viewModel = InventoryViewModel(
      InventoryRepositoryImpl(
        widget.db,
        companyId: companyId,
        isSuperAdmin: isSuper,
      ),
    );
    
    if (mounted) {
      setState(() {});
      _viewModel?.loadAllData();
    }
  }

  Future<String> _getFirstCompanyIdFromUtils(dynamic db) async {
    try {
      final result = await db.customSelect('SELECT id FROM companies WHERE is_active = 1 LIMIT 1').get();
      if (result.isNotEmpty) {
        return result.first.data['id'] as String;
      }
    } catch (e) {
      debugPrint('Error getting first company ID: $e');
    }
    // Fallback to a timestamp-based ID if no companies exist
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _showAddFormDialog({InventoryItem? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogBuilderContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogBuilderContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogBuilderContext).size.height * 0.9,
          ),
          child: Column(
            children: [
              // Header with back button
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(dialogBuilderContext).pop(),
                      style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Scrollable form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ChangeNotifierProvider.value(
      value: _viewModel!,
      child: InventoryForm(
        existing: existing,
        onSave: () { 
          Navigator.of(dialogBuilderContext).pop(); 
        },
      ),
    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safe build - check if view model is initialized
    if (_viewModel == null || !_viewModel!.initialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Filing System', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B35), // Orange
                  Color(0xFF4A90E2), // Blue
                ],
              ),
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _viewModel!,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Filing System', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B35), // Orange
                  Color(0xFF4A90E2), // Blue
                ],
              ),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Files'),
              Tab(text: 'Property'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: TopRightSearch(onChanged: (q) {
                _viewModel?.setSearchQuery(q);
              }),
            ),
          ],
        ),
        floatingActionButton: Consumer<InventoryViewModel>(
          builder: (context, viewModel, child) {
            return FloatingActionButton.extended(
              onPressed: () => _showAddFormDialog(),
              label: Text('Add ${viewModel.selectedType == InventoryType.file ? 'File' : 'Property'}'),
              icon: const Icon(Icons.add),
            );
          },
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange
                const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue
              ],
            ),
          ),
          child: const InventoryList(),
        ),
      ),
    );
  }
}
