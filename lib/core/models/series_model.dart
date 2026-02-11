import 'user_model.dart';

/// Series Model
class SeriesModel {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String? thumbnailUrl;
  final String genre;
  final String? tags;
  final int totalEpisodes;
  final int? createdById;
  final double hypeScore;
  final double trendingScore;
  final String status;
  final bool isAiGenerated;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final UserModel? createdBy;
  final int? episodeCount;

  SeriesModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    this.thumbnailUrl,
    required this.genre,
    this.tags,
    this.totalEpisodes = 0,
    this.createdById,
    this.hypeScore = 0,
    this.trendingScore = 0,
    this.status = 'DRAFT',
    this.isAiGenerated = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.episodeCount,
  });

  factory SeriesModel.fromJson(Map<String, dynamic> json) {
    return SeriesModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      coverUrl: json['coverUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      genre: json['genre'] as String,
      tags: json['tags'] as String?,
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      createdById: json['createdById'] as int?,
      hypeScore: (json['hypeScore'] as num?)?.toDouble() ?? 0,
      trendingScore: (json['trendingScore'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'DRAFT',
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      createdBy: json['createdBy'] != null
          ? UserModel.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      episodeCount: json['_count'] != null
          ? (json['_count'] as Map<String, dynamic>)['episodes'] as int?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'thumbnailUrl': thumbnailUrl,
      'genre': genre,
      'tags': tags,
      'totalEpisodes': totalEpisodes,
      'createdById': createdById,
      'hypeScore': hypeScore,
      'trendingScore': trendingScore,
      'status': status,
      'isAiGenerated': isAiGenerated,
    };
  }

  List<String> get tagsList {
    if (tags == null || tags!.isEmpty) return [];
    try {
      return tags!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  int get totalEpisodesCount => episodeCount ?? totalEpisodes;
}

/// Series List Response
class SeriesListResponse {
  final bool success;
  final List<SeriesModel> data;
  final PaginationInfo? pagination;

  SeriesListResponse({
    required this.success,
    required this.data,
    this.pagination,
  });

  factory SeriesListResponse.fromJson(Map<String, dynamic> json) {
    return SeriesListResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => SeriesModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Single Series Response
class SeriesResponse {
  final bool success;
  final SeriesModel? data;
  final String? message;

  SeriesResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory SeriesResponse.fromJson(Map<String, dynamic> json) {
    return SeriesResponse(
      success: json['success'] as bool,
      data: json['data'] != null
          ? SeriesModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Pagination Info
class PaginationInfo {
  final int? total;
  final int limit;
  final int offset;
  final bool hasMore;

  PaginationInfo({
    this.total,
    required this.limit,
    required this.offset,
    this.hasMore = false,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] as int?,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
