import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/series_model.dart';
import '../models/episode_model.dart';

/// Search Service for VERTIX
class SearchService {
  final ApiClient _client = ApiClient();

  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  /// Search series and episodes
  Future<SearchResponse> search(
    String query, {
    String? genre,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'q': query,
        'limit': limit,
        'offset': offset,
      };
      if (genre != null) queryParams['genre'] = genre;

      final response = await _client.get(
        ApiConstants.search,
        queryParameters: queryParams,
      );
      return SearchResponse.fromJson(response.data);
    } catch (e) {
      return SearchResponse(
        success: false,
        series: [],
        episodes: [],
      );
    }
  }

  /// Get search suggestions (autocomplete)
  Future<List<String>> getSuggestions(String query) async {
    try {
      final response = await _client.get(
        ApiConstants.searchSuggestions,
        queryParameters: {'q': query},
      );

      if (response.data['success'] == true) {
        return (response.data['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get trending searches
  Future<List<String>> getTrendingSearches() async {
    try {
      final response = await _client.get(ApiConstants.searchTrending);

      if (response.data['success'] == true) {
        return (response.data['trending'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get available genres
  Future<List<String>> getGenres() async {
    try {
      final response = await _client.get(ApiConstants.searchGenres);

      if (response.data['success'] == true) {
        return (response.data['genres'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// Search Response
class SearchResponse {
  final bool success;
  final List<SeriesModel> series;
  final List<EpisodeModel> episodes;
  final PaginationInfo? pagination;

  SearchResponse({
    required this.success,
    required this.series,
    required this.episodes,
    this.pagination,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      success: json['success'] as bool,
      series: (json['series'] as List<dynamic>?)
              ?.map((e) => SeriesModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isEmpty => series.isEmpty && episodes.isEmpty;
  bool get isNotEmpty => !isEmpty;
}
