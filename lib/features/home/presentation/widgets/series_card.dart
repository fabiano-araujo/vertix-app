import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';

/// Series Card Widget
/// Distinctive VERTIX style - NOT a Netflix copy
/// Features: 24px border radius, subtle glow, minimal text
class SeriesCard extends StatelessWidget {
  final int id;
  final String title;
  final String coverUrl;
  final String? genre;
  final VoidCallback? onTap;

  const SeriesCard({
    super.key,
    required this.id,
    required this.title,
    required this.coverUrl,
    this.genre,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      image: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 130, // Larger cards
          margin: const EdgeInsets.symmetric(horizontal: 6), // More spacing
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24), // 24px border radius
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGlow.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppColors.shimmerBase,
                    highlightColor: AppColors.shimmerHighlight,
                    child: Container(color: AppColors.surface),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surface,
                    child: const Icon(
                      Icons.movie_outlined,
                      color: AppColors.textTertiary,
                      size: 32,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(24),
                      splashColor: AppColors.primary.withValues(alpha: 0.2),
                      highlightColor: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
