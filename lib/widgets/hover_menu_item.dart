import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Desktop-only hover menu item with sub-menu support
class HoverMenuItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final List<HoverSubMenuItem> subItems;
  final bool isCollapsed;
  final int? badge;

  const HoverMenuItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    this.onTap,
    required this.subItems,
    required this.isCollapsed,
    this.badge,
  });

  @override
  State<HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<HoverMenuItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _showSubMenu = false;
  Timer? _closeTimer;
  OverlayEntry? _overlayEntry;
  final GlobalKey _itemKey = GlobalKey();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _removeOverlay();
    _animationController.dispose();
    super.dispose();
  }

  bool _isDesktop() {
    // Check if we're on desktop (not mobile/touch)
    if (kIsWeb) {
      // On web, check screen size and assume desktop if > 900px
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        return mediaQuery.size.width >= 900;
      }
      return true; // Default to desktop on web
    }
    // For desktop platforms, check if we have mouse support
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _onHoverEnter() {
    if (!_isDesktop() || widget.subItems.isEmpty) return;
    _closeTimer?.cancel();
    setState(() {
      _isHovered = true;
    });
    _showSubMenuOverlay();
  }

  void _onHoverExit() {
    if (!_isDesktop()) return;
    // Add delay before closing to prevent flickering
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isHovered = false;
        });
        _removeOverlay();
      }
    });
  }

  void _showSubMenuOverlay() {
    if (widget.subItems.isEmpty) return;
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => _SubMenuOverlay(
        itemKey: _itemKey,
        subItems: widget.subItems,
        isCollapsed: widget.isCollapsed,
        fadeAnimation: _fadeAnimation,
        slideAnimation: _slideAnimation,
        onClose: () {
          _onHoverExit();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
  }

  void _removeOverlay() {
    _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onItemTap() {
    // On mobile/touch, use tap to expand
    if (!_isDesktop()) {
      if (widget.subItems.isNotEmpty) {
        setState(() {
          _showSubMenu = !_showSubMenu;
        });
      } else {
        widget.onTap?.call();
      }
    } else {
      // On desktop, if no sub-items, navigate directly
      if (widget.subItems.isEmpty) {
        widget.onTap?.call();
      }
      // If has sub-items, don't navigate on main item click (use hover menu)
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTap: _onItemTap,
        child: Container(
          key: _itemKey,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 0 : 16,
            vertical: 12,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFFF6B35)
                : (_isHovered && _isDesktop())
                    ? Colors.white.withOpacity(0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: widget.isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                color: widget.isSelected
                    ? Colors.white
                    : Colors.grey.shade600,
                size: 20,
              ),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: widget.isSelected
                          ? Colors.white
                          : Colors.grey.shade800,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.subItems.isNotEmpty && !_isDesktop())
                  Icon(
                    _showSubMenu ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: widget.isSelected
                        ? Colors.white
                        : const Color(0xFF4A90E2),
                    child: Text(
                      '${widget.badge}',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isSelected
                            ? const Color(0xFFFF6B35)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sub-menu item for hover menu
class HoverSubMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const HoverSubMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });
}

/// Overlay widget for sub-menu
class _SubMenuOverlay extends StatelessWidget {
  final GlobalKey itemKey;
  final List<HoverSubMenuItem> subItems;
  final bool isCollapsed;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final VoidCallback onClose;

  const _SubMenuOverlay({
    required this.itemKey,
    required this.subItems,
    required this.isCollapsed,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final RenderBox? itemBox =
        itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (itemBox == null) return const SizedBox.shrink();

    final position = itemBox.localToGlobal(Offset.zero);
    final size = itemBox.size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate position for sub-menu
    double left;
    double top;
    if (isCollapsed) {
      // When collapsed, show popover next to icon
      left = position.dx + size.width + 8;
      top = position.dy;
    } else {
      // When expanded, show as indented list or popup
      left = position.dx + size.width - 8;
      top = position.dy;
    }

    return Positioned(
      left: left,
      top: top,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1F24)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < subItems.length; i++)
                    MouseRegion(
                      onEnter: (_) {
                        // Cancel any close timers when hovering sub-menu
                      },
                      child: InkWell(
                        onTap: () {
                          subItems[i].onTap();
                          onClose();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: subItems[i].isSelected
                                ? const Color(0xFFFF6B35).withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.only(
                              topLeft: i == 0
                                  ? const Radius.circular(12)
                                  : Radius.zero,
                              topRight: i == 0
                                  ? const Radius.circular(12)
                                  : Radius.zero,
                              bottomLeft: i == subItems.length - 1
                                  ? const Radius.circular(12)
                                  : Radius.zero,
                              bottomRight: i == subItems.length - 1
                                  ? const Radius.circular(12)
                                  : Radius.zero,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                subItems[i].icon,
                                size: 18,
                                color: subItems[i].isSelected
                                    ? const Color(0xFFFF6B35)
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subItems[i].label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: subItems[i].isSelected
                                        ? const Color(0xFFFF6B35)
                                        : Colors.grey.shade800,
                                    fontWeight: subItems[i].isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

