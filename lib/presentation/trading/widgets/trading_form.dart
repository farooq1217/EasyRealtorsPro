import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/font_utils.dart';
import 'package:shared/shared.dart' show TradingEntry, TradingType, TradingEntryType;
import '../../../core/services/pdf_service.dart';

class GenericTradingForm extends StatefulWidget {
  final TradingType type;
  final bool isFileTab;
  final Function(TradingEntry) onSave;
  final VoidCallback? onFormReset;

  const GenericTradingForm({
    super.key, 
    required this.type, 
    required this.isFileTab, 
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
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  final _remarksController = TextEditingController();
  
  // Form state variables
  String _selectedType = 'File'; // 'File' or 'Farm'
  String _selectedPaymentOption = 'Cash'; // Default payment option
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
      plotNo: null, // Not used in new form
      block: null, // Not used in new form
      quantity: quantity,
      rate: price, // Use price as rate
      totalAmount: totalAmount,
      commission: commission,
      tax: null, // Not used in new form
      netAmount: totalAmount + commission, // Total + commission
      comments: _remarksController.text, // Store remarks in comments field
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
      _selectedType = 'File';
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF1B1F24)
          : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                "${widget.type == TradingType.buy ? 'Buy' : 'Sell'} - ${_selectedType}",
                style: AppFonts.poppins(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              
              // Type Toggle: File or Farm
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = 'File'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedType == 'File' 
                                ? const Color(0xFFFF6B35) 
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            'File',
                            textAlign: TextAlign.center,
                            style: AppFonts.poppins(
                              color: _selectedType == 'File' 
                                  ? Colors.white 
                                  : Colors.grey.shade700,
                              fontWeight: _selectedType == 'File' 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = 'Farm'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedType == 'Farm' 
                                ? const Color(0xFFFF6B35) 
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Farm',
                            textAlign: TextAlign.center,
                            style: AppFonts.poppins(
                              color: _selectedType == 'Farm' 
                                  ? Colors.white 
                                  : Colors.grey.shade700,
                              fontWeight: _selectedType == 'Farm' 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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

              const SizedBox(height: 16),

              // Estate Name (Required)
              TextFormField(
                controller: _estateController,
                decoration: _fieldDecoration('Estate Name', isRequired: true),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 16),

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

              const SizedBox(height: 16),

              // Person Name (Required)
              TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration('Person Name', isRequired: true),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Quantity (Required) - Numeric input
              TextFormField(
                controller: _quantityController,
                decoration: _fieldDecoration('Quantity', isRequired: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final quantity = int.tryParse(value ?? '');
                  if (quantity == null || quantity! <= 0) return 'Please enter a valid quantity';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Price (Required) - Numeric input
              TextFormField(
                controller: _priceController,
                decoration: _fieldDecoration('Price', isRequired: true),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final price = double.tryParse(value ?? '');
                  if (price == null || price! <= 0) return 'Please enter a valid price';
                  return null;
                },
              ),

              const SizedBox(height: 16),

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
                    if (commission == null || commission! < 0) return 'Please enter a valid commission';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date - Auto-fill with current date, allow manual change
              InkWell(
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
                      Icon(Icons.calendar_today, color: Colors.grey.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: AppFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Remarks - Multi-line text field
              TextFormField(
                controller: _remarksController,
                decoration: _fieldDecoration('Remarks'),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),

              const SizedBox(height: 16),

              // Upload Image Button
              Container(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement image upload functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Image upload feature coming soon!',
                          style: AppFonts.poppins(),
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    'Upload Image/Documents',
                    style: AppFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: const Color(0xFFFF6B35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}