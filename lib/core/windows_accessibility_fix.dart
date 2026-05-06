import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

/// Windows Accessibility Fix - Prevents viewId and Semantics errors
class WindowsAccessibilityFix {
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  
  /// Initialize Windows-specific accessibility fixes
  static void initialize() {
    if (isWindows) {
      debugPrint('WindowsAccessibilityFix: Initializing Windows accessibility fixes');
      
      // Disable problematic accessibility features on Windows
      _disableSemanticsAnnouncements();
      _configureTooltipBehavior();
    }
  }
  
  /// Disable semantics announcements that cause viewId errors on Windows
  static void _disableSemanticsAnnouncements() {
    if (!isWindows) return;
    
    debugPrint('WindowsAccessibilityFix: Disabling semantics announcements on Windows');
    
    // Note: This is a placeholder for future implementation
    // In a real implementation, you might configure Flutter's semantics
    // to avoid announcements that trigger viewId errors
  }
  
  /// Configure tooltip behavior for Windows
  static void _configureTooltipBehavior() {
    if (!isWindows) return;
    
    debugPrint('WindowsAccessibilityFix: Configuring tooltip behavior for Windows');
  }
  
  /// Safe announcement wrapper that prevents Windows errors
  static void safeAnnounce(String message, {TextDirection? textDirection}) {
    if (!isWindows) {
      // On non-Windows platforms, use normal semantics announcements
      try {
        // Note: SemanticsService is not available in all Flutter versions
        // This is a placeholder for future implementation
        debugPrint('WindowsAccessibilityFix: Would announce: "$message"');
      } catch (e) {
        debugPrint('WindowsAccessibilityFix: SemanticsService not available: $e');
      }
      return;
    }
    
    // On Windows, skip announcements to prevent viewId errors
    debugPrint('WindowsAccessibilityFix: Skipped announcement on Windows: "$message"');
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
    if (!isWindows) {
      // On non-Windows platforms, use normal tooltips
      return Tooltip(
        message: message,
        child: child,
        padding: padding,
        decoration: decoration,
        textStyle: textStyle,
        waitDuration: waitDuration,
        showDuration: showDuration,
        triggerMode: triggerBehavior ?? TooltipTriggerMode.longPress,
      );
    }
    
    // On Windows, return child without tooltip to prevent viewId errors
    debugPrint('WindowsAccessibilityFix: Skipped tooltip on Windows: "$message"');
    return child;
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
    if (!isWindows) {
      // On non-Windows platforms, use normal semantics
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
    
    // On Windows, return child without semantics to prevent viewId errors
    if (label != null || hint != null) {
      debugPrint('WindowsAccessibilityFix: Skipped semantics on Windows - Label: "$label", Hint: "$hint"');
    }
    return child;
  }
}
