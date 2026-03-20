import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'schema.g.dart';

class Companies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get status => text()(); // 'active' or 'inactive'
  TextColumn get metadata => text().nullable()();
  IntColumn get maxUserLimit => integer().withDefault(const Constant(5))();
  TextColumn get subscriptionTier => text().withDefault(const Constant('Starter'))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get salt => text().nullable()();
  IntColumn get iterations => integer().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get contactNo => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get permissions => text().nullable()(); // JSON string storing permissions like {"role": "super_admin", "canView": true, "canAdd": false}
  TextColumn get companyId => text().nullable().references(Companies, #id)(); // null for Super Admin
  TextColumn get status => text().nullable()(); // 'active' or 'inactive'
  BoolColumn get isFirstLogin => boolean().withDefault(const Constant(true))(); // true for new Company Admins, forces password change
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get profilePicturePath => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class Societies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get metadata => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class Blocks extends Table {
  TextColumn get id => text()();
  TextColumn get societyId => text().references(Societies, #id)();
  TextColumn get name => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get metadata => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class Properties extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  // Legacy fields kept for backward compatibility
  TextColumn get propertyName => text()();
  IntColumn get price => integer().nullable()();
  TextColumn get remarks => text().nullable()();
  // New fields aligned with Files
  TextColumn get clientName => text().nullable()();
  TextColumn get fileNo => text().nullable()();
  TextColumn get referenceNo => text().nullable()();
  IntColumn get demand => integer().nullable()();
  TextColumn get saleStatus => text().nullable()();
  TextColumn get cnic => text().nullable()();
  TextColumn get societyId => text().nullable().references(Societies, #id)();
  TextColumn get blockId => text().nullable().references(Blocks, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class PropertyComments extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Properties, #id)();
  TextColumn get companyId => text().nullable()();
  TextColumn get comment => text().check(comment.length.isSmallerOrEqualValue(500))();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class FilesTable extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  // Legacy name kept for backward compatibility; not used in new UI
  TextColumn get name => text()();
  // New fields
  TextColumn get clientName => text().nullable()();
  TextColumn get fileNo => text().nullable()();
  TextColumn get referenceNo => text().nullable()();
  IntColumn get demand => integer().nullable()();
  TextColumn get saleStatus => text().nullable()(); // 'Sale' or 'Not Sale'
  TextColumn get mobileNo => text().nullable()();
  TextColumn get cnic => text().nullable()();
  TextColumn get societyId => text().nullable().references(Societies, #id)();
  TextColumn get blockId => text().nullable().references(Blocks, #id)();
  TextColumn get path => text().nullable()();
  TextColumn get remarks => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class FileComments extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(FilesTable, #id)();
  TextColumn get companyId => text().nullable()();
  TextColumn get comment => text().check(comment.length.isSmallerOrEqualValue(500))();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class RentalItems extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get name => text()();
  IntColumn get price => integer().nullable()();
  TextColumn get remarks => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get contactNo => text().nullable()();
  TextColumn get cnic => text().nullable()();
  IntColumn get security => integer().nullable()();
  TextColumn get saleStatus => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class RentalComments extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(RentalItems, #id)();
  TextColumn get companyId => text().nullable()();
  TextColumn get comment => text().check(comment.length.isSmallerOrEqualValue(500))();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class WorkingProgress extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get status => text().nullable()();
  TextColumn get remarks => text().nullable()();
  TextColumn get fromUser => text().nullable()();
  TextColumn get toUser => text().nullable()();
  TextColumn get transferDate => text().nullable()();
  TextColumn get nextWorkingDate => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get source => text().nullable()(); // NEW: Source of the working progress entry
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class WorkingComments extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(WorkingProgress, #id)();
  TextColumn get companyId => text().nullable()();
  TextColumn get comment => text().check(comment.length.isSmallerOrEqualValue(500))();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Reminders extends Table {
  IntColumn get reminderId => integer().autoIncrement()();
  TextColumn get agentId => text().references(Users, #id)();
  TextColumn get companyId => text().nullable()();
  TextColumn get clientName => text().nullable()();
  TextColumn get clientPhone => text().nullable()();
  TextColumn get reminderTitle => text()();
  TextColumn get reminderDetails => text().nullable()();
  TextColumn get reminderDate => text()();
  TextColumn get reminderTime => text()();
  TextColumn get notificationStatus => text()();
  BoolColumn get is_active => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
}

class Reports extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get password => text().nullable()();
  TextColumn get filePath => text().nullable()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Deletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get module => text()();
  TextColumn get entityId => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get updatedAt => text()();
}

class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get direction => text()();
  TextColumn get module => text().nullable()();
  TextColumn get exportId => text().nullable()();
  TextColumn get fileName => text().nullable()();
  TextColumn get status => text()();
  TextColumn get error => text().nullable()();
  TextColumn get companyId => text().nullable()();
  TextColumn get startedAt => text()();
  TextColumn get finishedAt => text().nullable()();
  @override
  List<String> get customConstraints => [
        'UNIQUE(direction, module, export_id)'
      ];
}

class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get clientName => text()();
  TextColumn get clientContact => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get organization => text().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get size => text().nullable()();
  TextColumn get location => text().nullable()();
  IntColumn get budget => integer().nullable()();
  TextColumn get remarks => text().nullable()();
  TextColumn get date => text().nullable()();
  TextColumn get source => text().nullable()(); // 'Agent' or 'Direct'
  BoolColumn get is_active => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class Expenditures extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get category => text().nullable()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get kind => text().nullable()(); // 'office' | 'project'
  TextColumn get projectId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get officeMonth => text().nullable()(); // yyyy-MM
  TextColumn get categoryType => text().nullable()(); // 'office' | 'project'
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class ExpenditureSubItems extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Expenditures, #id)(); // Foreign key to main expenditure
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

class TradingFileEntries extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get type => text()(); // 'buy' or 'sell'
  TextColumn get date => text()();
  TextColumn get mobile => text().nullable()();
  TextColumn get personName => text().nullable()();
  TextColumn get estateName => text().nullable()();
  IntColumn get quantity => integer().nullable()();
  RealColumn get totalAmount => real().nullable()(); // payment for file entries
  TextColumn get status => text().withDefault(const Constant('Pending'))();
  TextColumn get comments => text().nullable()();
  TextColumn get updatedAt => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))(); // true = synced to cloud, false = pending sync
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Companies,
  Users,
  Societies,
  Blocks,
  Properties,
  PropertyComments,
  FilesTable,
  FileComments,
  RentalItems,
  RentalComments,
  WorkingProgress,
  WorkingComments,
  Reminders,
  Reports,
  Deletions,
  SyncLogs,
  Clients,
  Expenditures,
  ExpenditureSubItems,
  TradingFileEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  static Future<QueryExecutor> Function()? _openExecutor;
  static AppDatabase? _instance;
  static Future<AppDatabase>? _instanceFuture;

  static AppDatabase? get instanceIfInitialized => _instance;

  static void configureOpener(Future<QueryExecutor> Function() openExecutor) {
    _openExecutor = openExecutor;
  }

  static Future<AppDatabase> instance() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);

    final inFlight = _instanceFuture;
    if (inFlight != null) return inFlight;

    final opener = _openExecutor;
    if (opener == null) {
      return Future.error(StateError('AppDatabase opener not configured. Call AppDatabase.configureOpener() from the app before using AppDatabase.instance().'));
    }

    final created = opener().then((executor) {
      final db = AppDatabase(executor);
      _instance = db;
      return db;
    }).catchError((e) {
      _instanceFuture = null;
      throw e;
    });
    _instanceFuture = created;
    return created;
  }

  static Future<void> closeInstance() async {
    final db = _instance;
    _instance = null;
    _instanceFuture = null;
    await db?.close();
  }

  /// Development mode: Reset database to ensure fresh schema
  /// WARNING: This will delete all local data. Use only in development!
  static Future<void> resetDatabaseInDevMode() async {
    try {
      // Check if we're in debug mode
      bool isDebugMode = false;
      assert(isDebugMode = true);
      
      if (!isDebugMode) {
        print('[DB] Database reset only allowed in debug mode');
        return;
      }
      
      print('[DB] Resetting database in development mode...');
      
      // Close existing instance
      await closeInstance();
      
      // Get the database file path using path_provider
      try {
        final appDir = await getApplicationSupportDirectory();
        final dbFile = File(p.join(appDir.path, 'data.sqlite'));
        print('[DB] Deleting database file: ${dbFile.path}');
        
        // Delete the database file
        if (await dbFile.exists()) {
          await dbFile.delete();
          print('[DB] Database file deleted successfully');
        } else {
          print('[DB] Database file not found, no deletion needed');
        }
      } catch (e) {
        print('[DB] Error accessing database file: $e');
      }
      
      print('[DB] Database reset completed. Next app start will create fresh database.');
    } catch (e) {
      print('[DB] Error resetting database: $e');
    }
  }

  @override
  int get schemaVersion => 33;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createSoftDeleteTriggers(m.database);
          await _safeAddIsActiveColumns(m.database); // ensure active flags exist even on fresh installs
          await _safeAddUserProfileColumns(m.database); // ensure profile columns exist
          await _ensureBusinessTables(m.database); // create trading/expenditure tables on fresh installs
          // Create Companies table if not already created
          await m.database.customStatement(
            'CREATE TABLE IF NOT EXISTS companies ('
            'id TEXT NOT NULL PRIMARY KEY,'
            'name TEXT NOT NULL,'
            'status TEXT NOT NULL,'
            'metadata TEXT,'
            'max_user_limit INTEGER NOT NULL DEFAULT 5,'
            "subscription_tier TEXT NOT NULL DEFAULT 'Starter',"
            'created_at TEXT NOT NULL,'
            'updated_at TEXT NOT NULL'
            ')'
          );
          // Ensure reminders table matches latest schema
          await m.database.customStatement('DROP TABLE IF EXISTS reminders');
          await m.database.customStatement(
            'CREATE TABLE reminders ('
            'reminder_id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'agent_id TEXT NOT NULL,'
            'company_id TEXT,'
            'client_name TEXT,'
            'client_phone TEXT,'
            'reminder_title TEXT NOT NULL,'
            'reminder_details TEXT,'
            'reminder_date TEXT NOT NULL,'
            'reminder_time TEXT NOT NULL,'
            'notification_status TEXT NOT NULL,'
            'is_active INTEGER NOT NULL DEFAULT 1,'
            'is_synced INTEGER NOT NULL DEFAULT 1,'
            'created_at TEXT NOT NULL,'
            'updated_at TEXT NOT NULL,'
            'FOREIGN KEY(agent_id) REFERENCES users(id)'
            ')'
          );
        },
        beforeOpen: (details) async {
          // Ensure business tables exist even when version is unchanged or DB was manually deleted
          await _ensureBusinessTables(this);
          
          // Ensure reminders table has company_id column for existing databases
          try {
            await this.customStatement('ALTER TABLE reminders ADD COLUMN company_id TEXT');
          } catch (e) {
            // Column might already exist, ignore error
          }
          
          // Ensure trading_entries table has created_by column for existing databases
          try {
            await this.customStatement('ALTER TABLE trading_entries ADD COLUMN created_by TEXT');
          } catch (e) {
            // Column might already exist, ignore error
          }
        },
        onUpgrade: (m, from, to) async {
          // Always make sure core business tables exist after upgrades too
          await _ensureBusinessTables(m.database);
          // v1 -> v2: ensure deletions exists and add transfer fields to working_progress
          if (from <= 1) {
            await m.createTable(deletions);
          }
          if (from < 2) {
            await m.database.customStatement('ALTER TABLE working_progress ADD COLUMN from_user TEXT');
            await m.database.customStatement('ALTER TABLE working_progress ADD COLUMN to_user TEXT');
            await m.database.customStatement('ALTER TABLE working_progress ADD COLUMN transfer_date TEXT');
          }
          if (from < 3) {
            // Add new columns to files_table for extended metadata
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN client_name TEXT');
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN file_no TEXT');
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN reference_no TEXT');
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN demand INTEGER');
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN sale_status TEXT');
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN mobile_no TEXT');
            // Add corresponding columns to properties
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN client_name TEXT');
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN file_no TEXT');
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN reference_no TEXT');
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN demand INTEGER');
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN sale_status TEXT');
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN mobile_no TEXT');
          }
          if (from < 4) {
            await m.database.customStatement('DROP TABLE IF EXISTS reminders');
            await m.database.customStatement(
              'CREATE TABLE reminders ('
              'reminder_id INTEGER PRIMARY KEY AUTOINCREMENT,'
              'agent_id TEXT NOT NULL,'
              'client_name TEXT,'
              'client_phone TEXT,'
              'reminder_title TEXT NOT NULL,'
              'reminder_details TEXT,'
              'reminder_date TEXT NOT NULL,'
              'reminder_time TEXT NOT NULL,'
              'notification_status TEXT NOT NULL,'
              'is_synced INTEGER NOT NULL DEFAULT 1,'
              'created_at TEXT NOT NULL,'
              'updated_at TEXT NOT NULL,'
              'FOREIGN KEY(agent_id) REFERENCES users(id)'
              ')'
            );
          }
          if (from < 5) {
            await m.database.customStatement('ALTER TABLE rental_items ADD COLUMN location TEXT');
          }
          if (from < 6) {
            await m.database.customStatement('ALTER TABLE rental_items ADD COLUMN owner_name TEXT');
            await m.database.customStatement('ALTER TABLE rental_items ADD COLUMN contact_no TEXT');
            await m.database.customStatement('ALTER TABLE rental_items ADD COLUMN security INTEGER');
            await m.database.customStatement('ALTER TABLE rental_items ADD COLUMN sale_status TEXT');
          }
          if (from < 7) {
            await m.database.customStatement('ALTER TABLE properties ADD COLUMN cnic TEXT');
            await m.database.customStatement('ALTER TABLE files_table ADD COLUMN cnic TEXT');
            await m.database.customStatement('ALTER TABLE rental_items ADD COLUMN cnic TEXT');
          }
          // Note: SQLite doesn't support DROP COLUMN, so mobile_no column will remain in database
          // but will not be used in the Properties table schema going forward
          if (from < 8) {
            // Schema version 8: Removed mobileNo from Properties table
            // The column remains in the database but is no longer part of the schema
          }
          if (from < 9) {
            // Schema version 9: Add Clients table
            await m.createTable(clients);
          }
          if (from < 10) {
            // Schema version 10: Add next_working_date column to working_progress table
            try {
              await m.database.customStatement('ALTER TABLE working_progress ADD COLUMN next_working_date TEXT');
            } catch (e) {
              // Column might already exist, ignore error
            }
          }
          if (from < 11) {
            // Schema version 11: Add category column to working_progress table
            try {
              await m.database.customStatement('ALTER TABLE working_progress ADD COLUMN category TEXT');
            } catch (e) {
              // Column might already exist, ignore error
            }
          }
          if (from < 12) {
            // Schema version 12: Add name, email, contactNo, permissions columns to users table
            try {
              await m.database.customStatement('ALTER TABLE users ADD COLUMN name TEXT');
              await m.database.customStatement('ALTER TABLE users ADD COLUMN email TEXT');
              await m.database.customStatement('ALTER TABLE users ADD COLUMN contact_no TEXT');
              await m.database.customStatement('ALTER TABLE users ADD COLUMN permissions TEXT');
            } catch (e) {
              // Columns might already exist, ignore error
            }
          }
          if (from < 13) {
            // Schema version 13: Add Companies table and companyId to users
            try {
              // Create Companies table using SQL
                await m.database.customStatement(
                  'CREATE TABLE IF NOT EXISTS companies ('
                  'id TEXT NOT NULL PRIMARY KEY,'
                  'name TEXT NOT NULL,'
                  'status TEXT NOT NULL,'
                  'metadata TEXT,'
                  'max_user_limit INTEGER NOT NULL DEFAULT 5,'
                  "subscription_tier TEXT NOT NULL DEFAULT 'Starter',"
                  'created_at TEXT NOT NULL,'
                  'updated_at TEXT NOT NULL'
                  ')'
                );
              await m.database.customStatement('ALTER TABLE users ADD COLUMN company_id TEXT');
              await m.database.customStatement('ALTER TABLE users ADD COLUMN status TEXT');
            } catch (e) {
              // Columns might already exist, ignore error
            }
          }
          if (from < 14) {
            // Schema version 14: Add is_first_login column to users table
            try {
              await m.database.customStatement('ALTER TABLE users ADD COLUMN is_first_login INTEGER DEFAULT 1');
            } catch (e) {
              // Column might already exist, ignore error
            }
          }

          if (from < 15) {
            // Schema version 15: Add company_id to tenant-owned tables
            final statements = <String>[
              'ALTER TABLE societies ADD COLUMN company_id TEXT',
              'ALTER TABLE blocks ADD COLUMN company_id TEXT',
              'ALTER TABLE properties ADD COLUMN company_id TEXT',
              'ALTER TABLE property_comments ADD COLUMN company_id TEXT',
              'ALTER TABLE files_table ADD COLUMN company_id TEXT',
              'ALTER TABLE file_comments ADD COLUMN company_id TEXT',
              'ALTER TABLE rental_items ADD COLUMN company_id TEXT',
              'ALTER TABLE rental_comments ADD COLUMN company_id TEXT',
              'ALTER TABLE working_progress ADD COLUMN company_id TEXT',
              'ALTER TABLE working_comments ADD COLUMN company_id TEXT',
              'ALTER TABLE reminders ADD COLUMN company_id TEXT',
              'ALTER TABLE reminders ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE reports ADD COLUMN company_id TEXT',
              'ALTER TABLE deletions ADD COLUMN company_id TEXT',
              'ALTER TABLE sync_logs ADD COLUMN company_id TEXT',
              'ALTER TABLE clients ADD COLUMN company_id TEXT',
            ];

            for (final stmt in statements) {
              try {
                await m.database.customStatement(stmt);
              } catch (e) {
                // Column might already exist, ignore error
              }
            }
          }

          if (from < 16) {
            try {
              await m.database.customStatement('ALTER TABLE companies ADD COLUMN max_user_limit INTEGER NOT NULL DEFAULT 5');
            } catch (e) {
              // Column might already exist, ignore error
            }
          }

          if (from < 17) {
            try {
              await m.database.customStatement("ALTER TABLE companies ADD COLUMN subscription_tier TEXT NOT NULL DEFAULT 'Starter'");
            } catch (e) {
              // Column might already exist, ignore error
            }
          }

          if (from < 18) {
            // Schema version 18: Add employee_id to users
            try {
              await m.database.customStatement('ALTER TABLE users ADD COLUMN employee_id TEXT');
            } catch (e) {
              // Column might already exist, ignore error
            }
          }

          if (from < 19) {
            final statements = <String>[
              'ALTER TABLE files_table ADD COLUMN created_by TEXT',
              'ALTER TABLE properties ADD COLUMN created_by TEXT',
              'ALTER TABLE rental_items ADD COLUMN created_by TEXT',
              'ALTER TABLE clients ADD COLUMN created_by TEXT',
            ];

            for (final stmt in statements) {
              try {
                await m.database.customStatement(stmt);
              } catch (e) {
                // Column might already exist, ignore error
              }
            }
          }

          if (from < 20) {
            try {
              await m.database.customStatement('ALTER TABLE users ADD COLUMN user_id TEXT');
            } catch (e) {
              // Column might already exist, ignore error
            }
            try {
              await m.database.customStatement('ALTER TABLE users ADD COLUMN created_at TEXT');
            } catch (e) {
              // Column might already exist, ignore error
            }

            // Backfill created_at from updated_at when missing.
            try {
              await m.database.customStatement(
                "UPDATE users SET created_at = updated_at WHERE created_at IS NULL OR TRIM(created_at) = ''",
              );
            } catch (_) {}

            // Normalize legacy IDs: If user_id is empty but employee_id exists, copy it first.
            try {
              await m.database.customStatement(
                "UPDATE users SET user_id = employee_id WHERE (user_id IS NULL OR TRIM(user_id) = '') AND employee_id IS NOT NULL AND TRIM(employee_id) != ''",
              );
            } catch (_) {}

            // Convert any non-USR IDs and generate missing ones in Dart for per-company sequencing.
            try {
              final rows = await m.database.customSelect(
                'SELECT id, company_id, user_id FROM users',
              ).get();

              final year = DateTime.now().year;

              final maxSeqByCompany = <String, int>{};
              final usedByCompany = <String, Set<String>>{};

              int _extractSeq(String raw) {
                final v = raw.trim().toUpperCase();
                final mUsr = RegExp(r'^USR-(\\d{4})-(\\d{1,6})$').firstMatch(v);
                if (mUsr != null) {
                  final seq = int.tryParse(mUsr.group(2) ?? '');
                  return seq ?? 0;
                }
                final mLegacy = RegExp(r'^(?:RE-|USR-)?(\\d{1,6})$').firstMatch(v.replaceAll('RE-', '').replaceAll('USR-', ''));
                if (mLegacy != null) {
                  final seq = int.tryParse(mLegacy.group(1) ?? '');
                  return seq ?? 0;
                }
                return 0;
              }

              // First pass: collect current max seq per company and used IDs.
              for (final r in rows) {
                final row = r.data;
                final companyId = (row['company_id'] ?? '').toString();
                final rawUserId = (row['user_id'] ?? '').toString();

                final used = usedByCompany.putIfAbsent(companyId, () => <String>{});
                if (rawUserId.trim().isNotEmpty) {
                  used.add(rawUserId.trim().toUpperCase());
                }

                final seq = _extractSeq(rawUserId);
                final currentMax = maxSeqByCompany[companyId] ?? 0;
                if (seq > currentMax) maxSeqByCompany[companyId] = seq;
              }

              // Second pass: convert/generate.
              for (final r in rows) {
                final row = r.data;
                final id = (row['id'] ?? '').toString();
                if (id.trim().isEmpty) continue;

                final companyId = (row['company_id'] ?? '').toString();
                final rawUserId = (row['user_id'] ?? '').toString();
                final normalized = rawUserId.trim().toUpperCase();

                String? nextUserId;

                if (normalized.isEmpty) {
                  final maxNow = maxSeqByCompany[companyId] ?? 0;
                  var seq = maxNow + 1;
                  final used = usedByCompany.putIfAbsent(companyId, () => <String>{});
                  while (used.contains('USR-$year-${seq.toString().padLeft(3, '0')}')) {
                    seq++;
                  }
                  nextUserId = 'USR-$year-${seq.toString().padLeft(3, '0')}';
                  maxSeqByCompany[companyId] = seq;
                  used.add(nextUserId);
                } else if (!normalized.startsWith('USR-')) {
                  final seq = _extractSeq(normalized);
                  if (seq > 0) {
                    nextUserId = 'USR-$year-${seq.toString().padLeft(3, '0')}';
                  }
                }

                if (nextUserId != null && nextUserId.trim().isNotEmpty) {
                  await m.database.customStatement(
                    'UPDATE users SET user_id = ? WHERE id = ?',
                    [nextUserId, id],
                  );
                }
              }
            } catch (_) {
              // ignore backfill failures
            }
          }

          if (from < 21) {
            final statements = <String>[
              'ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE properties ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE files_table ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE rental_items ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE working_progress ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE societies ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE blocks ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE reminders ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
            ];

            for (final stmt in statements) {
              try {
                await m.database.customStatement(stmt);
              } catch (_) {
                // Column might already exist; ignore errors to keep migration idempotent
              }
            }

            await _createSoftDeleteTriggers(m.database);
          }
          if (from < 22) {
            await _safeAddIsActiveColumns(m.database);
          }
          if (from < 23) {
            await _safeAddUserProfileColumns(m.database);
          }
          if (from < 24) {
            await _safeAddIsSyncedColumns(m.database);
          }
          if (from < 25) {
            await _safeAddIsActiveColumnsToBusinessTables(m.database);
          }
          if (from < 26) {
            // Ensure is_active columns exist in reminders and clients tables
            await _safeAddIsActiveColumns(m.database);
          }
          if (from < 27) {
            // Schema version 27: Add is_synced column to reminders table
            try {
              await m.database.customStatement('ALTER TABLE reminders ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1');
            } catch (e) {
              // Column might already exist, ignore error
            }
          }
          if (from < 29) {
            // Schema version 29: Ensure trading_entries table has all required columns
            print('[MIGRATION] Version 29: Ensuring trading_entries table has all required columns');
            try {
              // Add missing columns to trading_entries table if they don't exist
              final columnsToAdd = [
                'ALTER TABLE trading_entries ADD COLUMN person_name TEXT NOT NULL DEFAULT \'\'',
                'ALTER TABLE trading_entries ADD COLUMN mobile_no TEXT NOT NULL DEFAULT \'\'',
                'ALTER TABLE trading_entries ADD COLUMN estate_name TEXT NOT NULL DEFAULT \'\'',
                'ALTER TABLE trading_entries ADD COLUMN unit_price REAL NOT NULL DEFAULT 0',
                'ALTER TABLE trading_entries ADD COLUMN image_path TEXT',
                'ALTER TABLE trading_entries ADD COLUMN company_id TEXT NOT NULL DEFAULT \'\'',
                'ALTER TABLE trading_entries ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
                'ALTER TABLE trading_entries ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1',
                'ALTER TABLE trading_entries ADD COLUMN created_at TEXT NOT NULL DEFAULT \'\'',
                'ALTER TABLE trading_entries ADD COLUMN updated_at TEXT NOT NULL DEFAULT \'\'',
                'ALTER TABLE trading_entries ADD COLUMN created_by TEXT',
              ];
              
              for (final stmt in columnsToAdd) {
                try {
                  await m.database.customStatement(stmt);
                  print('[MIGRATION] Added column: ${stmt.split('ADD COLUMN')[1]}');
                } catch (e) {
                  // Column might already exist, ignore error
                  print('[MIGRATION] Column already exists: ${stmt.split('ADD COLUMN')[1]}');
                }
              }
              
              // Backfill existing records with default values
              try {
                final now = DateTime.now().toIso8601String();
                await m.database.customStatement('''
                  UPDATE trading_entries SET 
                    person_name = COALESCE(person_name, ''),
                    mobile_no = COALESCE(mobile_no, ''),
                    estate_name = COALESCE(estate_name, ''),
                    unit_price = COALESCE(unit_price, 0),
                    image_path = COALESCE(image_path, ''),
                    company_id = COALESCE(company_id, ''),
                    is_active = COALESCE(is_active, 1),
                    is_synced = COALESCE(is_synced, 1),
                    created_at = COALESCE(created_at, '$now'),
                    updated_at = COALESCE(updated_at, '$now')
                  WHERE person_name IS NULL OR mobile_no IS NULL OR estate_name IS NULL OR unit_price IS NULL
                ''');
                print('[MIGRATION] Backfilled trading_entries table with default values');
              } catch (e) {
                print('[MIGRATION] Error backfilling trading_entries: $e');
              }
            } catch (e) {
              print('[MIGRATION] Error in version 29 migration: $e');
            }
          }
          if (from < 31) {
            // Schema version 31: Add extended fields to working_progress and trading_entries tables
            print('[MIGRATION] Version 31: Adding extended fields to working_progress and trading_entries tables');
            try {
              final columnsToAdd = [
                // Working progress columns
                'ALTER TABLE working_progress ADD COLUMN plot_no TEXT',
                'ALTER TABLE working_progress ADD COLUMN registry_number TEXT',
                'ALTER TABLE working_progress ADD COLUMN size TEXT',
                'ALTER TABLE working_progress ADD COLUMN client_mobile TEXT',
                // Trading entries columns
                'ALTER TABLE trading_entries ADD COLUMN trade_type TEXT NOT NULL DEFAULT \'Buy\'',
                'ALTER TABLE trading_entries ADD COLUMN category TEXT NOT NULL DEFAULT \'File\'',
              ];
              
              for (final stmt in columnsToAdd) {
                try {
                  await m.database.customStatement(stmt);
                  print('[MIGRATION] Added column: ${stmt.split(' ').last}');
                } catch (e) {
                  print('[MIGRATION] Column already exists or failed: $stmt - $e');
                }
              }
              
              // Backfill existing trading entries with default values
              try {
                await m.database.customStatement('''
                  UPDATE trading_entries SET 
                    trade_type = COALESCE(trade_type, 'Buy'),
                    category = COALESCE(category, 'File')
                  WHERE trade_type IS NULL OR category IS NULL
                ''');
                print('[MIGRATION] Backfilled trading_entries table with default trade_type and category');
              } catch (e) {
                print('[MIGRATION] Error backfilling trading_entries: $e');
              }
            } catch (e) {
              print('[MIGRATION] Failed to add extended fields: $e');
            }
          }
          if (from < 32) {
            // Schema version 32: Ensure trading entries has trade_type and category columns (safety migration)
            print('[MIGRATION] Version 32: Ensuring trading_entries has trade_type and category columns');
            try {
              final columnsToAdd = [
                'ALTER TABLE trading_entries ADD COLUMN trade_type TEXT NOT NULL DEFAULT \'Buy\'',
                'ALTER TABLE trading_entries ADD COLUMN category TEXT NOT NULL DEFAULT \'File\'',
              ];
              
              for (final stmt in columnsToAdd) {
                try {
                  await m.database.customStatement(stmt);
                  print('[MIGRATION] Version 32 - Added column: ${stmt.split(' ').last}');
                } catch (e) {
                  print('[MIGRATION] Version 32 - Column already exists: ${stmt.split(' ').last}');
                }
              }
              
              // Backfill existing trading entries with default values
              try {
                await m.database.customStatement('''
                  UPDATE trading_entries SET 
                    trade_type = COALESCE(trade_type, 'Buy'),
                    category = COALESCE(category, 'File')
                  WHERE trade_type IS NULL OR category IS NULL
                ''');
                print('[MIGRATION] Version 32 - Backfilled trading_entries table with default values');
              } catch (e) {
                print('[MIGRATION] Version 32 - Error backfilling trading_entries: $e');
              }
            } catch (e) {
              print('[MIGRATION] Version 32 - Failed to ensure trading entries columns: $e');
            }
          }
          if (from < 33) {
            // Schema version 33: Final safety check for trading entries columns
            print('[MIGRATION] Version 33: Final safety check for trading_entries columns');
            try {
              final columnsToAdd = [
                'ALTER TABLE trading_entries ADD COLUMN trade_type TEXT NOT NULL DEFAULT \'Buy\'',
                'ALTER TABLE trading_entries ADD COLUMN category TEXT NOT NULL DEFAULT \'File\'',
              ];
              
              for (final stmt in columnsToAdd) {
                try {
                  await m.database.customStatement(stmt);
                  print('[MIGRATION] Version 33 - Added column: ${stmt.split(' ').last}');
                } catch (e) {
                  print('[MIGRATION] Version 33 - Column already exists: ${stmt.split(' ').last}');
                }
              }
              
              // Final backfill
              try {
                await m.database.customStatement('''
                  UPDATE trading_entries SET 
                    trade_type = COALESCE(trade_type, 'Buy'),
                    category = COALESCE(category, 'File')
                  WHERE trade_type IS NULL OR category IS NULL
                ''');
                print('[MIGRATION] Version 33 - Final backfill completed');
              } catch (e) {
                print('[MIGRATION] Version 33 - Error in final backfill: $e');
              }
            } catch (e) {
              print('[MIGRATION] Version 33 - Failed final safety check: $e');
            }
          }
        },
      );
}

/// Ensures non-Drift business tables exist (trading & expenditure) for fresh DBs or after deletion.
Future<void> _ensureBusinessTables(dynamic db) async {
  // Support both GeneratedDatabase (customStatement) and raw QueryExecutor (runCustom)
  Future<void> run(String sql) async {
    if (db is GeneratedDatabase) {
      await db.customStatement(sql);
    } else if (db is QueryExecutor) {
      await db.runCustom(sql, const []);
    } else {
      throw ArgumentError('Unsupported db type for _ensureBusinessTables');
    }
  }

  // Trading entries - SIMPLIFIED TABLE WITH SPECIFIC FIELDS
  await run('''
    CREATE TABLE IF NOT EXISTS trading_entries (
      id TEXT PRIMARY KEY,
      entry_type TEXT NOT NULL, -- HP, KP, MP, NMP, NNMP, BOP, SOP, AEMP
      trade_type TEXT NOT NULL DEFAULT 'Buy', -- 'Buy' or 'Sell'
      category TEXT NOT NULL DEFAULT 'File', -- 'File' or 'Form'
      date TEXT NOT NULL,
      person_name TEXT NOT NULL,
      mobile_no TEXT NOT NULL,
      estate_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL DEFAULT 0, -- Unit price for calculation
      image_path TEXT,
      company_id TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active' -- Status field for filtering
    )
  ''');

  // Trading file entries - LEGACY TABLE FOR BACKWARD COMPATIBILITY
  await run('''
    CREATE TABLE IF NOT EXISTS trading_file_entries (
      id TEXT PRIMARY KEY,
      company_id TEXT,
      created_by TEXT,
      type TEXT NOT NULL, -- 'buy' or 'sell'
      date TEXT NOT NULL,
      mobile TEXT,
      person_name TEXT,
      estate_name TEXT,
      quantity INTEGER,
      total_amount REAL, -- payment for file entries
      status TEXT NOT NULL DEFAULT 'Pending',
      comments TEXT,
      updated_at TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 1
    )
  ''');

  // Expenditures
  await run('''
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
      is_active INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL
    )
  ''');

  // Expenditure projects
  await run('''
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

  // Expenditure sub-items
  await run('''
    CREATE TABLE IF NOT EXISTS expenditure_sub_items (
      id TEXT PRIMARY KEY,
      parent_id TEXT NOT NULL,
      company_id TEXT,
      created_by TEXT,
      description TEXT NOT NULL,
      amount REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(parent_id) REFERENCES expenditures(id)
    )
  ''');
}

/// Ensures is_active columns exist for business tables.
Future<void> _safeAddIsActiveColumnsToBusinessTables(GeneratedDatabase db) async {
  // Business tables live outside Drift schema; keep them in sync
  for (final stmt in [
    'ALTER TABLE trading_entries ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE trading_entries ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE trading_entries ADD COLUMN entry_type TEXT', 
    'ALTER TABLE trading_entries ADD COLUMN plot_no TEXT', 
    'ALTER TABLE trading_entries ADD COLUMN block TEXT',  
    'ALTER TABLE trading_entries ADD COLUMN commission REAL', 
    'ALTER TABLE trading_entries ADD COLUMN tax REAL', 
    'ALTER TABLE trading_entries ADD COLUMN rate REAL',
    'ALTER TABLE trading_entries ADD COLUMN unit_price REAL NOT NULL DEFAULT 0', // Unit price for calculation
    // Note: trading_file_entries table is now created with is_active and is_synced columns
    // No need to drop it - it's maintained for backward compatibility
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (e) {
      // Column might already exist, ignore error
    }
  }

  print('[MIGRATION] ensured is_active columns on business tables');

  // Backfill to active so existing records are considered active
  for (final stmt in [
    'UPDATE trading_entries SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE trading_entries SET unit_price = 0 WHERE unit_price IS NULL', // Set default unit price
    'UPDATE trading_file_entries SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE expenditures SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE expenditure_projects SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE expenditure_sub_items SET is_active = 1 WHERE is_active IS NULL',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }
}

/// Ensures is_synced columns exist for incremental sync functionality.
Future<void> _safeAddIsSyncedColumns(GeneratedDatabase db) async {
  // Core Drift tables
  for (final stmt in [
    'ALTER TABLE companies ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE users ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE societies ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE blocks ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE properties ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE files_table ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE rental_items ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE working_progress ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE reminders ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE clients ADD COLUMN is_synced INTEGER DEFAULT 1',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }

  // Business tables live outside Drift schema; keep them in sync
  for (final stmt in [
    'ALTER TABLE trading_entries ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE trading_file_entries ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE expenditures ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE expenditure_projects ADD COLUMN is_synced INTEGER DEFAULT 1',
    'ALTER TABLE expenditure_sub_items ADD COLUMN is_synced INTEGER DEFAULT 1',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }

  try {
    print('[MIGRATION] ensured is_synced columns on all tables for incremental sync');
  } catch (_) {}

  // Backfill to synced so existing records are considered synced
  for (final stmt in [
    'UPDATE companies SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE users SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE societies SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE blocks SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE properties SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE files_table SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE rental_items SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE working_progress SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE reminders SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE clients SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE trading_entries SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE trading_file_entries SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE expenditures SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE expenditure_projects SET is_synced = 1 WHERE is_synced IS NULL',
    'UPDATE expenditure_sub_items SET is_synced = 1 WHERE is_synced IS NULL',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }
}

/// Adds is_active columns to critical tables and backfills active rows.
Future<void> _safeAddIsActiveColumns(GeneratedDatabase db) async {
  // Core tables
  for (final stmt in [
    'ALTER TABLE companies ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE societies ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE blocks ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE properties ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE files_table ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE rental_items ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE working_progress ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE reminders ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE clients ADD COLUMN is_active INTEGER DEFAULT 1',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }

  // Trading tables live outside Drift schema; keep them in sync
  for (final stmt in [
    'ALTER TABLE trading_entries ADD COLUMN is_active INTEGER DEFAULT 1',
    'ALTER TABLE trading_file_entries ADD COLUMN is_active INTEGER DEFAULT 1',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }

  try {
    print('[MIGRATION] ensured is_active columns on core and trading tables');
  } catch (_) {}

  // Backfill to active so filtered queries don't hide existing rows
  for (final stmt in [
    'UPDATE companies SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE users SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE societies SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE blocks SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE properties SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE files_table SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE rental_items SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE working_progress SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE reminders SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE clients SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE trading_entries SET is_active = 1 WHERE is_active IS NULL',
    'UPDATE trading_file_entries SET is_active = 1 WHERE is_active IS NULL',
  ]) {
    try {
      await db.customStatement(stmt);
    } catch (_) {}
  }
}

/// Ensures user profile-related columns exist for backward compatibility.
Future<void> _safeAddUserProfileColumns(GeneratedDatabase db) async {
  const statements = [
    'ALTER TABLE users ADD COLUMN full_name TEXT',
    'ALTER TABLE users ADD COLUMN fullName TEXT',
    'ALTER TABLE users ADD COLUMN phone TEXT',
    'ALTER TABLE users ADD COLUMN company_name TEXT',
    'ALTER TABLE users ADD COLUMN profile_picture_path TEXT',
    'ALTER TABLE users ADD COLUMN role TEXT',
    'ALTER TABLE users ADD COLUMN company_id TEXT'
  ];

  for (final stmt in statements) {
    try {
      await db.customStatement(stmt);
    } catch (_) {
      // ignore if column already exists
    }
  }

  try {
    print('[MIGRATION] ensured user profile columns (full_name/fullName/phone/company_name/profile_picture_path/role/company_id)');
  } catch (_) {}

  // Backfill phone from contact_no where empty
  try {
    await db.customStatement(
        'UPDATE users SET phone = contact_no WHERE (phone IS NULL OR phone = "") AND contact_no IS NOT NULL AND contact_no <> ""');
  } catch (_) {}
}

Future<void> _createSoftDeleteTriggers(GeneratedDatabase db) async {
  const nowExpr = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";
  final triggers = <String>[
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_users
    BEFORE DELETE ON users
    BEGIN
      UPDATE users SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_properties
    BEFORE DELETE ON properties
    BEGIN
      UPDATE properties SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_files
    BEFORE DELETE ON files_table
    BEGIN
      UPDATE files_table SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_rental_items
    BEFORE DELETE ON rental_items
    BEGIN
      UPDATE rental_items SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_working_progress
    BEFORE DELETE ON working_progress
    BEGIN
      UPDATE working_progress SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_societies
    BEFORE DELETE ON societies
    BEGIN
      UPDATE societies SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_blocks
    BEFORE DELETE ON blocks
    BEGIN
      UPDATE blocks SET is_active = 0, updated_at = $nowExpr WHERE id = OLD.id;
      SELECT RAISE(IGNORE);
    END;
    ''',
    '''
    CREATE TRIGGER IF NOT EXISTS soft_delete_reminders
    BEFORE DELETE ON reminders
    BEGIN
      UPDATE reminders SET is_active = 0, updated_at = $nowExpr WHERE reminder_id = OLD.reminder_id;
      SELECT RAISE(IGNORE);
    END;
    ''',
  ];

  for (final trigger in triggers) {
    await db.customStatement(trigger);
  }
}
