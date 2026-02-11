import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/series_model.dart';

/// Featured Banner at the top of Home page
/// Shows a featured series with large cover
class FeaturedBanner extends StatelessWidget {
  final SeriesModel? series;
  final VoidCallback? onPlay;
  final VoidCallback? onInfo;

  const FeaturedBanner({
    super.key,
    this.series,
    this.onPlay,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.55,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          CachedNetworkImage(
            imageUrl: series?.coverUrl ?? 'https://picsum.photos/800/1200?random=featured',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.surface,
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.surface,
              child: const Icon(Icons.error),
            ),
          ),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withAlpha(80),
                  AppColors.background.withAlpha(200),
                  AppColors.background,
                ],
                stops: const [0.0, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // Content
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Genre Tags
                Row(
                  children: [
                    _buildTag(series?.genre ?? 'Drama'),
                    if (series?.isAiGenerated == true) ...[
                      const SizedBox(width: 8),
                      _buildTag('IA', highlighted: true),
                    ],
                    const SizedBox(width: 8),
                    _buildTag('${series?.totalEpisodesCount ?? 0} eps'),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  series?.title ?? 'Serie em Destaque',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  series?.description ?? 'Uma historia envolvente que vai te prender do inicio ao fim. Assista agora!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    // Play Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Assistir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Add to List Button
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Info Button
                    IconButton(
                      onPressed: onInfo ?? onPlay,
                      icon: const Icon(Icons.info_outline),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withAlpha(80)
            : AppColors.surfaceLight.withAlpha(200),
        borderRadius: BorderRadius.circular(4),
        border: highlighted
            ? Border.all(color: AppColors.primary.withAlpha(150))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlighted ? AppColors.primary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
