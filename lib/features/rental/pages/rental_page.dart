import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/font_utils.dart';
import '../../../widgets/custom_pagination_card.dart' show CustomPaginationCard;

// Firebase imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_threading_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import '../../../core/role_utils.dart' as local;
import 'package:drift/drift.dart' as d;

import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:path/path.dart' as p;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/shared_utils.dart';
import '../../../core/phone_actions.dart';
import '../../../core/services/firestore_cache_service.dart';
import '../../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../../widgets/primary_gradient_button.dart';
import '../../../shimmer_widgets.dart';
import '../../../responsive_widgets.dart';
import '../../../core/app_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:drive_client/drive_client.dart';
import 'package:drive_client/retention.dart';
import 'package:http/http.dart' as http;
import 'package:system_tray/system_tray.dart' if (dart.library.html) '../../platform_stubs/system_tray_stub.dart' hide AppWindow;
import '../../../core/services/auth_service.dart';
import '../../../login_page.dart';
import '../../../features/rental/view_models/rental_view_model.dart';
import '../../../features/rental/repositories/rental_repository.dart';
import '../../../firestore_sync_service.dart' show FirestoreSyncState;
import '../../../image_cache_service.dart';
import '../../../offline_sync_service.dart';
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../widgets/stat_card.dart' show StatCard;
import '../../../widgets/performance_chart_card.dart' show PerformanceChartCard;
import '../../../core/app.dart' show AdminApp;
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../../../features/inventory/pages/inventory_page.dart' show InventoryPage;
import '../../../features/todo/pages/todo_page.dart' show ToDoPage;
import '../../../features/trading/pages/trading_page.dart' show TradingPage;
import 'package:provider/provider.dart';
import '../../../features/expenditure/pages/expenditure_page.dart' show ExpenditurePage;
import '../../../features/expenditure/view_models/expenditure_view_model.dart';
import '../../../features/users/pages/users_page.dart' as users show UsersPage;
import '../../../features/companies/pages/companies_page.dart' as companies show CompaniesPage;
import '../../../features/reports/pages/reports_page.dart' show ReportsPage;
import '../../../features/settings/pages/settings_page.dart' show SettingsPageClean;

class RentalItemsPage extends StatefulWidget {
  final AppDatabase db;
  final String? initialFilter; // 'Not Sold', 'Sold', 'Maintenance'
  final VoidCallback? onFilterCleared;

  const RentalItemsPage({
    super.key, 
    required this.db,
    this.initialFilter,
    this.onFilterCleared,
  });

  @override
  State<RentalItemsPage> createState() => _RentalItemsPageState();
}

class _RentalItemsPageState extends State<RentalItemsPage> {
  List<Map<String, dynamic>> _rows = [];
  String _q = '';
  bool _loading = true;
  bool _firestoreReady = true;
  Map<String, dynamic>? _editingRental;
  List<String> _rentalImages = [];
  Map<String, dynamic>? _currentUser;
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  FirestoreSyncState _syncState = FirestoreSyncState();
  String? _currentFilter;

  // FIXED: Move property type state to class level to persist across dialog opens
  ValueNotifier<String>? _propertyTypeState;

  // SQLite-only flag
  static const bool _sqliteOnlyMode = true;

  bool _isFirestoreOperationAllowed() {
    return !_sqliteOnlyMode && Firebase.apps.isNotEmpty;
  }

