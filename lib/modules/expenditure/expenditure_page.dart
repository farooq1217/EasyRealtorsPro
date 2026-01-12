import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
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
import '../../core/services/auth_service.dart';
import '../../core/models/expenditure_model.dart';
import '../../shimmer_widgets.dart';
import '../../professional_reports.dart';
import '../../core/app_utils.dart';
import '../../core/shared_utils.dart';
import '../../core/services/firestore_cache_service.dart';
import '../../core/services/permission_helper.dart' show PermissionHelper;
import '../../core/services/app_storage.dart' show AppStorage;
import '../../core/services/firestore_thread_helper.dart';

// Helper function for formatting month title
String _formatMonthTitle(String officeMonth) {
  try {
    final dt = DateTime.parse('$officeMonth-01');
    return DateFormat('MMM yyyy').format(dt);
  } catch (_) {
    return officeMonth;
  }
}

class ExpenditurePage extends StatefulWidget {
  final AppDatabase db;
  const ExpenditurePage({super.key, required this.db});

  @override
  State<ExpenditurePage> createState() => _ExpenditurePageState();
}

class _ExpenditurePageState extends State<ExpenditurePage> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _currentUser;
  String _currentOfficeMonth = DateFormat('yyyy-MM').format(DateTime.now());

  StreamSubscription<QuerySnapshot>? _expendituresSub;
  StreamSubscription<QuerySnapshot>? _projectsSub;
  StreamSubscription<QuerySnapshot>? _projectExpendituresSub; // Separate listener for project-type expenditures
  Timer? _dashboardReloadTimer;

  Future<void> _expApplyChain = Future.value();
  Future<void> _projApplyChain = Future.value();

  double _officeTotal = 0;
  List<_ExpenditureProjectRow> _runningProjects = [];
  int _closedProjectsCount = 0;

  // Tab controller for professional TabBar
  late TabController _tabController;
  String _selectedTab = 'Office Expense'; // 'Office Expense' or 'Projects'
  
  // Lazy loading state for tabs
  final Set<int> _loadedTabs = {0}; // Start with first tab loaded
  
  // Search and pagination state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, int> _tabPages = {'Office Expense': 0, 'Projects': 0};
  final Map<String, ScrollController> _tabScrollControllers = {};
  static const int _itemsPerPage = 100; // Items per page (50-200 range)
  
  // Data for Office Expense tab - now using categories
  final List<_ExpenditureCategoryRow> _officeCategories = [];
  final Map<String, Map<String, dynamic>> _creatorLookup = {};
  bool _loadingMoreOffice = false;
  bool _hasMoreOffice = true;
  
  // Data for Projects tab
  final List<_ExpenditureProjectRow> _closedProjects = [];
  bool _loadingMoreProjects = false;
  bool _hasMoreProjects = true;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Initialize scroll controllers for both tabs
    _tabScrollControllers['Office Expense'] = ScrollController()..addListener(() => _onTabScroll('Office Expense'));
    _tabScrollControllers['Projects'] = ScrollController()..addListener(() => _onTabScroll('Projects'));
    
    // Set initial tab to Office Expense
    _tabController.index = 0;
    _loadedTabs.add(0);
    
    _searchController.addListener(_onSearchChanged);
    
    Future.microtask(() async {
      await _loadCurrentUser();
      await _ensureTables();
      await _startFirestoreListenersIfNeeded();
      await _loadCreatorLookup();
      await _loadOfficeCategories(reset: true);
      await _loadClosedProjects(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabScrollControllers.values.forEach((controller) => controller.dispose());
    _expendituresSub?.cancel();
    _projectsSub?.cancel();
    _projectExpendituresSub?.cancel();
    _dashboardReloadTimer?.cancel();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final newTab = _tabController.index == 0 ? 'Office Expense' : 'Projects';
      if (_selectedTab != newTab) {
        setState(() {
          _selectedTab = newTab;
          // Reset pagination for the new tab
          _tabPages[_selectedTab] = 0;
        });
        // Mark tab as loaded
        _loadedTabs.add(_tabController.index);
        // Reload data when switching tabs if needed
        if (_selectedTab == 'Office Expense' && _officeCategories.isEmpty) {
          _loadOfficeCategories(reset: true);
        } else if (_selectedTab == 'Projects' && _closedProjects.isEmpty) {
          _loadClosedProjects(reset: true);
        }
      }
    }
  }
  
  void _onTabScroll(String tabType) {
    final controller = _tabScrollControllers[tabType];
    if (controller != null && controller.hasClients && controller.position.pixels > 0) {
      final maxScroll = controller.position.maxScrollExtent;
      final currentScroll = controller.position.pixels;
      // Load more when 80% scrolled
      if (currentScroll >= maxScroll * 0.8) {
        if (tabType == 'Office Expense' && !_loadingMoreOffice && _hasMoreOffice) {
          _loadOfficeCategories(reset: false);
        } else if (tabType == 'Projects' && !_loadingMoreProjects && _hasMoreProjects) {
          _loadClosedProjects(reset: false);
        }
      }
    }
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _scheduleDashboardReload() {
    _dashboardReloadTimer?.cancel();
    _dashboardReloadTimer = Timer(const Duration(milliseconds: 350), () {
      // Ensure Timer callback runs on platform thread for Windows
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await _loadDashboard();
          if (mounted && _selectedTab == 'Office Expense') {
            await _loadOfficeCategories(reset: true);
          } else if (mounted && _selectedTab == 'Projects') {
            await _loadClosedProjects(reset: true);
          }
        } catch (_) {}
      });
    });
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

  Future<void> _startFirestoreListenersIfNeeded() async {
    if (_currentUser == null) return;
    if (Firebase.apps.isEmpty) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    if (isAgent) return;

    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;

    _expendituresSub?.cancel();
    _projectsSub?.cancel();
    _projectExpendituresSub?.cancel();

    // Use .where() method for strict filtering at Firestore level
    // Office expenses listener - filter by kind='office' using .where()
    Query expQuery = FirebaseFirestore.instance.collection('expenditures')
        .where('kind', isEqualTo: 'office');
    
    // Project expenses listener - filter by kind='project' using .where()
    Query projectExpQuery = FirebaseFirestore.instance.collection('expenditures')
        .where('kind', isEqualTo: 'project');
    
    // Projects listener - sync all types (both 'office' and 'project') for both tabs
    Query projQuery = FirebaseFirestore.instance.collection('expenditure_projects');
    
    if (!isSuperAdmin) {
      // Use .where() for company filtering
      expQuery = expQuery.where('companyId', isEqualTo: companyId);
      projectExpQuery = projectExpQuery.where('companyId', isEqualTo: companyId);
      projQuery = projQuery.where('companyId', isEqualTo: companyId);
    }

    // Wrap entire callback in Future.microtask to ensure platform thread execution on Windows
    _expendituresSub = expQuery.snapshots().listen((snap) {
      // Immediately schedule on platform thread using microtask
      Future.microtask(() {
        // Then wrap UI updates in addPostFrameCallback
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            final changes = List<DocumentChange>.from(snap.docChanges);
            if (changes.isEmpty) return;

            _expApplyChain = _expApplyChain.then((_) async {
              await _applyExpenditureChangesChunked(changes);
              // Update UI on main thread - reload data and call setState inside addPostFrameCallback
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                try {
                  await _loadDashboard();
                  if (mounted && _selectedTab == 'Office Expense') {
                    await _loadOfficeCategories(reset: true);
                  }
                } catch (e) {
                  debugPrint('Error reloading after expenditure changes: $e');
                }
              });
            });
          } catch (e) {
            debugPrint('Error in expenditures listener callback: $e');
          }
        });
      });
    }, onError: (error) {
      Future.microtask(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            debugPrint('Firestore listener error (expenditures): $error');
            // Handle missing index errors gracefully
            final errorStr = error.toString().toLowerCase();
            if (errorStr.contains('index') || errorStr.contains('missing')) {
              debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
            }
          } catch (e) {
            debugPrint('Error in expenditures error handler: $e');
          }
        });
      });
    });

    // Wrap entire callback in Future.microtask to ensure platform thread execution on Windows
    _projectsSub = projQuery.snapshots().listen((snap) {
      // Immediately schedule on platform thread using microtask
      Future.microtask(() {
        // Then wrap UI updates in addPostFrameCallback
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            final changes = List<DocumentChange>.from(snap.docChanges);
            if (changes.isEmpty) return;

            _projApplyChain = _projApplyChain.then((_) async {
              await _applyProjectChangesChunked(changes);
              // Update UI on main thread - reload data and call setState inside addPostFrameCallback
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                try {
                  await _loadDashboard();
                  if (mounted && _selectedTab == 'Office Expense') {
                    await _loadOfficeCategories(reset: true);
                  } else if (mounted && _selectedTab == 'Projects') {
                    await _loadClosedProjects(reset: true);
                  }
                } catch (e) {
                  debugPrint('Error reloading after project changes: $e');
                }
              });
            });
          } catch (e) {
            debugPrint('Error in projects listener callback: $e');
          }
        });
      });
    }, onError: (error) {
      Future.microtask(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            debugPrint('Firestore listener error (projects): $error');
            // Handle missing index errors gracefully
            final errorStr = error.toString().toLowerCase();
            if (errorStr.contains('index') || errorStr.contains('missing')) {
              debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
            }
          } catch (e) {
            debugPrint('Error in projects error handler: $e');
          }
        });
      });
    });

    // Separate listener for project-type expenditures using .where() filtering
    // Wrap entire callback in Future.microtask to ensure platform thread execution on Windows
    _projectExpendituresSub = projectExpQuery.snapshots().listen((snap) {
      // Immediately schedule on platform thread using microtask
      Future.microtask(() {
        // Then wrap UI updates in addPostFrameCallback
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            final changes = List<DocumentChange>.from(snap.docChanges);
            if (changes.isEmpty) return;

            _expApplyChain = _expApplyChain.then((_) async {
              await _applyExpenditureChangesChunked(changes);
              // Update UI on main thread - reload data and call setState inside addPostFrameCallback
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                try {
                  await _loadDashboard();
                  if (mounted && _selectedTab == 'Projects') {
                    await _loadClosedProjects(reset: true);
                  }
                } catch (e) {
                  debugPrint('Error reloading after project expenditure changes: $e');
                }
              });
            });
          } catch (e) {
            debugPrint('Error in project expenditures listener callback: $e');
          }
        });
      });
    }, onError: (error) {
      Future.microtask(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            debugPrint('Firestore listener error (project expenditures): $error');
            // Handle missing index errors gracefully
            final errorStr = error.toString().toLowerCase();
            if (errorStr.contains('index') || errorStr.contains('missing')) {
              debugPrint('Firestore index may be missing. This is non-fatal - continuing with limited functionality.');
            }
          } catch (e) {
            debugPrint('Error in project expenditures error handler: $e');
          }
        });
      });
    });
  }

  Future<void> _applyExpenditureChangesChunked(List<DocumentChange> changes) async {
    const chunkSize = 50;
    for (var start = 0; start < changes.length; start += chunkSize) {
      final end = (start + chunkSize) > changes.length ? changes.length : (start + chunkSize);
      final chunk = changes.sublist(start, end);

      try {
        await widget.db.batch((batch) {
          for (final change in chunk) {
            final doc = change.doc;
            final nowIso = DateTime.now().toUtc().toIso8601String();
            if (change.type == DocumentChangeType.removed) {
              batch.customStatement(
                "UPDATE expenditures SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                [nowIso, doc.id],
              );
              continue;
            }

            final data = (doc.data() as Map<String, dynamic>);
            final id = (data['id'] ?? doc.id).toString();
            final cid = (data['companyId'] ?? data['company_id'])?.toString();
            final createdBy = (data['created_by'] ?? data['createdBy'] ?? data['creator_user_id'])?.toString();
            // FALLBACK: If kind is missing, default to 'office' so it shows in Office Expense tab
            var kind = (data['kind'] ?? data['type'])?.toString();
            if (kind == null || kind.isEmpty) {
              kind = 'office'; // Default fallback to ensure data is visible
            }
            final projectId = (data['projectId'] ?? data['project_id'])?.toString();
            final officeMonth = (data['officeMonth'] ?? data['office_month'])?.toString();
            final category = (data['category'] ?? data['expenseCategory'] ?? data['expense_category'])?.toString();
            final date = (data['date'] ?? '').toString();
            final desc = (data['description'] ?? '').toString();
            final rawAmount = data['amount'];
            final amount = (rawAmount is num) ? rawAmount.toDouble() : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
            final updatedAt = (data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();

            batch.customStatement(
              'INSERT OR REPLACE INTO expenditures (id, company_id, created_by, kind, project_id, office_month, category, date, description, amount, status, is_active, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, \'active\'), COALESCE(?, 1), ?)',
              [id, cid, createdBy, kind, projectId, officeMonth, category, date, desc, amount, data['status'], data['is_active'] ?? data['isActive'], updatedAt],
            );
          }
        });
      } catch (_) {}

      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _applyProjectChangesChunked(List<DocumentChange> changes) async {
    const chunkSize = 50;
    for (var start = 0; start < changes.length; start += chunkSize) {
      final end = (start + chunkSize) > changes.length ? changes.length : (start + chunkSize);
      final chunk = changes.sublist(start, end);

      try {
        await widget.db.batch((batch) {
          for (final change in chunk) {
            final doc = change.doc;
            final nowIso = DateTime.now().toUtc().toIso8601String();
            if (change.type == DocumentChangeType.removed) {
              batch.customStatement(
                "UPDATE expenditure_projects SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?",
                [nowIso, doc.id],
              );
              continue;
            }

            final data = (doc.data() as Map<String, dynamic>);
            final id = (data['id'] ?? doc.id).toString();
            final cid = (data['companyId'] ?? data['company_id'])?.toString();
            final createdBy = (data['created_by'] ?? data['createdBy'] ?? data['creator_user_id'])?.toString();
            final name = (data['name'] ?? '').toString();
            final status = (data['status'] ?? 'running').toString();
            // FALLBACK: If type is missing, default to 'project' for Projects tab, or 'office' if name suggests office category
            var projectType = (data['type'] ?? '').toString();
            if (projectType.isEmpty) {
              // Try to infer from name or default to 'project'
              projectType = 'project'; // Default to project type
            }
            final createdAt = (data['createdAt'] ?? data['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();
            final updatedAt = (data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString();
            final closedAt = (data['closedAt'] ?? data['closed_at'])?.toString();

            batch.customStatement(
              'INSERT OR REPLACE INTO expenditure_projects (id, company_id, created_by, name, status, is_active, type, created_at, updated_at, closed_at) VALUES (?, ?, ?, ?, ?, COALESCE(?, 1), ?, ?, ?, ?)',
              [id, cid, createdBy, name, status, data['is_active'] ?? data['isActive'] ?? 1, projectType, createdAt, updatedAt, closedAt],
            );
          }
        });
      } catch (_) {}

      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _ensureTables() async {
    try {
      await widget.db.customStatement('''
        CREATE TABLE IF NOT EXISTS expenditures (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          created_by TEXT,
          kind TEXT,
          project_id TEXT,
          category_id TEXT,
          office_month TEXT,
          category TEXT,
          date TEXT NOT NULL,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await widget.db.customStatement('''
        CREATE TABLE IF NOT EXISTS expenditure_projects (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          created_by TEXT,
          name TEXT NOT NULL,
          status TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'project',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          closed_at TEXT
        )
      ''');


      try {
        final columns = await widget.db.customSelect('PRAGMA table_info(expenditures)').get();
        bool hasCompanyId = false;
        bool hasUpdatedAt = false;
        bool hasKind = false;
        bool hasProjectId = false;
        bool hasCategoryId = false;
        bool hasOfficeMonth = false;
        bool hasCreatedBy = false;
        bool hasCategory = false;
        for (final row in columns) {
          final name = row.data['name']?.toString();
          if (name == 'company_id') hasCompanyId = true;
          if (name == 'updated_at') hasUpdatedAt = true;
          if (name == 'kind') hasKind = true;
          if (name == 'project_id') hasProjectId = true;
          if (name == 'category_id') hasCategoryId = true;
          if (name == 'office_month') hasOfficeMonth = true;
          if (name == 'created_by') hasCreatedBy = true;
          if (name == 'category') hasCategory = true;
        }
        if (!hasCompanyId) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN company_id TEXT');
        }
        if (!hasKind) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN kind TEXT');
        }
        if (!hasProjectId) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN project_id TEXT');
        }
        if (!hasCategoryId) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN category_id TEXT');
        }
        if (!hasOfficeMonth) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN office_month TEXT');
        }
        if (!hasUpdatedAt) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN updated_at TEXT');
        }
        if (!hasCreatedBy) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN created_by TEXT');
        }
        if (!hasCategory) {
          await widget.db.customStatement('ALTER TABLE expenditures ADD COLUMN category TEXT');
        }
      } catch (_) {}

      try {
        final columns = await widget.db.customSelect('PRAGMA table_info(expenditure_projects)').get();
        bool hasCreatedBy = false;
        bool hasType = false;
        for (final row in columns) {
          final name = row.data['name']?.toString();
          if (name == 'created_by') hasCreatedBy = true;
          if (name == 'type') hasType = true;
        }
        if (!hasCreatedBy) {
          await widget.db.customStatement('ALTER TABLE expenditure_projects ADD COLUMN created_by TEXT');
        }
        if (!hasType) {
          await widget.db.customStatement("ALTER TABLE expenditure_projects ADD COLUMN type TEXT NOT NULL DEFAULT 'project'");
          // Migrate existing expenditure_categories to expenditure_projects
          try {
            final categories = await widget.db.customSelect('SELECT * FROM expenditure_categories').get();
            for (final cat in categories) {
              final data = cat.data;
              await widget.db.customStatement(
                'INSERT OR REPLACE INTO expenditure_projects (id, company_id, created_by, name, status, type, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [
                  data['id'],
                  data['company_id'],
                  data['created_by'],
                  data['name'],
                  data['status'] ?? 'Active',
                  'office',
                  data['created_at'],
                  data['updated_at'],
                ],
              );
            }
          } catch (_) {}
        }
        // Ensure all existing records have type set (default to 'project' for existing records without type)
        try {
          await widget.db.customStatement("UPDATE expenditure_projects SET type = 'project' WHERE type IS NULL OR type = '' OR type NOT IN ('project', 'office')");
        } catch (_) {}
      } catch (_) {}
    } catch (e) {
      debugPrint('Error ensuring expenditure tables: $e');
    }
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();

    if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
      if (mounted) {
        setState(() {
          _officeTotal = 0;
          _runningProjects = [];
          _closedProjectsCount = 0;
          _loading = false;
        });
      }
      return;
    }

    try {
      final officeSumRow = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT COALESCE(SUM(amount), 0) AS total FROM expenditures WHERE kind = ? AND office_month = ?'
            : (isAgent
                ? 'SELECT COALESCE(SUM(amount), 0) AS total FROM expenditures WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND kind = ? AND office_month = ?'
                : 'SELECT COALESCE(SUM(amount), 0) AS total FROM expenditures WHERE company_id = ? AND kind = ? AND office_month = ?'),
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
          d.Variable.withString('office'),
          d.Variable.withString(_currentOfficeMonth),
        ],
      ).getSingle();

      final officeTotal = (officeSumRow.data['total'] as num?)?.toDouble() ?? 0;

      final projectsRes = await widget.db.customSelect(
        isSuperAdmin
            ? """
              SELECT p.id, p.name, p.status,
                     COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project'
              WHERE p.status = 'running'
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
            """
            : (isAgent
                ? """
              SELECT p.id, p.name, p.status,
                     COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project' AND e.company_id = p.company_id AND (e.created_by = ? OR e.created_by = ?)
              WHERE p.company_id = ? AND p.status = 'running' AND (p.created_by = ? OR p.created_by = ?)
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
            """
                : """
              SELECT p.id, p.name, p.status,
                     COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project' AND e.company_id = p.company_id
              WHERE p.company_id = ? AND p.status = 'running'
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
            """),
        variables: isSuperAdmin
            ? []
            : [
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent)
                  d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent)
                  d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
              ],
      ).get();

      final runningProjects = projectsRes
          .map(
            (r) => _ExpenditureProjectRow(
              id: r.data['id']?.toString() ?? '',
              name: r.data['name']?.toString() ?? '',
              status: r.data['status']?.toString() ?? 'Active',
              total: (r.data['total'] as num?)?.toDouble() ?? 0,
              type: 'project', // Explicitly set type for defensive filtering
            ),
          )
          .where((proj) => proj.type == 'project') // Defensive filter: ensure only projects
          .toList();

      final closedCountRow = await widget.db.customSelect(
        isSuperAdmin
            ? "SELECT COUNT(*) AS c FROM expenditure_projects WHERE type = 'project' AND status = 'closed'"
            : (isAgent
                ? "SELECT COUNT(*) AS c FROM expenditure_projects WHERE type = 'project' AND company_id = ? AND (created_by = ? OR created_by = ?) AND status = 'closed'"
                : "SELECT COUNT(*) AS c FROM expenditure_projects WHERE type = 'project' AND company_id = ? AND status = 'closed'"),
        variables: isSuperAdmin
            ? []
            : [
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent)
                  d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
              ],
      ).getSingle();

      final closedCount = (closedCountRow.data['c'] as num?)?.toInt() ?? 0;

      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _officeTotal = officeTotal;
          _runningProjects = runningProjects;
          _closedProjectsCount = closedCount;
          _loading = false;
        });
      });
    } catch (e) {
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenditure dashboard: $e')),
        );
      });
    }
  }

  void _syncToFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    // Ensure Firestore operations run on platform thread for Windows compatibility
    // Use FirestoreThreadHelper for tab filtering as requested
    FirestoreThreadHelper.executeOnPlatformThread(() async {
      try {
        if (Firebase.apps.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(docId)
              .set(data, SetOptions(merge: true));
          FirestoreCacheService().invalidateCache(collection, docId);
        }
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
      }
    });
  }

  Future<void> _loadCreatorLookup() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL)'
            : 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL) AND (company_id = ? OR company_id IS NULL)',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      _creatorLookup.clear();
      for (final row in res) {
        final data = row.data;
        final id = data['id']?.toString();
        final uid = data['user_id']?.toString();
        final m = {
          'name': data['name'],
          'username': data['username'],
          'status': data['status'],
        };
        if (id != null && id.trim().isNotEmpty) _creatorLookup[id.trim()] = m;
        if (uid != null && uid.trim().isNotEmpty) _creatorLookup[uid.trim()] = m;
      }
    } catch (_) {}
  }

  String _creatorLabel(String? createdBy) {
    final key = (createdBy ?? '').trim();
    if (key.isEmpty) return '';
    final u = _creatorLookup[key];
    if (u == null) return key;
    final name = (u['name'] ?? u['username'] ?? key).toString();
    final status = (u['status'] ?? 'active').toString();
    return status == 'active' ? name : '$name (Inactive)';
  }

  Future<void> _loadOfficeCategories({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _loading = true;
          _loadingMoreOffice = false;
          _hasMoreOffice = true;
          _officeCategories.clear();
          _tabPages['Office Expense'] = 0;
        });
      });
    } else {
      if (_loadingMoreOffice || !_hasMoreOffice) return;
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loadingMoreOffice = true);
      });
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMoreOffice = false;
        });
      }
      return;
    }

    try {
      final offset = reset ? 0 : _officeCategories.length;
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? """
              SELECT c.id, c.name, c.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects c
              LEFT JOIN expenditures e
                ON e.category_id = c.id AND e.kind = 'office'
              WHERE c.type = 'office'
              GROUP BY c.id, c.name, c.status
              ORDER BY c.updated_at DESC
              LIMIT ? OFFSET ?
            """
            : (isAgent
                ? """
              SELECT c.id, c.name, c.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects c
              LEFT JOIN expenditures e
                ON e.category_id = c.id AND e.kind = 'office' AND e.company_id = c.company_id AND (e.created_by = ? OR e.created_by = ?)
              WHERE c.type = 'office' AND c.company_id = ? AND (c.created_by = ? OR c.created_by = ?)
              GROUP BY c.id, c.name, c.status
              ORDER BY c.updated_at DESC
              LIMIT ? OFFSET ?
            """
                : """
              SELECT c.id, c.name, c.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects c
              LEFT JOIN expenditures e
                ON e.category_id = c.id AND e.kind = 'office' AND e.company_id = c.company_id
              WHERE c.type = 'office' AND c.company_id = ?
              GROUP BY c.id, c.name, c.status
              ORDER BY c.updated_at DESC
              LIMIT ? OFFSET ?
            """),
        variables: isSuperAdmin
            ? [
                d.Variable.withInt(_itemsPerPage),
                d.Variable.withInt(offset),
              ]
            : [
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent) d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent) d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
                d.Variable.withInt(_itemsPerPage),
                d.Variable.withInt(offset),
              ],
      ).get();

      final categories = res
          .map(
            (r) => _ExpenditureCategoryRow(
              id: r.data['id']?.toString() ?? '',
              name: r.data['name']?.toString() ?? '',
              status: r.data['status']?.toString() ?? 'Active',
              total: (r.data['total'] as num?)?.toDouble() ?? 0,
              // FALLBACK: If type is missing in DB, default to 'office' so it shows in Office Expense tab
              type: (r.data['type']?.toString() ?? 'office'), // Default to 'office' if missing
            ),
          )
          .where((cat) => cat.type == 'office') // Strict filter: ensure only office categories
          .toList();

      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (reset) {
            _officeCategories.clear();
          }
          _officeCategories.addAll(categories);
          _hasMoreOffice = categories.length == _itemsPerPage;
          _loading = false;
          _loadingMoreOffice = false;
        });
      });
    } catch (e) {
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadingMoreOffice = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading office expenses: $e')),
        );
      });
    }
  }

  Future<void> _loadClosedProjects({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _loading = true;
          _loadingMoreProjects = false;
          _hasMoreProjects = true;
          _closedProjects.clear();
          _tabPages['Projects'] = 0;
        });
      });
    } else {
      if (_loadingMoreProjects || !_hasMoreProjects) return;
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loadingMoreProjects = true);
      });
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _loadingMoreProjects = false;
          });
        });
      }
      return;
    }

    try {
      final offset = reset ? 0 : _closedProjects.length;
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? """
              SELECT p.id, p.name, p.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project'
              WHERE p.type = 'project'
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
              LIMIT ? OFFSET ?
            """
            : (isAgent
                ? """
              SELECT p.id, p.name, p.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project' AND e.company_id = p.company_id AND (e.created_by = ? OR e.created_by = ?)
              WHERE p.type = 'project' AND p.company_id = ? AND (p.created_by = ? OR p.created_by = ?)
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
              LIMIT ? OFFSET ?
            """
                : """
              SELECT p.id, p.name, p.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project' AND e.company_id = p.company_id
              WHERE p.type = 'project' AND p.company_id = ?
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
              LIMIT ? OFFSET ?
            """),
        variables: isSuperAdmin
            ? [
                d.Variable.withInt(_itemsPerPage),
                d.Variable.withInt(offset),
              ]
            : [
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent) d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent) d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
                d.Variable.withInt(_itemsPerPage),
                d.Variable.withInt(offset),
              ],
      ).get();

      final projects = res
          .map(
            (r) => _ExpenditureProjectRow(
              id: r.data['id']?.toString() ?? '',
              name: r.data['name']?.toString() ?? '',
              status: r.data['status']?.toString() ?? 'Active',
              total: (r.data['total'] as num?)?.toDouble() ?? 0,
              // FALLBACK: If type is missing in DB, default to 'project' so it shows in Projects tab
              type: (r.data['type']?.toString() ?? 'project'), // Default to 'project' if missing
            ),
          )
          .where((proj) => proj.type == 'project') // Defensive filter: ensure only projects
          .toList();

      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (reset) {
            _closedProjects.clear();
          }
          _closedProjects.addAll(projects);
          _hasMoreProjects = projects.length == _itemsPerPage;
          _loading = false;
          _loadingMoreProjects = false;
        });
      });
    } catch (e) {
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadingMoreProjects = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading closed projects: $e')),
        );
      });
    }
  }

  Future<void> _deleteProject(String projectId, String projectName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "$projectName"? This will permanently delete the project and all its expense entries. This action cannot be undone.'),
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

    if (confirm != true) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      // Soft delete all expenses for this project
      await widget.db.customStatement(
        isSuperAdmin
            ? "UPDATE expenditures SET status = 'archived', is_active = 0, updated_at = ? WHERE project_id = ? AND kind = ?"
            : "UPDATE expenditures SET status = 'archived', is_active = 0, updated_at = ? WHERE company_id = ? AND project_id = ? AND kind = ?",
        isSuperAdmin
            ? [nowIso, projectId, 'project']
            : [nowIso, companyId, projectId, 'project'],
      );

      // Soft delete the project
      await widget.db.customStatement(
        isSuperAdmin
            ? "UPDATE expenditure_projects SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?"
            : "UPDATE expenditure_projects SET status = 'archived', is_active = 0, updated_at = ? WHERE company_id = ? AND id = ?",
        isSuperAdmin ? [nowIso, projectId] : [nowIso, companyId, projectId],
      );

      // Soft delete in Firestore
      if (Firebase.apps.isNotEmpty) {
        try {
          // Mark all expense documents
          final expensesSnapshot = await FirebaseFirestore.instance
              .collection('expenditures')
              .where('projectId', isEqualTo: projectId)
              .get();
          
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in expensesSnapshot.docs) {
            batch.set(
              doc.reference,
              {
                'status': 'archived',
                'is_active': 0,
                'isActive': 0,
                'updated_at': nowIso,
                'deleted_at': nowIso,
              },
              SetOptions(merge: true),
            );
          }
          await batch.commit();

          // Mark project document
          await FirebaseFirestore.instance.collection('expenditure_projects').doc(projectId).set(
            {
              'status': 'archived',
              'is_active': 0,
              'isActive': 0,
              'updated_at': nowIso,
              'deleted_at': nowIso,
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          debugPrint('Error deleting from Firestore: $e');
        }
      }

      if (!mounted) return;
      await _loadClosedProjects(reset: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete project: $e')),
      );
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'expenditure')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to add expense categories')),
      );
      return;
    }

    final nameCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? categoryName;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_selectedTab == 'Office Expense' ? 'Add Expense Category' : 'Add Project'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtl,
            decoration: InputDecoration(
              labelText: _selectedTab == 'Office Expense' ? 'Category Name' : 'Project Name',
              hintText: _selectedTab == 'Office Expense' ? 'e.g., Office Supplies, Utilities' : 'e.g., Project Alpha, Project Beta',
              border: const OutlineInputBorder(),
            ),
            validator: (v) => v?.trim().isEmpty ?? true ? (_selectedTab == 'Office Expense' ? 'Category name is required' : 'Project name is required') : null,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              categoryName = nameCtl.text.trim();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              categoryName = nameCtl.text.trim();
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    // Don't dispose manually - the controller will be garbage collected
    // when the dialog widget tree is disposed. Manually disposing causes
    // issues during the closing animation.
    if (result == true && categoryName != null && categoryName!.isNotEmpty) {
      await _createCategory(categoryName!);
    }
  }

  Future<void> _createCategory(String name) async {
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company ID is required')),
      );
      return;
    }

    final createdBy = _currentUser?['id']?.toString() ?? '';
    final id = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final finalCompanyId = isSuperAdmin ? 'GLOBAL_ADMIN' : companyId!;

    try {
      // DEFAULT KIND: Detect which tab is currently active to set the correct type (0=office, 1=project)
      final finalCategoryType = _tabController.index == 0 ? 'office' : 'project';
      
      await widget.db.customStatement(
        'INSERT OR REPLACE INTO expenditure_projects (id, company_id, created_by, name, status, type, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, finalCompanyId, createdBy, name, 'Active', finalCategoryType, nowIso, nowIso],
      );

      _syncToFirestore(
        collection: 'expenditure_projects',
        docId: id,
        data: {
          'id': id,
          'companyId': finalCompanyId,
          'createdBy': createdBy,
          'created_by': createdBy,
          ...creatorFields(_currentUser),
          'name': name,
          'status': 'Active',
          'type': finalCategoryType, // DEFAULT KIND: Set based on current tab (0=office, 1=project)
          'createdAt': nowIso,
          'created_at': nowIso,
          'updatedAt': nowIso,
          'updated_at': nowIso,
        },
      );

      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadOfficeCategories(reset: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category created successfully')),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create category: $e')),
      );
    }
  }

  Future<void> _deleteOfficeCategory(String categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Are you sure you want to permanently delete this category and all its associated expenses? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;

    try {
      // Delete all expenses for this category from local DB
      await widget.db.customStatement(
        isSuperAdmin
            ? 'DELETE FROM expenditures WHERE category_id = ? AND kind = ?'
            : 'DELETE FROM expenditures WHERE company_id = ? AND category_id = ? AND kind = ?',
        isSuperAdmin ? [categoryId, 'office'] : [companyId, categoryId, 'office'],
      );

      // Delete the category from local DB
      await widget.db.customStatement(
        isSuperAdmin
            ? "DELETE FROM expenditure_projects WHERE id = ? AND type = 'office'"
            : "DELETE FROM expenditure_projects WHERE company_id = ? AND id = ? AND type = 'office'",
        isSuperAdmin ? [categoryId] : [companyId, categoryId],
      );

      // Delete from Firestore
      if (Firebase.apps.isNotEmpty) {
        try {
          final batch = FirebaseFirestore.instance.batch();
          
          // Delete all expenses in the category
          final expensesSnapshot = await FirebaseFirestore.instance
              .collection('expenditures')
              .where('category_id', isEqualTo: categoryId)
              .where('kind', isEqualTo: 'office')
              .get();
          
          for (final doc in expensesSnapshot.docs) {
            batch.delete(doc.reference);
          }
          
          // Delete category document
          await FirebaseFirestore.instance
              .collection('expenditure_projects')
              .doc(categoryId)
              .delete();
          
          await batch.commit();
        } catch (e) {
          debugPrint('Error deleting from Firestore: $e');
        }
      }

      if (!mounted) return;
      await _loadOfficeCategories(reset: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete category: $e')),
      );
    }
  }

  Future<void> _deleteOfficeExpense(String expenseId, String expenseDescription) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "$expenseDescription"? This action cannot be undone.'),
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

    if (confirm != true) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;

    try {
      // Delete from database
      await widget.db.customStatement(
        isSuperAdmin
            ? 'DELETE FROM expenditures WHERE id = ?'
            : 'DELETE FROM expenditures WHERE company_id = ? AND id = ?',
        isSuperAdmin ? [expenseId] : [companyId, expenseId],
      );

      // Delete from Firestore
      if (Firebase.apps.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('expenditures')
              .doc(expenseId)
              .delete();
        } catch (e) {
          debugPrint('Error deleting from Firestore: $e');
        }
      }

      if (!mounted) return;
      await _loadOfficeCategories(reset: true);
      await _loadDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete expense: $e')),
      );
    }
  }

  List<_ExpenditureCategoryRow> get _filteredOfficeCategories {
    // First filter: ensure only office categories (strict check)
    final officeOnly = _officeCategories.where((cat) => cat.type == 'office').toList();
    
    if (_searchQuery.isEmpty) return officeOnly;
    
    // Second filter: apply search query
    return officeOnly.where((category) {
      final name = (category.name).toLowerCase();
      if (name.contains(_searchQuery)) return true;
      
      final totalStr = category.total.toString();
      if (totalStr.contains(_searchQuery)) return true;
      
      return false;
    }).toList();
  }

  List<_ExpenditureProjectRow> get _filteredClosedProjects {
    // First filter: ensure only projects (defensive check)
    final projectsOnly = _closedProjects.where((proj) => proj.type == 'project').toList();
    
    if (_searchQuery.isEmpty) return projectsOnly;
    
    // Second filter: apply search query
    return projectsOnly.where((project) {
      final name = project.name.toLowerCase();
      if (name.contains(_searchQuery)) return true;
      
      final totalStr = project.total.toString();
      if (totalStr.contains(_searchQuery)) return true;
      
      return false;
    }).toList();
  }

  List<_ExpenditureCategoryRow> get _paginatedOfficeCategories {
    final filtered = _filteredOfficeCategories;
    // For now, return all filtered items (pagination handled by scroll)
    return filtered;
  }

  List<_ExpenditureProjectRow> get _paginatedClosedProjects {
    final filtered = _filteredClosedProjects;
    // For now, return all filtered items (pagination handled by scroll)
    return filtered;
  }

  bool _hasMoreOfficeCategories() {
    final filtered = _filteredOfficeCategories;
    final page = _tabPages['Office Expense'] ?? 0;
    return (page + 1) * _itemsPerPage < filtered.length || _hasMoreOffice;
  }

  bool _hasMoreClosedProjects() {
    final filtered = _filteredClosedProjects;
    final page = _tabPages['Projects'] ?? 0;
    return (page + 1) * _itemsPerPage < filtered.length || _hasMoreProjects;
  }

  Future<void> _showCreateProjectDialog() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'expenditure')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add projects.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final formKey = GlobalKey<FormState>();
    final defaultName = 'Project ${_runningProjects.length + _closedProjectsCount + 1}';
    final nameCtl = TextEditingController(text: defaultName);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Project'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtl,
            decoration: const InputDecoration(labelText: 'Project Name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Project name is required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;
    final finalCompanyId = isSuperAdmin ? 'GLOBAL_ADMIN' : companyId!;

    final createdBy = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? _currentUser?['id']?.toString();

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final name = nameCtl.text.trim();
    try {
      await widget.db.customStatement(
        'INSERT OR REPLACE INTO expenditure_projects (id, company_id, created_by, name, status, type, created_at, updated_at, closed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [id, finalCompanyId, createdBy, name, 'Active', 'project', nowIso, nowIso, null],
      );
      _syncToFirestore(
        collection: 'expenditure_projects',
        docId: id,
        data: {
          'id': id,
          'companyId': finalCompanyId,
          'createdBy': createdBy,
          'created_by': createdBy,
          ...creatorFields(_currentUser),
          'name': name,
          'status': 'Active',
          'type': 'project',
          'createdAt': nowIso,
          'updatedAt': nowIso,
          'closedAt': null,
        },
      );
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadDashboard();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create project: $e')));
    }
  }

  Widget _buildDashboardRow({
    required IconData icon,
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B1F24)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF4A90E2), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.grey.shade800,
                ),
              ),
            ),
            Text(
              trailing,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFF6B35),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'expenditure')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add expenses.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    final dateCtl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String selectedCategory = 'General';
    final customCategoryCtl = TextEditingController();

    Future<void> pickDate(StateSetter setLocal) async {
      final currentText = dateCtl.text.trim();
      DateTime initial = DateTime.now();
      try {
        if (currentText.isNotEmpty) initial = DateTime.parse(currentText);
      } catch (_) {}
      final picked = await showCustomDatePicker(context, initialDate: initial);
      if (picked != null) setLocal(() => dateCtl.text = DateFormat('yyyy-MM-dd').format(picked));
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                        IconButton(onPressed: () => Navigator.pop(dialogContext, false), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dateCtl,
                      readOnly: true,
                      onTap: () => pickDate(setLocal),
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtl,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                      items: const [
                        DropdownMenuItem(value: 'General', child: Text('General')),
                        DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                        DropdownMenuItem(value: 'Salaries', child: Text('Salaries')),
                        DropdownMenuItem(value: 'Fuel', child: Text('Fuel')),
                        DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                        DropdownMenuItem(value: 'Marketing', child: Text('Marketing')),
                        DropdownMenuItem(value: 'Office', child: Text('Office')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        setLocal(() => selectedCategory = v ?? 'General');
                      },
                    ),
                    if (selectedCategory == 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customCategoryCtl,
                        decoration: const InputDecoration(labelText: 'Custom Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_outlined)),
                        validator: (v) {
                          if (selectedCategory != 'Other') return null;
                          if (v == null || v.trim().isEmpty) return 'Enter category';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountCtl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(dialogContext, true);
                        },
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (saved != true) {
      dateCtl.dispose();
      descCtl.dispose();
      amountCtl.dispose();
      customCategoryCtl.dispose();
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final finalCompanyId = isSuperAdmin ? null : companyId;
    if (!isSuperAdmin && (finalCompanyId == null || finalCompanyId.isEmpty)) return;

    final createdBy = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? _currentUser?['id']?.toString();

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
    final category = (selectedCategory == 'Other' ? customCategoryCtl.text.trim() : selectedCategory).trim();
    try {
      // DEFAULT KIND: Set kind based on current tab index (0=office, 1=project)
      final expenseKind = _tabController.index == 0 ? 'office' : 'project';
      
      await widget.db.customStatement(
        'INSERT OR REPLACE INTO expenditures (id, company_id, created_by, kind, project_id, office_month, category, date, description, amount, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          finalCompanyId,
          createdBy,
          expenseKind, // DEFAULT KIND: Set based on current tab (0=office, 1=project)
          null,
          _currentOfficeMonth,
          category.isEmpty ? null : category,
          dateCtl.text.trim(),
          descCtl.text.trim(),
          amount,
          nowIso,
        ],
      );

      _syncToFirestore(
        collection: 'expenditures',
        docId: id,
        data: {
          'id': id,
          'companyId': finalCompanyId,
          'createdBy': createdBy,
          'created_by': createdBy,
          ...creatorFields(_currentUser),
          'kind': expenseKind, // DEFAULT KIND: Set based on current tab (0=office, 1=project)
          'projectId': null,
          'project_id': null,
          'officeMonth': _currentOfficeMonth,
          'office_month': _currentOfficeMonth,
          'category': category.isEmpty ? null : category,
          'date': dateCtl.text.trim(),
          'description': descCtl.text.trim(),
          'amount': amount,
          'updatedAt': nowIso,
          'updated_at': nowIso,
        },
      );
      // UI REFRESH: Use setState inside WidgetsBinding.instance.addPostFrameCallback to stop non-platform thread crash
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadOfficeCategories(reset: true);
        await _loadDashboard();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully')),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add expense: $e')),
      );
    } finally {
      dateCtl.dispose();
      descCtl.dispose();
      amountCtl.dispose();
      customCategoryCtl.dispose();
    }
  }

  Widget _buildTabContent(String tabType) {
    // Only build content if tab has been loaded (lazy loading)
    if (!_loadedTabs.contains(tabType == 'Office Expense' ? 0 : 1)) {
      return const SizedBox.shrink();
    }
    
    if (tabType == 'Office Expense') {
      return _buildOfficeExpenseTab();
    } else {
      return _buildClosedProjectsTab();
    }
  }

  Widget _buildOfficeExpenseTab() {
    final currency = NumberFormat('#,##0.00');
    final filtered = _filteredOfficeCategories;
    final paginated = _paginatedOfficeCategories;
    final scrollController = _tabScrollControllers['Office Expense'];
    
    if (_loading && _officeCategories.isEmpty) {
      return const ShimmerPageLoading(itemCount: 10);
    }
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No expense categories found',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search',
                style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }
    
    final totalAmount = filtered.fold(0.0, (sum, cat) => sum + cat.total);
    
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadOfficeCategories(reset: true),
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: paginated.length + (_hasMoreOfficeCategories() ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == paginated.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ShimmerListPlaceholder(itemCount: 3, itemHeight: 100),
                  );
                }
                final category = paginated[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
                      child: const Icon(Icons.category, color: Color(0xFF4A90E2)),
                    ),
                    title: Text(
                      category.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total: Rs ${currency.format(category.total)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Active',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rs ${currency.format(category.total)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: const Color(0xFFFF6B35),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await _deleteOfficeCategory(category.id);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  const Text('Delete Category'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OfficeExpenseCategoryPage(
                            db: widget.db,
                            categoryId: category.id,
                            categoryName: category.name,
                            currentUser: _currentUser,
                          ),
                        ),
                      );
                      await _loadOfficeCategories(reset: true);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        _ExpenseTotalBar(totalText: 'Total Office Expense: Rs ${currency.format(totalAmount)}'),
      ],
    );
  }

  Widget _buildClosedProjectsTab() {
    final currency = NumberFormat('#,##0.00');
    final filtered = _filteredClosedProjects;
    final paginated = _paginatedClosedProjects;
    final scrollController = _tabScrollControllers['Projects'];
    
    if (_loading && _closedProjects.isEmpty) {
      return const ShimmerPageLoading(itemCount: 10);
    }
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No closed projects found',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search',
                style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadClosedProjects(reset: true),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: paginated.length + (_hasMoreClosedProjects() ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == paginated.length) {
            // Show shimmer effect while loading more
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ShimmerListPlaceholder(itemCount: 3, itemHeight: 100),
            );
          }
          final project = paginated[i];
          final isActive = project.status == 'Active';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                child: Icon(
                  isActive ? Icons.check_circle : Icons.lock_outline,
                  color: isActive ? Colors.green : Colors.red,
                ),
              ),
              title: Text(
                project.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isActive ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      project.status,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs ${currency.format(project.total)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 18),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'view') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectExpensePage(
                          db: widget.db,
                          projectId: project.id,
                          currentUser: _currentUser,
                        ),
                      ),
                    );
                    await _loadClosedProjects(reset: true);
                  } else if (value == 'delete') {
                    await _deleteProject(project.id, project.name);
                  }
                },
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectExpensePage(
                      db: widget.db,
                      projectId: project.id,
                      currentUser: _currentUser,
                    ),
                  ),
                );
                await _loadClosedProjects(reset: true);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        title: Text(
          'Expenditure',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          // Search bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            width: 300,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search ${_selectedTab == 'Office Expense' ? 'expenses' : 'projects'}...',
                hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'Office Expense'),
            Tab(text: 'Projects'),
          ],
          onTap: (index) {
            setState(() {
              _selectedTab = index == 0 ? 'Office Expense' : 'Projects';
              _tabPages[_selectedTab] = 0;
            });
            // Mark tab as loaded
            _loadedTabs.add(index);
            // Reload data when switching tabs if needed
            if (_selectedTab == 'Office Expense' && _officeCategories.isEmpty) {
              _loadOfficeCategories(reset: true);
            } else if (_selectedTab == 'Projects' && _closedProjects.isEmpty) {
              _loadClosedProjects(reset: true);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedTab == 'Office Expense' ? _showCreateCategoryDialog : _showCreateProjectDialog,
        icon: const Icon(Icons.add),
        label: Text(_selectedTab == 'Office Expense' ? 'Add Expense Category' : 'Add Project'),
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
        child: IndexedStack(
          index: _tabController.index,
          children: [
            // Office Expense tab
            _buildTabContent('Office Expense'),
            // Projects tab
            _buildTabContent('Projects'),
          ],
        ),
      ),
    );
  }
}

class _ExpenditureProjectRow {
  final String id;
  final String name;
  final String status;
  final double total;
  final String type; // 'project' - for defensive filtering
  const _ExpenditureProjectRow({required this.id, required this.name, required this.status, required this.total, this.type = 'project'});
}

class _ExpenditureCategoryRow {
  final String id;
  final String name;
  final String status;
  final double total;
  final String type; // 'office' or 'project' - for strict filtering
  const _ExpenditureCategoryRow({required this.id, required this.name, required this.status, required this.total, required this.type});
}

class OfficeExpenseMonthPage extends StatefulWidget {
  final AppDatabase db;
  final String officeMonth; // yyyy-MM
  final Map<String, dynamic>? currentUser;
  const OfficeExpenseMonthPage({super.key, required this.db, required this.officeMonth, required this.currentUser});

  @override
  State<OfficeExpenseMonthPage> createState() => _OfficeExpenseMonthPageState();
}

class _OfficeExpenseMonthPageState extends State<OfficeExpenseMonthPage> {
  bool _loading = true;
  Map<String, dynamic>? _currentUser;
  final List<ExpenditureModel> _rows = [];
  final Map<String, Map<String, dynamic>> _creatorLookup = {};
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 200;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _searchController.addListener(_onSearchChanged);
    Future.microtask(() async {
      if (_currentUser == null) {
        await _loadCurrentUser();
      }
      await _load(reset: true);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _isSearching = _searchQuery.isNotEmpty;
    });
  }

  List<ExpenditureModel> get _filteredRows {
    if (_searchQuery.isEmpty) return _rows;
    
    return _rows.where((expense) {
      // Search in description
      final description = (expense.description ?? '').toLowerCase();
      if (description.contains(_searchQuery)) return true;
      
      // Search in amount
      final amountStr = expense.amount.toString();
      if (amountStr.contains(_searchQuery)) return true;
      
      // Search in added by
      final addedBy = _creatorLabel(expense.createdBy).toLowerCase();
      if (addedBy.contains(_searchQuery)) return true;
      
      return false;
    }).toList();
  }

  double get _filteredTotalAmount => _filteredRows.fold(0.0, (sum, e) => sum + e.amount);

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final authService = AuthService();
        final user = await authService.getCurrentUser(authToken);
        if (mounted) setState(() => _currentUser = user);
      }
    } catch (_) {}
  }

  double get _totalAmount => _rows.fold(0.0, (sum, e) => sum + e.amount);

  String _creatorLabel(String? createdBy) {
    final key = (createdBy ?? '').trim();
    if (key.isEmpty) return '';
    final u = _creatorLookup[key];
    if (u == null) return key;
    final name = (u['name'] ?? u['username'] ?? key).toString();
    final status = (u['status'] ?? 'active').toString();
    return status == 'active' ? name : '$name (Inactive)';
  }

  Future<void> _loadCreatorLookup() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL)'
            : 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL) AND (company_id = ? OR company_id IS NULL)',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      _creatorLookup.clear();
      for (final row in res) {
        final data = row.data;
        final id = data['id']?.toString();
        final uid = data['user_id']?.toString();
        final m = {
          'name': data['name'],
          'username': data['username'],
          'status': data['status'],
        };
        if (id != null && id.trim().isNotEmpty) _creatorLookup[id.trim()] = m;
        if (uid != null && uid.trim().isNotEmpty) _creatorLookup[uid.trim()] = m;
      }
    } catch (_) {}
  }

  void _syncToFirestore({required String collection, required String docId, required Map<String, dynamic> data}) {
    // Ensure Firestore operations run on platform thread for Windows compatibility
    FirestoreThreadHelper.executeOnPlatformThread(() async {
      try {
        if (Firebase.apps.isNotEmpty) {
          await FirebaseFirestore.instance.collection(collection).doc(docId).set(data, SetOptions(merge: true));
          FirestoreCacheService().invalidateCache(collection, docId);
        }
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
      }
    });
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _rows.clear();
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
      if (mounted) {
        setState(() {
          _rows.clear();
          _loading = false;
        });
      }
      return;
    }

    try {
      final offset = _rows.length;
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, company_id, kind, office_month, project_id, category, date, description, amount, created_by FROM expenditures WHERE kind = ? AND office_month = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'
            : (isAgent
                ? 'SELECT id, company_id, created_by, kind, office_month, project_id, category, date, description, amount FROM expenditures WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND kind = ? AND office_month = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'
                : 'SELECT id, company_id, kind, office_month, project_id, category, date, description, amount, created_by FROM expenditures WHERE company_id = ? AND kind = ? AND office_month = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'),
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias ?? myUserId!),
          d.Variable.withString('office'),
          d.Variable.withString(widget.officeMonth),
          d.Variable.withInt(_pageSize),
          d.Variable.withInt(offset),
        ],
      ).get();

      final mapped = res.map((r) {
        final data = r.data;
        return ExpenditureModel.fromMap({
          'id': data['id'],
          'companyId': data['company_id'],
          'createdBy': data['created_by'],
          'kind': data['kind'],
          'officeMonth': data['office_month'],
          'projectId': data['project_id'],
          'category': data['category'],
          'date': data['date'],
          'description': data['description'],
          'amount': data['amount'],
        });
      }).toList();

      if (!mounted) return;
      await _loadCreatorLookup();
      setState(() {
        _rows.addAll(mapped);
        _hasMore = mapped.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading office expenses: $e')));
    }
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (!_hasMore) return;
    if (index < _rows.length - 30) return;
    await _load(reset: false);
  }

  Future<void> _showAddExpenseDialog() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'expenditure')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add expenses.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final formKey = GlobalKey<FormState>();
    final dateCtl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String selectedCategory = 'General';
    final customCategoryCtl = TextEditingController();

    Future<void> pickDate(StateSetter setLocal) async {
      final currentText = dateCtl.text.trim();
      DateTime initial = DateTime.now();
      try {
        if (currentText.isNotEmpty) initial = DateTime.parse(currentText);
      } catch (_) {}
      final picked = await showCustomDatePicker(context, initialDate: initial);
      if (picked != null) {
        setLocal(() => dateCtl.text = DateFormat('yyyy-MM-dd').format(picked));
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (dialogContext, setLocal) {
            final maxW = MediaQuery.of(dialogContext).size.width;
            final dialogW = maxW < 520 ? maxW - 32 : 520.0;
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogW),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                          IconButton(onPressed: () => Navigator.pop(dialogContext, false), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dateCtl,
                        readOnly: true,
                        onTap: () => pickDate(setLocal),
                        decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_outlined)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtl,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                        items: const [
                          DropdownMenuItem(value: 'General', child: Text('General')),
                          DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                          DropdownMenuItem(value: 'Salaries', child: Text('Salaries')),
                          DropdownMenuItem(value: 'Fuel', child: Text('Fuel')),
                          DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                          DropdownMenuItem(value: 'Marketing', child: Text('Marketing')),
                          DropdownMenuItem(value: 'Office', child: Text('Office')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) {
                          setLocal(() => selectedCategory = v ?? 'General');
                        },
                      ),
                      if (selectedCategory == 'Other') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: customCategoryCtl,
                          decoration: const InputDecoration(labelText: 'Custom Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_outlined)),
                          validator: (v) {
                            if (selectedCategory != 'Other') return null;
                            if (v == null || v.trim().isEmpty) return 'Enter category';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Amount is required';
                          if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.pop(dialogContext, true);
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (saved != true) {
      dateCtl.dispose();
      descCtl.dispose();
      amountCtl.dispose();
      customCategoryCtl.dispose();
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final finalCompanyId = isSuperAdmin ? null : companyId;
    if (!isSuperAdmin && (finalCompanyId == null || finalCompanyId.isEmpty)) return;

    final createdBy = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? _currentUser?['id']?.toString();

    // Enforce monthly ledger: the expense date must belong to the opened month
    try {
      final pickedMonth = dateCtl.text.trim().length >= 7 ? dateCtl.text.trim().substring(0, 7) : '';
      if (pickedMonth != widget.officeMonth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Date must be within ${_formatMonthTitle(widget.officeMonth)}.')),
          );
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid date selected.')),
        );
      }
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
    final category = (selectedCategory == 'Other' ? customCategoryCtl.text.trim() : selectedCategory).trim();

    try {
      await widget.db.customStatement(
        'INSERT OR REPLACE INTO expenditures (id, company_id, created_by, kind, project_id, office_month, category, date, description, amount, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          finalCompanyId,
          createdBy,
          'office',
          null,
          widget.officeMonth,
          category.isEmpty ? null : category,
          dateCtl.text.trim(),
          descCtl.text.trim(),
          amount,
          nowIso,
        ],
      );

      _syncToFirestore(
        collection: 'expenditures',
        docId: id,
        data: {
          'id': id,
          'companyId': finalCompanyId,
          'createdBy': createdBy,
          'created_by': createdBy,
          ...creatorFields(_currentUser),
          'kind': 'office',
          'projectId': null,
          'officeMonth': widget.officeMonth,
          'category': category.isEmpty ? null : category,
          'date': dateCtl.text.trim(),
          'description': descCtl.text.trim(),
          'amount': amount,
          'updatedAt': nowIso,
        },
      );

      if (!mounted) return;
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
    }

    dateCtl.dispose();
    descCtl.dispose();
    amountCtl.dispose();
    customCategoryCtl.dispose();
  }

  Future<void> _printReport() async {
    final title = 'Office Expense (${_formatMonthTitle(widget.officeMonth)})';
    final serial = generateReportSerial(prefix: 'EXP');
    final generatedAt = DateTime.now();

    await logReportHistory(
      db: widget.db,
      currentUser: _currentUser,
      companyId: RoleUtils.getUserCompanyId(_currentUser),
      module: 'expenditure',
      entityId: widget.officeMonth,
      reportType: title,
      action: 'print',
      serialNumber: serial,
      generatedAt: generatedAt,
    );

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildExpenseStatementPdf(
          format: a4Format,
          db: widget.db,
          currentUser: _currentUser,
          title: title,
          rows: _rows,
          groupByCategory: true,
          action: 'print',
          serialNumber: serial,
          generatedAt: generatedAt,
          logHistory: false,
        );
      },
    );
  }

  Future<void> _downloadReport() async {
    final title = 'Office Expense (${_formatMonthTitle(widget.officeMonth)})';
    final a4Format = PdfPageFormat.a4;
    final bytes = await buildExpenseStatementPdf(
      format: a4Format,
      db: widget.db,
      currentUser: _currentUser,
      title: title,
      rows: _rows,
      groupByCategory: true,
      action: 'download',
    );
    await savePdfBytesToDisk(
      pdfBytes: bytes,
      suggestedBaseName: 'office_expense_${widget.officeMonth}_${fmtTs(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    final monthTitle = _formatMonthTitle(widget.officeMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Office Expense - $monthTitle',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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
                const Color(0xFFFF6B35),
                const Color(0xFF4A90E2),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history), tooltip: 'Previous Months', onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => OfficeExpenseMonthsArchivePage(db: widget.db, currentUser: _currentUser)));
          }),
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Download PDF', onPressed: _downloadReport),
          IconButton(icon: const Icon(Icons.print), tooltip: 'Print Report', onPressed: _printReport),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
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
            : Column(
                children: [
                  _ExpenseTableHeader(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: _rows.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 80),
                                    Center(
                                      child: Text(
                                        'No expenses for $monthTitle.',
                                        style: GoogleFonts.poppins(color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: _rows.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (context, i) {
                                    if (i >= _rows.length) {
                                      if (_loadingMore) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Center(child: Text('Loading more...', style: GoogleFonts.poppins(color: Colors.grey.shade600))),
                                        );
                                      }
                                      Future.microtask(() => _loadMoreIfNeeded(i));
                                      return const SizedBox(height: 32);
                                    }
                                    Future.microtask(() => _loadMoreIfNeeded(i));
                                    if (i > 0) {
                                      return Column(
                                        children: [
                                          Divider(height: 1, color: Colors.grey.shade300.withOpacity(0.6)),
                                          _ExpenseTableRow(
                                            date: _rows[i].date,
                                            description: _rows[i].description,
                                            amountText: 'Rs ${currency.format(_rows[i].amount)}',
                                            addedByText: _creatorLabel(_rows[i].createdBy),
                                          ),
                                        ],
                                      );
                                    }
                                    return _ExpenseTableRow(
                                      date: _rows[i].date,
                                      description: _rows[i].description,
                                      amountText: 'Rs ${currency.format(_rows[i].amount)}',
                                      addedByText: _creatorLabel(_rows[i].createdBy),
                                    );
                                  },
                                ),
                    ),
                  ),
                  _ExpenseTotalBar(
                    totalText: 'Rs ${currency.format(_isSearching ? _filteredTotalAmount : _totalAmount)}',
                  ),
                ],
              ),
      ),
    );
  }
}

class OfficeExpenseMonthsArchivePage extends StatefulWidget {
  final AppDatabase db;
  final Map<String, dynamic>? currentUser;
  const OfficeExpenseMonthsArchivePage({super.key, required this.db, required this.currentUser});

  @override
  State<OfficeExpenseMonthsArchivePage> createState() => _OfficeExpenseMonthsArchivePageState();
}

class _OfficeExpenseMonthsArchivePageState extends State<OfficeExpenseMonthsArchivePage> {
  bool _loading = true;
  Map<String, dynamic>? _currentUser;
  final List<String> _months = [];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    Future.microtask(() async {
      if (_currentUser == null) {
        try {
          final storage = AppStorage();
          final s = await storage.readSettings();
          final authToken = s['authToken'] as String?;
          if (authToken != null) {
            final user = await AuthService().getCurrentUser(authToken);
            if (mounted) setState(() => _currentUser = user);
          }
        } catch (_) {}
      }
      await _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
      if (mounted) {
        setState(() {
          _months.clear();
          _loading = false;
        });
      }
      return;
    }
    try {
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? "SELECT DISTINCT office_month AS m FROM expenditures WHERE kind = 'office' AND office_month IS NOT NULL AND office_month != '' ORDER BY office_month DESC"
            : (isAgent
                ? "SELECT DISTINCT office_month AS m FROM expenditures WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND kind = 'office' AND office_month IS NOT NULL AND office_month != '' ORDER BY office_month DESC"
                : "SELECT DISTINCT office_month AS m FROM expenditures WHERE company_id = ? AND kind = 'office' AND office_month IS NOT NULL AND office_month != '' ORDER BY office_month DESC"),
        variables: isSuperAdmin
            ? []
            : [
                d.Variable.withString(companyId!),
                if (isAgent) d.Variable.withString(myUserId!),
                if (isAgent)
                  d.Variable.withString(creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId!),
              ],
      ).get();
      final months = res.map((r) => r.data['m']?.toString() ?? '').where((m) => m.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        _months
          ..clear()
          ..addAll(months);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load months: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Previous Months', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
      ),
      body: _loading
          ? const ShimmerPageLoading(itemCount: 8)
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _months.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = _months[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: Text(_formatMonthTitle(m)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OfficeExpenseMonthPage(db: widget.db, officeMonth: m, currentUser: _currentUser),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class ProjectExpensePage extends StatefulWidget {
  final AppDatabase db;
  final String projectId;
  final Map<String, dynamic>? currentUser;
  const ProjectExpensePage({super.key, required this.db, required this.projectId, required this.currentUser});

  @override
  State<ProjectExpensePage> createState() => _ProjectExpensePageState();
}

class _ProjectExpensePageState extends State<ProjectExpensePage> {
  bool _loading = true;
  Map<String, dynamic>? _currentUser;
  String _projectName = '';
  String _projectStatus = 'Active';
  final List<ExpenditureModel> _rows = [];
  final Map<String, Map<String, dynamic>> _creatorLookup = {};
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 200;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    Future.microtask(() async {
      if (_currentUser == null) await _loadCurrentUser();
      await _load(reset: true);
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService().getCurrentUser(authToken);
        if (mounted) setState(() => _currentUser = user);
      }
    } catch (_) {}
  }

  double get _totalAmount => _rows.fold(0.0, (sum, e) => sum + e.amount);
  bool get _isClosed => _projectStatus == 'Closed';

  String _creatorLabel(String? createdBy) {
    final key = (createdBy ?? '').trim();
    if (key.isEmpty) return '';
    final u = _creatorLookup[key];
    if (u == null) return key;
    final name = (u['name'] ?? u['username'] ?? key).toString();
    final status = (u['status'] ?? 'active').toString();
    return status == 'active' ? name : '$name (Inactive)';
  }

  Future<void> _loadCreatorLookup() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL)'
            : 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL) AND (company_id = ? OR company_id IS NULL)',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      _creatorLookup.clear();
      for (final row in res) {
        final data = row.data;
        final id = data['id']?.toString();
        final uid = data['user_id']?.toString();
        final m = {
          'name': data['name'],
          'username': data['username'],
          'status': data['status'],
        };
        if (id != null && id.trim().isNotEmpty) _creatorLookup[id.trim()] = m;
        if (uid != null && uid.trim().isNotEmpty) _creatorLookup[uid.trim()] = m;
      }
    } catch (_) {}
  }

  void _syncToFirestore({required String collection, required String docId, required Map<String, dynamic> data}) {
    // Ensure Firestore operations run on platform thread for Windows compatibility
    FirestoreThreadHelper.executeOnPlatformThread(() async {
      try {
        if (Firebase.apps.isNotEmpty) {
          await FirebaseFirestore.instance.collection(collection).doc(docId).set(data, SetOptions(merge: true));
          FirestoreCacheService().invalidateCache(collection, docId);
        }
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
      }
    });
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _rows.clear();
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
      return;
    }

    if (isAgent && (myUserId == null || myUserId.trim().isEmpty)) {
      if (mounted) {
        setState(() {
          _projectName = '';
          _projectStatus = 'running';
          _rows.clear();
          _loading = false;
          _loadingMore = false;
          _hasMore = false;
        });
      }
      return;
    }

    try {
      final projectRow = await widget.db.customSelect(
        isSuperAdmin
            ? "SELECT id, name, status FROM expenditure_projects WHERE id = ? AND type = 'project'"
            : (isAgent
                ? "SELECT id, name, status FROM expenditure_projects WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND id = ? AND type = 'project'"
                : "SELECT id, name, status FROM expenditure_projects WHERE company_id = ? AND id = ? AND type = 'project'"),
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias ?? myUserId!),
          d.Variable.withString(widget.projectId),
        ],
      ).getSingleOrNull();

      final name = projectRow?.data['name']?.toString() ?? 'Project';
      final status = projectRow?.data['status']?.toString() ?? 'Active';

      final offset = _rows.length;
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, company_id, created_by, kind, office_month, project_id, category, date, description, amount FROM expenditures WHERE kind = ? AND project_id = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'
            : (isAgent
                ? 'SELECT id, company_id, created_by, kind, office_month, project_id, category, date, description, amount FROM expenditures WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND kind = ? AND project_id = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'
                : 'SELECT id, company_id, kind, office_month, project_id, category, date, description, amount, created_by FROM expenditures WHERE company_id = ? AND kind = ? AND project_id = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'),
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias ?? myUserId!),
          d.Variable.withString('project'),
          d.Variable.withString(widget.projectId),
          d.Variable.withInt(_pageSize),
          d.Variable.withInt(offset),
        ],
      ).get();

      final mapped = res.map((r) {
        final data = r.data;
        return ExpenditureModel.fromMap({
          'id': data['id'],
          'companyId': data['company_id'],
          'createdBy': data['created_by'],
          'kind': data['kind'],
          'officeMonth': data['office_month'],
          'projectId': data['project_id'],
          'category': data['category'],
          'date': data['date'],
          'description': data['description'],
          'amount': data['amount'],
        });
      }).toList();

      if (!mounted) return;
      await _loadCreatorLookup();
      setState(() {
        _projectName = name;
        _projectStatus = status;
        _rows.addAll(mapped);
        _hasMore = mapped.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading project: $e')));
    }
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (!_hasMore) return;
    if (index < _rows.length - 30) return;
    await _load(reset: false);
  }

  Future<void> _renameProject() async {
    final ctl = TextEditingController(text: _projectName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(controller: ctl, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Project Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = ctl.text.trim();
    if (newName.isEmpty) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await widget.db.customStatement(
        isSuperAdmin
            ? 'UPDATE expenditure_projects SET name = ?, updated_at = ? WHERE id = ?'
            : 'UPDATE expenditure_projects SET name = ?, updated_at = ? WHERE company_id = ? AND id = ?',
        [
          newName,
          nowIso,
          if (!isSuperAdmin) companyId,
          widget.projectId,
        ],
      );
      _syncToFirestore(
        collection: 'expenditure_projects',
        docId: widget.projectId,
        data: {'name': newName, 'updatedAt': nowIso},
      );
      if (!mounted) return;
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
    }
  }

  Future<void> _closeProject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Closed'),
        content: const Text('Are you sure you want to mark this project as closed? Once closed, you will not be able to add new expense entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Closed'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await widget.db.customStatement(
        isSuperAdmin
            ? "UPDATE expenditure_projects SET status = 'Closed', closed_at = ?, updated_at = ? WHERE id = ?"
            : "UPDATE expenditure_projects SET status = 'Closed', closed_at = ?, updated_at = ? WHERE company_id = ? AND id = ?",
        [
          nowIso,
          nowIso,
          if (!isSuperAdmin) companyId,
          widget.projectId,
        ],
      );
      _syncToFirestore(
        collection: 'expenditure_projects',
        docId: widget.projectId,
        data: {'status': 'Closed', 'closedAt': nowIso, 'updatedAt': nowIso},
      );
      if (!mounted) return;
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Close failed: $e')));
    }
  }

  Future<void> _showAddExpenseDialog() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'expenditure')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add expenses.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    // Strict restriction: Closed projects cannot have new entries
    if (_isClosed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This project is closed. You cannot add new entries.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final formKey = GlobalKey<FormState>();
    final dateCtl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String selectedCategory = 'General';
    final customCategoryCtl = TextEditingController();

    Future<void> pickDate(StateSetter setLocal) async {
      final currentText = dateCtl.text.trim();
      DateTime initial = DateTime.now();
      try {
        if (currentText.isNotEmpty) initial = DateTime.parse(currentText);
      } catch (_) {}
      final picked = await showCustomDatePicker(context, initialDate: initial);
      if (picked != null) setLocal(() => dateCtl.text = DateFormat('yyyy-MM-dd').format(picked));
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                        IconButton(onPressed: () => Navigator.pop(dialogContext, false), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dateCtl,
                      readOnly: true,
                      onTap: () => pickDate(setLocal),
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtl,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                      items: const [
                        DropdownMenuItem(value: 'General', child: Text('General')),
                        DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                        DropdownMenuItem(value: 'Salaries', child: Text('Salaries')),
                        DropdownMenuItem(value: 'Fuel', child: Text('Fuel')),
                        DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                        DropdownMenuItem(value: 'Marketing', child: Text('Marketing')),
                        DropdownMenuItem(value: 'Office', child: Text('Office')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        setLocal(() => selectedCategory = v ?? 'General');
                      },
                    ),
                    if (selectedCategory == 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customCategoryCtl,
                        decoration: const InputDecoration(labelText: 'Custom Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_outlined)),
                        validator: (v) {
                          if (selectedCategory != 'Other') return null;
                          if (v == null || v.trim().isEmpty) return 'Enter category';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountCtl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(dialogContext, true);
                        },
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (saved != true) {
      dateCtl.dispose();
      descCtl.dispose();
      amountCtl.dispose();
      customCategoryCtl.dispose();
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;
    final finalCompanyId = isSuperAdmin ? 'GLOBAL_ADMIN' : companyId!;

    final createdBy = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? _currentUser?['id']?.toString();

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
    final category = (selectedCategory == 'Other' ? customCategoryCtl.text.trim() : selectedCategory).trim();
    try {
      await widget.db.customStatement(
        'INSERT OR REPLACE INTO expenditures (id, company_id, created_by, kind, project_id, office_month, category, date, description, amount, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          finalCompanyId,
          createdBy,
          'project',
          widget.projectId,
          null,
          category.isEmpty ? null : category,
          dateCtl.text.trim(),
          descCtl.text.trim(),
          amount,
          nowIso,
        ],
      );

      _syncToFirestore(
        collection: 'expenditures',
        docId: id,
        data: {
          'id': id,
          'companyId': finalCompanyId,
          'createdBy': createdBy,
          'created_by': createdBy,
          ...creatorFields(_currentUser),
          'kind': 'project',
          'projectId': widget.projectId,
          'officeMonth': null,
          'category': category.isEmpty ? null : category,
          'date': dateCtl.text.trim(),
          'description': descCtl.text.trim(),
          'amount': amount,
          'updatedAt': nowIso,
        },
      );
      if (!mounted) return;
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
    }

    dateCtl.dispose();
    descCtl.dispose();
    amountCtl.dispose();
    customCategoryCtl.dispose();
  }

  Future<void> _printReport() async {
    final title = 'Project Expense ($_projectName)';
    final serial = generateReportSerial(prefix: 'EXP');
    final generatedAt = DateTime.now();

    await logReportHistory(
      db: widget.db,
      currentUser: _currentUser,
      companyId: RoleUtils.getUserCompanyId(_currentUser),
      module: 'expenditure',
      entityId: widget.projectId,
      reportType: title,
      action: 'print',
      serialNumber: serial,
      generatedAt: generatedAt,
    );

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildExpenseStatementPdf(
          format: a4Format,
          db: widget.db,
          currentUser: _currentUser,
          title: title,
          rows: _rows,
          groupByCategory: true,
          action: 'print',
          serialNumber: serial,
          generatedAt: generatedAt,
          logHistory: false,
        );
      },
    );
  }

  Future<void> _downloadReport() async {
    final title = 'Project Expense ($_projectName)';
    final a4Format = PdfPageFormat.a4;
    final bytes = await buildExpenseStatementPdf(
      format: a4Format,
      db: widget.db,
      currentUser: _currentUser,
      title: title,
      rows: _rows,
      groupByCategory: true,
      action: 'download',
    );
    await savePdfBytesToDisk(
      pdfBytes: bytes,
      suggestedBaseName: 'project_expense_${widget.projectId}_${fmtTs(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(
        title: Text(_projectName.isEmpty ? 'Project Expense' : _projectName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Download PDF', onPressed: _downloadReport),
          IconButton(icon: const Icon(Icons.print), tooltip: 'Print Report', onPressed: _printReport),
          // Hide Add Expense button for closed projects
          if (!_isClosed)
            IconButton(icon: const Icon(Icons.add), tooltip: 'New Entry', onPressed: _showAddExpenseDialog),
          if (!_isClosed)
            IconButton(icon: const Icon(Icons.lock_outline), tooltip: 'Mark as Closed', onPressed: _closeProject),
        ],
      ),
        floatingActionButton: _isClosed
            ? null // Hide FAB for closed projects
            : FloatingActionButton.extended(
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
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
            : Column(
                children: [
                  if (_isClosed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.orange.shade50,
                      child: Text('This project is closed.', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                    ),
                  _ExpenseTableHeader(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: _rows.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(child: Text('No expenses yet.', style: GoogleFonts.poppins(color: Colors.grey.shade700))),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _rows.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i >= _rows.length) {
                                  if (_loadingMore) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(child: Text('Loading more...', style: GoogleFonts.poppins(color: Colors.grey.shade600))),
                                    );
                                  }
                                  Future.microtask(() => _loadMoreIfNeeded(i));
                                  return const SizedBox(height: 32);
                                }

                                Future.microtask(() => _loadMoreIfNeeded(i));

                                if (i > 0) {
                                  return Column(
                                    children: [
                                      Divider(height: 1, color: Colors.grey.shade300.withOpacity(0.6)),
                                      _ExpenseTableRow(
                                        date: _rows[i].date,
                                        description: _rows[i].description,
                                        amountText: 'Rs ${currency.format(_rows[i].amount)}',
                                        addedByText: _creatorLabel(_rows[i].createdBy),
                                      ),
                                    ],
                                  );
                                }

                                return _ExpenseTableRow(
                                  date: _rows[i].date,
                                  description: _rows[i].description,
                                  amountText: 'Rs ${currency.format(_rows[i].amount)}',
                                  addedByText: _creatorLabel(_rows[i].createdBy),
                                );
                              },
                            ),
                    ),
                  ),
                  _ExpenseTotalBar(totalText: 'Rs ${currency.format(_totalAmount)}'),
                ],
              ),
      ),
    );
  }
}

class OfficeExpenseCategoryPage extends StatefulWidget {
  final AppDatabase db;
  final String categoryId;
  final String categoryName;
  final Map<String, dynamic>? currentUser;
  const OfficeExpenseCategoryPage({super.key, required this.db, required this.categoryId, required this.categoryName, required this.currentUser});

  @override
  State<OfficeExpenseCategoryPage> createState() => _OfficeExpenseCategoryPageState();
}

class _OfficeExpenseCategoryPageState extends State<OfficeExpenseCategoryPage> {
  bool _loading = true;
  Map<String, dynamic>? _currentUser;
  final List<ExpenditureModel> _rows = [];
  final Map<String, Map<String, dynamic>> _creatorLookup = {};
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 200;
  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    Future.microtask(() async {
      if (_currentUser == null) await _loadCurrentUser();
      await _load(reset: true);
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storage = AppStorage();
      final s = await storage.readSettings();
      final authToken = s['authToken'] as String?;
      if (authToken != null) {
        final user = await AuthService().getCurrentUser(authToken);
        if (mounted) setState(() => _currentUser = user);
      }
    } catch (_) {}
  }

  double get _totalAmount => _rows.fold(0.0, (sum, e) => sum + e.amount);

  String _creatorLabel(String? createdBy) {
    final key = (createdBy ?? '').trim();
    if (key.isEmpty) return '';
    final u = _creatorLookup[key];
    if (u == null) return key;
    final name = (u['name'] ?? u['username'] ?? key).toString();
    final status = (u['status'] ?? 'active').toString();
    return status == 'active' ? name : '$name (Inactive)';
  }

  Future<void> _loadCreatorLookup() async {
    try {
      final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
      final companyId = RoleUtils.getUserCompanyId(_currentUser);
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL)'
            : 'SELECT id, user_id, username, name, status FROM users WHERE (is_active = 1 OR is_active IS NULL) AND (company_id = ? OR company_id IS NULL)',
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId ?? '')],
      ).get();
      _creatorLookup.clear();
      for (final row in res) {
        final data = row.data;
        final id = data['id']?.toString();
        final uid = data['user_id']?.toString();
        final m = {
          'name': data['name'],
          'username': data['username'],
          'status': data['status'],
        };
        if (id != null && id.trim().isNotEmpty) _creatorLookup[id.trim()] = m;
        if (uid != null && uid.trim().isNotEmpty) _creatorLookup[uid.trim()] = m;
      }
    } catch (_) {}
  }

  void _syncToFirestore({required String collection, required String docId, required Map<String, dynamic> data}) {
    Future.microtask(() async {
      try {
        if (Firebase.apps.isNotEmpty) {
          await FirebaseFirestore.instance.collection(collection).doc(docId).set(data, SetOptions(merge: true));
          FirestoreCacheService().invalidateCache(collection, docId);
        }
      } catch (e) {
        debugPrint('Background Firestore sync failed for $collection/$docId: $e');
      }
    });
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _rows.clear();
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final isAgent = RoleUtils.isAgent(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    final myUserId = _currentUser?['id']?.toString();
    final myAlias = creatorFields(_currentUser)['creator_user_id_alias']?.toString() ?? myUserId;
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
      return;
    }

    try {
      final offset = _rows.length;
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? 'SELECT id, company_id, created_by, kind, category_id, category, date, description, amount FROM expenditures WHERE kind = ? AND category_id = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'
            : (isAgent
                ? 'SELECT id, company_id, created_by, kind, category_id, category, date, description, amount FROM expenditures WHERE company_id = ? AND (created_by = ? OR created_by = ?) AND kind = ? AND category_id = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'
                : 'SELECT id, company_id, kind, category_id, category, date, description, amount, created_by FROM expenditures WHERE company_id = ? AND kind = ? AND category_id = ? ORDER BY date ASC, updated_at ASC LIMIT ? OFFSET ?'),
        variables: [
          if (!isSuperAdmin) d.Variable.withString(companyId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myUserId!),
          if (!isSuperAdmin && isAgent) d.Variable.withString(myAlias ?? myUserId!),
          d.Variable.withString('office'),
          d.Variable.withString(widget.categoryId),
          d.Variable.withInt(_pageSize),
          d.Variable.withInt(offset),
        ],
      ).get();

      final mapped = res.map((r) {
        final data = r.data;
        return ExpenditureModel.fromMap({
          'id': data['id'],
          'companyId': data['company_id'],
          'createdBy': data['created_by'],
          'kind': data['kind'],
          'categoryId': data['category_id'],
          'category': data['category'],
          'date': data['date'],
          'description': data['description'],
          'amount': data['amount'],
        });
      }).toList();

      if (!mounted) return;
      await _loadCreatorLookup();
      setState(() {
        _rows.addAll(mapped);
        _hasMore = mapped.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading category: $e')));
    }
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (!_hasMore) return;
    if (index < _rows.length - 30) return;
    await _load(reset: false);
  }

  Future<void> _showAddExpenseDialog() async {
    if (!PermissionHelper.canAddModule(_currentUser, 'expenditure')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add expenses.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final formKey = GlobalKey<FormState>();
    final dateCtl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String selectedCategory = 'General';
    final customCategoryCtl = TextEditingController();

    Future<void> pickDate(StateSetter setLocal) async {
      final currentText = dateCtl.text.trim();
      DateTime initial = DateTime.now();
      try {
        if (currentText.isNotEmpty) initial = DateTime.parse(currentText);
      } catch (_) {}
      final picked = await showCustomDatePicker(context, initialDate: initial);
      if (picked != null) setLocal(() => dateCtl.text = DateFormat('yyyy-MM-dd').format(picked));
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateCtl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                    onTap: () => pickDate(setLocal),
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Date is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category/Sub-category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                    items: ['General', 'Office Supplies', 'Utilities', 'Rent', 'Maintenance', 'Travel', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setLocal(() => selectedCategory = v ?? 'General'),
                  ),
                  if (selectedCategory == 'Other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customCategoryCtl,
                      decoration: const InputDecoration(labelText: 'Custom Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_outlined)),
                      validator: (v) {
                        if (selectedCategory != 'Other') return null;
                        if (v == null || v.trim().isEmpty) return 'Enter category';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Amount is required';
                      if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(dialogContext, true);
                      },
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved != true) {
      dateCtl.dispose();
      descCtl.dispose();
      amountCtl.dispose();
      customCategoryCtl.dispose();
      return;
    }

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;
    final createdBy = _currentUser?['id']?.toString() ?? '';
    final id = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final finalCompanyId = isSuperAdmin ? 'GLOBAL_ADMIN' : companyId!;
    final amount = double.tryParse(amountCtl.text.trim()) ?? 0.0;
    final category = selectedCategory == 'Other' ? customCategoryCtl.text.trim() : selectedCategory;

    try {
      await widget.db.customStatement(
        'INSERT OR REPLACE INTO expenditures (id, company_id, created_by, kind, category_id, category, date, description, amount, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [id, finalCompanyId, createdBy, 'office', widget.categoryId, category.isEmpty ? null : category, dateCtl.text.trim(), descCtl.text.trim(), amount, nowIso],
      );

      _syncToFirestore(
        collection: 'expenditures',
        docId: id,
        data: {
          'id': id,
          'companyId': finalCompanyId,
          'createdBy': createdBy,
          'created_by': createdBy,
          ...creatorFields(_currentUser),
          'kind': 'office',
          'categoryId': widget.categoryId,
          'category_id': widget.categoryId,
          'category': category.isEmpty ? null : category,
          'date': dateCtl.text.trim(),
          'description': descCtl.text.trim(),
          'amount': amount,
          'updatedAt': nowIso,
          'updated_at': nowIso,
        },
      );

      if (!mounted) return;
      await _load(reset: true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
    }

    dateCtl.dispose();
    descCtl.dispose();
    amountCtl.dispose();
    customCategoryCtl.dispose();
  }

  Future<void> _printReport() async {
    final title = 'Office Expense - ${widget.categoryName}';
    final serial = generateReportSerial(prefix: 'EXP');
    final generatedAt = DateTime.now();

    await logReportHistory(
      db: widget.db,
      currentUser: _currentUser,
      companyId: RoleUtils.getUserCompanyId(_currentUser),
      module: 'expenditure',
      entityId: widget.categoryId,
      reportType: title,
      action: 'print',
      serialNumber: serial,
      generatedAt: generatedAt,
    );

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildExpenseStatementPdf(
          format: a4Format,
          db: widget.db,
          currentUser: _currentUser,
          title: title,
          rows: _rows,
          groupByCategory: false,
          action: 'print',
          serialNumber: serial,
          generatedAt: generatedAt,
          logHistory: false,
        );
      },
    );
  }

  Future<void> _downloadReport() async {
    final title = 'Office Expense - ${widget.categoryName}';
    final a4Format = PdfPageFormat.a4;
    final bytes = await buildExpenseStatementPdf(
      format: a4Format,
      db: widget.db,
      currentUser: _currentUser,
      title: title,
      rows: _rows,
      groupByCategory: false,
      action: 'download',
    );
    await savePdfBytesToDisk(
      pdfBytes: bytes,
      suggestedBaseName: 'office_expense_${widget.categoryName.replaceAll(' ', '_')}_${fmtTs(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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
                const Color(0xFFFF6B35),
                const Color(0xFF4A90E2),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Download PDF', onPressed: _downloadReport),
          IconButton(icon: const Icon(Icons.print), tooltip: 'Print Report', onPressed: _printReport),
          IconButton(icon: const Icon(Icons.add), tooltip: 'New Entry', onPressed: _showAddExpenseDialog),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
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
            : Column(
                children: [
                  _ExpenseTableHeader(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: _rows.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 80),
                                    Center(
                                      child: Text(
                                        'No expenses for this category.',
                                        style: GoogleFonts.poppins(color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: _rows.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (context, i) {
                                    if (i >= _rows.length) {
                                      if (_loadingMore) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Center(child: Text('Loading more...', style: GoogleFonts.poppins(color: Colors.grey.shade600))),
                                        );
                                      }
                                      Future.microtask(() => _loadMoreIfNeeded(i));
                                      return const SizedBox(height: 32);
                                    }
                                    Future.microtask(() => _loadMoreIfNeeded(i));
                                    if (i > 0) {
                                      return Column(
                                        children: [
                                          Divider(height: 1, color: Colors.grey.shade300.withOpacity(0.6)),
                                          _ExpenseTableRow(
                                            date: _rows[i].date,
                                            description: _rows[i].description,
                                            amountText: 'Rs ${currency.format(_rows[i].amount)}',
                                            addedByText: _creatorLabel(_rows[i].createdBy),
                                          ),
                                        ],
                                      );
                                    }
                                    return _ExpenseTableRow(
                                      date: _rows[i].date,
                                      description: _rows[i].description,
                                      amountText: 'Rs ${currency.format(_rows[i].amount)}',
                                      addedByText: _creatorLabel(_rows[i].createdBy),
                                    );
                                  },
                                ),
                    ),
                  ),
                  _ExpenseTotalBar(totalText: 'Rs ${currency.format(_totalAmount)}'),
                ],
              ),
      ),
    );
  }
}

class ClosedProjectsPage extends StatefulWidget {
  final AppDatabase db;
  final Map<String, dynamic>? currentUser;
  const ClosedProjectsPage({super.key, required this.db, required this.currentUser});

  @override
  State<ClosedProjectsPage> createState() => _ClosedProjectsPageState();
}

class _ClosedProjectsPageState extends State<ClosedProjectsPage> {
  bool _loading = true;
  Map<String, dynamic>? _currentUser;
  final List<_ExpenditureProjectRow> _projects = [];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    Future.microtask(() async {
      if (_currentUser == null) {
        try {
          final storage = AppStorage();
          final s = await storage.readSettings();
          final authToken = s['authToken'] as String?;
          if (authToken != null) {
            final user = await AuthService().getCurrentUser(authToken);
            if (mounted) setState(() => _currentUser = user);
          }
        } catch (_) {}
      }
      await _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await widget.db.customSelect(
        isSuperAdmin
            ? """
              SELECT p.id, p.name, p.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project'
              WHERE p.type = 'project'
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
            """
            : """
              SELECT p.id, p.name, p.status, COALESCE(SUM(e.amount), 0) AS total
              FROM expenditure_projects p
              LEFT JOIN expenditures e
                ON e.project_id = p.id AND e.kind = 'project' AND e.company_id = p.company_id
              WHERE p.type = 'project' AND p.company_id = ?
              GROUP BY p.id, p.name, p.status
              ORDER BY p.updated_at DESC
            """,
        variables: isSuperAdmin ? [] : [d.Variable.withString(companyId!)],
      ).get();

      final list = res
          .map(
            (r) => _ExpenditureProjectRow(
              id: r.data['id']?.toString() ?? '',
              name: r.data['name']?.toString() ?? '',
              status: r.data['status']?.toString() ?? 'Active',
              total: (r.data['total'] as num?)?.toDouble() ?? 0,
              type: 'project', // Explicitly set type for defensive filtering
            ),
          )
          .where((proj) => proj.type == 'project') // Defensive filter: ensure only projects
          .toList();

      if (!mounted) return;
      setState(() {
        _projects
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load closed projects: $e')));
    }
  }

  Future<void> _deleteProjectFromClosedPage(String projectId, String projectName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "$projectName"? This will permanently delete the project and all its expense entries. This action cannot be undone.'),
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

    if (confirm != true) return;

    final isSuperAdmin = RoleUtils.isSuperAdmin(_currentUser);
    final companyId = RoleUtils.getUserCompanyId(_currentUser);
    if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) return;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      // Soft delete all expenses for this project
      await widget.db.customStatement(
        isSuperAdmin
            ? "UPDATE expenditures SET status = 'archived', is_active = 0, updated_at = ? WHERE project_id = ? AND kind = ?"
            : "UPDATE expenditures SET status = 'archived', is_active = 0, updated_at = ? WHERE company_id = ? AND project_id = ? AND kind = ?",
        isSuperAdmin
            ? [nowIso, projectId, 'project']
            : [nowIso, companyId, projectId, 'project'],
      );

      // Soft delete the project
      await widget.db.customStatement(
        isSuperAdmin
            ? "UPDATE expenditure_projects SET status = 'archived', is_active = 0, updated_at = ? WHERE id = ?"
            : "UPDATE expenditure_projects SET status = 'archived', is_active = 0, updated_at = ? WHERE company_id = ? AND id = ?",
        isSuperAdmin ? [nowIso, projectId] : [nowIso, companyId, projectId],
      );

      // Soft delete in Firestore
      if (Firebase.apps.isNotEmpty) {
        try {
          // Mark all expense documents
          final expensesSnapshot = await FirebaseFirestore.instance
              .collection('expenditures')
              .where('projectId', isEqualTo: projectId)
              .get();
          
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in expensesSnapshot.docs) {
            batch.set(
              doc.reference,
              {
                'status': 'archived',
                'is_active': 0,
                'isActive': 0,
                'updated_at': nowIso,
                'deleted_at': nowIso,
              },
              SetOptions(merge: true),
            );
          }
          await batch.commit();

          // Mark project document
          await FirebaseFirestore.instance.collection('expenditure_projects').doc(projectId).set(
            {
              'status': 'archived',
              'is_active': 0,
              'isActive': 0,
              'updated_at': nowIso,
              'deleted_at': nowIso,
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          debugPrint('Error deleting from Firestore: $e');
        }
      }

      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete project: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(
        title: Text('Projects', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
      ),
      body: _loading
          ? const ShimmerPageLoading(itemCount: 8)
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = _projects[i];
                final isActive = p.status == 'Active';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      child: Icon(
                        isActive ? Icons.check_circle : Icons.lock_outline,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            p.status,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total: Rs ${currency.format(p.total)}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 18),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'view') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectExpensePage(db: widget.db, projectId: p.id, currentUser: _currentUser),
                            ),
                          );
                        } else if (value == 'delete') {
                          await _deleteProjectFromClosedPage(p.id, p.name);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectExpensePage(db: widget.db, projectId: p.id, currentUser: _currentUser),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ExpenseTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey.shade700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B1F24) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300.withOpacity(0.7))),
      ),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text('Date', style: style)),
          Expanded(child: Text('Description', style: style)),
          SizedBox(width: 110, child: Align(alignment: Alignment.centerRight, child: Text('Amount', style: style))),
        ],
      ),
    );
  }
}

class _ExpenseTableRow extends StatelessWidget {
  final String date;
  final String description;
  final String amountText;
  final String? addedByText;
  const _ExpenseTableRow({required this.date, required this.description, required this.amountText, this.addedByText});

  @override
  Widget build(BuildContext context) {
    final cellStyle = GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.grey.shade800);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(date, style: cellStyle)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: cellStyle, overflow: TextOverflow.ellipsis, maxLines: 1),
                if ((addedByText ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Added by: $addedByText',
                      style: cellStyle.copyWith(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 110, child: Align(alignment: Alignment.centerRight, child: Text(amountText, style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFFFF6B35))))),
        ],
      ),
    );
  }
}

class _ExpenseTotalBar extends StatelessWidget {
  final String totalText;
  const _ExpenseTotalBar({required this.totalText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B1F24) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300.withOpacity(0.7))),
      ),
      child: Row(
        children: [
          Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.grey.shade800)),
          const Spacer(),
          Text(totalText, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: const Color(0xFF4A90E2))),
        ],
      ),
    );
  }
}

// Detail View for Office Expense
class OfficeExpenseDetailPage extends StatelessWidget {
  final ExpenditureModel expense;
  final AppDatabase db;
  final Map<String, dynamic>? currentUser;
  const OfficeExpenseDetailPage({super.key, required this.expense, required this.db, required this.currentUser});

  List<MapEntry<String, String>> _getAllFields() {
    final fields = <MapEntry<String, String>>[];
    final currency = NumberFormat('#,##0.00');
    
    fields.add(MapEntry('ID', expense.id ?? 'N/A'));
    fields.add(MapEntry('Description', expense.description ?? 'N/A'));
    fields.add(MapEntry('Date', expense.date ?? 'N/A'));
    fields.add(MapEntry('Amount', 'Rs ${currency.format(expense.amount)}'));
    if (expense.category != null && expense.category!.isNotEmpty) {
      fields.add(MapEntry('Category', expense.category!));
    }
    if (expense.officeMonth != null && expense.officeMonth!.isNotEmpty) {
      fields.add(MapEntry('Office Month', expense.officeMonth!));
    }
    fields.add(MapEntry('Created By', expense.createdBy ?? 'N/A'));
    
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final allFields = _getAllFields();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Office Expense Details', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
          IconButton(icon: const Icon(Icons.print), onPressed: () => _print(context)),
          IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadPdf()),
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
                        'Office Expense Details',
                        style: GoogleFonts.poppins(
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
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Value',
                                      style: GoogleFonts.poppins(
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
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            field.value,
                                            style: GoogleFonts.poppins(fontSize: 13),
                                          ),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _print(BuildContext context) async {
    final currentUser = await loadCurrentUserFromStorage();
    final entityId = expense.id ?? '';
    final title = 'Office Expense Details';
    final fields = _getAllFields();

    await Printing.layoutPdf(
      onLayout: (_) async {
        final a4Format = PdfPageFormat.a4;
        return buildKeyValueReportPdf(
          format: a4Format,
          db: db,
          currentUser: currentUser,
          module: 'expenditure',
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
    final entityId = expense.id ?? '';
    final title = 'Office Expense Details';
    final fields = _getAllFields();

    final bytes = await buildKeyValueReportPdf(
      format: PdfPageFormat.a4,
      db: db,
      currentUser: currentUser,
      module: 'expenditure',
      entityId: entityId,
      title: title,
      action: 'download',
      fields: fields,
    );
    
    await savePdfBytesToDisk(
      pdfBytes: bytes,
      suggestedBaseName: 'office_expense_${entityId}_${fmtTs(DateTime.now())}',
    );
  }
}

Future<Uint8List> _buildExpenseReportPdf({
  required PdfPageFormat format,
  required String title,
  required List<ExpenditureModel> rows,
  required bool showMonth,
}) async {
  final sanitizedRows = rows
      .map((e) => {
            'date': e.date,
            'description': e.description,
            'amount': e.amount,
          })
      .toList(growable: false);

  return compute(
    _buildExpenseReportPdfInIsolate,
    {
      'format': {
        'w': format.width,
        'h': format.height,
        'ml': format.marginLeft,
        'mt': format.marginTop,
        'mr': format.marginRight,
        'mb': format.marginBottom,
      },
      'title': title,
      'rows': sanitizedRows,
      'showMonth': showMonth,
    },
  );
}

Future<Uint8List> _buildExpenseReportPdfInIsolate(Map<String, dynamic> args) async {
  final f = (args['format'] as Map).cast<String, dynamic>();
  final format = PdfPageFormat(
    (f['w'] as num).toDouble(),
    (f['h'] as num).toDouble(),
    marginLeft: (f['ml'] as num).toDouble(),
    marginTop: (f['mt'] as num).toDouble(),
    marginRight: (f['mr'] as num).toDouble(),
    marginBottom: (f['mb'] as num).toDouble(),
  );
  final title = (args['title'] ?? '').toString();
  final rows = (args['rows'] as List).cast<Map>();

  final pdf = pw.Document();
  final currency = NumberFormat('#,##0.00');
  final total = rows.fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5, color: const PdfColor.fromInt(0xFFBDBDBD)),
                columnWidths: {
                  0: const pw.FixedColumnWidth(90),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(90),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))),
                    ],
                  ),
                  ...rows.map(
                    (e) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((e['date'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((e['description'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('Rs ${currency.format(((e['amount'] as num?)?.toDouble() ?? 0.0))}', style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Spacer(),
                  pw.Text('Total: Rs ${currency.format(total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  return await pdf.save();
}
