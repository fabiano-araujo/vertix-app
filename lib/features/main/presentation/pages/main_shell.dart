import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/responsive.dart';
import '../widgets/web_top_nav.dart';

/// Main Shell with responsive navigation.
/// Mobile keeps the bottom bar; desktop uses a Netflix-style top nav.
class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _isScrolled = false;

  bool get _showAdminTab => AuthService().currentUser?.isAdmin == true;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/for-you')) return 1;
    if (location.startsWith('/my-vertix')) return 2;
    if (_showAdminTab && location.startsWith('/admin-production')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/for-you');
        break;
      case 2:
        context.go('/my-vertix');
        break;
      case 3:
        context.go('/admin-production');
        break;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrolled = notification.metrics.pixels > 40;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
    return false;
  }

  bool _isStudioEditor(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    return RegExp(r'^/admin-production/[^/]+/?$').hasMatch(path);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDesktop = Responsive.isDesktop(context);
    final location = GoRouterState.of(context).uri.path;
    final overlayHero = location == '/';
    final hideChrome = _isStudioEditor(location);
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.play_circle_outline),
        selectedIcon: Icon(Icons.play_circle),
        label: 'Para Voce',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Minha Vertix',
      ),
      if (_showAdminTab)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Producoes',
        ),
    ];

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.child,
            if (isDesktop && !hideChrome)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: WebTopNav(
                  selectedIndex: selectedIndex,
                  onItemTapped: (index) => _onItemTapped(context, index),
                  showAdminTab: _showAdminTab,
                  isScrolled: _isScrolled || !overlayHero,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop || hideChrome
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.surfaceLighter, width: 0.5),
                ),
              ),
              child: SafeArea(
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      _onItemTapped(context, index),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  height: 65,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: destinations,
                ),
              ),
            ),
    );
  }
}
