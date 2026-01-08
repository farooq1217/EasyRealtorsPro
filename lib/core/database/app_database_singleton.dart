import 'package:shared/shared.dart';

class AppDatabaseSingleton {
  static Future<AppDatabase> instance() async {
    return AppDatabase.instance();
  }

  static AppDatabase? get instanceIfInitialized => AppDatabase.instanceIfInitialized;

  static Future<void> close() async {
    await AppDatabase.closeInstance();
  }
}
