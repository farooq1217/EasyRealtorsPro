import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import '../core/utils/platform_utils.dart';
import '../core/utils/ui_utils.dart';
import '../core/utils/image_utils.dart';
import 'platform_aware_image.dart';

/// Responsive navigation widget that adapts to platform and screen size
class ResponsiveNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final Function() onLogout;
  final Map<String, dynamic>? currentUser;
  final int? badgeFiles;
  final int? badgeRentals;
  final Widget child;
  final List<NavigationItem> navigationItems;

  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.child,
    this.currentUser,
    this.badgeFiles,
    this.badgeRentals,
    this.navigationItems = const [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      NavigationItem(
        icon: Icons.inventory_outlined,
        selectedIcon: Icons.inventory,
        label: 'Inventory',
      ),
      NavigationItem(
        icon: Icons.work_outline,
        selectedIcon: Icons.work,
        label: 'Agent Work',
      ),
      NavigationItem(
        icon: Icons.home_work_outlined,
        selectedIcon: Icons.home_work,
        label: 'Rentals',
      ),
      NavigationItem(
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist,
        label: 'To-Do',
      ),
      NavigationItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine navigation type based on screen size and platform
        final useDrawer = _shouldUseDrawer(constraints);
        
        if (useDrawer) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  /// Determine if drawer should be used based on screen size and platform
  bool _shouldUseDrawer(BoxConstraints constraints) {
    // Use drawer on mobile platforms
    if (PlatformUtils.isMobile) return true;
    
    // Use drawer on small screens (less than 768px)
    if (constraints.maxWidth < 768) return true;
    
    // Use drawer on web with small screens
    if (kIsWeb && constraints.maxWidth < 1024) return true;
    
    return false;
  }

  /// Build mobile layout with drawer
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: child,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B35),
                    const Color(0xFF4A90E2),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: currentUser?['profile_picture_path'] != null
                              ? null
                              : null,
                          child: currentUser?['profile_picture_path'] == null
                              ? Text(
                                  (currentUser?['name']?.isNotEmpty == true)
                                      ? currentUser!['name'].substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : _buildProfileImage(context, currentUser?['profile_picture_path']),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser?['name'] ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currentUser?['email'] ?? 'user@example.com',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EasyRealtorsPro',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Navigation Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: navigationItems.length,
                itemBuilder: (context, index) {
                  final item = navigationItems[index];
                  final isSelected = selectedIndex == index;
                  final badge = _getBadgeForIndex(index);
                  
                  return ListTile(
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[600],
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: badge != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    selected: isSelected,
                    selectedTileColor: const Color(0xFFFF6B35).withOpacity(0.1),
                    onTap: () {
                      onDestinationSelected(index);
                      Navigator.of(context).pop(); // Close drawer
                    },
                  );
                },
              ),
            ),
            
            // Logout Button
            Container(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  onLogout();
                },
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          navigationItems[selectedIndex].label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  /// Build desktop layout with sidebar
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Navigation Rail or Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF6B35),
                      const Color(0xFF4A90E2),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: currentUser?['profile_picture_path'] != null
                              ? null
                              : null,
                          child: currentUser?['profile_picture_path'] == null
                              ? Text(
                                  (currentUser?['name']?.isNotEmpty == true)
                                      ? currentUser!['name'].substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : _buildProfileImage(context, currentUser?['profile_picture_path']),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser?['name'] ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currentUser?['email'] ?? 'user@example.com',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'EasyRealtorsPro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Navigation Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: navigationItems.length,
                  itemBuilder: (context, index) {
                    final item = navigationItems[index];
                    final isSelected = selectedIndex == index;
                    final badge = _getBadgeForIndex(index);
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[600],
                          size: 24,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[800],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                        trailing: badge != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  badge.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        selected: isSelected,
                        onTap: () => onDestinationSelected(index),
                      ),
                    );
                  },
                ),
              ),
              
              // Logout Button
              Container(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 24,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ),
        
        // Content Area
        Expanded(child: child),
      ],
    );
  }

  /// Build profile image with web support
  Widget _buildProfileImage(BuildContext context, String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Icon(Icons.person, color: Colors.white, size: 24);
    }
    
    return PlatformAwareImage(
      imagePath: imagePath,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      builder: (context, imageWidget) {
        return ClipOval(child: imageWidget);
      },
      placeholder: const Icon(Icons.person, color: Colors.white, size: 24),
      errorWidget: const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }

  /// Get badge count for navigation item
  int? _getBadgeForIndex(int index) {
    switch (index) {
      case 1: // Inventory
        return badgeFiles;
      case 3: // Rentals
        return badgeRentals;
      default:
        return null;
    }
  }
}

/// Navigation item model
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
