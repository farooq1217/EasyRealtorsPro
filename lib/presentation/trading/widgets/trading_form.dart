import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';
import '../../../domain/models/trading_entry.dart';

class GenericTradingForm extends StatefulWidget {
  final TradingType type; // Buy ya Sell
  final bool isFileTab;   // Trading File tab hai ya Trading Form tab
  final Function(TradingEntry) onSave;
  final Function(TradingEntry)? onBuyEntry; // Callback for Buy button
  final Function(TradingEntry)? onSellEntry; // Callback for Sell button
  final VoidCallback? onFormReset; // NEW: Callback for form reset

  const GenericTradingForm({
    super.key, 
    required this.type, 
    required this.isFileTab, 
    required this.onSave,
    this.onBuyEntry,
    this.onSellEntry,
    this.onFormReset, // NEW: Form reset callback
  });

  @override
  State<GenericTradingForm> createState() => _GenericTradingFormState();
}

class _GenericTradingFormState extends State<GenericTradingForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Saare Controllers ek hi jagah
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _estateController = TextEditingController();
  final _plotController = TextEditingController();
  final _blockController = TextEditingController(); // NEW: Block field for form entries
  final _amountController = TextEditingController();
  final _commissionController = TextEditingController();
  final _taxController = TextEditingController();

  // Field decoration helper - matches original styling
  InputDecoration _fieldDecoration(String label, {IconData? icon, Widget? suffixIcon, bool isRequired = false}) {
    // Map labels to appropriate icons for better visual clarity
    IconData? fieldIcon = icon;
    if (fieldIcon == null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('name') || lowerLabel.contains('client') || lowerLabel.contains('owner')) {
        fieldIcon = Icons.person_outline;
      } else if (lowerLabel.contains('mobile') || lowerLabel.contains('phone') || lowerLabel.contains('contact')) {
        fieldIcon = Icons.phone_outlined;
      } else if (lowerLabel.contains('estate') || lowerLabel.contains('society')) {
        fieldIcon = Icons.apartment_outlined;
      } else if (lowerLabel.contains('plot') || lowerLabel.contains('file no') || lowerLabel.contains('reference')) {
        fieldIcon = Icons.numbers_outlined;
      } else if (lowerLabel.contains('rate') || lowerLabel.contains('amount') || lowerLabel.contains('price')) {
        fieldIcon = null; // Will use "Rs" text widget instead
      } else if (lowerLabel.contains('commission')) {
        fieldIcon = Icons.percent_outlined;
      } else if (lowerLabel.contains('tax')) {
        fieldIcon = Icons.receipt_outlined;
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
    
    // Use "Rs" text widget for currency fields instead of dollar icon
    Widget? prefixWidget;
    if (fieldIcon == null && (label.toLowerCase().contains('rate') || label.toLowerCase().contains('amount'))) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text(
          'Rs',
          style: AppFonts.poppins(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );
    } else if (fieldIcon != null) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Icon(fieldIcon, color: Colors.grey.shade700),
      );
    }
    
    return InputDecoration(
      labelText: isRequired ? null : label,
      label: labelWidget,
      prefixIcon: prefixWidget,
      suffixIcon: suffixIcon,
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

  // Calculation Function: Rate + Commission + Tax
  double _calculateNetAmount() {
    double rate = double.tryParse(_amountController.text) ?? 0.0;
    double commission = double.tryParse(_commissionController.text) ?? 0.0;
    double tax = double.tryParse(_taxController.text) ?? 0.0;
    return rate + commission + tax; // Aapki voice ke mutabiq calculation logic
  }

  // Method to create TradingEntry from current form data
  TradingEntry createEntry(TradingType type) {
    if (!_formKey.currentState!.validate()) {
      return TradingEntry(
        id: '',
        type: type,
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

    final rate = double.tryParse(_amountController.text) ?? 0.0;
    final commission = double.tryParse(_commissionController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final netAmount = rate + commission + tax;

    // Create entry with conditional fields based on entry type
    if (widget.isFileTab) {
      // File entry: use payment field, no commission/tax/rate/plot/block
      return TradingEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        entryType: TradingEntryType.file,
        date: DateTime.now(),
        personName: _nameController.text,
        mobile: _mobileController.text,
        estateName: _estateController.text,
        plotNo: null, // File entries don't have plot numbers
        block: null, // File entries don't have block
        quantity: int.tryParse(_amountController.text) ?? 1, // Use amount as quantity for file entries
        rate: null, // File entries don't have rate
        totalAmount: rate, // Use rate as total_amount for file entries
        commission: 0.0, // File entries don't have commission
        tax: 0.0, // File entries don't have tax
        netAmount: rate, // Net amount same as total_amount for file entries
      );
    } else {
      // Form entry: use rate/commission/tax/plot/block, no payment field
      return TradingEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        entryType: TradingEntryType.form,
        date: DateTime.now(),
        personName: _nameController.text,
        mobile: _mobileController.text,
        estateName: _estateController.text,
        plotNo: _plotController.text,
        block: _blockController.text, // NEW: Include block field
        quantity: 1,
        rate: rate,
        totalAmount: rate, // Use rate as total_amount for form entries
        commission: commission,
        tax: tax,
        netAmount: netAmount,
      );
    }
  }

  // Method to reset form fields
  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _mobileController.clear();
    _estateController.clear();
    _plotController.clear();
    _blockController.clear(); // NEW: Clear block controller
    _amountController.clear();
    _commissionController.clear();
    _taxController.clear();
  }

  // Method to validate form
  bool validateForm() {
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _estateController.dispose();
    _plotController.dispose();
    _blockController.dispose(); // NEW: Dispose block controller
    _amountController.dispose();
    _commissionController.dispose();
    _taxController.dispose();
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
              Text(
                "${widget.type == TradingType.buy ? 'Buy' : 'Sell'} - ${widget.isFileTab ? 'File' : 'Form'}",
                style: AppFonts.poppins(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              
              // Person Name Field
              TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration('Person Name', isRequired: true),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 12),

              // Mobile Field
              TextFormField(
                controller: _mobileController,
                decoration: _fieldDecoration('Mobile No.', isRequired: true),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 12),

              // Estate Name
              TextFormField(
                controller: _estateController,
                decoration: _fieldDecoration('Estate/Society Name', isRequired: true),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 12),

              // Plot No (Sirf 'Form' tab mein dikhega)
              if (!widget.isFileTab) ...[
                TextFormField(
                  controller: _plotController,
                  decoration: _fieldDecoration('Plot Number'),
                ),
                const SizedBox(height: 12),

                // Block Field (Sirf 'Form' tab mein dikhega)
                TextFormField(
                  controller: _blockController,
                  decoration: _fieldDecoration('Block'),
                ),
                const SizedBox(height: 12),
              ],

              // Rate/Amount Field
              TextFormField(
                controller: _amountController,
                decoration: _fieldDecoration('Rate/Amount', isRequired: true),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 12),

              // Commission Field
              TextFormField(
                controller: _commissionController,
                decoration: _fieldDecoration('Commission'),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              // Tax Field
              TextFormField(
                controller: _taxController,
                decoration: _fieldDecoration('Tax'),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final rate = double.tryParse(_amountController.text) ?? 0.0;
                      final commission = double.tryParse(_commissionController.text) ?? 0.0;
                      final tax = double.tryParse(_taxController.text) ?? 0.0;
                      final netAmount = rate + commission + tax;

                      final entry = TradingEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        type: widget.type,
                        entryType: widget.isFileTab ? TradingEntryType.file : TradingEntryType.form,
                        date: DateTime.now(),
                        personName: _nameController.text,
                        mobile: _mobileController.text,
                        estateName: _estateController.text,
                        plotNo: widget.isFileTab ? null : _plotController.text,
                        block: widget.isFileTab ? null : _blockController.text,
                        quantity: widget.isFileTab ? int.tryParse(_amountController.text) ?? 1 : 1,
                        rate: widget.isFileTab ? null : rate,
                        totalAmount: widget.isFileTab ? rate : rate,
                        commission: widget.isFileTab ? 0.0 : commission,
                        tax: widget.isFileTab ? 0.0 : tax,
                        netAmount: widget.isFileTab ? rate : netAmount,
                      );
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

              // Buy and Sell Buttons
              if (widget.onBuyEntry != null || widget.onSellEntry != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onBuyEntry != null)
                      FloatingActionButton.extended(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final entry = createEntry(TradingType.buy);
                            if (entry.id.isNotEmpty) {
                              widget.onBuyEntry!(entry);
                            }
                          }
                        },
                        icon: const Icon(Icons.shopping_cart),
                        label: Text('Buy', style: AppFonts.poppins(fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFFFF6B35),
                      ),
                    if (widget.onBuyEntry != null && widget.onSellEntry != null)
                      const SizedBox(width: 12),
                    if (widget.onSellEntry != null)
                      FloatingActionButton.extended(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final entry = createEntry(TradingType.sell);
                            if (entry.id.isNotEmpty) {
                              widget.onSellEntry!(entry);
                            }
                          }
                        },
                        icon: const Icon(Icons.work),
                        label: Text('Sell', style: AppFonts.poppins(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.blue,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}