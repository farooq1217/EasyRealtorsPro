// presentation/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import '../../../core/services/app_storage.dart' show AppStorage;
import '../../../core/services/auth_service.dart';
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
  Map<String, dynamic>? user; // Store user data for access in build method
  final TextEditingController _societyNameController = TextEditingController();
  final TextEditingController _blockNameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  bool _mounted = true;
  bool _initialized = false; // Track initialization state
  
  // CRITICAL FIX: Add timeout mechanism to prevent infinite loading
  DateTime? _loadingStartTime;
  static const Duration _maxLoadingTime = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _loadingStartTime = DateTime.now();
    
    // PRE-FETCH CHECK: Initialize ViewModel immediately to prevent hanging
    // This ensures the ViewModel is ready before the navigation animation completes
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
    // Prevent duplicate initialization
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
    
    // ROLE SYNC FIX: Enhanced role detection
    final isSuper = RoleUtils.isSuperAdmin(user) || PermissionHelper.isBypassUser(user);
    var companyId = RoleUtils.getUserCompanyId(user);
    
    // IMMEDIATE FALLBACK: Set default fallback for null companyId
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
      
      // CRITICAL FIX: Initialize with proper error handling and ensure loading state is resolved
      try {
        await _viewModel!.initialize();
      } catch (e) {
        debugPrint('SettingsViewModel initialization error: $e');
        // Force loading state to false even if initialization fails
        if (_mounted && _viewModel != null) {
          _viewModel!.forceLoadingComplete();
        }
      }
      
      // SAFETY CHECK: Ensure loading is definitely false after initialization
      if (_mounted && _viewModel != null && _viewModel!.loading) {
        debugPrint('SettingsPage: Loading still true after initialization, forcing completion');
        _viewModel!.forceLoadingComplete();
      }
      
      _initialized = true;
      setState(() {}); // Trigger rebuild with initialized ViewModel
      
      // Sync form after initialization is complete
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

  Future<void> _deleteSociety(String societyId) async {
    if (_viewModel == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Society'),
        content: const Text('Are you sure you want to delete this society? All its blocks will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _viewModel!.deleteSociety(societyId);
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting society: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    if (_viewModel == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Block'),
        content: const Text('Are you sure you want to delete this block?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _viewModel!.deleteBlock(blockId);
      
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting block: $e'), backgroundColor: Colors.red),
        );
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
    companyId: actualCompanyId,  // ✅ Dynamic value
    isSuperAdmin: actualIsSuperAdmin,  // ✅ Dynamic value
  ),
);
    
    // ViewModel initialization is now handled only in initState() to prevent duplicates
    // No fallback needed as initState() ensures proper initialization
    
    // CRITICAL FIX: Check for infinite loading and force resolution
    if (_loadingStartTime != null && 
        DateTime.now().difference(_loadingStartTime!) > _maxLoadingTime &&
        viewModel.loading) {
      debugPrint('SettingsPage: Loading timeout reached, forcing completion');
      viewModel.forceLoadingComplete();
      _loadingStartTime = null; // Prevent repeated checks
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
                  Color(0xFFFF6B35), // Orange
                  Color(0xFF4A90E2), // Blue
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
              // Export button
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                // CRITICAL FIX: Add unique key to prevent GlobalKey duplication
                child: ElevatedButton.icon(
                  key: ValueKey('export_data_${DateTime.now().millisecondsSinceEpoch}'),
                  onPressed: _exportData,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    // CRITICAL FIX: Fix TextStyle interpolation
                    textStyle: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              // Profile Section
              _buildProfileSection(),
              const SizedBox(height: 24),
              
              // Societies Section
              _buildSocietiesSection(),
              const SizedBox(height: 24),
              
              // Blocks Section
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
                      onTap: _pickProfilePhoto,
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
                        enabled: false, // Email is typically not editable
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
                          onPressed: viewModel.savingProfile ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            // CRITICAL FIX: Fix TextStyle interpolation by using consistent theme
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
                        decoration: const InputDecoration(
                          labelText: 'Society Name',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // CRITICAL FIX: Add unique key to prevent GlobalKey duplication
                    ElevatedButton.icon(
                      key: ValueKey('add_society_${DateTime.now().millisecondsSinceEpoch}'),
                      onPressed: _addSociety,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        // CRITICAL FIX: Fix TextStyle interpolation
                        textStyle: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (viewModel.societies.isEmpty)
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
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.societies.length,
                    itemBuilder: (context, index) {
                      final society = viewModel.societies[index];
                      // CRITICAL FIX: Add unique key to each ListTile to prevent GlobalKey duplication
                      return ListTile(
                        key: ValueKey('society_${society['id']}_$index'),
                        title: Text(society['name'] ?? ''),
                        subtitle: Text('ID: ${society['id'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          // CRITICAL FIX: Prevent horizontal overflow by constraining Row
                          children: [
                            // CRITICAL FIX: Add unique key to IconButton
                            IconButton(
                              key: ValueKey('delete_society_${society['id']}_$index'),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSociety(society['id'] ?? ''),
                              tooltip: 'Delete Society',
                            ),
                          ],
                        ),
                        selected: viewModel.selectedSocietyId == society['id'],
                        selectedTileColor: Colors.orange.shade50,
                        onTap: () => viewModel.setSelectedSociety(society['id']),
                      );
                    },
                  ),
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
        final hasSelectedSociety = viewModel.selectedSocietyId != null;
        
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
                          decoration: const InputDecoration(
                            labelText: 'Block Name',
                            prefixIcon: Icon(Icons.apartment),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // CRITICAL FIX: Add unique key to prevent GlobalKey duplication
                      ElevatedButton.icon(
                        key: ValueKey('add_block_${viewModel.selectedSocietyId}_${DateTime.now().millisecondsSinceEpoch}'),
                        onPressed: _addBlock,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          // CRITICAL FIX: Fix TextStyle interpolation
                          textStyle: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (viewModel.isLoadingBlocks)
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
                  else if (viewModel.blocks.isEmpty)
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
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: viewModel.blocks.length,
                      itemBuilder: (context, index) {
                        final block = viewModel.blocks[index];
                        // CRITICAL FIX: Add unique key to each ListTile to prevent GlobalKey duplication
                        return ListTile(
                          key: ValueKey('block_${block['id']}_$index'),
                          title: Text(block['name'] ?? ''),
                          subtitle: Text('ID: ${block['id'] ?? ''}'),
                          trailing: IconButton(
                            key: ValueKey('delete_block_${block['id']}_$index'),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBlock(block['id'] ?? ''),
                            tooltip: 'Delete Block',
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
