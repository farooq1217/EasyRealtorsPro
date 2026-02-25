import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';


/// Expansion tile with desktop hover menu support
/// On desktop: shows hover menu
/// On mobile: uses click expansion
class HoverExpansionTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final bool selected;

  const HoverExpansionTile({
    super.key,
    this.leading,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.selected = false,
  });

  @override
  State<HoverExpansionTile> createState() => _HoverExpansionTileState();
}

class _HoverExpansionTileState extends State<HoverExpansionTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isExpanded = false;
  Timer? _closeTimer;
  OverlayEntry? _overlayEntry;
  final GlobalKey _itemKey = GlobalKey();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
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
    if (kIsWeb) {
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        return mediaQuery.size.width >= 900;
      }
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _onHoverEnter() {
    if (!_isDesktop()) return;
    _closeTimer?.cancel();
    setState(() {
      _isHovered = true;
    });
    _showSubMenuOverlay();
  }

  void _onHoverExit() {
    if (!_isDesktop()) return;
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
    if (widget.children.isEmpty) return;
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => _SubMenuOverlay(
        itemKey: _itemKey,
        children: widget.children,
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

  void _onTap() {
    if (_isDesktop()) {
      // On desktop, hover menu handles navigation
      return;
    }
    // On mobile, toggle expansion
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    // On mobile, use regular ExpansionTile
    if (!_isDesktop()) {
      return ExpansionTile(
        leading: widget.leading,
        title: widget.title,
        children: widget.children,
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: widget.onExpansionChanged,
      );
    }

    // On desktop, use hover menu
    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          key: _itemKey,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFFF6B35)
                : _isHovered
                    ? Colors.white.withOpacity(0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (widget.leading != null) widget.leading!,
              const SizedBox(width: 12),
              Expanded(child: widget.title),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay widget for sub-menu
class _SubMenuOverlay extends StatelessWidget {
  final GlobalKey itemKey;
  final List<Widget> children;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final VoidCallback onClose;

  const _SubMenuOverlay({
    required this.itemKey,
    required this.children,
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

    // Calculate position for sub-menu (show to the right)
    final left = position.dx + size.width + 8;
    final top = position.dy;

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
                color: isDark ? const Color(0xFF1B1F24) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
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
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

