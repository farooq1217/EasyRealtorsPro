import 'dart:async';

import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, compute;

import 'package:flutter/material.dart';

import '../../../core/font_utils.dart';

import 'package:flutter/services.dart';

// REMOVED: Firestore dependencies for SQLite-only operation

// import 'package:cloud_firestore/cloud_firestore.dart';

// import 'package:firebase_core/firebase_core.dart';

// Add back minimal Firebase imports for helper methods to work

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:intl/intl.dart';

import '../../../core/services/firebase_threading_handler.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

import 'package:shared/shared.dart';

import 'package:drift/drift.dart' as d;

import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;

import 'package:path/path.dart' as p;

import 'package:googleapis_auth/googleapis_auth.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:drive_client/drive_client.dart';

import 'package:drive_client/retention.dart';

import 'package:http/http.dart' as http;

import 'package:system_tray/system_tray.dart' if (dart.library.html) '../../platform_stubs/system_tray_stub.dart' hide AppWindow;

import '../../platform_stubs/window_manager_stub.dart';

import '../../core/services/auth_service.dart';

import '../../login_page.dart';

import '../../shimmer_widgets.dart';

import '../../professional_reports.dart' show buildKeyValueReportPdf, loadCurrentUserFromStorage, loadReportBranding, savePdfBytesToDisk, generateReportSerial, logReportHistory;

import '../../core/professional_pdf_generator.dart';

import '../../core/phone_actions.dart';

import '../../core/app_utils.dart';

import '../../core/shared_utils.dart';

import '../../core/services/firestore_cache_service.dart';

import '../../firestore_sync_service.dart';

import '../../image_cache_service.dart';

import '../../responsive_widgets.dart';

import '../../offline_sync_service.dart';

import '../../core/services/permission_helper.dart' show PermissionHelper;

import '../../core/services/app_storage.dart' show AppStorage;

import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;

import '../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;

import '../../widgets/stat_card.dart' show StatCard;

import '../../widgets/performance_chart_card.dart' show PerformanceChartCard;

import '../../core/app.dart' show AdminApp;

import '../../core/shared_utils.dart' show TopRightSearch, buildResponsiveInfoRow, InfoEntry, validatePassword, normalizeSubscriptionTier, subscriptionLimitForTier, showCustomTimePicker;

import '../../features/inventory/inventory_page.dart' show InventoryPage;

import '../../features/todo/todo_page.dart' show ToDoPage;

import '../../features/trading/trading_page.dart' show TradingPage;

import 'package:provider/provider.dart';

import '../../features/expenditure/expenditure_page.dart' show ExpenditurePage;

import '../../features/expenditure/expenditure_view_model.dart';

import '../../features/users/users_page.dart' as users show UsersPage;

import '../../features/companies/companies_page.dart' as companies show CompaniesPage;

import '../../features/reports/reports_page.dart' show ReportsPage;

import '../../features/settings/settings_page.dart' show SettingsPageClean;



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

  // REMOVED: Firestore-related state variables for SQLite-only operation

  bool _firestoreReady = true;

  Map<String, dynamic>? _editingRental;

  List<String> _rentalImages = [];

  Map<String, dynamic>? _currentUser; // Current logged-in user for permission checks

  // Firestore subscription and sync state for SQLite-only operation

  StreamSubscription<QuerySnapshot>? _firestoreSub;

  FirestoreSyncState _syncState = FirestoreSyncState();

  String? _currentFilter; // Current filter status



  // SQLite-only flag - disables all Firestore operations

  static const bool _sqliteOnlyMode = true;



  // Helper method to disable Firestore operations in SQLite-only mode

  bool _isFirestoreOperationAllowed() {

    return !_sqliteOnlyMode && Firebase.apps.isNotEmpty;

  }



  // Helper method to execute Firestore operations only if allowed

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

  

  /// Get current user from AuthService

  Future<void> _loadCurrentUser() async {

    try {

      final storage = AppStorage();

      final s = await storage.readSettings();

      final authToken = s['authToken'] as String?;

      if (authToken != null) {

        final authService = AuthService();

        final user = await authService.getCurrentUser(authToken);

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

      // REMOVED: Firestore listener for SQLite-only operation

      // await _startFirestoreListener();

      await _load();

    });

  }



  @override

  void dispose() {

    // REMOVED: Firestore subscription cancellation for SQLite-only operation

    // _firestoreSub?.cancel();

    super.dispose();

  }



  /// Start Firestore listener with pagination for real-time sync

  Future<void> _startFirestoreListener() async {

    if (!FirestoreSyncService().isAvailable) {

      Future.microtask(() {

        if (!mounted) return;

        setState(() => _firestoreReady = true);

      });

      return;

    }



    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    final companyId = RoleUtils.getUserCompanyId(_currentUser);



    try {

      // Use secure query builder for role-based isolation

      Query query = buildSecureFirestoreQuery(

        collection: 'rental_items',

        currentUser: _currentUser,

        orderBy: 'updatedAt',

        descending: true,

        limit: 50, // Paginated

      );



      _firestoreSub = query.snapshots().listen((snapshot) async {

        Future.microtask(() async {

          final changes = List<DocumentChange>.from(snapshot.docChanges);

          

          if (changes.isNotEmpty) {

            try {

              await widget.db.batch((batch) {

                for (final change in changes) {

                  final doc = change.doc;

                  final data = doc.data() as Map<String, dynamic>;

                  final id = (data['id'] ?? doc.id).toString();

                  

                  if (change.type == DocumentChangeType.removed) {

                    batch.customStatement(

                      'UPDATE rental_items SET is_active = 0, updated_at = ? WHERE id = ?',

                      [DateTime.now().toUtc().toIso8601String(), id],

                    );

                    continue;

                  }



                // Sync rental item data to SQLite

                final name = (data['name'] ?? '').toString();

                final location = (data['location'] ?? '').toString();

                final ownerName = (data['owner_name'] ?? data['ownerName'] ?? '').toString();

                final contactNo = (data['contact_no'] ?? data['contactNo'] ?? '').toString();

                final price = (data['price'] is num) ? (data['price'] as num).toInt() : int.tryParse(data['price']?.toString() ?? '');

                final security = (data['security'] is num) ? (data['security'] as num).toInt() : int.tryParse(data['security']?.toString() ?? '');

                final saleStatus = (data['sale_status'] ?? data['saleStatus'] ?? 'Not Sold').toString();

                final remarks = (data['remarks'] ?? '').toString();

                final createdBy = (data['created_by'] ?? data['createdBy'])?.toString();

                final cid = (data['company_id'] ?? data['companyId'])?.toString();

                final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();

                final isActiveRaw = data['is_active'] ?? data['isActive'];

                final isActive = isActiveRaw == null ? 1 : ((isActiveRaw is bool ? (isActiveRaw ? 1 : 0) : int.tryParse(isActiveRaw.toString()) ?? 1));



                batch.customStatement(

                  'INSERT OR REPLACE INTO rental_items (id, created_by, name, location, owner_name, contact_no, price, security, sale_status, remarks, company_id, is_active, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',

                  [id, createdBy, name, location, ownerName, contactNo, price, security, saleStatus, remarks, cid, isActive, updatedAt],

                );

              }

            });

            

            // Update UI on main thread

            Future.microtask(() async {

              if (!mounted) return;

              _syncState.startLoading();

              _syncState.finishLoading(synced: true);

              await _load(); // Reload to show updated data

              if (!mounted) return;

              setState(() => _firestoreReady = true);

            });

          } catch (e) {

            debugPrint('Error syncing Firestore changes to SQLite (rental_items): $e');

            Future.microtask(() {

              if (!mounted) return;

              _syncState.finishLoading(synced: false, errorMessage: e.toString());

              setState(() => _firestoreReady = true);

            });

          }

        } else {

          Future.microtask(() {

            if (!mounted) return;

            setState(() => _firestoreReady = true);

          });

        }

        });

      }, onError: (error) {

        debugPrint('Firestore listener error (rental_items): $error');

        // Handle missing index errors gracefully

        final errorStr = error.toString().toLowerCase();

        if (errorStr.contains('index') || errorStr.contains('missing')) {

          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');

        }

        Future.microtask(() {

          if (!mounted) return;

          _syncState.finishLoading(synced: false, errorMessage: error.toString());

          setState(() => _firestoreReady = true);

        });

      });

    } catch (e) {

      debugPrint('Error starting Firestore listener (rental_items): $e');

      // Handle missing index errors gracefully

      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('index') || errorStr.contains('missing')) {

        debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');

      }

      Future.microtask(() {

        if (!mounted) return;

        setState(() => _firestoreReady = true);

      });

    }

  }



  /// Background sync to Firestore (non-blocking, doesn't delay UI)

  void _syncToFirestore({

    required String collection,

    required String docId,

    required Map<String, dynamic> data,

  }) {

    // RootIsolateToken check removed - not available in this Flutter version

    // Run in background without blocking

    Future.microtask(() async {

      try {

        if (Firebase.apps.isNotEmpty) {

          final firestore = FirebaseFirestore.instance;

          await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));

          // Invalidate cache after successful sync

          FirestoreCacheService().invalidateCache(collection, docId);

        }

      } catch (e) {

        debugPrint('Background Firestore sync failed for $collection/$docId: $e');

        // Sync will retry automatically when connectivity is restored

      }

    });

  }



  Map<String, int> _commentCounts = {};

  Map<String, String> _commentPreview = {};



  Future<void> _load() async {

    setState(() => _loading = true);

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    final isAgent = RoleUtils.isAgent(_currentUser);

    final companyId = RoleUtils.getUserCompanyId(_currentUser);

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

    final cnt = await widget.db.customSelect('SELECT parent_id, COUNT(*) AS c FROM rental_comments GROUP BY parent_id').get();

    final prev = await widget.db.customSelect(

      'SELECT rc.parent_id, rc.comment FROM rental_comments rc JOIN (SELECT parent_id, MAX(updated_at) AS m FROM rental_comments GROUP BY parent_id) t ON t.parent_id = rc.parent_id AND t.m = rc.updated_at')

      .get();

    if (!mounted) return;

    setState(() {

      _rows = result.map((r) => Map<String, dynamic>.from(r.data)).toList();

      _commentCounts = { for (final r in cnt) (r.data['parent_id'] as String): (r.data['c'] as int) };

      _commentPreview = { for (final r in prev) (r.data['parent_id'] as String): (r.data['comment']?.toString() ?? '') };

      _loading = false;

    });

  }



  void _showAddFormDialog({Map<String, dynamic>? existing}) {

    setState(() {

      _editingRental = existing;

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

      barrierDismissible: false, // Prevent closing by clicking outside

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

                              // Use dialogContext which is the correct dialog context

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

  

  void _resetRentalForm() {

    setState(() {

      _editingRental = null;

      _rentalImages = [];

    });

  }



  Widget _buildAddRentalForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {

    final existing = _editingRental;

    // PERMANENT REQUIREMENT: When editing, load ALL existing data exactly as saved

    String? _selectedPropertyType = existing?['name']?.toString() ?? 'House';

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

    // Map old values to new values: "Sale" -> "Sold", "Not Sale" -> "Not Sold"

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
                        DropdownButtonFormField<String>(
                          value: _selectedPropertyType,
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
                            if (dialogSetState != null) {
                              dialogSetState(() {
                                _selectedPropertyType = value;
                              });
                            }
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

                              decoration: _fieldDecoration('Contact No.'),

                        keyboardType: TextInputType.phone,

                        maxLength: 11,

                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                              inputFormatters: [mobileNoFormatter],

                            ),

                          ),

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

                        onSubmitted: (_) => FocusScope.of(context).requestFocus(statusFocus),

                              decoration: _fieldDecoration('Security (Rs)'),

                        keyboardType: TextInputType.number,

                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                      ),

                          ),

                          fieldBox(

                      ValueListenableBuilder<String>(

                        valueListenable: statusState,

                        builder: (context, status, _) {

                          return DropdownButtonFormField<String>(

                            value: status.isEmpty ? null : status,

                            items: const [

                              DropdownMenuItem(value: 'Sold', child: Text('Sold')),

                              DropdownMenuItem(value: 'Not Sold', child: Text('Not Sold')),

                            ],

                            onChanged: (v) {

                              statusState.value = v ?? '';

                              setLocal(() {});

                              FocusScope.of(context).requestFocus(commentsFocus);

                            },

                                  decoration: _fieldDecoration('Status'),

                          );

                        },

                      ),

                          ),

                          fieldBox(

                            TextFormField(

                        controller: commentsCtl,

                        focusNode: commentsFocus,

                              textInputAction: TextInputAction.done,

                              decoration: _fieldDecoration('Remarks'),

                              maxLines: 1,

                              maxLength: 200,

                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                              inputFormatters: [commentFormatter],

                              validator: validateComment,

                            ),

                            span: columns,

                          ),

                        ],

                      ),

                      const SizedBox(height: 16),

                      ImageUploadWidget(

                        imagePaths: _rentalImages,

                        onImagesChanged: (images) {

                          setState(() {

                            _rentalImages = images;

                          });

                        },

                        maxImages: 3,

                      ),

                      const SizedBox(height: 24),

                      Row(

                        mainAxisAlignment: MainAxisAlignment.end,

                        children: [

                          OutlinedButton.icon(

                            onPressed: () {

                              _resetRentalForm();

                              Navigator.of(context).pop();

                            },

                            icon: const Icon(Icons.close, size: 18),

                            label: Text(

                              'Cancel',

                              style: AppFonts.poppins(fontWeight: FontWeight.w600),

                            ),

                            style: OutlinedButton.styleFrom(

                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

                              side: BorderSide(color: Colors.grey.shade400, width: 1.5),

                              shape: RoundedRectangleBorder(

                                borderRadius: BorderRadius.circular(12),

                              ),

                            ),

                          ),

                          const SizedBox(width: 12),

                          PrimaryGradientButton(

                            text: 'Save',

                            icon: Icons.save,

                            onPressed: () async {

                              // Capture images BEFORE closing dialog and clearing state

                              final imagesToSave = List<String>.from(_rentalImages);

                              

                              // Close dialog immediately when Save is clicked

                              final wasAdding = existing == null;

                              if (mounted) {

                                _resetRentalForm();

                                // Use dialogContext which is the correct dialog context from StatefulBuilder

                                if (dialogContext != null) Navigator.of(dialogContext).pop(); // Close dialog immediately

                              }

                              

                              try {

                                final nowIso = DateTime.now().toUtc().toIso8601String();

                                final isEdit = existing != null;

                                final id = isEdit ? (existing?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString()) : DateTime.now().millisecondsSinceEpoch.toString();

                              

                                // Get current values from state

                                final currentStatus = statusState.value;

                                

                                // PERMANENT REQUIREMENT: Use insertOnConflictUpdate to UPDATE existing record, not create duplicate

                                // PERMANENT REQUIREMENT: Only save fields with data - empty fields use d.Value.absent()

                                await widget.db.into(widget.db.rentalItems).insertOnConflictUpdate(

                                  RentalItemsCompanion(

                                    id: d.Value(id),

                                    updatedAt: d.Value(nowIso),

                                    companyId: RoleUtils.isSuperAdmin(_currentUser)

                                        ? const d.Value.absent()

                                        : d.Value(RoleUtils.getUserCompanyId(_currentUser)),

                                    createdBy: (() {

                                      final existingCreatedBy = existing?['created_by']?.toString();

                                      if (existingCreatedBy != null && existingCreatedBy.trim().isNotEmpty) {

                                        return d.Value<String?>(existingCreatedBy);

                                      }

                                      final myUserId = _currentUser?['id']?.toString();

                                      return (myUserId == null || myUserId.trim().isEmpty)

                                          ? const d.Value<String?>.absent()

                                          : d.Value<String?>(myUserId);

                                    })(),

                                    // Required field: always provide value (empty string if not filled)

                                    name: (_selectedPropertyType ?? '').isEmpty 

                                        ? const d.Value('')

                                        : d.Value(_selectedPropertyType ?? ''),

                                    // PERMANENT REQUIREMENT: Optional fields - only save if they have data (don't save empty fields)

                                    location: addressCtl.text.trim().isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(addressCtl.text.trim()),

                                    ownerName: ownerNameCtl.text.trim().isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(ownerNameCtl.text.trim()),

                                    contactNo: contactNoCtl.text.trim().isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(contactNoCtl.text.trim()),

                                    price: rentCtl.text.trim().isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(int.tryParse(rentCtl.text.trim())),

                                    security: securityCtl.text.trim().isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(int.tryParse(securityCtl.text.trim())),

                                    saleStatus: currentStatus.isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(currentStatus),

                                    remarks: commentsCtl.text.trim().isEmpty 

                                        ? d.Value.absent()

                                        : d.Value(commentsCtl.text.trim()),

                                  ),

                                );

                                

                                final existingCreatedBy = existing?['created_by']?.toString();

                                final createdByToSave = (existingCreatedBy != null && existingCreatedBy.trim().isNotEmpty)

                                    ? existingCreatedBy

                                    : _currentUser?['id']?.toString();



                                // Background sync to Firestore (non-blocking)

                                _syncToFirestore(

                                  collection: 'rental_items',

                                  docId: id,

                                  data: {

                                    'id': id,

                                    'companyId': RoleUtils.getUserCompanyId(_currentUser),

                                    'company_id': RoleUtils.getUserCompanyId(_currentUser),

                                    'createdBy': createdByToSave,

                                    'created_by': createdByToSave,

                                    'name': _selectedPropertyType ?? '',

                                    'location': addressCtl.text.trim(),

                                    'ownerName': ownerNameCtl.text.trim(),

                                    'contactNo': contactNoCtl.text.trim(),

                                    'price': rentCtl.text.trim().isNotEmpty ? int.tryParse(rentCtl.text.trim()) : null,

                                    'security': securityCtl.text.trim().isNotEmpty ? int.tryParse(securityCtl.text.trim()) : null,

                                    'saleStatus': currentStatus.isEmpty ? null : currentStatus,

                                    'remarks': commentsCtl.text.trim(),

                                    'updatedAt': nowIso,

                                    'imagePaths': imagesToSave.isNotEmpty ? imagesToSave : null,

                                  },

                                );

                                

                                // Reload data after save completes

                                if (mounted) {

                                  await _load();

                                  if (wasAdding) {

                                    ScaffoldMessenger.of(context).showSnackBar(

                                      const SnackBar(content: Text('Entry added successfully')),

                                    );

                                  }

                                }

                              } catch (e) {

                                debugPrint('Error saving rental item: $e');

                                if (mounted) {

                                  ScaffoldMessenger.of(context).showSnackBar(

                                    SnackBar(content: Text('Error saving: $e')),

                                  );

                                }

                              }

                            },

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



  Future<void> _updateRentalStatus(String id, String status) async {

    try {

      final nowIso = DateTime.now().toUtc().toIso8601String();



      // Update in SQLite

      await widget.db.customStatement(

        'UPDATE rental_items SET sale_status = ?, updated_at = ? WHERE id = ?',

        [status, nowIso, id],

      );



      // Update in Firestore if available

      try {

        if (Firebase.apps.isNotEmpty) {

          final firestore = FirebaseFirestore.instance;

          await firestore.collection('rental_items').doc(id).update({

            'saleStatus': status,

            'updatedAt': nowIso,

          });

        }

      } catch (e) {

        debugPrint('Firestore update failed: $e');

      }



      await _load();

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Status updated to $status')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to update status: $e')),

        );

      }

    }

  }



  Future<void> _handleMarkAsSold(Map<String, dynamic> entry) async {

    if (!PermissionHelper.canEditModule(_currentUser, 'rental_items')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('You do not have permission to update rental items'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    await _updateRentalStatus(entry['id'] as String, 'Sold');

  }



  Future<void> _handleMarkAsNotSold(Map<String, dynamic> entry) async {

    if (!PermissionHelper.canEditModule(_currentUser, 'rental_items')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('You do not have permission to update rental items'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    await _updateRentalStatus(entry['id'] as String, 'Not Sold');

  }



  InputDecoration _fieldDecoration(String label, {IconData? icon, Widget? suffixIcon, bool isRequired = false}) {

    // Map labels to appropriate icons for better visual clarity

    IconData? fieldIcon = icon;

    if (fieldIcon == null) {

      final lowerLabel = label.toLowerCase();

      if (lowerLabel.contains('name') || lowerLabel.contains('client') || lowerLabel.contains('owner')) {

        fieldIcon = Icons.person_outline;

      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone') || lowerLabel.contains('contact')) {

        fieldIcon = Icons.phone_outlined;

      } else if (lowerLabel.contains('email')) {

        fieldIcon = Icons.email_outlined;

      } else if (lowerLabel.contains('date') || lowerLabel.contains('time')) {

        fieldIcon = Icons.calendar_today_outlined;

      } else if (lowerLabel.contains('cnic') || lowerLabel.contains('id')) {

        fieldIcon = Icons.badge_outlined;

      } else if (lowerLabel.contains('plot') || lowerLabel.contains('file no') || lowerLabel.contains('reference')) {

        fieldIcon = Icons.numbers_outlined;

      } else if (lowerLabel.contains('size') || lowerLabel.contains('path')) {

        fieldIcon = Icons.straighten_outlined;

      } else if (lowerLabel.contains('price') || lowerLabel.contains('demand') || lowerLabel.contains('payment') || lowerLabel.contains('rent') || lowerLabel.contains('security')) {

        fieldIcon = null; // Will use "Rs" text widget instead

      } else if (lowerLabel.contains('category') || lowerLabel.contains('property type')) {

        fieldIcon = Icons.category_outlined;

      } else if (lowerLabel.contains('status')) {

        fieldIcon = Icons.info_outline;

      } else if (lowerLabel.contains('comment') || lowerLabel.contains('note')) {

        fieldIcon = Icons.note_outlined;

      } else if (lowerLabel.contains('address') || lowerLabel.contains('location')) {

        fieldIcon = Icons.location_on_outlined;

      } else if (lowerLabel.contains('registry') || lowerLabel.contains('transfer')) {

        fieldIcon = Icons.description_outlined;

      } else if (lowerLabel.contains('society') || lowerLabel.contains('block')) {

        fieldIcon = Icons.apartment_outlined;

      } else {

        fieldIcon = Icons.edit_outlined;

      }

    }

    

    // Add red asterisk for required fields

    Widget? labelWidget;

    if (isRequired) {

      labelWidget = RichText(

        text: TextSpan(

          text: label,

          style: AppFonts.poppins(

            color: Colors.grey.shade700,

          ),

          children: [

            TextSpan(

              text: ' *',

              style: AppFonts.poppins(

                color: Colors.red,

                fontWeight: FontWeight.bold,

              ),

            ),

          ],

        ),

      );

    }

    

    // Use "Rs" text widget for currency fields instead of dollar icon

    Widget? prefixWidget;

    // DISABLED: Remove Rs prefix for rent and security fields
    if (false && fieldIcon == null && (label.toLowerCase().contains('price') || label.toLowerCase().contains('demand') || label.toLowerCase().contains('payment') || label.toLowerCase().contains('rent') || label.toLowerCase().contains('security'))) {

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

      suffixIcon: suffixIcon,

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

      labelStyle: AppFonts.poppins(

        color: Colors.grey.shade700,

      ),

    );

  }



  Future<void> _delete(String id) async {

    // Permission check: Only allow delete if user has full_access

    if (!PermissionHelper.canDeleteModule(_currentUser, 'rental_items')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('You do not have permission to delete rental items.'),

            backgroundColor: Colors.red,

          ),

        );

      }

      return;

    }

    

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Confirm delete'),

        content: Text('Delete rental item $id?'),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),

          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),

        ],

      ),

    );

    if (ok != true) return;

    final dao = AppDao(widget.db);

    await dao.deleteRentalItem(id, updatedAtIso: DateTime.now().toUtc().toIso8601String());

    await _load();

  }



  @override

  Widget build(BuildContext context) {

    // Apply filter first, then search

    List<Map<String, dynamic>> filteredRows = _rows;

    if (_currentFilter != null) {

      if (_currentFilter == 'Not Sold') {

        filteredRows = _rows.where((r) => (r['sale_status']?.toString() ?? 'Not Sold') == 'Not Sold').toList();

      } else if (_currentFilter == 'Sold') {

        filteredRows = _rows.where((r) => (r['sale_status']?.toString() ?? 'Not Sold') == 'Sold').toList();

      } else if (_currentFilter == 'Maintenance') {

        // Filter by remarks containing maintenance-related keywords

        filteredRows = _rows.where((r) {

          final remarks = (r['remarks']?.toString() ?? '').toLowerCase();

          return remarks.contains('maintenance') || remarks.contains('repair') || remarks.contains('fix');

        }).toList();

      }

    }

    final rows = _q.isEmpty

        ? filteredRows

        : filteredRows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();

    final canAddRental = PermissionHelper.canAddModule(_currentUser, 'rental_items');

    final canEditRental = PermissionHelper.canEditModule(_currentUser, 'rental_items');

    final canDeleteRental = PermissionHelper.canDeleteModule(_currentUser, 'rental_items');

    final showActionMenu = canEditRental || canDeleteRental;

    return Scaffold(

      appBar: AppBar(

        title: Text('Rental Items', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        flexibleSpace: Container(

          decoration: BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [

                const Color(0xFFFF6B35), // Orange

                const Color(0xFF4A90E2), // Blue

              ],

            ),

          ),

        ),

        actions: [

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

            child: TopRightSearch(onChanged: (q) => setState(() => _q = q)),

          ),

        ],

      ),

      floatingActionButton: canAddRental

          ? FloatingActionButton.extended(

              onPressed: () => _showAddFormDialog(),

              icon: const Icon(Icons.add),

              label: const Text('Add Rental Item'),

            )

          : null,

      body: LayoutBuilder(

        builder: (context, constraints) {

          final isMobile = constraints.maxWidth < 900;

          return Stack(

            children: [

              Row(

                children: [

                  Expanded(

                    child: Container(

                      decoration: BoxDecoration(

                        gradient: LinearGradient(

                          begin: Alignment.topLeft,

                          end: Alignment.bottomRight,

                          colors: [

              const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange

              const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue

                          ],

                        ),

                        border: Border.all(

                          color: Colors.grey.shade300.withOpacity(0.5),

                          width: 1,

                        ),

                      ),

                      child: Stack(

                        children: [

                          rows.isEmpty

                              ? const Center(child: Text('No rental items found'))

                              : ListView.builder(

                                  padding: const EdgeInsets.all(12),

                                  itemCount: rows.length,

                                  itemBuilder: (ctx, i) {

                                    final r = rows[i];

                                    final TextStyle infoStyle = TextStyle(

                                      fontSize: 14,

                                      color: const Color(0xFFFF6B35),

                                    );

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

                                            r['name']?.toString() ?? 'N/A',

                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),

                                          ),

                                        ),

                                        FilledButton.icon(

                                          icon: const Icon(Icons.visibility, size: 16),

                                          label: const Text('Details'),

                                          style: FilledButton.styleFrom(

                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                                            textStyle: const TextStyle(fontSize: 12),

                                          ),

                                          onPressed: () {

                                            Navigator.push(

                                              context,

                                              MaterialPageRoute(

                                                builder: (_) => RentalDetailPage(

                                                  entry: r,

                                                  db: widget.db,

                                                ),

                                              ),

                                            );

                                          },

                                        ),

                                        const SizedBox(width: 8),

                                        if (showActionMenu)

                                          PopupMenuButton<String>(

                                            icon: const Icon(Icons.more_vert),

                                            itemBuilder: (context) => [

                                              if (canEditRental)

                                                PopupMenuItem<String>(

                                                  child: Row(

                                                    children: [

                                                      Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),

                                                      const SizedBox(width: 8),

                                                      const Text('Mark as Sold'),

                                                    ],

                                                  ),

                                                  onTap: () async {

                                                    await Future.delayed(const Duration(milliseconds: 100));

                                                    if (mounted) {

                                                      await _handleMarkAsSold(r);

                                                    }

                                                  },

                                                ),

                                              if (canEditRental)

                                                PopupMenuItem<String>(

                                                  child: Row(

                                                    children: [

                                                      Icon(Icons.close, size: 18, color: Colors.orange.shade700),

                                                      const SizedBox(width: 8),

                                                      const Text('Mark as Not Sold'),

                                                    ],

                                                  ),

                                                  onTap: () async {

                                                    await Future.delayed(const Duration(milliseconds: 100));

                                                    if (mounted) {

                                                      await _handleMarkAsNotSold(r);

                                                    }

                                                  },

                                                ),

                                              if (canEditRental) const PopupMenuDivider(),

                                              if (canEditRental)

                                                PopupMenuItem<String>(

                                                  child: const Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),

                                                  onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _showAddFormDialog(existing: r)),

                                                ),

                                              if (canDeleteRental)

                                                PopupMenuItem<String>(

                                                  child: Row(

                                                    children: [

                                                      Icon(Icons.delete, size: 18, color: Colors.red.shade700),

                                                      const SizedBox(width: 8),

                                                      const Text('Delete'),

                                                    ],

                                                  ),

                                                  onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _delete(r['id'] as String)),

                                                ),

                                            ],

                                          ),

                                      ],

                                    ),

                                    const SizedBox(height: 8),

                                    buildResponsiveInfoRow(

                                      context,

                                      [

                                        InfoEntry('Property Type', r['name'], style: infoStyle),

                                        InfoEntry('Price', r['price'] != null ? 'Rs ${r['price']}' : 'N/A', style: infoStyle),

                                      ],

                                    ),

                                    buildResponsiveInfoRow(

                                      context,

                                      [

                                        InfoEntry('Owner Name', r['owner_name'], style: infoStyle),

                                        InfoEntry('Contact No', r['contact_no'], style: infoStyle),

                                      ],

                                    ),

                                    buildResponsiveInfoRow(

                                      context,

                                      [

                                        InfoEntry('Security', r['security'] != null ? 'Rs ${r['security']}' : 'N/A', style: infoStyle),

                                      ],

                                    ),

                                    buildResponsiveInfoRow(

                                      context,

                                      [

                                        InfoEntry('Location', r['location'], style: infoStyle),

                                      ],

                                    ),

                                    const SizedBox(height: 4),

                                    buildResponsiveInfoRow(

                                      context,

                                      [

                                        InfoEntry('Status', r['sale_status'], style: const TextStyle(fontSize: 14)),

                                        InfoEntry('Remarks', r['remarks'], style: infoStyle),

                                      ],

                                    ),

                                    // Load and display images from Firestore (with caching)

                                    FutureBuilder<Map<String, dynamic>?>(

                                      future: r['id'] != null

                                          ? FirestoreCacheService().getCachedDocument(

                                              'rental_items',

                                              r['id']?.toString() ?? '',

                                            )

                                          : Future<Map<String, dynamic>?>.value(null),

                                      builder: (context, snapshot) {

                                        if (snapshot.connectionState == ConnectionState.waiting) {

                                          return const SizedBox.shrink();

                                        }

                                        if (!snapshot.hasData || snapshot.data == null) {

                                          return const SizedBox.shrink();

                                        }

                                        final data = snapshot.data ?? {};

                                        final imagePaths = data['imagePaths'];

                                        if (imagePaths == null) {

                                          return const SizedBox.shrink();

                                        }

                                        // Handle both List<dynamic> and List<String>

                                        List<String> paths = [];

                                        if (imagePaths is List) {

                                          paths = imagePaths.map((p) => p.toString()).toList();

                                        } else if (imagePaths is String) {

                                          paths = [imagePaths];

                                        }

                                        if (paths.isEmpty) {

                                          return const SizedBox.shrink();

                                        }

                                        return Column(

                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [

                                            const SizedBox(height: 8),

                                            Text(

                                              'Images:',

                                              style: TextStyle(

                                                fontSize: 13,

                                                fontWeight: FontWeight.w600,

                                                color: Colors.grey.shade700,

                                              ),

                                            ),

                                            const SizedBox(height: 8),

                                            Wrap(

                                              spacing: 8,

                                              runSpacing: 8,

                                              children: paths.take(3).map((path) {

                                                return GestureDetector(

                                                  onTap: () {

                                                    showDialog(

                                                      context: context,

                                                      builder: (ctx) => Dialog(

                                                        child: Stack(

                                                          children: [

                                                            Container(

                                                              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),

                                                              child: CachedImageWidget(

                                                                imagePath: path.toString(),

                                                                fit: BoxFit.contain,

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

                                                  },

                                                  child: Container(

                                                    width: 60,

                                                    height: 60,

                                                    decoration: BoxDecoration(

                                                      border: Border.all(color: Colors.grey.shade300),

                                                      borderRadius: BorderRadius.circular(8),

                                                    ),

                                                    child: ClipRRect(

                                                      borderRadius: BorderRadius.circular(8),

                                                      child: CachedImageWidget(

                                                        imagePath: path.toString(),

                                                        fit: BoxFit.cover,

                                                        width: 60,

                                                        height: 60,

                                                        errorWidget: const Icon(Icons.broken_image, size: 24),

                                                      ),

                                                    ),

                                                  ),

                                                );

                                              }).toList(),

                                            ),

                                          ],

                                        );

                                      },

                                    ),

                                   const SizedBox(height: 8),

                                   Text('Updated: ${r['updated_at']?.toString().split('T').first ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),

                                   Builder(

                                     builder: (context) {

                                       final recordId = r['id']?.toString();

                                       if (recordId != null && recordId.isNotEmpty) {

                                         final comment = _commentPreview[recordId];

                                         if (comment != null && comment.isNotEmpty) {

                                           return Column(

                                             crossAxisAlignment: CrossAxisAlignment.start,

                                             children: [

                                               const SizedBox(height: 8),

                                               Container(

                                                 padding: const EdgeInsets.all(8),

                                                 decoration: BoxDecoration(

                                                   color: Colors.grey.shade100,

                                                   borderRadius: BorderRadius.circular(4),

                                                 ),

                                                 child: Row(

                                                   crossAxisAlignment: CrossAxisAlignment.start,

                                                   children: [

                                                     Icon(Icons.comment, size: 16, color: Colors.grey.shade600),

                                                     const SizedBox(width: 8),

                                                     Expanded(

                                                       child: Text(

                                                         'Comment: $comment',

                                                         style: TextStyle(fontSize: 13, color: Colors.grey.shade800),

                                                       ),

                                                     ),

                                                   ],

                                                 ),

                                               ),

                                             ],

                                           );

                                         }

                                       }

                                       return const SizedBox.shrink();

                                     },

                                   ),

                                 ],

                               ),

                             ),

                           );

                                  },

                                ),

                          if (_syncState.isLoading)

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

                  ),

                ],

              ),

            ],

          );

        },

      ),

    );

  }

}



class SetupGate extends StatefulWidget {

  const SetupGate({super.key});



  @override

  State<SetupGate> createState() => _SetupGateState();

}



class _SetupGateState extends State<SetupGate> {

  late final AppStorage _storage;

  AccessCredentials? _creds;

  String? _folderId;

  bool _loading = true;



  @override

  void initState() {

    super.initState();

    _storage = AppStorage();

    _init();

  }



  Future<void> _init() async {

    final creds = await _storage.readCredentials();

    final folderId = await _storage.readFolderId();

    setState(() {

      _creds = creds;

      _folderId = folderId;

      _loading = false;

    });

  }



  @override

  Widget build(BuildContext context) {

    if (_loading) return const Scaffold(body: ShimmerPageLoading(itemCount: 8));

    final ready = _creds != null && _folderId != null && _folderId!.isNotEmpty;

    if (!ready) return SetupScreen(onConfigured: _init, storage: _storage);

    return HomeScreen(storage: _storage, initialCreds: _creds, folderId: _folderId!, bypassDrive: false);

  }

}



class SetupScreen extends StatefulWidget {

  final Future<void> Function() onConfigured;

  final AppStorage storage;

  const SetupScreen({super.key, required this.onConfigured, required this.storage});

  @override

  State<SetupScreen> createState() => _SetupScreenState();

}



class _SetupScreenState extends State<SetupScreen> {

  static const desktopClientId = '212619812573-2l5f2cceb00ojf23iap67718vs623mt9.apps.googleusercontent.com';

  final _folderCtl = TextEditingController(text: '1V8O_Rt6AbGipOmqsxWt87gjjH58iBHBP');

  String _status = '';

  SystemTray? _tray;

  DriveService? _drive;

  AccessCredentials? _creds;

  bool _busy = false;



  Future<void> _signIn() async {

    setState(() { _busy = true; _status = 'Opening Google sign-in...'; });

    try {

      final svc = DriveService(ClientId(desktopClientId), httpFactory: () => http.Client());

      final creds = await svc.signInInteractive((uri) async { await launchUrl(uri, mode: LaunchMode.externalApplication); });

      await widget.storage.writeCredentials(creds);

      setState(() { _drive = svc; _creds = creds; _status = 'Signed in.'; });

    } catch (e) {

      setState(() { _status = 'Sign-in failed: $e'; });

    } finally {

      setState(() { _busy = false; });

    }

  }



  Future<void> _validateFolder() async {

    if (_drive == null && _creds != null) {

      final svc = DriveService(ClientId(desktopClientId), httpFactory: () => http.Client());

      await svc.signIn(_creds);

      _drive = svc;

    }

    if (_drive == null) {

      setState(() { _status = 'Please sign in first.'; });

      return;

    }

    setState(() { _busy = true; _status = 'Validating folder ID...'; });

    try {

      final f = await _drive!.getFile(_folderCtl.text.trim());

      if (f == null || f.mimeType != 'application/vnd.google-apps.folder') {

        setState(() { _status = 'Folder not found or not a Drive folder.'; });

        return;

      }

      await widget.storage.writeFolderId(_folderCtl.text.trim());

      setState(() { _status = 'Folder saved: ${f.name}'; });

    } catch (e) {

      setState(() { _status = 'Validation failed: $e'; });

    } finally {

      setState(() { _busy = false; });

    }

  }



  Future<void> _createFolder() async {

    if (_drive == null && _creds != null) {

      final svc = DriveService(ClientId(desktopClientId), httpFactory: () => http.Client());

      await svc.signIn(_creds);

      _drive = svc;

    }

    if (_drive == null) {

      setState(() { _status = 'Please sign in first.'; });

      return;

    }

    setState(() { _busy = true; _status = 'Creating folder in Drive...'; });

    try {

      final folder = await _drive!.createFolder(name: 'MyAppSync');

      _folderCtl.text = folder.id!;

      await widget.storage.writeFolderId(folder.id!);

      setState(() { _status = 'Folder created: ${folder.name}'; });

    } catch (e) {

      setState(() { _status = 'Create failed: $e'; });

    } finally {

      setState(() { _busy = false; });

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('First-run Setup')),

      body: Center(

        child: OutlinedButton(

          onPressed: _busy

              ? null

              : () {

                  Navigator.of(context).pushReplacement(

                    MaterialPageRoute(

                      builder: (_) => HomeScreen(

                        storage: widget.storage,

                        initialCreds: null,

                        folderId: 'LOCAL',

                        bypassDrive: true,

                      ),

                    ),

                  );

                },

          child: const Text('Continue without Drive'),

        ),

      ),

    );

  }

}



class HomeScreen extends StatefulWidget {

  final AppStorage storage;

  final AccessCredentials? initialCreds;

  final String folderId;

  final bool bypassDrive;

  final int? initialNavIndex;

  const HomeScreen({super.key, required this.storage, required this.initialCreds, required this.folderId, required this.bypassDrive, this.initialNavIndex});

  @override

