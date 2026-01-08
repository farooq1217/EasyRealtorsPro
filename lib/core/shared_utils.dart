import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'services/auth_service.dart';
import '../responsive_widgets.dart';
import '../image_cache_service.dart';
import '../offline_sync_service.dart';

// Note: PermissionHelper and AppStorage are in main.dart and should be imported directly
// from '../main.dart' when needed

// Validation functions
String? validateCNIC(String? value) {
  if (value == null || value.trim().isEmpty) return 'CNIC is required';
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length != 13) return 'CNIC must be exactly 13 digits';
  return null;
}

String? validateFileNo(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 100) return 'Maximum 100 characters allowed';
  if (RegExp(r'[A-Za-z]').hasMatch(value)) return 'File No. cannot contain alphabets';
  return null;
}

String? validatePlotNo(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 100) return 'Maximum 100 characters allowed';
  if (RegExp(r'[A-Za-z]').hasMatch(value)) return 'Plot No. cannot contain alphabets';
  return null;
}

String? validateOwnerName(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 100) return 'Maximum 100 characters allowed';
  if (RegExp(r'[0-9]').hasMatch(value)) return 'Owner Name can only contain alphabets';
  return null;
}

String? validateMobileNo(String? value) {
  if (value == null || value.trim().isEmpty) return 'Mobile No. is required';
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length != 11) return 'Mobile No. must be exactly 11 digits';
  return null;
}

String? validateComment(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 200) return 'Maximum 200 characters allowed';
  return null;
}

String? validateContactNo(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length != 11) return 'Contact No. must be exactly 11 digits';
  return null;
}

String? validateClientName(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 100) return 'Maximum 100 characters allowed';
  if (RegExp(r'[0-9]').hasMatch(value)) return 'Client Name can only contain alphabets';
  return null;
}

String? validateClientMobileNo(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length != 11) return 'Client Mobile No. must be exactly 11 digits';
  return null;
}

String? validateRegistryTransferNo(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 50) return 'Maximum 50 characters allowed';
  if (RegExp(r'[^0-9]').hasMatch(value)) return 'Registry/Transfer No. can only contain digits';
  return null;
}

String? validateClientPhone(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length != 11) return 'Client Phone must be exactly 11 digits';
  return null;
}

String? validateEstateName(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 50) return 'Maximum 50 characters allowed';
  if (RegExp(r'[0-9]').hasMatch(value)) return 'Estate Name cannot contain digits';
  return null;
}

String? validateQuantity(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 50) return 'Maximum 50 characters allowed';
  return null;
}

String? validatePrice(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.length > 100) return 'Maximum 100 characters allowed';
  if (RegExp(r'[^0-9]').hasMatch(value)) return 'Price can only contain digits';
  return null;
}

// Input formatters
final FilteringTextInputFormatter cnicFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));
final FilteringTextInputFormatter fileNoFormatter = FilteringTextInputFormatter.allow(RegExp(r'[^A-Za-z]'));
final FilteringTextInputFormatter plotNoFormatter = FilteringTextInputFormatter.allow(RegExp(r'[^A-Za-z]'));
final FilteringTextInputFormatter ownerNameFormatter = FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\s]'));
final FilteringTextInputFormatter mobileNoFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));
final FilteringTextInputFormatter commentFormatter = FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s.,!?;:\-()]'));
final FilteringTextInputFormatter clientNameFormatter = FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\s]'));
final FilteringTextInputFormatter registryTransferNoFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));
final FilteringTextInputFormatter estateNameFormatter = FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\s]'));
final FilteringTextInputFormatter priceFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

