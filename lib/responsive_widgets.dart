import 'dart:ui';

import 'package:flutter/material.dart';
import 'offline_sync_service.dart';

/// Responsive sidebar with hamburger menu for mobile
class ResponsiveSidebar extends StatefulWidget {
  final Widget child;
  final List<Widget> menuItems;
  final String title;
  final bool isCollapsed;
  final VoidCallback? onToggle;
  final PreferredSizeWidget? appBar;

  const ResponsiveSidebar({
    super.key,
    required this.child,
    required this.menuItems,
    required this.title,
    this.isCollapsed = false,
    this.onToggle,
    this.appBar,
  });

  @override
  State<ResponsiveSidebar> createState() => _ResponsiveSidebarState();
}

class _ResponsiveSidebarState extends State<ResponsiveSidebar> {
  int? _hoveredIndex;

  static const _glassBase = Color(0xFF0F141B);
  static const _glassTint = Color(0xFF12161C);
  static const _accentOrange = Color(0xFFFF6B35);
  static const _accentBlue = Color(0xFF4A90E2);

  String? _extractLabel(Widget? title) {
    if (title == null) return null;
    if (title is Text) return title.data;
    if (title is DefaultTextStyle) return _extractLabel(title.child);
    if (title is Icon) return null;
    if (title is Row) {
      for (final child in title.children) {
        final label = _extractLabel(child);
        if (label != null && label.trim().isNotEmpty) return label;
      }
    }
    if (title is Column) {
      for (final child in title.children) {
        final label = _extractLabel(child);
        if (label != null && label.trim().isNotEmpty) return label;
      }
    }
    return null;
  }

  IconData _extractLeadingIcon(Widget? leading, {IconData fallback = Icons.circle_outlined}) {
    if (leading == null) return fallback;
    if (leading is Icon && leading.icon != null) return leading.icon!;
    return fallback;
  }

