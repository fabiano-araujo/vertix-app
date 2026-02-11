import 'series_model.dart';

/// Episode Model
class EpisodeModel {
  final int id;
  final int seriesId;
  final int episodeNumber;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int duration;
  final int views;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final double completionRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SeriesModel? series;
  final bool isLiked;
  final double watchProgress;

  EpisodeModel({
    required this.id,
    required this.seriesId,
    required this.episodeNumber,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.duration,
    this.views = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.completionRate = 0,
    this.createdAt,
    this.updatedAt,
    this.series,
    this.isLiked = false,
    this.watchProgress = 0,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: json['id'] as int,
      seriesId: json['seriesId'] as int,
      episodeNumber: json['episodeNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] as int,
      views: json['views'] as int? ?? 0,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      series: json['series'] != null
          ? SeriesModel.fromJson(json['series'] as Map<String, dynamic>)
          : null,
      isLiked: json['isLiked'] as bool? ?? false,
      watchProgress: (json['watchProgress'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'views': views,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
    };
  }

  EpisodeModel copyWith({
    int? id,
    int? seriesId,
    int? episodeNumber,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    int? views,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    double? completionRate,
    SeriesModel? series,
    bool? isLiked,
    double? watchProgress,
  }) {
    return EpisodeModel(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      views: views ?? this.views,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      completionRate: completionRate ?? this.completionRate,
      series: series ?? this.series,
      isLiked: isLiked ?? this.isLiked,
      watchProgress: watchProgress ?? this.watchProgress,
    );
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String get formattedViews => _formatNumber(views);
  String get formattedLikes => _formatNumber(likesCount);
  String get formattedComments => _formatNumber(commentsCount);
  String get formattedShares => _formatNumber(sharesCount);

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Episode List Response
class EpisodeListResponse {
  final bool success;
  final List<EpisodeModel> data;
  final PaginationInfo? pagination;

  EpisodeListResponse({
    required this.success,
    required this.data,
    this.pagination,
  });

  factory EpisodeListResponse.fromJson(Map<String, dynamic> json) {
    return EpisodeListResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Single Episode Response
class EpisodeResponse {
  final bool success;
  final EpisodeModel? data;
  final String? message;

  EpisodeResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory EpisodeResponse.fromJson(Map<String, dynamic> json) {
    return EpisodeResponse(
      success: json['success'] as bool,
      data: json['data'] != null
          ? EpisodeModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}
