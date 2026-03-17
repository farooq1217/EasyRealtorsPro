import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/font_utils.dart';
import 'package:shared/shared.dart' show TradingEntry;

class GenericTradingForm extends StatefulWidget {
  final Function(TradingEntry) onSave;
  final VoidCallback? onFormReset;

  const GenericTradingForm({
    super.key, 
    required this.onSave,
    this.onFormReset,
  });

  @override
  State<GenericTradingForm> createState() => _GenericTradingFormState();
}

class _GenericTradingFormState extends State<GenericTradingForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _estateController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  
  // Form state variables
  String _selectedEntryType = 'HP'; // Default entry type
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  
  // Entry type options
  static const List<String> _entryTypes = [
    'HP',
    'KP', 
    'MP',
    'NMP',
    'NNMP',
    'BOP',
    'SOP',
    'AEMP',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-fill date with current date
    _selectedDate = DateTime.now();
  }

  // Field decoration helper
  InputDecoration _fieldDecoration(String label, {IconData? icon, bool isRequired = false}) {
    // Map labels to appropriate icons
    IconData? fieldIcon = icon;
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name') || lowerLabel.contains('person')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('estate') || lowerLabel.contains('society')) {
        fieldIcon = Icons.apartment_outlined;
      } else if (lowerLabel.contains('quantity')) {
        fieldIcon = Icons.inventory_2_outlined;
      } else if (lowerLabel.contains('unit price') || lowerLabel.contains('price')) {
        // Don't show icon for Unit Price - will use prefixText instead
        fieldIcon = null;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }
    
    // Add red asterisk for required fields
    Widget? labelWidget;
    if (isRequired) {
      labelWidget = RichText(
        text: TextSpan(
          text: label,
          style: AppFonts.poppins(
            color: Colors.grey.shade700,
          ),
          children: [
            TextSpan(
              text: ' *',
              style: AppFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    return InputDecoration(
      labelText: isRequired ? null : label,
      label: labelWidget,
      prefixIcon: fieldIcon != null ? Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Icon(fieldIcon, color: Colors.grey.shade700),
      ) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF23272E)
          : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: AppFonts.poppins(color: Colors.grey.shade700),
      hintStyle: AppFonts.poppins(color: Colors.grey.shade500),
    );
  }

  // Method to create TradingEntry from current form data
  TradingEntry createEntry() {
    if (!_formKey.currentState!.validate()) {
      return TradingEntry(
        id: '',
        entryType: '',
        date: DateTime.now(),
        personName: '',
        mobileNo: '',
        estateName: '',
        quantity: 0,
        unitPrice: 0,
        companyId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
      );
    }

    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    // Clean unit price by removing any currency symbols and whitespace
    final unitPriceText = _unitPriceController.text.trim();
    final cleanUnitPriceText = unitPriceText.replaceAll(RegExp(r'[^\d.]'), ''); // Remove non-numeric characters except decimal
    final unitPrice = double.tryParse(cleanUnitPriceText) ?? 0.0;
    
    final now = DateTime.now();

    return TradingEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entryType: _selectedEntryType,
      date: _selectedDate,
      personName: _nameController.text,
      mobileNo: _mobileController.text,
      estateName: _estateController.text,
      quantity: quantity,
      unitPrice: unitPrice, // Save clean numeric value only
      imagePath: _imagePath,
      companyId: '', // Will be set by repository
      createdAt: now,
      updatedAt: now,
      status: 'active',
    );
  }

  // Method to reset form fields
  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _mobileController.clear();
    _estateController.clear();
    _quantityController.clear();
    _unitPriceController.clear();
    setState(() {
      _selectedEntryType = 'HP';
      _selectedDate = DateTime.now();
      _imagePath = null;
    });
  }

  // Date picker
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Image picker (placeholder)
  Future<void> _pickImage() async {
    // TODO: Implement image picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Image upload feature coming soon!',
          style: AppFonts.poppins(),
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _estateController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF1B1F24)
          : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Trading Entry',
              style: AppFonts.poppins(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            
            // Row 1: Dropdown (Type) | Date Picker | Mobile No.
            Row(
              children: [
                // Entry Type Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEntryType,
                    decoration: _fieldDecoration('Type', isRequired: true),
                    items: _entryTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type, style: AppFonts.poppins()),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedEntryType = newValue;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Date Picker
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF23272E)
                            : Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: AppFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Mobile No.
                Expanded(
                  child: TextFormField(
                    controller: _mobileController,
                    decoration: _fieldDecoration('Mobile No', isRequired: true),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (value!.length < 10) return 'Please enter a valid mobile number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Row 2: Person Name | Estate Name | Quantity | Unit Price
            Row(
              children: [
                // Person Name
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: _fieldDecoration('Person Name', isRequired: true),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Estate Name
                Expanded(
                  child: TextFormField(
                    controller: _estateController,
                    decoration: _fieldDecoration('Estate Name', isRequired: true),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Quantity
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: _fieldDecoration('Quantity', isRequired: true),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final quantity = double.tryParse(value ?? '');
                      if (quantity == null || quantity! <= 0) return 'Please enter a valid quantity';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Unit Price
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: InputDecoration(
                      labelText: 'Unit Price *',
                      labelStyle: AppFonts.poppins(color: Colors.grey.shade700),
                      prefixText: 'Rs ',
                      prefixStyle: AppFonts.poppins(color: Colors.grey.shade700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF23272E)
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final unitPrice = double.tryParse(value ?? '');
                      if (unitPrice == null || unitPrice! < 0) return 'Please enter a valid unit price';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Footer: Upload Image button (Left) | Cancel & Save Entry buttons (Right)
            Row(
              children: [
                // Upload Image Button
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    'Upload Image',
                    style: AppFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    side: BorderSide(color: const Color(0xFFFF6B35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Cancel Button
                TextButton(
                  onPressed: () {
                    widget.onFormReset?.call();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Save Entry Button
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final entry = createEntry();
                      widget.onSave(entry);
                      
                      // Reset form after successful save
                      _resetForm();
                      
                      // Call reset callback if provided
                      widget.onFormReset?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Entry',
                    style: AppFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}