import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import '../../../features/agents/repositories/agent_repository_impl.dart' show AgentRepositoryImpl;
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
import '../../../core/role_utils.dart' as local;
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
import '../../../core/shared_utils.dart' show TopRightSearch, buildResponsiveInfoRow, InfoEntry, showCustomTimePicker;
import '../../../features/agents/view_models/agent_view_model.dart';

class AgentWorkingPageClean extends StatefulWidget {
  final AppDatabase db;
  const AgentWorkingPageClean({super.key, required this.db});

  @override
  State<AgentWorkingPageClean> createState() => _AgentWorkingPageCleanState();
}

class _AgentWorkingPageCleanState extends State<AgentWorkingPageClean> {
  late AgentViewModel _viewModel;
  final _transferFormKey = GlobalKey<FormState>();
  final _clientRequirementFormKey = GlobalKey<FormState>();
  final _officeNotesFormKey = GlobalKey<FormState>();
  final _otherNotesFormKey = GlobalKey<FormState>();
  bool _officeNotesLoading = true;
  bool _otherNotesLoading = true;
  String? _officeNotesError;
  String? _otherNotesError;
  CollectionReference? _officeNotesRef;
  CollectionReference? _otherNotesRef;
  StreamSubscription<QuerySnapshot>? _officeNotesSub;
  StreamSubscription<QuerySnapshot>? _otherNotesSub;

