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
  final bool isLocked;
  final bool isUnlocked;
  final int unlockCost;
  final int? freeEpisodeCount;
  final int? paywallEpisode;
  final bool hasSubscriptionAccess;

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
    this.isLocked = false,
    this.isUnlocked = true,
    this.unlockCost = 1,
    this.freeEpisodeCount,
    this.paywallEpisode,
    this.hasSubscriptionAccess = false,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    final nested = json['episode'];
    final source = nested is Map<String, dynamic>
        ? Map<String, dynamic>.from(nested)
        : json;
    final seriesRaw = source['series'] ?? json['series'];
    final series = seriesRaw is Map<String, dynamic>
        ? SeriesModel.fromJson(seriesRaw)
        : null;
    final seriesId =
        source['seriesId'] as int? ??
        json['seriesId'] as int? ??
        series?.id ??
        0;
    final progress =
        json['progress'] ?? json['watchProgress'] ?? source['watchProgress'];

    return EpisodeModel(
      id: source['id'] as int,
      seriesId: seriesId,
      episodeNumber: source['episodeNumber'] as int? ?? 0,
      title: source['title'] as String? ?? '',
      description: source['description'] as String?,
      videoUrl: source['videoUrl'] as String? ?? '',
      thumbnailUrl: source['thumbnailUrl'] as String? ?? series?.coverUrl,
      duration: source['duration'] as int? ?? 0,
      views: source['views'] as int? ?? 0,
      likesCount: source['likesCount'] as int? ?? 0,
      commentsCount: source['commentsCount'] as int? ?? 0,
      sharesCount: source['sharesCount'] as int? ?? 0,
      completionRate: (source['completionRate'] as num?)?.toDouble() ?? 0,
      createdAt: source['createdAt'] != null
          ? DateTime.parse(source['createdAt'] as String)
          : null,
      updatedAt: source['updatedAt'] != null
          ? DateTime.parse(source['updatedAt'] as String)
          : null,
      series: series,
      isLiked: source['isLiked'] as bool? ?? json['isLiked'] as bool? ?? false,
      watchProgress: (progress as num?)?.toDouble() ?? 0,
      isLocked: source['isLocked'] as bool? ?? json['isLocked'] as bool? ?? false,
      isUnlocked: source['isUnlocked'] as bool? ?? json['isUnlocked'] as bool? ?? true,
      unlockCost: source['unlockCost'] as int? ?? json['unlockCost'] as int? ?? 1,
      freeEpisodeCount: source['freeEpisodeCount'] as int? ?? json['freeEpisodeCount'] as int?,
      paywallEpisode: source['paywallEpisode'] as int? ?? json['paywallEpisode'] as int?,
      hasSubscriptionAccess:
          source['hasSubscriptionAccess'] as bool? ??
          json['hasSubscriptionAccess'] as bool? ??
          false,
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
    bool? isLocked,
    bool? isUnlocked,
    int? unlockCost,
    int? freeEpisodeCount,
    int? paywallEpisode,
    bool? hasSubscriptionAccess,
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
      isLocked: isLocked ?? this.isLocked,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockCost: unlockCost ?? this.unlockCost,
      freeEpisodeCount: freeEpisodeCount ?? this.freeEpisodeCount,
      paywallEpisode: paywallEpisode ?? this.paywallEpisode,
      hasSubscriptionAccess:
          hasSubscriptionAccess ?? this.hasSubscriptionAccess,
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

  bool get isInProgress => watchProgress > 0.05 && watchProgress < 0.9;

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
