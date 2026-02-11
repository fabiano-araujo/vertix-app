import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/episode_model.dart';

/// Episode Service for VERTIX
class EpisodeService {
  final ApiClient _client = ApiClient();

  static final EpisodeService _instance = EpisodeService._internal();
  factory EpisodeService() => _instance;
  EpisodeService._internal();

  /// Get episode by ID
  Future<EpisodeResponse> getEpisode(int id) async {
    try {
      final response = await _client.get('${ApiConstants.episodes}/$id');
      return EpisodeResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeResponse(
        success: false,
        message: 'Erro ao carregar episodio',
      );
    }
  }

  /// Get episodes by series ID
  Future<EpisodeListResponse> getEpisodesBySeries(
    int seriesId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.series}/$seriesId/episodes',
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

  /// Record view for an episode
  Future<bool> recordView(int episodeId) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/view',
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle like for an episode
  Future<LikeResponse> toggleLike(int episodeId) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/like',
      );
      return LikeResponse.fromJson(response.data);
    } catch (e) {
      return LikeResponse(
        success: false,
        isLiked: false,
        likesCount: 0,
      );
    }
  }

  /// Update watch progress
  Future<bool> updateProgress(int episodeId, double progress) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/progress',
        data: {'progress': progress},
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Share episode
  Future<bool> recordShare(int episodeId) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/share',
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}

/// Like Response Model
class LikeResponse {
  final bool success;
  final bool isLiked;
  final int likesCount;
  final String? message;

  LikeResponse({
    required this.success,
    required this.isLiked,
    required this.likesCount,
    this.message,
  });

  factory LikeResponse.fromJson(Map<String, dynamic> json) {
    return LikeResponse(
      success: json['success'] as bool,
      isLiked: json['isLiked'] as bool? ?? false,
      likesCount: json['likesCount'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }
}
