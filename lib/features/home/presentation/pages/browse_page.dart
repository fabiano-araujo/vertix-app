import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/series_service.dart';
import '../../../../core/services/search_service.dart';
import '../../../../core/models/series_model.dart';
import '../../../home/presentation/widgets/series_card.dart';

/// Genre browse page — Netflix-style catalog grid.
class BrowsePage extends StatefulWidget {
  final String? genre;

  const BrowsePage({super.key, this.genre});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _seriesService = SeriesService();
  final _searchService = SearchService();

  List<String> _genres = [];
  List<SeriesModel> _series = [];
  String? _selectedGenre;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.genre;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final genres = await _searchService.getGenres();
    final series = _selectedGenre == null
        ? await _seriesService.getSeries(limit: 40)
        : await _seriesService.getByGenre(_selectedGenre!, limit: 40);
    if (!mounted) return;
    setState(() {
      _genres = genres;
      _series = series.data;
      _isLoading = false;
    });
  }

  Future<void> _selectGenre(String? genre) async {
    setState(() {
      _selectedGenre = genre;
      _isLoading = true;
    });
    final series = genre == null
        ? await _seriesService.getSeries(limit: 40)
        : await _seriesService.getByGenre(genre, limit: 40);
    if (!mounted) return;
    setState(() {
      _series = series.data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.background,
              title: Text(_selectedGenre ?? 'Categorias'),
            ),
      body: Padding(
        padding: EdgeInsets.only(top: isDesktop ? Responsive.topNavHeight : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                child: Text(
                  _selectedGenre ?? 'Categorias',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: padding),
                children: [
                  _chip('Todas', _selectedGenre == null, () => _selectGenre(null)),
                  for (final genre in _genres)
                    _chip(genre, _selectedGenre == genre, () => _selectGenre(genre)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _series.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma serie nesta categoria',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(padding, 8, padding, 32),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 6 : 3,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _series.length,
                          itemBuilder: (context, index) {
                            final item = _series[index];
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                return SeriesCard(
                                  id: item.id,
                                  title: item.title,
                                  coverUrl: item.coverUrl,
                                  genre: item.genre,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  onTap: () => context.push('/series/${item.id}'),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary.withAlpha(80),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}
