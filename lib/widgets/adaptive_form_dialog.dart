import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import '../core/utils/platform_utils.dart';
import 'adaptive_dialog.dart';

/// Adaptive form dialog that shows as bottom sheet on mobile and dialog on desktop
class AdaptiveFormDialog {
  /// Show adaptive form dialog
  static Future<Map<String, dynamic>?> show<T>({
    required BuildContext context,
    required String title,
    required List<FormFieldConfig> fields,
    String? confirmText,
    String? cancelText,
    bool barrierDismissible = true,
    Map<String, dynamic>? initialValues,
    Map<String, String>? Function(Map<String, dynamic>)? validator,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return AdaptiveDialog.show<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FormDialogContent(
        title: title,
        fields: fields,
        confirmText: confirmText,
        cancelText: cancelText,
        initialValues: initialValues,
        validator: validator,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
      barrierDismissible: barrierDismissible,
      maxWidth: kIsWeb ? 600 : 500,
    );
  }

  /// Show adaptive transfer form (example for your use case)
  static Future<Map<String, dynamic>?> showTransferForm({
    required BuildContext context,
    Map<String, dynamic>? initialValues,
  }) {
    return show<Map<String, dynamic>>(
      context: context,
      title: 'Add Transfer',
      fields: [
        FormFieldConfig(
          key: 'from',
          label: 'From',
          hintText: 'Enter source location',
          keyboardType: TextInputType.text,
          validator: (value) => value?.isEmpty == true ? 'Source is required' : null,
        ),
        FormFieldConfig(
          key: 'to',
          label: 'To',
          hintText: 'Enter destination',
          keyboardType: TextInputType.text,
          validator: (value) => value?.isEmpty == true ? 'Destination is required' : null,
        ),
        FormFieldConfig(
          key: 'amount',
          label: 'Amount',
          hintText: 'Enter amount',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty == true) return 'Amount is required';
            if (double.tryParse(value!) == null) return 'Enter a valid amount';
            return null;
          },
        ),
        FormFieldConfig(
          key: 'description',
          label: 'Description',
          hintText: 'Enter description',
          keyboardType: TextInputType.multiline,
          maxLines: 3,
          validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
        ),
      ],
      initialValues: initialValues,
      confirmText: 'Add Transfer',
      cancelText: 'Cancel',
    );
  }
}

/// Configuration for a form field
class FormFieldConfig {
  final String key;
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLines;
  final List<String>? dropdownItems;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextEditingController? controller;

  const FormFieldConfig({
    required this.key,
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines,
    this.dropdownItems,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
  });
}

/// Form dialog content widget
class _FormDialogContent extends StatefulWidget {
  final String title;
  final List<FormFieldConfig> fields;
  final String? confirmText;
  final String? cancelText;
  final Map<String, dynamic>? initialValues;
  final Map<String, String>? Function(Map<String, dynamic>)? validator;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const _FormDialogContent({
    super.key,
    required this.title,
    required this.fields,
    this.confirmText,
    this.cancelText,
    this.initialValues,
    this.validator,
    this.onConfirm,
    this.onCancel,
  });

  @override
  State<_FormDialogContent> createState() => _FormDialogContentState();
}

class _FormDialogContentState extends State<_FormDialogContent> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String?> _errors;
  late final GlobalKey<FormState> _formKey;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _controllers = {};
    _errors = {};
    
    // Initialize controllers with initial values
    for (final field in widget.fields) {
      _controllers[field.key] = TextEditingController(
        text: widget.initialValues?[field.key]?.toString() ?? '',
      );
      _errors[field.key] = null;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      
      try {
        // Collect form data
        final formData = <String, dynamic>{};
        for (final field in widget.fields) {
          final controller = _controllers[field.key]!;
          formData[field.key] = controller.text;
        }
        
        // Validate entire form
        if (widget.validator != null) {
          final validationErrors = widget.validator!(formData) ?? {};
          if (validationErrors.isNotEmpty) {
            setState(() {
              _errors.addAll(validationErrors);
            });
            return;
          }
        }
        
        // Call onConfirm callback
        widget.onConfirm?.call();
        
        // Return form data
        Navigator.of(context).pop(formData);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _handleCancel() {
    widget.onCancel?.call();
    Navigator.of(context).pop();
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
        
        // Form
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.fields.map((field) => _buildField(field)).toList(),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Actions
        Row(
          children: [
            if (widget.cancelText != null) ...[
              Expanded(
                child: TextButton(
                  onPressed: _isLoading ? null : _handleCancel,
                  child: Text(widget.cancelText!),
                ),
              ),
              if (widget.confirmText != null) const SizedBox(width: 12),
            ],
            if (widget.confirmText != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(widget.confirmText!),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildField(FormFieldConfig field) {
    final controller = _controllers[field.key]!;
    final errorText = _errors[field.key];
    
    if (field.dropdownItems != null) {
      // Dropdown field
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hintText,
            errorText: errorText,
            border: const OutlineInputBorder(),
            prefixIcon: field.prefixIcon,
            suffixIcon: field.suffixIcon,
          ),
          items: field.dropdownItems!.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: (value) {
            controller.text = value ?? '';
            setState(() {
              _errors[field.key] = null;
            });
          },
          validator: field.validator,
        ),
      );
    } else {
      // Text field
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          keyboardType: field.keyboardType,
          obscureText: field.obscureText,
          maxLines: field.maxLines ?? 1,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hintText,
            errorText: errorText,
            border: const OutlineInputBorder(),
            prefixIcon: field.prefixIcon,
            suffixIcon: field.suffixIcon,
          ),
          validator: (value) {
            // Clear error when user starts typing
            if (_errors[field.key] != null && (value?.isNotEmpty == true)) {
              setState(() {
                _errors[field.key] = null;
              });
            }
            return field.validator?.call(value);
          },
        ),
      );
    }
  }
}

/// Example usage widget showing how to use the adaptive form dialog
class AdaptiveFormExample extends StatelessWidget {
  const AdaptiveFormExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive Form Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await AdaptiveFormDialog.showTransferForm(
              context: context,
              initialValues: {
                'from': 'Warehouse A',
                'amount': '1000',
              },
            );
            
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Form submitted: $result'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Text('Show Transfer Form'),
        ),
      ),
    );
  }
}
