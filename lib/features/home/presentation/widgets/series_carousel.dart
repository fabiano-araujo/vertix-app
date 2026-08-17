import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import 'series_card.dart';

/// Horizontal carousel for series
/// Used in Home page for different categories
class SeriesCarousel extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;
  final Function(int id)? onItemTap;

  const SeriesCarousel({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    required this.items,
    this.onSeeAll,
    this.onItemTap,
  });

  @override
  State<SeriesCarousel> createState() => _SeriesCarouselState();
}

class _SeriesCarouselState extends State<SeriesCarousel> {
  final ScrollController _controller = ScrollController();
  bool _hovering = false;
  bool _canScrollBack = false;
  bool _canScrollForward = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateArrows);
    _controller.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canBack = position.pixels > 8;
    final canForward = position.pixels < position.maxScrollExtent - 8;
    if (canBack != _canScrollBack || canForward != _canScrollForward) {
      setState(() {
        _canScrollBack = canBack;
        _canScrollForward = canForward;
      });
    }
  }

  void _scrollBy(double direction) {
    if (!_controller.hasClients) return;
    final offset = MediaQuery.sizeOf(context).width * 0.75 * direction;
    _controller.animateTo(
      (_controller.offset + offset).clamp(
        0,
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.horizontalPadding(context);
    final poster = Responsive.posterSize(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, isDesktop ? 18 : 24, padding, 12),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 20,
                    color: widget.iconColor ?? AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? 20 : 16,
                    ),
                  ),
                ),
                if (widget.onSeeAll != null)
                  TextButton(
                    onPressed: widget.onSeeAll,
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: poster.height + (isDesktop ? 28 : 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.builder(
                  controller: _controller,
                  clipBehavior: Clip.none,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: padding - 6),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return SeriesCard(
                      id: item['id'],
                      title: item['title'],
                      coverUrl: item['coverUrl'],
                      genre: item['genre'],
                      width: poster.width,
                      height: poster.height,
                      onTap: widget.onItemTap != null
                          ? () => widget.onItemTap!(item['id'])
                          : null,
                    );
                  },
                ),
                if (isDesktop && _hovering && _canScrollBack)
                  _CarouselArrow(
                    alignment: Alignment.centerLeft,
                    icon: Icons.chevron_left,
                    onTap: () => _scrollBy(-1),
                  ),
                if (isDesktop && _hovering && _canScrollForward)
                  _CarouselArrow(
                    alignment: Alignment.centerRight,
                    icon: Icons.chevron_right,
                    onTap: () => _scrollBy(1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrow({
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: double.infinity,
          color: Colors.black.withValues(alpha: 0.45),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}
