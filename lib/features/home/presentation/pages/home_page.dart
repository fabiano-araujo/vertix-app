import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/feed_service.dart';
import '../../../../core/services/series_service.dart';
import '../../../../core/models/series_model.dart';
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

  bool _showAppBarBackground = false;
  bool _isLoading = true;

  SeriesModel? _featuredSeries;
  List<SeriesModel> _trending = [];
  List<SeriesModel> _newReleases = [];
  List<SeriesModel> _recommendations = [];
  List<SeriesModel> _action = [];
  List<SeriesModel> _romance = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
        setState(() {
          _featuredSeries = homeResponse.featured;
          _trending = homeResponse.trending;
          _newReleases = homeResponse.newReleases;
          _recommendations = homeResponse.recommendations;
          _action = homeResponse.genres['Acao'] ?? [];
          _romance = homeResponse.genres['Romance'] ?? [];
          _isLoading = false;
        });
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

  List<Map<String, dynamic>> _seriesToMaps(List<SeriesModel> series) {
    return series.map((s) => {
      'id': s.id,
      'title': s.title,
      'coverUrl': s.coverUrl,
      'genre': s.genre,
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
                      onPlay: () {
                        if (_featuredSeries != null) {
                          context.push('/series/${_featuredSeries!.id}');
                        }
                      },
                    ),
                  ),

                  // Quick Filters
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Series', true),
                            _buildFilterChip('Filmes', false),
                            _buildFilterChip('Categorias', false),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Em Alta (Trending)
                  if (_trending.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SeriesCarousel(
                        title: 'Em Alta',
                        icon: Icons.local_fire_department,
                        iconColor: AppColors.primary,
                        items: _seriesToMaps(_trending),
                        onItemTap: (id) => context.push('/series/$id'),
                      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1),
                    ),

                  // Novidades (New Releases)
                  if (_newReleases.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SeriesCarousel(
                        title: 'Novidades',
                        icon: Icons.new_releases_outlined,
                        items: _seriesToMaps(_newReleases),
                        onItemTap: (id) => context.push('/series/$id'),
                      ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: 0.1),
                    ),

                  // Recomendado para voce
                  if (_recommendations.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SeriesCarousel(
                        title: 'Recomendado para voce',
                        icon: Icons.thumb_up_outlined,
                        items: _seriesToMaps(_recommendations),
                        onItemTap: (id) => context.push('/series/$id'),
                      ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: 0.1),
                    ),

                  // Acao
                  if (_action.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SeriesCarousel(
                        title: 'Acao',
                        items: _seriesToMaps(_action),
                        onItemTap: (id) => context.push('/series/$id'),
                      ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideX(begin: 0.1),
                    ),

                  // Romance
                  if (_romance.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SeriesCarousel(
                        title: 'Romance',
                        items: _seriesToMaps(_romance),
                        onItemTap: (id) => context.push('/series/$id'),
                      ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideX(begin: 0.1),
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
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (value) {},
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