  Future<void> _executeFirestoreOperation(Future<void> Function() operation) async {
    if (_isFirestoreOperationAllowed()) {
      try {
        await operation();
      } catch (e) {
        debugPrint('Firestore operation failed (non-critical in SQLite-only mode): $e');
      }
    } else {
      debugPrint('Firestore operation skipped in SQLite-only mode');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService.getCurrentUser(authToken);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    Future.microtask(() async {
      await _loadCurrentUser();
      await _load();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final isSuperAdmin = local.RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = local.RoleUtils.isAgent(_currentUser);
    final companyId = local.RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();

    if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _loading = false;
      });
      return;
    }

    final result = await widget.db.customSelect(
      isSuperAdmin
          ? 'SELECT id, created_by, name, price, remarks, location, owner_name, contact_no, cnic, security, sale_status, company_id, updated_at FROM rental_items WHERE is_active = 1 ORDER BY updated_at DESC'
          : (isAgent
              ? 'SELECT id, created_by, name, price, remarks, location, owner_name, contact_no, cnic, security, sale_status, company_id, updated_at FROM rental_items WHERE company_id = ? AND created_by = ? AND is_active = 1 ORDER BY updated_at DESC'
              : 'SELECT id, created_by, name, price, remarks, location, owner_name, contact_no, cnic, security, sale_status, company_id, updated_at FROM rental_items WHERE company_id = ? AND is_active = 1 ORDER BY updated_at DESC'),
      variables: isSuperAdmin
          ? []
          : [
              d.Variable.withString(companyId ?? ''),
              if (isAgent) d.Variable.withString(myUserId ?? ''),
            ],
      readsFrom: {widget.db.rentalItems},
    ).get();

    final cnt = await widget.db.customSelect('SELECT parent_id, COUNT(*) AS c FROM rental_comments GROUP BY parent_id', variables: <d.Variable<Object>>[]).get();
    final prev = await widget.db.customSelect(
      'SELECT rc.parent_id, rc.comment FROM rental_comments rc JOIN (SELECT parent_id, MAX(updated_at) AS m FROM rental_comments GROUP BY parent_id) t ON t.parent_id = rc.parent_id AND t.m = rc.updated_at',
      variables: <d.Variable<Object>>[]).get();

    if (!mounted) return;

    setState(() {
      _rows = result.map((r) {
        final rowMap = Map<String, dynamic>.from(r.data);
        debugPrint('=== LOADED ROW FROM DB ===');
        debugPrint('Row ID: ${rowMap['id']}, Name: ${rowMap['name']}');
        return rowMap;
      }).toList();
      _loading = false;
    });
  }