  State<HomeScreen> createState() => _HomeScreenState();

}



class _HomeScreenState extends State<HomeScreen> {

  int? _hoveredMenuIndex;

  bool _sidebarCollapsed = false;

  static _HomeScreenState? _instance;

  static void _notifyGlobalUserActivity() {

    _instance?._onGlobalUserActivity();

  }



  static const desktopClientId = '212619812573-2l5f2cceb00ojf23iap67718vs623mt9.apps.googleusercontent.com';

  DriveService? _drive;

  String _status = '';

  SystemTray? _tray;

  Timer? _timer;

  Timer? _exportTimer;

  Timer? _rentalExportTimer;

  Timer? _badgeTimer;

  Timer? _dashboardStatsTimer;

  Timer? _inactivityTimer;

  Timer? _inactivityWarningTimer;

  OverlayEntry? _inactivityWarningOverlay;

  bool _autoLogoutInProgress = false;

  AppDatabase? _db;

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  String? _lastCsvName;

  String? _lastCsvPreview;

  int _navIndex = 0; // 0=Dashboard, 1=Files, 2=Agent Working, 3=Rental, 4=To-Do, 5=Settings, 6=Trading (unified), 7=Trading (unified), 8=Users, 9=Companies (Super Admin only), 10=Expenditure

  bool _showSidebar = true; // Toggle for sidebar visibility

  bool _sidebarManuallyToggled = false;

  int? _badgeFiles;

  int? _badgeProps;

  int? _badgeRentals;

  String? _rentalFilterStatus; // Filter status for Rental Items: 'Not Sold', 'Sold', 'Maintenance'

  String? _agentWorkingFilter; // Filter for Agent Working: 'daily_logs', 'performance_stats', 'commission_reports'

  // Dashboard detail view state

  String? _dashboardDetailTitle;

  String? _dashboardDetailType;

  String? _dashboardDetailStatus;

  List<Map<String, dynamic>> _dashboardDetailData = [];

  String _agentName = 'Farooq';

  String _dashboardTheme = 'system';

  Map<String, dynamic>? _currentUser; // Current logged-in user info

  bool _isSuperAdmin = true; // Force super admin - always true

  // Dashboard statistics

  int _dashboardActiveFiles = 0;

  double _dashboardMonthlyExpenditure = 0;

  int _dashboardTotalAgents = 0;

  int _totalFiles = 0;

  int _filesForSale = 0;

  int _filesSoldThisMonth = 0;

  int _filesSoldLastMonth = 0;

  int _totalProperties = 0;

  int _propertiesForSale = 0;

  int _propertiesSoldThisMonth = 0;

  int _propertiesSoldLastMonth = 0;

  int _totalRentalItems = 0;

  int _rentalItemsForSale = 0;

  int _rentalItemsSoldThisMonth = 0;

  int _rentalItemsSoldLastMonth = 0;

  

  // Next Actions data

  Map<String, dynamic>? _nextTodoTask;

  int _pendingTradesCount = 0;

  

  // Performance chart data (last 6 months)

  List<Map<String, dynamic>> _performanceData = [];



  Duration _delayUntilNext7am() {

    final now = DateTime.now();

    final today7 = DateTime(now.year, now.month, now.day, 7, 0);

    final target = now.isBefore(today7) ? today7 : today7.add(const Duration(days: 1));

    return target.difference(now);

  }





  Duration _delayUntilNext9pm() {

    final now = DateTime.now();

    final today9pm = DateTime(now.year, now.month, now.day, 21, 0);

    final target = now.isBefore(today9pm) ? today9pm : today9pm.add(const Duration(days: 1));

    return target.difference(now);

  }



  Future<void> _initNotifications() async {

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwin = DarwinInitializationSettings();

    const windows = WindowsInitializationSettings(

      appName: 'Easy Realtors Pro',

      appUserModelId: 'com.easyrealtorspro.desktop',

      guid: '8c9f5be0-1111-4b25-9c2e-000000000001',

    );

    const init = InitializationSettings(

      android: android,

      iOS: darwin,

      macOS: darwin,

      windows: windows,

    );

    await _notifications.initialize(init);

  }



  void _onGlobalUserActivity() {

    _resetInactivityTimer();

  }



  void _removeInactivityWarningOverlay() {

    try {

      _inactivityWarningOverlay?.remove();

    } catch (_) {}

    _inactivityWarningOverlay = null;

  }



