import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/font_utils.dart';
import '../../../../core/utils/error_handler.dart';
import 'package:shared/shared.dart' show TradingEntry;
import '../view_models/trading_view_model.dart';

class GenericTradingForm extends StatefulWidget {
  final Function(TradingEntry) onSave;
  final VoidCallback? onFormReset;
  final String? initialTradeType; // Buy/Sell
  final String? initialCategory; // File/Form
  final TradingViewModel viewModel;

  const GenericTradingForm({
    super.key, 
    required this.onSave,
    this.onFormReset,
    this.initialTradeType,
    this.initialCategory,
    required this.viewModel,
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
  String? _selectedEntryType; // No default entry type - user must choose
  String _selectedTradeType = 'Buy'; // Default to Buy
  String _selectedCategory = 'File'; // Default to File
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  bool _isDateFieldLocked = false; // Track if date field should be read-only
  
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
    
    // Set initial values if provided
    if (widget.initialTradeType != null) {
      _selectedTradeType = widget.initialTradeType!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  // Smart auto-date calculation based on payment option
  DateTime _calculateAutoDate(String paymentOption) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // Normalize to start of day
    
    switch (paymentOption) {
      case 'HP': // Current Date
        return today;
        
      case 'KP': // Current Date + 1 day
        return today.add(const Duration(days: 1));
        
      case 'MP': // Coming Monday of the current week
        int daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7; // If today is Monday, use next Monday
        return today.add(Duration(days: daysUntilMonday));
        
      case 'NMP': // The Monday after the coming Monday
        int daysUntilComingMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilComingMonday == 0) daysUntilComingMonday = 7; // If today is Monday, use next Monday
        return today.add(Duration(days: daysUntilComingMonday + 7));
        
      case 'NNMP': // The 3rd Monday from today
        int daysUntilFirstMonday = (DateTime.monday - today.weekday + 7) % 7;
        if (daysUntilFirstMonday == 0) daysUntilFirstMonday = 7; // If today is Monday, use next Monday
        return today.add(Duration(days: daysUntilFirstMonday + 14)); // +14 days for 3rd Monday
        
      case 'AEMP': // After Eid Monday Payment
    // Demo logic hata dein aur agli Eid ki exact date set karein.
    // Misal ke taur par, agar agli Eid 10 March 2027 ko hai:
    final upcomingEid = DateTime(2027, 3, 10); // Yahan asal Eid ki fixed date likhein

    int daysUntilEidMonday = (DateTime.monday - upcomingEid.weekday + 7) % 7;
    
    // Agar Eid khud Monday ko hai, toh agla Monday (7 days later) use karein
    if (daysUntilEidMonday == 0) {
        daysUntilEidMonday = 7; 
    }

    return upcomingEid.add(Duration(days: daysUntilEidMonday));
        
      case 'BOP': // Bank Opening Payment - manual date
      case 'SOP': // Society Opening Payment - manual date
      default:
        return today; // Default to current date for manual options
    }
  }

  // Check if date field should be locked for a payment option
  bool _isDateFieldLockedForOption(String? paymentOption) {
    if (paymentOption == null) return false;
    return ['HP', 'KP', 'MP', 'NMP', 'NNMP', 'AEMP'].contains(paymentOption);
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

  // Helper method to get available stock for current selection
  double _getAvailableStock() {
    if (_selectedTradeType.toLowerCase() != 'sell' || 
        _selectedEntryType == null || 
        _selectedEntryType!.isEmpty ||
        _estateController.text.isEmpty) {
      return 0.0;
    }
    
    return widget.viewModel.getAvailableStock(
      _estateController.text,
      _selectedEntryType!,
      _selectedCategory,
    );
  }

  // Method to create TradingEntry from current form data
  TradingEntry createEntry() {
    debugPrint('TradingForm: createEntry() called');
    debugPrint('TradingForm: _formKey.currentState?.validate() = ${_formKey.currentState?.validate()}');
    
    if (!_formKey.currentState!.validate()) {
      debugPrint('TradingForm: Form validation failed, returning empty entry');
      return TradingEntry(
        id: '',
        entryType: '',
        tradeType: _selectedTradeType,
        category: _selectedCategory,
        date: DateTime.now(),
        personName: '',
        mobileNo: '',
        estateName: '',
        quantity: 0,
        unitPrice: 0,
        companyId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
      );
    }

    debugPrint('TradingForm: Form validation passed, creating entry with data');
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    debugPrint('TradingForm: Parsed quantity = $quantity');
    
    // Clean unit price by removing any currency symbols and whitespace
    final unitPriceText = _unitPriceController.text.trim();
    final cleanUnitPriceText = unitPriceText.replaceAll(RegExp(r'[^\d.]'), ''); // Remove non-numeric characters except decimal
    final unitPrice = double.tryParse(cleanUnitPriceText) ?? 0.0;
    debugPrint('TradingForm: Cleaned unit price = $unitPrice (from "$unitPriceText")');
    
    final now = DateTime.now();
    final entryId = DateTime.now().millisecondsSinceEpoch.toString();

    final entry = TradingEntry(
      id: entryId,
      entryType: _selectedEntryType ?? '',
      tradeType: _selectedTradeType,
      category: _selectedCategory,
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
      status: 'pending',
    );
    
    debugPrint('TradingForm: Created entry with ID: $entryId');
    debugPrint('TradingForm: Entry details - Type: ${entry.entryType}, Trade: ${entry.tradeType}, Category: ${entry.category}');
    debugPrint('TradingForm: Entry details - Person: ${entry.personName}, Mobile: ${entry.mobileNo}, Estate: ${entry.estateName}');
    debugPrint('TradingForm: Entry details - Quantity: ${entry.quantity}, Unit Price: ${entry.unitPrice}, Date: ${entry.date}');
    
    return entry;
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
      _selectedEntryType = null; // Reset to null instead of HP
      _selectedTradeType = widget.initialTradeType ?? 'Buy'; // Reset to initial or default
      _selectedCategory = widget.initialCategory ?? 'File'; // Reset to initial or default
      _selectedDate = DateTime.now();
      _imagePath = null;
      _isDateFieldLocked = false; // Reset date field lock state
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
    ErrorHandler.handle(
      Exception('Image upload feature coming soon!'),
      userMessage: 'Image upload feature will be available in a future update.',
      operation: 'Image picker',
      context: context,
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
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Buy/Sell Toggle
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTradeType = 'Buy'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTradeType == 'Buy' ? Colors.green : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'BUY',
                          textAlign: TextAlign.center,
                          style: AppFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _selectedTradeType == 'Buy' ? Colors.white : Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTradeType = 'Sell'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTradeType == 'Sell' ? Colors.red : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'SELL',
                          textAlign: TextAlign.center,
                          style: AppFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _selectedTradeType == 'Sell' ? Colors.white : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category',
                  style: AppFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = 'File'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedCategory == 'File' ? Theme.of(context).primaryColor : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              'FILE',
                              textAlign: TextAlign.center,
                              style: AppFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: _selectedCategory == 'File' ? Colors.white : Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = 'Form'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedCategory == 'Form' ? Theme.of(context).primaryColor : Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              'FORM',
                              textAlign: TextAlign.center,
                              style: AppFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: _selectedCategory == 'Form' ? Colors.white : Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Row 1: Dropdown (Type) | Date Picker | Mobile No.
            Row(
              children: [
                // Entry Type Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEntryType,
                    decoration: _fieldDecoration('Type', isRequired: true).copyWith(
                      hintText: 'Select Payment Option',
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please select a payment option' : null,
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
                          
                          // Auto-calculate date for payment options that require it
                          if (_isDateFieldLockedForOption(newValue)) {
                            _selectedDate = _calculateAutoDate(newValue);
                            _isDateFieldLocked = true;
                          } else {
                            // For manual options (BOP, SOP), unlock the date field
                            _isDateFieldLocked = false;
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Date Picker
                Expanded(
                  child: InkWell(
                    onTap: _isDateFieldLocked ? null : _selectDate, // Disable tap when locked
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isDateFieldLocked 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _isDateFieldLocked
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade200)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF23272E)
                              : Colors.grey.shade50),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today, 
                            color: _isDateFieldLocked 
                              ? Colors.grey.shade500 
                              : Colors.grey.shade700, 
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: AppFonts.poppins(
                                color: _isDateFieldLocked 
                                  ? Colors.grey.shade600 
                                  : Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isDateFieldLocked)
                            Icon(
                              Icons.lock,
                              color: Colors.grey.shade500,
                              size: 16,
                            )
                          else
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
                    onChanged: (value) {
                      // Trigger state update to refresh helper text when estate name changes
                      if (_selectedTradeType.toLowerCase() == 'sell') {
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Quantity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _quantityController,
                        decoration: _fieldDecoration('Quantity', isRequired: true).copyWith(
                          errorMaxLines: 2, // Fix error truncation
                          helperText: _selectedTradeType.toLowerCase() == 'sell' && 
                                     _selectedEntryType != null && 
                                     _selectedEntryType!.isNotEmpty &&
                                     _estateController.text.isNotEmpty
                            ? 'In-stock: ${_getAvailableStock().toStringAsFixed(2)}'
                            : null,
                          helperStyle: AppFonts.poppins(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          final quantity = double.tryParse(value ?? '');
                          if (quantity == null || quantity! <= 0) return 'Please enter a valid quantity';
                          
                          // Stock validation for Sell entries
                          if (_selectedTradeType.toLowerCase() == 'sell' && 
                              _selectedEntryType != null && 
                              _selectedEntryType!.isNotEmpty &&
                              _estateController.text.isNotEmpty) {
                            
                            final availableStock = _getAvailableStock();
                            
                           /* if (quantity > availableStock) {
                              return 'Insufficient stock! Available: ${availableStock.toStringAsFixed(2)}';
                            }*/
                           
                          }
                          
                          return null;
                        },
                      ),
                    ],
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
                    debugPrint('TradingForm: Save button clicked');
                    debugPrint('TradingForm: _selectedEntryType = $_selectedEntryType');
                    debugPrint('TradingForm: _selectedTradeType = $_selectedTradeType');
                    debugPrint('TradingForm: _nameController.text = ${_nameController.text}');
                    debugPrint('TradingForm: _mobileController.text = ${_mobileController.text}');
                    debugPrint('TradingForm: _estateController.text = ${_estateController.text}');
                    debugPrint('TradingForm: _quantityController.text = ${_quantityController.text}');
                    debugPrint('TradingForm: _unitPriceController.text = ${_unitPriceController.text}');
                    debugPrint('TradingForm: Form validation result = ${_formKey.currentState?.validate()}');
                    
                    if (_formKey.currentState!.validate()) {
                      debugPrint('TradingForm: Form validation passed');
                      
                      // Additional stock validation for Sell entries (double-check)
                      if (_selectedTradeType.toLowerCase() == 'sell' && 
                          _selectedEntryType != null && 
                          _selectedEntryType!.isNotEmpty &&
                          _estateController.text.isNotEmpty) {
                        
                        final quantity = double.tryParse(_quantityController.text) ?? 0.0;
                        final availableStock = widget.viewModel.getAvailableStock(
                          _estateController.text,
                          _selectedEntryType!,
                          _selectedCategory,
                        );
                        
                      /* if (quantity > availableStock) {
                          // Show red SnackBar for insufficient stock
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Insufficient stock! Available quantity: ${availableStock.toStringAsFixed(2)}',
                                style: AppFonts.poppins(color: Colors.white),
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'OK',
                                textColor: Colors.white,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                },
                              ),
                            ),
                          );
                          return; // Don't proceed with save
                        }*/
                      }
                      
                      debugPrint('TradingForm: Creating entry...');
                      final entry = createEntry();
                      debugPrint('TradingForm: Entry created: ${entry.toString()}');
                      debugPrint('TradingForm: Calling widget.onSave...');
                      widget.onSave(entry);
                    } else {
                      debugPrint('TradingForm: Form validation failed');
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
