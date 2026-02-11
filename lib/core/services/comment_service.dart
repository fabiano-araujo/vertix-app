import '../network/api_client.dart';
import '../constants/api_constants.dart';
import '../models/comment_model.dart';

/// Comment Service for VERTIX
class CommentService {
  final ApiClient _client = ApiClient();

  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  /// Get comments for an episode
  Future<CommentListResponse> getComments(
    int episodeId, {
    int limit = 20,
    int offset = 0,
    String sortBy = 'recent',
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.episodes}/$episodeId/comments',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          'sortBy': sortBy,
        },
      );
      return CommentListResponse.fromJson(response.data);
    } catch (e) {
      return CommentListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get replies for a comment
  Future<CommentListResponse> getReplies(
    int commentId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.comments}/$commentId/replies',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return CommentListResponse.fromJson(response.data);
    } catch (e) {
      return CommentListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Create a comment on an episode
  Future<CommentResponse> createComment(int episodeId, String content) async {
    try {
      final response = await _client.post(
        '${ApiConstants.episodes}/$episodeId/comments',
        data: {'content': content},
      );
      return CommentResponse.fromJson(response.data);
    } catch (e) {
      return CommentResponse(
        success: false,
        message: 'Erro ao criar comentario',
      );
    }
  }

  /// Reply to a comment
  Future<CommentResponse> replyToComment(int commentId, String content) async {
    try {
      final response = await _client.post(
        '${ApiConstants.comments}/$commentId/reply',
        data: {'content': content},
      );
      return CommentResponse.fromJson(response.data);
    } catch (e) {
      return CommentResponse(
        success: false,
        message: 'Erro ao responder comentario',
      );
    }
  }

  /// Toggle like on a comment
  Future<CommentLikeResponse> toggleLike(int commentId) async {
    try {
      final response = await _client.post(
        '${ApiConstants.comments}/$commentId/like',
      );
      return CommentLikeResponse.fromJson(response.data);
    } catch (e) {
      return CommentLikeResponse(
        success: false,
        isLiked: false,
        likesCount: 0,
      );
    }
  }

  /// Delete a comment (only own comments)
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await _client.delete(
        '${ApiConstants.comments}/$commentId',
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Report a comment
  Future<bool> reportComment(int commentId, String reason) async {
    try {
      final response = await _client.post(
        '${ApiConstants.comments}/$commentId/report',
        data: {'reason': reason},
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}

/// Comment Like Response
class CommentLikeResponse {
  final bool success;
  final bool isLiked;
  final int likesCount;

  CommentLikeResponse({
    required this.success,
    required this.isLiked,
    required this.likesCount,
  });

  factory CommentLikeResponse.fromJson(Map<String, dynamic> json) {
    return CommentLikeResponse(
      success: json['success'] as bool,
      isLiked: json['isLiked'] as bool? ?? false,
      likesCount: json['likesCount'] as int? ?? 0,
    );
  }
}
