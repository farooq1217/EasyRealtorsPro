import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/stat_card.dart';
import '../../../core/font_utils.dart' show AppFonts;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import '../../../core/role_utils.dart' as local;
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../../core/shared_utils.dart' show TopRightSearch, showCustomTimePicker;
import '../../../widgets/standardized_footer.dart' show StandardizedFooter;
import '../../agents/view_models/agent_view_model.dart';
import '../../agents/repositories/agent_repository_impl.dart';
import 'agent_working_detail_page.dart';
import '../../../core/utils/logger.dart';

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
  List<_WorkNote> _officeNotes = [];
  List<_WorkNote> _otherNotes = [];

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
        // Force UI update when tab changes
        setState(() {});
      }
    });
    
    // Initialize note streams
    _initNoteStreams();
  }

  Future<void> _initNoteStreams() async {
    // For now, initialize empty notes to avoid errors
    if (!mounted) return;
    setState(() {
      _officeNotesLoading = false;
      _otherNotesLoading = false;
    });
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    
    setState(() {
      _officeNotesLoading = true;
      _otherNotesLoading = true;
      _officeNotesError = null;
      _otherNotesError = null;
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
    super.dispose();
  }

  // Date/time pickers delegate to view model
  Future<void> _pickDate() async {
    FocusScope.of(context).requestFocus(FocusNode()); // Hide keyboard
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      final viewModel = context.read<AgentViewModel>();
      // CRITICAL FIX: Update ViewModel state first, then controller
      viewModel.setSelectedDate(date);
      // Controller is already updated in setSelectedDate method
      debugPrint('AgentWorkingPage: Date selected - $date, controller text: "${viewModel.dateCtl.text}"');
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && mounted) {
      final viewModel = context.read<AgentViewModel>();
      // CRITICAL FIX: Update ViewModel state first, then controller
      viewModel.setSelectedTime(time);
      // Controller is already updated in setSelectedTime method
      debugPrint('AgentWorkingPage: Time selected - $time, controller text: "${viewModel.timeCtl.text}"');
    }
  }

  Future<void> _pickNextWorkingDate() async {
    FocusScope.of(context).requestFocus(FocusNode()); // Hide keyboard
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      final viewModel = context.read<AgentViewModel>();
      // CRITICAL FIX: Update ViewModel state first, then controller
      viewModel.setNextWorkingDate(date);
      // Controller is already updated in setNextWorkingDate method
      debugPrint('AgentWorkingPage: Next working date selected - $date, controller text: "${viewModel.nextWorkingDateCtl.text}"');
    }
  }

  Future<void> _pickRequirementDate() async {
    FocusScope.of(context).requestFocus(FocusNode()); // Hide keyboard
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      final viewModel = context.read<AgentViewModel>();
      // CRITICAL FIX: Update ViewModel state first, then controller
      viewModel.setReqSelectedDate(date);
      // Controller is already updated in setReqSelectedDate method
      debugPrint('AgentWorkingPage: Requirement date selected - $date, controller text: "${viewModel.reqDateCtl.text}"');
    }
  }

  Future<void> _pickRequirementTime() async {
    final picked = await showCustomTimePicker(
      context,
      initialTime: context.read<AgentViewModel>().reqSelectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      context.read<AgentViewModel>().setReqSelectedTime(picked);
    }
  }


  Future<void> _pickReqNextWorkingDate() async {
    FocusScope.of(context).requestFocus(FocusNode()); // Hide keyboard
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: context.read<AgentViewModel>().reqNextWorkingDate ?? now,
      firstDate: now,
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      final viewModel = context.read<AgentViewModel>();
      // CRITICAL FIX: Update ViewModel state first, then controller
      viewModel.setReqNextWorkingDate(picked);
      // Controller is already updated in setReqNextWorkingDate method
      debugPrint('AgentWorkingPage: Req next working date selected - $picked, controller text: "${viewModel.reqNextWorkingDateCtl.text}"');
    }
  } 

  Future<void> _submitTransfer({required String action, BuildContext? dialogContext, Map<String, dynamic>? existingItem}) async {
    Logger.debug("Save button clicked. Validating form...");
    
    bool success;
    if (existingItem != null) {
      // It's an update. Pass the existing ID as String!
      final String itemId = existingItem['id'].toString();
      success = await context.read<AgentViewModel>().updateTransfer(itemId);
    } else {
      // It's a new entry.
      success = await context.read<AgentViewModel>().addTransfer();
    }
    
    if (success && mounted) {
      // Close dialog immediately after successful save
      if (dialogContext != null) {
        Navigator.of(dialogContext).pop();
      }
      
      // Show success message with error handling to prevent accessibility crashes
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingItem != null ? 'Transfer updated successfully!' : 'Transfer added successfully!', style: AppFonts.poppins()),
            backgroundColor: const Color(0xFFFF6B35),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        Logger.warning("Could not show success message: $e");
      }
    } else if (context.read<AgentViewModel>().error != null && mounted) {
      // Show error message with error handling
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AgentViewModel>().error!), backgroundColor: Colors.red),
        );
      } catch (e) {
        Logger.warning("Could not show error message: $e");
      }
    }
  }

  Future<void> _submitClientRequirement({required String action, BuildContext? dialogContext, Map<String, dynamic>? existingItem}) async {
    Logger.debug("Save button clicked for client requirement. Validating form...");
    
    bool success;
    if (existingItem != null) {
      // It's an update. Pass the existing ID as String!
      final String itemId = existingItem['id'].toString();
      success = await context.read<AgentViewModel>().updateClientRequirement(itemId);
    } else {
      // It's a new entry.
      success = await context.read<AgentViewModel>().addClientRequirement();
    }
    
    if (success && mounted) {
      // Close dialog immediately after successful save
      if (dialogContext != null) {
        Navigator.of(dialogContext).pop();
      }
      
      // Show success message with error handling to prevent accessibility crashes
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingItem != null ? 'Client requirement updated successfully!' : 'Client requirement added successfully!', style: AppFonts.poppins()),
            backgroundColor: const Color(0xFFFF6B35),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        Logger.warning("Could not show success message: $e");
      }
    } else if (context.read<AgentViewModel>().error != null && mounted) {
      // Show error message with error handling
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AgentViewModel>().error!), backgroundColor: Colors.red),
        );
      } catch (e) {
        Logger.warning("Could not show error message: $e");
      }
    }
  }

  // Notes submission delegates to view model
  Future<void> _submitOfficeNote() async {
    if (_officeNotesFormKey.currentState?.validate() ?? false) {
      final success = await context.read<AgentViewModel>().addOfficeNote(text: context.read<AgentViewModel>().commentsCtl.text.trim());
      if (success && mounted) {
        context.read<AgentViewModel>().commentsCtl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Office note added successfully')),
        );
      }
    }
  }

  Future<void> _submitOtherNote() async {
    if (_otherNotesFormKey.currentState?.validate() ?? false) {
      final success = await context.read<AgentViewModel>().addOtherNote(text: context.read<AgentViewModel>().commentsCtl.text.trim());
      if (success && mounted) {
        context.read<AgentViewModel>().commentsCtl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other note added successfully')),
        );
      }
    }
  }

  // Search functionality delegates to view model
  void _onSearchChanged(String query) {
    context.read<AgentViewModel>().setSearchQuery(query);
  }

  void _clearSearch() {
    context.read<AgentViewModel>().clearSearch();
  }

  // Type selection delegates to view model
  void _onTypeChanged(String type) {
    context.read<AgentViewModel>().setSelectedType(type);
    
    // Refresh data when switching tabs to ensure filters are applied correctly
    if (type == 'Transfer') {
      context.read<AgentViewModel>().loadTransfers();
    } else {
      context.read<AgentViewModel>().loadClientRequirements();
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
            context.read<AgentViewModel>().refresh();
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
    await context.read<AgentViewModel>().generateProfessionalReceipt(entry.id);
    
    if (context.read<AgentViewModel>().error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<AgentViewModel>().error!)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt generation placeholder - to be implemented')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AgentViewModel>(
      create: (context) {
        // Initialize view model with repository - Use default values for immediate creation
        final repository = AgentRepositoryImpl(widget.db, companyId: null, isSuperAdmin: false);
        final viewModel = AgentViewModel(repository);
        
        // Initialize data asynchronously with proper user context
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            // Get current user from AuthService to determine proper context
            final storage = AppStorage();
            final settings = await storage.readSettings();
            final authToken = settings['authToken'] as String?;
            Map<String, dynamic>? currentUser;
            if (authToken != null) {
              currentUser = await AuthService.getCurrentUser(authToken);
            }
            
            final isSuperAdmin = local.RoleUtils.isSuperAdmin(currentUser) || PermissionHelper.isBypassUser(currentUser);
            final companyId = local.RoleUtils.getUserCompanyId(currentUser);
            debugPrint('AgentWorkingPage: Initializing repository - isSuperAdmin: $isSuperAdmin, companyId: $companyId, user: ${currentUser?['email']}');
            
            // Update repository with proper context if needed (this would require repository to support context updates)
            await viewModel.initialize();
          } catch (e) {
            debugPrint('AgentWorkingPage: Error during async initialization: $e');
          }
        });
        
        return viewModel;
      },
      child: Consumer<AgentViewModel>(
        builder: (context, viewModel, child) {
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
                labelStyle: AppFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                ),
                unselectedLabelStyle: AppFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                ),
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
              child: Column(
                children: [
                  // This is the ONLY Expanded widget. It pushes pagination to the bottom.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _tabController.index == 0 
                          ? _buildTransferContent() 
                          : _buildClientRequirementContent(),
                    ),
                  ),
                  // Standardized Footer with pagination and add button
                  Consumer<AgentViewModel>(
                    builder: (context, viewModel, child) {
                      return StandardizedFooter(
                        currentPage: viewModel.currentPage,
                        totalItems: _tabController.index == 0 
                          ? viewModel.transfers.length 
                          : viewModel.clientRequirements.length,
                        itemsPerPage: viewModel.itemsPerPage,
                        onPageChanged: (page) => viewModel.setPage(page),
                        onItemsPerPageChanged: (itemsPerPage) => viewModel.setItemsPerPage(itemsPerPage),
                        addButtonLabel: _tabController.index == 0 ? 'Add Transfer' : 'Add Requirement',
                        onAddPressed: () {
                          if (_tabController.index == 0) {
                            _showAddTransferDialog();
                          } else {
                            _showAddClientRequirementDialog();
                          }
                        },
                        showAddButton: true,
                        addButtonColor: const Color(0xFFFF6B35),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildTransferContent() {
    return Consumer<AgentViewModel>(
      builder: (context, viewModel, child) {
        // Filter transfers to only show entries with property categories (exact match with form dropdown)
        final propertyCategories = ['Residential', 'Commercial', 'Plot', 'other'];
        final filteredTransfers = viewModel.transfers.where((entry) => 
          entry.category != null && 
          entry.category!.isNotEmpty && 
          propertyCategories.contains(entry.category)
        ).toList();
        
        return filteredTransfers.isEmpty
            ? _buildEmptyState('No transfers found')
            : _buildTransfersList(filteredTransfers);
      },
    );
  }

  Widget _buildClientRequirementContent() {
    return Consumer<AgentViewModel>(
      builder: (context, viewModel, child) {
        // Filter client requirements to only show entries with source categories (exact match with form dropdown)
        final sourceCategories = ['Direct', 'Agent', 'Website', 'Social Media', 'Referral'];
        final filteredRequirements = viewModel.clientRequirements.where((entry) => 
          entry.category != null && 
          entry.category!.isNotEmpty && 
          sourceCategories.contains(entry.category)
        ).toList();
        
        return filteredRequirements.isEmpty
            ? _buildEmptyState('No client requirements found')
            : _buildClientRequirementsList(filteredRequirements);
      },
    );
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
    return Consumer<AgentViewModel>(
      builder: (context, viewModel, child) {
        final paginatedTransfers = viewModel.paginatedData;
        final propertyCategories = ['Residential', 'Commercial', 'Plot', 'other'];
        final filteredPaginatedTransfers = paginatedTransfers.where((entry) => 
          entry.category != null && 
          entry.category!.isNotEmpty && 
          propertyCategories.contains(entry.category)
        ).toList();
        
        return filteredPaginatedTransfers.isEmpty
            ? _buildEmptyState('No transfers found')
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: filteredPaginatedTransfers.length,
                itemBuilder: (context, index) {
                  final transfer = filteredPaginatedTransfers[index];
                  return _buildTransferCard(transfer);
                },
              );
      },
    );
  }

  Widget _buildClientRequirementsList(List<WorkingProgressData> requirements) {
    return Consumer<AgentViewModel>(
      builder: (context, viewModel, child) {
        final paginatedRequirements = viewModel.paginatedData;
        final sourceCategories = ['Direct', 'Agent', 'Website', 'Social Media', 'Referral'];
        final filteredPaginatedRequirements = paginatedRequirements.where((entry) => 
          entry.category != null && 
          entry.category!.isNotEmpty && 
          sourceCategories.contains(entry.category)
        ).toList();
        
        return filteredPaginatedRequirements.isEmpty
            ? _buildEmptyState('No client requirements found')
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: filteredPaginatedRequirements.length,
                itemBuilder: (context, index) {
                  final requirement = filteredPaginatedRequirements[index];
                  return _buildRequirementCard(requirement);
                },
              );
      },
    );
  }

  Widget _buildTransferCard(WorkingProgressData transfer) {
    return InkWell(
      onTap: () => _showDetails(context, transfer, true),
      borderRadius: BorderRadius.circular(12),
      child: Card(
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editItem(transfer, true);
                      } else if (value == 'delete') {
                        final String targetId = transfer.id.toString();
                        await _deleteItem(targetId, true);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (transfer.category != null && transfer.category!.isNotEmpty)
                _buildSimpleInfoRow('Category', transfer.category!),
              if (transfer.transferDate != null && transfer.transferDate!.isNotEmpty)
                _buildSimpleInfoRow('Date', transfer.transferDate!),
              if (transfer.nextWorkingDate != null && transfer.nextWorkingDate!.isNotEmpty)
                _buildSimpleInfoRow('Next Working Date', transfer.nextWorkingDate!),
              if (transfer.fromUser != null && transfer.fromUser!.isNotEmpty)
                _buildSimpleInfoRow('From User', transfer.fromUser!),
              if (transfer.toUser != null && transfer.toUser!.isNotEmpty)
                _buildSimpleInfoRow('To User', transfer.toUser!),
              Text(
                'Updated: ${transfer.updatedAt?.toString().split('T').first ?? 'N/A'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementCard(WorkingProgressData requirement) {
    return InkWell(
      onTap: () => _showDetails(context, requirement, false),
      borderRadius: BorderRadius.circular(12),
      child: Card(
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editItem(requirement, false);
                      } else if (value == 'delete') {
                        final String targetId = requirement.id.toString();
                        await _deleteItem(targetId, false);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (requirement.category != null && requirement.category!.isNotEmpty)
                _buildSimpleInfoRow('Source', requirement.category!),
              if (requirement.transferDate != null && requirement.transferDate!.isNotEmpty)
                _buildSimpleInfoRow('Date', requirement.transferDate!),
              if (requirement.nextWorkingDate != null && requirement.nextWorkingDate!.isNotEmpty)
                _buildSimpleInfoRow('Next Working Date', requirement.nextWorkingDate!),
              if (requirement.fromUser != null && requirement.fromUser!.isNotEmpty)
                _buildSimpleInfoRow('From User', requirement.fromUser!),
              if (requirement.toUser != null && requirement.toUser!.isNotEmpty)
                _buildSimpleInfoRow('To User', requirement.toUser!),
              Text(
                'Updated: ${requirement.updatedAt?.toString().split('T').first ?? 'N/A'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: AppFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFFF6B35),
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
      builder: (dialogContext) => ChangeNotifierProvider<AgentViewModel>.value(
        value: Provider.of<AgentViewModel>(context, listen: false),
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
              ),
              child: Column(
                children: [
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
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildTransferForm(dialogContext, setDialogState: setDialogState, existingItem: null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddClientRequirementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<AgentViewModel>.value(
        value: Provider.of<AgentViewModel>(context, listen: false),
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
              ),
              child: Column(
                children: [
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
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildClientRequirementForm(dialogContext, setDialogState: setDialogState, existingItem: null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Form initialization methods
  void _initializeTransferForm(Map<String, dynamic>? existingItem) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgentViewModel>().clearTransferForm();
      if (existingItem != null) {
        // Populate form with existing data
        if (existingItem['name'] != null) {
          context.read<AgentViewModel>().clientNameCtl.text = existingItem['name'];
        }
        
        if (existingItem['transfer_date'] != null) {
          try {
            final date = DateTime.parse(existingItem['transfer_date']);
            final viewModel = context.read<AgentViewModel>();
            viewModel.setSelectedDate(date);
            // Controller is already updated in setSelectedDate method
          } catch (e) {
            debugPrint('Error parsing transfer date: $e');
          }
        }
        
        if (existingItem['category'] != null) {
          context.read<AgentViewModel>().setTransferCategory(existingItem['category']);
        }
        
        if (existingItem['remarks'] != null) {
          context.read<AgentViewModel>().commentsCtl.text = existingItem['remarks'];
        }
        
        // Note: plot_no, registry_number, size, client_mobile are not available in WorkingProgressData
        // They would need to be fetched separately from the database if needed
      }
    });
  }

  void _initializeClientRequirementForm(Map<String, dynamic>? existingItem) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgentViewModel>().clearRequirementForm();
      if (existingItem != null) {
        // Populate form with existing data
        if (existingItem['name'] != null) {
          context.read<AgentViewModel>().reqClientNameCtl.text = existingItem['name'];
        }
        
        if (existingItem['transfer_date'] != null) {
          try {
            final date = DateTime.parse(existingItem['transfer_date']);
            final viewModel = context.read<AgentViewModel>();
            viewModel.setReqSelectedDate(date);
            // Controller is already updated in setReqSelectedDate method
          } catch (e) {
            debugPrint('Error parsing requirement date: $e');
          }
        }
        
        if (existingItem['source'] != null) {
          context.read<AgentViewModel>().setRequirementSource(existingItem['source']);
        }
        
        if (existingItem['remarks'] != null) {
          context.read<AgentViewModel>().reqCommentsCtl.text = existingItem['remarks'];
        }
        
        if (existingItem['next_working_date'] != null) {
          try {
            final date = DateTime.parse(existingItem['next_working_date']);
            final viewModel = context.read<AgentViewModel>();
            viewModel.setReqNextWorkingDate(date);
            // Controller is already updated in setReqNextWorkingDate method
          } catch (e) {
            debugPrint('Error parsing next working date: $e');
          }
        }
      }
    });
  }

  Widget _buildTransferForm(BuildContext dialogContext, {StateSetter? setDialogState, final Map<String, dynamic>? existingItem}) {
    // Initialize form data if existingItem is provided
    if (existingItem != null) {
      _initializeTransferForm(existingItem);
    }
    
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
                  child: _buildDropdownField('Category', context.read<AgentViewModel>().transferCategory, [
                    'Residential',
                    'Commercial', 
                    'Plot',
                    'other'
                  ], Icons.home, (value) {
                      context.read<AgentViewModel>().setTransferCategory(value);
                      if (setDialogState != null) setDialogState(() {});
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField('Size', context.read<AgentViewModel>().transferSize, [
                    '5 Marla',
                    '10 Marla',
                    '1 Kanal',
                    '2 Kanal',
                    'other'
                  ], Icons.straighten, (value) {
                      context.read<AgentViewModel>().setTransferSize(value);
                      if (setDialogState != null) setDialogState(() {});
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Consumer<AgentViewModel>(
                    builder: (context, viewModel, child) {
                      return _buildDateFieldWithIcon('Date *', viewModel.dateCtl, () async {
                          await _pickDate();
                          if (setDialogState != null) setDialogState(() {});
                        });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Consumer<AgentViewModel>(
                    builder: (context, viewModel, child) {
                      return _buildTimeFieldWithIcon('Time', viewModel.timeCtl, () {
                        _pickTime();
                        if (setDialogState != null) setDialogState(() {});
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Plot No', context.read<AgentViewModel>().plotCtl, Icons.location_on),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Registry No', context.read<AgentViewModel>().registryCtl, Icons.description),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Client Name *', context.read<AgentViewModel>().clientNameCtl, Icons.person),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Client Mobile', context.read<AgentViewModel>().clientMobileCtl, Icons.phone),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextFieldWithIcon('Comments', context.read<AgentViewModel>().commentsCtl, Icons.comment, maxLines: 3),
            const SizedBox(height: 16),
            
            // Show "Other" category field if "other" is selected
            if (context.read<AgentViewModel>().transferCategory == 'other') ...[
              _buildTextFieldWithIcon('Specify Category', context.read<AgentViewModel>().transferOtherCategoryCtl, Icons.category),
              const SizedBox(height: 16),
            ],
            
            // Show "Other" size field if "other" is selected  
            if (context.read<AgentViewModel>().transferSize == 'other') ...[
              _buildTextFieldWithIcon('Specify Size', context.read<AgentViewModel>().transferOtherSizeCtl, Icons.straighten),
              const SizedBox(height: 16),
            ],
            
            // Image upload section with functional button
            _buildFormSection('Property Images', [
              Consumer<AgentViewModel>(
                builder: (context, viewModel, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upload button
                      ElevatedButton.icon(
                        onPressed: () {
                          viewModel.pickImage();
                          if (setDialogState != null) setDialogState(() {});
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show selected image path
                      if (viewModel.imagePath != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Image selected: ${viewModel.imagePath!.split('/').last}',
                                  style: AppFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF333333),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  viewModel.clearImagePath();
                                  if (setDialogState != null) setDialogState(() {});
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                color: Colors.red.shade600,
                                tooltip: 'Clear image',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // Save Button - Fixed at bottom right
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 150,
                  child: ElevatedButton(
                    onPressed: () => _submitTransfer(action: 'save', dialogContext: dialogContext, existingItem: existingItem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: context.read<AgentViewModel>().saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Save', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientRequirementForm(BuildContext dialogContext, {StateSetter? setDialogState, final Map<String, dynamic>? existingItem}) {
    // Initialize form data if existingItem is provided
    if (existingItem != null) {
      _initializeClientRequirementForm(existingItem);
    }
    
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
                  child: _buildDropdownField('Category', context.read<AgentViewModel>().reqCategory, [
                    'Residential',
                    'Commercial', 
                    'Plot',
                    'other'
                  ], Icons.home, (value) {
                      context.read<AgentViewModel>().setReqCategory(value);
                      if (setDialogState != null) setDialogState(() {});
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField('Preferred Size', context.read<AgentViewModel>().reqSize, [
                    '5 Marla',
                    '10 Marla',
                    '1 Kanal',
                    '2 Kanal',
                    'other'
                  ], Icons.straighten, (value) {
                      context.read<AgentViewModel>().setReqSize(value);
                      if (setDialogState != null) setDialogState(() {});
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField('Preferred Location/Society', context.read<AgentViewModel>().reqLocation, [
                    'DHA',
                    'Bahria Town',
                    'LDA Avenue',
                    'Valencia',
                    'other'
                  ], Icons.location_on, (value) {
                      context.read<AgentViewModel>().setReqLocation(value);
                      if (setDialogState != null) setDialogState(() {});
                  }),
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
                  child: _buildTextFieldWithIcon('Client Name', context.read<AgentViewModel>().reqClientNameCtl, Icons.person),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Client Mobile No', context.read<AgentViewModel>().reqClientMobileCtl, Icons.phone),
                ),
              ],
            ),
            
            // Budget & Timeline Section
            _buildFormSection('Budget & Timeline', []),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextFieldWithIcon('Budget Min', context.read<AgentViewModel>().reqBudgetMinCtl, Icons.money),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextFieldWithIcon('Budget Max', context.read<AgentViewModel>().reqBudgetMaxCtl, Icons.money),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Consumer<AgentViewModel>(
                    builder: (context, viewModel, child) {
                      return _buildDateFieldWithIcon('Date', viewModel.reqDateCtl, () async {
                          await _pickRequirementDate();
                          if (setDialogState != null) setDialogState(() {});
                        });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()), // Empty space for alignment
              ],
            ),
            
            // Attachments & Notes Section
            _buildFormSection('Attachments & Notes', []),
            const SizedBox(height: 8),
            
            // Remarks field - Full width
            _buildTextFieldWithIcon('Remarks', context.read<AgentViewModel>().reqCommentsCtl, Icons.edit, maxLines: 3),
            
            const SizedBox(height: 16),
            
            // Upload Image - Separate row below Remarks
            ImageUploadWidget(
              imagePaths: context.read<AgentViewModel>().requirementImages,
              onImagesChanged: (images) {
                  context.read<AgentViewModel>().setRequirementImages(images);
                  if (setDialogState != null) setDialogState(() {});
              },
              maxImages: 3,
            ),
            
            const SizedBox(height: 32),
            
            // Save Button - Fixed at bottom right
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    onPressed: () => _submitClientRequirement(action: 'save', dialogContext: dialogContext, existingItem: existingItem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: context.read<AgentViewModel>().saving
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
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
    );
  }
  
  // Helper widget for dropdown fields with icons
 Widget _buildDropdownField(String label, String? value, List<String> items, IconData icon, Function(String?) onChanged) {
  return DropdownButtonFormField<String>(
    value: value,
    dropdownColor: Colors.white,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: Colors.white,
    ),
    style: AppFonts.poppins(fontSize: 12, color: Colors.black87),
    items: items.map((item) => DropdownMenuItem(
      value: item, 
      child: Text(item, style: AppFonts.poppins(fontSize: 12, color: Colors.black87)),
    )).toList(),
    onChanged: onChanged,
  );
}
  
  // Helper widget for date fields with icons
  Widget _buildDateFieldWithIcon(String label, TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          suffixIcon: Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
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
        style: AppFonts.poppins(fontSize: 12, color: Colors.black87),
      ),
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
    return _buildDropdownField('Category *', context.read<AgentViewModel>().transferCategory, [
      'Residential',
      'Commercial',
      'Plot',
      'other'
    ], Icons.home, (value) => context.read<AgentViewModel>().setTransferCategory(value));
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
          value: context.read<AgentViewModel>().requirementSource,
          dropdownColor: Colors.white,
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
          items: ['Direct','Agent','Website','Social Media','Referral']
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: AppFonts.poppins(fontSize: 12, color: Colors.black87)),
                  ))
              .toList(),
          onChanged: (value) {
            context.read<AgentViewModel>().setRequirementSource(value);
          },
        ),
      ],
    );
  }

  
  void _showDetails(BuildContext context, WorkingProgressData item, bool isTransfer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Header with Gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF6B35),
                      const Color(0xFFFF6B35).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTransfer ? 'Transfer Details' : 'Client Requirement Details',
                            style: AppFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isTransfer ? 'Transfer Entry' : 'Client Requirement',
                              style: AppFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID: ${item.id}',
                        style: AppFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Premium Content with Sections
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // General Information Section
                      _buildSectionHeader('General Information', Icons.info_outline),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow('ID', item.id),
                        _buildDetailRow('Type', isTransfer ? 'Transfer' : 'Client Requirements'),
                        _buildDetailRow('Status', item.status ?? 'N/A'),
                        _buildDetailRow('Name', item.name),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Category/Source Information Section
                      _buildSectionHeader('Category Information', Icons.category),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow(isTransfer ? 'Category' : 'Source', item.category ?? 'N/A'),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Timeline Information Section
                      _buildSectionHeader('Timeline Information', Icons.schedule),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        if (item.transferDate != null && item.transferDate!.isNotEmpty)
                          _buildDetailRow('Date', item.transferDate!.split('T').first.split(' ').first),
                        if (item.transferDate == null || item.transferDate!.isEmpty)
                          _buildDetailRow('Date', 'N/A'),
                        if (item.nextWorkingDate != null && item.nextWorkingDate!.isNotEmpty)
                          _buildDetailRow('Next Working Date', item.nextWorkingDate!.split('T').first.split(' ').first),
                        if (item.nextWorkingDate == null || item.nextWorkingDate!.isEmpty)
                          _buildDetailRow('Next Working Date', 'N/A'),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // User Information Section
                      _buildSectionHeader('User Information', Icons.people),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow('From User', item.fromUser ?? 'N/A'),
                        _buildDetailRow('To User', item.toUser ?? 'N/A'),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      // Additional Information Section
                      _buildSectionHeader('Additional Information', Icons.more_horiz),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildDetailRow('Company ID', item.companyId ?? 'N/A'),
                        _buildDetailRow('Remarks', item.remarks ?? 'N/A'),
                        _buildDetailRow('Updated', item.updatedAt?.toString().split('T').first ?? 'N/A'),
                        _buildDetailRow('Active', item.isActive?.toString() ?? 'N/A'),
                      ]),
                    ],
                  ),
                ),
              ),
              
              // Premium Footer with Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFFF6B35)),
                          foregroundColor: const Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _generatePdfReceipt(item, isTransfer);
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Generate Professional Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF6B35), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFF6B35),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Future<void> _generatePdfReceipt(WorkingProgressData item, bool isTransfer) async {
    try {
      final pdf = pw.Document();
      
      // Build PDF content
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFF6B35),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Real Estate Management System - Official Receipt',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                
                // Entry Details Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${isTransfer ? 'Transfer' : 'Client Requirement'} Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFFFF6B35),
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      
                      // Details Grid
                      pw.Table(
                        columnWidths: {
                          0: const pw.FixedColumnWidth(120),
                          1: const pw.FlexColumnWidth(),
                        },
                        children: [
                          _buildPdfRow('ID:', item.id),
                          _buildPdfRow('Type:', isTransfer ? 'Transfer' : 'Client Requirement'),
                          _buildPdfRow('Status:', item.status ?? 'N/A'),
                          _buildPdfRow('Name:', item.name),
                          _buildPdfRow(isTransfer ? 'Category:' : 'Source:', item.category ?? 'N/A'),
                          if (item.transferDate != null && item.transferDate!.isNotEmpty)
                            _buildPdfRow('Date:', item.transferDate!),
                          if (item.nextWorkingDate != null && item.nextWorkingDate!.isNotEmpty)
                            _buildPdfRow('Next Working Date:', item.nextWorkingDate!),
                          if (item.fromUser != null && item.fromUser!.isNotEmpty)
                            _buildPdfRow('From User:', item.fromUser!),
                          if (item.toUser != null && item.toUser!.isNotEmpty)
                            _buildPdfRow('To User:', item.toUser!),
                          if (item.companyId != null && item.companyId!.isNotEmpty)
                            _buildPdfRow('Company ID:', item.companyId!),
                          if (item.remarks != null && item.remarks!.isNotEmpty)
                            _buildPdfRow('Remarks:', item.remarks!),
                          _buildPdfRow('Updated:', item.updatedAt?.toString().split('T').first ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                
                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'EasyRealtorsPro - Real Estate Management System',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      // Use Printing.layoutPdf for Windows compatibility
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'agent_working_receipt_${item.id}.pdf',
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _editItem(WorkingProgressData item, bool isTransfer) async {
  // Convert WorkingProgressData to Map<String, dynamic> for form
  final itemMap = {
    'id': item.id,
    'name': item.name,
    'status': item.status,
    'remarks': item.remarks,
    'transfer_date': item.transferDate,
    'next_working_date': item.nextWorkingDate,
    'category': item.category,
    'source': item.source,
    // Note: plot_no, registry_number, size, client_mobile, images are not available in WorkingProgressData class
    // They exist in database but not in the generated class - will need to be fetched separately if needed
  };
  
  if (isTransfer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<AgentViewModel>.value(
        value: Provider.of<AgentViewModel>(context, listen: false),
        child: Dialog(
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
                        'Edit Transfer',
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
                  child: _buildTransferForm(dialogContext, existingItem: itemMap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider<AgentViewModel>.value(
        value: Provider.of<AgentViewModel>(context, listen: false),
        child: Dialog(
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
                        'Edit Client Requirement',
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
                  child: _buildClientRequirementForm(dialogContext, existingItem: itemMap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
  
  Future<void> _deleteItem(String itemId, bool isTransfer) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this ${isTransfer ? 'transfer' : 'client requirement'}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final agentViewModel = Provider.of<AgentViewModel>(context, listen: false);
        
        // Delete from database
        await agentViewModel.deleteItem(itemId);
        
        // FOOLPROOF MANUAL REFRESH PATTERN - Use public methods only
        agentViewModel.loadTransfers();
        agentViewModel.loadClientRequirements();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isTransfer ? 'Transfer' : 'Client Requirement'} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  pw.TableRow _buildPdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }
}