  void _showInactivityWarning() {

    if (!mounted) return;

    if (_autoLogoutInProgress) return;

    if (_currentUser == null) return;



    _removeInactivityWarningOverlay();

    final overlay = Overlay.of(context, rootOverlay: true);

    if (overlay == null) return;



    _inactivityWarningOverlay = OverlayEntry(

      builder: (ctx) {

        final size = MediaQuery.of(ctx).size;

        final maxW = size.width < 520 ? size.width * 0.92 : 420.0;

        return Positioned(

          top: 24,

          right: 24,

          child: Material(

            color: Colors.transparent,

            child: ConstrainedBox(

              constraints: BoxConstraints(maxWidth: maxW),

              child: Card(

                elevation: 6,

                child: Padding(

                  padding: const EdgeInsets.all(12),

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),

                      const SizedBox(width: 10),

                      Expanded(

                        child: Text(

                          'Your session is about to expire. Click anywhere to stay logged in.',

                          style: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),

                        ),

                      ),

                      const SizedBox(width: 10),

                      TextButton(

                        onPressed: _resetInactivityTimer,

                        child: const Text('Stay Logged In'),

                      ),

                    ],

                  ),

                ),

              ),

            ),

          ),

        );

      },

    );

    overlay.insert(_inactivityWarningOverlay!);

  }



  void _resetInactivityTimer() {

    if (_currentUser == null) return;

    if (_autoLogoutInProgress) return;

    _inactivityTimer?.cancel();

    _inactivityWarningTimer?.cancel();

    _removeInactivityWarningOverlay();

    _inactivityWarningTimer = Timer(const Duration(minutes: 58), _showInactivityWarning);

    _inactivityTimer = Timer(const Duration(minutes: 60), _handleInactivityTimeout);

  }



  void _refreshInactivityTimerForRole() {

    if (_currentUser == null) {

      _inactivityTimer?.cancel();

      _inactivityWarningTimer?.cancel();

      _removeInactivityWarningOverlay();

      return;

    }

    _resetInactivityTimer();

  }



  Future<void> _handleInactivityTimeout() async {

    if (!mounted) return;

    if (_autoLogoutInProgress) return;

    if (_currentUser == null) return;



    _autoLogoutInProgress = true;

    _removeInactivityWarningOverlay();

    try {

      final storage = AppStorage();

      final settings = await storage.readSettings();

      final sessionId = settings['currentSessionId'] as String?;

      await AuthService().logout(sessionId);

      FirestoreCacheService().clearCache();

      await storage.deleteCredentials();

      await storage.deleteFolderId();

    } catch (_) {}



    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(

      MaterialPageRoute(builder: (_) => const LoginPage()),

      (route) => false,

    );

  }



  @override

  void initState() {

    super.initState();

    _instance = this;

    _init();

  }



  Future<void> _init() async {

    if (!widget.bypassDrive) {

      final svc = DriveService(ClientId(desktopClientId), httpFactory: () => http.Client());

      await svc.signIn(widget.initialCreds);

      setState(() { _drive = svc; });

    }

    await _openDb();

    await _syncCompaniesFromFirestoreHome();



    // Ensure dynamic trading tables have required columns even if user never opens Trading screens

    try {

      await _db!.customStatement('ALTER TABLE trading_file_entries ADD COLUMN company_id TEXT');

    } catch (_) {}

    try {

      await _db!.customStatement('ALTER TABLE trading_file_entries ADD COLUMN person_name TEXT');

    } catch (_) {}

    try {

      await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN company_id TEXT');

    } catch (_) {}



    // Initialize system tray (Desktop only, not web/mobile)

    if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {

      try {

        final appWindow = AppWindow();

        final tray = SystemTray();

        await tray.initSystemTray(title: 'Real EMS', iconPath: 'assets/app_icon.ico');

        await tray.setToolTip('Real Estate Management System');

        tray.registerSystemTrayEventHandler((eventName) async {

          if (eventName == kSystemTrayEventRightClick || eventName == kSystemTrayEventClick) {

            appWindow.show();

          }

        });

        setState(() { _tray = tray; });

      } catch (_) {}

    }

    _navIndex = widget.initialNavIndex ?? 0;

    // Load settings for agent name and theme

    final s = await widget.storage.readSettings();

    final sidebarCollapsed = s['sidebarCollapsed'] as bool?;

    if (sidebarCollapsed != null && mounted) {

      setState(() {

        _sidebarManuallyToggled = true;

        _showSidebar = !sidebarCollapsed;

      });

    }

    _agentName = (s['agentName'] as String?) ?? 'Farooq';

    final savedTheme = (s['theme'] as String?) ?? 'light';

    _dashboardTheme = (savedTheme == 'dark' || savedTheme == 'light') ? savedTheme : 'light';

    // Load current user info and check if Super Admin

    final authToken = s['authToken'] as String?;

    if (authToken != null) {

      final authService = AuthService();

      final user = await authService.getCurrentUser(authToken);

      if (user != null) {

        setState(() {

          _currentUser = user;

          _isSuperAdmin = true; // Force super admin

        });

        _refreshInactivityTimerForRole();

        // FIX: Check if Umer Shahzad needs role update
        if (user['email']?.toString().toLowerCase() == 'umershahzad596@gmail.com' && _db != null) {
          debugPrint('ROLE FIX: Checking Umer Shahzad role...');
          final currentRole = RoleUtils.getUserRole(user);
          if (currentRole == 'agent') {
            debugPrint('ROLE FIX: Updating Umer Shahzad role from agent to company_admin...');
            try {
              final companyAdminPermissions = RoleUtils.createCompanyAdminPermissions();
              await _db!.customStatement(
                'UPDATE users SET permissions = ?, updated_at = ? WHERE email = ?',
                [
                  companyAdminPermissions,
                  DateTime.now().toUtc().toIso8601String(),
                  'umershahzad596@gmail.com'
                ]
              );
              debugPrint('ROLE FIX: ✅ Successfully updated Umer Shahzad role to company_admin');
              
              // Reload user data with new role
              final updatedUser = await authService.getCurrentUser(authToken);
              if (updatedUser != null) {
                setState(() {
                  _currentUser = updatedUser;
                });
                debugPrint('ROLE FIX: ✅ Reloaded user data with new role: ${RoleUtils.getUserRole(updatedUser)}');
              }
            } catch (e) {
              debugPrint('ROLE FIX: ❌ Error updating Umer Shahzad role: $e');
            }
          } else {
            debugPrint('ROLE FIX: Umer Shahzad already has role: $currentRole');
          }
        }

      }

    }



    await _backfillCompanyIdIfNeeded();

    _runRetention();

    _timer = Timer.periodic(const Duration(hours: 1), (_) => _runRetention());

    // Schedule exports hourly

    _runExport();

    _exportTimer = Timer.periodic(const Duration(hours: 1), (_) => _runExport());

    _runRentalExport();

    _rentalExportTimer = Timer.periodic(const Duration(hours: 1), (_) => _runRentalExport());

    // Badges

    await _refreshBadges();

    _badgeTimer = Timer.periodic(const Duration(minutes: 2), (_) => _refreshBadges());

    // Dashboard statistics

    await _loadDashboardStats();

    _dashboardStatsTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadDashboardStats());

    // Initialize notifications

    await _initNotifications();

  }



  @override

  void dispose() {

    _instance = null;

    _badgeTimer?.cancel();

    _dashboardStatsTimer?.cancel();

    _timer?.cancel();

    _exportTimer?.cancel();

    _rentalExportTimer?.cancel();

    _inactivityTimer?.cancel();

    _inactivityWarningTimer?.cancel();

    _inactivityWarningOverlay?.remove();

    super.dispose();

  }



  Future<void> _persistSidebarCollapsed(bool collapsed) async {

    try {

      final s = await widget.storage.readSettings();

      s['sidebarCollapsed'] = collapsed;

      await widget.storage.writeSettings(s);

    } catch (_) {}

  }



  Future<void> _logout() async {

    final storage = AppStorage();

    try {

      final settings = await storage.readSettings();

      final sessionId = settings['currentSessionId'] as String?;

      await AuthService().logout(sessionId);

      FirestoreCacheService().clearCache();

    } catch (_) {}

    await storage.deleteCredentials();

    await storage.deleteFolderId();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(

      MaterialPageRoute(builder: (_) => const LoginPage()),

      (route) => false,

    );

  }



  void _denyAndGoDashboard(String message) {

    if (mounted) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(message), backgroundColor: Colors.red),

      );

      setState(() => _navIndex = 0);

    }

  }



  bool _canViewModules() {

    if (_currentUser == null) return false;

    return PermissionHelper.canView(_currentUser);

  }



  bool _canAccessNavIndex(int index) {

    if (_currentUser == null) return true;

    final isAgent = RoleUtils.isAgent(_currentUser);

    final roleStr = (_currentUser?['role'] ?? '').toString().toLowerCase();

    final isUserRole = roleStr == 'user';

    final isBypass = PermissionHelper.isBypassUser(_currentUser);

    final isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    // CRITICAL DEBUG: Log role information for Umer Shahzad
    if (_currentUser?['email']?.toString().toLowerCase() == 'umershahzad596@gmail.com') {
      debugPrint('USER DEBUG: Umer Shahzad role check');
      debugPrint('USER DEBUG: Email: ${_currentUser?['email']}');
      debugPrint('USER DEBUG: Company ID: ${_currentUser?['company_id']}');
      debugPrint('USER DEBUG: Permissions: ${_currentUser?['permissions']}');
      debugPrint('USER DEBUG: Role: ${RoleUtils.getUserRole(_currentUser)}');
      debugPrint('USER DEBUG: isBypass: $isBypass');
      debugPrint('USER DEBUG: isCompanyAdmin: $isCompanyAdmin');
      debugPrint('USER DEBUG: isSuperAdmin: $isSuperAdmin');
      debugPrint('USER DEBUG: PermissionHelper.canViewModule(users): ${PermissionHelper.canViewModule(_currentUser, 'users')}');
      debugPrint('USER DEBUG: showUsers: ${isSuperAdmin || ((isBypass || isCompanyAdmin) && PermissionHelper.canViewModule(_currentUser, 'users'))}');
    }
    
    // Always allow Dashboard + My Profile/Settings

    if (index == 0 || index == 5) return true;

    String? moduleKey;

    switch (index) {

      case 1:

        moduleKey = 'inventory';

        break;

      case 2:

        moduleKey = 'agent_working';

        break;

      case 3:

        moduleKey = 'rental_items';

        break;

      case 4:

        moduleKey = 'todo';

        break;

      case 6:

      case 7:

        moduleKey = 'trading';

        break;

      case 8:

        moduleKey = 'users';

        break;

      case 9:

        moduleKey = 'companies';

        break;

      case 10:

        moduleKey = 'expenditure';

        break;

      default:

        moduleKey = null;

    }

    if (moduleKey != null && !PermissionHelper.canViewModule(_currentUser, moduleKey)) return false;

    // Agent/User role restrictions

    if (!isBypass && (isAgent || isUserRole)) {

      if (index == 2 || index == 8 || index == 9) return false;

    }

    // Company Admin should not access Companies

    if (!isBypass && isCompanyAdmin && index == 9 && !isSuperAdmin) return false;

    // Users restricted to admins (Company Admin or Super Admin)

    if (!isBypass && index == 8 && !(isSuperAdmin || isCompanyAdmin)) return false;

    return true;

  }



  String? _formatRegistrationDate(dynamic raw) {

    if (raw == null) return null;

    final s = raw.toString().trim();

    if (s.isEmpty) return null;

    final dt = DateTime.tryParse(s);

    if (dt == null) return null;

    final local = dt.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    final d = two(local.day);

    final m = two(local.month);

    final y = local.year.toString();

    final hh = two(local.hour);

    final mm = two(local.minute);

    return '$d-$m-$y | $hh:$mm';

  }



  Future<void> _backfillCompanyIdIfNeeded() async {

    if (_db == null) return;

    if (_currentUser == null) return;

    if (!RoleUtils.isCompanyAdmin(_currentUser)) return;



    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    if (companyId == null || companyId.isEmpty) return;



    final settings = await widget.storage.readSettings();

    final flagKey = 'backfill_company_id_v15_$companyId';



    // Always ensure trading tables have company_id (they're created dynamically on some installs)

    try {

      await _db!.customStatement('ALTER TABLE trading_file_entries ADD COLUMN company_id TEXT');

    } catch (_) {}

    try {

      await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN company_id TEXT');

    } catch (_) {}

    try {

      await _db!.customStatement('ALTER TABLE expenditure_projects ADD COLUMN company_id TEXT');

    } catch (_) {}



    final alreadyDone = settings[flagKey] == true;

    if (alreadyDone) return;



    final statements = <String>[

      "UPDATE societies SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE blocks SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE properties SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE property_comments SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE files_table SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE file_comments SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE rental_items SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE rental_comments SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE working_progress SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE working_comments SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE trading_file_entries SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE trading_entries SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE Expenditures SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE expenditure_projects SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE reports SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE deletions SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE sync_logs SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

      "UPDATE clients SET company_id = ? WHERE company_id IS NULL OR company_id = ''",

    ];



    try {

      await _db!.transaction(() async {

        for (final stmt in statements) {

          try {

            await _db!.customStatement(stmt, [companyId]);

          } catch (e) {

            // Some tables/columns may not exist in older installs; ignore safely

            debugPrint('Backfill skipped statement due to error: $e');

          }

        }

      });



      await widget.storage.writeSettings({...settings, flagKey: true});

      debugPrint('Backfill complete for companyId=$companyId');

    } catch (e) {

      debugPrint('Backfill failed for companyId=$companyId: $e');

    }

  }



  void _updateCsvPreview(String name, String csv) {

    // Keep preview short to avoid UI lag

    final lines = const LineSplitter().convert(csv);

    final head = lines.take(100).join('\n');

    setState(() {

      _lastCsvName = name;

      _lastCsvPreview = head;

    });

  }



  Future<void> _refreshBadges() async {

    if (_db == null) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    final companyId = RoleUtils.getUserCompanyId(_currentUser);



    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {

      return;

    }



    Future<int> countSince(String table, String module, String? since) async {

      int total = 0;

      if (since != null) {

        final r1 = await _db!.customSelect(

          isSuperAdmin

              ? 'SELECT COUNT(*) AS c FROM ' + table + ' WHERE updated_at > ?'

              : 'SELECT COUNT(*) AS c FROM ' + table + ' WHERE company_id = ? AND updated_at > ?',

          variables: isSuperAdmin

              ? [d.Variable.withString(since)]

              : [d.Variable.withString(companyId!), d.Variable.withString(since)],

        ).getSingle();

        total += (r1.data['c'] as int);

        final r2 = await _db!.customSelect(

          isSuperAdmin

              ? 'SELECT COUNT(*) AS c FROM deletions WHERE module = ? AND updated_at > ?'

              : 'SELECT COUNT(*) AS c FROM deletions WHERE module = ? AND company_id = ? AND updated_at > ?',

          variables: isSuperAdmin

              ? [d.Variable.withString(module), d.Variable.withString(since)]

              : [d.Variable.withString(module), d.Variable.withString(companyId!), d.Variable.withString(since)],

        ).getSingle();

        total += (r2.data['c'] as int);

      } else {

        final r1 = await _db!.customSelect(

          isSuperAdmin ? 'SELECT COUNT(*) AS c FROM ' + table : 'SELECT COUNT(*) AS c FROM ' + table + ' WHERE company_id = ?',

          variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],

        ).getSingle();

        total += (r1.data['c'] as int);

      }

      return total;

    }

    final propsSince = await widget.storage.readLastExportTs('properties');

    final rentSince = await widget.storage.readLastExportTs('rental_items');

    final filesSince = await widget.storage.readLastExportTs('files');

    final p = await countSince('properties', 'properties', propsSince);

    final r = await countSince('rental_items', 'rental_items', rentSince);

    final f = await countSince('files_table', 'files', filesSince);

    if (!mounted) return;

    setState(() {

      _badgeProps = p;

      _badgeRentals = r;

      _badgeFiles = f;

    });

  }



  Future<void> _loadDashboardStats() async {

    if (_db == null) return;

    final now = DateTime.now();

    final monthStart = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    final monthKey = DateFormat('yyyy-MM').format(now);

    final isSuper = RoleUtils.isSuperAdmin(_currentUser) || PermissionHelper.isBypassUser(_currentUser);

    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    

    // Calculate previous month range

    final prevMonth = DateTime(now.year, now.month - 1, 1);

    final prevMonthStart = prevMonth.toUtc().toIso8601String();

    final prevMonthEnd = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    

    final today = DateTime(now.year, now.month, now.day);

    final tomorrow = today.add(const Duration(days: 1));

    final todayStr = today.toIso8601String().split('T')[0];

    final tomorrowStr = tomorrow.toIso8601String().split('T')[0];



    // Headline stats (company-scoped)

    final activeFilesRow = await _db!.customSelect(

      isSuper

          ? "SELECT COUNT(*) AS c FROM trading_entries WHERE (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1)"

          : "SELECT COUNT(*) AS c FROM trading_entries WHERE (status IS NULL OR status != 'archived') AND (is_active IS NULL OR is_active = 1) AND company_id = ?",

      variables: isSuper ? [] : [d.Variable.withString(companyId ?? '')],

    ).getSingle();

    final monthlyExpenditureRow = await _db!.customSelect(

      isSuper

          ? "SELECT COALESCE(SUM(amount), 0) AS total FROM Expenditures WHERE kind = 'office' AND office_month = ?"

          : "SELECT COALESCE(SUM(amount), 0) AS total FROM Expenditures WHERE company_id = ? AND kind = 'office' AND office_month = ?",

      variables: isSuper

          ? [d.Variable.withString(monthKey)]

          : [d.Variable.withString(companyId ?? ''), d.Variable.withString(monthKey)],

    ).getSingle();

    final totalAgentsRow = await _db!.customSelect(

      isSuper

          ? "SELECT COUNT(*) AS c FROM users WHERE (is_active IS NULL OR is_active = 1) AND (status IS NULL OR LOWER(status) = 'active')"

          : "SELECT COUNT(*) AS c FROM users WHERE (is_active IS NULL OR is_active = 1) AND (status IS NULL OR LOWER(status) = 'active') AND (company_id = ? OR company_id = ?)",

      variables: isSuper ? [] : [d.Variable.withString(companyId ?? ''), d.Variable.withString(companyId ?? '')],

    ).getSingle();



    // Filing System statistics

    final totalFiles = await _db!.customSelect('SELECT COUNT(*) AS c FROM files_table', readsFrom: {_db!.filesTable}).getSingle();

    final filesForSale = await _db!.customSelect("SELECT COUNT(*) AS c FROM files_table WHERE (sale_status = 'Not Sale' OR sale_status = 'Not Sold' OR sale_status IS NULL)", readsFrom: {_db!.filesTable}).getSingle();

    final filesSoldThisMonth = await _db!.customSelect("SELECT COUNT(*) AS c FROM files_table WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= ?", variables: [d.Variable.withString(monthStart)], readsFrom: {_db!.filesTable}).getSingle();

    final filesSoldLastMonth = await _db!.customSelect("SELECT COUNT(*) AS c FROM files_table WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= ? AND updated_at < ?", variables: [d.Variable.withString(prevMonthStart), d.Variable.withString(prevMonthEnd)], readsFrom: {_db!.filesTable}).getSingle();



    // Properties statistics

    final totalProperties = await _db!.customSelect('SELECT COUNT(*) AS c FROM properties', readsFrom: {_db!.properties}).getSingle();

    final propertiesForSale = await _db!.customSelect("SELECT COUNT(*) AS c FROM properties WHERE (sale_status = 'Not Sale' OR sale_status = 'Not Sold' OR sale_status IS NULL)", readsFrom: {_db!.properties}).getSingle();

    final propertiesSoldThisMonth = await _db!.customSelect("SELECT COUNT(*) AS c FROM properties WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= ?", variables: [d.Variable.withString(monthStart)], readsFrom: {_db!.properties}).getSingle();

    final propertiesSoldLastMonth = await _db!.customSelect("SELECT COUNT(*) AS c FROM properties WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= ? AND updated_at < ?", variables: [d.Variable.withString(prevMonthStart), d.Variable.withString(prevMonthEnd)], readsFrom: {_db!.properties}).getSingle();



    // Rental Items statistics

    final totalRentalItems = await _db!.customSelect('SELECT COUNT(*) AS c FROM rental_items', readsFrom: {_db!.rentalItems}).getSingle();

    final rentalItemsSoldThisMonth = await _db!.customSelect('SELECT COUNT(*) AS c FROM rental_items WHERE updated_at >= ?', variables: [d.Variable.withString(monthStart)], readsFrom: {_db!.rentalItems}).getSingle();

    final rentalItemsSoldLastMonth = await _db!.customSelect('SELECT COUNT(*) AS c FROM rental_items WHERE updated_at >= ? AND updated_at < ?', variables: [d.Variable.withString(prevMonthStart), d.Variable.withString(prevMonthEnd)], readsFrom: {_db!.rentalItems}).getSingle();



    // Load Performance Chart Data (last 6 months)

    final performanceData = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {

      final monthDate = DateTime(now.year, now.month - i, 1);

      final monthStartStr = monthDate.toUtc().toIso8601String();

      final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);

      final monthEndStr = nextMonth.toUtc().toIso8601String();

      

      // Calculate total value for this month (sum of prices/demands from sold items)

      final filesValue = await _db!.customSelect(

        "SELECT COALESCE(SUM(demand), 0) AS total FROM files_table WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= ? AND updated_at < ?",

        variables: [d.Variable.withString(monthStartStr), d.Variable.withString(monthEndStr)],

        readsFrom: {_db!.filesTable}

      ).getSingle();

      

      final propertiesValue = await _db!.customSelect(

        "SELECT COALESCE(SUM(price), 0) AS total FROM properties WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= ? AND updated_at < ?",

        variables: [d.Variable.withString(monthStartStr), d.Variable.withString(monthEndStr)],

        readsFrom: {_db!.properties}

      ).getSingle();

      

      final rentalValue = await _db!.customSelect(

        "SELECT COALESCE(SUM(price), 0) AS total FROM rental_items WHERE updated_at >= ? AND updated_at < ?",

        variables: [d.Variable.withString(monthStartStr), d.Variable.withString(monthEndStr)],

        readsFrom: {_db!.rentalItems}

      ).getSingle();

      

      // OPTIMIZATION: Convert all int values to double to prevent type-cast errors
      final filesValueDouble = (filesValue.data['total'] as int? ?? 0).toDouble();
      final propertiesValueDouble = (propertiesValue.data['total'] as int? ?? 0).toDouble();
      final rentalValueDouble = (rentalValue.data['total'] as int? ?? 0).toDouble();
      
      final totalValue = filesValueDouble + propertiesValueDouble + rentalValueDouble;

      

      // Format month name clearly - use abbreviated month with year

      // Format: "Jul 2025" for clear display

      final monthName = DateFormat('MMM yyyy').format(monthDate);

      

      performanceData.add({

        'month': monthName,

        'value': totalValue,

      });

    }



    // Load Next Actions - To-Do task

    Map<String, dynamic>? nextTodo;

    try {

      final todos = await _db!.customSelect(

        'SELECT reminder_id, reminder_title, reminder_date, reminder_time FROM reminders ORDER BY reminder_date ASC, reminder_time ASC LIMIT 1',

      ).get();

      if (todos.isNotEmpty) {

        nextTodo = {

          'title': todos.first.data['reminder_title']?.toString() ?? '',

          'date': todos.first.data['reminder_date']?.toString() ?? '',

          'time': todos.first.data['reminder_time']?.toString() ?? '',

        };

      }

    } catch (e) {

      debugPrint('Error loading To-Do: $e');

    }



    // Load Pending Trades Count

    int pendingTrades = 0;

    try {

      // Check Trading File entries (assuming pending means not completed)

      final tradingFileCount = await _db!.customSelect(

        'SELECT COUNT(*) AS c FROM working_progress WHERE category LIKE ?',

        variables: [d.Variable.withString('%Trading%')],

        readsFrom: {_db!.workingProgress}

      ).getSingle();

      pendingTrades = tradingFileCount.data['c'] as int? ?? 0;

    } catch (e) {

      debugPrint('Error loading pending trades: $e');

    }



    if (!mounted) return;



    setState(() {

      _dashboardActiveFiles = activeFilesRow.data['c'] as int? ?? 0;

      _dashboardMonthlyExpenditure = (monthlyExpenditureRow.data['total'] as num?)?.toDouble() ?? 0.0;

      _dashboardTotalAgents = totalAgentsRow.data['c'] as int? ?? 0;

      _totalFiles = totalFiles.data['c'] as int;

      _filesForSale = filesForSale.data['c'] as int;

      _filesSoldThisMonth = filesSoldThisMonth.data['c'] as int;

      _filesSoldLastMonth = filesSoldLastMonth.data['c'] as int;

      _totalProperties = totalProperties.data['c'] as int;

      _propertiesForSale = propertiesForSale.data['c'] as int;

      _propertiesSoldThisMonth = propertiesSoldThisMonth.data['c'] as int;

      _propertiesSoldLastMonth = propertiesSoldLastMonth.data['c'] as int;

      _totalRentalItems = totalRentalItems.data['c'] as int;

      _rentalItemsSoldThisMonth = rentalItemsSoldThisMonth.data['c'] as int;

      _rentalItemsSoldLastMonth = rentalItemsSoldLastMonth.data['c'] as int;

      _rentalItemsForSale = _totalRentalItems - _rentalItemsSoldThisMonth;

      _performanceData = performanceData;

      _nextTodoTask = nextTodo;

      _pendingTradesCount = pendingTrades;

    });

  }



  Future<void> _runRetention() async {

    if (_drive == null) return;

    if (!mounted) return;

    setState(() { _status = 'Running retention...'; });

    try {

      final service = DriveRetentionService(_drive!);

      final deleted = await service.enforceRetention(widget.folderId);

      if (!mounted) return;

      setState(() { _status = 'Retention done. Deleted ${deleted.length} old files.'; });

    } catch (e) {

      if (!mounted) return;

      setState(() { _status = 'Retention failed: $e'; });

    }

  }



  Future<void> _openDb() async {

    _db = await AppDatabase.instance();

    await _ensureReportSchemaUpgrades();

  }



  Future<void> _ensureReportSchemaUpgrades() async {

    if (_db == null) return;



    await _ensureCompanyBrandingColumns();

    await _ensureExpenditureCategoryColumn();

    await _ensureTradingReportColumns();

  }



  Future<void> _syncCompaniesFromFirestoreHome() async {

    debugPrint('STRIKE 1 (home): Entering sync function');

    debugPrint('STRIKE 2 (home): Firebase apps count: ${Firebase.apps.length}');

    debugPrint('DB PATH (home sync): ${_db?.executor}');

    if (Firebase.apps.isEmpty) {

      debugPrint('STRIKE 3 (home): Firebase is NOT initialized!');

      return;

    }

    if (_db == null) return;

    try {

      debugPrint('DEBUG HOME: syncCompaniesFromFirestore started...');

      // Enhanced with FirebaseThreadingHandler for Windows compatibility
      final snap = await FirebaseThreadingHandler.executeWithThreadSafety(
        () => FirebaseFirestore.instance.collection('companies').get(),
        operationName: 'Home syncCompaniesFromFirestore',
      );

      debugPrint('Firestore docs found (home): ${snap.docs.length}');

      if (snap.docs.isEmpty) return;



      final nowIso = DateTime.now().toUtc().toIso8601String();

      await _db!.batch((batch) {

        for (final doc in snap.docs) {

          debugPrint('Attempting to sync company ID (home): ${doc.id}');

          final data = doc.data();

          debugPrint('Writing to SQLite (home): ${doc.id} - ${data['name']}');

          final id = doc.id.toString();

          if (id.trim().isEmpty) continue;



          final name = (data['name'] ?? 'No Name').toString();

          final status = (data['status'] ?? 'inactive').toString();

          final metadataRaw = data['metadata'];

          final metadata = metadataRaw == null

              ? null

              : (metadataRaw is String ? metadataRaw : jsonEncode(metadataRaw));

          final logoUrl = (data['logo_url'] ?? data['logoUrl'])?.toString();

          final address = data['address']?.toString();

          final contact = data['contact']?.toString();

          final maxRaw = data['max_user_limit'] ?? data['maxUserLimit'] ?? 5;

          final maxUserLimit = maxRaw is int ? maxRaw : int.tryParse(maxRaw.toString());

          final tier = (data['subscription_tier'] ?? data['subscriptionTier'] ?? 'Starter').toString();

          final createdAt = (data['created_at'] ?? data['createdAt'] ?? nowIso).toString();

          final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? nowIso).toString();



          try {

            batch.customStatement(

              'INSERT OR REPLACE INTO companies (id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',

              [

                id,

                name,

                status,

                metadata,

                logoUrl,

                address,

                contact,

                maxUserLimit,

                tier,

                createdAt,

                updatedAt,

              ],

            );

          } catch (e) {

            debugPrint('SQLite Insert Error (home) for $id: $e');

          }

        }

      });



      try {

        final countRes = await _db!.customSelect('SELECT COUNT(*) AS c FROM companies').getSingle();

        debugPrint('SQLite companies row count (home): ${countRes.data['c']}');

      } catch (e) {

        debugPrint('SQLite count error (home): $e');

      }

    } catch (e) {

      debugPrint('Companies Firestore sync failed (home): $e');

    }

  }



  Future<void> _ensureCompanyBrandingColumns() async {

    if (_db == null) return;

    try {

      final cols = await _db!.customSelect('PRAGMA table_info(companies)').get();

      bool hasLogo = false;

      bool hasAddress = false;

      bool hasContact = false;

      for (final r in cols) {

        final n = r.data['name']?.toString();

        if (n == 'logo_url') hasLogo = true;

        if (n == 'address') hasAddress = true;

        if (n == 'contact') hasContact = true;

      }

      if (!hasLogo) {

        await _db!.customStatement('ALTER TABLE companies ADD COLUMN logo_url TEXT');

      }

      if (!hasAddress) {

        await _db!.customStatement('ALTER TABLE companies ADD COLUMN address TEXT');

      }

      if (!hasContact) {

        await _db!.customStatement('ALTER TABLE companies ADD COLUMN contact TEXT');

      }



      // Backfill structured columns from legacy metadata JSON where possible

      final rows = await _db!.customSelect('SELECT id, metadata, logo_url, address, contact FROM companies').get();

      for (final row in rows) {

        final id = (row.data['id'] ?? '').toString();

        if (id.isEmpty) continue;

        final metaRaw = row.data['metadata'];

        final existingLogo = (row.data['logo_url'] ?? '').toString().trim();

        final existingAddress = (row.data['address'] ?? '').toString().trim();

        final existingContact = (row.data['contact'] ?? '').toString().trim();

        if ((metaRaw == null || metaRaw.toString().trim().isEmpty) ||

            (existingLogo.isNotEmpty && existingAddress.isNotEmpty && existingContact.isNotEmpty)) {

          continue;

        }

        Map<String, dynamic> meta;

        try {

          final decoded = jsonDecode(metaRaw.toString());

          meta = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};

        } catch (_) {

          meta = <String, dynamic>{};

        }

        String pick(List<String> keys) {

          for (final k in keys) {

            final v = meta[k];

            if (v == null) continue;

            final s = v.toString().trim();

            if (s.isNotEmpty) return s;

          }

          return '';

        }

        final logo = existingLogo.isNotEmpty ? existingLogo : pick(['logo', 'logoUrl', 'logo_url', 'logoPath', 'logo_path', 'companyLogo', 'company_logo']);

        final address = existingAddress.isNotEmpty ? existingAddress : pick(['address', 'companyAddress', 'company_address']);

        final contact = existingContact.isNotEmpty ? existingContact : pick(['contact', 'contactNo', 'contact_no', 'phone', 'mobile', 'email']);

        if (logo.isEmpty && address.isEmpty && contact.isEmpty) continue;

        try {

          await _db!.customStatement(

            'UPDATE companies SET logo_url = COALESCE(NULLIF(logo_url, \'\'), ?), address = COALESCE(NULLIF(address, \'\'), ?), contact = COALESCE(NULLIF(contact, \'\'), ?) WHERE id = ?',

            [logo.isEmpty ? null : logo, address.isEmpty ? null : address, contact.isEmpty ? null : contact, id],

          );

        } catch (_) {}



        if (Firebase.apps.isNotEmpty) {

          try {

            await FirebaseFirestore.instance.collection('companies').doc(id).set(

              {

                'logoUrl': logo.isEmpty ? null : logo,

                'logo_url': logo.isEmpty ? null : logo,

                'address': address.isEmpty ? null : address,

                'contact': contact.isEmpty ? null : contact,

              },

              SetOptions(merge: true),

            );

          } catch (_) {}

        }

      }

    } catch (_) {}

  }



  Future<void> _ensureExpenditureCategoryColumn() async {

    if (_db == null) return;

    try {

      final cols = await _db!.customSelect('PRAGMA table_info(Expenditures)').get();

      final hasCategory = cols.any((r) => (r.data['name']?.toString()) == 'category');

      if (!hasCategory) {

        await _db!.customStatement('ALTER TABLE Expenditures ADD COLUMN category TEXT');

      }

    } catch (_) {}

  }



  Future<void> _ensureTradingReportColumns() async {

    if (_db == null) return;

    try {

      // trading_entries is created dynamically in TradingFormPage, so guard ALTERs.

      final cols = await _db!.customSelect('PRAGMA table_info(trading_entries)').get();

      bool hasBuyer = false;

      bool hasSeller = false;

      bool hasPlotNo = false;

      bool hasBlock = false;

      bool hasCommission = false;

      for (final r in cols) {

        final n = r.data['name']?.toString();

        if (n == 'buyer_name') hasBuyer = true;

        if (n == 'seller_name') hasSeller = true;

        if (n == 'plot_no') hasPlotNo = true;

        if (n == 'block') hasBlock = true;

        if (n == 'commission') hasCommission = true;

      }

      if (!hasBuyer) {

        await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN buyer_name TEXT');

      }

      if (!hasSeller) {

        await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN seller_name TEXT');

      }

      if (!hasPlotNo) {

        await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN plot_no TEXT');

      }

      if (!hasBlock) {

        await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN block TEXT');

      }

      if (!hasCommission) {

        await _db!.customStatement('ALTER TABLE trading_entries ADD COLUMN commission REAL');

      }

    } catch (_) {}

  }



  Future<void> _runExport({bool full = false}) async {

    if (_drive == null || _db == null) return;

    setState(() { _status = 'Exporting properties...'; });

    try {

      final since = full ? null : await widget.storage.readLastExportTs('properties');

      final changed = await _queryChangedProperties(since);

      final deletes = await _queryPropertyDeletes(since);

      if (changed.isEmpty && deletes.isEmpty) {

        setState(() { _status = 'No property changes to export.'; });

        return;

      }

      final exportId = await widget.storage.nextExportId('properties');

      final now = DateTime.now().toUtc();

      final ts = fmtTs(now);

      final rows = <CsvExportRow>[];

      rows.addAll(changed.map((r) => CsvExportRow(

            exportId: exportId.toString(),

            module: 'properties',

            operation: 'UPDATE',

            id: r['id']!,

            updatedAt: r['updatedAt']!,

            data: {

              'property_name': r['property_name'] ?? '',

              'price': r['price'] ?? '',

              'remarks': r['remarks'] ?? '',

              'society_id': r['society_id'] ?? '',

              'block_id': r['block_id'] ?? '',

            },

          )));

      rows.addAll(deletes.map((d) => CsvExportRow(

            exportId: exportId.toString(),

            module: 'properties',

            operation: 'DELETE',

            id: d['id']!,

            updatedAt: d['updatedAt']!,

            data: const {},

          )));

      final csv = CsvUtils.writeExportCsv(rows);

      final name = 'export_properties_${ts}_${exportId}.csv';

      if (_drive == null || widget.bypassDrive) {

        final dir = await widget.storage.appDir();

        final f = io.File(p.join(dir.path, name));

        await f.writeAsString(csv);

        _updateCsvPreview(name, csv);

        setState(() { _status = 'Exported properties: ${rows.length} rows to ${f.path}'; });

      } else {

        await _drive!.uploadFile(folderId: widget.folderId, name: name, bytes: utf8.encode(csv));

      }

      // Advance last ts across changed + deletes

      final allTs = <String>[];

      allTs.addAll(changed.map((e) => e['updatedAt']!));

      allTs.addAll(deletes.map((e) => e['updatedAt']!));

      final maxTs = allTs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);

      await widget.storage.writeLastExportTs('properties', maxTs);

      await _refreshBadges();

      if (!widget.bypassDrive) { setState(() { _status = 'Exported properties: ${rows.length} rows as $name'; }); }

    } catch (e) {

      setState(() { _status = 'Export failed: $e'; });

    }

}

 

  Future<void> _runFilesExport({bool full = false}) async {

    if (_drive == null || _db == null) return;

    setState(() { _status = 'Exporting files...'; });

    try {

      final since = full ? null : await widget.storage.readLastExportTs('files');

      final changed = await _queryChangedFiles(since);

      final deletes = await _queryDeletes('files', since);

      if (changed.isEmpty && deletes.isEmpty) {

        setState(() { _status = 'No file changes to export.'; });

        return;

      }

      final exportId = await widget.storage.nextExportId('files');

      final ts = fmtTs(DateTime.now().toUtc());

      final rows = <CsvExportRow>[];

      for (final r in changed) {

        rows.add(CsvExportRow(

          exportId: exportId.toString(),

          module: 'files',

          operation: 'UPDATE',

          id: r['id']!,

          updatedAt: r['updatedAt']!,

          data: {

            'name': r['name'] ?? '',

            'society_id': r['society_id'] ?? '',

            'block_id': r['block_id'] ?? '',

            'path': r['path'] ?? '',

            'remarks': r['remarks'] ?? '',

          },

        ));

      }

      for (final d in deletes) {

        rows.add(CsvExportRow(

          exportId: exportId.toString(),

          module: 'files',

          operation: 'DELETE',

          id: d['id']!,

          updatedAt: d['updatedAt']!,

          data: const {},

        ));

      }

      final csv = CsvUtils.writeExportCsv(rows);

      final name = 'export_files_${ts}_${exportId}.csv';

      if (_drive == null || widget.bypassDrive) {

        final dir = await widget.storage.appDir();

        final f = io.File(p.join(dir.path, name));

        await f.writeAsString(csv);

        _updateCsvPreview(name, csv);

        setState(() { _status = 'Exported files: ${rows.length} rows to ${f.path}'; });

      } else {

        await _drive!.uploadFile(folderId: widget.folderId, name: name, bytes: utf8.encode(csv));

      }

      final allTs = <String>[];

      allTs..addAll(changed.map((e) => e['updatedAt']!))..addAll(deletes.map((e) => e['updatedAt']!));

      final maxTs = allTs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);

      await widget.storage.writeLastExportTs('files', maxTs);

      await _pruneDeletions('files', maxTs);

      await _refreshBadges();

      if (!widget.bypassDrive) { setState(() { _status = 'Exported files: ${rows.length} rows as $name'; }); }

    } catch (e) {

      setState(() { _status = 'Files export failed: $e'; });

    }

  }





  Future<void> _runRentalExport({bool full = false}) async {

    if (_drive == null || _db == null) return;

    setState(() { _status = 'Exporting rental items...'; });

    try {

      final since = full ? null : await widget.storage.readLastExportTs('rental_items');

      final changed = await _queryChangedRentalItems(since);

      final deletes = await _queryRentalDeletes(since);

      if (changed.isEmpty && deletes.isEmpty) {

        setState(() { _status = 'No rental changes to export.'; });

        return;

      }

      final exportId = await widget.storage.nextExportId('rental_items');

      final now = DateTime.now().toUtc();

      final ts = fmtTs(now);

      final rows = <CsvExportRow>[];

      for (final r in changed) {

        rows.add(CsvExportRow(

          exportId: exportId.toString(),

          module: 'rental_items',

          operation: 'UPDATE',

          id: r['id']!,

          updatedAt: r['updatedAt']!,

          data: {

            'name': r['name'] ?? '',

            'price': r['price'] ?? '',

            'remarks': r['remarks'] ?? '',

          },

        ));

      }

      for (final d in deletes) {

        rows.add(CsvExportRow(

          exportId: exportId.toString(),

          module: 'rental_items',

          operation: 'DELETE',

          id: d['id']!,

          updatedAt: d['updatedAt']!,

          data: const {},

        ));

      }

      final csv = CsvUtils.writeExportCsv(rows);

      final name = 'export_rental_items_${ts}_${exportId}.csv';

      if (_drive == null || widget.bypassDrive) {

        final dir = await widget.storage.appDir();

        final f = io.File(p.join(dir.path, name));

        await f.writeAsString(csv);

        _updateCsvPreview(name, csv);

      } else {

        await _drive!.uploadFile(folderId: widget.folderId, name: name, bytes: utf8.encode(csv));

      }

      // Advance last export ts using max of changed and delete timestamps

      final allTs = <String>[];

      allTs.addAll(changed.map((e) => e['updatedAt']!));

      allTs.addAll(deletes.map((e) => e['updatedAt']!));

      final maxTs = allTs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);

      await widget.storage.writeLastExportTs('rental_items', maxTs);

      await _refreshBadges();

      if (!widget.bypassDrive) { setState(() { _status = 'Exported rental: ${rows.length} rows as $name'; }); }

    } catch (e) {

      setState(() { _status = 'Rental export failed: $e'; });

    }

  }



  Future<List<Map<String, String>>> _queryChangedProperties(String? sinceIso) async {

    // Read directly using Drift generated schema

    final q = _db!.customSelect(

      sinceIso == null

          ? 'SELECT id, property_name, price, remarks, society_id, block_id, updated_at as updatedAt FROM properties'

          : 'SELECT id, property_name, price, remarks, society_id, block_id, updated_at as updatedAt FROM properties WHERE updated_at > ?',

      variables: sinceIso == null ? [] : [d.Variable.withString(sinceIso)],

      readsFrom: { _db!.properties },

    );

    final result = await q.get();

    return result.map((row) => {

      'id': row.data['id'] as String,

      'property_name': (row.data['property_name']?.toString()) ?? '',

      'price': (row.data['price']?.toString()) ?? '',

      'remarks': (row.data['remarks']?.toString()) ?? '',

      'society_id': (row.data['society_id']?.toString()) ?? '',

      'block_id': (row.data['block_id']?.toString()) ?? '',

      'updatedAt': row.data['updatedAt'] as String,

    }).toList();

  }



  Future<List<Map<String, String>>> _queryPropertyDeletes(String? sinceIso) async {

    final q = _db!.customSelect(

      sinceIso == null

          ? "SELECT entity_id as id, updated_at as updatedAt FROM deletions WHERE module = 'properties'"

          : "SELECT entity_id as id, updated_at as updatedAt FROM deletions WHERE module = 'properties' AND updated_at > ?",

      variables: sinceIso == null ? [] : [d.Variable.withString(sinceIso)],

      readsFrom: { _db!.deletions },

    );

    final result = await q.get();

    return result.map((row) => {

      'id': row.data['id'] as String,

      'updatedAt': row.data['updatedAt'] as String,

    }).toList();

  }



  Future<List<Map<String, String>>> _queryChangedFiles(String? sinceIso) async {

    final q = _db!.customSelect(

      sinceIso == null

          ? 'SELECT id, name, society_id, block_id, path, remarks, updated_at as updatedAt FROM files_table'

          : 'SELECT id, name, society_id, block_id, path, remarks, updated_at as updatedAt FROM files_table WHERE updated_at > ?',

      variables: sinceIso == null ? [] : [d.Variable.withString(sinceIso)],

      readsFrom: { _db!.filesTable },

    );

    final result = await q.get();

    return result.map((row) => {

      'id': row.data['id'] as String,

      'name': (row.data['name']?.toString()) ?? '',

      'society_id': (row.data['society_id']?.toString()) ?? '',

      'block_id': (row.data['block_id']?.toString()) ?? '',

      'path': (row.data['path']?.toString()) ?? '',

      'remarks': (row.data['remarks']?.toString()) ?? '',

      'updatedAt': row.data['updatedAt'] as String,

    }).toList();

  }





  Future<List<Map<String, String>>> _queryChangedRentalItems(String? sinceIso) async {

    final q = _db!.customSelect(

      sinceIso == null

          ? 'SELECT id, name, price, remarks, updated_at as updatedAt FROM rental_items'

          : 'SELECT id, name, price, remarks, updated_at as updatedAt FROM rental_items WHERE updated_at > ?',

      variables: sinceIso == null ? [] : [d.Variable.withString(sinceIso)],

      readsFrom: { _db!.rentalItems },

    );

    final result = await q.get();

    return result.map((row) => {

      'id': row.data['id'] as String,

      'name': (row.data['name']?.toString()) ?? '',

      'price': (row.data['price']?.toString()) ?? '',

      'remarks': (row.data['remarks']?.toString()) ?? '',

      'updatedAt': row.data['updatedAt'] as String,

    }).toList();

  }



  Future<List<Map<String, String>>> _queryRentalDeletes(String? sinceIso) async {

    final q = _db!.customSelect(

      sinceIso == null

          ? "SELECT entity_id as id, updated_at as updatedAt FROM deletions WHERE module = 'rental_items'"

          : "SELECT entity_id as id, updated_at as updatedAt FROM deletions WHERE module = 'rental_items' AND updated_at > ?",

      variables: sinceIso == null ? [] : [d.Variable.withString(sinceIso)],

      readsFrom: { _db!.deletions },

    );

    final result = await q.get();

    return result.map((row) => {

      'id': row.data['id'] as String,

      'updatedAt': row.data['updatedAt'] as String,

    }).toList();

  }



  Future<List<Map<String, String>>> _queryDeletes(String module, String? sinceIso) async {

    final q = _db!.customSelect(

      sinceIso == null

          ? "SELECT entity_id as id, updated_at as updatedAt FROM deletions WHERE module = ?"

          : "SELECT entity_id as id, updated_at as updatedAt FROM deletions WHERE module = ? AND updated_at > ?",

      variables: sinceIso == null ? [d.Variable.withString(module)] : [d.Variable.withString(module), d.Variable.withString(sinceIso)],

      readsFrom: { _db!.deletions },

    );

    final result = await q.get();

    return result.map((row) => {

      'id': row.data['id'] as String,

      'updatedAt': row.data['updatedAt'] as String,

    }).toList();

  }



  Future<void> _pruneDeletions(String module, String uptoIso) async {

    await _db!.customStatement('DELETE FROM deletions WHERE module = ? AND updated_at <= ?',

        [module, uptoIso]);

  }



  



  PreferredSizeWidget _gradientAppBar(String title) {

    return AppBar(

      elevation: 0,

      backgroundColor: Colors.transparent,

      flexibleSpace: Container(

        decoration: BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [

              const Color(0xFFFF6B35), // Orange

              const Color(0xFF4A90E2), // Blue

            ],

          ),

        ),

        child: SafeArea(

          bottom: false,

          child: Center(

            child: Padding(

              padding: const EdgeInsets.symmetric(horizontal: 72),

              child: Text(

                'Real Estate Management System',

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                textAlign: TextAlign.center,

                style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),

              ),

            ),

          ),

        ),

      ),

      actions: [

        IconButton(

          icon: const Icon(Icons.logout, color: Colors.white),

          tooltip: 'Logout',

          onPressed: _logout,

        ),

        // Theme Toggle Button

        Builder(

          builder: (context) {

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return IconButton(

              icon: Icon(

                isDark ? Icons.light_mode : Icons.dark_mode,

                color: Colors.white,

              ),

              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',

              onPressed: () {

                AdminApp.toggleTheme();

              },

            );

          },

        ),

      ],

    );

  }



  Future<void> _showDetailedData(String title, String filterType, String? status) async {

    if (_db == null) return;

    

    List<Map<String, dynamic>> data = [];

    String query = '';

    

    switch (filterType) {

      case 'files':

        if (status == 'total') {

          query = 'SELECT * FROM files_table ORDER BY updated_at DESC';

        } else if (status == 'for_sale') {

          query = "SELECT * FROM files_table WHERE sale_status = 'Not Sale' ORDER BY updated_at DESC";

        } else if (status == 'sold') {

          final now = DateTime.now();

          final firstDay = DateTime(now.year, now.month, 1);

          query = "SELECT * FROM files_table WHERE (sale_status = 'Sale' OR sale_status = 'Sold') AND updated_at >= '${firstDay.toIso8601String()}' ORDER BY updated_at DESC";

        }

        final result = await _db!.customSelect(query, readsFrom: {_db!.filesTable}).get();

        data = result.map((r) => Map<String, dynamic>.from(r.data)).toList();

        break;

      case 'properties':

        if (status == 'total') {

          query = 'SELECT * FROM properties ORDER BY updated_at DESC';

        } else if (status == 'for_sale') {

          query = "SELECT * FROM properties WHERE sale_status = 'Not Sold' ORDER BY updated_at DESC";

        } else if (status == 'sold') {

          final now = DateTime.now();

          final firstDay = DateTime(now.year, now.month, 1);

          query = "SELECT * FROM properties WHERE sale_status = 'Sold' AND updated_at >= '${firstDay.toIso8601String()}' ORDER BY updated_at DESC";

        }

        final result = await _db!.customSelect(query, readsFrom: {_db!.properties}).get();

        data = result.map((r) => Map<String, dynamic>.from(r.data)).toList();

        break;

      case 'rental':

        if (status == 'total') {

          query = 'SELECT * FROM rental_items ORDER BY updated_at DESC';

        } else if (status == 'for_sale') {

          query = "SELECT * FROM rental_items WHERE sale_status = 'Not Sold' ORDER BY updated_at DESC";

        } else if (status == 'sold') {

          final now = DateTime.now();

          final firstDay = DateTime(now.year, now.month, 1);

          query = "SELECT * FROM rental_items WHERE sale_status = 'Sold' AND updated_at >= '${firstDay.toIso8601String()}' ORDER BY updated_at DESC";

        }

        final result = await _db!.customSelect(query, readsFrom: {_db!.rentalItems}).get();

        data = result.map((r) => Map<String, dynamic>.from(r.data)).toList();

        break;

    }

    

    if (!mounted) return;

    

    setState(() {

      _dashboardDetailTitle = title;

      _dashboardDetailType = filterType;

      _dashboardDetailStatus = status;

      _dashboardDetailData = data;

    });

  }

  

  void _closeDashboardDetail() {

    setState(() {

      _dashboardDetailTitle = null;

      _dashboardDetailType = null;

      _dashboardDetailStatus = null;

      _dashboardDetailData = [];

    });

  }



  Widget _buildStatGrid(BoxConstraints constraints, List<Widget> cards) {

    if (cards.isEmpty) return const SizedBox.shrink();

    const spacing = 12.0;

    final maxWidth = constraints.maxWidth;

    int columns;

    if (maxWidth < 600 || cards.length == 1) {

      columns = 1;

    } else {

      final approx = (maxWidth / 260).floor();

      if (approx < 1) {

        columns = 1;

      } else if (approx > cards.length) {

        columns = cards.length;

      } else {

        columns = approx;

      }

    }

    final tileWidth = columns == 1 ? maxWidth : (maxWidth - spacing * (columns - 1)) / columns;

    return Wrap(

      spacing: spacing,

      runSpacing: spacing,

      children: cards.map((card) => SizedBox(width: tileWidth, child: card)).toList(),

    );

  }



  Widget _buildDashboardSection({

    required IconData icon,

    required Color iconColor,

    required String title,

    required List<Widget> cards,

  }) {

    return Container(

      margin: const EdgeInsets.only(bottom: 12),

        padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Colors.white.withOpacity(0.95),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(

          color: Colors.grey.shade200,

          width: 1,

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.08),

            blurRadius: 12,

            offset: const Offset(0, 3),

          ),

        ],

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

                  color: iconColor.withOpacity(0.15),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Icon(icon, color: iconColor, size: 22),

              ),

                const SizedBox(width: 12),

              Text(

                title,

                style: AppFonts.poppins(

                  fontSize: 18,

                  fontWeight: FontWeight.w600,

                  color: Colors.grey.shade800,

                ),

              ),

            ],

          ),

          const SizedBox(height: 12),

            LayoutBuilder(

              builder: (context, constraints) => _buildStatGrid(constraints, cards),

            ),

          ],

        ),

    );

  }



  Widget _buildNextActionsCard() {

    return Container(

      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Colors.white.withOpacity(0.95),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.grey.shade200, width: 1),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.08),

            blurRadius: 12,

            offset: const Offset(0, 3),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(

                  color: const Color(0xFFFF6B35).withOpacity(0.15),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: const Icon(Icons.task_alt, color: Color(0xFFFF6B35), size: 22),

              ),

              const SizedBox(width: 12),

              Text(

                'Next Actions',

                style: AppFonts.poppins(

                  fontSize: 18,

                  fontWeight: FontWeight.w600,

                  color: Colors.grey.shade800,

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          if (_nextTodoTask != null) ...[

            Row(

              children: [

                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    '${_nextTodoTask!['title']} on ${_nextTodoTask!['date']}',

                    style: AppFonts.poppins(

                      fontSize: 14,

                      color: Colors.grey.shade700,

                    ),

                  ),

                ),

              ],

            ),

            const SizedBox(height: 12),

          ],

          Row(

            children: [

              Icon(Icons.pending_actions, size: 16, color: Colors.grey.shade600),

              const SizedBox(width: 8),

              Text(

                'Pending Trades: $_pendingTradesCount',

                style: AppFonts.poppins(

                  fontSize: 14,

                  color: Colors.grey.shade700,

                ),

              ),

            ],

          ),

          if (_nextTodoTask == null && _pendingTradesCount == 0) ...[

            const SizedBox(height: 8),

            Text(

              'No upcoming actions',

              style: AppFonts.poppins(

                fontSize: 12,

                color: Colors.grey.shade500,

                fontStyle: FontStyle.italic,

              ),

            ),

          ],

        ],

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    Widget dashboard() {

      if (_db == null) return const ShimmerPageLoading(itemCount: 10);

      final summarySections = <Widget>[

        // Single row with only the last tile from each module

        Container(

          margin: const EdgeInsets.only(bottom: 12),

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(

            color: Colors.white.withOpacity(0.95),

            borderRadius: BorderRadius.circular(16),

            border: Border.all(

              color: Colors.grey.shade200,

              width: 1,

            ),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity(0.08),

                blurRadius: 12,

                offset: const Offset(0, 3),

              ),

            ],

          ),

          child: Row(

            children: [

              Expanded(

                child: StatCard(

                  label: 'Total Active Files',

                  value: '$_dashboardActiveFiles',

                  icon: Icons.folder_copy,

                  color: Colors.blue,

                  onTap: () => _showDetailedData('Active Files', 'files', 'total'),

                ),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: StatCard(

                  label: 'Monthly Expenditure',

                  value: NumberFormat('#,##0').format(_dashboardMonthlyExpenditure),

                  icon: Icons.receipt_long,

                  color: Colors.orange,

                  onTap: () => _showDetailedData('Monthly Expenditure', 'expenditure', 'total'),

                ),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: StatCard(

                  label: 'Total Agents',

                  value: '$_dashboardTotalAgents',

                  icon: Icons.group,

                  color: Colors.purple,

                  onTap: () => _showDetailedData('Agents', 'users', 'agent'),

                ),

              ),

            ],

          ),

        ),

        _buildDashboardSection(

          icon: Icons.show_chart,

          iconColor: const Color(0xFFFF6B35), // Orange

          title: 'Performance Overview',

          cards: [

            PerformanceChartCard(data: _performanceData),

          ],

        ),

        _buildNextActionsCard(),

      ];



      return Container(

        decoration: BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [

              const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange

              const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue

            ],

          ),

          border: Border.all(

            color: Colors.grey.shade300.withOpacity(0.5),

            width: 1,

          ),

        ),

        child: Padding(

          padding: const EdgeInsets.all(20),

          child: SingleChildScrollView(

        child: Column(

              mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Center(

                  child: Container(

                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),

                    decoration: BoxDecoration(

                      color: Colors.white.withOpacity(0.9),

                      borderRadius: BorderRadius.circular(16),

                      border: Border.all(

                        color: Colors.grey.shade300,

                        width: 1,

                      ),

                      boxShadow: [

                        BoxShadow(

                          color: Colors.black.withOpacity(0.05),

                          blurRadius: 10,

                          offset: const Offset(0, 2),

                        ),

                      ],

                    ),

              child: Text(

                      () {

                        final name = (_currentUser?['name'] ?? _currentUser?['fullName'] ?? _agentName).toString();

                        final uid = (_currentUser?['user_id'] ?? _currentUser?['userId'] ?? '').toString().trim();

                        final created = _currentUser?['created_at'] ?? _currentUser?['createdAt'];

                        final joined = _formatRegistrationDate(created);

                        final namePart = uid.isNotEmpty ? '$name ($uid)' : name;

                        final joinedPart = (joined == null) ? '' : ' | Joined: $joined';

                        return 'Welcome, $namePart$joinedPart';

                      }(),

                style: AppFonts.poppins(

                  fontWeight: FontWeight.w600,

                        fontSize: 22,

                        color: Colors.grey.shade800,

                ),

              ),

            ),

                ),

                const SizedBox(height: 16),

                // Filter Bar - Show when filter is active

                if (_dashboardDetailTitle != null)

                  Container(

                    margin: const EdgeInsets.only(bottom: 16),

                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                    decoration: BoxDecoration(

                      color: Colors.orange.shade50,

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(color: Colors.orange.shade200, width: 1.5),

                      boxShadow: [

                        BoxShadow(

                          color: Colors.orange.withOpacity(0.1),

                          blurRadius: 8,

                          offset: const Offset(0, 2),

                        ),

                      ],

                    ),

                    child: Row(

                      children: [

                        Container(

                          padding: const EdgeInsets.all(8),

                          decoration: BoxDecoration(

                            color: Colors.orange.shade100,

                            borderRadius: BorderRadius.circular(8),

                          ),

                          child: Icon(Icons.filter_alt, color: Colors.orange.shade700, size: 20),

                        ),

                        const SizedBox(width: 12),

                        Expanded(

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Text(

                                'Filter Active',

                                style: AppFonts.poppins(

                                  fontSize: 12,

                                  fontWeight: FontWeight.w500,

                                  color: Colors.orange.shade700,

                                ),

                              ),

                              const SizedBox(height: 2),

                              Text(

                                _dashboardDetailTitle!,

                                style: AppFonts.poppins(

                                  fontSize: 14,

                                  fontWeight: FontWeight.w600,

                                  color: Colors.grey.shade800,

                                ),

                              ),

                            ],

                          ),

                        ),

                        TextButton.icon(

                          onPressed: () {

                            _closeDashboardDetail();

                          },

                          icon: const Icon(Icons.close, size: 18),

                          label: const Text('Clear Filter'),

                          style: TextButton.styleFrom(

                            foregroundColor: Colors.orange.shade700,

                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                          ),

                        ),

                      ],

                    ),

                  ),

                // Show filtered data when filter is active

                if (_dashboardDetailTitle != null) ...[

                  Container(

                    margin: const EdgeInsets.only(bottom: 16),

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(

                      color: Colors.white.withOpacity(0.95),

                      borderRadius: BorderRadius.circular(16),

                      border: Border.all(color: Colors.grey.shade200, width: 1),

                      boxShadow: [

                        BoxShadow(

                          color: Colors.black.withOpacity(0.08),

                          blurRadius: 12,

                          offset: const Offset(0, 3),

                        ),

                      ],

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text(

                          'Filtered Results (${_dashboardDetailData.length} items)',

                          style: AppFonts.poppins(

                            fontSize: 16,

                            fontWeight: FontWeight.w600,

                            color: Colors.grey.shade800,

                          ),

                        ),

                        const SizedBox(height: 12),

                        if (_dashboardDetailData.isEmpty)

                          Padding(

                            padding: const EdgeInsets.all(20),

                            child: Center(

                              child: Text(

                                'No data found for this filter',

                                style: AppFonts.poppins(

                                  fontSize: 14,

                                  color: Colors.grey.shade600,

                                ),

                              ),

                            ),

                          )

                        else

                          ...(_dashboardDetailData.take(10).map((item) {

                            final detailStyle = TextStyle(fontSize: 13, color: Colors.grey.shade600);

                            final updatedRaw = item['updated_at'];

                            final updatedDisplay = updatedRaw is String && updatedRaw.contains('T')

                                ? updatedRaw.split('T').first

                                : updatedRaw?.toString();

                            

                            // Check if this is files module - show owner name, size (reference_no), and status

                            if (_dashboardDetailType == 'files') {

                              final ownerName = item['client_name']?.toString() ?? 'N/A';

                              final size = item['reference_no']?.toString() ?? 'N/A';

                              final status = item['sale_status']?.toString() ?? 'N/A';

                              

                              return Container(

                                margin: const EdgeInsets.only(bottom: 8),

                                padding: const EdgeInsets.all(12),

                                decoration: BoxDecoration(

                                  color: Colors.grey.shade50,

                                  borderRadius: BorderRadius.circular(8),

                                  border: Border.all(color: Colors.grey.shade200, width: 1),

                                ),

                                child: Row(

                                  children: [

                                    Expanded(

                                      child: Column(

                                        crossAxisAlignment: CrossAxisAlignment.start,

                                        children: [

                                          Text(

                                            'Owner Name: $ownerName',

                                            style: AppFonts.poppins(

                                              fontWeight: FontWeight.w600,

                                              fontSize: 14,

                                              color: Colors.grey.shade800,

                                            ),

                                          ),

                                          const SizedBox(height: 4),

                                          Text(

                                            'Size: $size',

                                            style: detailStyle,

                                          ),

                                          Text(

                                            'Status: $status',

                                            style: detailStyle,

                                          ),

                                        ],

                                      ),

                                    ),

                                    if (updatedDisplay != null)

                                      Text(

                                        updatedDisplay,

                                        style: detailStyle,

                                      ),

                                  ],

                                ),

                              );

                            }

                            

                            // For properties and rental items, use the original display

                            final title = item['name']?.toString() ??

                                item['client_name']?.toString() ??

                                item['property_name']?.toString() ??

                                item['id']?.toString() ??

                                'N/A';

                            

                            // Get status - check both sale_status and status fields

                            final status = item['sale_status']?.toString() ?? 

                                          item['status']?.toString() ?? 

                                          'N/A';

                            

                            // Get value - check demand, price fields

                            final value = item['demand']?.toString() ?? 

                                         item['price']?.toString() ?? 

                                         null;

                            

                            return Container(

                              margin: const EdgeInsets.only(bottom: 8),

                              padding: const EdgeInsets.all(12),

                              decoration: BoxDecoration(

                                color: Colors.grey.shade50,

                                borderRadius: BorderRadius.circular(8),

                                border: Border.all(color: Colors.grey.shade200, width: 1),

                              ),

                              child: Row(

                                children: [

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        Text(

                                          title,

                                          style: AppFonts.poppins(

                                            fontWeight: FontWeight.w600,

                                            fontSize: 14,

                                            color: Colors.grey.shade800,

                                          ),

                                        ),

                                        const SizedBox(height: 4),

                                        Text(

                                          'Status: $status',

                                          style: detailStyle,

                                        ),

                                        if (value != null)

                                          Text(

                                            'Value: $value',

                                            style: detailStyle,

                                          ),

                                      ],

                                    ),

                                  ),

                                  if (updatedDisplay != null)

                                    Text(

                                      updatedDisplay,

                                      style: detailStyle,

                                    ),

                                ],

                              ),

                            );

                          }).toList()),

                        if (_dashboardDetailData.length > 10)

                          Padding(

                            padding: const EdgeInsets.only(top: 8),

                            child: Text(

                              '... and ${_dashboardDetailData.length - 10} more items',

                              style: AppFonts.poppins(

                                fontSize: 12,

                                fontStyle: FontStyle.italic,

                                color: Colors.grey.shade600,

                              ),

                            ),

                          ),

                      ],

                    ),

                  ),

                ],

                Column(

                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: summarySections,

                ),

              ],

            ),

          ),

        ),

      );

    }



    Widget content;

    switch (_navIndex) {

      case 1:

        if (!_canAccessNavIndex(1)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : InventoryPage(db: _db!);

        }

        break;

      case 2:

        if (!_canAccessNavIndex(2)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null 

              ? const SizedBox.shrink()

              : AgentWorkingPage(

                  db: _db!,

                  initialView: _agentWorkingFilter,

                  onViewCleared: () {

                    if (mounted) setState(() => _agentWorkingFilter = null);

                  },

                );

        }

        break;

      case 3:

        if (!_canAccessNavIndex(3)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null 

              ? const SizedBox.shrink()

              : RentalItemsPage(

                  db: _db!,

                );

        }

        break;

      case 4:

        if (!_canAccessNavIndex(4)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : ToDoPage(db: _db!);

        }

        break;

      case 5:

        content = _db == null ? const SizedBox.shrink() : SettingsPageClean(db: _db!);

        break;

      case 6:

        if (!_canAccessNavIndex(6)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : TradingPage(db: _db!);

        }

        break;

      case 7:

        if (!_canAccessNavIndex(7)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : ReportsPage(db: _db!);

        }

        break;

      case 8:

        if (!_canAccessNavIndex(8)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : users.UsersPage(db: _db!);

        }

        break;

      case 9:

        if (!_canAccessNavIndex(9)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : companies.CompaniesPage(db: _db!);

        }

        break;

      case 10:

        if (!_canAccessNavIndex(10)) {

          WidgetsBinding.instance.addPostFrameCallback((_) => _denyAndGoDashboard('Permission Denied'));

          content = const SizedBox.shrink();

        } else {

          content = _db == null ? const SizedBox.shrink() : ChangeNotifierProvider(

            create: (context) => ExpenditureViewModel(_db!),

            child: ExpenditurePage(db: _db!),

          );

        }

        break;

      default:

        content = dashboard();

    }



    final isAgent = RoleUtils.isAgent(_currentUser);

    final roleStr = (_currentUser?['role'] ?? '').toString().toLowerCase();

    final isUserRole = roleStr == 'user';

    final isAgentRole = isAgent || isUserRole;

    final isBypass = PermissionHelper.isBypassUser(_currentUser);

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    final isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);

    // Super Admin should see all modules regardless of stored permissions.

    final canViewInventory = isSuperAdmin || PermissionHelper.canViewModule(_currentUser, 'inventory');

    final canViewAgentWorking = isSuperAdmin || (!isAgentRole && PermissionHelper.canViewModule(_currentUser, 'agent_working'));

    final canViewRental = isSuperAdmin || PermissionHelper.canViewModule(_currentUser, 'rental_items');

    final canViewTodo = isSuperAdmin || PermissionHelper.canViewModule(_currentUser, 'todo');

    final canViewExpenditure = isSuperAdmin || PermissionHelper.canViewModule(_currentUser, 'expenditure');

    final canViewTrading = isSuperAdmin || PermissionHelper.canViewModule(_currentUser, 'trading');

    final showUsers = isSuperAdmin || ((isBypass || isCompanyAdmin) && PermissionHelper.canViewModule(_currentUser, 'users'));

    final showCompanies = isSuperAdmin || ((isBypass) && PermissionHelper.canViewModule(_currentUser, 'companies'));

    final settingsLabel = isAgentRole ? 'My Profile' : 'Settings';



    final navItems = <_AdaptiveNavItem>[

      const _AdaptiveNavItem(

        index: 0,

        label: 'Dashboard',

        icon: Icons.dashboard_outlined,

        selectedIcon: Icons.dashboard,

      ),

      if (canViewInventory)

        const _AdaptiveNavItem(

          index: 1,

          label: 'Inventory',

          icon: Icons.insert_drive_file_outlined,

          selectedIcon: Icons.insert_drive_file,

          requiresAccess: true,

        ),

      if (canViewAgentWorking)

        const _AdaptiveNavItem(

          index: 2,

          label: 'Agent Working',

          icon: Icons.support_agent_outlined,

          selectedIcon: Icons.support_agent,

          requiresAccess: true,

        ),

      if (canViewRental)

        const _AdaptiveNavItem(

          index: 3,

          label: 'Rental Items',

          icon: Icons.chair_outlined,

          selectedIcon: Icons.chair,

          requiresAccess: true,

        ),

      if (canViewTodo)

        const _AdaptiveNavItem(

          index: 4,

          label: 'To-Do',

          icon: Icons.checklist_outlined,

          selectedIcon: Icons.checklist,

          requiresAccess: true,

        ),

      if (canViewExpenditure)

        const _AdaptiveNavItem(

          index: 10,

          label: 'Expenditure',

          icon: Icons.payments_outlined,

          selectedIcon: Icons.payments,

          requiresAccess: true,

        ),

      if (canViewTrading)

        const _AdaptiveNavItem(

          index: 6,

          label: 'Trading',

          icon: Icons.currency_exchange_outlined,

          selectedIcon: Icons.currency_exchange,

          requiresAccess: true,

        ),

      const _AdaptiveNavItem(

        index: 7,

        label: 'Reports',

        icon: Icons.assessment_outlined,

        selectedIcon: Icons.assessment,

      ),

      _AdaptiveNavItem(

        index: 5,

        label: settingsLabel,

        icon: Icons.settings_outlined,

        selectedIcon: Icons.settings,

      ),

      if (showUsers)

        const _AdaptiveNavItem(

          index: 8,

          label: 'Users',

          icon: Icons.people_outlined,

          selectedIcon: Icons.people,

          requiresAccess: true,

        ),

      if (showCompanies)

        const _AdaptiveNavItem(

          index: 9,

          label: 'Companies',

          icon: Icons.business_outlined,

          selectedIcon: Icons.business,

          requiresAccess: true,

        ),

    ];



    final normalizedNavIndex = _navIndex;



    Future<void> handleNavSelection(_AdaptiveNavItem item) async {

      _resetInactivityTimer();

      if (!isSuperAdmin && item.requiresAccess && !_canAccessNavIndex(item.index)) {

        _denyAndGoDashboard('Permission Denied');

        return;

      }

      if (mounted) {

        setState(() => _navIndex = item.index);

      }

    }



    final contentWidget = Container(

      decoration: BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [

            const Color(0xFFFF6B35).withOpacity(0.02),

            const Color(0xFF4A90E2).withOpacity(0.02),

          ],

        ),

        border: Border.all(

          color: Colors.grey.shade300.withOpacity(0.35),

          width: 1,

        ),

      ),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: DecoratedBox(

          decoration: BoxDecoration(

            color: Theme.of(context).cardColor,

            borderRadius: BorderRadius.circular(16),

            border: Border.all(

              color: Colors.grey.shade300.withOpacity(0.35),

              width: 1,

            ),

            boxShadow: [

              BoxShadow(

                color: (Theme.of(context).brightness == Brightness.dark)

                    ? Colors.black.withOpacity(0.5)

                    : Colors.black.withOpacity(0.12),

                blurRadius: 20,

                offset: const Offset(0, 10),

              ),

            ],

          ),

          child: ClipRRect(

            borderRadius: BorderRadius.circular(16),

            child: MouseRegion(

              onEnter: (_) {},

              child: Column(

                children: [

                  ConnectivityIndicator(),

                  Expanded(

                    child: AnimatedContainer(

                      duration: const Duration(milliseconds: 160),

                      transform: Matrix4.translationValues(0, 0, 0),

                      child: content,

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );



    // Build menu tiles reused in sidebar

    const sidebarTextColor = Colors.white;

    const sidebarIconColor = Colors.white70;

    const hoverBg = Colors.white12;

    const brandOrange = Color(0xFFFF6B35);

    List<Widget> buildMenuTiles({required bool closeDrawer, required bool collapsed}) {

      return [

        for (final item in navItems)

          Builder(

            builder: (context) {

              final idx = navItems.indexOf(item);

              final selected = normalizedNavIndex == item.index;

              final hovered = _hoveredMenuIndex == idx;

              final bgColor = selected

                  ? brandOrange.withOpacity(0.12)

                  : (hovered ? hoverBg : Colors.transparent);

              return MouseRegion(

                onEnter: (_) => setState(() => _hoveredMenuIndex = idx),

                onExit: (_) => setState(() => _hoveredMenuIndex = null),

                child: AnimatedContainer(

                  duration: const Duration(milliseconds: 160),

                  decoration: BoxDecoration(

                    color: bgColor,

                    border: Border(

                      left: BorderSide(

                        color: selected ? brandOrange : Colors.transparent,

                        width: 5,

                      ),

                    ),

                    boxShadow: hovered

                        ? [

                            BoxShadow(

                              color: Colors.black.withOpacity(0.14),

                              blurRadius: 12,

                              offset: const Offset(0, 6),

                            )

                          ]

                        : null,

                  ),

                  child: ListTile(

                    leading: Icon(

                      selected ? item.selectedIcon : item.icon,

                      color: hovered || selected ? Colors.white : sidebarIconColor,

                      size: 22,

                    ),

                    title: Row(

                      children: [

                        if (!collapsed)

                          Flexible(

                            child: Text(

                              item.label,

                              style: TextStyle(

                                color: hovered || selected ? Colors.white : sidebarTextColor,

                                fontWeight: FontWeight.w700,

                              ),

                            ),

                          ),

                      ],

                    ),

                    selected: selected,

                    onTap: () async {

                      await handleNavSelection(item);

                    },

                  ),

                ),

              );

            },

          ),

      ];

    }



    return Listener(

      onPointerDown: (_) => _resetInactivityTimer(),

      onPointerMove: (_) => _resetInactivityTimer(),

      child: Focus(

        autofocus: true,

        onKeyEvent: (node, event) {

          _resetInactivityTimer();

          return KeyEventResult.ignored;

        },

        child: Scaffold(

          appBar: _gradientAppBar('Admin'),

          body: Row(

            children: [

              Container(

                width: _sidebarCollapsed ? 82 : 280,

                decoration: BoxDecoration(

                  gradient: const LinearGradient(

                    begin: Alignment.topCenter,

                    end: Alignment.bottomCenter,

                    colors: [

                      Color(0xFF0B1A3A),

                      Color(0xFF132A54),

                    ],

                  ),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black.withOpacity(0.38),

                      blurRadius: 18,

                      offset: const Offset(4, 0),

                    ),

                  ],

                ),

                child: SafeArea(

                  child: Column(

                    children: [

                      Padding(

                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),

                        child: Align(

                          alignment: Alignment.centerLeft,

                          child: IconButton(

                            icon: Icon(

                              _sidebarCollapsed ? Icons.menu : Icons.chevron_left,

                              color: Colors.white,

                            ),

                            tooltip: _sidebarCollapsed ? 'Expand' : 'Collapse',

                            onPressed: () {

                              setState(() {

                                _sidebarCollapsed = !_sidebarCollapsed;

                              });

                            },

                          ),

                        ),

                      ),

                      Expanded(

                        child: ListView(

                          padding: EdgeInsets.zero,

                          children: buildMenuTiles(closeDrawer: false, collapsed: _sidebarCollapsed),

                        ),

                      ),

                      const Divider(color: Colors.white24, height: 1),

                      ListTile(

                        leading: const Icon(Icons.logout, color: Colors.white70),

                        title: _sidebarCollapsed

                            ? null

                            : const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),

                        onTap: () async {

                          await _logout();

                        },

                      ),

                    ],

                  ),

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: contentWidget,

              ),

            ],

          ),

        ),

      ),

    );

  }



}



class MyField extends StatelessWidget {

  final ValueChanged<String> onChanged;



  const MyField({

    Key? key,

    required this.onChanged,

  }) : super(key: key);



  @override

  Widget build(BuildContext context) {

    return TextField(onChanged: onChanged);

  }

}



// _TopRightSearch moved to lib/core/shared_utils.dart as TopRightSearch



class _ModePreview extends StatelessWidget {

  final bool dark;

  const _ModePreview._(this.dark);

  factory _ModePreview.light() => const _ModePreview._(false);

  factory _ModePreview.dark() => const _ModePreview._(true);

  factory _ModePreview.system() => const _ModePreview._(false); // Use light mode as fallback

  @override

  Widget build(BuildContext context) {

    return Container(

      width: 56,

      height: 36,

      decoration: BoxDecoration(

        color: dark ? const Color(0xFF1E1E1E) : Colors.white,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: Colors.grey.shade300),

      ),

      child: Center(

        child: Icon(dark ? Icons.dark_mode : Icons.light_mode, size: 16, color: dark ? Colors.white70 : Colors.black54),

      ),

    );

  }

}



