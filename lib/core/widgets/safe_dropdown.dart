import 'package:flutter/material.dart';

/// Utility class for safe dropdown operations that prevent assertion errors
class SafeDropdown {
  /// Validates if a dropdown value exists in the items list and returns a safe value
  /// 
  /// [selectedValue] - The current selected value
  /// [items] - List of available dropdown items
  /// [fallbackValue] - Optional fallback value if selected value doesn't exist
  /// 
  /// Returns the selected value if it exists, otherwise the fallback value or first item
  static T? getSafeValue<T>(
    T? selectedValue, 
    List<DropdownMenuItem<T>> items, {
    T? fallbackValue,
  }) {
    if (selectedValue == null) return fallbackValue;
    
    // Extract values from dropdown items
    final List<T> availableValues = items.map((item) => item.value!).toList();
    
    // Check if selected value exists in available values
    if (availableValues.contains(selectedValue)) {
      return selectedValue;
    }
    
    // Return fallback or first available value
    return fallbackValue ?? (availableValues.isNotEmpty ? availableValues.first : null);
  }

  /// Validates if a dropdown value exists in the items list for string values
  /// 
  /// [selectedValue] - The current selected string value
  /// [items] - List of available dropdown items
  /// [fallbackValue] - Optional fallback value if selected value doesn't exist
  /// 
  /// Returns the selected value if it exists, otherwise the fallback value or first item
  static String? getSafeStringValue(
    String? selectedValue, 
    List<DropdownMenuItem<String>> items, {
    String? fallbackValue,
  }) {
    if (selectedValue == null) return fallbackValue;
    
    // Extract values from dropdown items
    final List<String> availableValues = items.map((item) => item.value!).toList();
    
    // Check if selected value exists in available values
    if (availableValues.contains(selectedValue)) {
      return selectedValue;
    }
    
    // Return fallback or first available value
    return fallbackValue ?? (availableValues.isNotEmpty ? availableValues.first : null);
  }

  /// Creates a safe DropdownButtonFormField that prevents assertion errors
  /// 
  /// [items] - List of dropdown items
  /// [value] - Current selected value
  /// [onChanged] - Callback when value changes
  /// [decoration] - Input decoration
  /// [hintText] - Hint text
  /// [fallbackValue] - Optional fallback value if current value doesn't exist
  /// [validator] - Optional validator function
  /// [autovalidateMode] - Autovalidate mode
  /// 
  /// Returns a DropdownButtonFormField that won't crash on assertion errors
  static DropdownButtonFormField<T> createSafeDropdown<T>({
    required List<DropdownMenuItem<T>> items,
    T? value,
    ValueChanged<T?>? onChanged,
    InputDecoration? decoration,
    String? hintText,
    T? fallbackValue,
    FormFieldValidator<T?>? validator,
    AutovalidateMode? autovalidateMode,
  }) {
    return DropdownButtonFormField<T>(
      value: getSafeValue(value, items, fallbackValue: fallbackValue),
      decoration: decoration ?? InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      autovalidateMode: autovalidateMode,
    );
  }

  /// Creates a safe DropdownButtonFormField for string values
  /// 
  /// [items] - List of dropdown items
  /// [value] - Current selected string value
  /// [onChanged] - Callback when value changes
  /// [decoration] - Input decoration
  /// [hintText] - Hint text
  /// [fallbackValue] - Optional fallback value if current value doesn't exist
  /// [validator] - Optional validator function
  /// [autovalidateMode] - Autovalidate mode
  /// 
  /// Returns a DropdownButtonFormField that won't crash on assertion errors
  static DropdownButtonFormField<String> createSafeStringDropdown({
    required List<DropdownMenuItem<String>> items,
    String? value,
    ValueChanged<String?>? onChanged,
    InputDecoration? decoration,
    String? hintText,
    String? fallbackValue,
    FormFieldValidator<String?>? validator,
    AutovalidateMode? autovalidateMode,
  }) {
    return DropdownButtonFormField<String>(
      value: getSafeStringValue(value, items, fallbackValue: fallbackValue),
      decoration: decoration ?? InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      autovalidateMode: autovalidateMode,
    );
  }

  /// Helper method to create dropdown items from a list of values
  /// 
  /// [values] - List of values to create dropdown items from
  /// [displayNames] - Optional list of display names (same length as values)
  /// 
  /// Returns list of DropdownMenuItem widgets
  static List<DropdownMenuItem<T>> createItemsFromValues<T>(
    List<T> values, {
    List<String>? displayNames,
  }) {
    return values.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      final displayName = displayNames != null && index < displayNames.length 
          ? displayNames[index] 
          : value.toString();
      
      return DropdownMenuItem<T>(
        value: value,
        child: Text(displayName),
      );
    }).toList();
  }

  /// Helper method to create dropdown items from a map of value->label
  /// 
  /// [valueLabelMap] - Map of values to labels
  /// 
  /// Returns list of DropdownMenuItem widgets
  static List<DropdownMenuItem<T>> createItemsFromMap<T>(
    Map<T, String> valueLabelMap,
  ) {
    return valueLabelMap.entries.map((entry) {
      return DropdownMenuItem<T>(
        value: entry.key,
        child: Text(entry.value),
      );
    }).toList();
  }
}
