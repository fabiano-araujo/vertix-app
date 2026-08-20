import 'package:flutter/material.dart';

/// Breakpoints and spacing for the Netflix-style desktop layout.
class Responsive {
  Responsive._();

  static const double desktopBreakpoint = 960;
  static const double topNavHeight = 88;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static double horizontalPadding(BuildContext context) {
    if (!isDesktop(context)) return 16;
    return (MediaQuery.sizeOf(context).width * 0.04).clamp(32, 72);
  }

  /// Poster size so several titles stay visible in a desktop row.
  static Size posterSize(BuildContext context) {
    if (!isDesktop(context)) return const Size(130, 200);

    final width = MediaQuery.sizeOf(context).width;
    final padding = horizontalPadding(context) * 2;
    const visibleCards = 6.4;
    const gap = 8.0;
    final cardWidth = ((width - padding) / visibleCards - gap).clamp(
      140.0,
      220.0,
    );
    return Size(cardWidth, cardWidth * 1.5);
  }

  static EdgeInsets pageInsets(
    BuildContext context, {
    bool overlayNav = false,
  }) {
    final horizontal = horizontalPadding(context);
    final top = isDesktop(context) && !overlayNav ? topNavHeight : 0.0;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, 0);
  }
}
