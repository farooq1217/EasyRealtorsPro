import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import '../core/utils/platform_utils.dart';

/// Adaptive dialog that shows as bottom sheet on mobile and dialog on desktop
class AdaptiveDialog {
  /// Show adaptive dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
    double? elevation,
    Color? backgroundColor,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    EdgeInsets? padding,
    double? borderRadius,
    double? maxWidth,
  }) {
    // Determine if we should use bottom sheet
    final useBottomSheet = _shouldUseBottomSheet(context);

    if (useBottomSheet) {
      return showModalBottomSheet<T>(
        context: context,
        builder: (context) => _buildBottomSheetContent(
          context,
          builder,
          borderRadius: borderRadius ?? 16,
          backgroundColor: backgroundColor,
          padding: padding,
        ),
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
        isScrollControlled: isScrollControlled,
        useSafeArea: useSafeArea,
        enableDrag: enableDrag,
      );
    } else {
      return showDialog<T>(
        context: context,
        builder: (context) => _buildDialogContent(
          context,
          builder,
          borderRadius: borderRadius ?? 12,
          backgroundColor: backgroundColor,
          padding: padding,
          maxWidth: maxWidth,
        ),
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
      );
    }
  }

  /// Show adaptive alert dialog
  static Future<bool?> showAlertDialog({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
    Color? confirmColor,
    Color? cancelColor,
    bool isDangerous = false,
  }) {
    return show<bool>(
      context: context,
      builder: (context) => AlertDialogContent(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        confirmColor: confirmColor,
        cancelColor: cancelColor,
        isDangerous: isDangerous,
      ),
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show adaptive confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    return show<bool>(
      context: context,
      builder: (context) => ConfirmationDialogContent(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show adaptive input dialog
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    required String labelText,
    String? hintText,
    String? initialValue,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? confirmText,
    String? cancelText,
    String? validatorText,
    bool barrierDismissible = true,
  }) {
    return show<String>(
      context: context,
      builder: (context) => InputDialogContent(
        title: title,
        labelText: labelText,
        hintText: hintText,
        initialValue: initialValue,
        keyboardType: keyboardType,
        obscureText: obscureText,
        confirmText: confirmText,
        cancelText: cancelText,
        validatorText: validatorText,
      ),
      barrierDismissible: barrierDismissible,
    );
  }

  /// Determine if bottom sheet should be used
  static bool _shouldUseBottomSheet(BuildContext context) {
    // Use bottom sheet on mobile platforms
    if (PlatformUtils.isMobile) return true;
    
    // Use bottom sheet on small screens
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.size.width < 600) return true;
    
    // Use bottom sheet on web with small screens
    if (kIsWeb && mediaQuery.size.width < 800) return true;
    
    return false;
  }

  /// Build bottom sheet content
  static Widget _buildBottomSheetContent(
    BuildContext context,
    WidgetBuilder builder, {
    double borderRadius = 16,
    Color? backgroundColor,
    EdgeInsets? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar for visual feedback
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Content
            Flexible(child: builder(context)),
          ],
        ),
      ),
    );
  }

  /// Build dialog content
  static Widget _buildDialogContent(
    BuildContext context,
    WidgetBuilder builder, {
    double borderRadius = 12,
    Color? backgroundColor,
    EdgeInsets? padding,
    double? maxWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? 500,
      ),
      child: Dialog(
        backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(24),
          child: builder(context),
        ),
      ),
    );
  }
}

/// Alert dialog content widget
class AlertDialogContent extends StatelessWidget {
  final String title;
  final String content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final Color? cancelColor;
  final bool isDangerous;

  const AlertDialogContent({
    super.key,
    required this.title,
    required this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.cancelColor,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        
        // Content
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        // Actions
        Row(
          children: [
            if (cancelText != null) ...[
              Expanded(
                child: TextButton(
                  onPressed: () {
                    onCancel?.call();
                    Navigator.of(context).pop(false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: cancelColor ?? Colors.grey,
                  ),
                  child: Text(cancelText!),
                ),
              ),
              if (confirmText != null) const SizedBox(width: 12),
            ],
            if (confirmText != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onConfirm?.call();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDangerous ? Colors.red : confirmColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirmText!),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Confirmation dialog content widget
class ConfirmationDialogContent extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ConfirmationDialogContent({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Icon(
          Icons.help_outline,
          size: 48,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16),
        
        // Title
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        
        // Message
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        // Actions
        Row(
          children: [
            if (cancelText != null) ...[
              Expanded(
                child: TextButton(
                  onPressed: () {
                    onCancel?.call();
                    Navigator.of(context).pop(false);
                  },
                  child: Text(cancelText!),
                ),
              ),
              if (confirmText != null) const SizedBox(width: 12),
            ],
            if (confirmText != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onConfirm?.call();
                    Navigator.of(context).pop(true);
                  },
                  child: Text(confirmText!),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Input dialog content widget
class InputDialogContent extends StatefulWidget {
  final String title;
  final String labelText;
  final String? hintText;
  final String? initialValue;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? confirmText;
  final String? cancelText;
  final String? validatorText;

  const InputDialogContent({
    super.key,
    required this.title,
    required this.labelText,
    this.hintText,
    this.initialValue,
    this.keyboardType,
    this.obscureText = false,
    this.confirmText,
    this.cancelText,
    this.validatorText,
  });

  @override
  State<InputDialogContent> createState() => _InputDialogContentState();
}

class _InputDialogContentState extends State<InputDialogContent> {
  late TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        // Input field
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return widget.validatorText ?? 'This field is required';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        
        // Actions
        Row(
          children: [
            if (widget.cancelText != null) ...[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.cancelText!),
                ),
              ),
              if (widget.confirmText != null) const SizedBox(width: 12),
            ],
            if (widget.confirmText != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      Navigator.of(context).pop(_controller.text);
                    }
                  },
                  child: Text(widget.confirmText!),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
