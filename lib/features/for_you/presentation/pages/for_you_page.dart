import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/feed_service.dart';
import '../../../../core/services/episode_service.dart';
import '../../../../core/models/episode_model.dart';
import '../../../player/presentation/widgets/comments_sheet.dart';
import '../../../player/presentation/widgets/vertical_video_view.dart';

/// For You Page - TikTok-style vertical video feed
/// Full-screen vertical swipe navigation with autoplay
class ForYouPage extends StatefulWidget {
  const ForYouPage({super.key});

  @override
  State<ForYouPage> createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  late PageController _pageController;
  final FeedService _feedService = FeedService();
  final EpisodeService _episodeService = EpisodeService();

  int _currentIndex = 0;
  bool _isLoading = true;
  List<EpisodeModel> _episodes = [];
  Map<int, VideoPlayerController> _controllers = {};
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);

    final response = await _feedService.getForYouFeed(limit: 20);

    if (response.success) {
      setState(() {
        _episodes = response.data.where((item) => !item.isLocked).toList();
        _isLoading = false;
      });

      if (_episodes.isNotEmpty) {
        _preloadVideos(0);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _preloadVideos(int currentIndex) {
    // Preload current and next 2 videos
    for (int i = currentIndex; i <= currentIndex + 2 && i < _episodes.length; i++) {
      if (!_controllers.containsKey(i)) {
        if (_episodes[i].isLocked || _episodes[i].videoUrl.isEmpty) continue;
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(_episodes[i].videoUrl),
        );
        _controllers[i] = controller;
        controller.initialize().then((_) {
          if (!mounted) return;
          controller.setLooping(false);
          controller.addListener(() => _onVideoTick(i));
          if (i == currentIndex && mounted) {
            controller.play();
          }
          setState(() {});
        });
      }
    }

    // Dispose old controllers to save memory
    _controllers.removeWhere((key, controller) {
      if (key < currentIndex - 1 || key > currentIndex + 2) {
        controller.dispose();
        return true;
      }
      return false;
    });
  }

  void _onVideoTick(int index) {
    if (!mounted || index != _currentIndex || _advancing) return;
    final controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) return;
    final ended =
        !controller.value.isPlaying &&
        controller.value.duration > Duration.zero &&
        controller.value.position >=
            controller.value.duration - const Duration(milliseconds: 400);
    if (!ended) return;
    if (index < _episodes.length - 1) {
      _advancing = true;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  void _onPageChanged(int index) {
    // Pause previous video
    _controllers[_currentIndex]?.pause();

    setState(() {
      _currentIndex = index;
      _advancing = false;
    });

    // Play current video
    _controllers[index]?.play();

    // Preload more videos
    _preloadVideos(index);

    // Record view
    if (index < _episodes.length) {
      _episodeService.recordView(_episodes[index].id);
    }

    // Load more when near end
    if (index >= _episodes.length - 3) {
      _loadMoreEpisodes();
    }
  }

  Future<void> _loadMoreEpisodes() async {
    final response = await _feedService.getForYouFeed(
      limit: 10,
      offset: _episodes.length,
    );

    if (response.success && response.data.isNotEmpty) {
      setState(() {
        _episodes.addAll(response.data);
      });
    }
  }

  Future<void> _toggleLike(int index) async {
    final episode = _episodes[index];
    final response = await _episodeService.toggleLike(episode.id);

    if (response.success) {
      var likes = episode.likesCount;
      if (response.isLiked && !episode.isLiked) likes += 1;
      if (!response.isLiked && episode.isLiked) {
        likes = (likes - 1).clamp(0, 1 << 30);
      }
      if (response.likesCount > 0) likes = response.likesCount;
      setState(() {
        _episodes[index] = episode.copyWith(
          isLiked: response.isLiked,
          likesCount: likes,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: !isDesktop,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Para Voce',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push('/search'),
                ),
              ],
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _episodes.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: EdgeInsets.only(
                    top: isDesktop ? Responsive.topNavHeight : 0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 460 : double.infinity,
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        onPageChanged: _onPageChanged,
                        itemCount: _episodes.length,
                        itemBuilder: (context, index) {
                          return _buildVideoItem(_episodes[index], index);
                        },
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum video disponivel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadFeed,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(EpisodeModel episode, int index) {
    final controller = _controllers[index];
    final isActive = index == _currentIndex;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player or Thumbnail
        if (controller != null && controller.value.isInitialized)
          GestureDetector(
            onTap: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            },
            child: VerticalVideoView(controller: controller),
          )
        else
          Container(
            color: AppColors.surface,
            child: episode.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: episode.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    errorWidget: (_, __, ___) => _buildPlaceholder(episode),
                  )
                : _buildPlaceholder(episode),
          ),

        // Gradient Overlay
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.videoOverlayGradient,
          ),
        ),

        // Play/Pause indicator
        if (controller != null && !controller.value.isPlaying && isActive)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),

        // Bottom Info
        Positioned(
          left: 16,
          right: 80,
          bottom: Responsive.isDesktop(context) ? 24 : 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Series title
              if (episode.series != null)
                GestureDetector(
                  onTap: () => context.push('/series/${episode.seriesId}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      episode.series!.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Episode title
              Text(
                'Ep ${episode.episodeNumber} - ${episode.title}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              if (episode.description != null)
                Text(
                  episode.description!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 16),

            ],
          ),
        ),

        // Right Action Buttons
        Positioned(
          right: 12,
          bottom: Responsive.isDesktop(context) ? 48 : 120,
          child: Column(
            children: [
              // Like
              _buildActionButton(
                icon: episode.isLiked ? Icons.favorite : Icons.favorite_border,
                label: episode.formattedLikes,
                color: episode.isLiked ? AppColors.likeActive : AppColors.textPrimary,
                onTap: () => _toggleLike(index),
              ),
              const SizedBox(height: 20),

              // Comment
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: episode.formattedComments,
                onTap: () => _showCommentsSheet(episode.id),
              ),
              const SizedBox(height: 20),

              // Share
              _buildActionButton(
                icon: Icons.share_outlined,
                label: episode.formattedShares,
                onTap: () => _episodeService.recordShare(episode.id),
              ),
              const SizedBox(height: 20),

              // More
              _buildActionButton(
                icon: Icons.play_circle_outline,
                label: 'Serie',
                onTap: () => context.push('/player/${episode.id}'),
              ),
            ],
          ),
        ),

        // Progress indicator at bottom
        if (controller != null && controller.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceLighter,
                bufferedColor: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(EpisodeModel episode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 80,
            color: AppColors.textSecondary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'Ep ${episode.episodeNumber}',
            style: TextStyle(
              color: AppColors.textSecondary.withAlpha(128),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(150),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color ?? AppColors.textPrimary,
              size: 26,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCommentsSheet(int episodeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(episodeId: episodeId),
    );
  }
}
