import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class WebNavDestination {
  const WebNavDestination({required this.label, required this.index});

  final String label;
  final int index;
}

/// Netflix-style top navigation used on large web/desktop screens.
class WebTopNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final bool showAdminTab;
  final bool isScrolled;

  const WebTopNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.showAdminTab,
    this.isScrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 1200;
    final isWide = width >= 1600;
    final itemGap = isWide ? 28.0 : (isCompact ? 14.0 : 22.0);
    final labelFontSize = isWide ? 21.0 : (isCompact ? 16.0 : 18.0);
    final activeHorizontalPadding = isWide ? 22.0 : (isCompact ? 14.0 : 18.0);
    final activeVerticalPadding = isWide ? 13.0 : 10.0;
    final destinations = [
      const WebNavDestination(label: 'Início', index: 0),
      const WebNavDestination(label: 'Para Você', index: 1),
      const WebNavDestination(label: 'Minha Vertix', index: 2),
      if (showAdminTab) const WebNavDestination(label: 'Produções', index: 3),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: Responsive.topNavHeight,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      decoration: BoxDecoration(
        color: isScrolled ? AppColors.background.withValues(alpha: 0.96) : null,
        gradient: isScrolled
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.82),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onItemTapped(0),
            child: Text(
              'VERTIX',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: isWide ? 29 : (isCompact ? 23 : 26),
                letterSpacing: isWide ? 2.4 : 2,
              ),
            ),
          ),
          SizedBox(width: isWide ? 36 : (isCompact ? 18 : 28)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final destination in destinations) ...[
                    _NavLink(
                      label: destination.label,
                      selected: selectedIndex == destination.index,
                      onTap: () => onItemTapped(destination.index),
                      fontSize: labelFontSize,
                      horizontalPadding: activeHorizontalPadding,
                      verticalPadding: activeVerticalPadding,
                    ),
                    SizedBox(width: itemGap),
                  ],
                  _NavLink(
                    label: 'Categorias',
                    selected: GoRouterState.of(
                      context,
                    ).uri.path.startsWith('/browse'),
                    onTap: () => context.go('/browse'),
                    fontSize: labelFontSize,
                    horizontalPadding: activeHorizontalPadding,
                    verticalPadding: activeVerticalPadding,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: isWide ? 20 : 8),
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/search'),
            icon: Icon(Icons.search, size: isWide ? 25 : 22),
          ),
          IconButton(
            tooltip: 'Notificações',
            onPressed: () {},
            icon: Icon(Icons.notifications_outlined, size: isWide ? 25 : 22),
          ),
          SizedBox(width: isWide ? 12 : 4),
          InkWell(
            onTap: () => onItemTapped(2),
            borderRadius: BorderRadius.circular(isWide ? 8 : 6),
            child: Container(
              width: isWide ? 38 : 32,
              height: isWide ? 38 : 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(isWide ? 8 : 6),
              ),
              child: Text(
                user?.initials ?? 'V',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  const _NavLink({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.fontSize,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected || _hovering
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: widget.selected ? widget.horizontalPadding : 0,
          vertical: widget.selected ? widget.verticalPadding : 0,
        ),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.surfaceLighter.withValues(alpha: 0.92)
              : (_hovering
                    ? AppColors.surfaceLight.withValues(alpha: 0.55)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(999),
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style: TextStyle(
              color: color,
              fontSize: widget.fontSize,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
