import 'package:drift/drift.dart';

import 'db_executor_io.dart' if (dart.library.html) 'db_executor_web.dart' as impl;

QueryExecutor openAppExecutor(String pathOrName) {
  return impl.openAppExecutor(pathOrName);
}
