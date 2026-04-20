import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'platform_utils.dart';

/// Universal UI utilities for cross-platform compatibility
class UIUtils {
  /// Returns platform-specific padding
  static EdgeInsets getPlatformPadding() {
    if (PlatformUtils.isMobile) {
      return const EdgeInsets.all(16.0);
    } else if (PlatformUtils.isDesktop) {
      return const EdgeInsets.all(24.0);
    } else {
      // Web
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
    }
  }

  /// Returns platform-specific margin
  static EdgeInsets getPlatformMargin() {
    if (PlatformUtils.isMobile) {
      return const EdgeInsets.all(8.0);
    } else if (PlatformUtils.isDesktop) {
      return const EdgeInsets.all(16.0);
    } else {
      // Web
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    }
  }

  /// Returns platform-specific button height
  static double getButtonHeight() {
    if (PlatformUtils.isMobile) {
      return 48.0;
    } else if (PlatformUtils.isDesktop) {
      return 40.0;
    } else {
      // Web
      return 44.0;
    }
  }

  /// Returns platform-specific icon size
  static double getIconSize() {
    if (PlatformUtils.isMobile) {
      return 24.0;
    } else if (PlatformUtils.isDesktop) {
      return 20.0;
    } else {
      // Web
      return 22.0;
    }
  }

  /// Returns platform-specific font size
  static double getFontSize(BuildContext context, FontSizeType type) {
    switch (type) {
      case FontSizeType.small:
        if (PlatformUtils.isMobile) return 14.0;
        if (PlatformUtils.isDesktop) return 12.0;
        return 13.0; // Web
      case FontSizeType.medium:
        if (PlatformUtils.isMobile) return 16.0;
        if (PlatformUtils.isDesktop) return 14.0;
        return 15.0; // Web
      case FontSizeType.large:
        if (PlatformUtils.isMobile) return 18.0;
        if (PlatformUtils.isDesktop) return 16.0;
        return 17.0; // Web
      case FontSizeType.extraLarge:
        if (PlatformUtils.isMobile) return 20.0;
        if (PlatformUtils.isDesktop) return 18.0;
        return 19.0; // Web
      case FontSizeType.title:
        if (PlatformUtils.isMobile) return 24.0;
        if (PlatformUtils.isDesktop) return 20.0;
        return 22.0; // Web
      case FontSizeType.heading:
        if (PlatformUtils.isMobile) return 28.0;
        if (PlatformUtils.isDesktop) return 24.0;
        return 26.0; // Web
    }
  }

  /// Returns platform-specific card elevation
  static double getCardElevation() {
    if (PlatformUtils.isMobile) {
      return 4.0;
    } else if (PlatformUtils.isDesktop) {
      return 2.0;
    } else {
      // Web
      return 3.0;
    }
  }

  /// Returns platform-specific border radius
  static double getBorderRadius() {
    if (PlatformUtils.isMobile) {
      return 12.0;
    } else if (PlatformUtils.isDesktop) {
      return 8.0;
    } else {
      // Web
      return 10.0;
    }
  }

  /// Returns platform-specific spacing
  static double getSpacing(SpacingType type) {
    switch (type) {
      case SpacingType.xs:
        return PlatformUtils.isDesktop ? 4.0 : 6.0;
      case SpacingType.sm:
        return PlatformUtils.isDesktop ? 6.0 : 8.0;
      case SpacingType.md:
        return PlatformUtils.isDesktop ? 8.0 : 12.0;
      case SpacingType.lg:
        return PlatformUtils.isDesktop ? 12.0 : 16.0;
      case SpacingType.xl:
        return PlatformUtils.isDesktop ? 16.0 : 24.0;
      case SpacingType.xxl:
        return PlatformUtils.isDesktop ? 24.0 : 32.0;
    }
  }

  /// Returns platform-specific text theme scaling
  static TextScale getTextScale(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    
    if (PlatformUtils.isMobile) {
      return TextScale(
        small: textScaleFactor * 0.9,
        medium: textScaleFactor,
        large: textScaleFactor * 1.1,
      );
    } else if (PlatformUtils.isDesktop) {
      return TextScale(
        small: textScaleFactor * 0.85,
        medium: textScaleFactor * 0.95,
        large: textScaleFactor,
      );
    } else {
      // Web
      return TextScale(
        small: textScaleFactor * 0.9,
        medium: textScaleFactor,
        large: textScaleFactor * 1.05,
      );
    }
  }

  /// Returns platform-specific layout constraints
  static BoxConstraints getLayoutConstraints(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    if (PlatformUtils.isMobile) {
      return BoxConstraints(
        maxWidth: screenSize.width,
        minWidth: 0,
        maxHeight: double.infinity,
      );
    } else if (PlatformUtils.isDesktop) {
      return BoxConstraints(
        maxWidth: screenSize.width * 0.9,
        minWidth: 600,
        maxHeight: double.infinity,
      );
    } else {
      // Web
      return BoxConstraints(
        maxWidth: screenSize.width * 0.95,
        minWidth: 400,
        maxHeight: double.infinity,
      );
    }
  }

