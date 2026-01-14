import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared/shared.dart';
import '../core/services/app_storage.dart' show AppStorage;
import '../core/services/permission_helper.dart';
import '../core/services/auth_service.dart';

// Note: This sidebar widget is designed to work independently and can be used
// with any theme management system by passing themeMode and onThemeChanged callbacks.

/// Modern sidebar widget with trading menu support
class ModernSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onTradingTap;
  final VoidCallback onLogout;
  final int? badgeFiles;
  final int? badgeRentals;
  final VoidCallback onToggle;
  final bool isOpen;
  final ThemeMode? themeMode;
  final ValueChanged<String>? onThemeChanged;
  final Map<String, dynamic>? currentUser;

  const ModernSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onTradingTap,
    required this.onLogout,
    required this.onToggle,
    required this.isOpen,
    this.badgeFiles,
    this.badgeRentals,
    this.themeMode,
    this.onThemeChanged,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDarkMode = isDark || themeMode == ThemeMode.dark;
    final isBypass = PermissionHelper.isBypassUser(currentUser);
    bool _canSee(String moduleKey) {
      if (isBypass) return true;
      final level = PermissionHelper.getModulePermissionLevel(currentUser, moduleKey);
      return level != 'no_access';
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFF6B35), const Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'RE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Real Estate',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800, // Dark grey for better readability
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isOpen ? Icons.chevron_right : Icons.chevron_left,
                      size: 20,
                    ),
                    color: const Color(0xFFFF6B35), // Orange
                    onPressed: onToggle,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1), // Light orange background
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SidebarMenuItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'Dashboard',
                    isSelected: selectedIndex == 0,
                    onTap: () => onDestinationSelected(0),
                  ),
                  SidebarMenuItem(
                    icon: Icons.insert_drive_file_outlined,
                    selectedIcon: Icons.insert_drive_file,
                    label: 'Inventory',
                    isSelected: selectedIndex == 1,
                    onTap: _canSee('inventory') ? () => onDestinationSelected(1) : null,
                    badge: badgeFiles,
                    visible: _canSee('inventory'),
                  ),
                  SidebarMenuItem(
                    icon: Icons.support_agent_outlined,
                    selectedIcon: Icons.support_agent,
                    label: 'Agent Working',
                    isSelected: selectedIndex == 2,
                    onTap: _canSee('agent_working') ? () => onDestinationSelected(2) : null,
                    visible: _canSee('agent_working'),
                  ),
                  SidebarMenuItem(
                    icon: Icons.chair_outlined,
                    selectedIcon: Icons.chair,
                    label: 'Rental Items',
                    isSelected: selectedIndex == 3,
                    onTap: _canSee('rental_items') ? () => onDestinationSelected(3) : null,
                    badge: badgeRentals,
                    visible: _canSee('rental_items'),
                  ),
                  SidebarMenuItem(
                    icon: Icons.checklist_outlined,
                    selectedIcon: Icons.checklist,
                    label: 'To-Do',
                    isSelected: selectedIndex == 4,
                    onTap: _canSee('todo') ? () => onDestinationSelected(4) : null,
                    visible: _canSee('todo'),
                  ),
                  SidebarMenuItem(
                    icon: Icons.payments_outlined,
                    selectedIcon: Icons.payments,
                    label: 'Expenditure',
                    isSelected: selectedIndex == 10,
                    onTap: _canSee('expenditure') ? () => onDestinationSelected(10) : null,
                    visible: _canSee('expenditure'),
                  ),
                  // Trading - Direct Navigation
                  if (onTradingTap != null)
                    SidebarMenuItem(
                      icon: Icons.currency_exchange_outlined,
                      selectedIcon: Icons.currency_exchange,
                      label: 'Trading',
                      isSelected: selectedIndex == 6 || selectedIndex == 7,
                      onTap: _canSee('trading') ? onTradingTap! : null,
                      visible: _canSee('trading'),
                    ),
                  SidebarMenuItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    isSelected: selectedIndex == 5,
                    onTap: () => onDestinationSelected(5),
                  ),
                ],
              ),
            ),
            // Separator
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            // Logout
            SidebarMenuItem(
              icon: Icons.logout,
              selectedIcon: Icons.logout,
              label: 'Logout',
              isSelected: false,
              onTap: onLogout,
            ),
            // Dark Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isDarkMode ? 'Light Mode' : 'Dark Mode',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Switch(
                    value: isDarkMode,
                    onChanged: (value) async {
                      final next = value ? 'dark' : 'light';
                      final s = await AppStorage().readSettings();
                      s['theme'] = next;
                      await AppStorage().writeSettings(s);
                      onThemeChanged?.call(next);
                    },
                    activeColor: const Color(0xFFFF6B35), // Orange
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Sidebar menu item widget
class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSubItem;
  final int? badge;
  final bool visible;

  const SidebarMenuItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isSubItem = false,
    this.badge,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSubItem ? 48 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent, // Orange for selected
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 9,
                backgroundColor: isSelected ? Colors.white : const Color(0xFF4A90E2), // Blue for badge
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? const Color(0xFFFF6B35) : Colors.white, // Orange when selected
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trading sidebar menu widget (legacy, kept for compatibility)
class TradingSidebarMenu extends StatelessWidget {
  final bool expanded;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onSelect;
  final int navIndex;
  
  const TradingSidebarMenu({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
    required this.navIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Trading'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => onToggle(!expanded),
          ),
          if (expanded) ...[
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 40, right: 16),
              title: const Text('File'),
              selected: navIndex == 8,
              onTap: () => onSelect(8),
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 40, right: 16),
              title: const Text('Form'),
              selected: navIndex == 9,
              onTap: () => onSelect(9),
            ),
          ],
        ],
      ),
    );
  }
}

