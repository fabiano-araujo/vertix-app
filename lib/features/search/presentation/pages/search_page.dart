import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/search_service.dart';
import '../../../../core/services/series_service.dart';
import '../../../../core/models/series_model.dart';

/// Search Page
/// Features: Large search field, suggestions, history, results grid
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SearchService _searchService = SearchService();
  final SeriesService _seriesService = SeriesService();

  bool _isSearching = false;
  bool _isLoading = false;
  String _searchQuery = '';

  List<String> _suggestions = [];
  List<String> _trendingSearches = [];
  List<SeriesModel> _searchResults = [];
  List<SeriesModel> _recommendations = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final trending = await _searchService.getTrendingSearches();
    final recommendations = await _seriesService.getTrending(limit: 10);

    setState(() {
      _trendingSearches = trending;
      _recommendations = recommendations.data;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    // Debounce search
    _debounce?.cancel();
    if (query.isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _performSearch(query);
      });
    } else {
      setState(() {
        _searchResults = [];
        _suggestions = [];
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    // Get suggestions
    final suggestions = await _searchService.getSuggestions(query);

    // Get search results
    final results = await _searchService.search(query);

    setState(() {
      _suggestions = suggestions;
      _searchResults = results.series;
      _isLoading = false;
    });
  }

  void _searchFor(String query) {
    _searchController.text = query;
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Buscar'),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Busque series, filmes...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _focusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _isSearching
                    ? _buildSearchResults()
                    : _buildRecommendations(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending Searches
          if (_trendingSearches.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Trending',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _trendingSearches.map((search) {
                return ActionChip(
                  label: Text(search),
                  onPressed: () => _searchFor(search),
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Recommendations
          if (_recommendations.isNotEmpty) ...[
            const Text(
              'Series recomendadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final item = _recommendations[index];
                return _buildRecommendationItem(item);
              },
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(SeriesModel series) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: series.thumbnailUrl ?? series.coverUrl,
          width: 100,
          height: 60,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.surfaceLight,
          ),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.surfaceLight,
            child: const Icon(Icons.movie_outlined),
          ),
        ),
      ),
      title: Text(
        series.title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        series.genre,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline),
        onPressed: () => context.push('/series/${series.id}'),
      ),
      onTap: () => context.push('/series/${series.id}'),
    );
  }

  Widget _buildSearchResults() {
    // Show suggestions if available and no results yet
    if (_suggestions.isNotEmpty && _searchResults.isEmpty && !_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            leading: const Icon(Icons.search, color: AppColors.textSecondary),
            title: Text(suggestion),
            onTap: () => _searchFor(suggestion),
          );
        },
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textTertiary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum resultado para "$_searchQuery"',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${_searchResults.length} resultados',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              return _buildSearchResultCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(SeriesModel series) {
    return GestureDetector(
      onTap: () => context.push('/series/${series.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: series.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surfaceLight,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(Icons.movie_outlined),
                    ),
                  ),
                  // Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(150),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            series.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
