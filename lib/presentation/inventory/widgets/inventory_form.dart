// presentation/inventory/widgets/inventory_form.dart
import 'package:flutter/material.dart';
import '../../../../core/font_utils.dart';

import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../../domain/models/inventory_item.dart';
import '../inventory_view_model.dart';
import '../../../core/app_utils.dart' show pickAndCompressImage, showImageSourceDialog, uploadImageToFirebaseStorage, imageUrlsToJson;
import 'package:shared/shared.dart' show RoleUtils;
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/services/auth_service.dart';

class InventoryForm extends StatefulWidget {
  final InventoryItem? existing;
  final VoidCallback onSave;

  const InventoryForm({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<InventoryForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController ownerCtl, fileNoCtl, plotNoCtl, contactCtl, cnicCtl, demandCtl, remarksCtl, sizeCtl;
  String? selSoc, selBlk, selStatus = 'Not Sold';
  List<String> _imageUrls = []; // Firebase Storage URLs
  List<Uint8List> _pendingImageBytes = []; // Images waiting to be uploaded
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final viewModel = context.read<InventoryViewModel>();
    
    ownerCtl = TextEditingController(text: e?.clientName);
    fileNoCtl = TextEditingController(text: e?.fileNo);
    plotNoCtl = TextEditingController(text: e?.referenceNo);
    contactCtl = TextEditingController(
      text: viewModel.selectedType == InventoryType.file 
          ? (e?.mobileNo ?? '') 
          : (e?.propertyName ?? '')
    );
    cnicCtl = TextEditingController(text: e?.cnic);
    demandCtl = TextEditingController(text: e?.demand?.toString());
    remarksCtl = TextEditingController(text: e?.remarks);
    sizeCtl = TextEditingController(
      text: viewModel.selectedType == InventoryType.file 
          ? (e?.path ?? '') 
          : (e?.price?.toString() ?? '')
    );
    selSoc = e?.societyId;
    selBlk = e?.blockId;
    selStatus = e?.saleStatus ?? 'Not Sold';
    
    // Load existing image URLs
    if (e != null) {
      _imageUrls = List.from(e.imageUrls);
    }
  }

  @override
  void dispose() {
    ownerCtl.dispose();
    fileNoCtl.dispose();
    plotNoCtl.dispose();
    contactCtl.dispose();
    cnicCtl.dispose();
    demandCtl.dispose();
    remarksCtl.dispose();
    sizeCtl.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddImage() async {
    final source = await showImageSourceDialog(context);
    if (source == null) return;
    
    final result = await pickAndCompressImage(context, source);
    if (result != null && mounted) {
      setState(() {
        _pendingImageBytes.add(result['bytes'] as Uint8List);
      });
    }
  }

  void _removePendingImage(int index) {
    if (!mounted) return;
    setState(() {
      _pendingImageBytes.removeAt(index);
    });
  }

  void _removeImageUrl(int index) {
    if (!mounted) return;
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Widget _buildImageGallery() {
    final allImages = [
      ..._imageUrls.map((url) => {'type': 'url', 'url': url}),
      ..._pendingImageBytes.asMap().entries.map((e) => {'type': 'bytes', 'index': e.key, 'bytes': e.value}),
    ];

    if (allImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            itemBuilder: (ctx, i) {
              final item = allImages[i];
              final isUrl = item['type'] == 'url';
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isUrl
                          ? Image.network(
                              item['url'] as String,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                            )
                          : Image.memory(
                              item['bytes'] as Uint8List,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          if (isUrl) {
                            _removeImageUrl(i);
                          } else {
                            _removePendingImage(item['index'] as int);
                          }
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFFFF6B35)),
        const SizedBox(width: 8),
        Text(title, style: AppFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryViewModel>(
      builder: (context, viewModel, child) {
        return Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.existing == null 
                  ? 'Add ${viewModel.selectedType == InventoryType.file ? 'File' : 'Property'} Form' 
                  : 'Edit ${viewModel.selectedType == InventoryType.file ? 'File' : 'Property'} Form', 
              style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            
            _buildSectionHeader('Location Details', Icons.map_outlined),
            _buildDropdown('Society', viewModel.societies, selSoc, (v) {
              if (!mounted) return;
              setState(() { 
                selSoc = v; 
                selBlk = null; // Reset block selection
                // Trigger block reload in ViewModel
                viewModel.setSelectedSociety(v);
              });
            }),
            const SizedBox(height: 16),
            _buildDropdown('Block', viewModel.getAvailableBlocks(), selBlk, (v) {
              if (!mounted) return;
              setState(() => selBlk = v);
            }),

            _buildSectionHeader('Property Information', Icons.home_work_outlined),
            Row(children: [
              Expanded(child: _buildField(plotNoCtl, 'Plot / Ref No.', icon: Icons.numbers)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(sizeCtl, viewModel.selectedType == InventoryType.file ? 'Size' : 'Price (Rs)', icon: Icons.straighten)),
            ]),
            const SizedBox(height: 16),
            if (viewModel.selectedType == InventoryType.file) 
              _buildField(fileNoCtl, 'File No.', icon: Icons.file_copy_outlined),

            _buildSectionHeader('Client Information', Icons.person_outline),
            _buildField(ownerCtl, 'Owner Name', icon: Icons.person),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _buildField(contactCtl, 'Contact No.', icon: Icons.phone)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(cnicCtl, 'CNIC', icon: Icons.badge_outlined)),
            ]),

            _buildSectionHeader('Status & Finance', Icons.account_balance_wallet_outlined),
            if (viewModel.selectedType == InventoryType.property) ...[
              _buildField(demandCtl, 'Demand (Rs)', isNum: true, icon: Icons.money),
              const SizedBox(height: 16),
            ],
            _buildDropdown('Status', [
              {'id':'Sold','name':'Sold'}, 
              {'id':'Not Sold','name':'Not Sold'}
            ], selStatus, (v) {
              if (!mounted) return;
              setState(() => selStatus = v);
            }),

            _buildSectionHeader('Additional Info', Icons.notes),
            _buildField(remarksCtl, 'Remarks', maxLines: 2, icon: Icons.comment_outlined),
            
            _buildSectionHeader('Images', Icons.image_outlined),
            OutlinedButton.icon(
              onPressed: _pickAndAddImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Image'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            _buildImageGallery(),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity, 
              height: 50, 
              child: ElevatedButton(
                onPressed: _uploadingImages ? null : _saveAction, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: _uploadingImages 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Details', 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildField(TextEditingController ctl, String label, {bool isNum = false, int maxLines = 1, IconData? icon}) {
    return TextFormField(
      controller: ctl, 
      keyboardType: isNum ? TextInputType.number : TextInputType.text, 
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: icon != null ? Icon(icon) : null, 
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDropdown(String label, List<Map<String, String>> items, String? val, Function(String?) onChange) {
    final hasItems = items.isNotEmpty;
    final displayItems = hasItems 
        ? items 
        : [{'id': '__loading__', 'name': items.isEmpty ? 'No data found' : 'Loading...'}];
    
    return DropdownButtonFormField<String>(
      value: hasItems ? val : null,
      onChanged: hasItems ? onChange : null,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: const Icon(Icons.list), 
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        hintText: hasItems ? null : (items.isEmpty ? 'No data found' : 'Loading...'),
      ),
      items: displayItems.map((i) => DropdownMenuItem(
        value: i['id'],
        child: Text(i['name'] ?? ''),
        enabled: hasItems && i['id'] != '__loading__',
      )).toList(),
      validator: (v) => hasItems && v == null ? 'Required' : null,
    );
  }

  Future<void> _saveAction() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (!mounted) return;
    
    setState(() => _uploadingImages = true);
    
    final viewModel = context.read<InventoryViewModel>();
    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final currentUser = await _getCurrentUser();
    final companyId = RoleUtils.getUserCompanyId(currentUser);
    
    try {
      // Upload pending images to Firebase Storage
      List<String> uploadedUrls = List.from(_imageUrls);
      for (final bytes in _pendingImageBytes) {
        final url = await uploadImageToFirebaseStorage(
          imageBytes: bytes,
          module: viewModel.selectedType.name.toLowerCase(),
          recordId: id,
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      }
      
      final imageUrlsJson = imageUrlsToJson(uploadedUrls);
      
      InventoryItem item;
      if (viewModel.selectedType == InventoryType.file) {
        item = InventoryItem.file(
          id: id,
          clientName: ownerCtl.text.trim(),
          referenceNo: plotNoCtl.text.trim(),
          societyId: selSoc ?? '',
          blockId: selBlk,
          saleStatus: selStatus ?? 'Not Sold',
          remarks: imageUrlsJson.isNotEmpty ? '' : remarksCtl.text.trim(),
          cnic: cnicCtl.text.trim(),
          companyId: companyId ?? '',
          updatedAt: DateTime.now(),
          fileNo: fileNoCtl.text.trim(),
          mobileNo: contactCtl.text.trim(),
          path: sizeCtl.text.trim(),
          imageUrls: uploadedUrls,
        );
      } else {
        item = InventoryItem.property(
          id: id,
          clientName: ownerCtl.text.trim(),
          referenceNo: plotNoCtl.text.trim(),
          societyId: selSoc ?? '',
          blockId: selBlk,
          saleStatus: selStatus ?? 'Not Sold',
          remarks: imageUrlsJson.isNotEmpty ? '' : remarksCtl.text.trim(),
          cnic: cnicCtl.text.trim(),
          companyId: companyId ?? '',
          updatedAt: DateTime.now(),
          propertyName: contactCtl.text.trim(),
          demand: int.tryParse(demandCtl.text.trim()) ?? 0,
          price: int.tryParse(sizeCtl.text.trim()) ?? 0,
          imageUrls: uploadedUrls,
        );
      }
      
      await viewModel.saveItem(item);
      
      if (!mounted) return;
      setState(() {
        _uploadingImages = false;
        _pendingImageBytes.clear();
      });
      
      widget.onSave();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImages = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getCurrentUser() async {
    // Get current user from storage
    final storage = AppStorage();
    final s = await storage.readSettings();
    final token = s['authToken'] as String?;
    if (token != null) {
      return await AuthService().getCurrentUser(token);
    }
    return null;
  }
}
