import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
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
  bool _showAppBarBackground = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _showAppBarBackground
            ? AppColors.background.withValues(alpha: 0.95)
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
        onRefresh: () async {
          // TODO: Refresh data
          await Future.delayed(const Duration(seconds: 1));
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Featured Banner
            const SliverToBoxAdapter(
              child: FeaturedBanner(),
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
            SliverToBoxAdapter(
              child: SeriesCarousel(
                title: 'Em Alta',
                icon: Icons.local_fire_department,
                iconColor: AppColors.primary,
                items: _getMockSeries(),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1),
            ),

            // Novidades (New Releases)
            SliverToBoxAdapter(
              child: SeriesCarousel(
                title: 'Novidades',
                icon: Icons.new_releases_outlined,
                items: _getMockSeries(),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: 0.1),
            ),

            // Recomendado para voce
            SliverToBoxAdapter(
              child: SeriesCarousel(
                title: 'Recomendado para voce',
                icon: Icons.thumb_up_outlined,
                items: _getMockSeries(),
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: 0.1),
            ),

            // Series Curtas
            SliverToBoxAdapter(
              child: SeriesCarousel(
                title: 'Series Curtas',
                icon: Icons.timer_outlined,
                items: _getMockSeries(),
              ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideX(begin: 0.1),
            ),

            // Acao
            SliverToBoxAdapter(
              child: SeriesCarousel(
                title: 'Acao',
                items: _getMockSeries(),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideX(begin: 0.1),
            ),

            // Romance
            SliverToBoxAdapter(
              child: SeriesCarousel(
                title: 'Romance',
                items: _getMockSeries(),
              ).animate().fadeIn(duration: 300.ms, delay: 500.ms).slideX(begin: 0.1),
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
        selectedColor: AppColors.primary.withValues(alpha: 0.3),
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

  // Mock data for demonstration
  List<Map<String, dynamic>> _getMockSeries() {
    return List.generate(
      10,
      (index) => {
        'id': index,
        'title': 'Serie ${index + 1}',
        'coverUrl': 'https://picsum.photos/300/450?random=$index',
        'genre': ['Acao', 'Drama', 'Comedia', 'Romance'][index % 4],
      },
    );
  }
}
