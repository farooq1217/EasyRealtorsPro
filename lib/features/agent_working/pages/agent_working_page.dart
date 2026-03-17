import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import '../../../widgets/stat_card.dart';
import '../../../core/font_utils.dart' show AppFonts;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../../core/services/auth_service.dart';
import '../../../shimmer_widgets.dart';
import '../../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;
import '../../../core/professional_pdf_generator.dart';
import '../../../widgets/performance_chart_card.dart';
import '../../../core/app_utils.dart';
import '../../../core/shared_utils.dart';
import '../../../core/services/firebase_threading_handler.dart';
import '../../../firestore_sync_service.dart';
import '../../../image_cache_service.dart';
import '../../../responsive_widgets.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../../core/shared_utils.dart' show TopRightSearch, showCustomTimePicker;
import '../../agents/view_models/agent_view_model.dart';
import '../../agents/repositories/agent_repository_impl.dart';
import 'agent_working_detail_page.dart';

class AgentWorkingPage extends StatefulWidget {
  final AppDatabase db;
  const AgentWorkingPage({super.key, required this.db});

  @override
  State<AgentWorkingPage> createState() => _AgentWorkingPageState();
}

class _WorkNote {
  final String id;
  final String text;
  final DateTime createdAt;
  const _WorkNote({required this.id, required this.text, required this.createdAt});
}

class _AgentWorkingPageState extends State<AgentWorkingPage> with SingleTickerProviderStateMixin {
  late AgentViewModel _viewModel;
  late TabController _tabController;
  final _transferFormKey = GlobalKey<FormState>();
  final _clientRequirementFormKey = GlobalKey<FormState>();
  final _officeNotesFormKey = GlobalKey<FormState>();
  final _otherNotesFormKey = GlobalKey<FormState>();
  
