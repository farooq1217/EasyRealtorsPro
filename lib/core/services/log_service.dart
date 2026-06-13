import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LogService {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/app_logs.txt');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('LogService init error: $e');
    }
  }

  static Future<void> write(String message) async {
    try {
      if (_logFile != null) {
        final entry = '[${DateTime.now()}] $message\n';
        await _logFile!.writeAsString(entry, mode: FileMode.append, flush: true);
      }
      debugPrint(message);
    } catch (e) {
      debugPrint('LogService write error: $e');
    }
  }
}