  Widget _buildModernNavItem({
    required BuildContext context,
    required int index,
    required bool collapsed,
    required IconData icon,
    required Widget? title,
    required String tooltip,
    required bool selected,
    required VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
  }) {
    final hovered = _hoveredIndex == index;

    final activeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFFF6B35).withOpacity(0.26),
        const Color(0xFF4A90E2).withOpacity(0.20),
      ],
    );

    final hoverGlow = BoxShadow(
      color: const Color(0xFF4A90E2).withOpacity(0.20),
      blurRadius: 18,
      offset: const Offset(0, 10),
    );

    final baseRadius = BorderRadius.circular(12);

    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 6),
      padding: padding ?? EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: baseRadius,
        gradient: selected ? activeGradient : null,
        color: selected
            ? null
            : hovered
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(selected ? 0.14 : 0.08)),
        boxShadow: [if (hovered) hoverGlow],
      ),
      child: Row(
        mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (selected)
            Flexible(
              child: Container(
                width: 3,
                height: 22,
                margin: EdgeInsets.only(right: collapsed ? 0 : 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFF6B35),
                      Color(0xFF4A90E2),
                    ],
                  ),
                ),
              ),
            )
          else if (!collapsed)
            const SizedBox(width: 3 + 10),
          Flexible(
            child: Icon(
              icon,
              size: 22,
              color: selected
                  ? Colors.white
                  : hovered
                      ? Colors.white
                      : Colors.white.withOpacity(0.80),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withOpacity(0.90),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: title is Text
                    ? Text(
                        title.data ?? tooltip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: title ?? Text(
                          tooltip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );

    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: baseRadius,
        onTap: onTap,
        child: item,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: collapsed ? Tooltip(message: tooltip, child: tappable) : tappable,
    );
  }

  Widget _buildMenuEntry(BuildContext context, Widget item, int index, bool collapsed) {
    if (item is Divider) return item;

    if (item is ListTile) {
      final tooltip = _extractLabel(item.title) ?? '';
      final icon = _extractLeadingIcon(item.leading, fallback: Icons.circle_outlined);
      return _buildModernNavItem(
        context: context,
        index: index,
        collapsed: collapsed,
        icon: icon,
        title: item.title,
        tooltip: tooltip,
        selected: item.selected ?? false,
        onTap: item.onTap,
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: collapsed ? 12 : 10),
      );
    }

    if (item is ExpansionTile) {
      final tooltip = _extractLabel(item.title) ?? '';
      final icon = _extractLeadingIcon(item.leading, fallback: Icons.folder_open_outlined);
      final childrenTiles = item.children.whereType<ListTile>().toList();
      final anySelected = childrenTiles.any((t) => (t.selected ?? false) == true);

      if (collapsed) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: Tooltip(
            message: tooltip,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: PopupMenuButton<int>(
                tooltip: tooltip,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) {
                  return [
                    for (var i = 0; i < childrenTiles.length; i++)
                      PopupMenuItem<int>(
                        value: i,
                        child: Text(_extractLabel(childrenTiles[i].title) ?? ''),
                      ),
                  ];
                },
                onSelected: (i) {
                  if (i >= 0 && i < childrenTiles.length) {
                    childrenTiles[i].onTap?.call();
                  }
                },
                child: _buildModernNavItem(
                  context: context,
                  index: index,
                  collapsed: true,
                  icon: icon,
                  title: null,
                  tooltip: tooltip,
                  selected: anySelected,
                  onTap: null,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.02),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              icon,
              color: anySelected ? Colors.white : Colors.white.withOpacity(0.80),
            ),
            title: DefaultTextStyle.merge(
              style: TextStyle(
                color: anySelected ? Colors.white : Colors.white.withOpacity(0.90),
                fontWeight: anySelected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: item.title,
            ),
            initiallyExpanded: item.initiallyExpanded,
            onExpansionChanged: item.onExpansionChanged,
            iconColor: Colors.white.withOpacity(0.85),
            collapsedIconColor: Colors.white.withOpacity(0.70),
            children: [
              for (final child in childrenTiles)
                _buildModernNavItem(
                  context: context,
                  index: index * 1000 + childrenTiles.indexOf(child) + 1,
                  collapsed: false,
                  icon: _extractLeadingIcon(child.leading, fallback: Icons.circle_outlined),
                  title: child.title,
                  tooltip: _extractLabel(child.title) ?? '',
                  selected: child.selected ?? false,
                  onTap: child.onTap,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
            ],
          ),
        ),
      );
    }

    return item;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final isTablet = constraints.maxWidth >= 900 && constraints.maxWidth < 1200;

    final effectiveCollapsed = widget.isCollapsed;

    if (isMobile) {
      // Mobile: Use drawer
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            // Offline indicator
            StreamBuilder<bool>(
              stream: OfflineSyncService().connectivityStream,
              initialData: OfflineSyncService().isOnline,
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? true;
                final pendingCount = OfflineSyncService().pendingActionsCount;
                return Row(
                  children: [
                    if (!isOnline || pendingCount > 0)
                      IconButton(
                        icon: Stack(
                          children: [
                            Icon(
                              isOnline ? Icons.cloud_sync : Icons.cloud_off,
                              color: isOnline ? Colors.orange : Colors.red,
                            ),
                            if (pendingCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: Text(
                                    pendingCount > 9 ? '9+' : '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        tooltip: isOnline
                            ? 'Syncing $pendingCount pending actions'
                            : 'Offline - $pendingCount pending actions',
                        onPressed: () {
                          if (isOnline && pendingCount > 0) {
                            OfflineSyncService().syncNow();
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _glassTint.withOpacity(0.86),
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.10))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(8, 0),
                    ),
                  ],
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
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
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).maybePop(),
                                icon: Icon(Icons.close, color: Colors.white.withOpacity(0.95)),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<bool>(
                            stream: OfflineSyncService().connectivityStream,
                            initialData: OfflineSyncService().isOnline,
                            builder: (context, snapshot) {
                              final isOnline = snapshot.data ?? true;
                              return Row(
                                children: [
                                  Icon(
                                    isOnline ? Icons.wifi : Icons.wifi_off,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isOnline ? 'Online' : 'Offline',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < widget.menuItems.length; i++)
                      _buildMenuEntry(context, widget.menuItems[i], i, false),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: widget.child,
      );
    }

    final collapsedWidth = 76.0;
    final expandedWidth = isTablet ? 260.0 : 292.0;

    final glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _glassBase.withOpacity(0.80),
        _glassTint.withOpacity(0.70),
      ],
    );

    final sidebar = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      width: effectiveCollapsed ? collapsedWidth : expandedWidth,
      constraints: BoxConstraints(
        minWidth: effectiveCollapsed ? collapsedWidth : expandedWidth,
        maxWidth: effectiveCollapsed ? collapsedWidth : expandedWidth,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: glassGradient,
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 30,
                  offset: const Offset(10, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 64,
                    padding: EdgeInsets.symmetric(horizontal: effectiveCollapsed ? 6 : 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _accentOrange.withOpacity(0.90),
                          _accentBlue.withOpacity(0.90),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Tooltip(
                          message: effectiveCollapsed ? 'Expand' : 'Collapse',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: IconButton(
                              icon: AnimatedRotation(
                                turns: effectiveCollapsed ? 0.0 : 0.5,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOutCubic,
                                child: const Icon(Icons.menu, color: Colors.white),
                              ),
                              onPressed: widget.onToggle,
                            ),
                          ),
                        ),
                        if (!effectiveCollapsed) ...[
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                widget.title,
                                key: ValueKey<String>(widget.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<bool>(
                              stream: OfflineSyncService().connectivityStream,
                              initialData: OfflineSyncService().isOnline,
                              builder: (context, snapshot) {
                                final isOnline = snapshot.data ?? true;
                                final pendingCount = OfflineSyncService().pendingActionsCount;
                                return Tooltip(
                                  message: isOnline
                                      ? 'Syncing $pendingCount pending actions'
                                      : 'Offline - $pendingCount pending actions',
                                  child: Stack(
                                    children: [
                                      Icon(
                                        isOnline ? Icons.cloud_sync : Icons.cloud_off,
                                        color: Colors.white.withOpacity(0.85),
                                        size: 20,
                                      ),
                                      if (pendingCount > 0)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 10,
                                              minHeight: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        for (var i = 0; i < widget.menuItems.length; i++)
                          _buildMenuEntry(context, widget.menuItems[i], i, effectiveCollapsed),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final body = Row(
      children: [
        sidebar,
        Expanded(child: widget.child),
      ],
    );

        if (widget.appBar != null) {
          return Scaffold(appBar: widget.appBar, body: body);
        }

        return body;
      },
    );
  }
}

/// Responsive form layout that stacks on mobile
class ResponsiveFormLayout extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final double spacing;

  const ResponsiveFormLayout({
    super.key,
    required this.children,
    this.desktopColumns = 3,
    this.tabletColumns = 2,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final isTablet = constraints.maxWidth >= 900 && constraints.maxWidth < 1200;
        
        final columns = isMobile ? 1 : (isTablet ? tabletColumns : desktopColumns);
        
        if (columns == 1) {
          // Stack vertically on mobile
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children.map((child) => Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: child,
            )).toList(),
          );
        } else {
          // Use Wrap for multi-column layout
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children,
          );
        }
      },
    );
  }
}

/// Connectivity indicator widget
class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineSyncService().connectivityStream,
      initialData: OfflineSyncService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        final pendingCount = OfflineSyncService().pendingActionsCount;
        
        if (isOnline && pendingCount == 0) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOnline ? Colors.orange.shade50 : Colors.red.shade50,
            border: Border(
              bottom: BorderSide(
                color: isOnline ? Colors.orange.shade200 : Colors.red.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_sync : Icons.cloud_off,
                color: isOnline ? Colors.orange : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Syncing $pendingCount pending action${pendingCount != 1 ? 's' : ''}...'
                      : 'Offline mode - $pendingCount action${pendingCount != 1 ? 's' : ''} pending sync',
                  style: TextStyle(
                    color: isOnline ? Colors.orange.shade900 : Colors.red.shade900,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isOnline && pendingCount > 0)
                TextButton(
                  onPressed: () => OfflineSyncService().syncNow(),
                  child: const Text('Sync Now'),
                ),
            ],
          ),
        );
      },
    );
  }
}

