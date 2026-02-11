import 'user_model.dart';
import 'series_model.dart';

/// Comment Model
class CommentModel {
  final int id;
  final int episodeId;
  final int userId;
  final int? parentId;
  final String content;
  final int likesCount;
  final int repliesCount;
  final bool isPinned;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final UserModel? user;
  final bool isLiked;
  final List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.episodeId,
    required this.userId,
    this.parentId,
    required this.content,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isPinned = false,
    this.isHidden = false,
    required this.createdAt,
    this.updatedAt,
    this.user,
    this.isLiked = false,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as int,
      episodeId: json['episodeId'] as int,
      userId: json['userId'] as int,
      parentId: json['parentId'] as int?,
      content: json['content'] as String,
      likesCount: json['likesCount'] as int? ?? 0,
      repliesCount: json['repliesCount'] as int? ??
          (json['_count'] != null ? (json['_count'] as Map<String, dynamic>)['replies'] as int? ?? 0 : 0),
      isPinned: json['isPinned'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      isLiked: json['isLiked'] as bool? ?? false,
      replies: (json['replies'] as List<dynamic>?)
          ?.map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'episodeId': episodeId,
      'userId': userId,
      'parentId': parentId,
      'content': content,
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'isPinned': isPinned,
    };
  }

  CommentModel copyWith({
    int? id,
    int? episodeId,
    int? userId,
    int? parentId,
    String? content,
    int? likesCount,
    int? repliesCount,
    bool? isPinned,
    bool? isHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserModel? user,
    bool? isLiked,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
    );
  }

  bool get isReply => parentId != null;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}a';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}m';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'agora';
    }
  }

  String get formattedLikes {
    if (likesCount >= 1000000) {
      return '${(likesCount / 1000000).toStringAsFixed(1)}M';
    } else if (likesCount >= 1000) {
      return '${(likesCount / 1000).toStringAsFixed(1)}K';
    }
    return likesCount.toString();
  }
}

/// Comment List Response
class CommentListResponse {
  final bool success;
  final List<CommentModel> data;
  final PaginationInfo? pagination;

  CommentListResponse({
    required this.success,
    required this.data,
    this.pagination,
  });

  factory CommentListResponse.fromJson(Map<String, dynamic> json) {
    return CommentListResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Comment Response
class CommentResponse {
  final bool success;
  final CommentModel? data;
  final String? message;

  CommentResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    return CommentResponse(
      success: json['success'] as bool,
      data: json['data'] != null
          ? CommentModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}
