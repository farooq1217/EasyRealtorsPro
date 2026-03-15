import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/font_utils.dart';
import 'package:shared/shared.dart' show TradingEntry;

class StreamlinedTradingForm extends StatefulWidget {
  final String type; // Simple string: 'buy' or 'sell'
  final bool isFileTab;
  final Color headerColor;
  final String actionText;
  final Function(TradingEntry) onSave;

  const StreamlinedTradingForm({
    super.key,
    required this.type,
    required this.isFileTab,
    required this.headerColor,
    required this.actionText,
    required this.onSave,
  });

  @override
  State<StreamlinedTradingForm> createState() => StreamlinedTradingFormState();
}

class StreamlinedTradingFormState extends State<StreamlinedTradingForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _estateController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  
  // Form state variables
  String _selectedPaymentOption = 'Cash';
  DateTime _selectedDate = DateTime.now();
  
  // Payment options
  static const List<String> _paymentOptions = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'Online Payment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  // Enhanced field decoration with consistent styling
  InputDecoration _fieldDecoration(String label, {IconData? icon, bool isRequired = false}) {
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
        fieldIcon = Icons.attach_money_outlined;
      } else {
        fieldIcon = Icons.edit_outlined;
      }
    }
    
    Widget? labelWidget;
    if (isRequired) {
      labelWidget = RichText(
        text: TextSpan(
          text: label,
          style: AppFonts.poppins(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(
              text: ' *',
              style: AppFonts.poppins(
                color: widget.headerColor,
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
        child: Icon(fieldIcon, color: widget.headerColor, size: 20),
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
        borderSide: BorderSide(color: widget.headerColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: AppFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
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
        status: 'active', // Add status field
      );
    }

    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final now = DateTime.now();

    return TradingEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entryType: widget.isFileTab ? 'file' : 'form', // Simple string types
      date: _selectedDate,
      personName: _nameController.text,
      mobileNo: _mobileController.text,
      estateName: _estateController.text,
      quantity: quantity,
      unitPrice: unitPrice, // Use actual unit price from form
      imagePath: null, // Removed _imagePath reference
      companyId: '', // Will be set by repository
      createdAt: now,
      updatedAt: now,
      status: 'active', // Add status field
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
      _selectedPaymentOption = 'Cash';
      _selectedDate = DateTime.now();
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.headerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.headerColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.type == 'buy' ? Icons.shopping_cart : Icons.work,
                    color: widget.headerColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.actionText} Entry Details',
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.headerColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Payment Option Dropdown
            DropdownButtonFormField<String>(
              value: _selectedPaymentOption,
              decoration: _fieldDecoration('Payment Option', isRequired: true),
              items: _paymentOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: AppFonts.poppins()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPaymentOption = newValue;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Estate Name (Required)
            TextFormField(
              controller: _estateController,
              decoration: _fieldDecoration('Estate Name', isRequired: true),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),

            const SizedBox(height: 20),

            // Mobile No (Required) - Numeric input
            TextFormField(
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

            const SizedBox(height: 20),

            // Person Name (Required)
            TextFormField(
              controller: _nameController,
              decoration: _fieldDecoration('Person Name', isRequired: true),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),

            const SizedBox(height: 20),

            // Unit Price (Required)
            TextFormField(
              controller: _unitPriceController,
              decoration: _fieldDecoration('Unit Price (Rs)', isRequired: true),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                final unitPrice = double.tryParse(value ?? '');
                if (unitPrice == null || unitPrice! < 0) return 'Invalid price';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Quantity and Date in Row
            Row(
              children: [
                // Quantity (Required)
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: _fieldDecoration('Quantity', isRequired: true),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final quantity = double.tryParse(value ?? '');
                      if (quantity == null || quantity! <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Date Picker
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.headerColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                        color: widget.headerColor.withOpacity(0.05),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: widget.headerColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: AppFonts.poppins(
                                color: widget.headerColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: widget.headerColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Prominent Confirm Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final entry = createEntry();
                    widget.onSave(entry);
                    _resetForm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.headerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: widget.headerColor.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.type == 'buy' ? Icons.shopping_cart : Icons.work,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confirm ${widget.actionText}',
                      style: AppFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
