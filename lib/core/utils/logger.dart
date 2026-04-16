import 'package:flutter/foundation.dart';

/// Log levels for categorizing messages
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Centralized logging utility for EasyRealtorsPro
/// 
/// This utility provides consistent logging across the application with:
/// - Debug/Release mode awareness
/// - Structured logging with levels
/// - Performance-optimized logging
/// - Easy filtering and searching
class Logger {
  static const String _defaultTag = 'EasyRealtorsPro';
  
  /// Main logging method - only logs in debug mode
  static void log(
    String message, {
    String? tag,
    LogLevel level = LogLevel.debug,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Only log in debug mode to avoid production overhead
    if (!kDebugMode) return;
    
    final effectiveTag = tag ?? _defaultTag;
    final timestamp = DateTime.now().toIso8601String();
    final levelString = level.name.toUpperCase();
    
    // Format: [TIMESTAMP] [LEVEL] [TAG] Message
    final formattedMessage = '[$timestamp] [$levelString] [$effectiveTag] $message';
    
    switch (level) {
      case LogLevel.debug:
      case LogLevel.info:
        debugPrint(formattedMessage);
        break;
      case LogLevel.warning:
        debugPrint('⚠️ $formattedMessage');
        break;
      case LogLevel.error:
        debugPrint('❌ $formattedMessage');
        if (error != null) {
          debugPrint('   Error: $error');
        }
        if (stackTrace != null) {
          debugPrint('   Stack trace: $stackTrace');
        }
        break;
    }
  }
  
  /// Convenience methods for different log levels
  static void debug(String message, {String? tag}) {
    log(message, tag: tag, level: LogLevel.debug);
  }
  
  static void info(String message, {String? tag}) {
    log(message, tag: tag, level: LogLevel.info);
  }
  
  static void warning(String message, {String? tag}) {
    log(message, tag: tag, level: LogLevel.warning);
  }
  
  static void error(String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      message,
      tag: tag,
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Performance logging for measuring operation duration
  static T measure<T>(
    String operation,
    T Function() operationFunc, {
    String? tag,
    LogLevel level = LogLevel.debug,
  }) {
    if (!kDebugMode) {
      return operationFunc();
    }
    
    final stopwatch = Stopwatch()..start();
    try {
      final result = operationFunc();
      stopwatch.stop();
      log(
        '$operation completed in ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
        level: level,
      );
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      log(
        '$operation failed after ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
        level: LogLevel.error,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Async performance logging
  static Future<T> measureAsync<T>(
    String operation,
    Future<T> Function() operationFunc, {
    String? tag,
    LogLevel level = LogLevel.debug,
  }) async {
    if (!kDebugMode) {
      return await operationFunc();
    }
    
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operationFunc();
      stopwatch.stop();
      log(
        '$operation completed in ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
        level: level,
      );
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      log(
        '$operation failed after ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
        level: LogLevel.error,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

/// Extension methods for easier logging on objects
extension LoggerExtensions on Object {
  void logDebug(String message) => Logger.debug(message, tag: runtimeType.toString());
  void logInfo(String message) => Logger.info(message, tag: runtimeType.toString());
  void logWarning(String message) => Logger.warning(message, tag: runtimeType.toString());
  void logError(String message, {Object? error, StackTrace? stackTrace}) => 
      Logger.error(message, tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
}
