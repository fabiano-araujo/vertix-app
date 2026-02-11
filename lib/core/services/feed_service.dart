import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/episode_model.dart';
import '../models/series_model.dart';

/// Feed Service for VERTIX
/// Handles personalized content feeds
class FeedService {
  final ApiClient _client = ApiClient();

  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  /// Get personalized "For You" feed
  Future<EpisodeListResponse> getForYouFeed({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.feedForYou,
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get trending content
  Future<EpisodeListResponse> getTrending({int limit = 10}) async {
    try {
      final response = await _client.get(
        ApiConstants.feedTrending,
        queryParameters: {'limit': limit},
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get new releases
  Future<EpisodeListResponse> getNewReleases({int limit = 10}) async {
    try {
      final response = await _client.get(
        ApiConstants.feedNew,
        queryParameters: {'limit': limit},
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get home page data (multiple sections)
  Future<HomeFeedResponse> getHomeFeed() async {
    try {
      final response = await _client.get(ApiConstants.feedHome);
      return HomeFeedResponse.fromJson(response.data);
    } catch (e) {
      return HomeFeedResponse(
        success: false,
        featured: null,
        trending: [],
        newReleases: [],
        continueWatching: [],
        recommendations: [],
        genres: {},
      );
    }
  }

  /// Get continue watching list
  Future<EpisodeListResponse> getContinueWatching({int limit = 10}) async {
    try {
      final response = await _client.get(
        ApiConstants.feedContinueWatching,
        queryParameters: {'limit': limit},
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get watch history
  Future<EpisodeListResponse> getHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.feedHistory,
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get liked episodes
  Future<EpisodeListResponse> getLikedEpisodes({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.feedLikes,
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get content by genre
  Future<EpisodeListResponse> getByGenre(
    String genre, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.feed}/genre/$genre',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return EpisodeListResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeListResponse(
        success: false,
        data: [],
      );
    }
  }
}

/// Home Feed Response with all sections
class HomeFeedResponse {
  final bool success;
  final SeriesModel? featured;
  final List<SeriesModel> trending;
  final List<SeriesModel> newReleases;
  final List<EpisodeModel> continueWatching;
  final List<SeriesModel> recommendations;
  final Map<String, List<SeriesModel>> genres;

  HomeFeedResponse({
    required this.success,
    this.featured,
    required this.trending,
    required this.newReleases,
    required this.continueWatching,
    required this.recommendations,
    required this.genres,
  });

  factory HomeFeedResponse.fromJson(Map<String, dynamic> json) {
    // Parse genres map
    final genresData = json['genres'] as Map<String, dynamic>? ?? {};
    final genres = <String, List<SeriesModel>>{};
    genresData.forEach((key, value) {
      genres[key] = (value as List<dynamic>?)
              ?.map((e) => SeriesModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    });

    return HomeFeedResponse(
      success: json['success'] as bool,
      featured: json['featured'] != null
          ? SeriesModel.fromJson(json['featured'] as Map<String, dynamic>)
          : null,
      trending: (json['trending'] as List<dynamic>?)
              ?.map((e) => SeriesModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      newReleases: (json['newReleases'] as List<dynamic>?)
              ?.map((e) => SeriesModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      continueWatching: (json['continueWatching'] as List<dynamic>?)
              ?.map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => SeriesModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      genres: genres,
    );
  }
}
