import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

QueryExecutor openAppExecutor(String path) {
  return LazyDatabase(() async {
    final file = File(path);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    debugPrint('Creating SQLite database at: ${file.absolute.path}');
    
    // Use standard NativeDatabase - let the system handle SQLite
    return NativeDatabase(file);
  });
}
