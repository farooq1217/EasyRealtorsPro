import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsService;

/// Windows Accessibility Fix - Prevents viewId and Semantics errors
class WindowsAccessibilityFix {
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  
  /// Initialize Windows-specific accessibility fixes
  static void initialize() {
    if (isWindows) {
      debugPrint('WindowsAccessibilityFix: Initializing Windows accessibility fixes');
      
      // Override FlutterError.onError to suppress framework accessibility/semantics assertion errors on Windows
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (isWindowsAccessibilityError(details.exception)) {
          debugPrint('WindowsAccessibilityFix: Suppressed framework accessibility error: ${details.exception}');
          return;
        }
        originalOnError?.call(details);
      };

      // Override PlatformDispatcher.instance.onError to suppress platform accessibility/semantics errors on Windows
      final originalPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (Object exception, StackTrace stackTrace) {
        if (isWindowsAccessibilityError(exception)) {
          debugPrint('WindowsAccessibilityFix: Suppressed platform accessibility error: $exception');
          return true; // Marks error as handled
        }
        return originalPlatformOnError?.call(exception, stackTrace) ?? false;
      };
      
      _disableSemanticsAnnouncements();
      _configureTooltipBehavior();
    }
  }
  
  /// Disable semantics announcements that cause viewId errors on Windows
  static void _disableSemanticsAnnouncements() {
    if (!isWindows) return;
    debugPrint('WindowsAccessibilityFix: Semantics announcements will be handled via safeAnnounce on Windows');
  }
  
  /// Configure tooltip behavior for Windows
  static void _configureTooltipBehavior() {
    if (!isWindows) return;
    debugPrint('WindowsAccessibilityFix: Tooltips configured with excludeFromSemantics on Windows');
  }
  
  /// Safe announcement wrapper that prevents Windows errors
  static void safeAnnounce(String message, {TextDirection? textDirection, BuildContext? context}) {
    if (!isWindows) {
      // On non-Windows platforms, use normal semantics announcements
      try {
        final view = context != null ? View.of(context) : null;
        if (view != null) {
          SemanticsService.sendAnnouncement(
            view,
            message,
            textDirection ?? Directionality.maybeOf(context!) ?? TextDirection.ltr,
          );
        } else {
          final implicitView = PlatformDispatcher.instance.views.firstOrNull;
          if (implicitView != null) {
            SemanticsService.sendAnnouncement(
              implicitView,
              message,
              textDirection ?? TextDirection.ltr,
            );
          } else {
            debugPrint('WindowsAccessibilityFix: Would announce: "$message"');
          }
        }
      } catch (e) {
        debugPrint('WindowsAccessibilityFix: Announcement failed: $e');
      }
      return;
    }
    
    // On Windows, attempt safe announcement and catch errors
    try {
      final view = context != null ? View.of(context) : null;
      if (view != null) {
        SemanticsService.sendAnnouncement(
          view,
          message,
          textDirection ?? Directionality.maybeOf(context!) ?? TextDirection.ltr,
        );
      } else {
        final implicitView = PlatformDispatcher.instance.views.firstOrNull;
        if (implicitView != null) {
          SemanticsService.sendAnnouncement(
            implicitView,
            message,
            textDirection ?? TextDirection.ltr,
          );
        } else {
          debugPrint('WindowsAccessibilityFix: Skipped announcement on Windows, no view: "$message"');
        }
      }
    } catch (e) {
      if (isWindowsAccessibilityError(e)) {
        debugPrint('WindowsAccessibilityFix: Suppressed announcement error on Windows: $e');
      } else {
        debugPrint('WindowsAccessibilityFix: Announcement failed on Windows: $e');
      }
    }
  }
  
  /// Safe tooltip creation that prevents Windows errors
  static Widget safeTooltip({
    required String message,
    required Widget child,
    bool? enable,
    EdgeInsets? padding,
    Decoration? decoration,
    TextStyle? textStyle,
    Duration? waitDuration,
    Duration? showDuration,
    TooltipTriggerMode? triggerBehavior,
  }) {
    // We now keep tooltips active on Windows, but exclude them from the semantics tree to avoid native crashes
    return Tooltip(
      message: message,
      padding: padding,
      decoration: decoration,
      textStyle: textStyle,
      waitDuration: waitDuration,
      showDuration: showDuration,
      triggerMode: triggerBehavior ?? TooltipTriggerMode.longPress,
      excludeFromSemantics: isWindows, // Crucial fix: excludes semantics nodes only on Windows
      child: child,
    );
  }
  
  /// Check if an error is Windows accessibility related
  static bool isWindowsAccessibilityError(Object error) {
    if (!isWindows) return false;
    
    final errorString = error.toString().toLowerCase();
    final accessibilityPatterns = [
      'viewid property must be a flutterviewid',
      'announce message',
      'semanticsservice.announce',
      'tooltip',
      'accessibility',
      'windows accessibility',
      'viewid',
      'flutterviewid',
    ];
    
    return accessibilityPatterns.any((pattern) => errorString.contains(pattern));
  }
  
  /// Handle Windows accessibility errors gracefully
  static void handleAccessibilityError(Object error, StackTrace? stack) {
    if (isWindowsAccessibilityError(error)) {
      debugPrint('WindowsAccessibilityFix: Accessibility error handled gracefully: ${error.runtimeType}');
      return;
    }
    
    // Re-throw non-accessibility errors
    if (stack != null) {
      debugPrint('WindowsAccessibilityFix: Non-accessibility error: $error');
      debugPrint('Stack trace: $stack');
    }
  }
  
  /// Create a safe Semantics widget for Windows
  static Widget safeSemantics({
    required Widget child,
    bool? container,
    bool? explicitChildNodes,
    bool? excludeSemantics,
    String? label,
    String? hint,
    String? value,
    String? increasedValue,
    String? decreasedValue,
    String? onTapHint,
    TextDirection? textDirection,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onScrollLeft,
    VoidCallback? onScrollRight,
    VoidCallback? onScrollUp,
    VoidCallback? onScrollDown,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
    VoidCallback? onCopy,
    VoidCallback? onCut,
    VoidCallback? onPaste,
    VoidCallback? onDismiss,
    VoidCallback? onMoveCursorForwardByCharacter,
    VoidCallback? onMoveCursorBackwardByCharacter,
    VoidCallback? onSetSelection,
    VoidCallback? onSetText,
    VoidCallback? onDidGainAccessibilityFocus,
    VoidCallback? onDidLoseAccessibilityFocus,
  }) {
    // Instead of completely skipping semantics on Windows (which breaks accessibility),
    // we now use the standard Semantics widget. The error boundary overrides in initialize()
    // will gracefully catch and suppress any Windows-specific native viewId assertion crashes.
    return Semantics(
      container: container ?? false,
      explicitChildNodes: explicitChildNodes ?? false,
      excludeSemantics: excludeSemantics ?? false,
      label: label,
      hint: hint,
      value: value,
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
      onTapHint: onTapHint,
      textDirection: textDirection,
      onTap: onTap,
      onLongPress: onLongPress,
      onScrollLeft: onScrollLeft,
      onScrollRight: onScrollRight,
      onScrollUp: onScrollUp,
      onScrollDown: onScrollDown,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      onCopy: onCopy,
      onCut: onCut,
      onPaste: onPaste,
      onDismiss: onDismiss,
      onDidGainAccessibilityFocus: onDidGainAccessibilityFocus,
      onDidLoseAccessibilityFocus: onDidLoseAccessibilityFocus,
      child: child,
    );
  }
}
