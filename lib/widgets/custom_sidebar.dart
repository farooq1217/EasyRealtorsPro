import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/font_utils.dart';
import 'package:shared/shared.dart';
import '../core/services/app_storage.dart' show AppStorage;
import '../core/services/permission_helper.dart';
import '../core/services/auth_service.dart';
import '../core/role_utils.dart' as local;

// Note: This sidebar widget is designed to work independently and can be used
// with any theme management system by passing themeMode and onThemeChanged callbacks.

/// Modern sidebar widget with trading menu support
/// ✅ REFACTORED: Clean permission logic, comprehensive logging, no duplication
class ModernSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onTradingTap;
  final VoidCallback onLogout;
  final int? badgeFiles;
  final int? badgeRentals;
  final VoidCallback onToggle;
  final bool isOpen;
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
    this.currentUser,
  });

  // ✅ HELPER: Extract permissionsMap from user object (handles nested structure)
  Map<String, dynamic>? _extractPermissionsMap(Map<String, dynamic>? user) {
    if (user == null) return null;
    
    // Try direct permissionsMap first (top-level)
    var raw = user['permissionsMap'];
    
    // If not found, try nested inside permissions field
    if (raw == null && user['permissions'] != null) {
      final perms = user['permissions'];
      try {
        Map<String, dynamic>? decoded;
        if (perms is String) {
          decoded = jsonDecode(perms) as Map<String, dynamic>?;
        } else if (perms is Map) {
          decoded = perms as Map<String, dynamic>?;
        }
        if (decoded != null && decoded.containsKey('permissionsMap')) {
          raw = decoded['permissionsMap'];
        }
      } catch (e) {
        debugPrint('❌ Sidebar: Failed to decode permissions JSON: $e');
        return null;
      }
    }
    
    // Handle JSON string permissionsMap (if stored as string in DB)
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (e) {
        debugPrint('❌ Sidebar: Failed to decode permissionsMap string: $e');
        return null;
      }
    }
    
    return raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : null;
  }

  // ✅ HELPER: Normalize module key to handle snake_case vs camelCase mismatch
  String _normalizeModuleKey(String key) {
    // Convert snake_case to camelCase: agent_working → agentWorking
    return key.replaceAllMapped(RegExp(r'_([a-z])'), 
      (match) => match.group(1)!.toUpperCase());
  }

  // ✅ HELPER: Check if permission level is valid (not no_access)
  bool _isValidPermissionLevel(String? level) {
    if (level == null) return false;
    final normalized = level.toLowerCase().trim();
    return normalized != 'no_access' && 
           normalized != 'false' && 
           normalized != '0' &&
           normalized.isNotEmpty;
  }

  // ✅ CORE LOGIC: Determine if user can see a module
 bool _canSee(String moduleKey) {
  // Universal modules - always visible
  const universalModules = {'dashboard', 'settings'};
  if (universalModules.contains(moduleKey)) return true;

  // ✅ CRITICAL: If currentUser is null, hide everything (prevent errors)
  if (currentUser == null) {
    debugPrint('⚠️ Sidebar: currentUser is null, hiding $moduleKey');
    return false;
  }

  // ✅ Extract role & permissions ONCE (avoid repeated calls)
  final role = local.RoleUtils.getUserRole(currentUser).toLowerCase().trim();
  final permissionsMap = _extractPermissionsMap(currentUser);
  
  debugPrint('🔍 Sidebar: $moduleKey check - role="$role", permissionsMap keys: ${permissionsMap?.keys.toList()}');

  // ✅ Admin bypass: Check role directly (not via helper that might use stale cache)
  final isAdmin = role == 'super_admin' || 
                  role == 'superadmin' || 
                  role == 'super admin' ||
                  role == 'company_admin' || 
                  role == 'companyadmin' || 
                  role == 'company admin';
                  
  if (isAdmin) {
    debugPrint('✅ Sidebar: ADMIN BYPASS GRANTED for $moduleKey (role: $role)');
    return true;
  }

  // ✅ Permission-based check for non-admins
  if (permissionsMap == null || permissionsMap.isEmpty) {
    debugPrint('❌ Sidebar: DENIED $moduleKey - no permissionsMap');
    return false;
  }

  // Handle snake_case ↔ camelCase mismatch
  final normalizedKey = _normalizeModuleKey(moduleKey);
  final permValue = 
      permissionsMap[moduleKey]?.toString().toLowerCase() ?? 
      permissionsMap[normalizedKey]?.toString().toLowerCase();

  final isAllowed = _isValidPermissionLevel(permValue);
  debugPrint('${isAllowed ? '✅' : '❌'} Sidebar: $moduleKey → $permValue → ${isAllowed ? 'GRANTED' : 'DENIED'}');
  
  return isAllowed;
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isOpen ? 280 : 80,
        minWidth: isOpen ? 280 : 80,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A90E2).withOpacity(0.8),
                Color(0xFF2C3E50).withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: isOpen ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(-2, -2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(4, 8),
              ),
            ] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // ✅ Header - Responsive based on isOpen state
              Container(
                margin: const EdgeInsets.all(16),
                padding: EdgeInsets.symmetric(horizontal: isOpen ? 16 : 8, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: isOpen 
                  ? Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                            onPressed: onToggle,
                            style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero),
                            tooltip: 'Toggle Sidebar',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text('ERP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'EasyRealtorsPro',
                            style: AppFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: IconButton(
                            icon: Icon(isOpen ? Icons.chevron_left : Icons.chevron_right, size: 18),
                            color: Colors.white,
                            onPressed: onToggle,
                            style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                            onPressed: onToggle,
                            style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero),
                            tooltip: 'Toggle Sidebar',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text('ERP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
              ),
              
              // ✅ Menu Items - Always show icons, labels only when open
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SidebarMenuItem(
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard,
                        label: 'Dashboard',
                        isSelected: selectedIndex == 0,
                        onTap: () => onDestinationSelected(0),
                        visible: _canSee('dashboard'),
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.insert_drive_file_outlined,
                        selectedIcon: Icons.insert_drive_file,
                        label: 'Inventory',
                        isSelected: selectedIndex == 1,
                        onTap: _canSee('inventory') ? () => onDestinationSelected(1) : null,
                        badge: badgeFiles,
                        visible: _canSee('inventory'),
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.support_agent_outlined,
                        selectedIcon: Icons.support_agent,
                        label: 'Agent Working',
                        isSelected: selectedIndex == 2,
                        onTap: _canSee('agent_working') ? () => onDestinationSelected(2) : null,
                        visible: _canSee('agent_working'),
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.chair_outlined,
                        selectedIcon: Icons.chair,
                        label: 'Rental Items',
                        isSelected: selectedIndex == 3,
                        onTap: _canSee('rental_items') ? () => onDestinationSelected(3) : null,
                        badge: badgeRentals,
                        visible: _canSee('rental_items'),
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.checklist_outlined,
                        selectedIcon: Icons.checklist,
                        label: 'To-Do',
                        isSelected: selectedIndex == 4,
                        onTap: _canSee('todo') ? () => onDestinationSelected(4) : null,
                        visible: _canSee('todo'),
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.payments_outlined,
                        selectedIcon: Icons.payments,
                        label: 'Expenditure',
                        isSelected: selectedIndex == 10,
                        onTap: _canSee('expenditure') ? () => onDestinationSelected(10) : null,
                        visible: _canSee('expenditure'),
                        showLabel: isOpen,
                      ),
                      // Trading - Direct Navigation
                      if (onTradingTap != null)
                        SidebarMenuItem(
                          icon: Icons.currency_exchange_outlined,
                          selectedIcon: Icons.currency_exchange,
                          label: 'Trading',
                          isSelected: false,
                          onTap: _canSee('trading') ? onTradingTap : null,
                          visible: _canSee('trading'),
                          showLabel: isOpen,
                        ),
                      SidebarMenuItem(
                        icon: Icons.bar_chart_outlined,
                        selectedIcon: Icons.bar_chart,
                        label: 'Reports',
                        isSelected: selectedIndex == 8,
                        onTap: _canSee('reports') ? () => onDestinationSelected(8) : null,
                        visible: _canSee('reports'),
                        showLabel: isOpen,
                      ),
                      // Admin Menu Items with individual visibility control
                      SidebarMenuItem(
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people,
                        label: 'User Management',
                        isSelected: selectedIndex == 9,
                        onTap: _canSee('users') ? () => onDestinationSelected(9) : null,
                        visible: _canSee('users'),
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.business_outlined,
                        selectedIcon: Icons.business,
                        label: 'Company Management',
                        isSelected: selectedIndex == 11,
                        onTap: () => onDestinationSelected(11),
                        visible: local.RoleUtils.isSuperAdmin(currentUser),// Only visible to super_admin
                        showLabel: isOpen,
                      ),
                      SidebarMenuItem(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: 'Settings',
                        isSelected: selectedIndex == 5,
                        onTap: _canSee('settings') ? () => onDestinationSelected(5) : null,
                        visible: _canSee('settings'),
                        showLabel: isOpen,
                      ),
                    ],
                  ),
                ),
              ),
              
              // ✅ Separator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.white.withOpacity(0.2), Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // ✅ Logout
              SidebarMenuItem(
                icon: Icons.logout,
                selectedIcon: Icons.logout,
                label: 'Logout',
                isSelected: false,
                onTap: onLogout,
                showLabel: isOpen,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ Sidebar menu item widget - Clean, reusable, with badge support
class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSubItem;
  final int? badge;
  final bool visible;
  final bool showLabel;

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
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 8, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            constraints: BoxConstraints(minWidth: showLabel ? 200 : 64, minHeight: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: showLabel 
              ? Row(
                  children: [
                    // Orange Active Indicator
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), bottomLeft: Radius.circular(2)),
                          boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
                        ),
                      ),
                    
                    // Menu Item Container
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: isSelected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -3)),
                                BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 20, spreadRadius: 2),
                                BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.2), blurRadius: 15, spreadRadius: 1),
                              ] : [
                                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(isSelected ? selectedIcon : icon, color: Colors.white, size: 22),
                                if (showLabel) ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      label, 
                                      style: TextStyle(
                                        color: Colors.white, 
                                        fontSize: 14, 
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400
                                      )
                                    )
                                  ),
                                  if (badge != null && badge! > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
                                      ),
                                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -3)),
                            BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.2), blurRadius: 15, spreadRadius: 1),
                          ] : [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Icon(isSelected ? selectedIcon : icon, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// ✅ Trading sidebar menu widget (legacy, kept for compatibility)
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