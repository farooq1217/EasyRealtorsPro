import 'package:drift/drift.dart' as d;
import 'schema.dart';

class AppDao {
  final AppDatabase db;
  AppDao(this.db);

  Future<void> deleteProperty(String id, {required String updatedAtIso}) async {
    await db.transaction(() async {
      await (db.update(db.properties)..where((t) => t.id.equals(id))).write(
        PropertiesCompanion(
          isActive: const d.Value(false),
          updatedAt: d.Value(updatedAtIso),
        ),
      );
    });
  }

  Future<void> deleteRentalItem(String id, {required String updatedAtIso}) async {
    await db.transaction(() async {
      await (db.update(db.rentalItems)..where((t) => t.id.equals(id))).write(
        RentalItemsCompanion(
          isActive: const d.Value(false),
          updatedAt: d.Value(updatedAtIso),
        ),
      );
    });
  }
}
