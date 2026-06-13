// Follow Up table schema
import 'package:drift/drift.dart';


class FollowUps extends Table {
  // Primary key
  TextColumn get id => text()();

  // Basic fields
  TextColumn get clientName => text()();
  DateTimeColumn get followUpDate => dateTime()();
  TextColumn get followUpTime => text()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get companyId => text()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync and soft‑delete flags
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
