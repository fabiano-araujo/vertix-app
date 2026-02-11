import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'series_card.dart';

/// Horizontal carousel for series
/// Used in Home page for different categories
class SeriesCarousel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Ver todos'),
                ),
            ],
          ),
        ),

        // Carousel
        SizedBox(
          height: 200, // Larger cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return SeriesCard(
                id: item['id'],
                title: item['title'],
                coverUrl: item['coverUrl'],
                genre: item['genre'],
                onTap: onItemTap != null
                    ? () => onItemTap!(item['id'])
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
