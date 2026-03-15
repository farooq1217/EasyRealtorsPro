import 'dart:async';
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/font_utils.dart';
import '../../../widgets/primary_gradient_button.dart' show PrimaryGradientButton;
import '../../../widgets/image_upload_widget.dart' show ImageUploadWidget;
import '../rental/rental_view_model.dart';
import '../rental/repositories/rental_repository.dart';

class RentalFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const RentalFormDialog({
    super.key,
    this.existing,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<RentalFormDialog> createState() => _RentalFormDialogState();
}

class _RentalFormDialogState extends State<RentalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _contactNoController = TextEditingController();
  final _cnicController = TextEditingController();
  final _priceController = TextEditingController();
  final _securityController = TextEditingController();
  final _locationController = TextEditingController();
  final _remarksController = TextEditingController();
  
  String? _selectedStatus;
  String? _selectedPropertyType;
  String? _uploadedImagePath;
  bool _isLoading = false;

  final List<String> _statusOptions = [
    'Available',
    'Rented', 
    'Overdue',
    'Maintenance'
  ];

  final List<String> _propertyTypeOptions = [
    'House',
    'Shop',
    'Plaza',
    'Hall',
    'Apartment',
    'Office',
    'Warehouse'
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.existing != null) {
      final item = widget.existing!;
      _selectedPropertyType = item['name']?.toString() ?? 'House';
      _ownerNameController.text = item['owner_name']?.toString() ?? '';
      _contactNoController.text = item['contact_no']?.toString() ?? '';
      _cnicController.text = item['cnic']?.toString() ?? '';
      _priceController.text = item['price']?.toString() ?? '';
      _securityController.text = item['security']?.toString() ?? '';
      _locationController.text = item['location']?.toString() ?? '';
      _remarksController.text = item['remarks']?.toString() ?? '';
      _selectedStatus = item['sale_status']?.toString() ?? 'Available';
    } else {
      _selectedPropertyType = 'House';
      _selectedStatus = 'Available';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _contactNoController.dispose();
    _cnicController.dispose();
    _priceController.dispose();
    _securityController.dispose();
    _locationController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final rentalItem = {
        'id': widget.existing?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _selectedPropertyType ?? 'House',
        'owner_name': _ownerNameController.text.trim(),
        'contact_no': _contactNoController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'security': double.tryParse(_securityController.text) ?? 0.0,
        'location': _locationController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'sale_status': _selectedStatus,
        'is_active': 1,
        'image_path': _uploadedImagePath,
      };

      await widget.onSave(rentalItem);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving rental item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B35), // Orange
                    const Color(0xFF4A90E2), // Blue
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: widget.onCancel,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.existing == null ? 'Add Rental Item' : 'Edit Rental Item',
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Property Type | Address | Owner Name
                      Row(
                        children: [
                          // Property Type Dropdown
                          Expanded(
                            child: _buildPropertyTypeDropdown(),
                          ),
                          const SizedBox(width: 16),
                          // Address
                          Expanded(
                            child: _buildTextField(
                              controller: _locationController,
                              label: 'Address',
                              hint: 'Enter property address',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter address';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Owner Name
                          Expanded(
                            child: _buildTextField(
                              controller: _ownerNameController,
                              label: 'Owner Name',
                              hint: 'Enter owner name',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter owner name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 2: Contact No | Rent | Security
                      Row(
                        children: [
                          // Contact No
                          Expanded(
                            child: _buildTextField(
                              controller: _contactNoController,
                              label: 'Contact No.',
                              hint: 'Enter contact number',
                              keyboardType: TextInputType.phone,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter contact number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Rent
                          Expanded(
                            child: _buildTextField(
                              controller: _priceController,
                              label: 'Rent (Rs)',
                              hint: '0.00',
                              keyboardType: TextInputType.number,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid amount';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Security
                          Expanded(
                            child: _buildTextField(
                              controller: _securityController,
                              label: 'Security (Rs)',
                              hint: '0.00',
                              keyboardType: TextInputType.number,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid amount';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // Status Dropdown
                      const SizedBox(height: 16),
                      _buildStatusDropdown(),

                      // Remarks
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _remarksController,
                        label: 'Remarks',
                        hint: 'Enter any additional remarks',
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter remarks';
                          }
                          return null;
                        },
                      ),

                      // Image Upload
                      const SizedBox(height: 16),
                      _buildImageUploadSection(),

                      // Action Buttons
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : widget.onCancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFFFF6B35)),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppFonts.poppins(
                                  color: const Color(0xFFFF6B35),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PrimaryGradientButton(
                              text: widget.existing == null ? 'Add Item' : 'Update Item',
                              onPressed: _isLoading ? null : _handleSave,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Property Type',
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFF6B35),
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPropertyType,
              hint: const Text('Select property type'),
              items: _propertyTypeOptions.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPropertyType = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFF6B35),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              hint: const Text('Select status'),
              items: _statusOptions.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Image',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFF6B35),
          ),
        ),
        const SizedBox(height: 8),
        ImageUploadWidget(
          imagePaths: _uploadedImagePath != null ? [_uploadedImagePath!] : [],
          onImagesChanged: (images) {
            setState(() {
              _uploadedImagePath = images.isNotEmpty ? images.first : null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFF6B35),
              ),
            ),
            if (isRequired) ...[
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
