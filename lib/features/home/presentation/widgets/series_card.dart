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
    return GestureDetector(
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
              // Cover Image
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

              // Gradient Overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.cardGradient,
                ),
              ),

              // Minimal text - only title at bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 12,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Hover/Focus effect - subtle border
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
    );
  }
}
