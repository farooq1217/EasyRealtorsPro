import 'package:drift/drift.dart';

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
  TextColumn get permissions => text().nullable()(); // JSON string storing permissions like {"role": "super_admin", "canView": true, "canAdd": false}
  TextColumn get companyId => text().nullable().references(Companies, #id)(); // null for Super Admin
  TextColumn get status => text().nullable()(); // 'active' or 'inactive'
  BoolColumn get isFirstLogin => boolean().withDefault(const Constant(true))(); // true for new Company Admins, forces password change
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text()();
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
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedAt => text()();
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
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
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
  TextColumn get updatedAt => text()();
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

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createSoftDeleteTriggers(m.database);
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
            'client_name TEXT,'
            'client_phone TEXT,'
            'reminder_title TEXT NOT NULL,'
            'reminder_details TEXT,'
            'reminder_date TEXT NOT NULL,'
            'reminder_time TEXT NOT NULL,'
            'notification_status TEXT NOT NULL,'
            'created_at TEXT NOT NULL,'
            'updated_at TEXT NOT NULL,'
            'FOREIGN KEY(agent_id) REFERENCES users(id)'
            ')'
          );
        },
        onUpgrade: (m, from, to) async {
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
        },
      );
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
