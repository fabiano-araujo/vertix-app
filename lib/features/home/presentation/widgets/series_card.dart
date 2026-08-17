import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';

/// Series Card Widget
/// Portrait poster used in home rows. Desktop adds hover scale like Netflix.
class SeriesCard extends StatefulWidget {
  final int id;
  final String title;
  final String coverUrl;
  final String? genre;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const SeriesCard({
    super.key,
    required this.id,
    required this.title,
    required this.coverUrl,
    this.genre,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  State<SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<SeriesCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final width = widget.width ?? 130;
    final radius = width > 150 ? 8.0 : 24.0;

    return Semantics(
      label: widget.title,
      button: true,
      image: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovering ? 1.08 : 1,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: width,
              height: widget.height,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGlow.withValues(
                      alpha: _hovering ? 0.45 : 0.3,
                    ),
                    blurRadius: _hovering ? 28 : 20,
                    spreadRadius: -5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.coverUrl,
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
                    if (_hovering)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onTap,
                          borderRadius: BorderRadius.circular(radius),
                          splashColor: AppColors.primary.withValues(alpha: 0.2),
                          highlightColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
