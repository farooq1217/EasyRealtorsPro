import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey, FilteringTextInputFormatter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../core/services/auth_service.dart';
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
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../core/shared_utils.dart' show TopRightSearch;

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
  bool _companiesSynced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _guardUnauthorizedCompanies();
      await _ensureActiveColumns();
      await _loadCurrentUser();
      await _load(forceSync: true); // initial sync once, later loads rely on local data unless forced
    });
  }

  void _guardUnauthorizedCompanies() {
    final role = (_currentUser?['role'] ?? '').toString().toLowerCase();
    final isAgent = RoleUtils.isAgent(_currentUser);
    final isUserRole = role == 'user';
    if (isAgent || isUserRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Denied'),
            content: const Text('You are not authorized to view Companies.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  Future<void> _ensureActiveColumns() async {
    // Defensive: ensure columns exist to avoid missing-column crashes on filtered queries
    try {
      await widget.db.customStatement('ALTER TABLE companies ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await widget.db.customStatement('UPDATE companies SET is_active = 1 WHERE is_active IS NULL');
    } catch (_) {}
    try {
      await widget.db.customStatement('ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await widget.db.customStatement('UPDATE users SET is_active = 1 WHERE is_active IS NULL');
    } catch (_) {}
  }

  Future<void> _loadCurrentUser() async {
    try {
      final s = await AppStorage().readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService().getCurrentUser(authToken);
        if (mounted) {
          setState(() => _currentUser = user);
          _guardUnauthorizedCompanies();
        }
      }
    } catch (_) {}
  }

  Future<void> _syncCompaniesFromFirestore() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('companies').get();
      if (snap.docs.isEmpty) return;

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await widget.db.batch((batch) {
        for (final doc in snap.docs) {
          final data = doc.data();
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
    } catch (_) {}
  }

  Future<void> _load({bool forceSync = false}) async {
    setState(() => _loading = true);
    try {
      if (forceSync || !_companiesSynced) {
        await _syncCompaniesFromFirestore(); // keep SQLite fresh before reading
        _companiesSynced = true;
      }

      final result = await widget.db.customSelect(
        "SELECT * FROM companies WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC",
        readsFrom: {widget.db.companies},
      ).get();
      final rows = result.map((r) => r.data).toList();

      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      // Fallback if new columns (e.g., is_active) are missing: load minimal data so UI is not blank
      try {
        final fallback = await widget.db.customSelect(
          "SELECT * FROM companies WHERE (status IS NULL OR (status != 'archived' AND status != 'deleted')) ORDER BY updated_at DESC",
          readsFrom: {widget.db.companies},
        ).get();
        final rows = fallback.map((r) => r.data).toList();
        if (mounted) {
          setState(() {
            _rows = rows;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading companies: $e')),
          );
        }
      }
    }
  }

  void _showAddFormDialog({Map<String, dynamic>? existing}) {
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
                style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      
                      try {
                        final id = existing != null 
                            ? (existing!['id'] as String)
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
                        
                        // Insert or update company using raw SQL
                        if (existing == null) {
                          await widget.db.customStatement(
                            'INSERT INTO companies (id, name, status, metadata, logo_url, address, contact, max_user_limit, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                            [
                              id,
                              name,
                              selectedStatus,
                              metadata.isEmpty ? null : metadata,
                              logoUrl.isEmpty ? null : logoUrl,
                              address.isEmpty ? null : address,
                              contact.isEmpty ? null : contact,
                              maxUserLimit,
                              tier,
                              createdAt,
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
                            await FirebaseFirestore.instance.collection('companies').doc(id).set({
                              'id': id,
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
                              'created_at': createdAt,
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
          style: GoogleFonts.poppins(color: Colors.grey.shade700),
          children: [
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
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
          style: GoogleFonts.poppins(
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
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: confirmColor != null ? ElevatedButton.styleFrom(backgroundColor: confirmColor) : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteCompany(String id) async {
    final ok = await _confirmAction(
      title: 'Delete company',
      message: 'Delete this company from both SQLite and Firestore? This will archive the record and its users.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (!ok) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await widget.db.customStatement(
        "UPDATE companies SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
        [nowIso, id],
      );
      await widget.db.customStatement(
        "UPDATE users SET status = 'archived', is_active = 0, updated_at = ? WHERE company_id = ?",
        [nowIso, id],
      );
    } catch (e) {
      debugPrint('Local archive failed for company $id: $e');
    }

    if (mounted) {
      setState(() {
        _rows.removeWhere((r) => (r['id']?.toString() ?? '') == id);
      });
    }
    await _load();

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(id).set(
          {
            'status': 'archived',
            'is_active': 0,
            'isActive': 0,
            'isDeleted': true,
            'is_deleted': true,
            'updated_at': nowIso,
            'deleted_at': nowIso,
            'deleted_by_id': _currentUser?['id']?.toString(),
            'deleted_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
          },
          SetOptions(merge: true),
        );

        String _pad2(int v) => v.toString().padLeft(2, '0');
        final now = DateTime.now().toUtc();
        final logId =
            '${now.year}${_pad2(now.month)}${_pad2(now.day)}_${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}_${id.toString()}';
        final actorName = (_currentUser?['name'] ?? _currentUser?['email'] ?? _currentUser?['username'])?.toString();

        // Local audit log
        try {
          await widget.db.customStatement(
            'CREATE TABLE IF NOT EXISTS audit_logs (id TEXT PRIMARY KEY, action TEXT, target_id TEXT, target_type TEXT, actor_id TEXT, actor_name TEXT, company_id TEXT, created_at TEXT, metadata TEXT)',
          );
          await widget.db.customStatement(
            'INSERT OR REPLACE INTO audit_logs (id, action, target_id, target_type, actor_id, actor_name, company_id, created_at, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              logId,
              'Company Deleted',
              id,
              'company',
              _currentUser?['id']?.toString(),
              actorName,
              (_currentUser?['company_id'] ?? _currentUser?['companyId'])?.toString(),
              nowIso,
              null
            ],
          );
        } catch (e) {
          debugPrint('Local audit log insert failed: $e');
        }

        await FirebaseFirestore.instance.collection('company_audit_logs').doc(logId).set({
          'action': 'Company Deleted',
          'company_id': id,
          'deleted_at': nowIso,
          'deleted_by_id': _currentUser?['id']?.toString(),
          'deleted_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
          'created_at': nowIso,
          'id': logId,
        });
      }
    } catch (e) {
      debugPrint('Firestore archive failed for company $id: $e');
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company archived (soft deleted)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final rows = _q.isEmpty
        ? _rows
        : _rows.where((r) => r.values.any((v) => (v?.toString().toLowerCase() ?? '').contains(_q.toLowerCase()))).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Companies', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click the + button to add a new company',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500),
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
                      final companyId = r['id']?.toString() ?? '';
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
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                                      style: GoogleFonts.poppins(
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
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                              if (r['created_at'] != null)
                                Text(
                                  'Created: ${DateFormat('dd MMM yyyy').format(DateTime.parse(r['created_at']))}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: const [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: isActive ? 'deactivate' : 'activate',
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive ? Icons.toggle_off : Icons.toggle_on,
                                      size: 20,
                                      color: isActive ? Colors.orange : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isActive ? 'Deactivate' : 'Activate'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: const [
                                    Icon(Icons.delete, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showAddFormDialog(existing: r);
                              } else if (value == 'activate') {
                                await _toggleCompanyStatus(companyId, true);
                              } else if (value == 'deactivate') {
                                await _toggleCompanyStatus(companyId, false);
                              } else if (value == 'delete') {
                                await _deleteCompany(companyId);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _toggleCompanyStatus(String id, bool activate) async {
    final ok = await _confirmAction(
      title: activate ? 'Activate company' : 'Deactivate company',
      message: 'Are you sure you want to ${activate ? "activate" : "deactivate"} this company?',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      confirmColor: activate ? Colors.green : Colors.orange,
    );
    if (!ok) return;

    final newStatus = activate ? 'active' : 'inactive';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Always update local SQLite first so UI reflects change even if remote fails
    try {
      await widget.db.customStatement(
        'UPDATE companies SET status = ?, is_active = ?, updated_at = ? WHERE id = ?',
        [newStatus, activate ? 1 : 0, nowIso, id],
      );
    } catch (_) {}

    // Attempt Firestore, but do not block UI if it fails
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(id).set(
          {
            'status': newStatus,
            'is_active': activate ? 1 : 0,
            'isDeleted': !activate,
            'is_deleted': !activate,
            'updated_at': nowIso,
            'updated_by_email': (_currentUser?['email'] ?? _currentUser?['username'])?.toString(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Swallow Firestore errors to avoid red banners; local state already updated.
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company ${activate ? "activated" : "deactivated"} successfully')),
      );
    }
  }
}
