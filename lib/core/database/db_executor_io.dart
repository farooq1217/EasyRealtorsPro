import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

QueryExecutor openAppExecutor(String path) {
  return LazyDatabase(() async {
    return NativeDatabase.createInBackground(File(path));
  });
}