class _AdaptiveNavItem {

  final int index;

  final String label;

  final IconData icon;

  final IconData selectedIcon;

  final int? badge;

  final bool requiresAccess;

  const _AdaptiveNavItem({

    required this.index,

    required this.label,

    required this.icon,

    required this.selectedIcon,

    this.badge,

    this.requiresAccess = false,

  });

}



class AgentWorkingPage extends StatefulWidget {

  final AppDatabase db;

  final String? initialView; // 'daily_logs', 'performance_stats', 'commission_reports'

  final VoidCallback? onViewCleared;

  const AgentWorkingPage({

    super.key, 

    required this.db,

    this.initialView,

    this.onViewCleared,

  });



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

  final _transferFormKey = GlobalKey<FormState>();

  final _clientRequirementFormKey = GlobalKey<FormState>();

  final _officeNotesFormKey = GlobalKey<FormState>();

  final _otherNotesFormKey = GlobalKey<FormState>();

  final TextEditingController _dateCtl = TextEditingController();

  final TextEditingController _plotCtl = TextEditingController();

  final TextEditingController _clientNameCtl = TextEditingController();

  final TextEditingController _clientMobileCtl = TextEditingController();

  final TextEditingController _timeCtl = TextEditingController();

  final TextEditingController _registryCtl = TextEditingController();

  final TextEditingController _commentsCtl = TextEditingController();

  final TextEditingController _reqDateCtl = TextEditingController();

  final TextEditingController _reqPlotCtl = TextEditingController();

  final TextEditingController _reqClientNameCtl = TextEditingController();

  final TextEditingController _reqClientMobileCtl = TextEditingController();

  final TextEditingController _reqTimeCtl = TextEditingController();

  final TextEditingController _reqRegistryCtl = TextEditingController();

  final TextEditingController _reqCommentsCtl = TextEditingController();

  final TextEditingController _officeNotesCtl = TextEditingController();

  final TextEditingController _otherNotesCtl = TextEditingController();

  final TextEditingController _nextWorkingDateCtl = TextEditingController();

  final TextEditingController _reqNextWorkingDateCtl = TextEditingController();

  final TextEditingController _transferOtherCategoryCtl = TextEditingController();

  final TextEditingController _transferOtherSizeCtl = TextEditingController();

  String? _transferCategory;

  String? _transferSize; // Size field for plot sizes (2 Marla, 3 Marla, 5 Marla, 8 Marla, Other)

  String? _requirementCategory;

  String? _requirementSource;

  DateTime? _selectedDate;

  TimeOfDay? _selectedTime;

  DateTime? _reqSelectedDate;

  TimeOfDay? _reqSelectedTime;

  DateTime? _nextWorkingDate;

  DateTime? _reqNextWorkingDate;

  final List<_WorkNote> _officeNotes = [];

  final List<_WorkNote> _otherNotes = [];

  CollectionReference? _officeNotesRef;

  CollectionReference? _otherNotesRef;

  StreamSubscription<QuerySnapshot>? _officeNotesSub;

  StreamSubscription<QuerySnapshot>? _otherNotesSub;

  StreamSubscription<QuerySnapshot>? _workingProgressSub; // Real-time listener for working_progress

  bool _officeNotesLoading = true;

  bool _otherNotesLoading = true;

  String? _officeNotesError;

  String? _otherNotesError;

  List<Map<String, dynamic>> _savedEntries = [];

  bool _loadingEntries = false;

  String _selectedType = 'Transfer'; // 'Transfer' or 'Client Requirements'

  String _q = ''; // Search query

  List<String> _transferImages = [];

  List<String> _clientRequirementImages = []; // Reset images

  Map<String, dynamic>? _currentUser; // Current logged-in user for permission checks

  String? _currentView; // Current view: 'daily_logs', 'performance_stats', 'commission_reports'

  // Pagination state

  int _currentPage = 0;

  static const int _itemsPerPage = 100; // Items per page (50-200 range)

  final ScrollController _scrollController = ScrollController();

  // Tab controller for professional TabBar

  late TabController _tabController;

  // Lazy loading state for tabs

  final Set<int> _loadedTabs = {0}; // Start with first tab loaded

  // Separate pagination state for each tab

  final Map<String, int> _tabPages = {'Transfer': 0, 'Client Requirements': 0};

  final Map<String, ScrollController> _tabScrollControllers = {};

  

  /// Get current user from AuthService

  Future<void> _loadCurrentUser() async {

    try {

      final storage = AppStorage();

      final s = await storage.readSettings();

      final authToken = s['authToken'] as String?;

      if (authToken != null) {

        final authService = AuthService();

        final user = await authService.getCurrentUser(authToken);

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

    _currentView = widget.initialView;

    // Initialize tab controller with 2 tabs

    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(_onTabChanged);

    

    // Initialize scroll controllers for both tabs

    _tabScrollControllers['Transfer'] = ScrollController()..addListener(() => _onTabScroll('Transfer'));

    _tabScrollControllers['Client Requirements'] = ScrollController()..addListener(() => _onTabScroll('Client Requirements'));

    

    // Set initial tab based on widget.initialView or default to Transfer

    if (widget.initialView != null) {

      // Map initialView to tab index if needed

      _selectedType = widget.initialView == 'transfer' ? 'Transfer' : 'Client Requirements';

    }

    final initialTabIndex = _selectedType == 'Transfer' ? 0 : 1;

    _tabController.index = initialTabIndex;

    _loadedTabs.add(initialTabIndex);

    

    _scrollController.addListener(_onScroll);

    _initNoteStreams();

    Future.microtask(() async {

      await _loadCurrentUser();

      _initWorkingProgressListener(); // Initialize after user is loaded

      await _loadSavedEntries();

      _checkAndShowNotifications();

    });

  }

  

  void _onTabChanged() {

    if (!_tabController.indexIsChanging) {

      final newType = _tabController.index == 0 ? 'Transfer' : 'Client Requirements';

      if (_selectedType != newType) {

        setState(() {

          _selectedType = newType;

          // Reset pagination for the new tab

          _currentPage = _tabPages[_selectedType] ?? 0;

        });

        // Mark tab as loaded

        _loadedTabs.add(_tabController.index);

      }

    }

  }

  

  void _onTabScroll(String tabType) {

    final controller = _tabScrollControllers[tabType];

    if (controller != null && controller.hasClients && controller.position.pixels > 0) {

      // Load more when near bottom (80% scrolled)

      if (controller.position.maxScrollExtent > 0 && 

          controller.position.pixels >= controller.position.maxScrollExtent * 0.8) {

        final filtered = _getFilteredEntriesForTab(tabType);

        final currentPage = _tabPages[tabType] ?? 0;

        final totalItems = filtered.length;

        final displayedItems = (currentPage + 1) * _itemsPerPage;

        

        if (displayedItems < totalItems) {

          setState(() {

            _tabPages[tabType] = currentPage + 1;

            if (tabType == _selectedType) {

              _currentPage = _tabPages[_selectedType] ?? 0;

            }

          });

        }

      }

    }

  }



  void _onScroll() {

    // Load more when near bottom (80% scrolled)

    if (_scrollController.hasClients && 

        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {

      if (_hasMoreEntries()) {

        setState(() {

          _currentPage++;

        });

      }

    }

  }



  /// Background sync to Firestore (non-blocking, doesn't delay UI)

  void _syncToFirestore({

    required String collection,

    required String docId,

    required Map<String, dynamic> data,

  }) {

    // RootIsolateToken check removed - not available in this Flutter version

    // Run in background without blocking

    Future.microtask(() async {

      try {

        if (Firebase.apps.isNotEmpty) {

          final firestore = FirebaseFirestore.instance;

          await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));

          // Invalidate cache after successful sync

          FirestoreCacheService().invalidateCache(collection, docId);

        }

      } catch (e) {

        debugPrint('Background Firestore sync failed for $collection/$docId: $e');

        // Sync will retry automatically when connectivity is restored

      }

    });

  }



  Future<void> _checkAndShowNotifications() async {

    try {

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

      final companyId = RoleUtils.getUserCompanyId(_currentUser);



      if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {

        return;

      }

      final results = await widget.db.customSelect(

        isSuperAdmin

            ? 'SELECT * FROM working_progress WHERE next_working_date = ? AND status NOT IN (?, ?)'

            : 'SELECT * FROM working_progress WHERE company_id = ? AND next_working_date = ? AND status NOT IN (?, ?)',

        variables: [

          if (!isSuperAdmin && companyId != null) d.Variable.withString(companyId),

          d.Variable.withString(today),

          d.Variable.withString('Done'),

          d.Variable.withString('Closed'),

        ],

      ).get();

      

      if (results.isNotEmpty && mounted) {

        final entries = results.map((r) => r.data).toList();

        _showNotificationDialog(entries);

      }

    } catch (e) {

      // Silently handle errors - notification is not critical

    }

  }



  void _showNotificationDialog(List<Map<String, dynamic>> entries) {

    showDialog(

      context: context,

      barrierDismissible: true,

      builder: (context) => AlertDialog(

        title: Row(

          children: [

            Icon(Icons.notifications_active, color: Colors.orange.shade700),

            const SizedBox(width: 8),

            Text(

              'Scheduled Work Due Today',

              style: AppFonts.poppins(fontWeight: FontWeight.bold),

            ),

          ],

        ),

        content: SizedBox(

          width: double.maxFinite,

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                'You have ${entries.length} item(s) scheduled for today:',

                style: AppFonts.poppins(fontSize: 14),

              ),

              const SizedBox(height: 12),

              ...entries.map((entry) => Padding(

                padding: const EdgeInsets.only(bottom: 8),

                child: Card(

                  elevation: 1,

                  child: ListTile(

                    dense: true,

                    leading: Icon(Icons.work, color: Colors.purple.shade600),

                    title: Text(

                      entry['name']?.toString() ?? 'N/A',

                      style: AppFonts.poppins(

                        fontSize: 13,

                        fontWeight: FontWeight.w600,

                      ),

                    ),

                    subtitle: Text(

                      'Date: ${entry['transfer_date'] ?? 'N/A'}',

                      style: AppFonts.poppins(fontSize: 11),

                    ),

                  ),

                ),

              )),

            ],

          ),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),

            child: const Text('Dismiss'),

          ),

