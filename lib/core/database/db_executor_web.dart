import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openAppExecutor(String _) {
  return WebDatabase('desktop_admin');
}
