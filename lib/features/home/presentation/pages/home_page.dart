import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/feed_service.dart';
import '../../../../core/services/series_service.dart';
import '../../../../core/services/episode_service.dart';
import '../../../../core/services/search_service.dart';
import '../../../../core/services/watchlist_service.dart';
import '../../../../core/models/series_model.dart';
import '../../../../core/models/episode_model.dart';
import '../widgets/series_carousel.dart';
import '../widgets/featured_banner.dart';

/// Home Page with horizontal carousels
/// Shows: Em Alta, Novidades, Recomendado, Genre carousels
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final FeedService _feedService = FeedService();
  final SeriesService _seriesService = SeriesService();
  final EpisodeService _episodeService = EpisodeService();
  final SearchService _searchService = SearchService();
  final WatchlistService _watchlist = WatchlistService();

  bool _showAppBarBackground = false;
  bool _isLoading = true;
  bool _featuredInList = false;

  SeriesModel? _featuredSeries;
  List<SeriesModel> _trending = [];
  List<SeriesModel> _newReleases = [];
  List<SeriesModel> _recommendations = [];
  List<SeriesModel> _action = [];
  List<SeriesModel> _romance = [];
  List<EpisodeModel> _continueWatching = [];
  List<String> _genres = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _watchlist.revision.addListener(_onWatchlistChanged);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _watchlist.revision.removeListener(_onWatchlistChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onWatchlistChanged() {
    if (!mounted) return;
    setState(() {
      _featuredInList =
          _featuredSeries != null && _watchlist.contains(_featuredSeries!.id);
    });
  }

  void _onScroll() {
    final showBackground = _scrollController.offset > 100;
    if (showBackground != _showAppBarBackground) {
      setState(() => _showAppBarBackground = showBackground);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load home feed data
      final homeResponse = await _feedService.getHomeFeed();

      if (homeResponse.success) {
        await _watchlist.ensureLoaded();
        final genres = await _searchService.getGenres();
        setState(() {
          _featuredSeries = homeResponse.featured;
          _trending = homeResponse.trending;
          _newReleases = homeResponse.newReleases;
          _recommendations = homeResponse.recommendations;
          _continueWatching = homeResponse.continueWatching;
          _action =
              homeResponse.genres['Acao'] ?? homeResponse.genres['acao'] ?? [];
          _romance =
              homeResponse.genres['Romance'] ??
              homeResponse.genres['romance'] ??
              [];
          _featuredSeries =
              homeResponse.featured ??
              (_trending.isNotEmpty
                  ? _trending.first
                  : (_newReleases.isNotEmpty ? _newReleases.first : null));
          _featuredInList = _featuredSeries != null &&
              _watchlist.contains(_featuredSeries!.id);
          _genres = genres;
          _isLoading = false;
        });
        if (_continueWatching.isEmpty) {
          final extra = await _feedService.getContinueWatching();
          if (mounted && extra.data.isNotEmpty) {
            setState(() => _continueWatching = extra.data);
          }
        }
      } else {
        // Fallback to individual calls
        await _loadIndividualData();
      }
    } catch (e) {
      await _loadIndividualData();
    }
  }

  Future<void> _loadIndividualData() async {
    final trending = await _seriesService.getTrending(limit: 10);
    final newSeries = await _seriesService.getNew(limit: 10);
    final actionSeries = await _seriesService.getByGenre('Acao', limit: 10);
    final romanceSeries = await _seriesService.getByGenre('Romance', limit: 10);

    setState(() {
      _trending = trending.data;
      _newReleases = newSeries.data;
      _action = actionSeries.data;
      _romance = romanceSeries.data;
      if (_trending.isNotEmpty) {
        _featuredSeries = _trending.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _openSeries(int seriesId) async {
    context.push('/series/$seriesId');
  }

  Future<void> _playSeries(int seriesId) async {
    final inProgress = _continueWatching.where((item) => item.seriesId == seriesId);
    if (inProgress.isNotEmpty) {
      context.push('/player/${inProgress.first.id}');
      return;
    }

    final response = await _episodeService.getEpisodesBySeries(
      seriesId,
      limit: 1,
    );

    if (!mounted) return;

    if (response.success && response.data.isNotEmpty) {
      context.push('/player/${response.data.first.id}');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta série ainda não possui episódios disponíveis.'),
      ),
    );
  }

  Future<void> _toggleFeaturedList() async {
    if (_featuredSeries == null) return;
    final added = await _watchlist.toggle(_featuredSeries!);
    if (!mounted) return;
    setState(() => _featuredInList = added);
  }

  void _openCategories() {
    if (_genres.isEmpty) {
      context.push('/browse');
      return;
    }
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Todas'),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/browse');
                  },
                ),
                for (final genre in _genres)
                  ActionChip(
                    label: Text(genre),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/browse?genre=${Uri.encodeQueryComponent(genre)}');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _seriesToMaps(List<SeriesModel> series) {
    return series
        .map(
          (s) => {
            'id': s.id,
            'title': s.title,
            'coverUrl': s.coverUrl,
            'genre': s.genre,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: _showAppBarBackground
                  ? AppColors.background.withAlpha(240)
                  : Colors.transparent,
              title: Row(
                children: [
                  Text(
                    'VERTIX',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push('/search'),
                ),
                IconButton(
                  icon: const Icon(Icons.cast_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Featured Banner
                  SliverToBoxAdapter(
                    child: FeaturedBanner(
                      series: _featuredSeries,
                      inWatchlist: _featuredInList,
                      onPlay: () {
                        if (_featuredSeries != null) {
                          _playSeries(_featuredSeries!.id);
                        }
                      },
                      onInfo: () {
                        if (_featuredSeries != null) {
                          _openSeries(_featuredSeries!.id);
                        }
                      },
                      onMyList: _toggleFeaturedList,
                    ),
                  ),

                  if (!isDesktop)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Series', true, () {}),
                              _buildFilterChip('Categorias', false, _openCategories),
                            ],
                          ),
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: Offset(0, isDesktop ? -72 : 0),
                      child: Column(
                        children: [
                          if (_continueWatching.isNotEmpty)
                            SeriesCarousel(
                              title: 'Continue Assistindo',
                              icon: Icons.play_circle_outline,
                              items: _continueWatching
                                  .map(
                                    (episode) => {
                                      'id': episode.seriesId,
                                      'title': episode.series?.title ?? episode.title,
                                      'coverUrl': episode.series?.coverUrl ??
                                          episode.thumbnailUrl ??
                                          '',
                                      'genre': episode.series?.genre,
                                    },
                                  )
                                  .toList(),
                              onItemTap: (seriesId) {
                                final episode = _continueWatching.firstWhere(
                                  (item) => item.seriesId == seriesId,
                                  orElse: () => _continueWatching.first,
                                );
                                context.push('/player/${episode.id}');
                              },
                            ).animate().fadeIn(duration: 300.ms),
                          if (_watchlist.items.isNotEmpty)
                            SeriesCarousel(
                              title: 'Minha Lista',
                              icon: Icons.bookmark,
                              items: _seriesToMaps(_watchlist.items),
                              onItemTap: _openSeries,
                            ).animate().fadeIn(duration: 300.ms),
                          if (_trending.isNotEmpty)
                            SeriesCarousel(
                              title: 'Em Alta',
                              icon: Icons.local_fire_department,
                              iconColor: AppColors.primary,
                              items: _seriesToMaps(_trending),
                              onItemTap: _openSeries,
                            ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1),
                          if (_newReleases.isNotEmpty)
                            SeriesCarousel(
                                  title: 'Novidades',
                                  icon: Icons.new_releases_outlined,
                                  items: _seriesToMaps(_newReleases),
                                  onItemTap: _openSeries,
                                )
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 100.ms)
                                .slideX(begin: 0.1),
                          if (_recommendations.isNotEmpty)
                            SeriesCarousel(
                                  title: 'Recomendado para voce',
                                  icon: Icons.thumb_up_outlined,
                                  items: _seriesToMaps(_recommendations),
                                  onItemTap: _openSeries,
                                )
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 200.ms)
                                .slideX(begin: 0.1),
                          if (_action.isNotEmpty)
                            SeriesCarousel(
                                  title: 'Acao',
                                  items: _seriesToMaps(_action),
                                  onItemTap: _openSeries,
                                )
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 300.ms)
                                .slideX(begin: 0.1),
                          if (_romance.isNotEmpty)
                            SeriesCarousel(
                                  title: 'Romance',
                                  items: _seriesToMaps(_romance),
                                  onItemTap: _openSeries,
                                )
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 400.ms)
                                .slideX(begin: 0.1),
                        ],
                      ),
                    ),
                  ),

                  // Empty state fallback
                  if (_trending.isEmpty && _newReleases.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma serie disponivel',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: isDesktop ? 96 : 100),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary.withAlpha(80),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
