import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/font_utils.dart';
import 'package:shared/shared.dart';
import '../core/services/app_storage.dart' show AppStorage;
import '../core/services/permission_helper.dart';
import 'package:easyrealtorspro/core/services/auth/auth_service.dart';
import '../core/role_utils.dart' as local;

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

  // ✅ HELPER: Extract permissionsMap (Same as yours)
  Map<String, dynamic>? _extractPermissionsMap(Map<String, dynamic>? user) {
    if (user == null) return null;
    var raw = user['permissionsMap'];
    if (raw == null && user['permissions'] != null) {
      final perms = user['permissions'];
      try {
        Map<String, dynamic>? decoded;
        if (perms is String) {
          final decodedRaw = jsonDecode(perms);
          if (decodedRaw is Map) decoded = Map<String, dynamic>.from(decodedRaw);
        } else if (perms is Map) {
          decoded = Map<String, dynamic>.from(perms);
        }
        if (decoded != null && decoded.containsKey('permissionsMap')) {
          final nested = decoded['permissionsMap'];
          raw = nested is Map ? Map<String, dynamic>.from(nested) : nested;
        } else if (decoded != null) {
          final hasModuleKeys = decoded.keys.any((k) =>
            ['trading', 'inventory', 'rental', 'expenditure', 'agent_working',
             'reports', 'users', 'companies', 'dashboard', 'settings', 'todo',
             'rental_items'].contains(k));
          if (hasModuleKeys) {
            raw = Map<String, dynamic>.from(decoded)
              ..remove('role')..remove('companyId')..remove('company_id');
          }
        }
      } catch (e) { return null; }
    }
    if (raw is String) { try { raw = jsonDecode(raw); } catch (e) { return null; } }
    return raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : null;
  }

  String _normalizeModuleKey(String key) {
    return key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
  }

  bool _isValidPermissionLevel(String? level) {
    if (level == null) return false;
    final normalized = level.toLowerCase().trim();
    return normalized != 'no_access' && normalized != 'false' && normalized != '0' && normalized.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ✅ CRITICAL FIX 1: Extract Role and Permissions ONCE per build
    final role = currentUser != null ? local.RoleUtils.getUserRole(currentUser).toLowerCase().trim() : '';
    final permissionsMap = _extractPermissionsMap(currentUser); // Sirf 1 baar JSON parse hoga!
    
    final isAdmin = role == 'super_admin' || role == 'superadmin' || role == 'super admin' ||
                    role == 'company_admin' || role == 'companyadmin' || role == 'company admin';

    // ✅ CRITICAL FIX 2: Local function without logs and JSON parsing
    bool canSee(String moduleKey) {
      if ({'dashboard', 'settings'}.contains(moduleKey)) return true;
      if (currentUser == null) return false;
      if (isAdmin) return true;
      if (permissionsMap == null || permissionsMap.isEmpty) return false;
      
      final normalizedKey = _normalizeModuleKey(moduleKey);
      final permValue = permissionsMap[moduleKey]?.toString().toLowerCase() ?? 
                        permissionsMap[normalizedKey]?.toString().toLowerCase();
      return _isValidPermissionLevel(permValue);
    }

    // ✅ CRITICAL FIX 3: Calculate visibility ONCE and store in variables
    final canSeeInventory = canSee('inventory');
    final canSeeAgent = canSee('agent_working');
    final canSeeRental = canSee('rental_items');
    final canSeeTodo = canSee('todo');
    final canSeeExpenditure = canSee('expenditure');
    final canSeeTrading = canSee('trading');
    final canSeeFollowUp = canSee('follow_up');
    final canSeeReports = canSee('reports');
    final canSeeUsers = canSee('users');
    final isSuperAdmin = local.RoleUtils.isSuperAdmin(currentUser);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isOpen ? 280 : 80, minWidth: isOpen ? 280 : 80),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF4A90E2).withOpacity(0.8), Color(0xFF2C3E50).withOpacity(0.95)],
            ),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
            boxShadow: isOpen ? [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(-2, -2)),
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 25, offset: const Offset(4, 8)),
            ] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header (Aapka purana header code yahan rahega, maine space ke liye skip kiya hai)
              // ... (Header code yahan paste karein) ...

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // ✅ Ab variables use honge, bar bar function call nahi hoga
                      SidebarMenuItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard', isSelected: selectedIndex == 0, onTap: () => onDestinationSelected(0), visible: true, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.insert_drive_file_outlined, selectedIcon: Icons.insert_drive_file, label: 'Inventory', isSelected: selectedIndex == 1, onTap: canSeeInventory ? () => onDestinationSelected(1) : null, badge: badgeFiles, visible: canSeeInventory, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.support_agent_outlined, selectedIcon: Icons.support_agent, label: 'Agent Working', isSelected: selectedIndex == 2, onTap: canSeeAgent ? () => onDestinationSelected(2) : null, visible: canSeeAgent, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.chair_outlined, selectedIcon: Icons.chair, label: 'Rental Items', isSelected: selectedIndex == 3, onTap: canSeeRental ? () => onDestinationSelected(3) : null, badge: badgeRentals, visible: canSeeRental, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist, label: 'To-Do', isSelected: selectedIndex == 4, onTap: canSeeTodo ? () => onDestinationSelected(4) : null, visible: canSeeTodo, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments, label: 'Expenditure', isSelected: selectedIndex == 10, onTap: canSeeExpenditure ? () => onDestinationSelected(10) : null, visible: canSeeExpenditure, showLabel: isOpen),
                      
                      if (onTradingTap != null) ...[
                        SidebarMenuItem(icon: Icons.currency_exchange_outlined, selectedIcon: Icons.currency_exchange, label: 'Trading', isSelected: false, onTap: canSeeTrading ? onTradingTap : null, visible: canSeeTrading, showLabel: isOpen),
                      ],
                      
                      SidebarMenuItem(icon: Icons.event_available, selectedIcon: Icons.event_available, label: 'Follow Up', isSelected: selectedIndex == 7, onTap: canSeeFollowUp ? () => onDestinationSelected(7) : null, visible: canSeeFollowUp, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports', isSelected: selectedIndex == 8, onTap: canSeeReports ? () => onDestinationSelected(8) : null, visible: canSeeReports, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'User Management', isSelected: selectedIndex == 9, onTap: canSeeUsers ? () => onDestinationSelected(9) : null, visible: canSeeUsers, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.business_outlined, selectedIcon: Icons.business, label: 'Company Management', isSelected: selectedIndex == 11, onTap: () => onDestinationSelected(11), visible: isSuperAdmin, showLabel: isOpen),
                      
                      SidebarMenuItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', isSelected: selectedIndex == 5, onTap: () => onDestinationSelected(5), visible: true, showLabel: isOpen),
                    ],
                  ),
                ),
              ),
              Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.2), Colors.transparent]))),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ SidebarMenuItem mein BackdropFilter ko hata kar simple Container use karein (Performance ke liye)
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
    super.key, required this.icon, required this.selectedIcon, required this.label,
    required this.isSelected, required this.onTap, this.isSubItem = false,
    this.badge, this.visible = true, this.showLabel = true,
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
              // ✅ BackdropFilter ki jagah simple color use kiya hai taake GPU load na pare
              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: isSelected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected ? [
                BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.2), blurRadius: 15, spreadRadius: 1),
              ] : [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: showLabel 
              ? Row(
                  children: [
                    if (isSelected) Container(width: 4, height: 40, decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), bottomLeft: Radius.circular(2)))),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Icon(isSelected ? selectedIcon : icon, color: Colors.white, size: 22),
                            const SizedBox(width: 14),
                            Expanded(child: Text(label, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
                            if (badge != null && badge! > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: Icon(isSelected ? selectedIcon : icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}