import 'schema.dart';

class AppDao {
  final AppDatabase db;
  AppDao(this.db);

  Future<void> deleteProperty(String id, {required String updatedAtIso}) async {
    await db.transaction(() async {
      await (db.delete(db.properties)..where((t) => t.id.equals(id))).go();
      await db.into(db.deletions).insert(DeletionsCompanion.insert(
        module: 'properties',
        entityId: id,
        updatedAt: updatedAtIso,
      ));
    });
  }

  Future<void> deleteRentalItem(String id, {required String updatedAtIso}) async {
    await db.transaction(() async {
      await (db.delete(db.rentalItems)..where((t) => t.id.equals(id))).go();
      await db.into(db.deletions).insert(DeletionsCompanion.insert(
        module: 'rental_items',
        entityId: id,
        updatedAt: updatedAtIso,
      ));
    });
  }
}
