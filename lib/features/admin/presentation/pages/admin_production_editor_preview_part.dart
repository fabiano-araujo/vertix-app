part of 'admin_production_editor_page.dart';

class _WorkflowStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool last;

  const _WorkflowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withAlpha(100)),
                  ),
                  child: Icon(
                    done ? Icons.check : icon,
                    color: color,
                    size: 16,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: AppColors.surfaceLighter),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineClip {
  final double start;
  final double duration;
  final String label;
  final Color color;
  final IconData icon;

  const _TimelineClip({
    required this.start,
    required this.duration,
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _PreviewClip {
  final ProductionTakeItem take;
  final String source;
  final bool isAsset;

  const _PreviewClip({
    required this.take,
    required this.source,
    required this.isAsset,
  });
}

class _EpisodePreviewDialog extends StatefulWidget {
  final ProductionProject project;
  final ProductionEpisodeItem episode;

  const _EpisodePreviewDialog({required this.project, required this.episode});

  @override
  State<_EpisodePreviewDialog> createState() => _EpisodePreviewDialogState();
}

class _EpisodePreviewDialogState extends State<_EpisodePreviewDialog> {
  late final List<_PreviewClip> _clips = _previewClips(widget.episode);
  late final Duration _totalDuration = _episodeDuration(widget.episode);
  late final bool _usesAssembledPreview =
      widget.episode.assembledOutputUrl?.trim().isNotEmpty == true;

  VideoPlayerController? _controller;
  Timer? _storyboardTimer;
  Duration _storyboardPosition = Duration.zero;
  int _clipIndex = 0;
  int _loadGeneration = 0;
  bool _isAdvancingClip = false;
  bool _isLoadingVideo = false;
  bool _isPlaying = false;
  bool _storyboardMode = false;
  String? _videoError;

  bool get _hasPlayableVideo => _clips.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasPlayableVideo) {
      _loadClip(0, autoplay: true);
    } else {
      _storyboardMode = true;
      _isPlaying = true;
      _startStoryboardTimer();
    }
  }

  static List<_PreviewClip> _previewClips(ProductionEpisodeItem episode) {
    final assembled = episode.assembledOutputUrl?.trim();
    if (assembled != null && assembled.isNotEmpty && episode.takes.isNotEmpty) {
      final clip = _previewClip(episode.takes.first, assembled);
      if (clip != null) return [clip];
    }
    final clips = <_PreviewClip>[];
    for (final take in episode.takes) {
      final output = take.outputUrl?.trim();
      if (output == null || output.isEmpty || output.startsWith('local://')) {
        continue;
      }
      final clip = _previewClip(take, output);
      if (clip != null) clips.add(clip);
    }
    return clips;
  }

  static _PreviewClip? _previewClip(ProductionTakeItem take, String output) {
    if (output.startsWith('asset://')) {
      return _PreviewClip(
        take: take,
        source: output.substring('asset://'.length),
        isAsset: true,
      );
    }
    final source = _resolveProductionMediaUrl(output);
    final uri = Uri.tryParse(source);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return _PreviewClip(take: take, source: source, isAsset: false);
  }

  static Duration _episodeDuration(ProductionEpisodeItem episode) {
    final seconds = episode.takes.fold<int>(
      0,
      (total, take) => total + take.durationSeconds,
    );
    return Duration(seconds: seconds > 0 ? seconds : 1);
  }

  Future<void> _loadClip(int index, {required bool autoplay}) async {
    if (index < 0 || index >= _clips.length) return;
    final generation = ++_loadGeneration;
    _storyboardTimer?.cancel();
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _clipIndex = index;
      _isLoadingVideo = true;
      _isPlaying = autoplay;
      _storyboardMode = false;
      _videoError = null;
    });

    final clip = _clips[index];
    final controller = clip.isAsset
        ? VideoPlayerController.asset(clip.source)
        : VideoPlayerController.networkUrl(Uri.parse(clip.source));

    try {
      await controller.initialize();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handleVideoUpdate);
      _controller = controller;
      setState(() => _isLoadingVideo = false);
      if (autoplay) {
        await controller.play();
      }
    } catch (error) {
      await controller.dispose();
      if (!mounted || generation != _loadGeneration) return;
      _useStoryboard(
        'Nao foi possivel carregar o video do take ${clip.take.number}: $error',
      );
    }
  }

  void _handleVideoUpdate() {
    final controller = _controller;
    if (!mounted ||
        _storyboardMode ||
        _isAdvancingClip ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    if (value.hasError) {
      _useStoryboard(value.errorDescription ?? 'Erro ao reproduzir o video');
      return;
    }
    if (value.isPlaying != _isPlaying) {
      setState(() => _isPlaying = value.isPlaying);
    }
    final duration = value.duration;
    if (duration > Duration.zero &&
        value.position >= duration - const Duration(milliseconds: 80)) {
      if (_clipIndex + 1 < _clips.length) {
        _isAdvancingClip = true;
        _loadClip(
          _clipIndex + 1,
          autoplay: true,
        ).whenComplete(() => _isAdvancingClip = false);
      } else if (value.isPlaying) {
        controller.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  void _togglePlayback() {
    if (_storyboardMode) {
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) {
        _startStoryboardTimer();
      } else {
        _storyboardTimer?.cancel();
      }
      return;
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _startStoryboardTimer() {
    _storyboardTimer?.cancel();
    _storyboardTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_isPlaying) return;
      final next = _storyboardPosition + const Duration(milliseconds: 100);
      if (next >= _totalDuration) {
        setState(() {
          _storyboardPosition = Duration.zero;
          _isPlaying = false;
        });
        _storyboardTimer?.cancel();
      } else {
        setState(() => _storyboardPosition = next);
      }
    });
  }

  void _useStoryboard(String message) {
    _storyboardTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    if (!mounted) return;
    setState(() {
      _storyboardMode = true;
      _isLoadingVideo = false;
      _isPlaying = true;
      _storyboardPosition = Duration.zero;
      _videoError = message;
    });
    _startStoryboardTimer();
  }

  void _restart() {
    if (_storyboardMode) {
      setState(() {
        _storyboardPosition = Duration.zero;
        _isPlaying = true;
      });
      _startStoryboardTimer();
    } else {
      _loadClip(0, autoplay: true);
    }
  }

  void _skipStoryboard(Duration amount) {
    final next = _storyboardPosition + amount;
    final clamped = next < Duration.zero
        ? Duration.zero
        : next > _totalDuration
        ? _totalDuration
        : next;
    setState(() => _storyboardPosition = clamped);
  }

  ProductionTakeItem get _currentTake {
    if (_storyboardMode || _usesAssembledPreview) {
      final position = _storyboardMode
          ? _storyboardPosition
          : (_controller?.value.position ?? Duration.zero);
      var elapsed = 0;
      for (final take in widget.episode.takes) {
        elapsed += take.durationSeconds;
        if (position.inMilliseconds < elapsed * 1000) return take;
      }
      return widget.episode.takes.last;
    }
    return _clips[_clipIndex].take;
  }

  Duration get _position {
    if (_storyboardMode) return _storyboardPosition;
    return _controller?.value.position ?? Duration.zero;
  }

  Duration get _positionDuration {
    if (_storyboardMode) return _totalDuration;
    final duration = _controller?.value.duration ?? Duration.zero;
    return duration > Duration.zero ? duration : Duration(seconds: 1);
  }

  @override
  void dispose() {
    _storyboardTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final currentTake = _currentTake;
    final currentPosition = _position;
    final duration = _positionDuration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (currentPosition.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.play_circle_outline, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text('Prévia da montagem', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: screenHeight * 0.72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildViewport(currentTake),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Voltar 10 segundos',
                    onPressed: _storyboardMode
                        ? () => _skipStoryboard(const Duration(seconds: -10))
                        : null,
                    icon: const Icon(Icons.replay_10),
                  ),
                  IconButton.filled(
                    tooltip: _isPlaying ? 'Pausar' : 'Reproduzir',
                    onPressed: _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: 'Reiniciar',
                    onPressed: _restart,
                    icon: const Icon(Icons.replay),
                  ),
                  IconButton(
                    tooltip: 'Avançar 10 segundos',
                    onPressed: _storyboardMode
                        ? () => _skipStoryboard(const Duration(seconds: 10))
                        : null,
                    icon: const Icon(Icons.forward_10),
                  ),
                ],
              ),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(_formatPreviewDuration(currentPosition)),
                  const Spacer(),
                  Text(_formatPreviewDuration(duration)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Take ${currentTake.number} • ${currentTake.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _storyboardMode
                      ? _videoError == null
                            ? 'Prévia storyboard: os takes ainda não têm vídeo renderizado.'
                            : 'Vídeo indisponível; exibindo a prévia storyboard.'
                      : 'Vídeos renderizados serão reproduzidos em sequência.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              if (_hasPlayableVideo && _storyboardMode) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _loadClip(0, autoplay: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tentar vídeo novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _buildViewport(ProductionTakeItem take) {
    final controller = _controller;
    if (!_storyboardMode &&
        !_isLoadingVideo &&
        controller != null &&
        controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (!_isPlaying)
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(170),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.play_arrow, size: 34),
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildProjectCover(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0xE9000000)],
            ),
          ),
        ),
        if (_isLoadingVideo)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
              ),
              child: const Padding(
                padding: EdgeInsets.all(15),
                child: Icon(Icons.movie_filter_outlined, size: 34),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Text(
            'TAKE ${take.number}\n${take.title}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectCover() {
    if (widget.project.coverAssetPath?.isNotEmpty == true) {
      return Image.asset(
        widget.project.coverAssetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildProjectCoverFallback(),
      );
    }
    if (widget.project.coverUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: widget.project.coverUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildProjectCoverFallback(),
      );
    }
    return _buildProjectCoverFallback();
  }

  Widget _buildProjectCoverFallback() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF183153), Color(0xFF121212)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 54,
        color: AppColors.primaryLight,
      ),
    ),
  );
}

String _formatPreviewDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
