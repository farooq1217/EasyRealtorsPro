// presentation/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/app_storage.dart' show AppStorage;
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../../../core/shared_utils.dart' show TopRightSearch;
import '../../../core/services/permission_helper.dart' show PermissionHelper;
import '../../../core/role_utils.dart';
import '../view_models/settings_view_model.dart';
import '../repositories/settings_repository_impl.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'dart:io' if (dart.library.html) '../../platform_stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;

class SettingsPageClean extends StatefulWidget {
  final dynamic db;
  const SettingsPageClean({super.key, required this.db});

  @override
  State<SettingsPageClean> createState() => _SettingsPageCleanState();
}

class _SettingsPageCleanState extends State<SettingsPageClean> {
  SettingsViewModel? _viewModel;
  Map<String, dynamic>? user;
  final TextEditingController _societyNameController = TextEditingController();
  final TextEditingController _blockNameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  bool _mounted = true;
  bool _initialized = false;
  bool _isDeleting = false; // ✅ NEW: Track delete operation
  
  DateTime? _loadingStartTime;
  static const Duration _maxLoadingTime = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _loadingStartTime = DateTime.now();
    _initializeViewModel();
  }

  @override
  void dispose() {
    _mounted = false;
    _societyNameController.dispose();
    _blockNameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _initializeViewModel() async {
    if (_initialized) {
      debugPrint('SettingsPage: Already initialized, skipping duplicate call');
      return;
    }
    
    debugPrint('SettingsPage: PRE-FETCH CHECK - Starting ViewModel initialization');
    
    final storage = AppStorage();
    final s = await storage.readSettings();
    final token = s['authToken'] as String?;
    if (token != null) {
      user = await AuthService.getCurrentUser(token);
    }
    
    final isSuper = RoleUtils.isSuperAdmin(user) || PermissionHelper.isBypassUser(user);
    var companyId = RoleUtils.getUserCompanyId(user);
    
    if (companyId == null) {
      if (isSuper) {
        companyId = 'GLOBAL_ADMIN';
        debugPrint('SettingsPage: IMMEDIATE FALLBACK - Set companyId to GLOBAL_ADMIN for Super Admin');
      } else {
        debugPrint('SettingsPage: No companyId provided for non-super-admin, using empty string to prevent hanging');
        companyId = '';
      }
    }
    
    debugPrint('SettingsPage: Final parameters - isSuper: $isSuper, companyId: $companyId');
    debugPrint('SettingsPage: User data - Email: ${user?['email']}, Role: ${user?['role']}');
    
    _viewModel = SettingsViewModel(
      SettingsRepositoryImpl(
        widget.db,
        companyId: companyId,
        isSuperAdmin: isSuper,
      ),
    );
    
    if (_mounted) {
      setState(() {});
      
      try {
        await _viewModel!.initialize();
      } catch (e) {
        debugPrint('SettingsViewModel initialization error: $e');
        if (_mounted && _viewModel != null) {
          _viewModel!.forceLoadingComplete();
        }
      }
      
      if (_mounted && _viewModel != null && _viewModel!.loading) {
        debugPrint('SettingsPage: Loading still true after initialization, forcing completion');
        _viewModel!.forceLoadingComplete();
      }
      
      _initialized = true;
      setState(() {});
      
      if (_mounted && _viewModel != null) {
        _viewModel!.syncProfileForm(
          fullNameController: _fullNameController,
          phoneController: _phoneController,
          companyController: _companyController,
          emailController: _emailController,
        );
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_viewModel == null) return;
    
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (result == null) return;
      
      await _viewModel!.updateProfileImage(result.path);
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_viewModel == null || _viewModel!.currentUser == null) return;
    if (_profileFormKey.currentState?.validate() != true) return;

    final canEditCompany = RoleUtils.isSuperAdmin(_viewModel!.currentUser);
    final canEditNamePhone = canEditCompany || RoleUtils.isCompanyAdmin(_viewModel!.currentUser) || RoleUtils.isAgent(_viewModel!.currentUser);
    
    if (!canEditCompany && !canEditNamePhone) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to edit profile'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await _viewModel!.updateProfile(
        name: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        profilePicturePath: _viewModel!.profileImagePath,
      );
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSociety() async {
    if (_viewModel == null) return;
    
    final name = _societyNameController.text.trim();
    if (name.isEmpty) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a society name'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await _viewModel!.addSociety(name);
      _societyNameController.clear();
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding society: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addBlock() async {
    if (_viewModel == null) return;
    
    final name = _blockNameController.text.trim();
    if (name.isEmpty) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a block name'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await _viewModel!.addBlock(name);
      _blockNameController.clear();
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ FIXED: Simplified delete society - no pre-clearing
Future<void> _deleteSociety(String societyId, String societyName) async {
  if (_viewModel == null || _isDeleting) return;
  
  if (societyId.isEmpty) {
    debugPrint('SettingsPage: Cannot delete society - empty ID');
    return;
  }
  
  final messenger = ScaffoldMessenger.of(context);
  
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Society'),
      content: Text('Are you sure you want to delete "$societyName"? All its blocks will also be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !_mounted) return;

  setState(() {
    _isDeleting = true;
  });

  try {
    debugPrint('SettingsPage: Starting delete operation for society: $societyId');
    
    // ✅ CRITICAL FIX: Sirf deleteSociety call karein, setSelectedSociety nahi
    // deleteSociety method khud selection clear karega agar zaroorat ho
    await _viewModel!.deleteSociety(societyId);
    
    debugPrint('SettingsPage: Delete operation completed successfully');
    
    if (_mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Society deleted successfully'), 
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e, stackTrace) {
    debugPrint('SettingsPage: Error deleting society: $e');
    debugPrint('SettingsPage: Stack trace: $stackTrace');
    
    if (_mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting society: ${e.toString()}'), 
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (_mounted) {
      setState(() {
        _isDeleting = false;
      });
    }
  }
}

  // ✅ FIXED: Delete block with complete safety
  Future<void> _deleteBlock(String blockId, String blockName) async {
    if (_viewModel == null || _isDeleting) return;
    
    if (blockId.isEmpty) {
      debugPrint('SettingsPage: Cannot delete block - empty ID');
      return;
    }
    
    final messenger = ScaffoldMessenger.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Block'),
        content: Text('Are you sure you want to delete "$blockName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !_mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      debugPrint('SettingsPage: Starting delete operation for block: $blockId');
      
      await _viewModel!.deleteBlock(blockId);
      
      debugPrint('SettingsPage: Block delete completed successfully');
      
      if (_mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Block deleted successfully'), 
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('SettingsPage: Error deleting block: $e');
      debugPrint('SettingsPage: Stack trace: $stackTrace');
      
      if (_mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting block: ${e.toString()}'), 
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (_mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _exportData() async {
    if (_viewModel == null) return;
    
    try {
      await _viewModel!.exportDataToCsv();
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualCompanyId = RoleUtils.getUserCompanyId(user) ?? 'GLOBAL_ADMIN';
    final actualIsSuperAdmin = RoleUtils.isSuperAdmin(user);

    final viewModel = _viewModel ?? SettingsViewModel(
      SettingsRepositoryImpl(
        widget.db,
        companyId: actualCompanyId,
        isSuperAdmin: actualIsSuperAdmin,
      ),
    );
    
    if (_loadingStartTime != null && 
        DateTime.now().difference(_loadingStartTime!) > _maxLoadingTime &&
        viewModel.loading) {
      debugPrint('SettingsPage: Loading timeout reached, forcing completion');
      viewModel.forceLoadingComplete();
      _loadingStartTime = null;
    }
    
    if (viewModel.loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Settings', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFF4A90E2),
                ],
              ),
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  key: ValueKey('export_data_${DateTime.now().millisecondsSinceEpoch}'),
                  onPressed: _isDeleting ? null : _exportData,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    textStyle: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              _buildProfileSection(),
              const SizedBox(height: 24),
              _buildSocietiesSection(),
              const SizedBox(height: 24),
              _buildBlocksSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Consumer<SettingsViewModel>(
      builder: (context, viewModel, child) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _isDeleting ? null : _pickProfilePhoto,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: viewModel.profileImagePath != null && !kIsWeb
                            ? FileImage(File(viewModel.profileImagePath!)) as ImageProvider
                            : null,
                        child: viewModel.profileImagePath == null
                            ? const Icon(Icons.person, size: 40, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Settings',
                            style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your personal information',
                            style: AppFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.savingProfile)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _profileFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        enabled: !_isDeleting,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_isDeleting,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (RoleUtils.isSuperAdmin(viewModel.currentUser))
                        TextFormField(
                          controller: _companyController,
                          enabled: !_isDeleting,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: ValueKey('save_profile_${viewModel.currentUser?["id"] ?? "unknown"}'),
                          onPressed: (viewModel.savingProfile || _isDeleting) ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: viewModel.savingProfile
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save Profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocietiesSection() {
    return Consumer<SettingsViewModel>(
      builder: (context, viewModel, child) {
        // ✅ CRITICAL: Safe access to societies list
        final societies = viewModel.societies ?? [];
        final selectedId = viewModel.selectedSocietyId;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Societies',
                  style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _societyNameController,
                        enabled: !_isDeleting,
                        decoration: const InputDecoration(
                          labelText: 'Society Name',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      key: ValueKey('add_society_${DateTime.now().millisecondsSinceEpoch}'),
                      onPressed: _isDeleting ? null : _addSociety,
                      icon: _isDeleting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        textStyle: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (societies.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'No societies added yet',
                          style: AppFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  // ✅ CRITICAL: Use Column instead of ListView.builder for better stability
                  ...societies.map((society) {
                    final societyId = society['id']?.toString() ?? '';
                    final societyName = society['name']?.toString() ?? 'Unknown';
                    final isSelected = selectedId == societyId;
                    
                    return ListTile(
                      key: ValueKey('society_$societyId'),
                      title: Text(societyName),
                      subtitle: Text('ID: $societyId'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDeleting)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              key: ValueKey('delete_society_$societyId'),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSociety(societyId, societyName),
                              tooltip: 'Delete Society',
                            ),
                        ],
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.orange.shade50,
                      onTap: _isDeleting ? null : () => viewModel.setSelectedSociety(societyId),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlocksSection() {
    return Consumer<SettingsViewModel>(
      builder: (context, viewModel, child) {
        // ✅ CRITICAL: Safe access to all properties
        final hasSelectedSociety = viewModel.selectedSocietyId != null && 
                                    viewModel.selectedSocietyId!.isNotEmpty;
        final blocks = viewModel.blocks ?? [];
        final isLoadingBlocks = viewModel.isLoadingBlocks;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocks',
                  style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!hasSelectedSociety) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Please select a society first to manage blocks',
                          style: AppFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _blockNameController,
                          enabled: !_isDeleting,
                          decoration: const InputDecoration(
                            labelText: 'Block Name',
                            prefixIcon: Icon(Icons.apartment),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        key: ValueKey('add_block_${viewModel.selectedSocietyId}_${DateTime.now().millisecondsSinceEpoch}'),
                        onPressed: _isDeleting ? null : _addBlock,
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          textStyle: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingBlocks)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Loading blocks...',
                            style: AppFonts.poppins(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else if (blocks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'No blocks added for this society',
                            style: AppFonts.poppins(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else
                    // ✅ CRITICAL: Use Column instead of ListView.builder
                    ...blocks.map((block) {
                      final blockId = block['id']?.toString() ?? '';
                      final blockName = block['name']?.toString() ?? 'Unknown';
                      
                      return ListTile(
                        key: ValueKey('block_$blockId'),
                        title: Text(blockName),
                        subtitle: Text('ID: $blockId'),
                        trailing: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                key: ValueKey('delete_block_$blockId'),
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteBlock(blockId, blockName),
                                tooltip: 'Delete Block',
                              ),
                      );
                    }).toList(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}