  /// Returns platform-specific scrollbar configuration
  static ScrollbarThemeData getScrollbarTheme() {
    if (PlatformUtils.isMobile) {
      // Mobile typically doesn't show scrollbars by default
      return ScrollbarThemeData(
        thickness: MaterialStateProperty.all(4.0),
        radius: const Radius.circular(2.0),
        thumbColor: MaterialStateProperty.all(Colors.grey.withOpacity(0.5)),
      );
    } else {
      // Desktop and Web show more prominent scrollbars
      return ScrollbarThemeData(
        thickness: MaterialStateProperty.all(8.0),
        radius: const Radius.circular(4.0),
        thumbColor: MaterialStateProperty.all(Colors.grey.withOpacity(0.7)),
        trackColor: MaterialStateProperty.all(Colors.grey.withOpacity(0.2)),
      );
    }
  }

  /// Returns platform-specific hover effects
  static bool get showHoverEffects => !PlatformUtils.isMobile;

  /// Returns platform-specific cursor type
  static MouseCursor getCursorType(CursorType type) {
    if (PlatformUtils.isMobile) {
      return SystemMouseCursors.basic; // Mobile doesn't have cursors
    }
    
    switch (type) {
      case CursorType.pointer:
        return SystemMouseCursors.click;
      case CursorType.text:
        return SystemMouseCursors.text;
      case CursorType.move:
        return SystemMouseCursors.move;
      case CursorType.notAllowed:
        return SystemMouseCursors.forbidden;
      case CursorType.progress:
        return SystemMouseCursors.progress;
      case CursorType.wait:
        return SystemMouseCursors.wait;
      default:
        return SystemMouseCursors.basic;
    }
  }

  /// Returns platform-specific animation duration
  static Duration getAnimationDuration(AnimationType type) {
    switch (type) {
      case AnimationType.fast:
        return PlatformUtils.isMobile ? const Duration(milliseconds: 150) : const Duration(milliseconds: 100);
      case AnimationType.normal:
        return PlatformUtils.isMobile ? const Duration(milliseconds: 300) : const Duration(milliseconds: 200);
      case AnimationType.slow:
        return PlatformUtils.isMobile ? const Duration(milliseconds: 500) : const Duration(milliseconds: 300);
    }
  }

  /// Returns platform-specific dialog configuration
  static DialogConfiguration getDialogConfiguration(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    if (PlatformUtils.isMobile) {
      return DialogConfiguration(
        width: screenSize.width * 0.9,
        maxHeight: screenSize.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        borderRadius: 16.0,
      );
    } else if (PlatformUtils.isDesktop) {
      return DialogConfiguration(
        width: 600.0,
        maxHeight: screenSize.height * 0.8,
        padding: const EdgeInsets.all(24.0),
        borderRadius: 12.0,
      );
    } else {
      // Web
      return DialogConfiguration(
        width: screenSize.width * 0.8,
        maxHeight: screenSize.height * 0.8,
        padding: const EdgeInsets.all(20.0),
        borderRadius: 14.0,
      );
    }
  }

  /// Returns platform-specific navigation bar configuration
  static bool get useBottomNavigationBar => PlatformUtils.isMobile;

  /// Returns platform-specific drawer configuration
  static bool get useDrawer => !PlatformUtils.isMobile;

  /// Returns platform-specific floating action button configuration
  static FloatingActionButtonLocation getFabLocation() {
    if (PlatformUtils.isMobile) {
      return FloatingActionButtonLocation.endFloat;
    } else {
      return FloatingActionButtonLocation.endFloat;
    }
  }

  /// Returns platform-specific grid configuration
  static GridConfiguration getGridConfiguration(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    if (PlatformUtils.isMobile) {
      return GridConfiguration(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        spacing: 8.0,
      );
    } else if (PlatformUtils.isDesktop) {
      return GridConfiguration(
        crossAxisCount: (screenSize.width / 300).floor(),
        childAspectRatio: 1.2,
        spacing: 16.0,
      );
    } else {
      // Web
      return GridConfiguration(
        crossAxisCount: (screenSize.width / 280).floor(),
        childAspectRatio: 1.1,
        spacing: 12.0,
      );
    }
  }

  /// Returns platform-specific list tile configuration
  static ListTileConfiguration getListTileConfiguration() {
    return ListTileConfiguration(
      contentPadding: PlatformUtils.isMobile 
          ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0)
          : const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
      minVerticalPadding: PlatformUtils.isMobile ? 4.0 : 2.0,
      dense: PlatformUtils.isDesktop,
    );
  }
}

/// Font size types for platform-specific text scaling
enum FontSizeType {
  small,
  medium,
  large,
  extraLarge,
  title,
  heading,
}

/// Spacing types for platform-specific margins and padding
enum SpacingType {
  xs,
  sm,
  md,
  lg,
  xl,
  xxl,
}

/// Animation duration types
enum AnimationType {
  fast,
  normal,
  slow,
}

/// Cursor types for desktop platforms
enum CursorType {
  pointer,
  text,
  move,
  notAllowed,
  progress,
  wait,
  basic,
}

/// Text scale configuration
class TextScale {
  final double small;
  final double medium;
  final double large;

  const TextScale({
    required this.small,
    required this.medium,
    required this.large,
  });
}

/// Dialog configuration
class DialogConfiguration {
  final double width;
  final double maxHeight;
  final EdgeInsets padding;
  final double borderRadius;

  const DialogConfiguration({
    required this.width,
    required this.maxHeight,
    required this.padding,
    required this.borderRadius,
  });
}

/// Grid configuration
class GridConfiguration {
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const GridConfiguration({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.spacing,
  });
}

/// List tile configuration
class ListTileConfiguration {
  final EdgeInsets contentPadding;
  final double minVerticalPadding;
  final bool dense;

  const ListTileConfiguration({
    required this.contentPadding,
    required this.minVerticalPadding,
    required this.dense,
  });
}
