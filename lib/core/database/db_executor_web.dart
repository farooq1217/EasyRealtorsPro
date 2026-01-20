import 'package:drift/drift.dart';
import 'package:drift/web.dart';

Future<void> configureSqlite3ForWindows() async {
  // No-op for web
}

QueryExecutor openAppExecutor(String _) {
  return WebDatabase('desktop_admin');
}
