import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared/shared.dart';
import 'package:drift/drift.dart' as d;
import '../../core/services/auth_service.dart';
import '../../core/services/app_storage.dart' show AppStorage;
import '../../firestore_sync_service.dart';

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  const SettingsPage({super.key, required this.db});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _currentUser;
  StreamSubscription<QuerySnapshot>? _societiesSub;
  StreamSubscription<QuerySnapshot>? _blocksSub;
  List<Map<String, dynamic>> _societies = [];
  List<Map<String, dynamic>> _blocks = [];
  String? _selectedSocietyId;
  final TextEditingController _societyNameController = TextEditingController();
  final TextEditingController _blockNameController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCurrentUser();
      await _initFirestoreListeners();
    });
  }

  @override
  void dispose() {
    _societiesSub?.cancel();
    _blocksSub?.cancel();
    _societyNameController.dispose();
    _blockNameController.dispose();
    super.dispose();
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

  /// Initialize real-time Firestore listeners for societies and blocks
  Future<void> _initFirestoreListeners() async {
    if (Firebase.apps.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (_currentUser == null) {
      setState(() => _loading = false);
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      setState(() => _loading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Listen to societies collection
      Query societiesQuery = firestore.collection('societies');
      if (!isSuperAdmin) {
        societiesQuery = societiesQuery.where('companyId', isEqualTo: companyId);
      }
      societiesQuery = societiesQuery.orderBy('name');

      _societiesSub = societiesQuery.snapshots().listen((snapshot) async {
        try {
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final data = doc.data() as Map<String, dynamic>;
            final id = (data['id'] ?? doc.id).toString();

            if (change.type == DocumentChangeType.removed) {
              // Delete from SQLite
              await widget.db.customStatement(
                'DELETE FROM societies WHERE id = ?',
                [id],
              );
              // Also delete all blocks for this society
              await widget.db.customStatement(
                'DELETE FROM blocks WHERE society_id = ?',
                [id],
              );
            } else {
              // Insert or update in SQLite
              final name = (data['name'] ?? '').toString();
              final cid = (data['companyId'] ?? data['company_id'])?.toString();
              final metadata = (data['metadata'] ?? '').toString();
              final updatedAt = (data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();

              await widget.db.into(widget.db.societies).insertOnConflictUpdate(
                SocietiesCompanion(
                  id: d.Value(id),
                  name: d.Value(name),
                  companyId: d.Value(cid),
                  metadata: d.Value(metadata.isEmpty ? null : metadata),
                  updatedAt: d.Value(updatedAt),
                ),
              );
            }
          }

          // Update local list
          final allSocieties = await widget.db.customSelect(
            isSuperAdmin
                ? 'SELECT id, name FROM societies ORDER BY name'
                : 'SELECT id, name FROM societies WHERE company_id = ? ORDER BY name',
            variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],
            readsFrom: {widget.db.societies},
          ).get();

          // Update UI on main thread
          Future.microtask(() {
            if (!mounted) return;
            setState(() {
              _societies = allSocieties.map((r) => {
                'id': r.data['id'] as String,
                'name': (r.data['name']?.toString()) ?? '',
              }).toList();
              _loading = false;
            });
          });
        } catch (e) {
          debugPrint('Error processing societies changes: $e');
          Future.microtask(() {
            if (!mounted) return;
            setState(() => _loading = false);
          });
        }
      }, onError: (error) {
        debugPrint('Error in societies listener: $error');
        // Handle missing index errors gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _loading = false);
        });
      });

      // Listen to blocks collection
      Query blocksQuery = firestore.collection('blocks');
      if (!isSuperAdmin) {
        blocksQuery = blocksQuery.where('companyId', isEqualTo: companyId);
      }
      blocksQuery = blocksQuery.orderBy('name');

      _blocksSub = blocksQuery.snapshots().listen((snapshot) async {
        try {
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final data = doc.data() as Map<String, dynamic>;
            final id = (data['id'] ?? doc.id).toString();

            if (change.type == DocumentChangeType.removed) {
              // Delete from SQLite
              await widget.db.customStatement(
                'DELETE FROM blocks WHERE id = ?',
                [id],
              );
            } else {
              // Insert or update in SQLite
              final societyId = (data['societyId'] ?? data['society_id'] ?? '').toString();
              final name = (data['name'] ?? '').toString();
              final cid = (data['companyId'] ?? data['company_id'])?.toString();
              final metadata = (data['metadata'] ?? '').toString();
              final updatedAt = (data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();

              await widget.db.into(widget.db.blocks).insertOnConflictUpdate(
                BlocksCompanion(
                  id: d.Value(id),
                  societyId: d.Value(societyId),
                  name: d.Value(name),
                  companyId: d.Value(cid),
                  metadata: d.Value(metadata.isEmpty ? null : metadata),
                  updatedAt: d.Value(updatedAt),
                ),
              );
            }
          }

          // Update local blocks list on main thread
          Future.microtask(() async {
            if (!mounted) return;
            await _loadBlocksForSelectedSociety();
          });
        } catch (e) {
          debugPrint('Error processing blocks changes: $e');
        }
      }, onError: (error) {
        debugPrint('Error in blocks listener: $error');
        // Handle missing index errors gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('missing')) {
          debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
        }
      });

      // Initial load from SQLite
      final allSocieties = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, name FROM societies ORDER BY name'
            : 'SELECT id, name FROM societies WHERE company_id = ? ORDER BY name',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],
        readsFrom: {widget.db.societies},
      ).get();

      if (mounted) {
        setState(() {
          _societies = allSocieties.map((r) => {
            'id': r.data['id'] as String,
            'name': (r.data['name']?.toString()) ?? '',
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize Firestore listeners: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadBlocksForSelectedSociety() async {
    if (_selectedSocietyId == null) {
      if (!mounted) return;
      setState(() => _blocks = []);
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    final blocks = await widget.db.customSelect(
      isSuperAdmin
          ? 'SELECT id, society_id, name FROM blocks WHERE society_id = ? ORDER BY name'
          : 'SELECT id, society_id, name FROM blocks WHERE society_id = ? AND company_id = ? ORDER BY name',
      variables: isSuperAdmin
          ? [d.Variable.withString(_selectedSocietyId!)]
          : [d.Variable.withString(_selectedSocietyId!), d.Variable.withString(companyId!)],
      readsFrom: {widget.db.blocks},
    ).get();

    if (!mounted) return;
    setState(() {
      _blocks = blocks.map((r) => {
        'id': r.data['id'] as String,
        'society_id': (r.data['society_id']?.toString()) ?? '',
        'name': (r.data['name']?.toString()) ?? '',
      }).toList();
    });
  }

  Future<void> _addSociety() async {
    final name = _societyNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a society name'), backgroundColor: Colors.red),
      );
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    try {
      // Generate ID
      final id = 'soc_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Save to SQLite first
      await widget.db.into(widget.db.societies).insertOnConflictUpdate(
        SocietiesCompanion(
          id: d.Value(id),
          name: d.Value(name),
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          metadata: const d.Value(null),
          updatedAt: d.Value(nowIso),
        ),
      );

      // Sync to Firestore
      if (Firebase.apps.isNotEmpty) {
        await FirestoreSyncService().syncDocument(
          collection: 'societies',
          documentId: id,
          data: {
            'id': id,
            'name': name,
            'companyId': isSuperAdmin ? null : companyId,
            'metadata': null,
            'updatedAt': nowIso,
          },
          merge: true,
        );
      }

      _societyNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error adding society: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding society: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addBlock() async {
    if (_selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a society first'), backgroundColor: Colors.red),
      );
      return;
    }

    final name = _blockNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a block name'), backgroundColor: Colors.red),
      );
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);

    try {
      // Generate ID
      final id = 'blk_${_selectedSocietyId}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Save to SQLite first
      await widget.db.into(widget.db.blocks).insertOnConflictUpdate(
        BlocksCompanion(
          id: d.Value(id),
          societyId: d.Value(_selectedSocietyId!),
          name: d.Value(name),
          companyId: isSuperAdmin ? const d.Value.absent() : d.Value(companyId),
          metadata: const d.Value(null),
          updatedAt: d.Value(nowIso),
        ),
      );

      // Sync to Firestore
      if (Firebase.apps.isNotEmpty) {
        await FirestoreSyncService().syncDocument(
          collection: 'blocks',
          documentId: id,
          data: {
            'id': id,
            'societyId': _selectedSocietyId!,
            'name': name,
            'companyId': isSuperAdmin ? null : companyId,
            'metadata': null,
            'updatedAt': nowIso,
          },
          merge: true,
        );
      }

      _blockNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error adding block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSociety(String societyId) async {
    // Check if society has active files or properties
    final filesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM files_table WHERE society_id = ?',
      variables: [d.Variable.withString(societyId)],
      readsFrom: {widget.db.filesTable},
    ).getSingle();

    final propertiesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM properties WHERE society_id = ?',
      variables: [d.Variable.withString(societyId)],
      readsFrom: {widget.db.properties},
    ).getSingle();

    final files = filesCount.read<int>('count') ?? 0;
    final properties = propertiesCount.read<int>('count') ?? 0;

    if (files > 0 || properties > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning: Active Records Found'),
          content: Text(
            'This society has $files file(s) and $properties property(ies) linked to it.\n\n'
            'Deleting this society will also delete all its blocks. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Society'),
          content: const Text('Are you sure you want to delete this society? All its blocks will also be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      // Delete from Firestore first (before SQLite to preserve block IDs)
      if (Firebase.apps.isNotEmpty) {
        // Delete all blocks for this society first from Firestore
        final blocksSnapshot = await FirebaseFirestore.instance
            .collection('blocks')
            .where('societyId', isEqualTo: societyId)
            .get();

        for (final blockDoc in blocksSnapshot.docs) {
          await FirestoreSyncService().deleteDocument(
            collection: 'blocks',
            documentId: blockDoc.id,
          );
        }

        await FirestoreSyncService().deleteDocument(
          collection: 'societies',
          documentId: societyId,
        );
      }

      // Delete from SQLite (blocks will be deleted by the Firestore listener)
      await widget.db.customStatement('DELETE FROM blocks WHERE society_id = ?', [societyId]);
      await widget.db.customStatement('DELETE FROM societies WHERE id = ?', [societyId]);

      // Clear selection if deleted society was selected
      if (_selectedSocietyId == societyId) {
        setState(() {
          _selectedSocietyId = null;
          _blocks = [];
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error deleting society: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting society: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    // Check if block has active files or properties
    final filesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM files_table WHERE block_id = ?',
      variables: [d.Variable.withString(blockId)],
      readsFrom: {widget.db.filesTable},
    ).getSingle();

    final propertiesCount = await widget.db.customSelect(
      'SELECT COUNT(*) AS count FROM properties WHERE block_id = ?',
      variables: [d.Variable.withString(blockId)],
      readsFrom: {widget.db.properties},
    ).getSingle();

    final files = filesCount.read<int>('count') ?? 0;
    final properties = propertiesCount.read<int>('count') ?? 0;

    if (files > 0 || properties > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning: Active Records Found'),
          content: Text(
            'This block has $files file(s) and $properties property(ies) linked to it.\n\n'
            'Are you sure you want to delete this block?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Block'),
          content: const Text('Are you sure you want to delete this block?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      // Delete from SQLite
      await widget.db.customStatement('DELETE FROM blocks WHERE id = ?', [blockId]);

      // Delete from Firestore
      if (Firebase.apps.isNotEmpty) {
        await FirestoreSyncService().deleteDocument(
          collection: 'blocks',
          documentId: blockId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error deleting block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildProfileField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final companyName = _currentUser?['company_name']?.toString() ?? 
                       _currentUser?['companyName']?.toString() ?? 
                       'N/A';
    final fullName = _currentUser?['name']?.toString() ?? 
                    _currentUser?['full_name']?.toString() ?? 
                    _currentUser?['fullName']?.toString() ?? 
                    'N/A';
    final phone = _currentUser?['phone']?.toString() ?? 
                 _currentUser?['mobile']?.toString() ?? 
                 'N/A';
    final email = _currentUser?['email']?.toString() ?? 
                 _currentUser?['gmail']?.toString() ?? 
                 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFFF6B35),
      ),
      body: Column(
        children: [
          // Profile Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFF6B35).withOpacity(0.1),
                  const Color(0xFF4A90E2).withOpacity(0.1),
                ],
              ),
            ),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFFF6B35),
                          child: Text(
                            fullName.isNotEmpty && fullName != 'N/A' 
                                ? fullName[0].toUpperCase() 
                                : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Profile',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildProfileField('Company Name', companyName),
                              const SizedBox(height: 12),
                              _buildProfileField('Full Name', fullName),
                              const SizedBox(height: 12),
                              _buildProfileField('Phone', phone),
                              const SizedBox(height: 12),
                              _buildProfileField('Email', email),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // System Config Section (Societies & Blocks)
          Expanded(
            child: Row(
              children: [
                // Left side - Societies
                Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Societies',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _societyNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Society Name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addSociety(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _addSociety,
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _societies.isEmpty
                        ? const Center(child: Text('No societies found. Add one to get started.'))
                        : ListView.builder(
                            itemCount: _societies.length,
                            itemBuilder: (context, index) {
                              final society = _societies[index];
                              final isSelected = _selectedSocietyId == society['id'];
                              return ListTile(
                                title: Text(society['name'] ?? ''),
                                selected: isSelected,
                                selectedTileColor: const Color(0xFFFF6B35).withOpacity(0.1),
                                onTap: () {
                                  setState(() {
                                    _selectedSocietyId = society['id'];
                                  });
                                  _loadBlocksForSelectedSociety();
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteSociety(society['id']),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Right side - Blocks
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Blocks',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (_selectedSocietyId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'Please select a society to manage its blocks',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _blockNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Block Name',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onSubmitted: (_) => _addBlock(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _addBlock,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF6B35),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _selectedSocietyId == null
                        ? const Center(child: Text('Select a society to view its blocks'))
                        : _blocks.isEmpty
                            ? const Center(child: Text('No blocks found for this society. Add one to get started.'))
                            : ListView.builder(
                                itemCount: _blocks.length,
                                itemBuilder: (context, index) {
                                  final block = _blocks[index];
                                  return ListTile(
                                    title: Text(block['name'] ?? ''),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteBlock(block['id']),
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
            ),
          ),
        ],
      ),
    );
  }
}