  void _showAddFormDialog({Map<String, dynamic>? existing}) {
    setState(() {
      _editingRental = existing;
      
      // FIXED: Initialize class-level property type state
      final validPropertyTypes = ['House', 'Shop', 'Plaza', 'Hall', 'Apartment', 'Office', 'Warehouse'];
      String existingPropertyType = existing?['name']?.toString() ?? '';
      _propertyTypeState = ValueNotifier<String>(
        validPropertyTypes.contains(existingPropertyType) ? existingPropertyType : 'House'
      );
      
      if (existing != null && existing['id'] != null) {
        // Load images from Firestore when editing
        final existingId = existing['id'].toString();
        if (Firebase.apps.isNotEmpty) {
          FirebaseFirestore.instance.collection('rental_items').doc(existingId).get().then((doc) {
            if (doc.exists && doc.data() != null && doc.data()!['imagePaths'] != null) {
              final imagePaths = List<String>.from(doc.data()!['imagePaths'] ?? []);
              if (mounted) {
                setState(() {
                  _rentalImages = imagePaths;
                });
              }
            } else {
              setState(() {
                _rentalImages = [];
              });
            }
          }).catchError((e) {
            debugPrint('Error loading rental images: $e');
            if (mounted) {
              setState(() {
                _rentalImages = [];
              });
            }
          });
        } else {
          _rentalImages = [];
        }
      } else {
        _rentalImages = []; // Reset images when opening new form
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogBuilderContext) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              _editingRental = null;
              _rentalImages = [];
            });
            Navigator.of(dialogBuilderContext).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(dialogBuilderContext).size.width < 600 ? 8 : 16,
            vertical: MediaQuery.of(dialogBuilderContext).size.height < 800 ? 8 : 16,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogBuilderContext).size.width * 0.95,
              maxHeight: MediaQuery.of(dialogBuilderContext).size.height * 0.95,
            ),
            decoration: BoxDecoration(
              color: Theme.of(dialogBuilderContext).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: StatefulBuilder(
                builder: (dialogContext, setDialogState) {
                  return Stack(
                    children: [
                      // Form content with padding for back button
                      Padding(
                        padding: const EdgeInsets.only(top: 56), // Space for back button
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildAddRentalForm(setDialogState, dialogContext),
                        ),
                      ),
                      // Back button at top-left
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _editingRental = null;
                                _rentalImages = [];
                              });
                              Navigator.of(dialogContext).pop();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.grey.shade800,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddRentalForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {
    final existing = _editingRental;
    
    // Ensure property type state is initialized
    if (_propertyTypeState == null) {
      final validPropertyTypes = ['House', 'Shop', 'Plaza', 'Hall', 'Apartment', 'Office', 'Warehouse'];
      String existingPropertyType = existing?['name']?.toString() ?? '';
      _propertyTypeState = ValueNotifier<String>(
        validPropertyTypes.contains(existingPropertyType) ? existingPropertyType : 'House'
      );
    }
    
    final addressCtl = TextEditingController(text: existing?['location']?.toString() ?? '');
    final ownerNameCtl = TextEditingController(text: existing?['owner_name']?.toString() ?? '');
    final contactNoCtl = TextEditingController(text: existing?['contact_no']?.toString() ?? '');
    final rentCtl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final securityCtl = TextEditingController(text: existing?['security']?.toString() ?? '');
    final commentsCtl = TextEditingController(text: existing?['remarks']?.toString() ?? '');

    // Focus nodes for Tab navigation
    final propertyTypeFocus = FocusNode();
    final addressFocus = FocusNode();
    final ownerNameFocus = FocusNode();
    final contactNoFocus = FocusNode();
    final rentFocus = FocusNode();
    final securityFocus = FocusNode();
    final statusFocus = FocusNode();
    final commentsFocus = FocusNode();

    // Initialize state variables outside builder to persist across rebuilds
    final existingStatus = existing?['sale_status']?.toString() ?? '';
    final mappedStatus = existingStatus == 'Sale' ? 'Sold' : (existingStatus == 'Not Sale' ? 'Not Sold' : existingStatus);
    final statusState = ValueNotifier<String>(mappedStatus);

    return StatefulBuilder(
      builder: (context, setLocal) {
        return FocusScope(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final isMobile = maxWidth < 600;
                  final isTablet = maxWidth >= 600 && maxWidth < 900;
                  final columns = maxWidth > 1100
                      ? 3
                      : maxWidth > 720
                          ? 2
                          : 1;
                  final double fieldWidth = columns == 1 ? maxWidth : (maxWidth - (16 * (columns - 1))) / columns;

                  Widget fieldBox(Widget child, {int span = 1}) {
                    if (columns == 1) return SizedBox(width: double.infinity, child: child);
                    final effectiveSpan = span > columns ? columns : span;
                    final width = (fieldWidth * effectiveSpan) + (16 * (effectiveSpan - 1));
                    return SizedBox(width: width, child: child);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        existing == null ? 'Add Rental Item' : 'Edit Rental Item',
                        style: AppFonts.poppins(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          fieldBox(
                            ValueListenableBuilder<String>(
                              valueListenable: _propertyTypeState!,
                              builder: (context, propertyTypeValue, child) {
                                debugPrint('=== VALUE LISTENABLE BUILDER ===');
                                debugPrint('Current propertyTypeValue: $propertyTypeValue');
                                return DropdownButtonFormField<String>(
                                  value: propertyTypeValue.isNotEmpty ? propertyTypeValue : 'House', // Set default to first item if null
                                  focusNode: propertyTypeFocus,
                                  decoration: _fieldDecoration('Property Type', isRequired: true),
                                  items: const [
                                    DropdownMenuItem(value: 'House', child: Text('House')),
                                    DropdownMenuItem(value: 'Shop', child: Text('Shop')),
                                    DropdownMenuItem(value: 'Plaza', child: Text('Plaza')),
                                    DropdownMenuItem(value: 'Hall', child: Text('Hall')),
                                    DropdownMenuItem(value: 'Apartment', child: Text('Apartment')),
                                    DropdownMenuItem(value: 'Office', child: Text('Office')),
                                    DropdownMenuItem(value: 'Warehouse', child: Text('Warehouse')),
                                  ],
                                  onChanged: (value) {
                                    debugPrint('=== DROPDOWN CHANGED ===');
                                    debugPrint('New value: $value');
                                    debugPrint('Before update - _propertyTypeState!.value: ${_propertyTypeState!.value}');
                                    if (value != null) {
                                      _propertyTypeState!.value = value; // Update ValueNotifier
                                      debugPrint('After update - _propertyTypeState!.value: ${_propertyTypeState!.value}');
                                      if (dialogSetState != null) {
                                        dialogSetState(() {}); // Trigger dialog rebuild
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          fieldBox(
                            TextField(
                              controller: addressCtl,
                              focusNode: addressFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(ownerNameFocus),
                              decoration: _fieldDecoration('Address'),
                            ),
                          ),
                          fieldBox(
                            TextField(
                              controller: ownerNameCtl,
                              focusNode: ownerNameFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(contactNoFocus),
                              decoration: _fieldDecoration('Owner Name'),
                              maxLength: 100,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              inputFormatters: [clientNameFormatter],
                            ),
                          ),
                          fieldBox(
                            TextField(
                              controller: contactNoCtl,
                              focusNode: contactNoFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(rentFocus),
                              decoration: _fieldDecoration('Contact No'),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          fieldBox(
                            TextField(
                              controller: rentCtl,
                              focusNode: rentFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(securityFocus),
                              decoration: _fieldDecoration('Rent (Rs)'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          fieldBox(
                            TextField(
                              controller: securityCtl,
                              focusNode: securityFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(commentsFocus),
                              decoration: _fieldDecoration('Security (Rs)'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          fieldBox(
                            ValueListenableBuilder<String>(
                              valueListenable: statusState,
                              builder: (context, statusValue, child) {
                                return DropdownButtonFormField<String>(
                                  value: statusValue?.isNotEmpty == true ? statusValue : 'Not Sold', // Set default to first item if null
                                  focusNode: statusFocus,
                                  decoration: _fieldDecoration('Sale Status'),
                                  items: const [
                                    DropdownMenuItem(value: 'Not Sold', child: Text('Not Sold')),
                                    DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null && dialogSetState != null) {
                                      dialogSetState(() {
                                        statusState.value = value;
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      fieldBox(
                        TextField(
                          controller: commentsCtl,
                          focusNode: commentsFocus,
                          maxLines: 3,
                          decoration: _fieldDecoration('Remarks'),
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Image upload section
                      ImageUploadWidget(
                        imagePaths: _rentalImages,
                        onImagesChanged: (images) {
                          if (dialogSetState != null) {
                            dialogSetState(() {
                              _rentalImages = images;
                            });
                          }
                        },
                        maxImages: 5,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _editingRental = null;
                                _rentalImages = [];
                              });
                              if (dialogContext != null && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.grey.shade700,
                            ),
                            child: Text('Cancel', style: AppFonts.poppins(fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_propertyTypeState!.value.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select property type'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (addressCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter address'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (ownerNameCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter owner name'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (contactNoCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter contact number'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (rentCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter rent amount'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final rent = int.tryParse(rentCtl.text.trim());
                              if (rent == null || rent <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter valid rent amount'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final security = int.tryParse(securityCtl.text.trim()) ?? 0;

                              // Save data
                              final now = DateTime.now().toUtc();
                              final data = {
                                'name': _propertyTypeState!.value.trim(), // FIXED: Use ValueNotifier value
                                'location': addressCtl.text.trim(),
                                'owner_name': ownerNameCtl.text.trim(),
                                'contact_no': contactNoCtl.text.trim(),
                                'price': rent,
                                'security': security,
                                'sale_status': statusState.value,
                                'remarks': commentsCtl.text.trim(),
                                'created_at': now.toIso8601String(),
                                'updated_at': now.toIso8601String(),
                              };
                              
                              debugPrint('=== RENTAL SAVE DEBUG ===');
                              debugPrint('Property Type being saved: ${data['name']}');
                              debugPrint('_propertyTypeState!.value: ${_propertyTypeState!.value}');

                              try {
                                if (existing != null && existing['id'] != null) {
                                  // Update existing record
                                  await widget.db.customStatement(
                                    'UPDATE rental_items SET name = ?, location = ?, owner_name = ?, contact_no = ?, price = ?, security = ?, sale_status = ?, remarks = ?, updated_at = ? WHERE id = ?',
                                    [
                                      data['name'],
                                      data['location'],
                                      data['owner_name'],
                                      data['contact_no'],
                                      data['price'],
                                      data['security'],
                                      data['sale_status'],
                                      data['remarks'],
                                      data['updated_at'],
                                      existing['id'],
                                    ],
                                  );
                                } else {
                                  // Insert new record
                                  final id = now.millisecondsSinceEpoch.toString();
                                  final companyId = local.RoleUtils.getUserCompanyId(_currentUser);
                                  final userId = _currentUser?['id']?.toString();
                                  data['id'] = id;
                                  data['created_by'] = userId ?? '';
                                  data['company_id'] = companyId ?? '';
                                  data['is_active'] = 1;

                                  await widget.db.customStatement(
                                    'INSERT INTO rental_items (id, created_by, name, location, owner_name, contact_no, price, security, sale_status, remarks, company_id, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                                    [
                                      id,
                                      userId ?? '',
                                      data['name'],
                                      data['location'],
                                      data['owner_name'],
                                      data['contact_no'],
                                      data['price'],
                                      data['security'],
                                      data['sale_status'],
                                      data['remarks'],
                                      companyId ?? '',
                                      data['is_active'],
                                      data['created_at'],
                                      data['updated_at'],
                                    ],
                                  );
                                }

                                // Close dialog
                                setState(() {
                                  _editingRental = null;
                                  _rentalImages = [];
                                });
                                if (dialogContext != null && dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }

                                // Reload data
                                debugPrint('=== RELOADING DATA AFTER SAVE ===');
                                await _load();
                                debugPrint('=== DATA RELOADED ===');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(existing != null ? 'Rental item updated successfully' : 'Rental item added successfully'),
                                    backgroundColor: const Color(0xFFFF6B35),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error saving rental item: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(existing != null ? 'Update' : 'Save', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(
    String label, {
    bool isRequired = false,
    Widget? suffixIcon,
    IconData? icon,
    IconData? fieldIcon,
  }) {
    fieldIcon = fieldIcon ?? icon;
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('email')) {
        fieldIcon = Icons.email_outlined;
      } else if (lowerLabel.contains('contact') || lowerLabel.contains('phone')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('password')) {
        fieldIcon = Icons.lock_outline;
      } else if (lowerLabel.contains('permission') || lowerLabel.contains('restriction')) {
        fieldIcon = Icons.security;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }

    Widget? labelWidget;
    if (isRequired) {
      labelWidget = RichText(
        text: TextSpan(
          text: label,
          style: AppFonts.poppins(color: Colors.grey.shade700),
          children: [
            TextSpan(
              text: ' *',
              style: AppFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Use "Rs" text widget for currency fields instead of dollar icon
    Widget? prefixWidget;
    if (fieldIcon == null && (label.toLowerCase().contains('price') || label.toLowerCase().contains('demand') || label.toLowerCase().contains('payment') || label.toLowerCase().contains('rent') || label.toLowerCase().contains('security'))) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text(
          'Rs',
          style: AppFonts.poppins(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );
    } else if (fieldIcon != null) {
      prefixWidget = Icon(fieldIcon, color: Colors.grey.shade700);
    }

    return InputDecoration(
      labelText: isRequired ? null : label,
      label: labelWidget,
      prefixIcon: prefixWidget,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF23272E)
          : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: AppFonts.poppins(color: Colors.grey.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1D23)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Rental Management',
          style: AppFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (filter) {
              setState(() {
                _currentFilter = filter;
              });
              _load();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Items'),
              ),
              const PopupMenuItem(
                value: 'Not Sold',
                child: Text('Not Sold'),
              ),
              const PopupMenuItem(
                value: 'Sold',
                child: Text('Sold'),
              ),
              const PopupMenuItem(
                value: 'Maintenance',
                child: Text('Maintenance'),
              ),
            ],
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TopRightSearch(onChanged: (value) {
              setState(() {
                _q = value;
              });
            }),
          ),
        ],
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
        child: Column(
          children: [
            // Scrollable Content Area
            Expanded(
              child: SingleChildScrollView(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No rental items found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first rental item to get started',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _rows.length,
                            itemBuilder: (context, index) {
                          final row = _rows[index];
                          final id = row['id']?.toString() ?? '';
                          final name = row['name']?.toString() ?? '';
                          final location = row['location']?.toString() ?? '';
                          final ownerName = row['owner_name']?.toString() ?? '';
                          final contactNo = row['contact_no']?.toString() ?? '';
                          final price = row['price']?.toString() ?? '';
                          final security = row['security']?.toString() ?? '';
                          final saleStatus = row['sale_status']?.toString() ?? '';
                          final remarks = row['remarks']?.toString() ?? '';

                          // Apply search filter
                          if (_q.isNotEmpty) {
                            final searchLower = _q.toLowerCase();
                            if (!name.toLowerCase().contains(searchLower) &&
                                !location.toLowerCase().contains(searchLower) &&
                                !ownerName.toLowerCase().contains(searchLower) &&
                                !contactNo.toLowerCase().contains(searchLower) &&
                                !price.toLowerCase().contains(searchLower) &&
                                !saleStatus.toLowerCase().contains(searchLower)) {
                              return const SizedBox.shrink();
                            }
                          }

                          // Apply current filter
                          if (_currentFilter != null && _currentFilter != saleStatus) {
                            return const SizedBox.shrink();
                          }

                          return InkWell(
                            onTap: () => _showDetailsPreviewDialog(context, row),
                            borderRadius: BorderRadius.circular(12),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: saleStatus == 'Sold'
                                                    ? Colors.green
                                                    : saleStatus == 'Maintenance'
                                                        ? Colors.orange
                                                        : Colors.blue,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                saleStatus,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(Icons.location_on, location),
                                        _buildInfoRow(Icons.person, ownerName),
                                        _buildInfoRow(Icons.phone, contactNo),
                                        _buildInfoRow(Icons.attach_money, 'Rent: Rs$price'),
                                        if (security.isNotEmpty && security != '0')
                                          _buildInfoRow(Icons.security, 'Security: Rs$security'),
                                        if (remarks.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Remarks: $remarks',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // 3-dot menu at top-right
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (String value) {
                                        if (value == 'edit') {
                                          _showAddFormDialog(existing: row);
                                        } else if (value == 'delete') {
                                          _deleteRental(id);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, color: Colors.blue, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
            ),
            // Pagination (Fixed at bottom)
            Container(
              padding: const EdgeInsets.all(16),
              child: _buildPaginationCard(),
            ),
          ],
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFormDialog(),
        backgroundColor: const Color(0xFFFF6B35),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationCard() {
    return CustomPaginationCard(
      currentPage: 1, // TODO: Implement pagination state
      totalItems: _rows.length,
      itemsPerPage: 20, // TODO: Make configurable
      onPageChanged: (page) {
        // TODO: Implement page change logic
      },
      onItemsPerPageChanged: (limit) {
        // TODO: Implement items per page change logic
      },
    );
  }

  Future<void> _deleteRental(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rental Item'),
        content: const Text('Are you sure you want to delete this rental item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.db.customStatement(
        'UPDATE rental_items SET is_active = 0, updated_at = ? WHERE id = ?',
        [DateTime.now().toUtc().toIso8601String(), id],
      );

      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental item deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting rental item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDetailsPreviewDialog(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final location = item['location']?.toString() ?? '';
    final ownerName = item['owner_name']?.toString() ?? '';
    final contactNo = item['contact_no']?.toString() ?? '';
    final price = item['price']?.toString() ?? '';
    final security = item['security']?.toString() ?? '';
    final saleStatus = item['sale_status']?.toString() ?? '';
    final remarks = item['remarks']?.toString() ?? '';
    final id = item['id']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and close button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B35), // Orange
                      Color(0xFF4A90E2), // Blue
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Receipt Preview',
                        style: AppFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Property Information Section
                      _buildDetailSection(
                        'Property Information',
                        [
                          _buildDetailRow('Property Type', name),
                          _buildDetailRow('Location', location),
                          _buildDetailRow('Status', saleStatus),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Owner Information Section
                      _buildDetailSection(
                        'Owner Information',
                        [
                          _buildDetailRow('Owner Name', ownerName),
                          _buildDetailRow('Contact Number', contactNo),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Financial Information Section
                      _buildDetailSection(
                        'Financial Information',
                        [
                          _buildDetailRow('Monthly Rent', 'Rs$price'),
                          if (security.isNotEmpty && security != '0')
                            _buildDetailRow('Security Deposit', 'Rs$security'),
                        ],
                      ),
                      if (remarks.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDetailSection(
                          'Additional Remarks',
                          [
                            _buildDetailRow('Remarks', remarks),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Receipt Information
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Receipt Information',
                                  style: AppFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Receipt ID', '#R$id'),
                            _buildDetailRow('Generated Date', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
                            _buildDetailRow('Company', 'EasyRealtorsPro'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer with Generate PDF button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _generateRentalPDF(item);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      'Generate PDF',
                      style: AppFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateRentalPDF(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? '';
    final location = item['location']?.toString() ?? '';
    final ownerName = item['owner_name']?.toString() ?? '';
    final contactNo = item['contact_no']?.toString() ?? '';
    final price = item['price']?.toString() ?? '';
    final security = item['security']?.toString() ?? '';
    final saleStatus = item['sale_status']?.toString() ?? '';
    final remarks = item['remarks']?.toString() ?? '';
    final id = item['id']?.toString() ?? '';

    // Create PDF document
    final pdf = pw.Document();

    // Define custom colors
    final primaryColor = PdfColor.fromInt(0xFFFF6B35); // Orange
    final secondaryColor = PdfColor.fromInt(0xFF4A90E2); // Blue
    final textColor = PdfColor.fromInt(0xFF333333);
    final lightGray = PdfColor.fromInt(0xFFF5F5F5);

    // Add page to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Real Estate Management System',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Rental Agreement / Receipt',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Receipt Information
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightGray,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 16,
                          height: 16,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey600,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'Receipt Information',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    _buildPDFRow('Receipt ID', '#R$id'),
                    _buildPDFRow('Generated Date', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
                    _buildPDFRow('Company', 'EasyRealtorsPro'),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Property Information Section
              _buildPDFSection('Property Information', [
                _buildPDFRow('Property Type', name),
                _buildPDFRow('Location', location),
                _buildPDFRow('Status', saleStatus),
              ]),
              pw.SizedBox(height: 24),

              // Owner Information Section
              _buildPDFSection('Owner Information', [
                _buildPDFRow('Owner Name', ownerName),
                _buildPDFRow('Contact Number', contactNo),
              ]),
              pw.SizedBox(height: 24),

              // Financial Information Section
              _buildPDFSection('Financial Information', [
                _buildPDFRow('Monthly Rent', 'Rs$price'),
                if (security.isNotEmpty && security != '0')
                  _buildPDFRow('Security Deposit', 'Rs$security'),
              ]),

              // Remarks Section (if present)
              if (remarks.isNotEmpty) ...[
                pw.SizedBox(height: 24),
                _buildPDFSection('Additional Remarks', [
                  _buildPDFRow('Remarks', remarks),
                ]),
              ],

              pw.Spacer(),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                child: pw.Column(
                  children: [
                    pw.Divider(color: PdfColors.grey300),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'This is a computer-generated receipt.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      'Generated on ${DateFormat('dd MMM yyyy \'at\' hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
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

    // Trigger printing dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rental_Receipt_$id.pdf',
    );
  }

  pw.Widget _buildPDFSection(String title, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF333333),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF666666),
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF666666),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColor.fromInt(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Companies Management Page - Super Admin Only
class CompaniesPage extends StatefulWidget {
  final AppDatabase db;

  const CompaniesPage({super.key, required this.db});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies Management'),
        backgroundColor: const Color(0xFFFF6B35),
      ),
      body: const Center(
        child: Text('Companies Management - Coming Soon'),
      ),
    );
  }
}
