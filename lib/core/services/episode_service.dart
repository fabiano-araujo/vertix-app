import 'package:dio/dio.dart';
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
    int limit = 80,
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

  Future<bool> recordRetention({
    required int episodeId,
    required String event,
    int positionSeconds = 0,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/retention',
        data: {
          'event': event,
          'positionSeconds': positionSeconds,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<UnlockEpisodeResponse> unlockEpisode(int episodeId) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/unlock',
      );
      final data = response.data['data'] is Map<String, dynamic>
          ? response.data['data'] as Map<String, dynamic>
          : null;
      return UnlockEpisodeResponse(
        success: response.data['success'] == true,
        message: response.data['message'] as String?,
        reason: response.data['reason'] as String?,
        episode: data != null ? EpisodeModel.fromJson(data) : null,
        availableCredits: data?['availableCredits'] as int? ?? 0,
      );
    } catch (e) {
      String? message;
      String? reason;
      int credits = 0;
      if (e is DioException && e.response?.data is Map) {
        final body = e.response!.data as Map;
        message = body['message'] as String?;
        reason = body['reason'] as String?;
        final data = body['data'];
        if (data is Map) {
          credits = data['availableCredits'] as int? ?? 0;
        }
      }
      return UnlockEpisodeResponse(
        success: false,
        message: message ?? 'Erro ao desbloquear episodio',
        reason: reason,
        availableCredits: credits,
      );
    }
  }

  /// Next episode in the same series
  Future<EpisodeResponse> getNextEpisode(int episodeId) async {
    try {
      final response = await _client.get(
        '${ApiConstants.episodes}/$episodeId/next',
      );
      return EpisodeResponse.fromJson(response.data);
    } catch (e) {
      return EpisodeResponse(
        success: false,
        message: 'Erro ao carregar proximo episodio',
      );
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

class UnlockEpisodeResponse {
  final bool success;
  final EpisodeModel? episode;
  final int availableCredits;
  final String? message;
  final String? reason;

  UnlockEpisodeResponse({
    required this.success,
    this.episode,
    this.availableCredits = 0,
    this.message,
    this.reason,
  });
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
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return LikeResponse(
      success: json['success'] as bool? ?? false,
      isLiked: data['isLiked'] as bool? ?? json['isLiked'] as bool? ?? false,
      likesCount: data['likesCount'] as int? ?? json['likesCount'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }
}
