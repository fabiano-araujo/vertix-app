import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/episode_service.dart';
import '../../../../core/services/watchlist_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/credits_service.dart';
import '../../../../core/models/episode_model.dart';
import '../../../../core/models/series_model.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/vertical_video_view.dart';
import '../widgets/player_paywall_overlay.dart';

/// Vertical binge player — DramaBox/TikTok style for a series.
class PlayerPage extends StatefulWidget {
  final int episodeId;

  const PlayerPage({super.key, required this.episodeId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _episodeService = EpisodeService();
  final _watchlist = WatchlistService();
  final _auth = AuthService();
  final _credits = CreditsService();

  PageController? _pageController;
  List<EpisodeModel> _episodes = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, DateTime> _lastProgressSave = {};
  final Set<String> _retentionSent = {};

  int _currentIndex = 0;
  int _creditsBalance = 0;
  int? _pendingUnlockIndex;
  bool _isLoading = true;
  bool _showPlayHint = false;
  bool _inWatchlist = false;
  bool _paywallVisible = false;
  bool _unlocking = false;
  bool _nextTapReady = false;
  String? _error;
  String? _paywallMessage;
  bool _advancing = false;

  EpisodeModel? get _current =>
      _episodes.isEmpty ? null : _episodes[_currentIndex];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_onVideoTick);
      controller.dispose();
    }
    _pageController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _load() async {
    final response = await _episodeService.getEpisode(widget.episodeId);
    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() {
        _error = response.message ?? 'Erro ao carregar episodio';
        _isLoading = false;
      });
      return;
    }

    final current = response.data!;
    var playlist = <EpisodeModel>[current];
    final siblings = await _episodeService.getEpisodesBySeries(
      current.seriesId,
      limit: 80,
    );
    if (siblings.success && siblings.data.isNotEmpty) {
      playlist = siblings.data;
    }

    var index = playlist.indexWhere((item) => item.id == current.id);
    if (index < 0) {
      playlist.insert(0, current);
      index = 0;
    } else {
      playlist[index] = current.copyWith(
        isLiked: current.isLiked,
        watchProgress: current.watchProgress,
        series: current.series ?? playlist[index].series,
      );
    }

    await _watchlist.ensureLoaded();
    _pageController = PageController(initialPage: index);
    setState(() {
      _episodes = playlist;
      _currentIndex = index;
      _inWatchlist = _watchlist.contains(current.seriesId);
      _isLoading = false;
    });

    _refreshCredits();
    if (playlist[index].isLocked) {
      _showPaywallFor(index);
    } else {
      _preload(index);
      _episodeService.recordView(current.id);
      _trackRetention(playlist[index], 'start');
    }
  }

  void _preload(int index) {
    for (var i = index - 1; i <= index + 2; i++) {
      if (i < 0 || i >= _episodes.length || _controllers.containsKey(i)) {
        continue;
      }
      if (_episodes[i].isLocked || _episodes[i].videoUrl.isEmpty) {
        continue;
      }
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_episodes[i].videoUrl),
      );
      _controllers[i] = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(false);
        controller.addListener(_onVideoTick);
        if (i == _currentIndex) {
          _resumeIfNeeded(i);
          controller.play();
        }
        setState(() {});
      });
    }

    _controllers.removeWhere((key, controller) {
      if (key < index - 1 || key > index + 2) {
        controller.removeListener(_onVideoTick);
        controller.dispose();
        return true;
      }
      return false;
    });
  }

  void _resumeIfNeeded(int index) {
    final controller = _controllers[index];
    final episode = _episodes[index];
    if (controller == null || !controller.value.isInitialized) return;
    if (!episode.isInProgress) return;
    final target = controller.value.duration * episode.watchProgress;
    controller.seekTo(target);
  }

  void _onVideoTick() {
    if (!mounted) return;
    if (_paywallVisible) return;
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;

    final playing = controller.value.isPlaying;
    if (playing == _showPlayHint) {
      setState(() => _showPlayHint = !playing);
    }

    _saveProgress(_currentIndex);

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero) {
      final seconds = position.inSeconds;
      if (seconds >= 3) _trackRetention(_episodes[_currentIndex], 'retain_3s', seconds);
      if (seconds >= 15) _trackRetention(_episodes[_currentIndex], 'retain_15s', seconds);
      final ready = position.inMilliseconds >= duration.inMilliseconds * 0.88;
      if (ready != _nextTapReady) {
        setState(() => _nextTapReady = ready);
      }
    }

    final ended =
        !controller.value.isPlaying &&
        controller.value.duration > Duration.zero &&
        controller.value.position >=
            controller.value.duration - const Duration(milliseconds: 400);
    if (ended) {
      _trackRetention(
        _episodes[_currentIndex],
        'complete',
        controller.value.position.inSeconds,
      );
      _requestNext(fromAutoAdvance: true);
    }
  }

  void _saveProgress(int index) {
    final controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) return;
    final now = DateTime.now();
    final last = _lastProgressSave[index];
    if (last != null && now.difference(last).inSeconds < 5) return;
    final duration = controller.value.duration.inMilliseconds;
    if (duration <= 0) return;
    _lastProgressSave[index] = now;
    final progress = controller.value.position.inMilliseconds / duration;
    _episodeService.updateProgress(_episodes[index].id, progress.clamp(0, 1));
  }

  void _onPageChanged(int index) {
    _controllers[_currentIndex]?.pause();
    _saveProgress(_currentIndex);
    setState(() {
      _currentIndex = index;
      _advancing = false;
      _nextTapReady = false;
    });
    if (_episodes[index].isLocked) {
      _showPaywallFor(index);
      return;
    }
    if (_paywallVisible) {
      setState(() {
        _paywallVisible = false;
        _pendingUnlockIndex = null;
        _paywallMessage = null;
      });
    }
    final controller = _controllers[index];
    if (controller != null && controller.value.isInitialized) {
      _resumeIfNeeded(index);
      controller.play();
    }
    _preload(index);
    _episodeService.recordView(_episodes[index].id);
    _trackRetention(_episodes[index], 'start');
    if (index > 0) {
      _trackRetention(_episodes[index - 1], 'next_start');
    }
  }

  Future<void> _requestNext({bool fromAutoAdvance = false}) async {
    if (_advancing || _paywallVisible) return;
    if (_currentIndex >= _episodes.length - 1) return;
    final next = _episodes[_currentIndex + 1];
    if (next.isLocked) {
      _controllers[_currentIndex]?.pause();
      _showPaywallFor(_currentIndex + 1, freezeCurrent: true);
      return;
    }
    if (fromAutoAdvance) {
      _trackRetention(_episodes[_currentIndex], 'next_start');
    }
    _advancing = true;
    await _pageController?.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _togglePlay() {
    if (_paywallVisible) return;
    final controller = _controllers[_currentIndex];
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  Future<void> _refreshCredits() async {
    if (_auth.currentUser == null) return;
    final snapshot = await _credits.getMine();
    if (!mounted || !snapshot.success) return;
    setState(() => _creditsBalance = snapshot.availableCredits);
  }

  void _trackRetention(EpisodeModel episode, String event, [int positionSeconds = 0]) {
    final key = '${episode.id}:$event';
    if (_retentionSent.contains(key)) return;
    _retentionSent.add(key);
    _episodeService.recordRetention(
      episodeId: episode.id,
      event: event,
      positionSeconds: positionSeconds,
    );
  }

  void _showPaywallFor(int index, {bool freezeCurrent = false}) {
    if (index < 0 || index >= _episodes.length) return;
    _controllers[_currentIndex]?.pause();
    final target = _episodes[index];
    setState(() {
      _paywallVisible = true;
      _pendingUnlockIndex = index;
      _nextTapReady = false;
      _advancing = false;
      _paywallMessage = null;
    });
    _trackRetention(target, 'paywall_shown');
    if (!freezeCurrent && index != _currentIndex && _pageController != null) {
      _pageController!.jumpToPage(index);
    }
  }

  Future<void> _unlockPending() async {
    final index = _pendingUnlockIndex;
    if (index == null || _unlocking) return;
    if (_auth.currentUser == null) {
      if (!mounted) return;
      context.push('/login');
      return;
    }

    setState(() => _unlocking = true);
    final response = await _episodeService.unlockEpisode(_episodes[index].id);
    if (!mounted) return;

    if (!response.success || response.episode == null) {
      setState(() {
        _unlocking = false;
        _paywallMessage = response.message ?? 'Não foi possível desbloquear';
        if (response.availableCredits > 0 || response.reason == 'no_credits') {
          _creditsBalance = response.availableCredits;
        }
      });
      return;
    }

    setState(() {
      _episodes[index] = response.episode!;
      _creditsBalance = response.availableCredits;
      _paywallVisible = false;
      _pendingUnlockIndex = null;
      _unlocking = false;
      _paywallMessage = null;
    });
    _preload(index);
    if (index != _currentIndex) {
      await _pageController?.animateToPage(
        index,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      final controller = _controllers[index];
      if (controller != null && controller.value.isInitialized) {
        controller.play();
      }
    }
  }

  Future<void> _toggleLike() async {
    final episode = _current;
    if (episode == null) return;
    final response = await _episodeService.toggleLike(episode.id);
    if (!response.success || !mounted) return;
    var likes = episode.likesCount;
    if (response.isLiked && !episode.isLiked) likes += 1;
    if (!response.isLiked && episode.isLiked) likes = (likes - 1).clamp(0, 1 << 30);
    if (response.likesCount > 0) likes = response.likesCount;
    setState(() {
      _episodes[_currentIndex] = episode.copyWith(
        isLiked: response.isLiked,
        likesCount: likes,
      );
    });
  }

  Future<void> _toggleWatchlist() async {
    final episode = _current;
    if (episode == null) return;
    final series =
        episode.series ??
        SeriesModel(
          id: episode.seriesId,
          title: episode.series?.title ?? episode.title,
          description: '',
          coverUrl: episode.thumbnailUrl ?? '',
          genre: episode.series?.genre ?? '',
        );
    final added = await _watchlist.toggle(series);
    if (!mounted) return;
    setState(() => _inWatchlist = added);
  }

  void _showComments() {
    final episode = _current;
    if (episode == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(episodeId: episode.id),
    );
  }

  void _showEpisodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLighter,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Episodios',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  itemCount: _episodes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    final selected = index == _currentIndex;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (_episodes[index].isLocked) {
                          _showPaywallFor(index, freezeCurrent: true);
                          return;
                        }
                        _pageController?.jumpToPage(index);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _episodes[index].isLocked
                            ? const Icon(Icons.lock, size: 16, color: AppColors.textSecondary)
                            : Text(
                          '${_episodes[index].episodeNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? _buildError()
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 460 : double.infinity,
                    ),
                    child: _buildFeed(),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: _paywallVisible
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: _onPageChanged,
          itemCount: _episodes.length,
          itemBuilder: (context, index) => _buildPage(index),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  if (_current != null)
                    Text(
                      'Ep ${_current!.episodeNumber}/${_episodes.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showEpisodePicker,
                    icon: const Icon(Icons.view_list_outlined, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(int index) {
    final episode = _episodes[index];
    final controller = _controllers[index];
    final active = index == _currentIndex;

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            VerticalVideoView(controller: controller)
          else
            ColoredBox(
              color: Colors.black,
              child: episode.thumbnailUrl != null
                  ? Image.network(episode.thumbnailUrl!, fit: BoxFit.cover)
                  : const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.videoOverlayGradient),
          ),
          if (_showPlayHint && active)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white, size: 72),
            ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (episode.series != null)
                  GestureDetector(
                    onTap: () => context.push('/series/${episode.seriesId}'),
                    child: Text(
                      episode.series!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Ep ${episode.episodeNumber} · ${episode.title}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (episode.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    episode.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                if (index < _episodes.length - 1) ...[
                  const SizedBox(height: 10),
                  if (_nextTapReady && active && !_paywallVisible)
                    FilledButton(
                      onPressed: () {
                        _requestNext();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        _episodes[index + 1].isLocked
                            ? 'Continuar'
                            : 'Próximo episódio',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    const Text(
                      'Deslize para o proximo episodio',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 36,
            child: Column(
              children: [
                _sideButton(
                  icon: episode.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: episode.formattedLikes,
                  color: episode.isLiked ? AppColors.likeActive : Colors.white,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 18),
                _sideButton(
                  icon: Icons.chat_bubble_outline,
                  label: episode.formattedComments,
                  onTap: _showComments,
                ),
                const SizedBox(height: 18),
                _sideButton(
                  icon: _inWatchlist ? Icons.bookmark : Icons.bookmark_border,
                  label: 'Lista',
                  onTap: _toggleWatchlist,
                ),
                const SizedBox(height: 18),
                _sideButton(
                  icon: Icons.view_module_outlined,
                  label: 'Eps',
                  onTap: _showEpisodePicker,
                ),
              ],
            ),
          ),
          if (controller != null && controller.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: !_paywallVisible,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  backgroundColor: Colors.white24,
                  bufferedColor: Colors.white38,
                ),
              ),
            ),
          if (_paywallVisible &&
              active &&
              _pendingUnlockIndex != null &&
              _pendingUnlockIndex! < _episodes.length)
            PlayerPaywallOverlay(
              episodeNumber: _episodes[_pendingUnlockIndex!].episodeNumber,
              unlockCost: _episodes[_pendingUnlockIndex!].unlockCost,
              availableCredits: _creditsBalance,
              unlocking: _unlocking,
              authenticated: _auth.currentUser != null,
              message: _paywallMessage,
              onUnlock: _unlockPending,
              onLogin: () => context.push('/login'),
            ),
        ],
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
