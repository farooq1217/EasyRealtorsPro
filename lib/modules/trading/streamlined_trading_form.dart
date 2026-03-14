import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/font_utils.dart';
import 'package:shared/shared.dart' show TradingEntry, TradingType, TradingEntryType;

class StreamlinedTradingForm extends StatefulWidget {
  final TradingType type;
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
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  final _remarksController = TextEditingController();
  
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
      } else if (lowerLabel.contains('price') || lowerLabel.contains('amount')) {
        fieldIcon = Icons.attach_money_outlined;
      } else if (lowerLabel.contains('commission')) {
        fieldIcon = Icons.percent_outlined;
      } else if (lowerLabel.contains('remarks') || lowerLabel.contains('comments')) {
        fieldIcon = Icons.comment_outlined;
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
        type: widget.type,
        entryType: widget.isFileTab ? TradingEntryType.file : TradingEntryType.form,
        date: DateTime.now(),
        personName: '',
        mobile: '',
        estateName: '',
        plotNo: null,
        block: null,
        quantity: 0,
        rate: null,
        totalAmount: null,
        commission: null,
        tax: null,
        netAmount: null,
      );
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final commission = double.tryParse(_commissionController.text) ?? 0.0;
    final totalAmount = quantity * price;

    return TradingEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: widget.type,
      entryType: widget.isFileTab ? TradingEntryType.file : TradingEntryType.form,
      date: _selectedDate,
      personName: _nameController.text,
      mobile: _mobileController.text,
      estateName: _estateController.text,
      plotNo: null,
      block: null,
      quantity: quantity,
      rate: price,
      totalAmount: totalAmount,
      commission: commission,
      tax: null,
      netAmount: totalAmount + commission,
      comments: _remarksController.text,
    );
  }

  // Method to reset form fields
  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _mobileController.clear();
    _estateController.clear();
    _quantityController.clear();
    _priceController.clear();
    _commissionController.clear();
    _remarksController.clear();
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
    _priceController.dispose();
    _commissionController.dispose();
    _remarksController.dispose();
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
                    widget.type == TradingType.buy ? Icons.shopping_cart : Icons.work,
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

            // Quantity and Price in Row (Field Grouping)
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
                      final quantity = int.tryParse(value ?? '');
                      if (quantity == null || quantity! <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Price (Required)
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: _fieldDecoration('Price', isRequired: true),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final price = double.tryParse(value ?? '');
                      if (price == null || price! <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Commission (Optional) - Numeric input
            TextFormField(
              controller: _commissionController,
              decoration: _fieldDecoration('Commission'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final commission = double.tryParse(value);
                  if (commission == null || commission! < 0) return 'Invalid';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Date - Auto-fill with current date, allow manual change
            InkWell(
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

            const SizedBox(height: 20),

            // Remarks - Multi-line text field
            TextFormField(
              controller: _remarksController,
              decoration: _fieldDecoration('Remarks'),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),

            const SizedBox(height: 32),

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
                      widget.type == TradingType.buy ? Icons.shopping_cart : Icons.work,
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
