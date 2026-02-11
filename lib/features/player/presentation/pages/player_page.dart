import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/episode_service.dart';
import '../../../../core/models/episode_model.dart';
import '../widgets/comments_sheet.dart';

/// Video Player Page
class PlayerPage extends StatefulWidget {
  final int episodeId;

  const PlayerPage({super.key, required this.episodeId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _episodeService = EpisodeService();

  VideoPlayerController? _controller;
  EpisodeModel? _episode;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEpisode();
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadEpisode() async {
    final response = await _episodeService.getEpisode(widget.episodeId);

    if (response.success && response.data != null) {
      setState(() {
        _episode = response.data;
      });
      _initializeVideo();
      // Record view
      _episodeService.recordView(widget.episodeId);
    } else {
      setState(() {
        _error = response.message ?? 'Erro ao carregar episodio';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeVideo() async {
    if (_episode == null) return;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(_episode!.videoUrl),
    );

    try {
      await _controller!.initialize();
      _controller!.addListener(_videoListener);
      setState(() {
        _isLoading = false;
      });
      _controller!.play();
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar video';
        _isLoading = false;
      });
    }
  }

  void _videoListener() {
    if (!mounted) return;
    final isPlaying = _controller?.value.isPlaying ?? false;
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }

    // Update progress
    if (_controller != null && _controller!.value.isInitialized) {
      final position = _controller!.value.position.inSeconds;
      final duration = _controller!.value.duration.inSeconds;
      if (duration > 0) {
        final progress = position / duration;
        // Save progress every 10 seconds
        if (position % 10 == 0 && position > 0) {
          _episodeService.updateProgress(widget.episodeId, progress);
        }
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seek(Duration position) {
    _controller?.seekTo(position);
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(episodeId: widget.episodeId),
    );
  }

  Future<void> _toggleLike() async {
    if (_episode == null) return;

    final response = await _episodeService.toggleLike(widget.episodeId);
    if (response.success) {
      setState(() {
        _episode = _episode!.copyWith(
          isLiked: response.isLiked,
          likesCount: response.likesCount,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildPlayer(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

          // Controls overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black54,
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
              child: _buildControls(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Spacer(),
                if (_episode != null)
                  Text(
                    'Ep ${_episode!.episodeNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings, color: Colors.white),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Center play/pause
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _seek(
                    (_controller?.value.position ?? Duration.zero) -
                        const Duration(seconds: 10),
                  ),
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 32),
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(width: 32),
                IconButton(
                  onPressed: () => _seek(
                    (_controller?.value.position ?? Duration.zero) +
                        const Duration(seconds: 10),
                  ),
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom info and actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                if (_controller != null && _controller!.value.isInitialized)
                  _buildProgressBar(),
                const SizedBox(height: 16),

                // Episode info
                if (_episode != null) ...[
                  Text(
                    _episode!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_episode!.series != null)
                    Text(
                      _episode!.series!.title,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        icon: _episode!.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: _episode!.formattedLikes,
                        color: _episode!.isLiked ? AppColors.primary : Colors.white,
                        onTap: _toggleLike,
                      ),
                      _buildActionButton(
                        icon: Icons.comment,
                        label: _episode!.formattedComments,
                        onTap: _showComments,
                      ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Compartilhar',
                        onTap: () {
                          _episodeService.recordShare(widget.episodeId);
                          // TODO: Implement share
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.playlist_play,
                        label: 'Serie',
                        onTap: () {
                          if (_episode?.seriesId != null) {
                            context.push('/series/${_episode!.seriesId}');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white24,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: position.inMilliseconds.toDouble(),
            min: 0,
            max: duration.inMilliseconds.toDouble(),
            onChanged: (value) {
              _seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString();
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