  // Stream subscriptions for real-time sync
  StreamSubscription<QuerySnapshot>? _officeNotesSub;
  StreamSubscription<QuerySnapshot>? _otherNotesSub;
  bool _officeNotesLoading = true;
  bool _otherNotesLoading = true;
  String? _officeNotesError;
  String? _otherNotesError;
  CollectionReference? _officeNotesRef;
  CollectionReference? _otherNotesRef;
  final List<_WorkNote> _officeNotes = [];
  final List<_WorkNote> _otherNotes = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize TabController
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (!mounted) return;
        final type = _tabController.index == 0 ? 'Transfer' : 'Client Requirements';
        _onTypeChanged(type);
      }
    });
    
    // Initialize view model with repository
    final isSuperAdmin = RoleUtils.isSuperAdmin(null) || PermissionHelper.isBypassUser(null);
    final companyId = RoleUtils.getUserCompanyId(null);
    final repository = AgentRepositoryImpl(widget.db, companyId: companyId, isSuperAdmin: isSuperAdmin);
    _viewModel = AgentViewModel(repository);
    
    // Initialize data
    _initData();
    _initNoteStreams();
  }

  Future<void> _initData() async {
    await _viewModel.initialize();
  }

  void _initNoteStreams() {
    try {
      final isWindows = !kIsWeb && io.Platform.isWindows;
      if (isWindows) {
        Future.microtask(() async {
          await _loadNotesOnce();
        });
        return;
      }
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        setState(() {
          _officeNotesError = 'Firebase not initialized';
          _otherNotesError = 'Firebase not initialized';
          _officeNotesLoading = false;
          _otherNotesLoading = false;
        });
        return;
      }
      final firestore = FirebaseFirestore.instance;
      _officeNotesRef = firestore.collection('agent_working').doc('office_notes').collection('notes');
      _otherNotesRef = firestore.collection('agent_working').doc('other_notes').collection('notes');
      
      _officeNotesSub = _officeNotesRef!
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) => Future.microtask(() => _handleNotesEvent(snapshot, isOffice: true)), onError: (error) {
        setState(() {
          _officeNotesError = error.toString();
          _officeNotesLoading = false;
        });
      });
      _otherNotesSub = _otherNotesRef!
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) => Future.microtask(() => _handleNotesEvent(snapshot, isOffice: false)), onError: (error) {
        setState(() {
          _otherNotesError = error.toString();
          _otherNotesLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        final msg = 'Failed to connect to Firebase: $e';
        _officeNotesError = msg;
        _otherNotesError = msg;
        _officeNotesLoading = false;
        _otherNotesLoading = false;
      });
    }
  }

  Future<void> _loadNotesOnce() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (!mounted) return;
        setState(() {
          _officeNotesError = 'Firebase not initialized';
          _otherNotesError = 'Firebase not initialized';
          _officeNotesLoading = false;
          _otherNotesLoading = false;
        });
        return;
      }

      // Wait briefly for auth to become available (Windows startup race)
      for (var i = 0; i < 10; i++) {
        if (!mounted) return;
        if (FirebaseAuth.instance.currentUser != null) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (FirebaseAuth.instance.currentUser == null) {
        if (!mounted) return;
        setState(() {
          _officeNotesError = 'Not authenticated';
          _otherNotesError = 'Not authenticated';
          _officeNotesLoading = false;
          _otherNotesLoading = false;
        });
        return;
      }
      try {
        // On Windows, avoid getIdToken() calls that can cause platform thread errors
        if (io.Platform.isWindows) {
          // Just ensure Firebase is initialized without refreshing token
          if (FirebaseAuth.instance.currentUser != null) {
            debugPrint('Windows: Skipping ID token refresh to avoid platform thread errors');
          }
        } else {
          // CRITICAL: Use thread-safe ID token refresh
          await FirebaseThreadingHandler.executeIdTokenRefreshWithThreadSafety();
        }
      } catch (_) {}

      final firestore = FirebaseFirestore.instance;
      _officeNotesRef = firestore.collection('agent_working').doc('office_notes').collection('notes');
      _otherNotesRef = firestore.collection('agent_working').doc('other_notes').collection('notes');

      final officeSnap = await _officeNotesRef!.orderBy('createdAt', descending: true).get();
      final otherSnap = await _otherNotesRef!.orderBy('createdAt', descending: true).get();

      if (!mounted) return;
      _handleNotesEvent(officeSnap, isOffice: true);
      _handleNotesEvent(otherSnap, isOffice: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = 'Failed to connect to Firebase: $e';
        _officeNotesError = msg;
        _otherNotesError = msg;
        _officeNotesLoading = false;
        _otherNotesLoading = false;
      });
    }
  }

  void _handleNotesEvent(QuerySnapshot snapshot, {required bool isOffice}) {
    final notes = _parseNotes(snapshot.docs);
    setState(() {
      if (isOffice) {
        _officeNotes
          ..clear()
          ..addAll(notes);
        _officeNotesLoading = false;
        _officeNotesError = null;
      } else {
        _otherNotes
          ..clear()
          ..addAll(notes);
        _otherNotesLoading = false;
        _otherNotesError = null;
      }
    });
  }

  List<_WorkNote> _parseNotes(List<QueryDocumentSnapshot> docs) {
    final notes = <_WorkNote>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final text = data['text']?.toString() ?? '';
      final createdAt = _decodeTimestamp(data['createdAt']);
      notes.add(_WorkNote(id: doc.id, text: text, createdAt: createdAt));
    }
    // Already sorted by orderBy('createdAt', descending: true)
    return notes;
  }

  DateTime _decodeTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _officeNotesSub?.cancel();
    _otherNotesSub?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  // Date/time pickers delegate to view model
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showCustomDatePicker(
      context,
      initialDate: _viewModel.selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _viewModel.setSelectedDate(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showCustomTimePicker(
      context,
      initialTime: _viewModel.selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      _viewModel.setSelectedTime(picked);
    }
  }

  Future<void> _pickRequirementDate() async {
    final now = DateTime.now();
    final picked = await showCustomDatePicker(
      context,
      initialDate: _viewModel.reqSelectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _viewModel.setReqSelectedDate(picked);
    }
  }

  Future<void> _pickRequirementTime() async {
    final picked = await showCustomTimePicker(
      context,
      initialTime: _viewModel.reqSelectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      _viewModel.setReqSelectedTime(picked);
    }
  }

  Future<void> _pickNextWorkingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.nextWorkingDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _viewModel.setNextWorkingDate(picked);
    }
  }

  Future<void> _pickReqNextWorkingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.reqNextWorkingDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _viewModel.setReqNextWorkingDate(picked);
    }
  }

  // Form submission delegates to view model
  Future<void> _submitTransfer({required String action, BuildContext? dialogContext}) async {
    print("Save button clicked. Validating form...");
    
    final success = await _viewModel.addTransfer();
    
    if (success && mounted) {
      // Close dialog immediately after successful save
      if (dialogContext != null) {
        Navigator.of(dialogContext).pop();
      }
      
      // Show success message with error handling to prevent accessibility crashes
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer added successfully!', style: AppFonts.poppins()),
            backgroundColor: const Color(0xFFFF6B35),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print("Warning: Could not show success message: $e");
      }
    } else if (_viewModel.error != null && mounted) {
      // Show error message with error handling
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_viewModel.error!), backgroundColor: Colors.red),
        );
      } catch (e) {
        print("Warning: Could not show error message: $e");
      }
    }
  }

  Future<void> _submitClientRequirement({required String action, BuildContext? dialogContext}) async {
    print("Save button clicked for client requirement. Validating form...");
    
    final success = await _viewModel.addClientRequirement();
    
    if (success && mounted) {
      // Close dialog immediately after successful save
      if (dialogContext != null) {
        Navigator.of(dialogContext).pop();
      }
      
      // Show success message with error handling to prevent accessibility crashes
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client requirement added successfully!', style: AppFonts.poppins()),
            backgroundColor: const Color(0xFFFF6B35),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print("Warning: Could not show success message: $e");
      }
    } else if (_viewModel.error != null && mounted) {
      // Show error message with error handling
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_viewModel.error!), backgroundColor: Colors.red),
        );
      } catch (e) {
        print("Warning: Could not show error message: $e");
      }
    }
  }

  // Notes submission delegates to view model
  Future<void> _submitOfficeNote() async {
    if (_officeNotesFormKey.currentState?.validate() ?? false) {
      final success = await _viewModel.addOfficeNote(text: _viewModel.commentsCtl.text.trim());
      if (success && mounted) {
        _viewModel.commentsCtl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Office note added successfully')),
        );
      }
    }
  }

  Future<void> _submitOtherNote() async {
    if (_otherNotesFormKey.currentState?.validate() ?? false) {
      final success = await _viewModel.addOtherNote(text: _viewModel.commentsCtl.text.trim());
      if (success && mounted) {
        _viewModel.commentsCtl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other note added successfully')),
        );
      }
    }
  }

  // Search functionality delegates to view model
  void _onSearchChanged(String query) {
    _viewModel.setSearchQuery(query);
  }

  void _clearSearch() {
    _viewModel.clearSearch();
  }

  // Type selection delegates to view model
  void _onTypeChanged(String type) {
    _viewModel.setSelectedType(type);
    
    // Refresh data when switching tabs to ensure filters are applied correctly
    if (type == 'Transfer') {
      _viewModel.loadTransfers();
    } else {
      _viewModel.loadClientRequirements();
    }
  }

  // Navigation to detail page
  void _navigateToDetail(WorkingProgressData entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgentWorkingDetailPage(
          entryData: _convertWorkingProgressToMap(entry),
          db: widget.db,
          onUpdate: () {
            // Refresh data when returning from detail page
            _viewModel.refresh();
          },
        ),
      ),
    );
  }

  // Helper to convert WorkingProgressData to Map for detail page
  Map<String, dynamic> _convertWorkingProgressToMap(WorkingProgressData data) {
    return {
      'id': data.id,
      'companyId': data.companyId,
      'name': data.name,
      'status': data.status,
      'remarks': data.remarks,
      'fromUser': data.fromUser,
      'toUser': data.toUser,
      'transferDate': data.transferDate,
      'nextWorkingDate': data.nextWorkingDate,
      'category': data.category,
      'isActive': data.isActive,
      'updatedAt': data.updatedAt,
      'isSynced': data.isSynced,
    };
  }

  // Receipt generation placeholder
  Future<void> _generateReceipt(WorkingProgressData entry) async {
    await _viewModel.generateProfessionalReceipt(entry.id);
    
    if (_viewModel.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error!)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt generation placeholder - to be implemented')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: Text('Agent Working', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
                indicatorColor: Colors.purple,
                indicatorWeight: 3,
                labelColor: Colors.purple,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                labelStyle: AppFonts.poppins(fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppFonts.poppins(fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Transfer'),
                  Tab(text: 'Client Requirements'),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: TopRightSearch(onChanged: _onSearchChanged),
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransferContent(),
                  _buildClientRequirementContent(),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showAddTransferDialog();
                } else {
                  _showAddClientRequirementDialog();
                }
              },
              label: Text('ADD'),
              icon: const Icon(Icons.add),
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransferContent() {
    // Filter transfers to only show entries with property categories (exact match with form dropdown)
    final propertyCategories = ['Residential', 'Commercial', 'Plot', 'other'];
    final filteredTransfers = _viewModel.transfers.where((entry) => 
      entry.category != null && 
      entry.category!.isNotEmpty && 
      propertyCategories.contains(entry.category)
    ).toList();
    
    return filteredTransfers.isEmpty
        ? _buildEmptyState('No transfers found')
        : _buildTransfersList(filteredTransfers);
  }

  Widget _buildClientRequirementContent() {
    // Filter client requirements to only show entries with source categories (exact match with form dropdown)
    final sourceCategories = ['Direct', 'Agent', 'Website', 'Social Media', 'Referral'];
    final filteredRequirements = _viewModel.clientRequirements.where((entry) => 
      entry.category != null && 
      entry.category!.isNotEmpty && 
      sourceCategories.contains(entry.category)
    ).toList();
    
    return filteredRequirements.isEmpty
        ? _buildEmptyState('No client requirements found')
        : _buildClientRequirementsList(filteredRequirements);
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransfersList(List<WorkingProgressData> transfers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _buildTransferCard(transfer);
      },
    );
  }

  Widget _buildClientRequirementsList(List<WorkingProgressData> requirements) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requirements.length,
      itemBuilder: (context, index) {
        final requirement = requirements[index];
        return _buildRequirementCard(requirement);
      },
    );
  }

  Widget _buildTransferCard(WorkingProgressData transfer) {
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
                    transfer.name,
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transfer.status ?? 'Pending'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    transfer.status ?? 'Pending',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (transfer.category != null && transfer.category!.isNotEmpty)
              _buildInfoRow('Category', transfer.category!),
            if (transfer.transferDate != null && transfer.transferDate!.isNotEmpty)
              _buildInfoRow('Date', transfer.transferDate!),
            if (transfer.nextWorkingDate != null && transfer.nextWorkingDate!.isNotEmpty)
              _buildInfoRow('Next Working Date', transfer.nextWorkingDate!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToDetail(transfer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'Action',
                      style: AppFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _generateReceipt(transfer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Icon(Icons.receipt_long, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementCard(WorkingProgressData requirement) {
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
                    requirement.name,
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(requirement.status ?? 'Pending'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    requirement.status ?? 'Pending',
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (requirement.category != null && requirement.category!.isNotEmpty)
              _buildInfoRow('Source', requirement.category!),
            if (requirement.transferDate != null && requirement.transferDate!.isNotEmpty)
              _buildInfoRow('Date', requirement.transferDate!),
            if (requirement.nextWorkingDate != null && requirement.nextWorkingDate!.isNotEmpty)
              _buildInfoRow('Next Working Date', requirement.nextWorkingDate!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToDetail(requirement),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'Action',
                      style: AppFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _generateReceipt(requirement),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Icon(Icons.receipt_long, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'closed':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.blue;
    }
  }

  void _showAddTransferDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2),
                    ),
                    const Spacer(),
                    Text(
                      'Add Transfer',
                      style: AppFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Clean form content - no tabs
              Expanded(
                child: _buildTransferForm(dialogContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddClientRequirementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2),
                    ),
                    const Spacer(),
                    Text(
                      'Add Client Requirement',
                      style: AppFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Clean form content - no tabs
              Expanded(
                child: _buildClientRequirementForm(dialogContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferForm(BuildContext dialogContext) {
    return Form(
      key: _transferFormKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Details Row
            _buildFormSection('Property Details', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField('Category *', _viewModel.transferCategory, [
                    'Residential',
                    'Commercial', 
                    'Plot',
                    'other'
                  ], Icons.home, (value) => _viewModel.setTransferCategory(value)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField('Size', _viewModel.transferSize, [
                    '5 Marla',
                    '10 Marla',
                    '1 Kanal',
                    '2 Kanal',
                    'other'
                  ], Icons.straighten, (value) => _viewModel.setTransferSize(value)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Plot No', _viewModel.plotCtl, Icons.tag),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Registry/Transfer Number', _viewModel.registryCtl, Icons.description),
                ),
              ],
            ),
            
            // Client Information Row
            _buildFormSection('Client Information', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Client Name', _viewModel.clientNameCtl, Icons.person),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Client Mobile No.', _viewModel.clientMobileCtl, Icons.phone),
                ),
              ],
            ),
            
            // Timeline & Follow-up Row
            _buildFormSection('Timeline & Follow-up', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateFieldWithIcon('Date *', _viewModel.dateCtl, _pickDate),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeFieldWithIcon('Time *', _viewModel.timeCtl, _pickTime),
                ),
              ],
            ),
            
            // Attachments & Notes Section
            _buildFormSection('Attachments & Notes', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ImageUploadWidget(
                    imagePaths: _viewModel.transferImages,
                    onImagesChanged: (images) => _viewModel.setTransferImages(images),
                    maxImages: 3,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildTextFieldWithIcon('Remarks', _viewModel.commentsCtl, Icons.edit, maxLines: 3),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Save Button - Fixed at bottom right
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 150,
                  child: ElevatedButton(
                    onPressed: () => _submitTransfer(action: 'save', dialogContext: dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _viewModel.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                          'Save Transfer',
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientRequirementForm(BuildContext dialogContext) {
    return Form(
      key: _clientRequirementFormKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Preferences Section
            _buildFormSection('Property Preferences', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField('Category', _viewModel.reqCategory, [
                    'Residential',
                    'Commercial', 
                    'Plot',
                    'other'
                  ], Icons.home, (value) => _viewModel.setReqCategory(value)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField('Preferred Size', _viewModel.reqSize, [
                    '5 Marla',
                    '10 Marla',
                    '1 Kanal',
                    '2 Kanal',
                    'other'
                  ], Icons.straighten, (value) => _viewModel.setReqSize(value)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField('Preferred Location/Society', _viewModel.reqLocation, [
                    'DHA',
                    'Bahria Town',
                    'LDA Avenue',
                    'Valencia',
                    'other'
                  ], Icons.location_on, (value) => _viewModel.setReqLocation(value)),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()), // Empty space for alignment
              ],
            ),
            
            // Client Information Section
            _buildFormSection('Client Information', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Client Name', _viewModel.reqClientNameCtl, Icons.person),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Client Mobile No', _viewModel.reqClientMobileCtl, Icons.phone),
                ),
              ],
            ),
            
            // Budget & Timeline Section
            _buildFormSection('Budget & Timeline', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Budget Min', _viewModel.reqBudgetMinCtl, Icons.money),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Budget Max', _viewModel.reqBudgetMaxCtl, Icons.money),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateFieldWithIcon('Date', _viewModel.reqDateCtl, _pickRequirementDate),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()), // Empty space for alignment
              ],
            ),
            
            // Attachments & Notes Section
            _buildFormSection('Attachments & Notes', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ImageUploadWidget(
                    imagePaths: _viewModel.requirementImages,
                    onImagesChanged: (images) => _viewModel.setRequirementImages(images),
                    maxImages: 3,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildTextFieldWithIcon('Remarks', _viewModel.reqCommentsCtl, Icons.edit, maxLines: 3),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Save Button - Fixed at bottom right
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    onPressed: () => _submitClientRequirement(action: 'save', dialogContext: dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _viewModel.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Save Requirement',
                            style: AppFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for form sections with headers
  Widget _buildFormSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
  
  // Helper widget for text fields with icons
  Widget _buildTextFieldWithIcon(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: Colors.white,
          ),
          style: AppFonts.poppins(fontSize: 12),
        ),
      ],
    );
  }
  
  // Helper widget for dropdown fields with icons
  Widget _buildDropdownField(String label, String? value, List<String> items, IconData icon, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: Colors.white,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: AppFonts.poppins(fontSize: 12)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
        // Show other field if 'other' is selected
        if (value == 'other' && (label.contains('Category') || label.contains('Size'))) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: label.contains('Category') ? _viewModel.transferOtherCategoryCtl : _viewModel.transferOtherSizeCtl,
            decoration: InputDecoration(
              labelText: label.contains('Category') ? 'Specify Category' : 'Specify Size',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: Colors.white,
            ),
            style: AppFonts.poppins(fontSize: 12),
          ),
        ],
      ],
    );
  }
  
  // Helper widget for date fields with icons
  Widget _buildDateFieldWithIcon(String label, TextEditingController controller, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'Select date' : controller.text,
                    style: AppFonts.poppins(
                      fontSize: 12,
                      color: controller.text.isEmpty ? Colors.grey.shade500 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Helper widget for time fields with icons

  Widget _buildTimeFieldWithIcon(String label, TextEditingController controller, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'Select time' : controller.text,
                    style: AppFonts.poppins(
                      fontSize: 14,
                      color: controller.text.isEmpty ? Colors.grey.shade500 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: AppFonts.poppins(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return _buildDropdownField('Category *', _viewModel.transferCategory, [
      'Residential',
      'Commercial',
      'Plot',
      'other'
    ], Icons.home, (value) => _viewModel.setTransferCategory(value));
  }

  Widget _buildSourceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Source',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _viewModel.requirementSource,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: 'Direct', child: Text('Direct')),
            DropdownMenuItem(value: 'Agent', child: Text('Agent')),
            DropdownMenuItem(value: 'Website', child: Text('Website')),
            DropdownMenuItem(value: 'Social Media', child: Text('Social Media')),
            DropdownMenuItem(value: 'Referral', child: Text('Referral')),
          ],
          onChanged: (value) {
            _viewModel.setRequirementSource(value);
          },
        ),
      ],
    );
  }
}
