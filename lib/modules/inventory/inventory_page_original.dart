import 'package:flutter/material.dart';
import '../../../core/font_utils.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared/shared.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../core/services/app_storage.dart' show AppStorage;
import '../../core/services/auth_service.dart';
import '../../shimmer_widgets.dart';
import '../../core/shared_utils.dart' show TopRightSearch, buildResponsiveInfoRow, InfoEntry;
import '../../core/app_utils.dart' show pickAndCompressImage, showImageSourceDialog, uploadImageToFirebaseStorage, imageUrlsToJson, jsonToImageUrls, fmtTs;
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk;
import '../../core/professional_pdf_generator.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math' show Random;
import '../../image_cache_service.dart' show CachedImageWidget;
import 'package:printing/printing.dart';
import '../../core/phone_actions.dart';

/// Get the first available company ID for super admin operations
Future<String> _getFirstCompanyId(AppDatabase db) async {
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

class FilesPage extends StatefulWidget {
  final AppDatabase db;
  const FilesPage({super.key, required this.db});
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  List<Map<String, String>> _societies = [];
  List<Map<String, String>> _blocks = [];
  Map<String, dynamic>? _currentUser;
  late TabController _tabController;
  String _selectedType = 'Files'; 
  String _q = '';
  String? _selectedStatusFilter; // null = All, 'Sold' = Sold, 'Not Sold' = Available
  String? _selectedSocietyId; // Selected society for filtering
  String? _selectedBlockId; // Selected block for filtering
  
  // Pagination variables
  int _currentPage = 1;
  int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (!mounted) return;
        setState(() {
          _selectedType = _tabController.index == 0 ? 'Files' : 'Property';
          _load();
        });
      }
    });
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final storage = AppStorage();
    final s = await storage.readSettings();
    final token = s['authToken'] as String?;
    if (token != null) _currentUser = await AuthService().getCurrentUser(token);
    await _loadSocietiesAndBlocks();
    await _load();
  }

  Future<void> _loadSocietiesAndBlocks() async {
    if (!mounted) return;
    final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
    // Use first available company for super admin, otherwise use the user's companyId
    final companyId = isSuper ? await _getFirstCompanyId(widget.db) : (RoleUtils.getUserCompanyId(_currentUser) ?? '');
    final soc = await widget.db.customSelect(
      isSuper
          ? 'SELECT id, name FROM societies WHERE is_active = 1'
          : 'SELECT id, name FROM societies WHERE company_id = ? AND is_active = 1',
      variables: isSuper ? [] : [d.Variable.withString(companyId)],
    ).get();
    final blks = await widget.db.customSelect(
      isSuper
          ? 'SELECT id, society_id, name FROM blocks WHERE is_active = 1'
          : 'SELECT id, society_id, name FROM blocks WHERE company_id = ? AND is_active = 1',
      variables: isSuper ? [] : [d.Variable.withString(companyId)],
    ).get();
    if (!mounted) return;
    setState(() {
      _societies = soc.map((r) => {'id': r.data['id'] as String, 'name': r.data['name'] as String}).toList();
      _blocks = blks.map((r) => {'id': r.data['id'] as String, 'society_id': r.data['society_id'] as String, 'name': r.data['name'] as String}).toList();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final table = _selectedType == 'Files' ? 'files_table' : 'properties';
    final clauses = <String>['is_active = 1'];
    final vars = <d.Variable<String>>[];
    if (!isSuper) {
      clauses.add('company_id = ?');
      vars.add(d.Variable.withString(companyId ?? ''));
    }
    final where = clauses.isNotEmpty ? 'WHERE ${clauses.join(' AND ')}' : '';
    final result = await widget.db
        .customSelect('SELECT * FROM $table $where ORDER BY updated_at DESC', variables: vars)
        .get();
    if (!mounted) return;
    setState(() { 
      _rows = result.map((r) => Map<String, dynamic>.from(r.data)).toList(); 
      _loading = false; 
    });
  }

  // Get filtered rows based on search query, status filter, society, and block
  List<Map<String, dynamic>> get _filteredRows {
    var filtered = _rows;
    
    // Apply society filter
    if (_selectedSocietyId != null) {
      filtered = filtered.where((row) {
        final societyId = row['society_id']?.toString();
        return societyId == _selectedSocietyId;
      }).toList();
    }
    
    // Apply block filter
    if (_selectedBlockId != null) {
      filtered = filtered.where((row) {
        final blockId = row['block_id']?.toString();
        return blockId == _selectedBlockId;
      }).toList();
    }
    
    // Apply status filter
    if (_selectedStatusFilter != null) {
      filtered = filtered.where((row) {
        final status = row['sale_status']?.toString() ?? 'Not Sold';
        return status == _selectedStatusFilter;
      }).toList();
    }
    
    // Apply search query
    if (_q.isNotEmpty) {
      final query = _q.toLowerCase();
      filtered = filtered.where((row) {
        final clientName = (row['client_name']?.toString() ?? '').toLowerCase();
        final referenceNo = (row['reference_no']?.toString() ?? '').toLowerCase();
        final fileNo = (row['file_no']?.toString() ?? '').toLowerCase();
        final mobileNo = (row['mobile_no']?.toString() ?? '').toLowerCase();
        final propertyName = (row['property_name']?.toString() ?? '').toLowerCase();
        return clientName.contains(query) ||
               referenceNo.contains(query) ||
               fileNo.contains(query) ||
               mobileNo.contains(query) ||
               propertyName.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  // Reset pagination when filters change
  void _resetPagination() {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
  }

  /// Exports inventory to PDF - All processing in isolate to prevent UI blocking
  Future<void> _exportToPdf(BuildContext context) async {
    try {
      if (_filteredRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items to export')),
        );
        return;
      }

      // Show immediate feedback dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Generating PDF...',
                  style: AppFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );

      // Pre-load ALL data BEFORE compute() to prevent blocking
      // Do this in parallel for better performance
      final preloadFutures = await Future.wait([
        _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf'),
        _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf'),
        loadCurrentUserFromStorage(),
      ]);

      final baseFontBytes = (preloadFutures[0] as Uint8List?) ?? Uint8List(0);
      final boldFontBytes = (preloadFutures[1] as Uint8List?) ?? Uint8List(0);
      final currentUser = preloadFutures[2] as Map<String, dynamic>?;

      // Load branding (database query - must be done before isolate)
      final branding = await loadReportBranding(db: widget.db, currentUser: currentUser);

      // Prepare data for isolate - convert to serializable format
      final rowsData = _filteredRows.map((item) => {
        'client_name': item['client_name']?.toString(),
        'reference_no': item['reference_no']?.toString(),
        'file_no': item['file_no']?.toString(),
        'path': item['path']?.toString(),
        'mobile_no': item['mobile_no']?.toString(),
        'property_name': item['property_name']?.toString(),
        'price': item['price']?.toString(),
        'demand': item['demand']?.toString(),
        'sale_status': item['sale_status']?.toString(),
        'updated_at': item['updated_at']?.toString(),
      }).toList();

      // Build fields in isolate
      final fields = await compute(_buildInventoryFieldsInIsolate, {
        'rows': rowsData,
        'selectedType': _selectedType,
        'generatedDate': DateTime.now().toIso8601String().split('T').first,
      });

      // Generate entire PDF using existing buildKeyValueReportPdf with pre-loaded data
      // This prevents blocking since fonts and branding are already loaded
      final pdfBytes = await buildKeyValueReportPdf(
        format: PdfPageFormat.a4,
        db: widget.db,
        currentUser: currentUser,
        module: 'inventory',
        entityId: null,
        title: '$_selectedType Inventory Report',
        action: 'download',
        fields: fields,
        preloadedBaseFontBytes: baseFontBytes,
        preloadedBoldFontBytes: boldFontBytes,
        preloadedBranding: branding,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Asynchronous file saving
        final fileName = 'inventory_${_selectedType.toLowerCase()}_${fmtTs(DateTime.now())}';
        await savePdfBytesToDisk(
          pdfBytes: pdfBytes,
          suggestedBaseName: fileName,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateProfessionalReceipt(BuildContext context) async {
    if (_filteredRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to include in receipt')));
      }
      return;
    }

    final today = DateTime.now();
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Type', _selectedType),
      MapEntry('Items', _filteredRows.length.toString()),
      MapEntry('Generated', today.toIso8601String().split('T').first),
    ];

    final gridRows = _filteredRows.take(50).map((item) {
      return {
        'Client': item['client_name']?.toString() ?? item['owner_name']?.toString() ?? '-',
        'File/Property': (item['file_no'] ?? item['property_name'] ?? item['reference_no'] ?? '-').toString(),
        'Price': (item['price'] ?? item['demand'] ?? '-').toString(),
        'Status': item['sale_status']?.toString() ?? '-',
      };
    }).toList();

    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: widget.db,
      module: 'Inventory',
      title: '$_selectedType Receipt',
      entityId: gridRows.first['File/Property'],
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }

  /// Helper to load font bytes
  Future<Uint8List?> _tryLoadRobotoBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Generate report serial number
  String _generateReportSerial({String prefix = 'RPT'}) {
    final now = DateTime.now().toUtc();
    final two = (int n) => n.toString().padLeft(2, '0');
    final base = '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}-${now.millisecond.toString().padLeft(3, '0')}';
    final rand = Random().nextInt(10000).toString().padLeft(4, '0');
    return '$prefix-$base-$rand';
  }


  /// Builds inventory fields in isolate to prevent UI blocking
  static List<MapEntry<String, String>> _buildInventoryFieldsInIsolate(Map<String, dynamic> args) {
    final rows = (args['rows'] as List).cast<Map<String, dynamic>>();
    final selectedType = args['selectedType'] as String;
    final generatedDate = args['generatedDate'] as String;
    
    final fields = <MapEntry<String, String>>[];
    
    // Add summary fields
    fields.add(MapEntry('Report Type', '$selectedType Inventory Report'));
    fields.add(MapEntry('Total Items', rows.length.toString()));
    fields.add(MapEntry('Generated', generatedDate));
    
    // Add each item as a section
    for (int i = 0; i < rows.length; i++) {
      final item = rows[i];
      fields.add(MapEntry('', '')); // Separator
      fields.add(MapEntry('Item ${i + 1}', ''));
      fields.add(MapEntry('Owner Name', item['client_name']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Reference No.', item['reference_no']?.toString() ?? 'N/A'));
      
      if (selectedType == 'Files') {
        if (item['file_no'] != null) {
          fields.add(MapEntry('File No.', item['file_no']?.toString() ?? 'N/A'));
        }
        fields.add(MapEntry('Size', item['path']?.toString() ?? 'N/A'));
        if (item['mobile_no'] != null) {
          fields.add(MapEntry('Mobile No.', item['mobile_no']?.toString() ?? 'N/A'));
        }
      } else {
        fields.add(MapEntry('Property Name', item['property_name']?.toString() ?? 'N/A'));
        fields.add(MapEntry('Price', item['price']?.toString() ?? 'N/A'));
        if (item['demand'] != null) {
          fields.add(MapEntry('Demand', item['demand']?.toString() ?? 'N/A'));
        }
      }
      
      fields.add(MapEntry('Status', item['sale_status']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Updated', item['updated_at']?.toString().split('T').first ?? 'N/A'));
    }
    
    return fields;
  }

  // AGENT WORKING SECTIONAL DIALOG
  void _showAddFormDialog({Map<String, dynamic>? existing}) {
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
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                children: [
                  // Header with back button
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(dialogContext).pop(),
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
                      child: _InventoryFormBody(
                        db: widget.db,
                        selectedType: _selectedType,
                        existing: existing,
                        societies: _societies,
                        blocks: _blocks,
                        currentUser: _currentUser,
                        onSave: () { 
                          Navigator.of(dialogContext).pop(); 
                          _load(); 
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Filing System', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Files'), Tab(text: 'Property')]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (q) {
              if (!mounted) return;
              setState(() => _q = q);
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFormDialog(),
        label: Text('Add $_selectedType'),
        icon: const Icon(Icons.add),
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
        child: Stack(
          children: [
            Column(
                children: [
                // Filter Chips Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1B1F24)
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300.withOpacity(0.7)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Available', 'Not Sold'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sold', 'Sold'),
                      // Clear Filters button - only show when any filter is active
                      if (_selectedSocietyId != null || _selectedBlockId != null || _selectedStatusFilter != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedSocietyId = null;
                              _selectedBlockId = null;
                              _selectedStatusFilter = null;
                            });
                            _resetPagination();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Clear Filters'),
                        ),
                    ],
                  ),
                ),
                // Society and Block Dropdowns
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1B1F24)
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300.withOpacity(0.7)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: _buildMainPageDropdown(
                            'Society',
                            _societies,
                            _selectedSocietyId,
                            (value) {
                              if (!mounted) return;
                              setState(() {
                                _selectedSocietyId = value;
                                _selectedBlockId = null; // Reset block when society changes
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: _buildMainPageDropdown(
                            'Block',
                            _selectedSocietyId != null
                                ? _blocks.where((b) => b['society_id'] == _selectedSocietyId).toList()
                                : [],
                            _selectedBlockId,
                            (value) {
                              if (!mounted) return;
                              setState(() {
                                _selectedBlockId = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // List View
                Expanded(
                  child: _filteredRows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No items found',
                                style: AppFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
                          itemCount: _filteredRows.length,
                          itemBuilder: (ctx, i) {
                            final r = _filteredRows[i];
                            return _buildInventoryCard(r);
                          },
                        ),
                ),
              ],
            ),
            // Sync indicator - show only when syncing
            if (false) // No sync state in inventory page, so always false
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper function to get color for Size field based on Marla value
  Color _getSizeColor(String size) {
    final sizeLower = size.toLowerCase();
    
    if (sizeLower.contains('2 marla')) {
      return const Color(0xFFD2B48C); // Light beige/tan
    } else if (sizeLower.contains('3 marla')) {
      return const Color(0xFFE6E6FA); // Light purple/lavender
    } else if (sizeLower.contains('5 marla')) {
      return const Color(0xFF90EE90); // Light green
    } else if (sizeLower.contains('8 marla')) {
      return const Color(0xFFFFB6C1); // Light pink
    } else {
      return const Color(0xFFFF6B35); // Orange - default color
    }
  }

  // Helper function to get style for Size field based on Marla value
  TextStyle _getSizeStyle(String size) {
    final sizeColor = _getSizeColor(size);
    
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: sizeColor,
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> r) {
    final ownerName = r['client_name']?.toString() ?? 'N/A';
    final size = _selectedType == 'Files' 
        ? (r['path']?.toString() ?? '')
        : (r['price']?.toString() ?? '');
    final status = r['sale_status']?.toString() ?? 'Not Sold';
    final statusTextColor = status == 'Sold' 
        ? Colors.red.shade700 
        : Colors.blue.shade700;
    
    final TextStyle infoStyle = TextStyle(
      fontSize: 14,
      color: const Color(0xFFFF6B35),
    );
    
    // Build title: owner name • size/category
    final title = size.isNotEmpty 
        ? '$ownerName • $size'
        : ownerName;
    
    final sizeValue = size.trim();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InventoryDetailPage(
                          data: r,
                          db: widget.db,
                          type: _selectedType,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text('Edit'),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _showAddFormDialog(existing: r),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          const Text('Delete'),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _deleteItem(r['id'] as String),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            buildResponsiveInfoRow(
              context,
              [
                InfoEntry('Owner Name', ownerName, style: infoStyle),
              ],
            ),
            // Size field with color coding
            if (sizeValue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Size: ',
                      style: infoStyle,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSizeColor(sizeValue).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getSizeColor(sizeValue),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        sizeValue,
                        style: _getSizeStyle(sizeValue),
                      ),
                    ),
                  ],
                ),
              ),
            buildResponsiveInfoRow(
              context,
              [
                InfoEntry('Status', status, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusTextColor,
                )),
              ],
            ),
            Text(
              'Updated: ${r['updated_at']?.toString().split('T').first ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final table = _selectedType == 'Files' ? 'files_table' : 'properties';
        await widget.db.customStatement(
          'UPDATE $table SET is_active = 0, updated_at = ? WHERE id = ?',
          [DateTime.now().toUtc().toIso8601String(), id],
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete item: $e')),
          );
        }
      }
    }
  }

  Widget _buildMainPageDropdown(
    String label,
    List<Map<String, String>> items,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    final hasItems = items.isNotEmpty;
    // Always show dropdown with placeholder, even when loading or empty
    final List<Map<String, String?>> displayItems = hasItems
        ? [
            {'id': null, 'name': 'All $label'}, // Add "All" option to clear filter
            ...items.map((item) => {'id': item['id'], 'name': item['name']}),
          ]
        : [{'id': null, 'name': 'Select $label'}];
    
    return DropdownButtonFormField<String?>(
      value: selectedValue,
      onChanged: hasItems ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select $label',
        prefixIcon: const Icon(Icons.list),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        filled: true,
        fillColor: Colors.white,
      ),
      items: displayItems.map((i) {
        final itemId = i['id'];
        final itemName = i['name'] ?? '';
        return DropdownMenuItem<String?>(
          value: itemId,
          child: Text(itemName),
          enabled: hasItems,
        );
      }).toList(),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedStatusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!mounted) return;
        setState(() {
          _selectedStatusFilter = selected ? value : null;
        });
      },
      selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4A90E2),
      labelStyle: AppFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300,
        width: isSelected ? 2 : 1,
      ),
    );
  }
}

class _InventoryFormBody extends StatefulWidget {
  final AppDatabase db;
  final String selectedType;
  final Map<String, dynamic>? existing;
  final List<Map<String, String>> societies;
  final List<Map<String, String>> blocks;
  final Map<String, dynamic>? currentUser;
  final VoidCallback onSave;

  const _InventoryFormBody({required this.db, required this.selectedType, this.existing, required this.societies, required this.blocks, this.currentUser, required this.onSave});

  @override
  State<_InventoryFormBody> createState() => _InventoryFormBodyState();
}

class _InventoryFormBodyState extends State<_InventoryFormBody> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController ownerCtl, fileNoCtl, plotNoCtl, contactCtl, cnicCtl, demandCtl, remarksCtl, sizeCtl;
  String? selSoc, selBlk, selStatus = 'Not Sold';
  List<String> _imageUrls = []; // Firebase Storage URLs
  List<Uint8List> _pendingImageBytes = []; // Images waiting to be uploaded
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    ownerCtl = TextEditingController(text: e?['client_name']?.toString());
    fileNoCtl = TextEditingController(text: e?['file_no']?.toString());
    plotNoCtl = TextEditingController(text: e?['reference_no']?.toString());
    contactCtl = TextEditingController(text: widget.selectedType == 'Files' ? (e?['mobile_no']?.toString() ?? '') : (e?['property_name']?.toString() ?? ''));
    cnicCtl = TextEditingController(text: e?['cnic']?.toString());
    demandCtl = TextEditingController(text: e?['demand']?.toString());
    remarksCtl = TextEditingController(text: e?['remarks']?.toString());
    sizeCtl = TextEditingController(text: widget.selectedType == 'Files' ? (e?['path']?.toString() ?? '') : (e?['price']?.toString() ?? ''));
    selSoc = e?['society_id'];
    selBlk = e?['block_id'];
    selStatus = e?['sale_status'] ?? 'Not Sold';
    // Load existing image URLs from remarks field (stored as JSON)
    final remarks = e?['remarks']?.toString() ?? '';
    if (remarks.isNotEmpty) {
      // Try to parse as JSON (image URLs)
      try {
        _imageUrls = jsonToImageUrls(remarks);
        // If it's valid JSON and not empty, use it; otherwise use as regular remarks
        if (_imageUrls.isNotEmpty) {
          remarksCtl = TextEditingController(); // Clear remarks if it's image URLs
        }
      } catch (e) {
        // Not JSON, treat as regular remarks
        _imageUrls = [];
      }
    }
  }

  Future<void> _pickAndAddImage() async {
    final source = await showImageSourceDialog(context);
    if (source == null) return;
    
    final result = await pickAndCompressImage(context, source);
    if (result != null && mounted) {
      setState(() {
        _pendingImageBytes.add(result['bytes'] as Uint8List);
      });
    }
  }

  void _removePendingImage(int index) {
    if (!mounted) return;
    setState(() {
      _pendingImageBytes.removeAt(index);
    });
  }

  void _removeImageUrl(int index) {
    if (!mounted) return;
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Widget _buildImageGallery() {
    final allImages = [
      ..._imageUrls.map((url) => {'type': 'url', 'url': url}),
      ..._pendingImageBytes.asMap().entries.map((e) => {'type': 'bytes', 'index': e.key, 'bytes': e.value}),
    ];

    if (allImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            itemBuilder: (ctx, i) {
              final item = allImages[i];
              final isUrl = item['type'] == 'url';
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isUrl
                          ? Image.network(
                              item['url'] as String,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                            )
                          : Image.memory(
                              item['bytes'] as Uint8List,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          if (isUrl) {
                            _removeImageUrl(i);
                          } else {
                            _removePendingImage(item['index'] as int);
                          }
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // AGENT WORKING STYLE SECTION HEADER
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFFFF6B35)),
        const SizedBox(width: 8),
        Text(title, style: AppFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing == null ? 'Add ${widget.selectedType} Form' : 'Edit ${widget.selectedType} Form', 
             style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        
        _buildSectionHeader('Location Details', Icons.map_outlined),
        _buildDropdown('Society', widget.societies, selSoc, (v) {
          if (!mounted) return;
          setState(() { selSoc = v; selBlk = null; });
        }),
        const SizedBox(height: 16),
        _buildDropdown('Block', widget.blocks.where((b) => b['society_id'] == selSoc).toList(), selBlk, (v) {
          if (!mounted) return;
          setState(() => selBlk = v);
        }),

        _buildSectionHeader('Property Information', Icons.home_work_outlined),
        Row(children: [
          Expanded(child: _buildField(plotNoCtl, 'Plot / Ref No.', icon: Icons.numbers)),
          const SizedBox(width: 16),
          Expanded(child: _buildField(sizeCtl, widget.selectedType == 'Files' ? 'Size' : 'Price (Rs)', icon: Icons.straighten)),
        ]),
        const SizedBox(height: 16),
        if (widget.selectedType == 'Files') _buildField(fileNoCtl, 'File No.', icon: Icons.file_copy_outlined),

        _buildSectionHeader('Client Information', Icons.person_outline),
        _buildField(ownerCtl, 'Owner Name', icon: Icons.person),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildField(contactCtl, 'Contact No.', icon: Icons.phone)),
          const SizedBox(width: 16),
          Expanded(child: _buildField(cnicCtl, 'CNIC', icon: Icons.badge_outlined)),
        ]),

        _buildSectionHeader('Status & Finance', Icons.account_balance_wallet_outlined),
        if (widget.selectedType == 'Property') ...[
          _buildField(demandCtl, 'Demand (Rs)', isNum: true, icon: Icons.money),
          const SizedBox(height: 16),
        ],
        _buildDropdown('Status', [{'id':'Sold','name':'Sold'}, {'id':'Not Sold','name':'Not Sold'}], selStatus, (v) {
          if (!mounted) return;
          setState(() => selStatus = v);
        }),

        _buildSectionHeader('Additional Info', Icons.notes),
        _buildField(remarksCtl, 'Remarks', maxLines: 2, icon: Icons.comment_outlined),
        
        _buildSectionHeader('Images', Icons.image_outlined),
        OutlinedButton.icon(
          onPressed: _pickAndAddImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Add Image'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        _buildImageGallery(),
        const SizedBox(height: 32),
        
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: _saveAction, 
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }

  Widget _buildField(TextEditingController ctl, String label, {bool isNum = false, int maxLines = 1, IconData? icon}) {
    return TextFormField(
      controller: ctl, keyboardType: isNum ? TextInputType.number : TextInputType.text, maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: icon != null ? Icon(icon) : null, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDropdown(String label, List<Map<String, String>> items, String? val, Function(String?) onChange) {
    final hasItems = items.isNotEmpty;
    final displayItems = hasItems 
        ? items 
        : [{'id': '__loading__', 'name': items.isEmpty ? 'No data found' : 'Loading...'}];
    
    return DropdownButtonFormField<String>(
      value: hasItems ? val : null,
      onChanged: hasItems ? onChange : null,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: const Icon(Icons.list), 
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        hintText: hasItems ? null : (items.isEmpty ? 'No data found' : 'Loading...'),
      ),
      items: displayItems.map((i) => DropdownMenuItem(
        value: i['id'],
        child: Text(i['name'] ?? ''),
        enabled: hasItems && i['id'] != '__loading__',
      )).toList(),
      validator: (v) => hasItems && v == null ? 'Required' : null,
    );
  }

  Future<void> _saveAction() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _uploadingImages = true);
    
    final id = widget.existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    final cid = RoleUtils.getUserCompanyId(widget.currentUser);
    
    try {
      // Upload pending images to Firebase Storage
      List<String> uploadedUrls = List.from(_imageUrls);
      for (final bytes in _pendingImageBytes) {
        final url = await uploadImageToFirebaseStorage(
          imageBytes: bytes,
          module: widget.selectedType.toLowerCase(),
          recordId: id,
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      }
      
      final imageUrlsJson = imageUrlsToJson(uploadedUrls);
      
      if (widget.selectedType == 'Files') {
        await widget.db.into(widget.db.filesTable).insertOnConflictUpdate(FilesTableCompanion(
          id: d.Value(id),
          name: d.Value(ownerCtl.text.trim()), // Required field
          clientName: d.Value(ownerCtl.text.trim()),
          fileNo: d.Value(fileNoCtl.text.trim()),
          referenceNo: d.Value(plotNoCtl.text.trim()),
          mobileNo: d.Value(contactCtl.text.trim()),
          societyId: d.Value(selSoc),
          blockId: d.Value(selBlk),
          saleStatus: d.Value(selStatus),
          path: d.Value(sizeCtl.text.trim()),
          remarks: d.Value(imageUrlsJson.isNotEmpty ? imageUrlsJson : remarksCtl.text.trim()),
          updatedAt: d.Value(DateTime.now().toUtc().toIso8601String()),
          companyId: d.Value(cid),
        ));
      } else {
        await widget.db.into(widget.db.properties).insertOnConflictUpdate(PropertiesCompanion(
          id: d.Value(id),
          clientName: d.Value(ownerCtl.text.trim()),
          referenceNo: d.Value(plotNoCtl.text.trim()),
          propertyName: d.Value(contactCtl.text.trim()),
          demand: d.Value(int.tryParse(demandCtl.text.trim()) ?? 0),
          price: d.Value(int.tryParse(sizeCtl.text.trim()) ?? 0),
          societyId: d.Value(selSoc),
          blockId: d.Value(selBlk),
          saleStatus: d.Value(selStatus),
          remarks: d.Value(imageUrlsJson.isNotEmpty ? imageUrlsJson : remarksCtl.text.trim()),
          updatedAt: d.Value(DateTime.now().toUtc().toIso8601String()),
          companyId: d.Value(cid),
        ));
      }
      
      if (!mounted) return;
      setState(() {
        _uploadingImages = false;
        _pendingImageBytes.clear();
      });
      
      widget.onSave();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImages = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// Detail View with Image Gallery
class InventoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppDatabase db;
  final String type;
  const InventoryDetailPage({super.key, required this.data, required this.db, required this.type});

  List<String> _getImageUrls() {
    final remarks = data['remarks']?.toString() ?? '';
    if (remarks.isEmpty) return [];
    // Try to parse as JSON (image URLs)
    try {
      return jsonToImageUrls(remarks);
    } catch (e) {
      return [];
    }
  }

  List<MapEntry<String, String>> _getAllFields() {
    final fields = <MapEntry<String, String>>[];
    
    if (type == 'Files') {
      fields.add(MapEntry('ID', data['id']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Owner Name', data['client_name']?.toString() ?? 'N/A'));
      fields.add(MapEntry('File No.', data['file_no']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Reference No.', data['reference_no']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Mobile No.', data['mobile_no']?.toString() ?? 'N/A'));
      fields.add(MapEntry('CNIC', data['cnic']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Size', data['path']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Sale Status', data['sale_status']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Society ID', data['society_id']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Block ID', data['block_id']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Demand', data['demand']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Updated At', data['updated_at']?.toString().split('T').first ?? 'N/A'));
      // Check if remarks is JSON (image URLs) or regular text
      final remarks = data['remarks']?.toString() ?? '';
      if (remarks.isNotEmpty) {
        try {
          final decoded = json.decode(remarks);
          if (decoded is List) {
            fields.add(MapEntry('Images', '${decoded.length} image(s)'));
          } else {
            fields.add(MapEntry('Remarks', remarks));
          }
        } catch (e) {
          fields.add(MapEntry('Remarks', remarks));
        }
      } else {
        fields.add(MapEntry('Remarks', 'N/A'));
      }
    } else {
      fields.add(MapEntry('ID', data['id']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Owner Name', data['client_name']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Property Name', data['property_name']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Reference No.', data['reference_no']?.toString() ?? 'N/A'));
      fields.add(MapEntry('File No.', data['file_no']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Price', data['price']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Demand', data['demand']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Sale Status', data['sale_status']?.toString() ?? 'N/A'));
      fields.add(MapEntry('CNIC', data['cnic']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Society ID', data['society_id']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Block ID', data['block_id']?.toString() ?? 'N/A'));
      fields.add(MapEntry('Updated At', data['updated_at']?.toString().split('T').first ?? 'N/A'));
      // Check if remarks is JSON (image URLs) or regular text
      final remarks = data['remarks']?.toString() ?? '';
      if (remarks.isNotEmpty) {
        try {
          final decoded = json.decode(remarks);
          if (decoded is List) {
            fields.add(MapEntry('Images', '${decoded.length} image(s)'));
          } else {
            fields.add(MapEntry('Remarks', remarks));
          }
        } catch (e) {
          fields.add(MapEntry('Remarks', remarks));
        }
      } else {
        fields.add(MapEntry('Remarks', 'N/A'));
      }
    }
    
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _getImageUrls();
    final allFields = _getAllFields();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${type} Details', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B35),
                Color(0xFF4A90E2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _generateProfessionalReceipt(context),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: const Text(
              'Generate Professional Receipt',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.03),
              const Color(0xFF4A90E2).withOpacity(0.03),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data Table
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${type} Details',
                        style: AppFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Use ListView.separated instead of Table.map() to prevent UI blocking
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            // Header row
                            Container(
                              decoration: BoxDecoration(color: Colors.grey.shade200),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Field',
                                      style: AppFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Value',
                                      style: AppFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Data rows using ListView.separated for better performance
                            SizedBox(
                              height: allFields.length * 50.0 < 400 ? allFields.length * 50.0 : 400,
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                itemCount: allFields.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
                                itemBuilder: (context, index) {
                                  final field = allFields[index];
                                  final isEven = index % 2 == 0;
                                  return Container(
                                    color: isEven ? Colors.white : Colors.grey.shade50,
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            field.key,
                                            style: AppFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: _linkify(context, field.key, field.value),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Image Gallery
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Images',
                          style: AppFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF6B35),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length,
                            itemBuilder: (ctx, i) {
                              return GestureDetector(
                                onTap: () => _showImageDialog(context, imageUrls[i]),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imageUrls[i],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(child: Icon(Icons.broken_image, size: 48)),
                                      ),
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: (loadingProgress.expectedTotalBytes != null && loadingProgress.expectedTotalBytes! > 0)
                                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _print(BuildContext context) async {
    final currentUser = await loadCurrentUserFromStorage();
    final entityId = data['id']?.toString();
    final title = '${type} Details';
    final fields = _getAllFields();

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildKeyValueReportPdf(
          format: a4Format,
          db: db,
          currentUser: currentUser,
          module: 'inventory',
          entityId: entityId,
          title: title,
          action: 'print',
          fields: fields,
          logHistory: false,
        );
      },
    );
  }

  Future<void> _downloadPdf() async {
    final currentUser = await loadCurrentUserFromStorage();
    final entityId = data['id']?.toString();
    final title = '${type} Details';
    final fields = _getAllFields();

    final bytes = await buildKeyValueReportPdf(
      format: PdfPageFormat.a4,
      db: db,
      currentUser: currentUser,
      module: 'inventory',
      entityId: entityId,
      title: title,
      action: 'download',
      fields: fields,
    );
    
    await savePdfBytesToDisk(
      pdfBytes: bytes,
      suggestedBaseName: 'inventory_${type.toLowerCase()}_${entityId ?? 'detail'}_${fmtTs(DateTime.now())}',
    );
  }

  Future<void> _generateProfessionalReceipt(BuildContext context) async {
    final entityId = data['id']?.toString();
    final title = '${type} Receipt';
    final keyValues = _getAllFields();
    final gridRows = <Map<String, String>>[
      {
        'Name': data['client_name']?.toString() ?? data['owner_name']?.toString() ?? '-',
        'Reference': (data['file_no'] ?? data['property_name'] ?? data['reference_no'] ?? '-').toString(),
        'Price': (data['price'] ?? data['demand'] ?? '-').toString(),
        'Status': data['sale_status']?.toString() ?? '-',
      },
    ];

    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: db,
      module: 'Inventory',
      title: title,
      entityId: entityId,
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }

  Widget _linkify(BuildContext context, String label, String value) {
    final isPhone = label.toLowerCase().contains('contact') || label.toLowerCase().contains('mobile');
    return GestureDetector(
      onTap: isPhone && value.trim().isNotEmpty ? () => showPhoneActionSheet(context, value) : null,
      child: Text(
        value,
        style: AppFonts.poppins(
          color: isPhone ? Colors.blue.shade700 : null,
          decoration: isPhone ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }
}