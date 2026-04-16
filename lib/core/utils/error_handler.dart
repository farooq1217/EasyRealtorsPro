import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Standardized error handling utility for EasyRealtorsPro
/// 
/// This utility provides:
/// - Consistent error handling patterns
/// - User-friendly error messages
/// - Developer-friendly logging
/// - Toast/SnackBar error display
class ErrorHandler {
  /// Handle errors with consistent logging and user feedback
  static void handle(
    Object error, {
    String? userMessage,
    String? operation,
    StackTrace? stackTrace,
    BuildContext? context,
    bool showSnackBar = true,
    String? tag,
  }) {
    // Log the error for developers
    final operationText = operation != null ? ' during $operation' : '';
    Logger.error(
      'Error occurred$operationText',
      tag: tag ?? 'ErrorHandler',
      error: error,
      stackTrace: stackTrace,
    );
    
    // Show user-friendly message if context is available
    if (context != null && showSnackBar) {
      _showUserFriendlyMessage(context, error, userMessage);
    }
  }
  
  /// Handle async errors with consistent logging and user feedback
  static Future<void> handleAsync(
    Future<void> Function() operation, {
    String? userMessage,
    String? operationName,
    BuildContext? context,
    bool showSnackBar = true,
    String? tag,
  }) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      handle(
        error,
        userMessage: userMessage,
        operation: operationName,
        stackTrace: stackTrace,
        context: context,
        showSnackBar: showSnackBar,
        tag: tag,
      );
    }
  }
  
  /// Execute synchronous operation with error handling
  static T execute<T>(
    T Function() operation, {
    String? userMessage,
    String? operationName,
    BuildContext? context,
    bool showSnackBar = true,
    String? tag,
    T? fallback,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handle(
        error,
        userMessage: userMessage,
        operation: operationName,
        stackTrace: stackTrace,
        context: context,
        showSnackBar: showSnackBar,
        tag: tag,
      );
      
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }
  
  /// Show user-friendly error message via SnackBar
  static void _showUserFriendlyMessage(
    BuildContext context,
    Object error,
    String? customMessage,
  ) {
    final message = customMessage ?? _getUserFriendlyMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();
    
    // Network related errors
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Network connection error. Please check your internet connection and try again.';
    }
    
    // Authentication errors
    if (errorString.contains('authentication') ||
        errorString.contains('unauthorized') ||
        errorString.contains('login') ||
        errorString.contains('password')) {
      return 'Authentication error. Please check your credentials and try again.';
    }
    
    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('access denied') ||
        errorString.contains('unauthorized')) {
      return 'Permission denied. You don\'t have access to perform this action.';
    }
    
    // Database errors
    if (errorString.contains('database') ||
        errorString.contains('sqlite') ||
        errorString.contains('query')) {
      return 'Database error. Please try again. If the problem persists, contact support.';
    }
    
    // File system errors
    if (errorString.contains('file') ||
        errorString.contains('path') ||
        errorString.contains('directory')) {
      return 'File system error. Please check your file permissions and try again.';
    }
    
    // Validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('required')) {
      return 'Invalid input. Please check your data and try again.';
    }
    
    // Default error message
    return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
  }
  
  /// Create a standardized try-catch wrapper
  static Future<T?> tryCatch<T>(
    Future<T> Function() operation, {
    String? userMessage,
    String? operationName,
    BuildContext? context,
    bool showSnackBar = true,
    String? tag,
    T? defaultValue,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handle(
        error,
        userMessage: userMessage,
        operation: operationName,
        stackTrace: stackTrace,
        context: context,
        showSnackBar: showSnackBar,
        tag: tag,
      );
      return defaultValue;
    }
  }
  
  /// Create a synchronous try-catch wrapper
  static T? tryCatchSync<T>(
    T Function() operation, {
    String? userMessage,
    String? operationName,
    BuildContext? context,
    bool showSnackBar = true,
    String? tag,
    T? defaultValue,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handle(
        error,
        userMessage: userMessage,
        operation: operationName,
        stackTrace: stackTrace,
        context: context,
        showSnackBar: showSnackBar,
        tag: tag,
      );
      return defaultValue;
    }
  }
}

/// Extension method for easier error handling on Futures
extension ErrorHandlingFutureExtension<T> on Future<T> {
  Future<T?> handleError({
    String? userMessage,
    String? operationName,
    BuildContext? context,
    bool showSnackBar = true,
    String? tag,
    T? defaultValue,
  }) {
    return ErrorHandler.tryCatch<T>(
      () => this,
      userMessage: userMessage,
      operationName: operationName,
      context: context,
      showSnackBar: showSnackBar,
      tag: tag,
      defaultValue: defaultValue,
    );
  }
}