  @override
  void initState() {
    super.initState();
    final currentUser = AuthService.currentUser;
    final isSuperAdmin = local.RoleUtils.isSuperAdmin(currentUser) || PermissionHelper.isBypassUser(currentUser);
    final companyId = local.RoleUtils.getUserCompanyId(currentUser);
    
    _viewModel = AgentViewModel(
      AgentRepositoryImpl(
        widget.db,
        companyId: companyId,
        isSuperAdmin: isSuperAdmin,
      ),
    );
    
    _initNoteStreams();
    _viewModel.initialize();
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
        _viewModel.officeNotes.clear();
        _viewModel.officeNotes.addAll(notes);
        _officeNotesLoading = false;
        _officeNotesError = null;
      } else {
        _viewModel.otherNotes.clear();
        _viewModel.otherNotes.addAll(notes);
        _otherNotesLoading = false;
        _otherNotesError = null;
      }
    });
  }

  List<Map<String, dynamic>> _parseNotes(List<QueryDocumentSnapshot> docs) {
    final notes = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final text = data['text']?.toString() ?? '';
      final createdAt = _decodeTimestamp(data['createdAt']);
      notes.add({
        'id': doc.id,
        'text': text,
        'createdAt': createdAt,
      });
    }
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
    _officeNotesSub?.cancel();
    _otherNotesSub?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  // Date and time pickers (delegating to ViewModel)
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

  // Form submissions (delegating to ViewModel)
  Future<void> _submitTransfer({required String action, BuildContext? dialogContext}) async {
    final success = await _viewModel.addTransfer();
    if (success && mounted && dialogContext != null) {
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer added successfully'), backgroundColor: Colors.green),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error ?? 'Failed to add transfer'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitClientRequirement({required String action, BuildContext? dialogContext}) async {
    final success = await _viewModel.addClientRequirement();
    if (success && mounted && dialogContext != null) {
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client requirement added successfully'), backgroundColor: Colors.green),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error ?? 'Failed to add client requirement'), backgroundColor: Colors.red),
      );
    }
  }

  // Delete entry (keeping existing logic)
  Future<void> _deleteEntry(String id) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.db.customStatement('DELETE FROM working_progress WHERE id = ?', [id]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted'), backgroundColor: Colors.green),
        );
        // Reload data
        _viewModel.loadTransfers();
        _viewModel.loadClientRequirements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper methods (preserving existing UI logic)
  InputDecoration _fieldDecoration(String label, {IconData? icon, Widget? suffixIcon, String? hint, bool isRequired = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.purple.shade600, size: 20) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget fieldBox(Widget child, {int span = 1}) {
    return span > 1
        ? child
        : Container(
            constraints: const BoxConstraints(minHeight: 56),
            child: child,
          );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSizeColor(String size) {
    switch (size.toLowerCase()) {
      case '2 marla':
        return Colors.green;
      case '3 marla':
        return Colors.blue;
      case '5 marla':
        return Colors.orange;
      case '8 marla':
        return Colors.red;
      case '10 marla':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  TextStyle _getSizeStyle(String size) {
    final color = _getSizeColor(size);
    return TextStyle(
      fontWeight: FontWeight.bold,
      color: color,
      fontSize: 12,
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              'Agent Working',
              style: AppFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              TopRightSearch(
                hintText: 'Search by Owner Name or Category...',
                onChanged: _viewModel.setSearchQuery,
              ),
            ],
          ),
          body: Column(
            children: [
              // Tab selection
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _viewModel.setSelectedType('Transfer'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _viewModel.selectedType == 'Transfer' ? Colors.purple.shade600 : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Transfer',
                            textAlign: TextAlign.center,
                            style: AppFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _viewModel.selectedType == 'Transfer' ? Colors.white : Colors.purple.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _viewModel.setSelectedType('Client Requirements'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _viewModel.selectedType == 'Client Requirements' ? Colors.purple.shade600 : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Client Requirements',
                            textAlign: TextAlign.center,
                            style: AppFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _viewModel.selectedType == 'Client Requirements' ? Colors.white : Colors.purple.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEntryDialog(),
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_viewModel.loadingTransfers || _viewModel.loadingRequirements) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red.shade400, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _viewModel.error!,
              style: AppFonts.poppins(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_viewModel.selectedType == 'Transfer') {
                  _viewModel.loadTransfers();
                } else {
                  _viewModel.loadClientRequirements();
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final entries = _viewModel.filteredEntries;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _viewModel.selectedType == 'Transfer' ? Icons.swap_horiz : Icons.people,
              color: Colors.grey.shade400,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_viewModel.selectedType} entries found',
              style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first ${_viewModel.selectedType.toLowerCase()} entry',
              style: AppFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_viewModel.selectedType == 'Transfer') {
          await _viewModel.loadTransfers();
        } else {
          await _viewModel.loadClientRequirements();
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _buildEntryCard(entry);
        },
      ),
    );
  }

  Widget _buildEntryCard(WorkingProgressData entry) {
    final title = entry.name;
    final status = entry.status ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final infoStyle = AppFonts.poppins(fontSize: 14, color: Colors.grey.shade700);

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
                    // TODO: Implement detail page navigation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Detail page not implemented yet')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    if (PermissionHelper.canDeleteModule(_viewModel.currentUser, 'agent_working'))
                      PopupMenuItem(
                        child: const Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Delete')]),
                        onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _deleteEntry(entry.id)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            buildResponsiveInfoRow(
              context,
              [
                InfoEntry('Owner Name', entry.name, style: infoStyle),
              ],
            ),
            // Category field with color coding
            if (entry.category != null && entry.category!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Category: ',
                      style: infoStyle,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSizeColor(entry.category!).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getSizeColor(entry.category!),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        entry.category!,
                        style: _getSizeStyle(entry.category!),
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
                  color: statusColor,
                )),
              ],
            ),
            if (entry.transferDate != null)
              buildResponsiveInfoRow(
                context,
                [
                  InfoEntry('Date', entry.transferDate!, style: infoStyle),
                ],
              ),
            if (entry.remarks != null && entry.remarks!.isNotEmpty)
              buildResponsiveInfoRow(
                context,
                [
                  InfoEntry('Remarks', entry.remarks!, style: infoStyle),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAddEntryDialog() {
    if (_viewModel.selectedType == 'Transfer') {
      _showTransferDialog();
    } else {
      _showClientRequirementDialog();
    }
  }

  void _showTransferDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: StatefulBuilder(
            builder: (dialogContext, dialogSetState) {
              return Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                        const Spacer(),
                        Text(
                          'Add Transfer',
                          style: AppFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ),
                  
                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _transferFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Property Details
                            _buildSectionHeader('Property Details', Icons.home),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.plotCtl,
                                    decoration: _fieldDecoration('Plot Number'),
                                    maxLength: 50,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                                fieldBox(
                                  DropdownButtonFormField<String>(
                                    value: _viewModel.transferCategory,
                                    decoration: _fieldDecoration('Category'),
                                    items: const [
                                      DropdownMenuItem(value: '2 Marla', child: Text('2 Marla')),
                                      DropdownMenuItem(value: '3 Marla', child: Text('3 Marla')),
                                      DropdownMenuItem(value: '5 Marla', child: Text('5 Marla')),
                                      DropdownMenuItem(value: '8 Marla', child: Text('8 Marla')),
                                      DropdownMenuItem(value: '10 Marla', child: Text('10 Marla')),
                                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                                    ],
                                    onChanged: (value) {
                                      _viewModel.setTransferCategory(value);
                                    },
                                  ),
                                ),
                                if (_viewModel.transferCategory == 'Other')
                                  fieldBox(
                                    TextFormField(
                                      controller: _viewModel.transferOtherCategoryCtl,
                                      decoration: _fieldDecoration('Custom Category'),
                                      maxLength: 50,
                                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    ),
                                  ),
                              ],
                            ),

                            // Section 2: Client Information
                            _buildSectionHeader('Client Information', Icons.person),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.clientNameCtl,
                                    decoration: _fieldDecoration('Client Name'),
                                    maxLength: 100,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter client name';
                                      return null;
                                    },
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.clientMobileCtl,
                                    keyboardType: TextInputType.phone,
                                    decoration: _fieldDecoration('Client Mobile No.', hint: '03XX-XXXXXXX'),
                                    maxLength: 11,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                              ],
                            ),

                            // Section 3: Timeline & Follow-up
                            _buildSectionHeader('Timeline & Follow-up', Icons.schedule),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.dateCtl,
                                    readOnly: true,
                                    onTap: _pickDate,
                                    decoration: _fieldDecoration('Date', icon: Icons.calendar_today, suffixIcon: const Icon(Icons.calendar_today), isRequired: true),
                                    validator: (value) => value == null || value.isEmpty ? 'Select a date' : null,
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.timeCtl,
                                    readOnly: true,
                                    onTap: _pickTime,
                                    decoration: _fieldDecoration('Time', icon: Icons.schedule, suffixIcon: const Icon(Icons.schedule), isRequired: true),
                                    validator: (value) => value == null || value.isEmpty ? 'Select time' : null,
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.nextWorkingDateCtl,
                                    readOnly: true,
                                    onTap: _pickNextWorkingDate,
                                    decoration: _fieldDecoration('Next Working Date', suffixIcon: const Icon(Icons.calendar_today), hint: 'Select next working date for reminder'),
                                  ),
                                ),
                              ],
                            ),

                            // Section 4: Attachments & Notes
                            _buildSectionHeader('Attachments & Notes', Icons.attach_file),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  ImageUploadWidget(
                                    imagePaths: _viewModel.transferImages,
                                    onImagesChanged: (images) {
                                      _viewModel.setTransferImages(images);
                                    },
                                    maxImages: 3,
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.commentsCtl,
                                    decoration: _fieldDecoration('Remarks'),
                                    maxLines: 5,
                                    minLines: 3,
                                    maxLength: 200,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Footer buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PrimaryGradientButton(
                            text: 'Save Transfer',
                            onPressed: () => _submitTransfer(action: 'save', dialogContext: dialogContext),
                          ),
                        ),
                      ],
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

  void _showClientRequirementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: StatefulBuilder(
            builder: (dialogContext, dialogSetState) {
              return Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                        const Spacer(),
                        Text(
                          'Add Client Requirement',
                          style: AppFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ),
                  
                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _clientRequirementFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Requirement Details
                            _buildSectionHeader('Requirement Details', Icons.home),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqPlotCtl,
                                    decoration: _fieldDecoration('Plot Number'),
                                    maxLength: 50,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                                fieldBox(
                                  DropdownButtonFormField<String>(
                                    value: _viewModel.requirementSource,
                                    decoration: _fieldDecoration('Source'),
                                    items: const [
                                      DropdownMenuItem(value: 'Direct', child: Text('Direct')),
                                      DropdownMenuItem(value: 'Referral', child: Text('Referral')),
                                      DropdownMenuItem(value: 'Website', child: Text('Website')),
                                      DropdownMenuItem(value: 'Social Media', child: Text('Social Media')),
                                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                                    ],
                                    onChanged: (value) {
                                      _viewModel.setRequirementSource(value);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Section 2: Client Information
                            _buildSectionHeader('Client Information', Icons.person),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqClientNameCtl,
                                    decoration: _fieldDecoration('Client Name'),
                                    maxLength: 100,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter client name';
                                      return null;
                                    },
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqClientMobileCtl,
                                    keyboardType: TextInputType.phone,
                                    decoration: _fieldDecoration('Client Mobile No.', hint: '03XX-XXXXXXX'),
                                    maxLength: 11,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                              ],
                            ),

                            // Section 3: Timeline & Follow-up
                            _buildSectionHeader('Timeline & Follow-up', Icons.schedule),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqDateCtl,
                                    readOnly: true,
                                    onTap: _pickRequirementDate,
                                    decoration: _fieldDecoration('Date', icon: Icons.calendar_today, suffixIcon: const Icon(Icons.calendar_today), isRequired: true),
                                    validator: (value) => value == null || value.isEmpty ? 'Select a date' : null,
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqTimeCtl,
                                    readOnly: true,
                                    onTap: _pickRequirementTime,
                                    decoration: _fieldDecoration('Time', icon: Icons.schedule, suffixIcon: const Icon(Icons.schedule), isRequired: true),
                                    validator: (value) => value == null || value.isEmpty ? 'Select time' : null,
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqNextWorkingDateCtl,
                                    readOnly: true,
                                    onTap: _pickReqNextWorkingDate,
                                    decoration: _fieldDecoration('Next Working Date', suffixIcon: const Icon(Icons.calendar_today), hint: 'Select next working date for reminder'),
                                  ),
                                ),
                              ],
                            ),

                            // Section 4: Attachments & Notes
                            _buildSectionHeader('Attachments & Notes', Icons.attach_file),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                fieldBox(
                                  ImageUploadWidget(
                                    imagePaths: _viewModel.clientRequirementImages,
                                    onImagesChanged: (images) {
                                      _viewModel.setClientRequirementImages(images);
                                    },
                                    maxImages: 3,
                                  ),
                                ),
                                fieldBox(
                                  TextFormField(
                                    controller: _viewModel.reqCommentsCtl,
                                    decoration: _fieldDecoration('Remarks'),
                                    maxLines: 5,
                                    minLines: 3,
                                    maxLength: 200,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Footer buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PrimaryGradientButton(
                            text: 'Save Requirement',
                            onPressed: () => _submitClientRequirement(action: 'save', dialogContext: dialogContext),
                          ),
                        ),
                      ],
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
}