// ============================================================================
// PASSWORD VALIDATION
// ============================================================================
String? validatePassword(String? password) {
  if (password == null || password.isEmpty) {
    return 'Password is required';
  }
  
  // Check length (8-16 characters)
  if (password.length < 8 || password.length > 16) {
    return 'Password must be between 8 and 16 characters';
  }
  
  // Check for at least 1 uppercase letter
  if (!password.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain at least 1 uppercase letter';
  }
  
  // Check for at least 1 lowercase letter
  if (!password.contains(RegExp(r'[a-z]'))) {
    return 'Password must contain at least 1 lowercase letter';
  }
  
  // Check for at least 1 numeric digit
  if (!password.contains(RegExp(r'[0-9]'))) {
    return 'Password must contain at least 1 numeric digit';
  }
  
  // Check for at least 1 special character
  if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    return 'Password must contain at least 1 special character (@, #, \$, %, etc.)';
  }
  
  return null; // Password is valid
}

// ============================================================================
// SUBSCRIPTION TIER HELPERS
// ============================================================================
String normalizeSubscriptionTier(Object? v) {
  final s = (v ?? '').toString().trim();
  if (s.isEmpty) return 'Starter';
  final lower = s.toLowerCase();
  if (lower == 'starter') return 'Starter';
  if (lower == 'professional') return 'Professional';
  if (lower == 'business') return 'Business';
  if (lower == 'enterprise') return 'Enterprise';
  return 'Starter';
}

int subscriptionLimitForTier(String tier, {int? enterpriseLimit}) {
  final t = normalizeSubscriptionTier(tier);
  switch (t) {
    case 'Professional':
      return 10;
    case 'Business':
      return 15;
    case 'Enterprise':
      final v = enterpriseLimit ?? 15;
      if (v < 15) return 15;
      if (v > 50) return 50;
      return v;
    case 'Starter':
    default:
      return 5;
  }
}

// ============================================================================
// TIME PICKER
// ============================================================================
Future<TimeOfDay?> showCustomTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) async {
  return await showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFFFF6B35), // Orange
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.grey.shade800,
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      );
    },
  );
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

/// Top-right search widget for app bars
class TopRightSearch extends StatefulWidget {
  final void Function(String query)? onChanged;
  final String? hintText;
  const TopRightSearch({super.key, this.onChanged, this.hintText});
  
  @override
  State<TopRightSearch> createState() => _TopRightSearchState();
}

class _TopRightSearchState extends State<TopRightSearch> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Compact width that scales a bit with screen size
    final boxWidth = width < 700 ? 180.0 : width < 1000 ? 220.0 : 260.0;
    return SizedBox(
      width: boxWidth,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                )
              : null,
          hintText: widget.hintText ?? 'Search...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF252A32)
              : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.grey.shade900,
        ),
        onChanged: (value) {
          setState(() {}); // Rebuild to show/hide clear button
          widget.onChanged?.call(value);
        },
      ),
    );
  }
}

/// Info entry class for building responsive info rows
class InfoEntry {
  final String label;
  final Object? value;
  final TextStyle? style;

  const InfoEntry(this.label, this.value, {this.style});
}

/// Builds a responsive info row that displays entries horizontally on wide screens
/// and vertically on narrow screens
Widget buildResponsiveInfoRow(BuildContext context, List<InfoEntry> entries) {
  final isWide = MediaQuery.of(context).size.width > 720 && entries.length > 1;
  final defaultStyle = TextStyle(
    fontSize: 14,
    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.blueGrey.shade700,
  );

  List<Widget> tiles = entries
      .map<Widget>(
        (entry) => Padding(
          padding: EdgeInsets.only(bottom: isWide ? 0 : 4),
          child: Text(
            (() {
              final v = entry.value?.toString();
              final valueText = (v == null || v.trim().isEmpty) ? 'N/A' : v.trim();
              return '${entry.label}: $valueText';
            })(),
            style: entry.style ?? defaultStyle,
          ),
        ),
      )
      .toList();

  if (isWide) {
    return Row(
      children: tiles
          .map<Widget>(
            (child) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: child,
              ),
            ),
          )
          .toList(),
    );
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tiles);
}

