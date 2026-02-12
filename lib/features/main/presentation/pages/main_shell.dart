import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Main Shell with Bottom Navigation
/// Contains the 4 main tabs: Home, Para Voce, Minha Vertix, Buscar
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/for-you')) return 1;
    if (location.startsWith('/my-vertix')) return 2;
    return 0; // Home
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.surfaceLighter,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onItemTapped(context, index),
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 65,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.play_circle_outline),
                selectedIcon: Icon(Icons.play_circle),
                label: 'Para Voce',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Minha Vertix',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