          FilledButton(

            onPressed: () {

              Navigator.pop(context);

              // Optionally scroll to saved entries section

            },

            child: const Text('View Details'),

          ),

        ],

      ),

    );

  }



  Future<void> _loadSavedEntries() async {

    setState(() => _loadingEntries = true);

    try {

      // Load from SQLite FIRST - show data instantly

      final results = await widget.db.customSelect(

        'SELECT * FROM working_progress ORDER BY updated_at DESC',

      ).get();

      

      List<Map<String, dynamic>> entries = results.map((row) => row.data).toList();

      

      // Show SQLite data immediately (no delay)

      setState(() {

        _savedEntries = entries;

        _loadingEntries = false;

      });

      

      // Load from Firestore in background and merge (non-blocking)

      if (Firebase.apps.isNotEmpty) {

        _mergeFirestoreData(entries).then((mergedEntries) {

          if (mounted) {

            setState(() {

              _savedEntries = mergedEntries;

            });

          }

        }).catchError((e) {

          debugPrint('Firestore merge failed: $e');

          // Keep SQLite data if Firestore fails

        });

      }

    } catch (e) {

      setState(() => _loadingEntries = false);

    }

  }



  /// Merge Firestore data in background (non-blocking)

  Future<List<Map<String, dynamic>>> _mergeFirestoreData(

      List<Map<String, dynamic>> sqliteEntries) async {

    try {

      final entryIds = sqliteEntries

          .map((e) => e['id']?.toString())

          .whereType<String>()

          .where((id) => id.isNotEmpty)

          .toList();



      if (entryIds.isEmpty) return sqliteEntries;



      // Use cached batch fetch

      final firestoreData = await FirestoreCacheService()

          .getCachedDocuments('working_progress', entryIds);



      // Merge Firestore data with SQLite data

      return sqliteEntries.map((entry) {

        final id = entry['id']?.toString();

        if (id != null && firestoreData.containsKey(id)) {

          final firestoreEntry = firestoreData[id]!;

          return {

            ...entry,

            'id': entry['id'],

            'name': entry['name'],

            'status': entry['status'],

            'transfer_date': entry['transfer_date'] ?? firestoreEntry['transferDate'],

            'next_working_date':

                entry['next_working_date'] ?? firestoreEntry['nextWorkingDate'],

            'updated_at': entry['updated_at'],

            ...firestoreEntry,

          };

        }

        return entry;

      }).toList();

    } catch (e) {

      debugPrint('Error merging Firestore data: $e');

      return sqliteEntries; // Return SQLite data if merge fails

    }

  }



  List<Map<String, dynamic>> _getFilteredEntries() {

    return _getFilteredEntriesForTab(_selectedType);

  }

  

  List<Map<String, dynamic>> _getFilteredEntriesForTab(String tabType) {

    Iterable<Map<String, dynamic>> entries = _savedEntries;

    

    // Filter by type (Transfer or Client Requirements)

    if (tabType == 'Transfer') {

      entries = entries.where((e) {

        final type = e['type']?.toString() ?? '';

        final category = e['category']?.toString();

        // Transfer entries have type='transfer' or have category field (from Firestore)

        // If type is missing but category exists, it's likely a Transfer entry

        return type == 'transfer' || (type.isEmpty && category != null && category.isNotEmpty);

      });

    } else if (tabType == 'Client Requirements') {

      entries = entries.where((e) {

        final type = e['type']?.toString() ?? '';

        final source = e['source']?.toString();

        // Client Requirements entries have type='client_requirement' or have source field

        // If type is missing but source exists, it's likely a Client Requirement entry

        return type == 'client_requirement' || (type.isEmpty && source != null && source.isNotEmpty);

      });

    }

    

    

    // Filter by search query

    if (_q.isNotEmpty) {

      entries = entries.where((e) {

        return e.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()));

      });

    }

    

    // Sort entries

    List<Map<String, dynamic>> sortedEntries = entries.toList();

    // Sort by updated date (most recent first)

    sortedEntries.sort((a, b) {

      final dateA = a['updated_at']?.toString() ?? '';

      final dateB = b['updated_at']?.toString() ?? '';

      return dateB.compareTo(dateA);

    });

    

    // Additional sorting by plot size if needed

    if (false) { // Disabled - no block filter

      sortedEntries.sort((a, b) {

        final sizeA = _getSizeSortOrder(a['size']?.toString());

        final sizeB = _getSizeSortOrder(b['size']?.toString());

        return sizeA.compareTo(sizeB); // Smaller sizes first

      });

    }

    

    return sortedEntries;

  }



  List<Map<String, dynamic>> _getPaginatedEntries() {

    return _getPaginatedEntriesForTab(_selectedType);

  }

  

  List<Map<String, dynamic>> _getPaginatedEntriesForTab(String tabType) {

    final filtered = _getFilteredEntriesForTab(tabType);

    final currentPage = _tabPages[tabType] ?? 0;

    final startIndex = 0;

    final endIndex = ((currentPage + 1) * _itemsPerPage).clamp(0, filtered.length);

    return filtered.sublist(startIndex, endIndex);

  }



  bool _hasMoreEntries() {

    return _hasMoreEntriesForTab(_selectedType);

  }

  

  bool _hasMoreEntriesForTab(String tabType) {

    final filtered = _getFilteredEntriesForTab(tabType);

    final currentPage = _tabPages[tabType] ?? 0;

    return (currentPage + 1) * _itemsPerPage < filtered.length;

  }



  @override

  void dispose() {

    _dateCtl.dispose();

    _plotCtl.dispose();

    _clientNameCtl.dispose();

    _clientMobileCtl.dispose();

    _timeCtl.dispose();

    _registryCtl.dispose();

    _commentsCtl.dispose();

    _reqDateCtl.dispose();

    _reqPlotCtl.dispose();

    _reqClientNameCtl.dispose();

    _reqClientMobileCtl.dispose();

    _reqTimeCtl.dispose();

    _reqRegistryCtl.dispose();

    _reqCommentsCtl.dispose();

    _officeNotesCtl.dispose();

    _otherNotesCtl.dispose();

    _nextWorkingDateCtl.dispose();

    _reqNextWorkingDateCtl.dispose();

    _transferOtherCategoryCtl.dispose();

    _transferOtherSizeCtl.dispose();

    _scrollController.dispose();

    _tabController.dispose();

    // Dispose all tab scroll controllers

    for (var controller in _tabScrollControllers.values) {

      controller.dispose();

    }

    _tabScrollControllers.clear();

    _officeNotesSub?.cancel();

    _otherNotesSub?.cancel();

    _workingProgressSub?.cancel();

    super.dispose();

  }



  void _initNoteStreams() {

    try {

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

      

      try {

        _officeNotesSub = _officeNotesRef!

            .orderBy('createdAt', descending: true)

            .snapshots()

            .listen((snapshot) => _handleNotesEvent(snapshot, isOffice: true), onError: (error) {

          if (mounted) {

            setState(() {

              _officeNotesError = error.toString();

              _officeNotesLoading = false;

            });

          }

        });

      } catch (e) {

        debugPrint('Error creating office notes listener: $e');

        if (mounted) {

          setState(() {

            _officeNotesError = 'Failed to connect: $e';

            _officeNotesLoading = false;

          });

        }

      }

      try {

        _otherNotesSub = _otherNotesRef!

            .orderBy('createdAt', descending: true)

            .snapshots()

            .listen((snapshot) => _handleNotesEvent(snapshot, isOffice: false), onError: (error) {

          if (mounted) {

            setState(() {

              _otherNotesError = error.toString();

              _otherNotesLoading = false;

            });

          }

        });

      } catch (e) {

        debugPrint('Error creating other notes listener: $e');

        if (mounted) {

          setState(() {

            _otherNotesError = 'Failed to connect: $e';

            _otherNotesLoading = false;

          });

        }

      }

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



  /// Initialize real-time Firestore listener for working_progress entries

  void _initWorkingProgressListener() {

    if (Firebase.apps.isEmpty) return;

    if (_currentUser == null) return;



    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    final isAgent = RoleUtils.isAgent(_currentUser);

    if (isAgent) return; // Agents don't need real-time sync for all entries



    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;



    try {

      final firestore = FirebaseFirestore.instance;

      Query query = firestore.collection('working_progress');

      

      if (!isSuperAdmin) {

        query = query.where('companyId', isEqualTo: companyId);

      }

      

      try {

        _workingProgressSub = query

            .orderBy('updatedAt', descending: true)

            .snapshots()

            .listen((snapshot) {

          if (!mounted) return;

        

        // Process changes in background

        Future.microtask(() async {

          try {

            for (final change in snapshot.docChanges) {

              final doc = change.doc;

              final data = doc.data() as Map<String, dynamic>;

              final id = (data['id'] ?? doc.id).toString();

              

              if (change.type == DocumentChangeType.removed) {

                // Delete from SQLite

                await widget.db.customStatement(

                  'DELETE FROM working_progress WHERE id = ?',

                  [id],

                );

              } else {

                // Insert or update in SQLite - only use columns that exist in schema

                final nowIso = DateTime.now().toUtc().toIso8601String();

                await widget.db.customStatement(

                  '''INSERT OR REPLACE INTO working_progress 

                     (id, company_id, name, status, remarks, transfer_date, next_working_date, 

                      category, from_user, to_user, updated_at)

                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',

                  [

                    id,

                    data['companyId'] ?? data['company_id'],

                    data['name'],

                    data['status'],

                    data['remarks'],

                    data['transferDate'] ?? data['transfer_date'],

                    data['nextWorkingDate'] ?? data['next_working_date'],

                    data['category'],

                    data['fromUser'] ?? data['from_user'],

                    data['toUser'] ?? data['to_user'],

                    data['updatedAt'] ?? data['updated_at'] ?? nowIso,

                  ],

                );

              }

            }

            

            // Reload entries to reflect changes

            if (mounted) {

              await _loadSavedEntries();

            }

          } catch (e) {

            debugPrint('Error processing working_progress changes: $e');

          }

        });

        }, onError: (error) {

          if (!mounted) return;

          debugPrint('Error in working_progress listener: $error');

        });

      } catch (e) {

        debugPrint('Error creating working_progress snapshots listener: $e');

        if (!mounted) return;

      }

    } catch (e) {

      debugPrint('Failed to initialize working_progress listener: $e');

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



  Future<void> _pickDate() async {

    final now = DateTime.now();

      final picked = await showCustomDatePicker(

      context,

      initialDate: _selectedDate ?? now,

      firstDate: DateTime(now.year - 5),

      lastDate: DateTime(now.year + 5),

    );

    if (picked != null) {

      setState(() {

        _selectedDate = picked;

        _dateCtl.text = DateFormat('dd MMM yyyy').format(picked);

      });

    }

  }



  Future<void> _pickTime() async {

    final picked = await showCustomTimePicker(

      context,

      initialTime: _selectedTime ?? TimeOfDay.now(),

    );

    if (picked != null) {

      setState(() {

        _selectedTime = picked;

        _timeCtl.text = picked.format(context);

      });

    }

  }



  Future<void> _pickRequirementDate() async {

    final now = DateTime.now();

      final picked = await showCustomDatePicker(

      context,

      initialDate: _reqSelectedDate ?? now,

      firstDate: DateTime(now.year - 5),

      lastDate: DateTime(now.year + 5),

    );

    if (picked != null) {

      setState(() {

        _reqSelectedDate = picked;

        _reqDateCtl.text = DateFormat('dd MMM yyyy').format(picked);

      });

    }

  }



  Future<void> _pickRequirementTime() async {

    final picked = await showCustomTimePicker(

      context,

      initialTime: _reqSelectedTime ?? TimeOfDay.now(),

    );

    if (picked != null) {

      setState(() {

        _reqSelectedTime = picked;

        _reqTimeCtl.text = picked.format(context);

      });

    }

  }



  Future<void> _pickNextWorkingDate() async {

    final now = DateTime.now();

    final picked = await showDatePicker(

      context: context,

      initialDate: _nextWorkingDate ?? now,

      firstDate: now,

      lastDate: DateTime(now.year + 5),

    );

    if (picked != null) {

      setState(() {

        _nextWorkingDate = picked;

        _nextWorkingDateCtl.text = DateFormat('dd MMM yyyy').format(picked);

      });

    }

  }



  Future<void> _pickReqNextWorkingDate() async {

    final now = DateTime.now();

    final picked = await showDatePicker(

      context: context,

      initialDate: _reqNextWorkingDate ?? now,

      firstDate: now,

      lastDate: DateTime(now.year + 5),

    );

    if (picked != null) {

      setState(() {

        _reqNextWorkingDate = picked;

        _reqNextWorkingDateCtl.text = DateFormat('dd MMM yyyy').format(picked);

      });

    }

  }



  Future<void> _submitTransfer({required String action, BuildContext? dialogContext}) async {

    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    final formValid = _transferFormKey.currentState?.validate() ?? false;

    if (!formValid) return;

    

    if (_selectedDate == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Please select a date')),

      );

      return;

    }



    // Capture images BEFORE closing dialog and clearing state

    final imagesToSave = List<String>.from(_transferImages);

    

    // Close dialog immediately when Save is clicked

    if (mounted && dialogContext != null) {

      // Use dialogContext which is the correct dialog context from StatefulBuilder

      Navigator.of(dialogContext).pop(); // Close the popup dialog immediately

    }



    try {

      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final nowIso = DateTime.now().toUtc().toIso8601String();

      final transferDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final nextWorkingDateStr = _nextWorkingDate != null 

          ? DateFormat('yyyy-MM-dd').format(_nextWorkingDate!)

          : null;

      

      // Determine status based on action

      final status = 'Pending'; // Always save as Pending when using Save button

      

      // Use custom category if "Other" is selected and custom value is provided

      final categoryToSave = _transferCategory == 'other' && _transferOtherCategoryCtl.text.trim().isNotEmpty

          ? _transferOtherCategoryCtl.text.trim()

          : _transferCategory;

      

      // Use custom size if "Other" is selected - must use custom value (validation ensures it's not empty)

      final sizeToSave = _transferSize == 'other'

          ? _transferOtherSizeCtl.text.trim() // Always use custom text when "Other" is selected

          : _transferSize;

      

      // OFFLINE-FIRST: Save to local database FIRST

      await widget.db.into(widget.db.workingProgress).insertOnConflictUpdate(

        WorkingProgressCompanion.insert(

          id: id,

          companyId: RoleUtils.isSuperAdmin(_currentUser)

              ? const d.Value.absent()

              : d.Value(RoleUtils.getUserCompanyId(_currentUser)),

          name: _clientNameCtl.text.trim(),

          status: d.Value(status),

          remarks: _commentsCtl.text.trim().isEmpty 

              ? const d.Value.absent() 

              : d.Value(_commentsCtl.text.trim()),

          fromUser: const d.Value.absent(),

          toUser: const d.Value.absent(),

          transferDate: d.Value(transferDate),

          nextWorkingDate: nextWorkingDateStr != null ? d.Value(nextWorkingDateStr) : const d.Value.absent(),

          category: categoryToSave != null && categoryToSave.isNotEmpty ? d.Value(categoryToSave) : const d.Value.absent(),

          updatedAt: nowIso,

        ),

      );



      // Background sync to Firestore (non-blocking)

      _syncToFirestore(

        collection: 'working_progress',

        docId: id,

        data: {

          'id': id,

          'companyId': RoleUtils.getUserCompanyId(_currentUser),

          'name': _clientNameCtl.text.trim(),

          'status': status,

          'remarks': _commentsCtl.text.trim().isEmpty ? null : _commentsCtl.text.trim(),

          'transferDate': transferDate,

          'nextWorkingDate': nextWorkingDateStr,

          'updatedAt': nowIso,

          'type': 'transfer',

          'category': categoryToSave,

          'plotNo': _plotCtl.text.trim(),

          'size': sizeToSave, // Size field (2 Marla, 3 Marla, 5 Marla, 8 Marla, or custom)

          'clientMobile': _clientMobileCtl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''), // PERMANENT: Clean mobile - digits only

          'registryNumber': _registryCtl.text.trim(), // PERMANENT: Validated by form validator

          'imagePaths': imagesToSave.isNotEmpty ? imagesToSave : null, // Save image paths

        },

      );



      // Reset form

      _transferFormKey.currentState?.reset();

      _dateCtl.clear();

      _plotCtl.clear();

      _clientNameCtl.clear();

      _clientMobileCtl.clear();

      _timeCtl.clear();

      _registryCtl.clear();

      _commentsCtl.clear();

      _nextWorkingDateCtl.clear();

      _transferOtherCategoryCtl.clear();

      _transferOtherSizeCtl.clear();

      _transferCategory = null;

      _transferSize = null;

      _selectedDate = null;

      _selectedTime = null;

      _nextWorkingDate = null;

      _transferImages = [];



      // Reload entries after save completes

      if (mounted) {

        await _loadSavedEntries();

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Transfer details saved successfully.')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to save transfer: $e')),

        );

      }

    }

  }



  Future<void> _submitClientRequirement({required String action, BuildContext? dialogContext}) async {

    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    final formValid = _clientRequirementFormKey.currentState?.validate() ?? false;

    if (!formValid) return;

    

    if (_reqSelectedDate == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Please select a date')),

      );

      return;

    }



    // Capture images BEFORE closing dialog and clearing state

    final imagesToSave = List<String>.from(_clientRequirementImages);

    

    // Close dialog immediately when Save is clicked

    if (mounted && dialogContext != null) {

      // Use dialogContext which is the correct dialog context from StatefulBuilder

      Navigator.of(dialogContext).pop(); // Close the popup dialog immediately

    }



    try {

      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final nowIso = DateTime.now().toUtc().toIso8601String();

      final transferDate = DateFormat('yyyy-MM-dd').format(_reqSelectedDate!);

      final nextWorkingDateStr = _reqNextWorkingDate != null 

          ? DateFormat('yyyy-MM-dd').format(_reqNextWorkingDate!)

          : null;

      

      // Combine client name with category and source for the name field

      final name = '${_reqClientNameCtl.text.trim()} (${_requirementCategory ?? 'N/A'}, ${_requirementSource ?? 'N/A'})';

      

      // Determine status based on action

      final status = 'Pending'; // Always save as Pending when using Save button

      

      // OFFLINE-FIRST: Save to local database FIRST

      await widget.db.into(widget.db.workingProgress).insertOnConflictUpdate(

        WorkingProgressCompanion.insert(

          id: id,

          companyId: RoleUtils.isSuperAdmin(_currentUser)

              ? const d.Value.absent()

              : d.Value(RoleUtils.getUserCompanyId(_currentUser)),

          name: name,

          status: d.Value(status),

          remarks: _reqCommentsCtl.text.trim().isEmpty 

              ? const d.Value.absent() 

              : d.Value(_reqCommentsCtl.text.trim()),

          fromUser: const d.Value.absent(),

          toUser: const d.Value.absent(),

          transferDate: d.Value(transferDate),

          nextWorkingDate: nextWorkingDateStr != null ? d.Value(nextWorkingDateStr) : const d.Value.absent(),

          updatedAt: nowIso,

        ),

      );



      // Background sync to Firestore (non-blocking)

      _syncToFirestore(

        collection: 'working_progress',

        docId: id,

        data: {

          'id': id,

          'companyId': RoleUtils.getUserCompanyId(_currentUser),

          'name': name,

          'status': status,

          'remarks': _reqCommentsCtl.text.trim().isEmpty ? null : _reqCommentsCtl.text.trim(),

          'transferDate': transferDate,

          'nextWorkingDate': nextWorkingDateStr,

          'updatedAt': nowIso,

          'type': 'client_requirement',

          'category': _requirementCategory,

          'source': _requirementSource,

          'plotNo': _reqPlotCtl.text.trim(),

          'clientMobile': _reqClientMobileCtl.text.trim(),

          'registryNumber': _reqRegistryCtl.text.trim(),

          'imagePaths': imagesToSave.isNotEmpty ? imagesToSave : null, // Save image paths

        },

      );



      // Reset form

      _clientRequirementFormKey.currentState?.reset();

      _reqDateCtl.clear();

      _reqPlotCtl.clear();

      _reqClientNameCtl.clear();

      _reqClientMobileCtl.clear();

      _reqTimeCtl.clear();

      _reqRegistryCtl.clear();

      _reqCommentsCtl.clear();

      _reqNextWorkingDateCtl.clear();

      _requirementCategory = null;

      _requirementSource = null;

      _reqSelectedDate = null;

      _reqSelectedTime = null;

      _reqNextWorkingDate = null;

      _clientRequirementImages = [];



      // Reload entries after save completes

      if (mounted) {

        await _loadSavedEntries();

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Client requirements saved successfully.')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to save client requirement: $e')),

        );

      }

    }

  }



  void _saveOfficeNote() async {

    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    final valid = _officeNotesFormKey.currentState?.validate() ?? false;

    if (!valid || _officeNotesRef == null) return;

    final text = _officeNotesCtl.text.trim();

    try {

      await _officeNotesRef!.add({

        'text': text,

        'createdAt': FieldValue.serverTimestamp(),

      });

      _officeNotesCtl.clear();

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Office note added.')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Unable to save office note: $e')),

        );

      }

    }

  }



  void _saveOtherNote() async {

    if (!PermissionHelper.canAddModule(_currentUser, 'agent_working')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    final valid = _otherNotesFormKey.currentState?.validate() ?? false;

    if (!valid || _otherNotesRef == null) return;

    final text = _otherNotesCtl.text.trim();

    try {

      await _otherNotesRef!.add({

        'text': text,

        'createdAt': FieldValue.serverTimestamp(),

      });

      _otherNotesCtl.clear();

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Other work note added.')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Unable to save note: $e')),

        );

      }

    }

  }



  InputDecoration _fieldDecoration(String label, {String? hint, IconData? icon, Widget? suffixIcon, bool isRequired = false}) {

    // Map labels to appropriate icons for better visual clarity

    IconData? fieldIcon = icon;

    if (fieldIcon == null) {

      final lowerLabel = label.toLowerCase();

      if (lowerLabel.contains('name') || lowerLabel.contains('client') || lowerLabel.contains('owner')) {

        fieldIcon = Icons.person_outline;

      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone') || lowerLabel.contains('contact')) {

        fieldIcon = Icons.phone_outlined;

      } else if (lowerLabel.contains('email')) {

        fieldIcon = Icons.email_outlined;

      } else if (lowerLabel.contains('date') || lowerLabel.contains('time')) {

        fieldIcon = Icons.calendar_today_outlined;

      } else if (lowerLabel.contains('cnic') || lowerLabel.contains('id')) {

        fieldIcon = Icons.badge_outlined;

      } else if (lowerLabel.contains('plot') || lowerLabel.contains('file no') || lowerLabel.contains('reference')) {

        fieldIcon = Icons.numbers_outlined;

      } else if (lowerLabel.contains('size') || lowerLabel.contains('path')) {

        fieldIcon = Icons.straighten_outlined;

      } else if (lowerLabel.contains('price') || lowerLabel.contains('demand') || lowerLabel.contains('payment') || lowerLabel.contains('rent') || lowerLabel.contains('security')) {

        fieldIcon = null; // Will use "Rs" text widget instead

      } else if (lowerLabel.contains('category')) {

        fieldIcon = Icons.category_outlined;

      } else if (lowerLabel.contains('status')) {

        fieldIcon = Icons.info_outline;

      } else if (lowerLabel.contains('comment') || lowerLabel.contains('note')) {

        fieldIcon = Icons.note_outlined;

      } else if (lowerLabel.contains('address') || lowerLabel.contains('location')) {

        fieldIcon = Icons.location_on_outlined;

      } else if (lowerLabel.contains('registry') || lowerLabel.contains('transfer')) {

        fieldIcon = Icons.description_outlined;

      } else if (lowerLabel.contains('society') || lowerLabel.contains('block')) {

        fieldIcon = Icons.apartment_outlined;

      } else {

        fieldIcon = Icons.edit_outlined;

      }

    }

    

    // Add asterisk for required fields

    final labelText = isRequired ? '$label *' : label;

    

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

      labelText: labelText,

      hintText: hint,

      prefixIcon: prefixWidget,

      suffixIcon: suffixIcon,

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



  Widget _buildSectionCard({required String title, required Widget body, bool initiallyExpanded = false}) {

    return Card(

      margin: const EdgeInsets.only(bottom: 16),

      elevation: 2,

      child: ExpansionTile(

        initiallyExpanded: initiallyExpanded,

        title: Text(

          title,

          style: AppFonts.poppins(fontWeight: FontWeight.w600),

        ),

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

            child: body,

          ),

        ],

      ),

    );

  }



  Widget _buildTransferForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {

    return Form(

      key: _transferFormKey,

      autovalidateMode: AutovalidateMode.onUserInteraction,

      child: Card(

        elevation: 2,

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: LayoutBuilder(

            builder: (context, constraints) {

              final maxWidth = constraints.maxWidth;

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



              // Helper function to build section headers

              Widget _buildSectionHeader(String title, IconData icon) {

                return Padding(

                  padding: const EdgeInsets.only(top: 24, bottom: 16),

                  child: Row(

                    children: [

                      Icon(icon, size: 20, color: const Color(0xFFFF6B35)),

                      const SizedBox(width: 8),

                      Text(

                        title,

                        style: AppFonts.poppins(

                          fontSize: 16,

                          fontWeight: FontWeight.w600,

                          color: Colors.grey.shade800,

                        ),

                      ),

                    ],

                  ),

                );

              }



              return SingleChildScrollView(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'Transfer Form',

                      style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),

                    ),

                    

                    // Section 1: Property Details

                    _buildSectionHeader('Property Details', Icons.home_work),

                    Wrap(

                      spacing: 16,

                      runSpacing: 16,

                      children: [

                        fieldBox(

                          DropdownButtonFormField<String>(

                            value: _transferCategory,

                            decoration: _fieldDecoration('Category', isRequired: true),

                            items: const [

                              DropdownMenuItem(value: 'plot', child: Text('Plot')),

                              DropdownMenuItem(value: 'house', child: Text('House')),

                              DropdownMenuItem(value: 'shop', child: Text('Shop')),

                              DropdownMenuItem(value: 'file', child: Text('File')),

                              DropdownMenuItem(value: 'plaza', child: Text('Plaza')),

                              DropdownMenuItem(value: 'other', child: Text('Other')),

                            ],

                            onChanged: (value) {

                              if (dialogSetState != null) {

                                dialogSetState(() {

                                  _transferCategory = value;

                                  if (value != 'other') {

                                    _transferOtherCategoryCtl.clear();

                                  }

                                });

                              } else {

                                setState(() {

                                  _transferCategory = value;

                                  if (value != 'other') {

                                    _transferOtherCategoryCtl.clear();

                                  }

                                });

                              }

                            },

                            validator: (value) => value == null || value.isEmpty ? 'Select category' : null,

                          ),

                        ),

                        if (_transferCategory == 'other')

                          fieldBox(

                            TextFormField(

                              controller: _transferOtherCategoryCtl,

                              decoration: _fieldDecoration('Custom Category', hint: 'Enter custom category name'),

                              maxLength: 100,

                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                              validator: (value) {

                                if (_transferCategory == 'other') {

                                  if (value == null || value.trim().isEmpty) {

                                    return 'Enter custom category';

                                  }

                                  if (value.length > 100) {

                                    return 'Maximum 100 characters allowed';

                                  }

                                }

                                return null;

                              },

                            ),

                          ),

                        fieldBox(

                          DropdownButtonFormField<String>(

                            value: _transferSize,

                            decoration: _fieldDecoration('Size'),

                            items: const [

                              DropdownMenuItem(value: '2 Marla', child: Text('2 Marla')),

                              DropdownMenuItem(value: '3 Marla', child: Text('3 Marla')),

                              DropdownMenuItem(value: '5 Marla', child: Text('5 Marla')),

                              DropdownMenuItem(value: '8 Marla', child: Text('8 Marla')),

                              DropdownMenuItem(value: 'other', child: Text('Other')),

                            ],

                            onChanged: (value) {

                              if (dialogSetState != null) {

                                dialogSetState(() {

                                  _transferSize = value;

                                  if (value != 'other') {

                                    _transferOtherSizeCtl.clear();

                                  }

                                });

                              } else {

                                setState(() {

                                  _transferSize = value;

                                  if (value != 'other') {

                                    _transferOtherSizeCtl.clear();

                                  }

                                });

                              }

                            },

                            validator: (value) => value == null || value.isEmpty ? 'Select size' : null,

                          ),

                        ),

                        if (_transferSize == 'other')

                          fieldBox(

                            TextFormField(

                              controller: _transferOtherSizeCtl,

                              decoration: _fieldDecoration('Custom Size', hint: 'Enter custom size'),

                              maxLength: 100,

                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                              validator: (value) {

                                if (_transferSize == 'other') {

                                  if (value == null || value.trim().isEmpty) {

                                    return 'Enter custom size';

                                  }

                                  if (value.length > 100) {

                                    return 'Maximum 100 characters allowed';

                                  }

                                }

                                return null;

                              },

                            ),

                          ),

                        fieldBox(

                          TextFormField(

                            controller: _plotCtl,

                            decoration: _fieldDecoration('Plot No.'),

                            maxLength: 100,

                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                            inputFormatters: [plotNoFormatter],

                            validator: (value) {

                              if (value == null || value.isEmpty) return 'Enter plot number';

                              return validatePlotNo(value);

                            },

                          ),

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _registryCtl,

                            decoration: _fieldDecoration('Registry/Transfer Number'),

                            maxLength: 50,

                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                            inputFormatters: [registryTransferNoFormatter],

                            validator: (value) {

                              if (value == null || value.isEmpty) return 'Enter registry or transfer number';

                              return validateRegistryTransferNo(value);

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

                            controller: _clientNameCtl,

                            decoration: _fieldDecoration('Client Name'),

                            maxLength: 100,

                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                            inputFormatters: [clientNameFormatter],

                            validator: (value) {

                              if (value == null || value.isEmpty) return 'Enter client name';

                              return validateClientName(value);

                            },

                          ),

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _clientMobileCtl,

                            keyboardType: TextInputType.phone,

                            decoration: _fieldDecoration('Client Mobile No.', hint: '03XX-XXXXXXX'),

                            maxLength: 11,

                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                            inputFormatters: [mobileNoFormatter],

                            validator: validateClientMobileNo,

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

                            controller: _dateCtl,

                            readOnly: true,

                            onTap: _pickDate,

                            decoration: _fieldDecoration('Date', icon: Icons.calendar_today, suffixIcon: const Icon(Icons.calendar_today), isRequired: true),

                            validator: (value) => value == null || value.isEmpty ? 'Select a date' : null,

                          ),

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _timeCtl,

                            readOnly: true,

                            onTap: _pickTime,

                            decoration: _fieldDecoration('Time', icon: Icons.schedule, suffixIcon: const Icon(Icons.schedule), isRequired: true),

                            validator: (value) => value == null || value.isEmpty ? 'Select time' : null,

                          ),

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _nextWorkingDateCtl,

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

                            imagePaths: _transferImages,

                            onImagesChanged: (images) {

                              if (dialogSetState != null) {

                                dialogSetState(() {

                                  _transferImages = images;

                                });

                              } else {

                                setState(() {

                                  _transferImages = images;

                                });

                              }

                            },

                            maxImages: 3,

                          ),

                          span: columns,

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _commentsCtl,

                            decoration: _fieldDecoration('Remarks'),

                            maxLines: 5,

                            minLines: 3,

                            maxLength: 200,

                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                            inputFormatters: [commentFormatter],

                            validator: validateComment,

                          ),

                          span: columns,

                        ),

                      ],

                    ),

                  const SizedBox(height: 16),

                  Row(

                    children: [

                      OutlinedButton.icon(

                        onPressed: () {

                          _resetTransferForm();

                          final navContext = dialogContext ?? context;

                          Navigator.of(navContext).pop();

                        },

                        icon: const Icon(Icons.close),

                        label: const Text('Cancel'),

                      ),

                      const Spacer(),

                      if (PermissionHelper.canAddModule(_currentUser, 'agent_working'))

                        PrimaryGradientButton(

                          text: 'Save',

                          icon: Icons.save,

                          onPressed: () => _submitTransfer(action: 'Save', dialogContext: dialogContext),

                        ),

                    ],

                  ),

                ],

              ),

            );

            },

          ),

        ),

      ),

    );

  }



  Widget _buildClientRequirementForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {

    return Form(

      key: _clientRequirementFormKey,

      autovalidateMode: AutovalidateMode.onUserInteraction,

      child: Card(

        elevation: 2,

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: LayoutBuilder(

            builder: (context, constraints) {

              final maxWidth = constraints.maxWidth;

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

                children: [

                  Text(

                    'Client Requirement Form',

                    style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),

                  ),

                  const SizedBox(height: 24),

                  Wrap(

                    spacing: 16,

                    runSpacing: 16,

                    children: [

                      fieldBox(

                        DropdownButtonFormField<String>(

                          value: _requirementCategory,

                          decoration: _fieldDecoration('Category'),

                          items: const [

                            DropdownMenuItem(value: 'plot', child: Text('Plot')),

                            DropdownMenuItem(value: 'house', child: Text('House')),

                            DropdownMenuItem(value: 'shop', child: Text('Shop')),

                            DropdownMenuItem(value: 'file', child: Text('File')),

                            DropdownMenuItem(value: 'plaza', child: Text('Plaza')),

                            DropdownMenuItem(value: 'other', child: Text('Other')),

                          ],

                          onChanged: (value) {

                            if (dialogSetState != null) {

                              dialogSetState(() => _requirementCategory = value);

                            } else {

                              setState(() => _requirementCategory = value);

                            }

                          },

                          validator: (value) => value == null || value.isEmpty ? 'Select category' : null,

                        ),

                      ),

                        fieldBox(

                          TextFormField(

                            controller: _reqDateCtl,

                            readOnly: true,

                            onTap: _pickRequirementDate,

                            decoration: _fieldDecoration('Date', suffixIcon: const Icon(Icons.calendar_today), isRequired: true),

                            validator: (value) => value == null || value.isEmpty ? 'Select a date' : null,

                          ),

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _reqPlotCtl,

                            decoration: _fieldDecoration('Plot No.', isRequired: true),

                            validator: (value) => value == null || value.isEmpty ? 'Enter plot number' : null,

                          ),

                        ),

                        fieldBox(

                          TextFormField(

                            controller: _reqClientNameCtl,

                            decoration: _fieldDecoration('Client Name', isRequired: true),

                            maxLength: 100,

                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                            inputFormatters: [clientNameFormatter],

                            validator: (value) {

                              if (value == null || value.isEmpty) return 'Enter client name';

                              return validateClientName(value);

                            },

                          ),

                        ),

                      fieldBox(

                        TextFormField(

                          controller: _reqClientMobileCtl,

                          keyboardType: TextInputType.phone,

                          decoration: _fieldDecoration('Client Mobile No.', hint: '03XX-XXXXXXX', isRequired: true),

                          maxLength: 11,

                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                          inputFormatters: [mobileNoFormatter],

                          validator: validateClientMobileNo,

                        ),

                      ),

                      fieldBox(

                        TextFormField(

                          controller: _reqTimeCtl,

                          readOnly: true,

                          onTap: _pickRequirementTime,

                          decoration: _fieldDecoration('Time', suffixIcon: const Icon(Icons.schedule), isRequired: true),

                          validator: (value) => value == null || value.isEmpty ? 'Select time' : null,

                        ),

                      ),

                      fieldBox(

                        DropdownButtonFormField<String>(

                          value: _requirementSource,

                          decoration: _fieldDecoration('Source'),

                          items: const [

                            DropdownMenuItem(value: 'website', child: Text('Website')),

                            DropdownMenuItem(value: 'referral', child: Text('Referral')),

                            DropdownMenuItem(value: 'walk-in', child: Text('Walk-in')),

                            DropdownMenuItem(value: 'social-media', child: Text('Social Media')),

                            DropdownMenuItem(value: 'advertisement', child: Text('Advertisement')),

                            DropdownMenuItem(value: 'other', child: Text('Other')),

                          ],

                          onChanged: (value) {

                            if (dialogSetState != null) {

                              dialogSetState(() => _requirementSource = value);

                            } else {

                              setState(() => _requirementSource = value);

                            }

                          },

                          validator: (value) => value == null || value.isEmpty ? 'Select source' : null,

                        ),

                      ),

                      fieldBox(

                        TextFormField(

                          controller: _reqRegistryCtl,

                          decoration: _fieldDecoration('Registry/Transfer Number'),

                          maxLength: 50,

                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                          inputFormatters: [registryTransferNoFormatter],

                          validator: (value) {

                            if (value == null || value.isEmpty) return 'Enter registry or transfer number';

                            return validateRegistryTransferNo(value);

                          },

                        ),

                      ),

                      fieldBox(

                        TextFormField(

                          controller: _reqNextWorkingDateCtl,

                          readOnly: true,

                          onTap: _pickReqNextWorkingDate,

                          decoration: _fieldDecoration('Next Working Date', suffixIcon: const Icon(Icons.calendar_today), hint: 'Select next working date for reminder'),

                        ),

                      ),

                      fieldBox(

                        TextFormField(

                          controller: _reqCommentsCtl,

                          decoration: _fieldDecoration('Remarks'),

                          maxLines: 1,

                          maxLength: 200,

                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,

                          inputFormatters: [commentFormatter],

                          validator: validateComment,

                        ),

                        span: columns,

                      ),

                    ],

                  ),

                  const SizedBox(height: 16),

                  ImageUploadWidget(

                    imagePaths: _clientRequirementImages,

                    onImagesChanged: (images) {

                      setState(() {

                        _clientRequirementImages = images;

                      });

                    },

                    maxImages: 3,

                  ),

                  const SizedBox(height: 16),

                  Row(

                    children: [

                      OutlinedButton.icon(

                        onPressed: () {

                          _resetClientRequirementForm();

                          final navContext = dialogContext ?? context;

                          Navigator.of(navContext).pop();

                        },

                        icon: const Icon(Icons.close),

                        label: const Text('Cancel'),

                      ),

                      const Spacer(),

                      if (PermissionHelper.canAddModule(_currentUser, 'agent_working'))

                        PrimaryGradientButton(

                          text: 'Save',

                          icon: Icons.save,

                          onPressed: () => _submitClientRequirement(action: 'Save', dialogContext: dialogContext),

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

  }



  Widget _buildNotesSection({

    required String label,

    required TextEditingController controller,

    required GlobalKey<FormState> formKey,

    required VoidCallback onSave,

    required List<_WorkNote> notes,

    required bool isLoading,

    required String? error,

  }) {

    final noteFormat = DateFormat('dd MMM yyyy â€¢ hh:mm a');

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Form(

          key: formKey,

          child: Column(

            children: [

              TextFormField(

                controller: controller,

                maxLines: 4,

                decoration: _fieldDecoration('Notes', hint: 'Add notes for $label'),

                validator: (value) => value == null || value.trim().isEmpty ? 'Enter notes' : null,

              ),

              const SizedBox(height: 12),

              Align(

                alignment: Alignment.centerRight,

                child: PermissionHelper.canAddModule(_currentUser, 'agent_working')

                    ? FilledButton.icon(

                        icon: const Icon(Icons.save),

                        label: const Text('Save Note'),

                        onPressed: onSave,

                      )

                    : const SizedBox.shrink(),

              ),

            ],

          ),

        ),

        const SizedBox(height: 16),

        Divider(color: Colors.blueGrey.shade100),

        const SizedBox(height: 8),

        if (isLoading)

          const Padding(

            padding: EdgeInsets.symmetric(vertical: 12),

            child: Center(child: ShimmerBox(width: 140, height: 14)),

          )

        else if (error != null)

          Padding(

            padding: const EdgeInsets.symmetric(vertical: 12),

            child: Text(

              'Unable to load notes: $error',

              style: TextStyle(color: Colors.red.shade400),

            ),

          )

        else if (notes.isEmpty)

          Text(

            'No notes yet.',

            style: TextStyle(color: Colors.grey.shade600),

          )

        else

          Column(

            children: notes

                .map(

                  (entry) => Card(

                    margin: const EdgeInsets.only(bottom: 12),

                    elevation: 1,

                    child: ListTile(

                      key: ValueKey(entry.id),

                      leading: const Icon(Icons.note_alt, color: Colors.indigo),

                      title: Text(entry.text),

                      subtitle: Text(noteFormat.format(entry.createdAt)),

                    ),

                  ),

                )

                .toList(),

          ),

      ],

    );

  }



  Widget _buildComingSoon(String title) {

    return _buildSectionCard(

      title: title,

      body: const Text(

        'This form will be available soon.',

        style: TextStyle(color: Colors.black54),

      ),

    );

  }



  Widget _buildDataDisplaySection() {

    if (_loadingEntries) {

      return const ShimmerPageLoading(itemCount: 10);

    }



    final filteredEntries = _getFilteredEntries();



    if (filteredEntries.isEmpty) {

      return Center(

        child: Text('No ${_selectedType.toLowerCase()} entries found'),

      );

    }



    final TextStyle infoStyle = TextStyle(

      fontSize: 14,

      color: const Color(0xFFFF6B35),

    );



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Padding(

          padding: const EdgeInsets.all(12),

          child: Column(

            children: [

              Row(

                children: [

                  Expanded(

                    child: DropdownButtonFormField<String>(

                      value: _selectedType,

                      items: const [

                        DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),

                        DropdownMenuItem(value: 'Client Requirements', child: Text('Client Requirements')),

                      ],

                      onChanged: (v) {

                        if (v != null) {

                          setState(() {

                            _selectedType = v;

                          });

                        }

                      },

                      decoration: const InputDecoration(

                        labelText: 'Type',

                        border: OutlineInputBorder(),

                        filled: true,

                      ),

                    ),

                  ),

                ],

              ),

            ],

          ),

        ),

        Expanded(

          child: ListView.builder(

            padding: const EdgeInsets.symmetric(horizontal: 12),

            itemCount: filteredEntries.length,

            itemBuilder: (ctx, i) {

              final entry = filteredEntries[i];

              final status = entry['status'] ?? 'Pending';

              final statusColor = status == 'Done' 

                  ? Colors.green.shade700 

                  : status == 'Closed' 

                      ? Colors.orange.shade700 

                      : Colors.blue.shade700;

              

              // Build title similar to Inventory module

              final category = entry['category']?.toString() ?? '';

              final title = category.isNotEmpty 

                  ? '${entry['name'] ?? 'N/A'} â€¢ $category'

                  : entry['name'] ?? 'N/A';

              

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

                              // Can add detail view later if needed

                            },

                          ),

                          const SizedBox(width: 8),

                          PopupMenuButton(

                            icon: const Icon(Icons.more_vert),

                            itemBuilder: (context) => [

                              if (PermissionHelper.canDeleteModule(_currentUser, 'agent_working'))

                                PopupMenuItem(

                                  child: const Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Delete')]),

                                  onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _deleteEntry(entry['id'] as String)),

                                ),

                            ],

                          ),

                        ],

                      ),

                      const SizedBox(height: 8),

                      buildResponsiveInfoRow(

                        context,

                        [

                          InfoEntry('Owner Name', entry['name'], style: infoStyle),

                        ],

                      ),

                      // Size field with color coding

                      if (entry['size'] != null && entry['size'].toString().isNotEmpty)

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

                                  color: _getSizeColor(entry['size']?.toString() ?? '').withOpacity(0.3),

                                  borderRadius: BorderRadius.circular(6),

                                  border: Border.all(

                                    color: _getSizeColor(entry['size']?.toString() ?? ''),

                                    width: 2,

                                  ),

                                ),

                                child: Text(

                                  entry['size']?.toString() ?? '',

                                  style: _getSizeStyle(entry['size']?.toString() ?? ''),

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

                      // Load and display images from Firestore (with caching)

                      FutureBuilder<Map<String, dynamic>?>(

                        future: entry['id'] != null

                            ? FirestoreCacheService().getCachedDocument(

                                'working_progress',

                                entry['id']?.toString() ?? '',

                              )

                            : Future<Map<String, dynamic>?>.value(null),

                        builder: (context, snapshot) {

                          if (snapshot.connectionState == ConnectionState.waiting) {

                            return const SizedBox.shrink();

                          }

                          if (!snapshot.hasData || snapshot.data == null) {

                            return const SizedBox.shrink();

                          }

                          final data = snapshot.data!;

                          final imagePaths = data['imagePaths'];

                          if (imagePaths == null) {

                            return const SizedBox.shrink();

                          }

                          // Handle both List<dynamic> and List<String>

                          List<String> paths = [];

                          if (imagePaths is List) {

                            paths = imagePaths.map((p) => p.toString()).toList();

                          } else if (imagePaths is String) {

                            paths = [imagePaths];

                          }

                          if (paths.isEmpty) {

                            return const SizedBox.shrink();

                          }

                          return Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              const SizedBox(height: 8),

                              Text(

                                'Images:',

                                style: TextStyle(

                                  fontSize: 13,

                                  fontWeight: FontWeight.w600,

                                  color: Colors.grey.shade700,

                                ),

                              ),

                              const SizedBox(height: 8),

                              Wrap(

                                spacing: 8,

                                runSpacing: 8,

                                children: paths.take(3).map((path) {

                                  return GestureDetector(

                                    onTap: () {

                                      showDialog(

                                        context: context,

                                        builder: (ctx) => Dialog(

                                          child: Stack(

                                            children: [

                                              Container(

                                                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),

                                                              child: CachedImageWidget(

                                                                imagePath: path.toString(),

                                                                fit: BoxFit.contain,

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

                                    },

                                    child: Container(

                                      width: 60,

                                      height: 60,

                                      decoration: BoxDecoration(

                                        border: Border.all(color: Colors.grey.shade300),

                                        borderRadius: BorderRadius.circular(8),

                                      ),

                                      child: ClipRRect(

                                        borderRadius: BorderRadius.circular(8),

                                        child: CachedImageWidget(

                                          imagePath: path.toString(),

                                          fit: BoxFit.cover,

                                          width: 60,

                                          height: 60,

                                          errorWidget: const Icon(Icons.broken_image, size: 24),

                                        ),

                                      ),

                                    ),

                                  );

                                }).toList(),

                              ),

                            ],

                          );

                        },

                      ),

                      const SizedBox(height: 8),

                      Text(

                        'Updated: ${entry['updated_at']?.toString().split('T').first ?? ''}',

                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),

                      ),

                    ],

                  ),

                ),

              );

            },

          ),

        ),

      ],

    );

  }



  Future<void> _updateEntryStatus(String id, String status, {DateTime? nextDate}) async {

    try {

      final nowIso = DateTime.now().toUtc().toIso8601String();

      final nextDateStr = nextDate != null ? DateFormat('yyyy-MM-dd').format(nextDate) : null;



      // Update in SQLite

      await widget.db.customStatement(

        'UPDATE working_progress SET status = ?, next_working_date = ?, updated_at = ? WHERE id = ?',

        [status, nextDateStr ?? '', nowIso, id],

      );



      // Update in Firestore if available

      try {

        if (Firebase.apps.isNotEmpty) {

          final firestore = FirebaseFirestore.instance;

          await firestore.collection('working_progress').doc(id).update({

            'status': status,

            'nextWorkingDate': nextDateStr,

            'updatedAt': nowIso,

          });

        }

      } catch (e) {

        debugPrint('Firestore update failed: $e');

      }



      await _loadSavedEntries();

      if (mounted) {

        final dateMsg = nextDateStr != null ? ' (Next Date: ${DateFormat('dd MMM yyyy').format(nextDate!)})' : '';

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Status updated to $status$dateMsg')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to update status: $e')),

        );

      }

    }

  }



  Future<void> _handleDone(Map<String, dynamic> entry) async {

    await _updateEntryStatus(entry['id'] as String, 'Done');

  }



  Future<void> _handleNextDate(Map<String, dynamic> entry) async {

    final existingNextDate = entry['nextWorkingDate']?.toString() ?? entry['next_working_date']?.toString();

    DateTime? initialDate;

    if (existingNextDate != null && existingNextDate.isNotEmpty) {

      try {

        initialDate = DateTime.tryParse(existingNextDate);

        if (initialDate == null) {

          initialDate = DateFormat('yyyy-MM-dd').parse(existingNextDate);

        }

      } catch (e) {

        initialDate = DateTime.now();

      }

    } else {

      initialDate = DateTime.now();

    }



    final picked = await showDatePicker(

      context: context,

      initialDate: initialDate,

      firstDate: DateTime.now(),

      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),

    );

    if (picked != null) {

      await _updateEntryStatus(entry['id'] as String, entry['status']?.toString() ?? 'Pending', nextDate: picked);

    }

  }



  Future<void> _handleCloseIncomplete(Map<String, dynamic> entry) async {

    await _updateEntryStatus(entry['id'] as String, 'Closed');

  }



  Future<void> _deleteEntry(String id) async {

    // Permission check: Only allow delete if user has full_access

    if (!PermissionHelper.canDeleteModule(_currentUser, 'agent_working')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('You do not have permission to delete entries.'),

            backgroundColor: Colors.red,

          ),

        );

      }

      return;

    }

    

    final confirm = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('Delete Entry'),

        content: const Text('Are you sure you want to delete this entry?'),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context, false),

            child: const Text('Cancel'),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(context, true),

            style: FilledButton.styleFrom(backgroundColor: Colors.red),

            child: const Text('Delete'),

          ),

        ],

      ),

    );



    if (confirm == true) {

      try {

        await widget.db.customStatement(

          'DELETE FROM working_progress WHERE id = ?',

          [id],

        );

        await _loadSavedEntries();

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('Entry deleted successfully')),

          );

        }

      } catch (e) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(content: Text('Failed to delete entry: $e')),

          );

        }

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: Text(

          'Agent Working',

          style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),

        ),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        flexibleSpace: Container(

          decoration: BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [

                const Color(0xFFFF6B35), // Orange

                const Color(0xFF4A90E2), // Blue

              ],

            ),

          ),

        ),

        actions: [

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

            child: TopRightSearch(onChanged: (q) {

              setState(() {

                _q = q;

                // Reset pagination for current tab on search

                _tabPages[_selectedType] = 0;

                _currentPage = 0;

              });

            }),

          ),

        ],

        bottom: TabBar(

          controller: _tabController,

          indicatorColor: Colors.white,

          indicatorWeight: 3,

          labelColor: Colors.white,

          unselectedLabelColor: Colors.white.withOpacity(0.7),

          labelStyle: AppFonts.poppins(

            fontSize: 14,

            fontWeight: FontWeight.w600,

          ),

          unselectedLabelStyle: AppFonts.poppins(

            fontSize: 14,

            fontWeight: FontWeight.normal,

          ),

          tabs: const [

            Tab(text: 'Transfer'),

            Tab(text: 'Client Requirements'),

          ],

          onTap: (index) {

            setState(() {

              _selectedType = index == 0 ? 'Transfer' : 'Client Requirements';

              _currentPage = _tabPages[_selectedType] ?? 0;

            });

            // Mark tab as loaded

            _loadedTabs.add(index);

          },

        ),

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: _showAddFormDialog,

        icon: const Icon(Icons.add),

        label: Text(_selectedType == 'Transfer' ? 'Add Transfer' : 'Add Client Requirement'),

        hoverColor: const Color(0xFFFF7C4F),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

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

        child: IndexedStack(

          index: _tabController.index,

          children: [

            // Transfer tab

            _buildTabContent('Transfer'),

            // Client Requirements tab

            _buildTabContent('Client Requirements'),

          ],

        ),

      ),

    );

  }

  

  Widget _buildTabContent(String tabType) {

    // Only build content if tab has been loaded (lazy loading)

    if (!_loadedTabs.contains(tabType == 'Transfer' ? 0 : 1)) {

      return const SizedBox.shrink();

    }

    

    final allFiltered = _getFilteredEntriesForTab(tabType);

    final paginatedEntries = _getPaginatedEntriesForTab(tabType);

    final scrollController = _tabScrollControllers[tabType] ?? _scrollController;

    

    if (_loadingEntries && _savedEntries.isEmpty) {

      return const ShimmerPageLoading(itemCount: 10);

    }

    

    if (allFiltered.isEmpty) {

      return Center(

        child: Padding(

          padding: const EdgeInsets.all(32),

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

                'No ${tabType.toLowerCase()} entries found',

                style: AppFonts.poppins(

                  fontSize: 16,

                  color: Colors.grey.shade600,

                ),

              ),

            ],

          ),

        ),

      );

    }

    

    return ListView.builder(

      controller: scrollController,

      padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),

      itemCount: paginatedEntries.length + (_hasMoreEntriesForTab(tabType) ? 1 : 0),

      itemBuilder: (ctx, i) {

        if (i == paginatedEntries.length) {

          // Show shimmer effect while loading more

          return Padding(

            padding: const EdgeInsets.symmetric(vertical: 8),

            child: ShimmerListPlaceholder(itemCount: 3, itemHeight: 100),

          );

        }

        return _buildEntryCard(paginatedEntries[i]);

      },

    );

  }





  void _resetTransferForm() {

    _transferFormKey.currentState?.reset();

    _dateCtl.clear();

    _plotCtl.clear();

    _clientNameCtl.clear();

    _clientMobileCtl.clear();

    _timeCtl.clear();

    _registryCtl.clear();

    _commentsCtl.clear();

    _nextWorkingDateCtl.clear();

    _transferOtherCategoryCtl.clear();

    _transferOtherSizeCtl.clear();

    _transferCategory = null;

    _transferSize = null;

    _selectedDate = null;

    _selectedTime = null;

    _nextWorkingDate = null;

    _transferImages = []; // Reset images

  }



  void _resetClientRequirementForm() {

    _clientRequirementFormKey.currentState?.reset();

    _reqDateCtl.clear();

    _reqPlotCtl.clear();

    _reqClientNameCtl.clear();

    _reqClientMobileCtl.clear();

    _reqTimeCtl.clear();

    _reqRegistryCtl.clear();

    _reqCommentsCtl.clear();

    _reqNextWorkingDateCtl.clear();

    _requirementCategory = null;

    _requirementSource = null;

    _reqSelectedDate = null;

    _reqSelectedTime = null;

    _reqNextWorkingDate = null;

    _clientRequirementImages = []; // Reset images

  }



  void _showAddFormDialog() {

    showDialog(

      context: context,

      barrierDismissible: false, // Prevent closing by clicking outside

      builder: (dialogBuilderContext) => Focus(

        autofocus: true,

        onKeyEvent: (node, event) {

          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {

            if (_selectedType == 'Transfer') {

              _resetTransferForm();

            } else {

              _resetClientRequirementForm();

            }

            Navigator.of(dialogBuilderContext).pop();

            return KeyEventResult.handled;

          }

          return KeyEventResult.ignored;

        },

        child: Dialog(

          insetPadding: const EdgeInsets.all(16),

          child: Container(

            width: MediaQuery.of(dialogBuilderContext).size.width * 0.9,

            height: MediaQuery.of(dialogBuilderContext).size.height * 0.9,

            child: StatefulBuilder(

              builder: (dialogContext, setDialogState) {

                return Stack(

                  children: [

                    // Form content with padding for back button

                    Padding(

                      padding: const EdgeInsets.only(top: 56), // Space for back button

                      child: SingleChildScrollView(

                        padding: const EdgeInsets.all(16),

                        child: _selectedType == 'Transfer' 

                            ? _buildTransferForm(setDialogState, dialogContext) 

                            : _buildClientRequirementForm(setDialogState, dialogContext),

                      ),

                    ),

                    // Back button at top-left

                    Positioned(

                      top: 8,

                      left: 8,

                      child: IconButton(

                        icon: const Icon(Icons.arrow_back),

                        onPressed: () {

                          if (_selectedType == 'Transfer') {

                            _resetTransferForm();

                          } else {

                            _resetClientRequirementForm();

                          }

                          // Use dialogContext which is the correct dialog context

                          Navigator.of(dialogContext).pop();

                        },

                        style: IconButton.styleFrom(

                          backgroundColor: Colors.white.withOpacity(0.9),

                          elevation: 2,

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



  // Helper function to get sort order for plot sizes

  int _getSizeSortOrder(String? size) {

    if (size == null || size.isEmpty) return 999; // Put empty sizes at the end

    final sizeLower = size.toLowerCase();

    if (sizeLower.contains('2 marla')) return 1;

    if (sizeLower.contains('3 marla')) return 2;

    if (sizeLower.contains('5 marla')) return 3;

    if (sizeLower.contains('8 marla')) return 4;

    // Custom sizes (Other) should come after standard sizes but before empty

    return 500; // Custom sizes in the middle

  }



  Widget _buildEntryCard(Map<String, dynamic> entry) {

    final status = entry['status'] ?? 'Pending';

    final statusColor = status == 'Done' 

        ? Colors.green.shade700 

        : status == 'Closed' 

            ? Colors.orange.shade700 

            : Colors.blue.shade700;

    

    final TextStyle infoStyle = TextStyle(

      fontSize: 14,

      color: const Color(0xFFFF6B35),

    );

    

    // Build title similar to Inventory module

    final category = entry['category']?.toString() ?? '';

    final title = category.isNotEmpty 

        ? '${entry['name'] ?? 'N/A'} â€¢ $category'

        : entry['name'] ?? 'N/A';

    

    // Get background color based on size

    // Check multiple possible field names for size

    final sizeValue = (entry['size']?.toString() ?? 

                       entry['Size']?.toString() ?? 

                       '').trim();

    final sizeColor = sizeValue.isNotEmpty ? _getSizeColor(sizeValue) : null;

    

    // Get image paths from entry

    final imagePaths = entry['imagePaths'] != null 

        ? List<String>.from(entry['imagePaths'] is List ? entry['imagePaths'] : [])

        : <String>[];

    

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

                        builder: (context) => AgentWorkingDetailPage(

                          entryData: entry,

                          db: widget.db,

                          onUpdate: () => _loadSavedEntries(),

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

                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),

                          const SizedBox(width: 8),

                          const Text('Done'),

                        ],

                      ),

                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _handleDone(entry)),

                    ),

                    PopupMenuItem<String>(

                      child: Row(

                        children: [

                          Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade700),

                          const SizedBox(width: 8),

                          const Text('Next Date'),

                        ],

                      ),

                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _handleNextDate(entry)),

                    ),

                    PopupMenuItem<String>(

                      child: Row(

                        children: [

                          Icon(Icons.close, size: 18, color: Colors.orange.shade700),

                          const SizedBox(width: 8),

                          const Text('Close Incomplete'),

                        ],

                      ),

                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _handleCloseIncomplete(entry)),

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

                      onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _deleteEntry(entry['id'] as String)),

                    ),

                  ],

                ),

              ],

            ),

            const SizedBox(height: 8),

            buildResponsiveInfoRow(

              context,

              [

                InfoEntry('Owner Name', entry['name'], style: infoStyle),

              ],

            ),

            // Size field with color coding

            if (entry['size'] != null && entry['size'].toString().isNotEmpty)

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

                        color: _getSizeColor(entry['size']?.toString() ?? '').withOpacity(0.3),

                        borderRadius: BorderRadius.circular(6),

                        border: Border.all(

                          color: _getSizeColor(entry['size']?.toString() ?? ''),

                          width: 2,

                        ),

                      ),

                      child: Text(

                        entry['size']?.toString() ?? '',

                        style: _getSizeStyle(entry['size']?.toString() ?? ''),

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

            Text(

              'Updated: ${entry['updated_at']?.toString().split('T').first ?? ''}',

              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),

            ),

            // Image thumbnails

            if (imagePaths.isNotEmpty) ...[

              const SizedBox(height: 12),

              Text(

                'Images:',

                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),

              ),

              const SizedBox(height: 8),

              Wrap(

                spacing: 8,

                runSpacing: 8,

                children: imagePaths.take(3).map((imagePath) {

                  return GestureDetector(

                    onTap: () {

                      showDialog(

                        context: context,

                        builder: (ctx) => Dialog(

                          child: Stack(

                            children: [

                              Container(

                                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),

                                child: CachedImageWidget(

                                  imagePath: imagePath,

                                  fit: BoxFit.contain,

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

                    },

                    child: Container(

                      width: 60,

                      height: 60,

                      decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(color: Colors.grey.shade300),

                      ),

                      child: ClipRRect(

                        borderRadius: BorderRadius.circular(8),

                        child: CachedImageWidget(

                          imagePath: imagePath,

                          fit: BoxFit.cover,

                          width: 60,

                          height: 60,

                          errorWidget: const Icon(Icons.broken_image, size: 30),

                        ),

                      ),

                    ),

                  );

                }).toList(),

              ),

            ],

          ],

        ),

      ),

    );

  }

}



class AgentWorkingDetailPage extends StatefulWidget {

  final Map<String, dynamic> entryData;

  final AppDatabase db;

  final VoidCallback onUpdate;



  const AgentWorkingDetailPage({

    super.key,

    required this.entryData,

    required this.db,

    required this.onUpdate,

  });



  @override

  State<AgentWorkingDetailPage> createState() => _AgentWorkingDetailPageState();

}



class _AgentWorkingDetailPageState extends State<AgentWorkingDetailPage> {

  DateTime? _selectedNextDate;



  @override

  void initState() {

    super.initState();

    // Initialize next date from existing data

    final nextDateStr = widget.entryData['nextWorkingDate']?.toString() ?? 

                        widget.entryData['next_working_date']?.toString();

    if (nextDateStr != null && nextDateStr.isNotEmpty) {

      try {

        // Try parsing ISO format first

        _selectedNextDate = DateTime.tryParse(nextDateStr);

        // If that fails, try yyyy-MM-dd format

        if (_selectedNextDate == null) {

          _selectedNextDate = DateFormat('yyyy-MM-dd').parse(nextDateStr);

        }

      } catch (e) {

        debugPrint('Failed to parse next date: $e');

      }

    }

  }



  Future<void> _updateStatus(String status, {DateTime? nextDate}) async {

    try {

      final nowIso = DateTime.now().toUtc().toIso8601String();

      final id = widget.entryData['id'] as String;

      // Use yyyy-MM-dd format to match the rest of the codebase

      final nextDateStr = nextDate != null ? DateFormat('yyyy-MM-dd').format(nextDate) : null;



      // Update in SQLite

      await widget.db.customStatement(

        'UPDATE working_progress SET status = ?, next_working_date = ?, updated_at = ? WHERE id = ?',

        [status, nextDateStr ?? '', nowIso, id],

      );



      // Update in Firestore if available

      try {

        if (Firebase.apps.isNotEmpty) {

          final firestore = FirebaseFirestore.instance;

          await firestore.collection('working_progress').doc(id).update({

            'status': status,

            'nextWorkingDate': nextDateStr,

            'updatedAt': nowIso,

          });

        }

      } catch (e) {

        debugPrint('Firestore update failed: $e');

      }



      if (mounted) {

        widget.onUpdate();

        Navigator.pop(context);

        final dateMsg = nextDateStr != null ? ' (Next Date: ${DateFormat('dd MMM yyyy').format(nextDate!)})' : '';

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Status updated to $status$dateMsg')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to update status: $e')),

        );

      }

    }

  }



  Future<void> _printDocument() async {

    final entry = widget.entryData;

    final isTransfer = entry['type']?.toString() == 'transfer' ||

        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);

    final title = isTransfer ? 'Transfer Details' : 'Client Requirements Details';

    final serial = generateReportSerial(prefix: 'RPT');

    final generatedAt = DateTime.now();



    final currentUser = await loadCurrentUserFromStorage();

    final entityId = entry['id']?.toString();

    final fields = <MapEntry<String, String>>[

      MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirements'),

      MapEntry('Status', entry['status']?.toString() ?? 'N/A'),

      if (entry['category'] != null) MapEntry('Category', entry['category']?.toString() ?? 'N/A'),

      MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'),

      MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'),

      if (entry['plotNo'] != null) MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'),

      if (entry['registryNumber'] != null)

        MapEntry('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'),

      if (entry['transferDate'] != null || entry['transfer_date'] != null)

        MapEntry('Date', ((entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '').split('T').first.split(' ').first),

      if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null)

        MapEntry('Next Working Date', ((entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '').split('T').first.split(' ').first),

      MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'),

      if (entry['remarks'] != null && entry['remarks'].toString().trim().isNotEmpty)

        MapEntry('Remarks', entry['remarks'].toString()),

    ];



    await logReportHistory(

      db: widget.db,

      currentUser: currentUser,

      companyId: RoleUtils.getUserCompanyId(currentUser),

      module: 'agent_working',

      entityId: entityId,

      reportType: title,

      action: 'print',

      serialNumber: serial,

      generatedAt: generatedAt,

    );



    await Printing.layoutPdf(

      onLayout: (_) async {

        final a4Format = PdfPageFormat.a4;

        return buildKeyValueReportPdf(

          format: a4Format,

          db: widget.db,

          currentUser: currentUser,

          module: 'agent_working',

          entityId: entityId,

          title: title,

          action: 'print',

          fields: fields,

          serialNumber: serial,

          generatedAt: generatedAt,

          logHistory: false,

        );

      },

    );

  }



  Future<void> _downloadPdf() async {

    try {

      final entry = widget.entryData;

      final isTransfer = entry['type']?.toString() == 'transfer' ||

          (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);

      final title = isTransfer ? 'Transfer Details' : 'Client Requirements Details';

      

      // Show immediate feedback dialog

      if (!mounted) return;

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

                Text('Generating PDF...', style: AppFonts.poppins(fontSize: 14)),

              ],

            ),

          ),

        ),

      );

      

      // Pre-load ALL data BEFORE compute() to prevent blocking

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

      final entryData = {

        'id': entry['id']?.toString(),

        'type': entry['type']?.toString(),

        'category': entry['category']?.toString(),

        'status': entry['status']?.toString(),

        'name': entry['name']?.toString(),

        'clientMobile': entry['clientMobile']?.toString(),

        'plotNo': entry['plotNo']?.toString(),

        'registryNumber': entry['registryNumber']?.toString(),

        'transferDate': entry['transferDate']?.toString(),

        'transfer_date': entry['transfer_date']?.toString(),

        'nextWorkingDate': entry['nextWorkingDate']?.toString(),

        'next_working_date': entry['next_working_date']?.toString(),

        'updated_at': entry['updated_at']?.toString(),

        'updatedAt': entry['updatedAt']?.toString(),

        'remarks': entry['remarks']?.toString(),

      };

      

      // Build fields in isolate to keep UI responsive

      final fields = await compute(_buildRentalFieldsInIsolate, {

        'entry': entryData,

        'isTransfer': isTransfer,

      });

      

      final entityId = entry['id']?.toString();

      final bytes = await buildKeyValueReportPdf(

        format: PdfPageFormat.a4,

        db: widget.db,

        currentUser: currentUser,

        module: 'agent_working',

        entityId: entityId,

        title: title,

        action: 'download',

        fields: fields,

        preloadedBaseFontBytes: baseFontBytes,

        preloadedBoldFontBytes: boldFontBytes,

        preloadedBranding: branding,

      );

      

      if (mounted) {

        Navigator.pop(context); // Close loading dialog

      }

      

      await savePdfBytesToDisk(

        pdfBytes: bytes,

        suggestedBaseName: 'agent_working_${entityId ?? 'detail'}_${fmtTs(DateTime.now())}',

      );

      

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('PDF exported successfully')),

        );

      }

    } catch (e) {

      if (mounted) {

        Navigator.pop(context); // Close loading dialog if still open

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),

        );

      }

    }

  }



  Future<void> _generateProfessionalReceipt() async {

    final entry = widget.entryData;

    final isTransfer = entry['type']?.toString() == 'transfer' ||

        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);

    final title = isTransfer ? 'Transfer Receipt' : 'Client Requirements Receipt';



    final keyValues = <MapEntry<String, String>>[

      MapEntry('Reference', entry['id']?.toString() ?? 'N/A'),

      MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirement'),

      MapEntry('Status', entry['status']?.toString() ?? 'N/A'),

      if (entry['category'] != null) MapEntry('Category', entry['category']?.toString() ?? 'N/A'),

      MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'),

      MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'),

      if (entry['plotNo'] != null) MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'),

      if (entry['registryNumber'] != null) MapEntry('Registry/Transfer #', entry['registryNumber']?.toString() ?? 'N/A'),

      if (entry['transferDate'] != null || entry['transfer_date'] != null)

        MapEntry('Date', (entry['transferDate'] ?? entry['transfer_date'])?.toString().split('T').first ?? 'N/A'),

      if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null)

        MapEntry('Next Working Date', (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString().split('T').first ?? 'N/A'),

      MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'),

      if (entry['remarks'] != null && entry['remarks'].toString().trim().isNotEmpty) MapEntry('Remarks', entry['remarks'].toString()),

    ];



    final gridRows = <Map<String, String>>[

      {

        'Client': entry['name']?.toString() ?? 'N/A',

        'Plot/Block': (entry['plotNo'] ?? entry['registryNumber'] ?? '-').toString(),

        'Status': entry['status']?.toString() ?? 'N/A',

        'Next Date': ((entry['nextWorkingDate'] ?? entry['next_working_date']) ?? '-').toString(),

      },

    ];



    await ProfessionalPdfGenerator.generateReceipt(

      context: context,

      db: widget.db,

      module: 'Rental',

      title: title,

      entityId: entry['id']?.toString(),

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

  

  /// Builds rental fields in isolate to prevent UI blocking

  static List<MapEntry<String, String>> _buildRentalFieldsInIsolate(Map<String, dynamic> args) {

    final entry = args['entry'] as Map<String, dynamic>;

    final isTransfer = args['isTransfer'] as bool;

    

    final fields = <MapEntry<String, String>>[];

    

    fields.add(MapEntry('Type', isTransfer ? 'Transfer' : 'Client Requirements'));

    fields.add(MapEntry('Status', entry['status']?.toString() ?? 'N/A'));

    if (entry['category'] != null) {

      fields.add(MapEntry('Category', entry['category']?.toString() ?? 'N/A'));

    }

    fields.add(MapEntry('Client Name', entry['name']?.toString() ?? 'N/A'));

    fields.add(MapEntry('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'));

    if (entry['plotNo'] != null) {

      fields.add(MapEntry('Plot No.', entry['plotNo']?.toString() ?? 'N/A'));

    }

    if (entry['registryNumber'] != null) {

      fields.add(MapEntry('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'));

    }

    if (entry['transferDate'] != null || entry['transfer_date'] != null) {

      final dateStr = (entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '';

      fields.add(MapEntry('Date', dateStr.split('T').first.split(' ').first));

    }

    if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null) {

      final nextDateStr = (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '';

      fields.add(MapEntry('Next Working Date', nextDateStr.split('T').first.split(' ').first));

    }

    fields.add(MapEntry('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'));

    if (entry['remarks'] != null && entry['remarks'].toString().trim().isNotEmpty) {

      fields.add(MapEntry('Remarks', entry['remarks'].toString()));

    }

    

    return fields;

  }



  Future<Uint8List> _generatePdf(PdfPageFormat format) async {

    final entry = widget.entryData;

    final isTransfer = entry['type']?.toString() == 'transfer' ||

        (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);

    final title = isTransfer ? 'Transfer Details' : 'Client Requirements Details';

    

    // Prepare data for isolate - convert to serializable format

    final entryData = {

      'id': entry['id']?.toString(),

      'type': entry['type']?.toString(),

      'category': entry['category']?.toString(),

      'status': entry['status']?.toString(),

      'name': entry['name']?.toString(),

      'clientMobile': entry['clientMobile']?.toString(),

      'plotNo': entry['plotNo']?.toString(),

      'registryNumber': entry['registryNumber']?.toString(),

      'transferDate': entry['transferDate']?.toString(),

      'transfer_date': entry['transfer_date']?.toString(),

      'nextWorkingDate': entry['nextWorkingDate']?.toString(),

      'next_working_date': entry['next_working_date']?.toString(),

      'updated_at': entry['updated_at']?.toString(),

      'updatedAt': entry['updatedAt']?.toString(),

      'remarks': entry['remarks']?.toString(),

    };

    

    // Build fields in isolate to keep UI responsive

    final fields = await compute(_buildRentalFieldsInIsolate, {

      'entry': entryData,

      'isTransfer': isTransfer,

    });

    

    final currentUser = await loadCurrentUserFromStorage();

    final entityId = entry['id']?.toString();

    return buildKeyValueReportPdf(

      format: format,

      db: widget.db,

      currentUser: currentUser,

      module: 'agent_working',

      entityId: entityId,

      title: title,

      action: 'print',

      fields: fields,

      logHistory: false,

    );

  }



  pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {

    return pw.Column(

      crossAxisAlignment: pw.CrossAxisAlignment.start,

      children: [

        pw.Text(

          title,

          style: pw.TextStyle(

            fontSize: 15,

            fontWeight: pw.FontWeight.bold,

          ),

        ),

        pw.SizedBox(height: 8),

        ...children,

        pw.SizedBox(height: 8),

      ],

    );

  }



  pw.Widget _buildPdfRow(String label, String value) {

    return pw.Padding(

      padding: const pw.EdgeInsets.only(bottom: 6),

      child: pw.Row(

        crossAxisAlignment: pw.CrossAxisAlignment.start,

        children: [

          pw.SizedBox(

            width: 140,

            child: pw.Text(

              '$label:',

              style: pw.TextStyle(

                fontSize: 11,

                fontWeight: pw.FontWeight.bold,

              ),

            ),

          ),

          pw.Expanded(

            child: pw.Text(

              value,

              style: const pw.TextStyle(fontSize: 11),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildDetailRow(String label, String value) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 140,

            child: Text(

              '$label:',

              style: TextStyle(

                fontWeight: FontWeight.w600,

                color: Colors.grey.shade700,

              ),

            ),

          ),

          Expanded(

            child: Text(

              value,

              style: const TextStyle(fontSize: 14),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildDetailSection(BuildContext context, String title, IconData icon, List<Widget> children, bool isMobile) {

    return Card(

      elevation: 1,

      child: Padding(

        padding: EdgeInsets.all(isMobile ? 10 : 12),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                Icon(icon, size: 18, color: const Color(0xFFFF6B35)),

                const SizedBox(width: 8),

                Text(

                  title,

                  style: AppFonts.poppins(

                    fontSize: isMobile ? 14 : 16,

                    fontWeight: FontWeight.w600,

                    color: const Color(0xFFFF6B35),

                  ),

                ),

              ],

            ),

            const SizedBox(height: 8),

            ...children,

          ],

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final entry = widget.entryData;

    final status = entry['status']?.toString() ?? 'Pending';

    final isTransfer = entry['type']?.toString() == 'transfer' || 

                       (entry['type']?.toString()?.isEmpty ?? true && entry['category'] != null);

    final statusColor = status == 'Done' 

        ? Colors.green.shade700 

        : status == 'Closed' 

            ? Colors.orange.shade700 

            : Colors.blue.shade700;



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

        appBar: AppBar(

          leading: IconButton(

            icon: const Icon(Icons.arrow_back),

            onPressed: () => Navigator.pop(context),

            tooltip: 'Back (ESC)',

          ),

          title: Text(

            isTransfer ? 'Transfer Details' : 'Client Requirements Details',

            style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),

          ),

          centerTitle: true,

          elevation: 0,

          backgroundColor: Colors.transparent,

          flexibleSpace: Container(

            decoration: BoxDecoration(

              gradient: LinearGradient(

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,

                colors: [Colors.purple.shade500, Colors.purple.shade400, Colors.purple.shade300],

              ),

            ),

          ),

          actions: [

          TextButton.icon(

            onPressed: _generateProfessionalReceipt,

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

                const Color(0xFFFF6B35).withOpacity(0.03), // Very subtle orange

                const Color(0xFF4A90E2).withOpacity(0.03), // Very subtle blue

              ],

            ),

            border: Border.all(

              color: Colors.grey.shade300.withOpacity(0.5),

              width: 1,

            ),

          ),

          child: LayoutBuilder(

            builder: (context, constraints) {

              final maxWidth = constraints.maxWidth;

              final isMobile = maxWidth < 600;



              return SingleChildScrollView(

                child: Center(

                  child: Container(

                    constraints: const BoxConstraints(maxWidth: 850),

                    child: Card(

                      elevation: 4,

                      margin: EdgeInsets.all(isMobile ? 12 : 16),

                      child: Padding(

                        padding: EdgeInsets.all(isMobile ? 12 : 16),

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.stretch,

                          children: [

                            // Header

                            Center(

                              child: Text(

                                isTransfer ? 'Transfer Details' : 'Client Requirements Details',

                                style: AppFonts.poppins(

                                  fontSize: isMobile ? 20 : 22,

                                  fontWeight: FontWeight.bold,

                                  color: const Color(0xFFFF6B35),

                                ),

                              ),

                            ),

                            const SizedBox(height: 16),

                            Divider(color: Colors.grey.shade300),

                            const SizedBox(height: 16),

                            

                            // Basic Information

                            _buildDetailSection(

                              context,

                              'Basic Information',

                              Icons.info,

                              [

                                _buildDetailRow('Type', isTransfer ? 'Transfer' : 'Client Requirements'),

                                _buildDetailRow('Status', status),

                                if (entry['category'] != null)

                                  _buildDetailRow('Category', entry['category']?.toString() ?? 'N/A'),

                              ],

                              isMobile,

                            ),

                            

                            const SizedBox(height: 12),

                            

                            // Client Information

                            _buildDetailSection(

                              context,

                              'Client Information',

                              Icons.person,

                              [

                                _buildDetailRow('Client Name', entry['name']?.toString() ?? 'N/A'),

                                _buildDetailRow('Client Mobile', entry['clientMobile']?.toString() ?? 'N/A'),

                                if (entry['plotNo'] != null)

                                  _buildDetailRow('Plot No.', entry['plotNo']?.toString() ?? 'N/A'),

                                if (entry['registryNumber'] != null)

                                  _buildDetailRow('Registry/Transfer Number', entry['registryNumber']?.toString() ?? 'N/A'),

                              ],

                              isMobile,

                            ),

                            

                            const SizedBox(height: 12),

                            

                            // Date Information

                            _buildDetailSection(

                              context,

                              'Date Information',

                              Icons.calendar_today,

                              () {

                                final dateRows = <Widget>[];

                                if (entry['transferDate'] != null || entry['transfer_date'] != null) {

                                  final dateStr = (entry['transferDate'] ?? entry['transfer_date'])?.toString() ?? '';

                                  dateRows.add(_buildDetailRow('Date', dateStr.split('T').first.split(' ').first));

                                }

                                if (entry['nextWorkingDate'] != null || entry['next_working_date'] != null) {

                                  final nextDateStr = (entry['nextWorkingDate'] ?? entry['next_working_date'])?.toString() ?? '';

                                  dateRows.add(_buildDetailRow('Next Working Date', nextDateStr.split('T').first.split(' ').first));

                                }

                                dateRows.add(_buildDetailRow('Updated', (entry['updated_at'] ?? entry['updatedAt'])?.toString().split('T').first ?? 'N/A'));

                                return dateRows;

                              }(),

                              isMobile,

                            ),

                            

                            if (entry['remarks'] != null && entry['remarks'].toString().isNotEmpty) ...[

                              const SizedBox(height: 12),

                              _buildDetailSection(

                                context,

                                'Remarks',

                                Icons.comment,

                                [

                                  Padding(

                                    padding: const EdgeInsets.only(top: 4),

                                    child: Text(

                                      entry['remarks'].toString(),

                                      style: const TextStyle(fontSize: 14),

                                    ),

                                  ),

                                ],

                                isMobile,

                              ),

                            ],

                          ],

                        ),

                      ),

                    ),

                  ),

                ),

              );

            },

          ),

        ),

      ),

    );

  }

}



class RentalDetailPage extends StatelessWidget {

  final Map<String, dynamic> entry;

  final AppDatabase db;



  const RentalDetailPage({super.key, required this.entry, required this.db});



  List<MapEntry<String, String>> _keyValues() {

    return [

      MapEntry('Property Type', entry['name']?.toString() ?? 'N/A'),

      MapEntry('Owner Name', entry['owner_name']?.toString() ?? 'N/A'),

      MapEntry('Monthly Rent', entry['price']?.toString() ?? 'N/A'),

      MapEntry('Security', entry['security']?.toString() ?? 'N/A'),

      MapEntry('Location', entry['location']?.toString() ?? 'N/A'),

      MapEntry('Status', entry['sale_status']?.toString() ?? 'N/A'),

      MapEntry('Contact', entry['contact_no']?.toString() ?? 'N/A'),

      MapEntry('Updated At', entry['updated_at']?.toString().split('T').first ?? 'N/A'),

      if ((entry['remarks'] ?? '').toString().trim().isNotEmpty) MapEntry('Remarks', entry['remarks'].toString()),

    ];

  }



  List<Map<String, String>> _gridRows() {

    return [

      {

        'Property Type': entry['name']?.toString() ?? 'N/A',

        'Owner Name': entry['owner_name']?.toString() ?? 'N/A',

        'Monthly Rent': entry['price']?.toString() ?? 'N/A',

        'Security': entry['security']?.toString() ?? 'N/A',

      },

    ];

  }



  Future<void> _generateReceipt(BuildContext context) async {

    if (!context.mounted) return;

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (_) => const AlertDialog(

        content: SizedBox(

          width: 240,

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              CircularProgressIndicator(),

              SizedBox(height: 16),

              Text('Generating receipt...'),

            ],

          ),

        ),

      ),

    );

    try {

      await ProfessionalPdfGenerator.generateReceipt(

        context: context,

        db: db,

        module: 'Rental',

        title: 'Rental Receipt',

        entityId: entry['id']?.toString(),

        keyValues: _keyValues(),

        gridRows: _gridRows(),

      );

    } finally {

      if (context.mounted) Navigator.of(context).pop();

    }

  }



  Widget _infoRow(BuildContext context, String label, String value) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 150,

            child: Text(label, style: AppFonts.poppins(fontWeight: FontWeight.w600)),

          ),

          Expanded(

            child: GestureDetector(

              onTap: label == 'Contact' && value.trim().isNotEmpty

                  ? () => showPhoneActionSheet(context, value)

                  : null,

              child: Text(

                value,

                style: AppFonts.poppins(

                  color: label == 'Contact' ? Colors.blue.shade700 : null,

                  decoration: label == 'Contact' ? TextDecoration.underline : TextDecoration.none,

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final kv = _keyValues();

    return Scaffold(

      appBar: AppBar(

        title: const Text('Rental Details'),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        flexibleSpace: Container(

          decoration: const BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [

                Color(0xFFFF6B35), // Orange/Coral

                Color(0xFF4A90E2), // Blue accent for contrast

              ],

            ),

          ),

        ),

        actions: [

          TextButton.icon(

            style: TextButton.styleFrom(foregroundColor: Colors.white),

            onPressed: () => _generateReceipt(context),

            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),

            label: const Text(

              'Generate Professional Receipt',

              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),

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

          padding: const EdgeInsets.all(16),

          child: Card(

            elevation: 2,

            child: Padding(

              padding: const EdgeInsets.all(16),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(entry['name']?.toString() ?? 'Rental Item',

                      style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),

                  const SizedBox(height: 12),

                  Divider(color: Colors.grey.shade300),

                  const SizedBox(height: 12),

                  ...kv.map((e) => _infoRow(context, e.key, e.value)),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}



class UsersPage extends StatefulWidget {

  final AppDatabase db;

  const UsersPage({super.key, required this.db});

  @override

  State<UsersPage> createState() => _UsersPageState();

}



class _UsersPageState extends State<UsersPage> {

  List<Map<String, dynamic>> _rows = [];

  String _q = '';

  bool _loading = false;

  bool _firestoreReady = false;

  Map<String, dynamic>? _editingUser;

  List<Map<String, String>> _companies = [];

  Map<String, dynamic>? _currentUser;

  bool _backfillingUserIds = false;

  bool _backfillUserIdsDone = false;

  StreamSubscription<QuerySnapshot>? _firestoreSub;

  FirestoreSyncState _syncState = FirestoreSyncState();



  @override

  void initState() {

    super.initState();

    Future.microtask(() async {

      await _loadCurrentUser();

      await _startFirestoreListener();

      await _loadCompanies();

      await _load();

    });

  }



  @override

  void dispose() {

    // REMOVED: Firestore subscription cancellation for SQLite-only operation

    // _firestoreSub?.cancel();

    super.dispose();

  }



  /// Start Firestore listener with pagination for real-time sync

  Future<void> _startFirestoreListener() async {

    if (!FirestoreSyncService().isAvailable) {

      Future.microtask(() {

        if (!mounted) return;

        setState(() => _firestoreReady = true);

      });

      return;

    }



    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {

      Future.microtask(() {

        if (!mounted) return;

        setState(() => _firestoreReady = true);

      });

      return;

    }



    try {

      // Use secure query builder for role-based isolation

      Query query = buildSecureFirestoreQuery(

        collection: 'users',

        currentUser: _currentUser,

        orderBy: 'updatedAt',

        descending: true,

        limit: 50, // Paginated

      );



      _firestoreSub = query.snapshots().listen((snapshot) async {

        Future.microtask(() async {

          final changes = List<DocumentChange>.from(snapshot.docChanges);

          

          if (changes.isNotEmpty) {

            try {

              await widget.db.batch((batch) {

                for (final change in changes) {

                  final doc = change.doc;

                  final data = doc.data() as Map<String, dynamic>;

                  final id = (data['id'] ?? doc.id).toString();

                  

                  if (change.type == DocumentChangeType.removed) {

                    batch.customStatement('DELETE FROM users WHERE id = ?', [id]);

                    continue;

                  }



                // Sync user data to SQLite (exclude sensitive password fields)

                final username = (data['username'] ?? '').toString();

                final userId = (data['user_id'] ?? data['userId'] ?? '').toString();

                final name = (data['name'] ?? '').toString();

                final email = (data['email'] ?? '').toString();

                final contactNo = (data['contact_no'] ?? data['contactNo'] ?? '').toString();

                final permissions = data['permissions'];

                final status = (data['status'] ?? 'active').toString();

                final cid = (data['company_id'] ?? data['companyId'])?.toString();

                final createdAt = (data['created_at'] ?? data['createdAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();

                final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? DateTime.now().toUtc().toIso8601String()).toString();



                // Note: Password fields are NOT synced from Firestore for security

                batch.customStatement(

                  'INSERT OR REPLACE INTO users (id, username, user_id, name, email, contact_no, permissions, company_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',

                  [id, username, userId, name, email, contactNo, permissions != null ? jsonEncode(permissions) : null, cid, status, createdAt, updatedAt],

                );

              }

            });

            

            // Update UI on main thread

            Future.microtask(() async {

              if (!mounted) return;

              _syncState.startLoading();

              _syncState.finishLoading(synced: true);

              await _load(); // Reload to show updated data

              if (!mounted) return;

              setState(() => _firestoreReady = true);

            });

          } catch (e) {

            debugPrint('Error syncing Firestore changes to SQLite (users): $e');

            Future.microtask(() {

              if (!mounted) return;

              _syncState.finishLoading(synced: false, errorMessage: e.toString());

              setState(() => _firestoreReady = true);

            });

          }

        } else {

          Future.microtask(() {

            if (!mounted) return;

            setState(() => _firestoreReady = true);

          });

        }

        });

      }, onError: (error) {

        debugPrint('Firestore listener error (users): $error');

        // Handle missing index errors gracefully

        final errorStr = error.toString().toLowerCase();

        if (errorStr.contains('index') || errorStr.contains('missing')) {

          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');

        }

        Future.microtask(() {

          if (!mounted) return;

          _syncState.finishLoading(synced: false, errorMessage: error.toString());

          setState(() => _firestoreReady = true);

        });

      });

    } catch (e) {

      debugPrint('Error starting Firestore listener (users): $e');

      // Handle missing index errors gracefully

      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('index') || errorStr.contains('missing')) {

        debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');

      }

      Future.microtask(() {

        if (!mounted) return;

        setState(() => _firestoreReady = true);

      });

    }

  }



  Future<void> _loadCurrentUser() async {

    try {

      final storage = AppStorage();

      final s = await storage.readSettings();

      final authToken = s['authToken'] as String?;

      if (authToken != null) {

        final authService = AuthService();

        final user = await authService.getCurrentUser(authToken);

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



  Future<void> _loadCompanies() async {

    if (!mounted) return;

    try {

      if (_currentUser == null) {

        if (!mounted) return;

        setState(() => _companies = []);

        return;

      }



      final result = RoleUtils.isSuperAdmin(_currentUser)

          ? await widget.db.customSelect(

              'SELECT id, name FROM companies WHERE status = ? ORDER BY name',

              variables: [d.Variable.withString('active')],

              readsFrom: {widget.db.companies},

            ).get()

          : await widget.db.customSelect(

              'SELECT id, name FROM companies WHERE id = ? AND status = ? LIMIT 1',

              variables: [

                d.Variable.withString(RoleUtils.getUserCompanyId(_currentUser) ?? ''),

                d.Variable.withString('active'),

              ],

              readsFrom: {widget.db.companies},

            ).get();

      if (!mounted) return;

      setState(() {

        _companies = result.map((r) => {

          'id': r.data['id'] as String,

          'name': r.data['name']?.toString() ?? '',

        }).toList();

      });

    } catch (e) {

      debugPrint('Error loading companies: $e');

    }

  }



  Future<List<Map<String, String>>> _loadCompaniesForForm() async {

    try {

      if (_currentUser == null) return [];



      final result = RoleUtils.isSuperAdmin(_currentUser)

          ? await widget.db.customSelect(

              'SELECT id, name FROM companies WHERE status = ? ORDER BY name',

              variables: [d.Variable.withString('active')],

              readsFrom: {widget.db.companies},

            ).get()

          : await widget.db.customSelect(

              'SELECT id, name FROM companies WHERE id = ? AND status = ? LIMIT 1',

              variables: [

                d.Variable.withString(RoleUtils.getUserCompanyId(_currentUser) ?? ''),

                d.Variable.withString('active'),

              ],

              readsFrom: {widget.db.companies},

            ).get();

      return result.map((r) => {

        'id': r.data['id'] as String,

        'name': r.data['name']?.toString() ?? '',

      }).toList();

    } catch (e) {

      debugPrint('Error loading companies for form: $e');

      return [];

    }

  }



  // Test method to query user by email

  Future<void> _testQueryUserByEmail(String email) async {

    try {

      debugPrint('\nðŸ” Querying user with email: $email');

      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');

      

      final result = await widget.db.customSelect(

        'SELECT * FROM users WHERE email = ?',

        variables: [d.Variable.withString(email)],

        readsFrom: {widget.db.users},

      ).get();

      

      if (result.isEmpty) {

        debugPrint('âŒ No user found with email: $email');

        debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(content: Text('No user found with email: $email'), backgroundColor: Colors.orange),

          );

        }

        return;

      }

      

      debugPrint('âœ… Found ${result.length} user(s) with email: $email\n');

      

      for (var row in result) {

        debugPrint('ðŸ“‹ User Details:');

        row.data.forEach((key, value) {

          // Don't print full password hash for security, just show it exists

          if (key == 'password_hash' && value != null) {

            final hash = value.toString();

            debugPrint('   $key: ${hash.substring(0, hash.length > 30 ? 30 : hash.length)}... (hidden)');

          } else {

            debugPrint('   $key: $value');

          }

        });

        debugPrint('');

      }

      

      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');

      

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text('Found ${result.length} user(s). Check console for details.'),

            backgroundColor: Colors.green,

            duration: const Duration(seconds: 3),

          ),

        );

      }

    } catch (e) {

      debugPrint('âŒ Error querying user: $e');

      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),

        );

      }

    }

  }



  // Method to check password hash (password cannot be retrieved, only reset)

  Future<void> _checkUserPasswordInfo(String email) async {

    try {

      debugPrint('\nðŸ” Checking Password Information for: $email');

      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');

      

      final result = await widget.db.customSelect(

        'SELECT id, username, email, password_hash, salt, iterations, is_first_login, company_id FROM users WHERE email = ?',

        variables: [d.Variable.withString(email)],

        readsFrom: {widget.db.users},

      ).get();

      

      if (result.isEmpty) {

        debugPrint('âŒ No user found with email: $email\n');

        return;

      }

      

      final userData = result.first.data;

      final passwordHash = userData['password_hash'] as String?;

      final salt = userData['salt'] as String?;

      final iterations = userData['iterations'] as int?;

      final isFirstLogin = userData['is_first_login'] as int? ?? 0;

      final companyId = userData['company_id'] as String?;

      

      debugPrint('âš ï¸  SECURITY NOTE:');

      debugPrint('   Passwords are stored as HASHED values for security.');

      debugPrint('   The original password CANNOT be retrieved from the database.\n');

      

      debugPrint('ðŸ“‹ Password Hash Information:');

      if (passwordHash != null) {

        debugPrint('   Password Hash: ${passwordHash.substring(0, passwordHash.length > 50 ? 50 : passwordHash.length)}...');

        debugPrint('   Salt: ${salt ?? "N/A"}');

        debugPrint('   Iterations: ${iterations ?? "N/A"}');

        debugPrint('   Hash Format: ${passwordHash.split(":").length} parts');

      } else {

        debugPrint('   âš ï¸  No password hash found!');

      }

      

      debugPrint('\nðŸ‘¤ User Status:');

      debugPrint('   Username: ${userData['username']}');

      debugPrint('   Email: ${userData['email']}');

      debugPrint('   is_first_login: $isFirstLogin ${isFirstLogin == 1 ? "(Must change password)" : "(Password already changed)"}');

      debugPrint('   Company ID: ${companyId ?? "None (Regular User)"}');

      

      if (isFirstLogin == 1 && companyId != null) {

        debugPrint('\nðŸ’¡ IMPORTANT:');

        debugPrint('   This is a Company Admin with is_first_login = true.');

        debugPrint('   The temporary password was shown when the user was created.');

        debugPrint('   If you don\'t have it, you need to RESET the password.\n');

      }

      

      debugPrint('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n');

      

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text('Password info retrieved. Check console. Original password cannot be retrieved.'),

            backgroundColor: Colors.blue,

            duration: const Duration(seconds: 4),

          ),

        );

      }

    } catch (e) {

      debugPrint('âŒ Error: $e\n');

    }

  }



  Future<void> _load() async {

    if (!mounted) return;

    setState(() => _loading = true);

    try {

      if (_currentUser == null) {

        if (!mounted) return;

        setState(() {

          _rows = [];

          _loading = false;

        });

        return;

      }



      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

      final myCompanyId = RoleUtils.getUserCompanyId(_currentUser);

      final myUserId = _currentUser?['id']?.toString();





      // Load users with all fields including new ones

      final result = await widget.db.customSelect(

        isSuperAdmin

            ? 'SELECT id, username, user_id, name, email, contact_no, permissions, company_id, status, created_at, updated_at FROM users ORDER BY updated_at DESC'

            : 'SELECT id, username, user_id, name, email, contact_no, permissions, company_id, status, created_at, updated_at FROM users WHERE company_id = ? AND id != ? AND permissions LIKE ? ORDER BY updated_at DESC',

        variables: isSuperAdmin

            ? []

            : [

                d.Variable.withString(myCompanyId!),

                d.Variable.withString(myUserId ?? ''),

                d.Variable.withString('%"role":"agent"%'),

              ],

        readsFrom: {widget.db.users},

      ).get();



      final rows = result.map((r) => Map<String, dynamic>.from(r.data)).toList();

      await _backfillMissingUserIds(rows);

      if (!mounted) return;

      setState(() {

        _rows = rows;

        _loading = false;

      });

    } catch (e) {

      // If new columns don't exist yet, fallback to basic query

      try {

        if (_currentUser == null) {

          if (!mounted) return;

          setState(() {

            _rows = [];

            _loading = false;

          });

          return;

        }



        final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

        final myCompanyId = RoleUtils.getUserCompanyId(_currentUser);



        final result = await widget.db.customSelect(

          isSuperAdmin

              ? 'SELECT id, username, company_id, updated_at FROM users ORDER BY updated_at DESC'

              : 'SELECT id, username, company_id, updated_at FROM users WHERE company_id = ? ORDER BY updated_at DESC',

          variables: isSuperAdmin ? [] : [d.Variable.withString(myCompanyId!)],

          readsFrom: {widget.db.users},

        ).get();

        if (!mounted) return;

        setState(() {

          _rows = result.map((r) => r.data).toList();

          _loading = false;

        });

      } catch (e2) {

        if (!mounted) return;

        setState(() => _loading = false);

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(content: Text('Error loading users: $e2')),

          );

        }

      }

    }

  }



  Future<void> _backfillMissingUserIds(List<Map<String, dynamic>> viewRows) async {

    if (_backfillUserIdsDone) return;

    if (_backfillingUserIds) return;

    _backfillingUserIds = true;

    try {

      final missing = viewRows.where((r) {

        final uid = r['user_id']?.toString().trim() ?? '';

        return uid.isEmpty;

      }).toList();

      if (missing.isEmpty) {

        _backfillUserIdsDone = true;

        return;

      }



      final nowIso = DateTime.now().toUtc().toIso8601String();

      final year = DateTime.now().year;



      int extractSeq(String raw) {

        final v = raw.trim().toUpperCase();

        final mUsr = RegExp(r'^USR-(\\d{4})-(\\d{1,6})$').firstMatch(v);

        if (mUsr != null) {

          final y = int.tryParse(mUsr.group(1) ?? '');

          if (y != year) return 0;

          final n = int.tryParse(mUsr.group(2) ?? '');

          return n ?? 0;

        }

        return 0;

      }



      final all = await widget.db.customSelect(

        'SELECT company_id, user_id FROM users',

        readsFrom: {widget.db.users},

      ).get();



      final maxSeqByCompany = <String, int>{};

      final usedByCompany = <String, Set<String>>{};



      for (final r in all) {

        final m = r.data;

        final companyId = (m['company_id'] ?? '').toString();

        final rawUserId = (m['user_id'] ?? '').toString();

        final used = usedByCompany.putIfAbsent(companyId, () => <String>{});

        if (rawUserId.trim().isNotEmpty) {

          used.add(rawUserId.trim().toUpperCase());

        }

        final seq = extractSeq(rawUserId);

        final currentMax = maxSeqByCompany[companyId] ?? 0;

        if (seq > currentMax) maxSeqByCompany[companyId] = seq;

      }



      for (final r in missing) {

        final id = (r['id'] ?? '').toString();

        if (id.trim().isEmpty) continue;

        final companyId = (r['company_id'] ?? '').toString();



        String next;

        if (companyId.trim().isEmpty) {

          next = 'USR-$year-000';

        } else {

          final used = usedByCompany.putIfAbsent(companyId, () => <String>{});

          var seq = (maxSeqByCompany[companyId] ?? 0) + 1;

          while (used.contains('USR-$year-${seq.toString().padLeft(3, '0')}')) {

            seq++;

          }

          next = 'USR-$year-${seq.toString().padLeft(3, '0')}';

          maxSeqByCompany[companyId] = seq;

          used.add(next.toUpperCase());

        }



        await widget.db.customStatement(

          'UPDATE users SET user_id = ?, updated_at = ? WHERE id = ?',

          [next, nowIso, id],

        );



        if (Firebase.apps.isNotEmpty) {

          try {

            await FirebaseFirestore.instance.collection('users').doc(id).set({

              'user_id': next,

              'userId': next,

              'updated_at': nowIso,

            }, SetOptions(merge: true));

          } catch (e) {

            if (kDebugMode) {

              debugPrint('Backfill user_id Firestore sync failed for users/$id: $e');

            }

          }

        }



        r['user_id'] = next;

      }



      _backfillUserIdsDone = true;

    } finally {

      _backfillingUserIds = false;

    }

  }



  void _showAddFormDialog({Map<String, dynamic>? existing}) {

    // Bypass permission checks for Super Admin

    setState(() {

      _editingUser = existing;

    });

    

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => Focus(

        autofocus: true,

        onKeyEvent: (node, event) {

          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {

            setState(() {

              _editingUser = null;

            });

            Navigator.of(context).pop();

            return KeyEventResult.handled;

          }

          return KeyEventResult.ignored;

        },

        child: Dialog(

          backgroundColor: Colors.transparent,

          insetPadding: EdgeInsets.symmetric(

            horizontal: MediaQuery.of(context).size.width < 600 ? 8 : 16,

            vertical: MediaQuery.of(context).size.height < 800 ? 8 : 16,

          ),

          child: Container(

            constraints: BoxConstraints(

              maxWidth: 600,

              maxHeight: MediaQuery.of(context).size.height * 0.9,

            ),

            decoration: BoxDecoration(

              color: Theme.of(context).cardColor,

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

                      Padding(

                        padding: const EdgeInsets.only(top: 56),

                        child: SingleChildScrollView(

                          padding: const EdgeInsets.all(20),

                          child: _buildAddUserForm(setDialogState, dialogContext),

                        ),

                      ),

                      Positioned(

                        top: 12,

                        left: 12,

                        child: Material(

                          color: Colors.transparent,

                          child: InkWell(

                            onTap: () {

                              setState(() {

                                _editingUser = null;

                              });

                              Navigator.of(context).pop();

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



  void _resetUserForm() {

    setState(() {

      _editingUser = null;

    });

  }



  Widget _buildCredentialRow(String label, String value) {

    return Row(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        SizedBox(

          width: 120,

          child: Text(

            label,

            style: AppFonts.poppins(

              fontSize: 13,

              fontWeight: FontWeight.w600,

              color: Colors.grey.shade700,

            ),

          ),

        ),

        Expanded(

          child: SelectableText(

            value,

            style: AppFonts.poppins(

              fontSize: 13,

              fontWeight: FontWeight.w500,

              color: Colors.grey.shade900,

            ),

          ),

        ),

      ],

    );

  }



  Widget _buildAddUserForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {

    final existing = _editingUser;

    final nameCtl = TextEditingController(text: existing?['name']?.toString() ?? '');

    final userIdCtl = TextEditingController(text: (existing?['user_id'] ?? existing?['userId'])?.toString() ?? '');

    final emailCtl = TextEditingController(text: existing?['email']?.toString() ?? existing?['username']?.toString() ?? '');

    final usernameCtl = TextEditingController(text: existing?['username']?.toString() ?? '');

    final contactCtl = TextEditingController(text: existing?['contact_no']?.toString() ?? '');

    final passwordCtl = TextEditingController();

    String? selectedPermission;

    String? selectedCompanyId = existing?['company_id']?.toString();

    String selectedRole = 'agent';

    const moduleDefs = [

      {'key': 'inventory', 'label': 'Inventory'},

      {'key': 'agent_working', 'label': 'Agent Working'},

      {'key': 'rental_items', 'label': 'Rental Items'},

      {'key': 'todo', 'label': 'To-Do'},

      {'key': 'trading', 'label': 'Trading'},

      {'key': 'expenditure', 'label': 'Expenditure'},

    ];

    final Map<String, String> modulePermissions = {

      'inventory': 'view_add',

      'agent_working': 'view_add',

      'rental_items': 'view_add',

      'todo': 'view_add',

      'trading': 'view_add',

      'expenditure': 'view_add',

    };

    Map<String, String> _sanitizeModulePermissions(Map<String, String> source) {

      const allowedValues = {'no_access', 'view_only', 'view_add', 'view_add_edit', 'full_access'};

      final allowedKeys = moduleDefs.map((m) => m['key']!).toSet();

      final cleaned = <String, String>{};

      for (final key in allowedKeys) {

        final raw = (source[key] ?? '').toString().trim();

        cleaned[key] = allowedValues.contains(raw) ? raw : 'no_access';

      }

      return cleaned;

    }



    Map<String, dynamic> _buildPermissionsPayload() {

      selectedPermission ??= 'view_add';



      Map<String, String> modulePermissionsMap = <String, String>{};

      if (selectedRole == 'agent') {

        modulePermissionsMap = _sanitizeModulePermissions(modulePermissions);

        final values = modulePermissionsMap.values;

        if (values.isNotEmpty && values.every((v) => v.trim() == 'no_access')) {

          selectedPermission = 'no_access';

        } else if (values.any((v) => v.trim() == 'view_add' || v.trim() == 'view_add_edit')) {

          selectedPermission = 'view_add';

        } else {

          selectedPermission = 'view_only';

        }

      }



      final permissionsMap = {

        'permission': selectedPermission,

        'role': selectedRole,

        'canView': selectedPermission != 'no_access',

        'canAdd': selectedPermission == 'view_add' || selectedPermission == 'full_access',

        'canEdit': selectedPermission == 'full_access',

        'canDelete': selectedPermission == 'full_access',

        'permissionsMap': modulePermissionsMap,

      };



      final encoded = jsonEncode(permissionsMap);

      if (encoded.length > 900000) {

        debugPrint('Permissions payload too large (${encoded.length}). Sending minimal permissions only.');

        return {

          'permission': selectedPermission,

          'role': selectedRole,

          'canView': selectedPermission != 'no_access',

          'canAdd': selectedPermission == 'view_add' || selectedRole != 'agent',

          'canEdit': selectedPermission == 'full_access' || selectedRole != 'agent',

          'canDelete': selectedPermission == 'full_access',

          'permissionsMap': <String, String>{},

        };

      }



      return permissionsMap;

    }

    final formKey = GlobalKey<FormState>();



    String? _userIdError;



    bool _checkingUserLimit = false;

    bool _userLimitReached = false;

    int? _currentActiveUsers;

    int? _maxUserLimit;

    String? _checkedCompanyId;

    bool _limitInitDone = false;

    bool _userIdInitDone = false;



    Future<void> _autoGenerateUserId({required String companyId, required StateSetter setLocal}) async {

      if (existing != null) return;

      if (_userIdInitDone) return;

      if (userIdCtl.text.trim().isNotEmpty) {

        _userIdInitDone = true;

        return;

      }

      _userIdInitDone = true;

      try {

        final year = DateTime.now().year;

        final res = await widget.db.customSelect(

          'SELECT user_id FROM users WHERE company_id = ? AND user_id IS NOT NULL',

          variables: [d.Variable.withString(companyId)],

          readsFrom: {widget.db.users},

        ).get();



        int extractSeq(String raw) {

          final v = raw.trim().toUpperCase();

          final mUsr = RegExp(r'^USR-(\d{4})-(\d{1,6})$').firstMatch(v);

          if (mUsr != null) {

            final y = int.tryParse(mUsr.group(1) ?? '');

            if (y != year) return 0;

            final n = int.tryParse(mUsr.group(2) ?? '');

            return n ?? 0;

          }

          return 0;

        }



        final used = <String>{};

        var maxNum = 0;

        for (final row in res) {

          final raw = row.data['user_id']?.toString() ?? '';

          final upper = raw.trim().toUpperCase();

          if (upper.isNotEmpty) used.add(upper);

          final n = extractSeq(raw);

          if (n > maxNum) maxNum = n;

        }



        var next = maxNum + 1;

        var suggested = 'USR-$year-${next.toString().padLeft(3, '0')}';

        while (used.contains(suggested.toUpperCase())) {

          next++;

          suggested = 'USR-$year-${next.toString().padLeft(3, '0')}';

        }



        userIdCtl.text = suggested;

        setLocal(() {});

      } catch (_) {

        // ignore auto-suggest failures

      }

    }



    Future<void> _ensureUniqueUserId({

      required String companyId,

      required String currentUserId,

      required StateSetter setLocal,

    }) async {

      if (existing != null) return;

      final year = DateTime.now().year;



      Future<bool> isUnique(String candidate) async {

        final res = await widget.db.customSelect(

          'SELECT COUNT(*) as c FROM users WHERE company_id = ? AND user_id = ? AND id != ?',

          variables: [

            d.Variable.withString(companyId),

            d.Variable.withString(candidate),

            d.Variable.withString(currentUserId),

          ],

          readsFrom: {widget.db.users},

        ).getSingle();

        final cRaw = res.data['c'];

        final c = cRaw is int ? cRaw : int.tryParse(cRaw?.toString() ?? '0') ?? 0;

        return c == 0;

      }



      int extractSeqForYear(String raw) {

        final v = raw.trim().toUpperCase();

        final m = RegExp(r'^USR-(\d{4})-(\d{1,6})$').firstMatch(v);

        if (m == null) return 0;

        final y = int.tryParse(m.group(1) ?? '');

        if (y != year) return 0;

        final n = int.tryParse(m.group(2) ?? '');

        return n ?? 0;

      }



      Future<String> nextCandidate({int? minSeq}) async {

        final res = await widget.db.customSelect(

          'SELECT user_id FROM users WHERE company_id = ? AND user_id IS NOT NULL',

          variables: [d.Variable.withString(companyId)],

          readsFrom: {widget.db.users},

        ).get();



        final used = <String>{};

        var maxNum = 0;

        for (final row in res) {

          final raw = row.data['user_id']?.toString() ?? '';

          final upper = raw.trim().toUpperCase();

          if (upper.isNotEmpty) used.add(upper);

          final n = extractSeqForYear(raw);

          if (n > maxNum) maxNum = n;

        }



        var seq = (minSeq != null && minSeq > maxNum) ? minSeq : (maxNum + 1);

        var candidate = 'USR-$year-${seq.toString().padLeft(3, '0')}';

        while (used.contains(candidate.toUpperCase())) {

          seq++;

          candidate = 'USR-$year-${seq.toString().padLeft(3, '0')}';

        }

        return candidate;

      }



      int? currentSeq;

      final currentRaw = userIdCtl.text.trim();

      if (currentRaw.isNotEmpty) {

        final n = extractSeqForYear(currentRaw);

        if (n > 0) currentSeq = n;

      }



      for (var attempt = 0; attempt < 25; attempt++) {

        if (userIdCtl.text.trim().isEmpty) {

          userIdCtl.text = await nextCandidate();

          setLocal(() {

            _userIdError = null;

          });

        }



        final cand = userIdCtl.text.trim();

        final unique = await isUnique(cand);

        if (unique) return;



        currentSeq = (currentSeq ?? extractSeqForYear(cand));

        userIdCtl.text = await nextCandidate(minSeq: (currentSeq ?? 0) + 1);

        setLocal(() {

          _userIdError = null;

        });

      }



      setLocal(() => _userIdError = 'Failed to generate unique User ID. Please try again.');

      throw Exception('Failed to generate unique User ID');

    }



    Future<bool> _isUserIdUnique({

      required String companyId,

      required String userId,

      required String currentUserId,

    }) async {

      final res = await widget.db.customSelect(

        'SELECT COUNT(*) as c FROM users WHERE company_id = ? AND user_id = ? AND id != ?',

        variables: [

          d.Variable.withString(companyId),

          d.Variable.withString(userId),

          d.Variable.withString(currentUserId),

        ],

        readsFrom: {widget.db.users},

      ).getSingle();

      final cRaw = res.data['c'];

      final c = cRaw is int ? cRaw : int.tryParse(cRaw?.toString() ?? '0') ?? 0;

      return c == 0;

    }



    Future<void> _refreshUserLimit({required String companyId, required StateSetter setLocal}) async {

      if (_checkingUserLimit && _checkedCompanyId == companyId) return;

      final wasReached = _userLimitReached;

      _checkingUserLimit = true;

      _checkedCompanyId = companyId;

    final companyIdStr = companyId.toString();

      setLocal(() {});

      try {

        int? limit;

        int? cnt;

        String tier = 'Starter';



        if (Firebase.apps.isNotEmpty) {

          try {

          // Enhanced with FirebaseThreadingHandler for Windows compatibility
          final doc = await FirebaseThreadingHandler.executeWithThreadSafety(
            () => FirebaseFirestore.instance.collection('companies').doc(companyIdStr).get(),
            operationName: 'Home getCompanyDetails',
          );

            if (!doc.exists) {

            debugPrint('UserLimit: Firestore companies/$companyIdStr not found. Looking for ID: $companyIdStr');

            }

            final data = doc.data();

            final raw = data?['max_user_limit'] ?? data?['maxUserLimit'];

            limit = raw is int ? raw : int.tryParse(raw?.toString() ?? '');

            tier = normalizeSubscriptionTier(data?['subscription_tier'] ?? data?['subscriptionTier']);

          } catch (e) {

            if (kDebugMode) {

            debugPrint('UserLimit: Firestore company limit read failed for companyId=$companyIdStr: $e');

            }

          }



          try {

            QuerySnapshot<Map<String, dynamic>> snap;

          // Enhanced with FirebaseThreadingHandler for Windows compatibility
          snap = await FirebaseThreadingHandler.executeWithThreadSafety(
            () => FirebaseFirestore.instance.collection('users').where('company_id', isEqualTo: companyIdStr).get(),
            operationName: 'Home syncUsers-company_id',
          );

            if (snap.docs.isEmpty) {

            // Enhanced with FirebaseThreadingHandler for Windows compatibility
            snap = await FirebaseThreadingHandler.executeWithThreadSafety(
              () => FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: companyIdStr).get(),
              operationName: 'Home syncUsers-companyId',
            );

            }

            final docs = snap.docs.map((d) => d.data()).toList();

            cnt = docs.where((u) {

              final status = (u['status'] ?? 'active').toString().trim().toLowerCase();

              final isDeleted = (u['isDeleted'] == true) || (u['is_deleted'] == true);

              final deletedAt = u['deleted_at'];

              if (isDeleted) return false;

              if (deletedAt != null && deletedAt.toString().trim().isNotEmpty) return false;

              if (status == 'inactive' || status == 'deleted') return false;

              if (status.isNotEmpty && status != 'active') return false;

              final role = (u['role'] ?? (u['permissions'] is Map ? (u['permissions'] as Map)['role'] : null))?.toString();

              return role != 'super_admin';

            }).length;

          } catch (e) {

            if (kDebugMode) {

              debugPrint('UserLimit: Firestore user count failed for companyId=$companyId: $e');

            }

          }

        }



        if (limit == null || cnt == null) {

          final limitRes = await widget.db.customSelect(

            'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',

            variables: [d.Variable.withString(companyId)],

            readsFrom: {widget.db.companies},

          ).get();



          final row = limitRes.isNotEmpty ? limitRes.first.data : null;

          final limitRaw = row?['max_user_limit'];

          final tierRaw = row?['subscription_tier'];

          tier = normalizeSubscriptionTier(tierRaw ?? tier);

          limit ??= (limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? ''));

          limit ??= subscriptionLimitForTier(tier);



          final countRes = await widget.db.customSelect(

            "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL)",

            variables: [d.Variable.withString(companyId)],

            readsFrom: {widget.db.users},

          ).get();



          final cntRaw = countRes.isNotEmpty ? countRes.first.data['cnt'] : 0;

          cnt ??= cntRaw is int ? cntRaw : int.tryParse(cntRaw.toString()) ?? 0;

        }



        if (kDebugMode) {

          debugPrint('UserLimit: companyId=$companyId subscription_tier=$tier max_user_limit=$limit current_active_agents=$cnt');

        }



        _maxUserLimit = limit;

        _currentActiveUsers = cnt;

        _userLimitReached = (cnt ?? 0) >= (limit ?? 5);

      } catch (_) {

        _maxUserLimit = null;

        _currentActiveUsers = null;

        _userLimitReached = false;

      } finally {

        _checkingUserLimit = false;

        setLocal(() {});

      }



      if (!wasReached && _userLimitReached && mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Limit reached: ${_currentActiveUsers ?? '?'} / ${_maxUserLimit ?? '?'} active users in use. Please contact Super Admin to upgrade your plan.')),

        );

      }

    }

    

    // Parse existing permissions if editing

    if (existing != null && existing['permissions'] != null) {

      try {

        final rawPerms = existing['permissions'];

        if (rawPerms is String && rawPerms.length > 900000) {

          debugPrint('Skipping oversized permissions payload (${rawPerms.length}) for existing user.');

        } else {

          final perms = rawPerms is String ? jsonDecode(rawPerms) : rawPerms;

        selectedPermission = perms['permission']?.toString();

        selectedRole = perms['role']?.toString() ?? 'agent';

        final rawMap = perms['permissionsMap'];

        if (rawMap is Map) {

          rawMap.forEach((k, v) {

            final key = k.toString();

            final val = v?.toString() ?? '';

            if (modulePermissions.containsKey(key) && val.isNotEmpty) {

              modulePermissions[key] = val;

            }

          });

        } else {

          final legacy = PermissionHelper.getPermissionLevel(existing);

          final mapped = PermissionHelper.normalizeLegacyToModuleLevel(legacy);

          for (final k in modulePermissions.keys) {

            modulePermissions[k] = mapped;

          }

        }

        }

      } catch (e) {

        // Ignore parse errors

      }

    }



    // Force super admin context - remove null checks

    final isSuperAdmin = true; // Always true for Super Admin

    final isCompanyAdmin = false; // Not needed for Super Admin

    final myCompanyId = selectedCompanyId ??

        (_companies.isNotEmpty ? _companies.first['id'] : RoleUtils.getUserCompanyId(_currentUser));

    final myCompanyIdStr = (myCompanyId ?? '').toString();

    selectedCompanyId = myCompanyIdStr.isEmpty ? null : myCompanyIdStr;

    if (selectedRole.isEmpty || selectedRole == 'agent') {

      selectedRole = existing?['role']?.toString() ?? 'agent';

    }

    if (selectedPermission == null || selectedPermission!.trim().isEmpty) {

      selectedPermission = 'view_add';

    }

    

    final permissionOptions = [

      {'value': 'view_only', 'label': 'View Only - Can only view data'},

      {'value': 'view_add', 'label': 'View & Add - Can view and add data'},

      if (isSuperAdmin) {'value': 'full_access', 'label': 'Full Access - Can view, add, edit, and delete data'},

      {'value': 'no_access', 'label': 'No Access - Cannot view or add data'},

    ];



    const modulePermissionOptions = [

      {'value': 'no_access', 'label': 'No Access'},

      {'value': 'view_only', 'label': 'View Only'},

      {'value': 'view_add', 'label': 'View & Add'},

      {'value': 'view_add_edit', 'label': 'View, Add & Edit'},

    ];



    final roleOptions = const [

      {'value': 'agent', 'label': 'Agent'},

      {'value': 'company_admin', 'label': 'Company Admin'},

      {'value': 'super_admin', 'label': 'Super Admin'},

      {'value': 'business', 'label': 'Business'},

    ];



    return StatefulBuilder(

      builder: (context, setLocal) {

        if (!_limitInitDone && existing == null) {

          _limitInitDone = true;

          final cid = selectedCompanyId ?? (_companies.isNotEmpty ? _companies.first['id'] : null);

          if (cid != null && cid.trim().isNotEmpty) {

            Future.microtask(() => _refreshUserLimit(companyId: cid, setLocal: setLocal));

          }

        }

        final cidForEmp = selectedCompanyId ?? (_companies.isNotEmpty ? _companies.first['id'] : null);

        if (existing == null && cidForEmp != null && cidForEmp.trim().isNotEmpty) {

          Future.microtask(() => _autoGenerateUserId(companyId: cidForEmp, setLocal: setLocal));

        }

        return Form(

          key: formKey,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [

              Text(

                existing == null ? 'Add New User' : 'Edit User',

                style: AppFonts.poppins(

                  fontSize: 24,

                  fontWeight: FontWeight.w700,

                  color: Colors.grey.shade900,

                ),

              ),

              const SizedBox(height: 28),

              TextFormField(

                controller: userIdCtl,

                decoration: _fieldDecoration('User ID', isRequired: true).copyWith(errorText: _userIdError),

                readOnly: true,

                validator: (value) {

                  final v = value?.trim() ?? '';

                  if (v.isEmpty) return 'User ID is required';

                  if (v.length > 20) return 'Maximum 20 characters allowed';

                  return null;

                },

              ),

              const SizedBox(height: 16),

              TextFormField(

                controller: nameCtl,

                decoration: _fieldDecoration('Name', isRequired: true),

                validator: (value) {

                  if (value == null || value.trim().isEmpty) {

                    return 'Name is required';

                  }

                  if (value.length > 100) {

                    return 'Maximum 100 characters allowed';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 16),

              TextFormField(

                controller: emailCtl,

                decoration: _fieldDecoration('E-mail', isRequired: true),

                keyboardType: TextInputType.emailAddress,

                validator: (value) {

                  if (value == null || value.trim().isEmpty) {

                    return 'E-mail is required';

                  }

                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

                  if (!emailRegex.hasMatch(value)) {

                    return 'Please enter a valid email address';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 16),

              if (existing == null)

                TextFormField(

                  controller: usernameCtl,

                  decoration: _fieldDecoration('Username', isRequired: true, icon: Icons.person),

                  validator: (value) {

                    if (value == null || value.trim().isEmpty) {

                      return 'Username is required';

                    }

                    if (value.length < 3) {

                      return 'Username must be at least 3 characters';

                    }

                    return null;

                  },

                ),

              if (existing == null) const SizedBox(height: 16),

              TextFormField(

                controller: contactCtl,

                decoration: _fieldDecoration('Contact no.', isRequired: true),

                keyboardType: TextInputType.phone,

                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],

                validator: (value) {

                  if (value == null || value.trim().isEmpty) {

                    return 'Contact no. is required';

                  }

                  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

                  if (digitsOnly.length != 11) {

                    return 'Contact no. must be exactly 11 digits';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 16),

              if (existing == null)

                TextFormField(

                  controller: passwordCtl,

                  decoration: _fieldDecoration('Temporary Password', isRequired: true),

                  obscureText: true,

                  validator: validatePassword,

                ),

              if (existing == null) const SizedBox(height: 16),

              if (existing == null && isSuperAdmin)

                Column(

                  children: [

                    DropdownButtonFormField<String>(

                      decoration: _fieldDecoration('Role', isRequired: true, icon: Icons.badge_outlined),

                      value: selectedRole,

                      items: roleOptions

                          .map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!)))

                          .toList(),

                      onChanged: (value) {

                        setLocal(() {

                          selectedRole = value ?? 'agent';

                          if (selectedRole == 'agent' && (selectedPermission == null || selectedPermission!.trim().isEmpty)) {

                            selectedPermission = 'view_add';

                          }

                        });

                      },

                      validator: (value) {

                        if (value == null || value.isEmpty) return 'Please select role';

                        return null;

                      },

                    ),

                    const SizedBox(height: 16),

                  ],

                ),



              // Company selection (forced to current company for Company Admin)

              if (existing == null)

                FutureBuilder<List<Map<String, String>>>(

                  future: _loadCompaniesForForm(),

                  builder: (context, snapshot) {

                    final companies = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(

                      decoration: _fieldDecoration('Company', isRequired: true, icon: Icons.business),

                      value: selectedCompanyId,

                      items: [

                        ...companies.map((c) => DropdownMenuItem(

                              value: c['id'],

                              child: Text(c['name'] ?? ''),

                            )),

                      ],

                      onChanged: (value) {

                              setLocal(() {

                                selectedCompanyId = value;

                                // Regenerate User ID when company changes (new user only)

                                if (existing == null) {

                                  _userIdError = null;

                                  _userIdInitDone = false;

                                  userIdCtl.text = '';

                                }

                              });

                              final cid = value;

                              if (existing == null && cid != null && cid.trim().isNotEmpty) {

                                _refreshUserLimit(companyId: cid, setLocal: setLocal);

                                _autoGenerateUserId(companyId: cid, setLocal: setLocal);

                              }

                            },

                      validator: (value) {

                        if (value == null || value.isEmpty) return 'Please select company';

                        return null;

                      },

                    );

                  },

                ),

              if (existing == null) const SizedBox(height: 16),

              if (selectedRole != 'agent')

                Column(

                  children: [

                    DropdownButtonFormField<String>(

                      decoration: _fieldDecoration('Restrictions/Permissions', isRequired: true),

                      value: selectedPermission,

                      items: permissionOptions.map((option) {

                        return DropdownMenuItem(

                          value: option['value'],

                          child: Text(option['label']!),

                        );

                      }).toList(),

                      onChanged: (value) {

                        setLocal(() {

                          selectedPermission = value;

                        });

                      },

                      validator: (value) {

                        if (value == null || value.isEmpty) {

                          return 'Please select permissions';

                        }

                        return null;

                      },

                    ),

                    const SizedBox(height: 24),

                  ],

                ),

              if (selectedRole == 'agent')

                Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'Module Permissions',

                      style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),

                    ),

                    const SizedBox(height: 10),

                    LayoutBuilder(

                      builder: (context, constraints) {

                        final isWide = constraints.maxWidth >= 520;

                        return Column(

                          children: moduleDefs.map((m) {

                            final moduleKey = m['key']!;

                            final moduleLabel = m['label']!;

                            final currentLevel = modulePermissions[moduleKey] ?? 'no_access';



                            final dropdown = DropdownButtonFormField<String>(

                              value: currentLevel,

                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),

                              items: modulePermissionOptions

                                  .map(

                                    (o) => DropdownMenuItem<String>(

                                      value: o['value'],

                                      child: Text(o['label']!),

                                    ),

                                  )

                                  .toList(),

                              onChanged: (value) {

                                setLocal(() {

                                  modulePermissions[moduleKey] = value ?? 'no_access';

                                });

                              },

                            );



                            if (isWide) {

                              return Padding(

                                padding: const EdgeInsets.only(bottom: 10),

                                child: Row(

                                  children: [

                                    Expanded(

                                      child: Text(

                                        moduleLabel,

                                        style: AppFonts.poppins(fontWeight: FontWeight.w600),

                                      ),

                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(child: dropdown),

                                  ],

                                ),

                              );

                            }



                            return Padding(

                              padding: const EdgeInsets.only(bottom: 10),

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(moduleLabel, style: AppFonts.poppins(fontWeight: FontWeight.w600)),

                                  const SizedBox(height: 8),

                                  dropdown,

                                ],

                              ),

                            );

                          }).toList(),

                        );

                      },

                    ),

                    const SizedBox(height: 24),

                  ],

                ),

              if (existing == null && selectedCompanyId != null)

                Padding(

                  padding: const EdgeInsets.only(bottom: 12),

                  child: Text(

                    _checkingUserLimit

                        ? 'Checking user limit...'

                        : (_maxUserLimit != null && _currentActiveUsers != null)

                            ? 'Active users: $_currentActiveUsers / $_maxUserLimit'

                            : 'User limit status: unknown',

                    style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade700),

                  ),

                ),

              Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  OutlinedButton.icon(

                    onPressed: () {

                      _resetUserForm();

                      Navigator.of(context).pop();

                    },

                    icon: const Icon(Icons.close, size: 18),

                    label: Text(

                      'Cancel',

                      style: AppFonts.poppins(fontWeight: FontWeight.w600),

                    ),

                    style: OutlinedButton.styleFrom(

                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(12),

                      ),

                    ),

                  ),

                  const SizedBox(width: 12),

                  PrimaryGradientButton(

                    text: 'Save',

                    icon: Icons.save,

                    onPressed: (existing == null && _userLimitReached)

                        ? null

                        : () async {

                            if (kDebugMode) {

                              debugPrint('AddUser: Save pressed existing=${existing != null} role=$selectedRole selectedCompanyId=$selectedCompanyId myCompanyId=$myCompanyId checking=$_checkingUserLimit reached=$_userLimitReached');

                            }

                            final isValid = formKey.currentState?.validate() ?? false;

                            if (kDebugMode) {

                              debugPrint('AddUser: form validate -> $isValid');

                            }

                            if (!isValid) return;



                            // Bypass permission checks for Super Admin

                            try {

                              final id = existing != null ? (existing?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString()) : DateTime.now().millisecondsSinceEpoch.toString();

                              final nowIso = DateTime.now().toUtc().toIso8601String();

                              final createdIso = existing == null

                                  ? nowIso

                                  : (existing?['created_at']?.toString() ?? existing?['createdAt']?.toString() ?? nowIso);

                              final name = nameCtl.text.trim();

                              final userId = userIdCtl.text.trim();

                              final email = emailCtl.text.trim();

                              final username = existing == null ? usernameCtl.text.trim() : (existing?['username']?.toString() ?? email);

                              final contactNo = contactCtl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');



                              // Hash the password if creating new user

                              String? hashedPassword;

                              String? salt;

                              int? iterations;

                              String? tempPassword;

                              if (existing == null) {

                                tempPassword = passwordCtl.text;

                                hashedPassword = PasswordHasher.hash(tempPassword);

                                final parts = hashedPassword.split(':');

                                iterations = int.parse(parts[0]);

                                salt = parts[1];

                              }



                              final effectiveCompanyId = isSuperAdmin ? selectedCompanyId : myCompanyId;

                              if (effectiveCompanyId == null || effectiveCompanyId.trim().isEmpty) {

                                if (mounted) {

                                  ScaffoldMessenger.of(context).showSnackBar(

                                    const SnackBar(content: Text('Please select company'), backgroundColor: Colors.red),

                                  );

                                }

                                return;

                              }



                              if (existing == null) {

                                try {

                                  await _ensureUniqueUserId(companyId: effectiveCompanyId, currentUserId: id, setLocal: setLocal);

                                } catch (_) {

                                  if (mounted) {

                                    ScaffoldMessenger.of(context).showSnackBar(

                                      const SnackBar(content: Text('Failed to generate unique User ID. Please try again.'), backgroundColor: Colors.red),

                                    );

                                  }

                                  return;

                                }

                              } else {

                                final unique = await _isUserIdUnique(

                                  companyId: effectiveCompanyId,

                                  userId: userIdCtl.text.trim(),

                                  currentUserId: id,

                                );

                                if (!unique) {

                                  setLocal(() => _userIdError = 'This User ID is already assigned.');

                                  if (mounted) {

                                    ScaffoldMessenger.of(context).showSnackBar(

                                      const SnackBar(content: Text('This User ID is already assigned.'), backgroundColor: Colors.red),

                                    );

                                  }

                                  return;

                                }

                              }



                              if (existing == null) {

                                int? limit;

                                int? cnt;

                                String tier = 'Starter';



                                if (Firebase.apps.isNotEmpty) {

                                  try {

                                    // Enhanced with FirebaseThreadingHandler for Windows compatibility
                                    final doc = await FirebaseThreadingHandler.executeWithThreadSafety(
                                      () => FirebaseFirestore.instance.collection('companies').doc(effectiveCompanyId.toString()).get(),
                                      operationName: 'Home getCompany-effectiveCompanyId',
                                    );

                                    final data = doc.data();

                                    final raw = data?['max_user_limit'] ?? data?['maxUserLimit'];

                                    limit = raw is int ? raw : int.tryParse(raw?.toString() ?? '');

                                    tier = normalizeSubscriptionTier(data?['subscription_tier'] ?? data?['subscriptionTier']);

                                  } catch (e) {

                                    if (kDebugMode) {

                                      debugPrint('UserLimit(final): Firestore company limit read failed for companyId=$effectiveCompanyId: $e');

                                    }

                                  }



                                  try {

                                    QuerySnapshot<Map<String, dynamic>> snap;

                                    // Enhanced with FirebaseThreadingHandler for Windows compatibility
                                    snap = await FirebaseThreadingHandler.executeWithThreadSafety(
                                      () => FirebaseFirestore.instance.collection('users').where('company_id', isEqualTo: effectiveCompanyId).get(),
                                      operationName: 'Home syncUsers-effectiveCompanyId',
                                    );

                                    if (snap.docs.isEmpty) {

                                      // Enhanced with FirebaseThreadingHandler for Windows compatibility
                                      snap = await FirebaseThreadingHandler.executeWithThreadSafety(
                                        () => FirebaseFirestore.instance.collection('users').where('companyId', isEqualTo: effectiveCompanyId).get(),
                                        operationName: 'Home syncUsers-effectiveCompanyId',
                                      );

                                    }

                                    final docs = snap.docs.map((d) => d.data()).toList();

                                    cnt = docs.where((u) {

                                      final status = (u['status'] ?? 'active').toString().trim().toLowerCase();

                                      final isDeleted = (u['isDeleted'] == true) || (u['is_deleted'] == true);

                                      final deletedAt = u['deleted_at'];

                                      if (isDeleted) return false;

                                      if (deletedAt != null && deletedAt.toString().trim().isNotEmpty) return false;

                                      if (status == 'inactive' || status == 'deleted') return false;

                                      if (status.isNotEmpty && status != 'active') return false;

                                      final role = (u['role'] ?? (u['permissions'] is Map ? (u['permissions'] as Map)['role'] : null))?.toString();

                                      return role != 'super_admin';

                                    }).length;

                                  } catch (e) {

                                    if (kDebugMode) {

                                      debugPrint('UserLimit(final): Firestore user count failed for companyId=$effectiveCompanyId: $e');

                                    }

                                  }

                                }



                                if (limit == null || cnt == null) {

                                  final limitRes = await widget.db.customSelect(

                                    'SELECT max_user_limit, subscription_tier FROM companies WHERE id = ? LIMIT 1',

                                    variables: [d.Variable.withString(effectiveCompanyId)],

                                    readsFrom: {widget.db.companies},

                                  ).get();

                                  final row = limitRes.isNotEmpty ? limitRes.first.data : null;

                                  final limitRaw = row?['max_user_limit'];

                                  final tierRaw = row?['subscription_tier'];

                                  tier = normalizeSubscriptionTier(tierRaw ?? tier);

                                  limit ??= (limitRaw is int ? limitRaw : int.tryParse(limitRaw?.toString() ?? ''));

                                  limit ??= subscriptionLimitForTier(tier);

                                  final countRes = await widget.db.customSelect(

                                    "SELECT COUNT(*) as cnt FROM users WHERE company_id = ? AND (status = 'active' OR status IS NULL)",

                                    variables: [d.Variable.withString(effectiveCompanyId)],

                                    readsFrom: {widget.db.users},

                                  ).get();

                                  final cntRaw = countRes.isNotEmpty ? countRes.first.data['cnt'] : 0;

                                  cnt ??= cntRaw is int ? cntRaw : int.tryParse(cntRaw.toString()) ?? 0;

                                }



                                if (kDebugMode) {

                                  debugPrint('UserLimit(final): companyId=$effectiveCompanyId subscription_tier=$tier max_user_limit=$limit current_active_agents=$cnt');

                                }



                                if ((cnt ?? 0) >= (limit ?? 5)) {

                                  if (mounted) {

                                    ScaffoldMessenger.of(context).showSnackBar(

                                      SnackBar(content: Text('Limit reached: ${cnt ?? '?'} / ${limit ?? '?'} active users in use. Please contact Super Admin to upgrade your plan.')),

                                    );

                                  }

                                  return;

                                }

                              }



                              final isFirstLogin = existing == null && selectedRole == 'company_admin' ? 1 : 0;



                              if (!isSuperAdmin && selectedPermission == 'full_access') {

                                selectedPermission = 'view_add';

                              }



                              // Store permissions as JSON

                              final permissionsMap = _buildPermissionsPayload();

                              final permissionsJson = jsonEncode(permissionsMap);



                              // Insert or update user using raw SQL to include all new fields

                              if (existing == null) {

                                await widget.db.customStatement(

                                  'INSERT INTO users (id, username, password_hash, salt, iterations, user_id, name, email, contact_no, permissions, company_id, status, is_first_login, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',

                                  [id, username, hashedPassword, salt, iterations, userIdCtl.text.trim(), name, email, contactNo, permissionsJson, effectiveCompanyId, 'active', isFirstLogin, createdIso, nowIso],

                                );

                                if (kDebugMode) {

                                  debugPrint('AddUser: inserted locally userId=$id companyId=$effectiveCompanyId role=$selectedRole');

                                }



                                try {

                                  if (Firebase.apps.isNotEmpty) {

                                    final createdAtTs = Timestamp.fromDate(DateTime.tryParse(createdIso)?.toUtc() ?? DateTime.now().toUtc());

                                    await FirebaseFirestore.instance.collection('users').doc(id).set({

                                      'id': id,

                                      'username': username,

                                      'user_id': userIdCtl.text.trim(),

                                      'userId': userIdCtl.text.trim(),

                                      'name': name,

                                      'email': email,

                                      'contact_no': contactNo,

                                      'company_id': effectiveCompanyId,

                                      'companyId': effectiveCompanyId,

                                      'status': 'active',

                                      'isDeleted': false,

                                      'is_deleted': false,

                                      'role': selectedRole,

                                      'permissions': permissionsMap,

                                      'created_at': createdAtTs,

                                      'updated_at': nowIso,

                                    }, SetOptions(merge: true));

                                  }

                                } catch (e) {

                                  if (kDebugMode) {

                                    debugPrint('Firestore sync failed for users/$id: $e');

                                  }

                                }

                              } else {

                                if (isCompanyAdmin) {

                                  final existingCompanyId = existing?['company_id']?.toString();

                                  if (existingCompanyId == null || existingCompanyId != myCompanyId) {

                                    if (mounted) {

                                      ScaffoldMessenger.of(context).showSnackBar(

                                        const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

                                      );

                                    }

                                    return;

                                  }

                                }

                                // Update existing user (don't change password or is_first_login)

                                await widget.db.customStatement(

                                  'UPDATE users SET username = ?, user_id = ?, name = ?, email = ?, contact_no = ?, permissions = ?, company_id = ?, updated_at = ? WHERE id = ?',

                                  [username, userIdCtl.text.trim(), name, email, contactNo, permissionsJson, effectiveCompanyId, nowIso, id],

                                );

                                if (kDebugMode) {

                                  debugPrint('AddUser: updated locally userId=$id companyId=$effectiveCompanyId role=$selectedRole');

                                }



                                try {

                                  if (Firebase.apps.isNotEmpty) {

                                    final createdAtTs = Timestamp.fromDate(DateTime.tryParse(createdIso)?.toUtc() ?? DateTime.now().toUtc());

                                    final rawExistingStatus = existing == null ? null : existing['status'];

                                    final existingStatus = ((rawExistingStatus?.toString().trim().isNotEmpty) ?? false)

                                        ? rawExistingStatus.toString()

                                        : 'active';

                                    final normalizedStatus = existingStatus.toString().trim().toLowerCase();

                                    final existingIsDeleted = normalizedStatus == 'inactive' || normalizedStatus == 'deleted';

                                    await FirebaseFirestore.instance.collection('users').doc(id).set({

                                      'id': id,

                                      'username': username,

                                      'user_id': userIdCtl.text.trim(),

                                      'userId': userIdCtl.text.trim(),

                                      'name': name,

                                      'email': email,

                                      'contact_no': contactNo,

                                      'company_id': effectiveCompanyId,

                                      'companyId': effectiveCompanyId,

                                      'status': existingStatus,

                                      'isDeleted': existingIsDeleted,

                                      'is_deleted': existingIsDeleted,

                                      'role': selectedRole,

                                      'permissions': permissionsMap,

                                      'created_at': createdAtTs,

                                      'updated_at': nowIso,

                                    }, SetOptions(merge: true));

                                  }

                                } catch (e) {

                                  if (kDebugMode) {

                                    debugPrint('Firestore sync failed for users/$id: $e');

                                  }

                                }

                              }



                              // Close modal immediately after save (matching trading form pattern)

                              if (mounted) {

                                final wasAdding = existing == null;

                                final navContext = dialogContext ?? context;

                                Navigator.of(navContext).pop();

                                _resetUserForm();

                                await _load();

                                if (wasAdding && mounted) {

                                  // Show credentials if Company Admin was created

                                  if (selectedRole == 'company_admin' && tempPassword != null) {

                                    showDialog(

                                      context: context,

                                      barrierDismissible: false,

                                      builder: (context) => AlertDialog(

                                        title: Row(

                                          children: [

                                            Icon(Icons.info_outline, color: Colors.blue.shade700),

                                            const SizedBox(width: 8),

                                            Text('Company Admin Credentials', style: AppFonts.poppins(fontWeight: FontWeight.w600)),

                                          ],

                                        ),

                                        content: Builder(

                                          builder: (context) {

                                            final size = MediaQuery.of(context).size;

                                            final w = size.width < 560 ? size.width * 0.9 : 520.0;

                                            final maxH = size.height * 0.7;

                                            return ConstrainedBox(

                                              constraints: BoxConstraints(maxWidth: w, maxHeight: maxH),

                                              child: SingleChildScrollView(

                                                child: Column(

                                                  mainAxisSize: MainAxisSize.min,

                                                  crossAxisAlignment: CrossAxisAlignment.start,

                                                  children: [

                                                    Text(

                                                      'Please share these credentials with the Company Admin:',

                                                      style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade700),

                                                    ),

                                                    const SizedBox(height: 16),

                                                    Container(

                                                      padding: const EdgeInsets.all(12),

                                                      decoration: BoxDecoration(

                                                        color: Colors.blue.shade50,

                                                        borderRadius: BorderRadius.circular(8),

                                                        border: Border.all(color: Colors.blue.shade200),

                                                      ),

                                                      child: Column(

                                                        crossAxisAlignment: CrossAxisAlignment.start,

                                                        children: [

                                                          _buildCredentialRow('Username:', username),

                                                          const SizedBox(height: 8),

                                                          _buildCredentialRow('Temporary Password:', tempPassword!),

                                                        ],

                                                      ),

                                                    ),

                                                    const SizedBox(height: 12),

                                                    Container(

                                                      padding: const EdgeInsets.all(12),

                                                      decoration: BoxDecoration(

                                                        color: Colors.orange.shade50,

                                                        borderRadius: BorderRadius.circular(8),

                                                        border: Border.all(color: Colors.orange.shade200),

                                                      ),

                                                      child: Row(

                                                        children: [

                                                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),

                                                          const SizedBox(width: 8),

                                                          Expanded(

                                                            child: Text(

                                                              'The user will be required to change their password on first login.',

                                                              style: AppFonts.poppins(fontSize: 12, color: Colors.orange.shade900),

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

                                        actions: [

                                          TextButton.icon(

                                            onPressed: () {

                                              Clipboard.setData(ClipboardData(text: 'Username: $username\nPassword: $tempPassword'));

                                              ScaffoldMessenger.of(context).showSnackBar(

                                                const SnackBar(content: Text('Credentials copied to clipboard')),

                                              );

                                            },

                                            icon: const Icon(Icons.copy),

                                            label: const Text('Copy'),

                                          ),

                                          FilledButton(

                                            onPressed: () => Navigator.of(context).pop(),

                                            child: const Text('OK'),

                                          ),

                                        ],

                                      ),

                                    );

                                  } else {

                                    ScaffoldMessenger.of(context).showSnackBar(

                                      const SnackBar(content: Text('User added successfully')),

                                    );

                                  }

                                } else if (mounted) {

                                  ScaffoldMessenger.of(context).showSnackBar(

                                    const SnackBar(content: Text('User updated successfully')),

                                  );

                                }

                              }

                            } catch (e) {

                              if (mounted) {

                                ScaffoldMessenger.of(context).showSnackBar(

                                  SnackBar(content: Text('Failed to save user: $e')),

                                );

                              }

                            }

                          },

                  ),

                ],

              ),

            ],

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



  Future<void> _delete(String id) async {

    if (_currentUser == null) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }



    if (!PermissionHelper.canDelete(_currentUser)) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }



    if (RoleUtils.isCompanyAdmin(_currentUser)) {

      final myCompanyId = RoleUtils.getUserCompanyId(_currentUser);

      final target = _rows.where((r) => (r['id']?.toString() ?? '') == id).toList();

      final targetCompanyId = target.isEmpty ? null : target.first['company_id']?.toString();

      if (myCompanyId == null || targetCompanyId == null || targetCompanyId != myCompanyId) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

          );

        }

        return;

      }

    }



    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Confirm delete'),

        content: const Text('Deactivate this user? Historical data will be preserved.'),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),

          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate')),

        ],

      ),

    );

    if (ok != true) return;

    if (id == (_currentUser?['id']?.toString() ?? '')) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('You cannot deactivate your own account.'), backgroundColor: Colors.red),

        );

      }

      return;

    }



    String? targetRole;

    try {

      final target = _rows.where((r) => (r['id']?.toString() ?? '') == id).toList();

      if (target.isNotEmpty) {

        final p = target.first['permissions'];

        final decoded = p is String ? jsonDecode(p) : p;

        if (decoded is Map) {

          targetRole = decoded['role']?.toString();

        }

      }

    } catch (_) {}

    if (targetRole == 'super_admin') {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('You cannot deactivate Super Admin.'), backgroundColor: Colors.red),

        );

      }

      return;

    }



    final nowIso = DateTime.now().toUtc().toIso8601String();

    await widget.db.customStatement(

      "UPDATE users SET status = 'inactive', updated_at = ? WHERE id = ?",

      [nowIso, id],

    );



    // RootIsolateToken check removed - not available in this Flutter version

    Future.microtask(() async {

      try {

        if (Firebase.apps.isEmpty) return;

        await FirebaseFirestore.instance.collection('users').doc(id).set(

          {

            'status': 'inactive',

            'isDeleted': true,

            'is_deleted': true,

            'updated_at': nowIso,

            'deleted_at': nowIso,

            'deleted_by_id': _currentUser?['id']?.toString(),

            'deleted_by_name': (_currentUser?['name'] ?? _currentUser?['email'] ?? _currentUser?['username'])?.toString(),

          },

          SetOptions(merge: true),

        );



        // Build readable log id: YYYYMMDD_HHMMSS_userId

        String _pad2(int v) => v.toString().padLeft(2, '0');

        final now = DateTime.now().toUtc();

        final logId =

            '${now.year}${_pad2(now.month)}${_pad2(now.day)}_${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}_${id.toString()}';

        final actorName = (_currentUser?['name'] ?? _currentUser?['email'] ?? _currentUser?['username'])?.toString();

        final companyId = RoleUtils.getUserCompanyId(_currentUser);



        // Local audit log for offline visibility

        try {

          await widget.db.customStatement(

            'CREATE TABLE IF NOT EXISTS audit_logs (id TEXT PRIMARY KEY, action TEXT, target_id TEXT, target_type TEXT, actor_id TEXT, actor_name TEXT, company_id TEXT, created_at TEXT, metadata TEXT)',

          );

          await widget.db.customStatement(

            'INSERT OR REPLACE INTO audit_logs (id, action, target_id, target_type, actor_id, actor_name, company_id, created_at, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',

            [

              logId,

              'User Deactivated',

              id,

              'user',

              _currentUser?['id']?.toString(),

              actorName,

              companyId,

              nowIso,

              null

            ],

          );

        } catch (e) {

          debugPrint('Local audit log insert failed: $e');

        }



        await FirebaseFirestore.instance.collection('user_audit_logs').doc(logId).set(

          {

            'action': 'User Deactivated',

            'target_user_id': id,

            'deleted_at': nowIso,

            'deleted_by_id': _currentUser?['id']?.toString(),

            'deleted_by_name': actorName,

            'company_id': companyId,

            'companyId': companyId,

            'created_at': nowIso,

            'id': logId,

          },

        );

      } catch (e) {

        debugPrint('User deactivate Firestore sync failed for users/$id: $e');

      }

    });

    await _load();

  }



  Future<void> _resetUserPassword(String userId, String username, String? email) async {

    final passwordCtl = TextEditingController();

    final confirmPasswordCtl = TextEditingController();

    final formKey = GlobalKey<FormState>();

    

    final result = await showDialog<bool>(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => AlertDialog(

        title: Row(

          children: [

            Icon(Icons.lock_reset, color: Colors.orange.shade700),

            const SizedBox(width: 8),

            Text('Reset Password', style: AppFonts.poppins(fontWeight: FontWeight.w600)),

          ],

        ),

        content: Form(

          key: formKey,

          child: SingleChildScrollView(

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'Reset password for:',

                  style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade700),

                ),

                const SizedBox(height: 4),

                Text(

                  'Username: $username\nEmail: ${email ?? ''}',

                  style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),

                ),

                const SizedBox(height: 16),

                TextFormField(

                  controller: passwordCtl,

                  obscureText: true,

                  decoration: InputDecoration(

                    labelText: 'New Temporary Password',

                    prefixIcon: const Icon(Icons.lock_outline),

                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

                  ),

                  validator: (value) {

                    if (value == null || value.isEmpty) {

                      return 'Password is required';

                    }

                    if (value.length < 6) {

                      return 'Password must be at least 6 characters';

                    }

                    return null;

                  },

                ),

                const SizedBox(height: 12),

                TextFormField(

                  controller: confirmPasswordCtl,

                  obscureText: true,

                  decoration: InputDecoration(

                    labelText: 'Confirm Password',

                    prefixIcon: const Icon(Icons.lock_outline),

                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

                  ),

                  validator: (value) {

                    if (value == null || value.isEmpty) {

                      return 'Please confirm password';

                    }

                    if (value != passwordCtl.text) {

                      return 'Passwords do not match';

                    }

                    return null;

                  },

                ),

                const SizedBox(height: 12),

                Container(

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: Colors.blue.shade50,

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(color: Colors.blue.shade200),

                  ),

                  child: Row(

                    children: [

                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Text(

                          'This will set a new temporary password. User will be required to change it on next login.',

                          style: AppFonts.poppins(fontSize: 12, color: Colors.blue.shade900),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Cancel'),

          ),

          FilledButton(

            onPressed: () {

              if (formKey.currentState!.validate()) {

                Navigator.pop(ctx, true);

              }

            },

            style: FilledButton.styleFrom(backgroundColor: Colors.orange),

            child: const Text('Reset Password'),

          ),

        ],

      ),

    );

    

    if (result != true) return;

    

    try {

      final newPassword = passwordCtl.text.trim();

      final hashedPassword = PasswordHasher.hash(newPassword);

      final parts = hashedPassword.split(':');

      final iterations = int.parse(parts[0]);

      final salt = parts[1];

      

      // Update password and set is_first_login to true

      await widget.db.customStatement(

        'UPDATE users SET password_hash = ?, salt = ?, iterations = ?, is_first_login = ?, updated_at = ? WHERE id = ?',

        [

          hashedPassword,

          salt,

          iterations,

          1, // Set is_first_login to true (force password change)

          DateTime.now().toUtc().toIso8601String(),

          userId,

        ],

      );



      await AuthService().syncUserCacheFromDb(db: widget.db, userId: userId);

      

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text('Password reset successfully!', style: TextStyle(fontWeight: FontWeight.w600)),

                const SizedBox(height: 4),

                Text('New password: $newPassword', style: const TextStyle(fontSize: 12)),

                const SizedBox(height: 4),

                const Text('User will be required to change password on next login.', style: TextStyle(fontSize: 11)),

              ],

            ),

            backgroundColor: Colors.green,

            duration: const Duration(seconds: 5),

            action: SnackBarAction(

              label: 'Copy',

              textColor: Colors.white,

              onPressed: () {

                Clipboard.setData(ClipboardData(text: 'Username: $username\nPassword: $newPassword'));

                ScaffoldMessenger.of(context).showSnackBar(

                  const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),

                );

              },

            ),

          ),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to reset password: $e'), backgroundColor: Colors.red),

        );

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    final isSuperAdmin = true;

    final rows = _q.isEmpty

        ? _rows

        : _rows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();

    return Scaffold(

      appBar: AppBar(

        title: Text('Users', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        flexibleSpace: Container(

          decoration: BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [

                const Color(0xFFFF6B35),

                const Color(0xFF4A90E2),

              ],

            ),

          ),

        ),

        actions: [

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

            child: TopRightSearch(onChanged: (q) => setState(() => _q = q)),

          ),

          // Test buttons - Remove in production

          PopupMenuButton<String>(

            icon: const Icon(Icons.bug_report, color: Colors.white),

            tooltip: 'Test Queries',

            onSelected: (value) {

              if (value == 'query') {

                _testQueryUserByEmail('ali@gmail.com');

              } else if (value == 'password') {

                _checkUserPasswordInfo('ali@gmail.com');

              }

            },

            itemBuilder: (context) => [

              const PopupMenuItem(

                value: 'query',

                child: Row(

                  children: [

                    Icon(Icons.search, size: 18),

                    SizedBox(width: 8),

                    Text('Query User'),

                  ],

                ),

              ),

              const PopupMenuItem(

                value: 'password',

                child: Row(

                  children: [

                    Icon(Icons.lock, size: 18),

                    SizedBox(width: 8),

                    Text('Check Password Info'),

                  ],

                ),

              ),

            ],

          ),

        ],

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: () => _showAddFormDialog(),

        icon: const Icon(Icons.add),

        label: const Text('Add New User'),

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

        child: Stack(

          children: [

            rows.isEmpty

                ? Center(

                    child: Column(

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [

                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),

                        const SizedBox(height: 16),

                        Text(

                          'No users found',

                          style: AppFonts.poppins(

                            fontSize: 18,

                            color: Colors.grey.shade600,

                          ),

                        ),

                      ],

                    ),

                  )

                : ListView.builder(

                    padding: const EdgeInsets.all(12),

                    itemCount: rows.length,

                    itemBuilder: (ctx, i) {

                      final r = rows[i];

                      final userId = r['id']?.toString() ?? '';

                      final username = r['username']?.toString() ?? '';

                      final email = r['email']?.toString() ?? username;

                      final displayUserId = r['user_id']?.toString();

                      final status = (r['status'] ?? 'active').toString();

                      final isInactive = status != 'active';

                      final name = r['name']?.toString() ?? r['username']?.toString() ?? 'N/A';

                      final normalizedUserId = (displayUserId ?? '').trim();

                      final nameWithUserId = normalizedUserId.isEmpty ? name : '$name ($normalizedUserId)';

                      final titleText = isInactive ? '$nameWithUserId (Inactive)' : nameWithUserId;

                      return Card(

                        margin: const EdgeInsets.only(bottom: 12),

                        elevation: 2,

                        child: ListTile(

                          leading: CircleAvatar(

                            backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),

                            child: Icon(Icons.person, color: const Color(0xFFFF6B35)),

                          ),

                          title: Text(

                            titleText,

                            style: AppFonts.poppins(fontWeight: FontWeight.w600),

                          ),

                          subtitle: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              if (normalizedUserId.isNotEmpty) Text('User ID: $normalizedUserId', style: AppFonts.poppins(fontSize: 12)),

                              if (r['email'] != null)

                                Text('Email: ${r['email']}', style: AppFonts.poppins(fontSize: 12)),

                              if (r['contact_no'] != null)

                                Text('Contact: ${r['contact_no']}', style: AppFonts.poppins(fontSize: 12)),

                              if (isInactive)

                                Text(

                                  'Status: $status',

                                  style: AppFonts.poppins(fontSize: 12, color: Colors.red.shade700),

                                ),

                              if (r['permissions'] != null)

                                Text(

                                  'Permissions: ${_getPermissionLabel(r['permissions'])}',

                                  style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade600),

                                ),

                            ],

                          ),

                          trailing: PopupMenuButton<String>(

                            itemBuilder: (context) => [

                              PopupMenuItem<String>(

                                value: 'edit',

                                child: const Row(

                                  children: [

                                    Icon(Icons.edit, size: 18),

                                    SizedBox(width: 8),

                                    Text('Edit'),

                                  ],

                                ),

                              ),

                              PopupMenuItem<String>(

                                value: 'reset',

                                child: const Row(

                                  children: [

                                    Icon(Icons.lock_reset, size: 18, color: Colors.orange),

                                    SizedBox(width: 8),

                                    Text('Reset Password'),

                                    ],

                                  ),

                                ),

                              if (PermissionHelper.canDelete(_currentUser)) ...[

                                const PopupMenuDivider(),

                                PopupMenuItem<String>(

                                  value: 'delete',

                                  child: const Row(

                                    children: [

                                      Icon(Icons.delete, size: 18, color: Colors.red),

                                      SizedBox(width: 8),

                                      Text('Delete'),

                                    ],

                                  ),

                                ),

                              ],

                            ],

                            onSelected: (value) {

                              if (value == 'edit') {

                                _showAddFormDialog(existing: r);

                              } else if (value == 'reset') {

                                _resetUserPassword(userId, username, email);

                              } else if (value == 'delete') {

                                _delete(r['id'] as String);

                              }

                            },

                          ),

                        ),

                      );

                    },

                  ),

            if (_syncState.isLoading)

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



  String _getPermissionLabel(dynamic permissions) {

    try {

      if (permissions is String) {

        final perms = jsonDecode(permissions);

        return perms['permission']?.toString() ?? 'N/A';

      }

      return 'N/A';

    } catch (e) {

      return 'N/A';

    }

  }

}



/// Companies Management Page - Super Admin Only

/// Allows Super Admin to create, edit, activate, and deactivate companies

class CompaniesPage extends StatefulWidget {

  final AppDatabase db;

  const CompaniesPage({super.key, required this.db});

  @override

  State<CompaniesPage> createState() => _CompaniesPageState();

}



class _CompaniesPageState extends State<CompaniesPage> {

  List<Map<String, dynamic>> _rows = [];

  String _q = '';

  bool _loading = true;

  Map<String, dynamic>? _editingCompany;

  Map<String, dynamic>? _currentUser;



  @override

  void initState() {

    super.initState();

    Future.microtask(() async {

      await _loadCurrentUser();

      await _load();

    });

  }



  Future<void> _loadCurrentUser() async {

    try {

      final s = await AppStorage().readSettings();

      final authToken = s['authToken'] as String?;

      if (authToken != null) {

        final user = await AuthService().getCurrentUser(authToken);

        if (mounted) setState(() => _currentUser = user);

      }

    } catch (_) {}

  }



  Future<void> _load() async {

    setState(() => _loading = true);

    try {

      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);

      final isCompanyAdmin = RoleUtils.isCompanyAdmin(_currentUser);

      final isAgent = RoleUtils.isAgent(_currentUser);

      if (isAgent) {

        setState(() {

          _rows = [];

          _loading = false;

        });

        return;

      }

      final companyId = RoleUtils.getUserCompanyId(_currentUser);

      final result = isSuperAdmin

          ? await widget.db.customSelect(

              'SELECT id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at FROM companies ORDER BY updated_at DESC',

              readsFrom: {widget.db.companies},

            ).get()

          : (isCompanyAdmin && companyId != null && companyId.isNotEmpty)

              ? await widget.db.customSelect(

                  'SELECT id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at FROM companies WHERE id = ? LIMIT 1',

                  variables: [d.Variable.withString(companyId)],

                  readsFrom: {widget.db.companies},

                ).get()

              : <d.QueryRow>[];

      var rows = result.map((r) => r.data).toList();



      // If nothing locally and Firestore is available, backfill companies from Firestore

      if (rows.isEmpty && Firebase.apps.isNotEmpty) {

        try {

          // Enhanced with FirebaseThreadingHandler for Windows compatibility
          final snap = await FirebaseThreadingHandler.executeWithThreadSafety(
            () => FirebaseFirestore.instance.collection('companies').get(),
            operationName: 'Home syncAllCompanies',
          );

          if (snap.docs.isNotEmpty) {

            final nowIso = DateTime.now().toUtc().toIso8601String();

            await widget.db.batch((batch) {

              for (final doc in snap.docs) {

                final data = doc.data();

                final id = doc.id.toString();

                if (id.trim().isEmpty) continue;

                final name = (data['name'] ?? '').toString();

                final status = (data['status'] ?? 'active').toString();

                final metadataRaw = data['metadata'];

                final metadata = metadataRaw == null

                    ? null

                    : (metadataRaw is String ? metadataRaw : jsonEncode(metadataRaw));

                final logoUrl = (data['logoUrl'] ?? data['logo_url'])?.toString();

                final address = data['address']?.toString();

                final contact = data['contact']?.toString();

                final maxRaw = data['max_user_limit'] ?? data['maxUserLimit'];

                final maxUserLimit = maxRaw is int ? maxRaw : int.tryParse(maxRaw?.toString() ?? '');

                final tier = (data['subscription_tier'] ?? data['subscriptionTier'] ?? 'Starter').toString();

                final createdAt = (data['created_at'] ?? data['createdAt'] ?? nowIso).toString();

                final updatedAt = (data['updated_at'] ?? data['updatedAt'] ?? nowIso).toString();



                batch.customStatement(

                  'INSERT OR REPLACE INTO companies (id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',

                  [

                    id,

                    name,

                    status,

                    metadata,

                    logoUrl,

                    address,

                    contact,

                    maxUserLimit,

                    tier,

                    createdAt,

                    updatedAt,

                  ],

                );

              }

            });



            final refreshed = isSuperAdmin

                ? await widget.db.customSelect(

                    'SELECT id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at FROM companies ORDER BY updated_at DESC',

                    readsFrom: {widget.db.companies},

                  ).get()

                : (isCompanyAdmin && companyId != null && companyId.isNotEmpty)

                    ? await widget.db.customSelect(

                        'SELECT id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at FROM companies WHERE id = ? LIMIT 1',

                        variables: [d.Variable.withString(companyId)],

                        readsFrom: {widget.db.companies},

                      ).get()

                    : <d.QueryRow>[];

            rows = refreshed.map((r) => r.data).toList();

          }

        } catch (e) {

          if (kDebugMode) {

            debugPrint('Companies Firestore backfill failed: $e');

          }

        }

      }



      setState(() {

        _rows = rows;

        _loading = false;

      });

    } catch (e) {

      setState(() => _loading = false);

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Error loading companies: $e')),

        );

      }

    }

  }



  void _showAddFormDialog({Map<String, dynamic>? existing}) {

    // Bypass permission checks for Super Admin

    setState(() {

      _editingCompany = existing;

    });

    

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => Focus(

        autofocus: true,

        onKeyEvent: (node, event) {

          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {

            setState(() {

              _editingCompany = null;

            });

            Navigator.of(context).pop();

            return KeyEventResult.handled;

          }

          return KeyEventResult.ignored;

        },

        child: Dialog(

          backgroundColor: Colors.transparent,

          insetPadding: EdgeInsets.symmetric(

            horizontal: MediaQuery.of(context).size.width < 600 ? 8 : 16,

            vertical: MediaQuery.of(context).size.height < 800 ? 8 : 16,

          ),

          child: Container(

            constraints: BoxConstraints(

              maxWidth: 600,

              maxHeight: MediaQuery.of(context).size.height * 0.9,

            ),

            decoration: BoxDecoration(

              color: Theme.of(context).cardColor,

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

                      Padding(

                        padding: const EdgeInsets.only(top: 56),

                        child: SingleChildScrollView(

                          padding: const EdgeInsets.all(20),

                          child: _buildAddCompanyForm(setDialogState, dialogContext),

                        ),

                      ),

                      Positioned(

                        top: 12,

                        left: 12,

                        child: Material(

                          color: Colors.transparent,

                          child: InkWell(

                            onTap: () {

                              setState(() {

                                _editingCompany = null;

                              });

                              Navigator.of(context).pop();

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



  void _resetCompanyForm() {

    setState(() {

      _editingCompany = null;

    });

  }



  Widget _buildAddCompanyForm([StateSetter? dialogSetState, BuildContext? dialogContext]) {

    final existing = _editingCompany;

    final nameCtl = TextEditingController(text: existing?['name']?.toString() ?? '');

    final metadataCtl = TextEditingController(text: existing?['metadata']?.toString() ?? '');

    final logoCtl = TextEditingController(text: existing?['logo_url']?.toString() ?? '');

    final addressCtl = TextEditingController(text: existing?['address']?.toString() ?? '');

    final contactCtl = TextEditingController(text: existing?['contact']?.toString() ?? '');



    final existingTierRaw = existing?['subscription_tier'];

    final existingLimitRaw = existing?['max_user_limit'];

    final existingLimit = existingLimitRaw is int ? existingLimitRaw : int.tryParse(existingLimitRaw?.toString() ?? '');

    String selectedTier = normalizeSubscriptionTier(existingTierRaw);

    if ((existingTierRaw == null || existingTierRaw.toString().trim().isEmpty) && existingLimit != null) {

      if (existingLimit == 5) selectedTier = 'Starter';

      if (existingLimit == 10) selectedTier = 'Professional';

      if (existingLimit == 15) selectedTier = 'Business';

      if (existingLimit >= 16 && existingLimit <= 50) selectedTier = 'Enterprise';

    }

    // Safety check: Ensure selectedTier is always a valid option
    final validTiers = ['Starter', 'Professional', 'Business', 'Enterprise'];
    if (!validTiers.contains(selectedTier)) {
      selectedTier = 'Starter'; // Default to first option if invalid
    }

    final enterpriseLimitCtl = TextEditingController(text: (selectedTier == 'Enterprise' ? (existingLimit ?? 15) : 15).toString());



    final rawExistingStatus = existing == null ? null : existing['status'];

    String selectedStatus = rawExistingStatus?.toString() ?? 'active';

    final formKey = GlobalKey<FormState>();



    return StatefulBuilder(

      builder: (context, setLocal) {

        return Form(

          key: formKey,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [

              Text(

                existing == null ? 'Add New Company' : 'Edit Company',

                style: AppFonts.poppins(

                  fontSize: 24,

                  fontWeight: FontWeight.w700,

                  color: Colors.grey.shade900,

                ),

              ),

              const SizedBox(height: 28),

              TextFormField(

                controller: nameCtl,

                decoration: _fieldDecoration('Company Name', isRequired: true, icon: Icons.business),

                validator: (value) {

                  if (value == null || value.trim().isEmpty) {

                    return 'Company name is required';

                  }

                  if (value.length > 200) {

                    return 'Maximum 200 characters allowed';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(

                decoration: _fieldDecoration('Status', isRequired: true, icon: Icons.info_outline),

                value: selectedStatus,

                items: const [

                  DropdownMenuItem(value: 'active', child: Text('Active')),

                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),

                ],

                onChanged: (value) {

                  setLocal(() {

                    selectedStatus = value ?? 'active';

                  });

                },

                validator: (value) {

                  if (value == null || value.isEmpty) {

                    return 'Please select status';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 16),

              TextFormField(

                controller: metadataCtl,

                decoration: _fieldDecoration('Metadata (Optional)', icon: Icons.description_outlined),

                maxLines: 3,

                validator: (value) {

                  if (value != null && value.length > 500) {

                    return 'Maximum 500 characters allowed';

                  }

                  return null;

                },

              ),

              const SizedBox(height: 16),

              TextFormField(

                controller: logoCtl,

                decoration: _fieldDecoration('Company Logo URL/Path (Optional)', icon: Icons.image_outlined),

                validator: (value) {

                  if (value != null && value.length > 500) return 'Maximum 500 characters allowed';

                  return null;

                },

              ),

              const SizedBox(height: 16),

              TextFormField(

                controller: addressCtl,

                decoration: _fieldDecoration('Company Address (Optional)', icon: Icons.location_on_outlined),

                maxLines: 2,

                validator: (value) {

                  if (value != null && value.length > 500) return 'Maximum 500 characters allowed';

                  return null;

                },

              ),

              const SizedBox(height: 16),

              TextFormField(

                controller: contactCtl,

                decoration: _fieldDecoration('Company Contact (Optional)', icon: Icons.phone_outlined),

                validator: (value) {

                  if (value != null && value.length > 200) return 'Maximum 200 characters allowed';

                  return null;

                },

              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(

                decoration: _fieldDecoration('Subscription Package', isRequired: true, icon: Icons.workspace_premium_outlined),

                value: selectedTier,

                items: const [

                  DropdownMenuItem(value: 'Starter', child: Text('Starter (Max 5 Agents)')),

                  DropdownMenuItem(value: 'Professional', child: Text('Professional (Max 10 Agents)')),

                  DropdownMenuItem(value: 'Business', child: Text('Business (Max 15 Agents)')),

                  DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise (15 to 50 Agents)')),

                ],

                onChanged: (value) {

                  setLocal(() {

                    selectedTier = normalizeSubscriptionTier(value);

                    if (selectedTier != 'Enterprise') {

                      enterpriseLimitCtl.text = '15';

                    }

                  });

                },

                validator: (value) {

                  if (value == null || value.trim().isEmpty) return 'Please select a package';

                  return null;

                },

              ),

              if (selectedTier == 'Enterprise') ...[

                const SizedBox(height: 16),

                TextFormField(

                  controller: enterpriseLimitCtl,

                  decoration: _fieldDecoration('Enterprise Agent Limit (15 - 50)', isRequired: true, icon: Icons.people_outline),

                  keyboardType: TextInputType.number,

                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],

                  validator: (value) {

                    if (value == null || value.trim().isEmpty) {

                      return 'Enterprise agent limit is required';

                    }

                    final v = int.tryParse(value.trim());

                    if (v == null) return 'Please enter a valid number';

                    if (v < 15 || v > 50) return 'Enterprise limit must be between 15 and 50';

                    return null;

                  },

                ),

              ],

              const SizedBox(height: 24),

              Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  OutlinedButton.icon(

                    onPressed: () {

                      _resetCompanyForm();

                      Navigator.of(context).pop();

                    },

                    icon: const Icon(Icons.close, size: 18),

                    label: Text(

                      'Cancel',

                      style: AppFonts.poppins(fontWeight: FontWeight.w600),

                    ),

                    style: OutlinedButton.styleFrom(

                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(12),

                      ),

                    ),

                  ),

                  const SizedBox(width: 12),

                  PrimaryGradientButton(

                    text: existing == null ? 'Save Company' : 'Update Company',

                    icon: Icons.save,

                    onPressed: () async {

                      if (formKey.currentState == null || !formKey.currentState!.validate()) {

                        return;

                      }

                      

                      try {

                        final id = existing != null 

                            ? (existing?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString())

                            : DateTime.now().millisecondsSinceEpoch.toString();

                        final nowIso = DateTime.now().toUtc().toIso8601String();

                        final name = nameCtl.text.trim();

                        final metadata = metadataCtl.text.trim();

                        final logoUrl = logoCtl.text.trim();

                        final address = addressCtl.text.trim();

                        final contact = contactCtl.text.trim();

                        final tier = normalizeSubscriptionTier(selectedTier);

                        final enterpriseLimit = int.tryParse(enterpriseLimitCtl.text.trim());

                        final maxUserLimit = subscriptionLimitForTier(tier, enterpriseLimit: enterpriseLimit);

                        final createdAt = existing != null 

                            ? (existing!['created_at']?.toString() ?? nowIso)

                            : nowIso;

                        

                        // Restore check: see if a deleted/archived company with same name exists in Firestore

                        String restoreCompanyId = id;

                        String restoreCreatedAt = createdAt;

                        try {

                          if (existing == null && Firebase.apps.isNotEmpty) {

                            final snap = await FirebaseFirestore.instance

                                .collection('companies')

                                .where('name', isEqualTo: name)

                                .limit(1)

                                .get();

                            if (snap.docs.isNotEmpty) {

                              final doc = snap.docs.first;

                              final data = doc.data();

                              final wasDeleted = (data['isDeleted'] == true) || (data['is_deleted'] == true);

                              final prevCreated = data['created_at'] ?? data['createdAt'];

                              bool restore = false;

                              if (wasDeleted) {

                                restore = await showDialog<bool>(

                                      context: context,

                                      builder: (ctx) => AlertDialog(

                                        title: const Text('Restore Company?'),

                                        content: const Text('A previously deleted company with this name was found. Restore old data or create a fresh record?'),

                                        actions: [

                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Create Fresh')),

                                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),

                                        ],

                                      ),

                                    ) ??

                                    false;

                              }

                              if (restore) {

                                restoreCompanyId = doc.id;

                                if (prevCreated is String && prevCreated.isNotEmpty) {

                                  restoreCreatedAt = prevCreated;

                                }

                              } else {

                                restoreCompanyId = id;

                                restoreCreatedAt = createdAt;

                              }

                            }

                          }

                        } catch (_) {}



                        // Insert or update company using raw SQL

                        if (existing == null) {

                          await widget.db.customStatement(

                            'INSERT INTO companies (id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',

                            [

                              restoreCompanyId,

                              name,

                              selectedStatus,

                              metadata.isEmpty ? null : metadata,

                              logoUrl.isEmpty ? null : logoUrl,

                              address.isEmpty ? null : address,

                              contact.isEmpty ? null : contact,

                              maxUserLimit,

                              tier,

                              restoreCreatedAt,

                              nowIso,

                            ],

                          );

                        } else {

                          await widget.db.customStatement(

                            'UPDATE companies SET name = ?, status = ?, metadata = ?, logo_url = ?, address = ?, contact = ?, max_user_limit = ?, subscription_tier = ?, updated_at = ? WHERE id = ?',

                            [

                              name,

                              selectedStatus,

                              metadata.isEmpty ? null : metadata,

                              logoUrl.isEmpty ? null : logoUrl,

                              address.isEmpty ? null : address,

                              contact.isEmpty ? null : contact,

                              maxUserLimit,

                              tier,

                              nowIso,

                              id,

                            ],

                          );

                        }



                        try {

                          if (Firebase.apps.isNotEmpty) {

                            await FirebaseFirestore.instance.collection('companies').doc(restoreCompanyId).set({

                              'id': restoreCompanyId,

                              'name': name,

                              'status': selectedStatus,

                              'metadata': metadata.isEmpty ? null : metadata,

                              'logoUrl': logoUrl.isEmpty ? null : logoUrl,

                              'logo_url': logoUrl.isEmpty ? null : logoUrl,

                              'address': address.isEmpty ? null : address,

                              'contact': contact.isEmpty ? null : contact,

                              'max_user_limit': maxUserLimit,

                              'maxUserLimit': maxUserLimit,

                              'subscription_tier': tier,

                              'subscriptionTier': tier,

                              'created_at': restoreCreatedAt,

                              'updated_at': nowIso,

                            }, SetOptions(merge: true));

                          }

                        } catch (e) {

                          if (kDebugMode) {

                            debugPrint('Firestore sync failed for companies/$id: $e');

                          }

                        }

                        

                        // Close modal immediately after save (matching trading form pattern)

                        if (mounted) {

                          final wasAdding = existing == null;

                          final navContext = dialogContext ?? context;

                          Navigator.of(navContext).pop();

                          _resetCompanyForm();

                          await _load();

                          if (wasAdding && mounted) {

                            ScaffoldMessenger.of(context).showSnackBar(

                              const SnackBar(content: Text('Company added successfully')),

                            );

                          } else if (mounted) {

                            ScaffoldMessenger.of(context).showSnackBar(

                              const SnackBar(content: Text('Company updated successfully')),

                            );

                          }

                        }

                      } catch (e) {

                        if (mounted) {

                          ScaffoldMessenger.of(context).showSnackBar(

                            SnackBar(content: Text('Failed to save company: $e')),

                          );

                        }

                      }

                    },

                  ),

                ],

              ),

            ],

          ),

        );

      },

    );

  }



  InputDecoration _fieldDecoration(String label, {IconData? icon, bool isRequired = false}) {

    IconData? fieldIcon = icon ?? Icons.edit_outlined;

    

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



  Future<void> _delete(String id) async {

    if (!RoleUtils.isSuperAdmin(_currentUser) || !PermissionHelper.canDelete(_currentUser)) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Confirm delete'),

        content: Text('Delete company $id? This will also affect all users and data associated with this company.'),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),

          ElevatedButton(

            onPressed: () => Navigator.pop(ctx, true),

            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

            child: const Text('Delete'),

          ),

        ],

      ),

    );

    if (ok != true) return;

    try {

      await (widget.db.delete(widget.db.companies)..where((t) => t.id.equals(id))).go();

      await _load();

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Company deleted successfully')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to delete company: $e')),

        );

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    final isSuperAdmin = true;

    final rows = _q.isEmpty

        ? _rows

        : _rows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();

    return Scaffold(

      appBar: AppBar(

        title: Text('Companies', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        flexibleSpace: Container(

          decoration: BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [

                const Color(0xFFFF6B35),

                const Color(0xFF4A90E2),

              ],

            ),

          ),

        ),

        actions: [

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),

            child: TopRightSearch(onChanged: (q) => setState(() => _q = q)),

          ),

        ],

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: () => _showAddFormDialog(),

        icon: const Icon(Icons.add),

        label: const Text('Add New Company'),

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

        child: _loading

            ? const ShimmerPageLoading(itemCount: 10)

            : rows.isEmpty

                ? Center(

                    child: Column(

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [

                        Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),

                        const SizedBox(height: 16),

                        Text(

                          'No companies found',

                          style: AppFonts.poppins(

                            fontSize: 18,

                            color: Colors.grey.shade600,

                          ),

                        ),

                        const SizedBox(height: 8),

                        Text(

                          'Click the + button to add a new company',

                          style: AppFonts.poppins(

                            fontSize: 14,

                            color: Colors.grey.shade500,

                          ),

                        ),

                      ],

                    ),

                  )

                : ListView.builder(

                    padding: const EdgeInsets.all(12),

                    itemCount: rows.length,

                    itemBuilder: (ctx, i) {

                      final r = rows[i];

                      final status = r['status']?.toString() ?? 'active';

                      final isActive = status == 'active';

                      return Card(

                        margin: const EdgeInsets.only(bottom: 12),

                        elevation: 2,

                        child: ListTile(

                          leading: CircleAvatar(

                            backgroundColor: isActive 

                                ? Colors.green.withOpacity(0.1)

                                : Colors.grey.withOpacity(0.1),

                            child: Icon(

                              Icons.business,

                              color: isActive ? Colors.green : Colors.grey,

                            ),

                          ),

                          title: Text(

                            r['name']?.toString() ?? 'N/A',

                            style: AppFonts.poppins(fontWeight: FontWeight.w600),

                          ),

                          subtitle: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Row(

                                children: [

                                  Container(

                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                                    decoration: BoxDecoration(

                                      color: isActive 

                                          ? Colors.green.withOpacity(0.1)

                                          : Colors.grey.withOpacity(0.1),

                                      borderRadius: BorderRadius.circular(4),

                                    ),

                                    child: Text(

                                      isActive ? 'Active' : 'Inactive',

                                      style: AppFonts.poppins(

                                        fontSize: 11,

                                        color: isActive ? Colors.green : Colors.grey,

                                        fontWeight: FontWeight.w600,

                                      ),

                                    ),

                                  ),

                                  if (r['metadata'] != null && (r['metadata'] as String).isNotEmpty) ...[

                                    const SizedBox(width: 8),

                                    Text(

                                      'Metadata available',

                                      style: AppFonts.poppins(fontSize: 11, color: Colors.grey.shade600),

                                    ),

                                  ],

                                ],

                              ),

                              if (r['created_at'] != null)

                                Text(

                                  'Created: ${DateFormat('dd MMM yyyy').format(DateTime.parse(r['created_at']))}',

                                  style: AppFonts.poppins(fontSize: 11, color: Colors.grey.shade500),

                                ),

                            ],

                          ),

                          trailing: isSuperAdmin

                              ? PopupMenuButton(

                                  itemBuilder: (context) => [

                                    PopupMenuItem(

                                      child: const Text('Edit'),

                                      onTap: () => Future.delayed(

                                        const Duration(milliseconds: 100),

                                        () => _showAddFormDialog(existing: r),

                                      ),

                                    ),

                                    PopupMenuItem(

                                      child: Text(

                                        isActive ? 'Deactivate' : 'Activate',

                                        style: TextStyle(color: isActive ? Colors.orange : Colors.green),

                                      ),

                                      onTap: () => Future.delayed(

                                        const Duration(milliseconds: 100),

                                        () => _toggleStatus(r['id'] as String, !isActive),

                                      ),

                                    ),

                                    PopupMenuItem(

                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),

                                      onTap: () => Future.delayed(

                                        const Duration(milliseconds: 100),

                                        () => _delete(r['id'] as String),

                                      ),

                                    ),

                                  ],

                                )

                              : null,

                        ),

                      );

                    },

                  ),

      ),

    );

  }



  Future<void> _toggleStatus(String id, bool activate) async {

    if (!RoleUtils.isSuperAdmin(_currentUser)) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Permission Denied'), backgroundColor: Colors.red),

        );

      }

      return;

    }

    try {

      final newStatus = activate ? 'active' : 'inactive';

      final nowIso = DateTime.now().toUtc().toIso8601String();

      await widget.db.customStatement(

        'UPDATE companies SET status = ?, updated_at = ? WHERE id = ?',

        [newStatus, nowIso, id],

      );

      await _load();

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Company ${activate ? "activated" : "deactivated"} successfully')),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to update company status: $e')),

        );

      }

    }

  }



}



/// Sub-menu item for hover menu

class _HoverSubMenuItem {

  final String label;

  final IconData icon;

  final VoidCallback onTap;

  final bool isSelected;



  const _HoverSubMenuItem({

    required this.label,

    required this.icon,

    required this.onTap,

    this.isSelected = false,

  });

}



/// Overlay widget for sub-menu

class _SubMenuOverlay extends StatelessWidget {

  final GlobalKey itemKey;

  final List<_HoverSubMenuItem> subItems;

  final bool isCollapsed;

  final Animation<double> fadeAnimation;

  final Animation<Offset> slideAnimation;

  final VoidCallback onHoverEnter;

  final VoidCallback onHoverExit;

  final VoidCallback onClose;



  const _SubMenuOverlay({

    required this.itemKey,

    required this.subItems,

    required this.isCollapsed,

    required this.fadeAnimation,

    required this.slideAnimation,

    required this.onHoverEnter,

    required this.onHoverExit,

    required this.onClose,

  });



  @override

  Widget build(BuildContext context) {

    final RenderBox? itemBox =

        itemKey.currentContext?.findRenderObject() as RenderBox?;

    if (itemBox == null) return const SizedBox.shrink();



    final position = itemBox.localToGlobal(Offset.zero);

    final size = itemBox.size;

    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;



    // Calculate position for sub-menu with bridge area

    double left;

    double top;

    double bridgeWidth = 8.0; // Bridge area to prevent dead zone

    if (isCollapsed) {

      // When collapsed, show popover next to icon

      left = position.dx + size.width;

      top = position.dy;

    } else {

      // When expanded, show as popup to the right

      left = position.dx + size.width - bridgeWidth;

      top = position.dy;

    }



    return Positioned(

      left: left,

      top: top,

      child: MouseRegion(

        onEnter: (_) {

          // Keep menu open when hovering over it or the bridge

          onHoverEnter();

        },

        onExit: (_) {

          // Delay closing when mouse leaves

          onHoverExit();

        },

        child: Row(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Bridge area to prevent dead zone between sidebar and menu

            MouseRegion(

              onEnter: (_) => onHoverEnter(),

              onExit: (_) => onHoverExit(),

              child: Container(

                width: bridgeWidth,

                height: size.height,

                color: Colors.transparent,

              ),

            ),

            FadeTransition(

              opacity: fadeAnimation,

              child: SlideTransition(

                position: slideAnimation,

                child: Material(

                  color: Colors.transparent,

                  child: Container(

                    constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),

                    decoration: BoxDecoration(

                      color: isDark ? const Color(0xFF1B1F24) : Colors.white,

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(

                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,

                      ),

                      boxShadow: [

                        BoxShadow(

                          color: Colors.black.withOpacity(0.15),

                          blurRadius: 20,

                          offset: const Offset(0, 8),

                        ),

                      ],

                    ),

                    child: Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        for (var i = 0; i < subItems.length; i++)

                          MouseRegion(

                            onEnter: (_) => onHoverEnter(),

                            onExit: (_) => onHoverExit(),

                            child: InkWell(

                              onTap: () {

                                subItems[i].onTap();

                                onClose();

                              },

                              child: Container(

                                padding: const EdgeInsets.symmetric(

                                  horizontal: 16,

                                  vertical: 12,

                                ),

                                decoration: BoxDecoration(

                                  color: subItems[i].isSelected

                                      ? const Color(0xFFFF6B35).withOpacity(0.1)

                                      : Colors.transparent,

                                  borderRadius: BorderRadius.only(

                                    topLeft: i == 0

                                        ? const Radius.circular(12)

                                        : Radius.zero,

                                    topRight: i == 0

                                        ? const Radius.circular(12)

                                        : Radius.zero,

                                    bottomLeft: i == subItems.length - 1

                                        ? const Radius.circular(12)

                                        : Radius.zero,

                                    bottomRight: i == subItems.length - 1

                                        ? const Radius.circular(12)

                                        : Radius.zero,

                                  ),

                                ),

                                child: Row(

                                  children: [

                                    Icon(

                                      subItems[i].icon,

                                      size: 18,

                                      color: subItems[i].isSelected

                                          ? const Color(0xFFFF6B35)

                                          : Colors.grey.shade600,

                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(

                                      child: Text(

                                        subItems[i].label,

                                        style: AppFonts.poppins(

                                          fontSize: 14,

                                          color: subItems[i].isSelected

                                              ? const Color(0xFFFF6B35)

                                              : Colors.grey.shade800,

                                          fontWeight: subItems[i].isSelected

                                              ? FontWeight.w600

                                              : FontWeight.normal,

                                        ),

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            ),

                          ),

                      ],

                    ),

                  ),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}

