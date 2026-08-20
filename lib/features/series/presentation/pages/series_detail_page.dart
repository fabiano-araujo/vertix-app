import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/series_service.dart';
import '../../../../core/services/episode_service.dart';
import '../../../../core/services/watchlist_service.dart';
import '../../../../core/models/series_model.dart';
import '../../../../core/models/episode_model.dart';

/// Netflix-style series title page.
class SeriesDetailPage extends StatefulWidget {
  final int seriesId;

  const SeriesDetailPage({super.key, required this.seriesId});

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  final _seriesService = SeriesService();
  final _episodeService = EpisodeService();
  final _watchlist = WatchlistService();

  SeriesModel? _series;
  List<EpisodeModel> _episodes = [];
  bool _isLoading = true;
  bool _inWatchlist = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _seriesService.getSeriesDetail(widget.seriesId);
      final seriesResponse = detail.series;
      final episodesResponse = await _episodeService.getEpisodesBySeries(
        widget.seriesId,
        limit: 80,
      );

      if (seriesResponse.success && seriesResponse.data != null) {
        await _watchlist.ensureLoaded();
        final episodes = episodesResponse.data.isNotEmpty
            ? episodesResponse.data
            : detail.episodes;
        setState(() {
          _series = seriesResponse.data;
          _episodes = episodes;
          _inWatchlist = _watchlist.contains(widget.seriesId);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = seriesResponse.message ?? 'Erro ao carregar serie';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao conectar com o servidor';
        _isLoading = false;
      });
    }
  }

  EpisodeModel? get _resumeEpisode {
    for (final episode in _episodes) {
      if (!episode.isLocked && episode.isInProgress) return episode;
    }
    return null;
  }

  int get _episodeCount => _episodes.isNotEmpty
      ? _episodes.length
      : (_series?.totalEpisodesCount ?? 0);

  void _playSeries() {
    if (_episodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta série ainda não possui episódios disponíveis.'),
        ),
      );
      return;
    }
    final episode = _resumeEpisode ??
        _episodes.firstWhere((item) => !item.isLocked, orElse: () => _episodes.first);
    context.push('/player/${episode.id}');
  }

  Future<void> _toggleWatchlist() async {
    if (_series == null) return;
    final added = await _watchlist.toggle(_series!);
    if (!mounted) return;
    setState(() => _inWatchlist = added);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? _buildError()
              : _buildContent(),
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
            onPressed: _loadData,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_series == null) return const SizedBox();
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.horizontalPadding(context);
    final height = MediaQuery.sizeOf(context).height;
    final imageHeight = isDesktop
        ? (height * 0.72).clamp(420.0, 640.0)
        : height * 0.42;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _series!.heroImageUrl,
                      fit: BoxFit.cover,
                      alignment: isDesktop
                          ? const Alignment(0.4, 0)
                          : Alignment.center,
                      placeholder: (_, __) =>
                          const ColoredBox(color: AppColors.surface),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: AppColors.surface,
                        child: Icon(Icons.movie, size: 64),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            AppColors.background.withValues(alpha: 0.75),
                            AppColors.background,
                          ],
                          stops: const [0.0, 0.4, 0.82, 1.0],
                        ),
                      ),
                    ),
                    if (isDesktop)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.background.withValues(alpha: 0.88),
                              AppColors.background.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.38, 0.78],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 16,
                      left: padding - 8,
                      child: SafeArea(
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(0, isDesktop ? -96 : -56),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCopy(isDesktop),
                        const SizedBox(height: 36),
                        Text(
                          'Episódios',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _episodeCount == 1
                              ? '1 episódio'
                              : '$_episodeCount episódios',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.surfaceLighter),
                        const SizedBox(height: 8),
                        if (_episodes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'Os episódios desta série estarão disponíveis em breve.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ..._episodes.map(_buildEpisodeRow),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCopy(bool isDesktop) {
    final resume = _resumeEpisode;
    final year = _series!.createdAt?.year.toString();
    final match = _series!.hypeScore > 0
        ? '${(_series!.hypeScore.clamp(0, 100)).round()}% relevante'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _series!.title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 48 : 32,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (match != null)
              Text(
                match,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            if (year != null)
              Text(year, style: const TextStyle(color: AppColors.textSecondary)),
            _metaBox(
              _episodeCount > 0
                  ? '$_episodeCount eps'
                  : 'Série',
            ),
            _metaBox(_series!.genre),
            if (_series!.isAiGenerated) _metaBox('IA', accent: true),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _series!.description,
          maxLines: isDesktop ? 4 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: isDesktop ? 16 : 14,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _playSeries,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: Text(resume != null ? 'Continuar' : 'Assistir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white,
                disabledForegroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 28 : 22,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _roundAction(
              icon: _inWatchlist ? Icons.check : Icons.add,
              tooltip: _inWatchlist ? 'Na Minha Lista' : 'Minha Lista',
              onTap: _toggleWatchlist,
            ),
          ],
        ),
      ],
    );
  }

  Widget _metaBox(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: accent ? AppColors.primary : AppColors.textTertiary,
        ),
        color: accent ? AppColors.primary.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? AppColors.primaryLight : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textSecondary),
            color: Colors.black.withValues(alpha: 0.35),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEpisodeRow(EpisodeModel episode) {
    return InkWell(
      onTap: () => context.push('/player/${episode.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${episode.episodeNumber}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 140,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: episode.thumbnailUrl ?? _series!.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppColors.surfaceLight),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: AppColors.surfaceLight,
                            child: const Icon(Icons.play_arrow, color: Colors.white70),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        if (episode.isLocked)
                          const ColoredBox(
                            color: Color(0x88000000),
                            child: Center(
                              child: Icon(Icons.lock, color: Colors.white, size: 22),
                            ),
                          ),
                        if (episode.watchProgress > 0.05)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: episode.watchProgress.clamp(0, 1),
                              minHeight: 3,
                              backgroundColor: Colors.black45,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              episode.title.isEmpty
                                  ? 'Episódio ${episode.episodeNumber}'
                                  : episode.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (episode.isLocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.lock, size: 16, color: AppColors.textSecondary),
                            ),
                          if (episode.duration > 0)
                            Text(
                              episode.formattedDuration,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        episode.description?.trim().isNotEmpty == true
                            ? episode.description!
                            : _series!.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.surfaceLighter, height: 1),
          ],
        ),
      ),
    );
  }
}
