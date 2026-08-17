import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/series_model.dart';
import '../../../../core/utils/responsive.dart';

/// Featured Banner at the top of Home page
/// Mobile keeps a compact poster hero; desktop uses a Netflix-style billboard.
class FeaturedBanner extends StatelessWidget {
  final SeriesModel? series;
  final VoidCallback? onPlay;
  final VoidCallback? onInfo;

  const FeaturedBanner({super.key, this.series, this.onPlay, this.onInfo});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = Responsive.isDesktop(context);
    final imageUrl = series?.heroImageUrl.isNotEmpty == true
        ? series!.heroImageUrl
        : 'https://picsum.photos/800/1200?random=featured';
    final height = isDesktop
        ? (size.height * 0.88).clamp(520.0, 860.0)
        : size.height * 0.55;
    final padding = Responsive.horizontalPadding(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            alignment: isDesktop ? const Alignment(0.35, 0) : Alignment.center,
            placeholder: (context, url) => Container(color: AppColors.surface),
            errorWidget: (context, url, error) => Container(
              color: AppColors.surface,
              child: const Icon(Icons.error),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withAlpha(isDesktop ? 20 : 80),
                  AppColors.background.withAlpha(isDesktop ? 160 : 200),
                  AppColors.background,
                ],
                stops: isDesktop
                    ? const [0.0, 0.45, 0.78, 1.0]
                    : const [0.0, 0.5, 0.75, 1.0],
              ),
            ),
          ),
          if (isDesktop)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.background.withValues(alpha: 0.88),
                    AppColors.background.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.38, 0.72],
                ),
              ),
            ),
          Positioned(
            left: padding,
            right: isDesktop ? size.width * 0.38 : padding,
            bottom: isDesktop ? 96 : 24,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 640 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDesktop) ...[
                    Text(
                      series?.title ?? 'Destaque Vertix',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 56,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(series?.genre ?? 'Drama'),
                      if (series?.isAiGenerated == true)
                        _buildTag('IA', highlighted: true),
                      _buildTag('${series?.totalEpisodesCount ?? 0} eps'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    series?.description ??
                        'Uma historia envolvente que vai te prender do inicio ao fim. Assista agora!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                      fontSize: isDesktop ? 18 : 14,
                    ),
                    maxLines: isDesktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 22),
                  _buildActions(isDesktop),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDesktop) {
    final playButton = ElevatedButton.icon(
      onPressed: onPlay,
      icon: const Icon(Icons.play_arrow, size: 28),
      label: const Text('Assistir'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 28 : 16,
          vertical: isDesktop ? 16 : 14,
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );

    final infoButton = isDesktop
        ? OutlinedButton.icon(
            onPressed: onInfo ?? onPlay,
            icon: const Icon(Icons.info_outline),
            label: const Text('Mais informações'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : IconButton(
            onPressed: onInfo ?? onPlay,
            icon: const Icon(Icons.info_outline),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.all(12),
            ),
          );

    if (isDesktop) {
      return Row(
        children: [
          playButton,
          const SizedBox(width: 12),
          infoButton,
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
            tooltip: 'Minha lista',
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.textSecondary),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: playButton),
        const SizedBox(width: 12),
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
        infoButton,
      ],
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
