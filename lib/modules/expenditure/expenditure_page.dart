import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

// Project imports
import '../../core/services/auth_service.dart';
import '../../core/models/expenditure_model.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart';
import '../../core/professional_pdf_generator.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;

class ExpenditurePage extends StatefulWidget {
  final AppDatabase db;
  const ExpenditurePage({super.key, required this.db});

  @override
  State<ExpenditurePage> createState() => _ExpenditurePageState();
}

class _ExpenditurePageState extends State<ExpenditurePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  Map<String, dynamic>? _user;
  
  // Data lists for two tabs
  List<Map<String, dynamic>> _officeExpenses = [];
  List<Map<String, dynamic>> _projectExpenses = [];
  List<Map<String, dynamic>> _filteredOfficeExpenses = [];
  List<Map<String, dynamic>> _filteredProjectExpenses = [];
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  
  // Form controllers for add expense dialog
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  
  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // Ensure expenditures table has proper columns
  Future<void> _ensureExpenditureTableColumns() async {
    try {
      // Check if table exists and has required columns
      final cols = await widget.db.customSelect('PRAGMA table_info(expenditures)').get();
      final columnNames = cols.map((r) => r.data['name']?.toString()).toList();
      
      // Add missing columns if needed
      if (!columnNames.contains('category_type')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN category_type TEXT');
      }
      if (!columnNames.contains('kind')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN kind TEXT');
      }
      if (!columnNames.contains('project_id')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN project_id TEXT');
      }
      if (!columnNames.contains('category_id')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN category_id TEXT');
      }
      if (!columnNames.contains('office_month')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN office_month TEXT');
      }
      if (!columnNames.contains('is_active')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN is_active INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('is_synced')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN is_synced INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('created_at')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN created_at TEXT');
      }
      if (!columnNames.contains('updated_at')) {
        await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN updated_at TEXT');
      }
    } catch (e) {
      debugPrint('Error ensuring expenditure table columns: $e');
    }
  }

  // Your latest setup logic
  Future<void> _setup() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final authService = AuthService();
        _user = await authService.getCurrentUser(authToken);
        AuthService.currentUser = _user;
      }
      await _ensureExpenditureTableColumns();
      await _refreshData();
    } catch (e) {
      debugPrint("Setup Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    final cId = RoleUtils.getUserCompanyId(_user);
    if (cId == null) return;

    // CRITICAL: Set loading state immediately to prevent "No data found" flash
    if (mounted) setState(() => _loading = true);

    try {
      // Fetching and splitting data into Office and Projects
      final rows = await widget.db.customSelect(
        'SELECT * FROM expenditures WHERE company_id = ? AND (is_active IS NULL OR is_active = 1) ORDER BY date DESC',
        variables: [d.Variable.withString(cId)],
      ).get();

      if (mounted) {
        setState(() {
          final allData = rows.map((r) => r.data).toList();
          // Filter by category_type for Office and Projects
          _officeExpenses = allData.where((e) => e['category_type'] == 'office').toList();
          _projectExpenses = allData.where((e) => e['category_type'] == 'project').toList();
          
          // If no category_type, show all as office expenses
          if (_officeExpenses.isEmpty && _projectExpenses.isEmpty) {
            _officeExpenses = allData;
          }
          
          // Apply search filter
          _applySearchFilter();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error refreshing expenditure data: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applySearchFilter() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (query.isEmpty) {
        _filteredOfficeExpenses = List.from(_officeExpenses);
        _filteredProjectExpenses = List.from(_projectExpenses);
      } else {
        _filteredOfficeExpenses = _officeExpenses.where((item) {
          final description = (item['description']?.toString() ?? '').toLowerCase();
          final amount = (item['amount']?.toString() ?? '').toLowerCase();
          final date = (item['date']?.toString() ?? '').toLowerCase();
          return description.contains(query) || amount.contains(query) || date.contains(query);
        }).toList();
        
        _filteredProjectExpenses = _projectExpenses.where((item) {
          final description = (item['description']?.toString() ?? '').toLowerCase();
          final amount = (item['amount']?.toString() ?? '').toLowerCase();
          final date = (item['date']?.toString() ?? '').toLowerCase();
          return description.contains(query) || amount.contains(query) || date.contains(query);
        }).toList();
      }
    });
  }

  bool get _canAdd => 
    PermissionHelper.getModulePermissionLevel(_user, 'expenditure').contains('add') || 
    RoleUtils.isCompanyAdmin(_user);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('Expenditures', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Office Expense", icon: Icon(Icons.business_center)),
            Tab(text: "Projects", icon: Icon(Icons.assignment)),
          ],
        ),
        actions: [
          // Professional Receipt Generation
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: _generateProfessionalReceipt,
            tooltip: 'Generate Professional Receipt',
          ),
          // Add button in AppBar
          if (_canAdd)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddDialog(_tabController.index == 0 ? "office" : "project"),
              tooltip: 'Add Expense',
            ),
          // Global Search
          TopRightSearch(
            onChanged: (query) {
              _searchController.text = query;
              _applySearchFilter();
            },
            hintText: 'Search expenses...',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListView(_filteredOfficeExpenses, "Office"),
          _buildListView(_filteredProjectExpenses, "Project"),
        ],
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list, String type) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == "Office" ? Icons.business_center : Icons.assignment,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No $type Records Found",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_canAdd)
              Text(
                "Tap the + button to add your first expense",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      );
    }

    // Calculate total amount
    final totalAmount = list.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item['amount']?.toString() ?? '0') ?? 0),
    );

    return Column(
      children: [
        // Total Amount Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total $type Expense:",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                f.format(totalAmount),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Expense List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "${i + 1}",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    item['description'] ?? 'No Description',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['date'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        f.format(amount),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red.shade600,
                        ),
                      ),
                      if (item['category'] != null)
                        Text(
                          item['category'],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  onLongPress: () => _handleDelete(item['id']),
                  onTap: () => _navigateToDetails(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Navigation to details page
  void _navigateToDetails(Map<String, dynamic> expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenditureDetailsPage(
          db: widget.db,
          expense: expense,
          user: _user,
        ),
      ),
    );
  }

  // --- CRUD Actions ---

  // Date picker method
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // Save expense method with validation
  Future<void> _saveExpense(String type) async {
    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();
    
    // Validation
    if (description.isEmpty) {
      _showErrorSnackBar('Please enter a description');
      return;
    }
    
    if (amountText.isEmpty) {
      _showErrorSnackBar('Please enter an amount');
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }
    
    if (_selectedDate == null) {
      _showErrorSnackBar('Please select a date');
      return;
    }
    
    try {
      final cId = RoleUtils.getUserCompanyId(_user);
      if (cId == null) {
        _showErrorSnackBar('Unable to determine company');
        return;
      }
      
      final expenseId = const Uuid().v4();
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // Insert into database
      await widget.db.customStatement(
        '''INSERT INTO expenditures 
           (id, date, description, amount, category_type, company_id, created_by, created_at, updated_at, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)''',
        [
          expenseId,
          formattedDate,
          description,
          amount,
          type, // 'office' or 'project'
          cId,
          _user?['id'] ?? _user?['userId'],
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
      
      Navigator.pop(context);
      _showSuccessSnackBar('$type expense added successfully');
      
      // CRITICAL: Set loading state immediately to prevent "No data found" flash
      if (mounted) setState(() => _loading = true);
      await _refreshData();
    } catch (e) {
      debugPrint('Error saving expense: $e');
      _showErrorSnackBar('Failed to save expense');
    }
  }

  // Helper methods for showing messages
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddDialog(String type) {
    // Clear previous values
    _descriptionController.clear();
    _amountController.clear();
    _dateController.clear();
    _selectedDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      type == "office" ? Icons.business_center : Icons.assignment,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Add $type Expense",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Date Field
              Text(
                "Date",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                              : 'Select Date',
                          style: GoogleFonts.poppins(
                            color: _selectedDate != null
                                ? Colors.black
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description Field
              Text(
                "Description",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter expense description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              
              // Amount Field
              Text(
                "Amount",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () => _saveExpense(type),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Save Expense",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDelete(dynamic id) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await widget.db.customStatement('UPDATE expenditures SET is_active = 0 WHERE id = ?', [id]);
      
      // CRITICAL: Set loading state immediately to prevent "No data found" flash
      if (mounted) setState(() => _loading = true);
      await _refreshData();
    }
  }

  // Professional Receipt Generation
  Future<void> _generateProfessionalReceipt() async {
    final currentList = _tabController.index == 0 ? _filteredOfficeExpenses : _filteredProjectExpenses;
    final title = _tabController.index == 0 ? "Office Expense Receipt" : "Project Expense Receipt";
    
    if (currentList.isEmpty) {
      _showErrorSnackBar('No expenses to generate receipt');
      return;
    }
    
    // Build key values for receipt header
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Report Type', title),
      MapEntry('Date Generated', DateFormat('dd MMM yyyy').format(DateTime.now())),
      MapEntry('Total Expenses', '${currentList.length}'),
      MapEntry('Generated By', _user?['username']?.toString() ?? 'N/A'),
    ];
    
    // Build grid rows for expense items
    final gridRows = currentList.map((expense) => {
      'Date': expense['date']?.toString() ?? 'N/A',
      'Description': expense['description']?.toString() ?? 'N/A',
      'Amount': f.format(expense['amount'] ?? 0),
      'Type': expense['category_type']?.toString() ?? 'N/A',
    }).toList();
    
    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: widget.db,
      module: 'Expenditure',
      title: title,
      entityId: 'EXP_${DateTime.now().millisecondsSinceEpoch}',
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }
}

// --- Expenditure Details Page ---

class ExpenditureDetailsPage extends StatefulWidget {
  final AppDatabase db;
  final Map<String, dynamic> expense;
  final Map<String, dynamic>? user;
  
  const ExpenditureDetailsPage({
    super.key,
    required this.db,
    required this.expense,
    this.user,
  });

  @override
  State<ExpenditureDetailsPage> createState() => _ExpenditureDetailsPageState();
}

class _ExpenditureDetailsPageState extends State<ExpenditureDetailsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _subItems = [];
  
  // Form controllers for adding sub-items
  final TextEditingController _itemDescriptionController = TextEditingController();
  final TextEditingController _itemAmountController = TextEditingController();
  
  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
  
  @override
  void initState() {
    super.initState();
    _setup();
  }
  
  @override
  void dispose() {
    _itemDescriptionController.dispose();
    _itemAmountController.dispose();
    super.dispose();
  }
  
  Future<void> _setup() async {
    await _ensureExpenditureItemsTable();
    await _loadSubItems();
    if (mounted) setState(() => _loading = false);
  }
  
  // Ensure expenditure_items table exists
  Future<void> _ensureExpenditureItemsTable() async {
    try {
      // Check if table exists and has required columns
      final cols = await widget.db.customSelect('PRAGMA table_info(expenditure_items)').get();
      final columnNames = cols.map((r) => r.data['name']?.toString()).toList();
      
      // Create table if it doesn't exist
      if (columnNames.isEmpty) {
        await widget.db.customStatement('''
          CREATE TABLE IF NOT EXISTS expenditure_items (
            id TEXT PRIMARY KEY,
            parent_id TEXT NOT NULL,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            company_id TEXT,
            created_by TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_active INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 1,
            FOREIGN KEY (parent_id) REFERENCES expenditures (id)
          )
        ''');
      } else {
        // Add missing columns if needed
        if (!columnNames.contains('parent_id')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN parent_id TEXT');
        }
        if (!columnNames.contains('company_id')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN company_id TEXT');
        }
        if (!columnNames.contains('created_by')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN created_by TEXT');
        }
        if (!columnNames.contains('created_at')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN created_at TEXT');
        }
        if (!columnNames.contains('updated_at')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN updated_at TEXT');
        }
        if (!columnNames.contains('is_active')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN is_active INTEGER DEFAULT 1');
        }
        if (!columnNames.contains('is_synced')) {
          await widget.db.customStatement('ALTER TABLE expenditure_items ADD COLUMN is_synced INTEGER DEFAULT 1');
        }
      }
    } catch (e) {
      debugPrint('Error ensuring expenditure_items table: $e');
    }
  }
  
  Future<void> _loadSubItems() async {
    try {
      final cId = RoleUtils.getUserCompanyId(widget.user);
      if (cId == null) return;
      
      final rows = await widget.db.customSelect(
        'SELECT * FROM expenditure_items WHERE parent_id = ? AND company_id = ? AND (is_active IS NULL OR is_active = 1) ORDER BY created_at DESC',
        variables: [d.Variable.withString(widget.expense['id']), d.Variable.withString(cId)],
      ).get();
      
      if (mounted) {
        setState(() {
          _subItems = rows.map((r) => r.data).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading sub items: $e');
    }
  }
  
  bool get _canAdd => 
    PermissionHelper.getModulePermissionLevel(widget.user, 'expenditure').contains('add') || 
    RoleUtils.isCompanyAdmin(widget.user);
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Expense Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final expenseAmount = double.tryParse(widget.expense['amount']?.toString() ?? '0') ?? 0;
    final subItemsTotal = _subItems.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item['amount']?.toString() ?? '0') ?? 0),
    );
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expense Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Professional Receipt Generation for individual expense
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: _generateProfessionalReceipt,
            tooltip: 'Generate Professional Receipt',
          ),
          // Add button for sub-items
          if (_canAdd)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddSubItemDialog,
              tooltip: 'Add Sub-Item',
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.expense['description'] ?? 'No Description',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.expense['date'] ?? '',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Main Amount',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          f.format(expenseAmount),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Sub-Items Total',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          f.format(subItemsTotal),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white30,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Expense',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      f.format(expenseAmount + subItemsTotal),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Sub-Items Section
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expense Breakdown',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_canAdd)
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: _showAddSubItemDialog,
                          tooltip: 'Add Sub-Item',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _subItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Sub-Items Found',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_canAdd)
                                Text(
                                  'Tap + to add breakdown items',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _subItems.length,
                          itemBuilder: (context, i) {
                            final item = _subItems[i];
                            final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "${i + 1}",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['description'] ?? 'No Description',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Text(
                                  f.format(amount),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                onLongPress: () => _handleDeleteSubItem(item['id']),
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
    );
  }
  
  void _showAddSubItemDialog() {
    _itemDescriptionController.clear();
    _itemAmountController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Add Sub-Item",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text(
                "Description",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _itemDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter sub-item description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              
              Text(
                "Amount",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _itemAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _saveSubItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Save Item",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _saveSubItem() async {
    final description = _itemDescriptionController.text.trim();
    final amountText = _itemAmountController.text.trim();
    
    if (description.isEmpty) {
      _showErrorSnackBar('Please enter a description');
      return;
    }
    
    if (amountText.isEmpty) {
      _showErrorSnackBar('Please enter an amount');
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }
    
    try {
      final cId = RoleUtils.getUserCompanyId(widget.user);
      if (cId == null) {
        _showErrorSnackBar('Unable to determine company');
        return;
      }
      
      final itemId = const Uuid().v4();
      
      await widget.db.customStatement(
        '''INSERT INTO expenditure_items 
           (id, parent_id, description, amount, company_id, created_by, created_at, updated_at, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)''',
        [
          itemId,
          widget.expense['id'],
          description,
          amount,
          cId,
          widget.user?['id'] ?? widget.user?['userId'],
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
      
      Navigator.pop(context);
      _showSuccessSnackBar('Sub-item added successfully');
      
      // CRITICAL: Set loading state immediately to prevent "No data found" flash
      if (mounted) setState(() => _loading = true);
      await _loadSubItems();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error saving sub-item: $e');
      _showErrorSnackBar('Failed to save sub-item');
    }
  }
  
  Future<void> _handleDeleteSubItem(dynamic id) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Sub-Item?"),
        content: const Text("Are you sure you want to delete this sub-item?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      await widget.db.customStatement('UPDATE expenditure_items SET is_active = 0 WHERE id = ?', [id]);
      
      // CRITICAL: Set loading state immediately to prevent "No data found" flash
      if (mounted) setState(() => _loading = true);
      await _loadSubItems();
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // Professional Receipt Generation for individual expense
  Future<void> _generateProfessionalReceipt() async {
    final expenseAmount = double.tryParse(widget.expense['amount']?.toString() ?? '0') ?? 0;
    final subItemsTotal = _subItems.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item['amount']?.toString() ?? '0') ?? 0),
    );
    
    // Build key values for receipt header
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Expense ID', widget.expense['id']?.toString() ?? 'N/A'),
      MapEntry('Description', widget.expense['description']?.toString() ?? 'N/A'),
      MapEntry('Date', widget.expense['date']?.toString() ?? 'N/A'),
      MapEntry('Type', widget.expense['category_type']?.toString() ?? 'N/A'),
      MapEntry('Main Amount', f.format(expenseAmount)),
      MapEntry('Sub-Items Count', '${_subItems.length}'),
      MapEntry('Sub-Items Total', f.format(subItemsTotal)),
      MapEntry('Total Expense', f.format(expenseAmount + subItemsTotal)),
      MapEntry('Generated By', widget.user?['username']?.toString() ?? 'N/A'),
    ];
    
    // Build grid rows for sub-items
    final gridRows = _subItems.map((subItem) => {
      'Description': subItem['description']?.toString() ?? 'N/A',
      'Amount': f.format(subItem['amount'] ?? 0),
      'Date Added': subItem['created_at']?.toString() ?? 'N/A',
    }).toList();
    
    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: widget.db,
      module: 'Expenditure',
      title: 'Expense Details Receipt',
      entityId: widget.expense['id']?.toString(),
      keyValues: keyValues,
      gridRows: gridRows,
    );
  }
}