import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class WebNavDestination {
  const WebNavDestination({
    required this.label,
    required this.index,
  });

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
    final destinations = [
      const WebNavDestination(label: 'Início', index: 0),
      const WebNavDestination(label: 'Para Você', index: 1),
      const WebNavDestination(label: 'Minha Vertix', index: 2),
      if (showAdminTab)
        const WebNavDestination(label: 'Produções', index: 3),
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
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 28),
          for (final destination in destinations) ...[
            _NavLink(
              label: destination.label,
              selected: selectedIndex == destination.index,
              onTap: () => onItemTapped(destination.index),
            ),
            const SizedBox(width: 18),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search, size: 22),
          ),
          IconButton(
            tooltip: 'Notificações',
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, size: 22),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => onItemTapped(2),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
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

  const _NavLink({
    required this.label,
    required this.selected,
    required this.onTap,
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
