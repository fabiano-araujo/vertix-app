import '../network/api_client.dart';
import '../constants/api_constants.dart';

/// Admin Service for VERTIX
/// Handles AI generation and admin operations
class AdminService {
  final ApiClient _client = ApiClient();

  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  /// Start AI series generation
  Future<GenerationResponse> generateSeries({
    required String theme,
    required String genre,
    required int episodeCount,
    int duration = 60,
    String? targetAudience,
    String? style,
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.adminGenerateSeries,
        data: {
          'theme': theme,
          'genre': genre,
          'episodeCount': episodeCount,
          'duration': duration,
          'targetAudience': targetAudience,
          'style': style,
        },
      );

      return GenerationResponse.fromJson(response.data);
    } catch (e) {
      return GenerationResponse(
        success: false,
        message: 'Erro ao iniciar geracao',
      );
    }
  }

  /// Get all generation jobs
  Future<JobListResponse> getJobs({int limit = 20, int offset = 0}) async {
    try {
      final response = await _client.get(
        ApiConstants.adminJobs,
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      return JobListResponse.fromJson(response.data);
    } catch (e) {
      return JobListResponse(
        success: false,
        data: [],
      );
    }
  }

  /// Get single job status
  Future<JobResponse> getJobStatus(int jobId) async {
    try {
      final response = await _client.get('${ApiConstants.adminJobs}/$jobId');
      return JobResponse.fromJson(response.data);
    } catch (e) {
      return JobResponse(
        success: false,
        message: 'Erro ao buscar status',
      );
    }
  }

  /// Get analytics
  Future<AnalyticsResponse> getAnalytics() async {
    try {
      final response = await _client.get(ApiConstants.adminAnalytics);
      return AnalyticsResponse.fromJson(response.data);
    } catch (e) {
      return AnalyticsResponse(success: false);
    }
  }
}

/// Generation Job Model
class GenerationJob {
  final int id;
  final int? seriesId;
  final String status;
  final String type;
  final Map<String, dynamic>? inputData;
  final Map<String, dynamic>? outputData;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  GenerationJob({
    required this.id,
    this.seriesId,
    required this.status,
    required this.type,
    this.inputData,
    this.outputData,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    return GenerationJob(
      id: json['id'] as int,
      seriesId: json['seriesId'] as int?,
      status: json['status'] as String,
      type: json['type'] as String,
      inputData: json['inputData'] as Map<String, dynamic>?,
      outputData: json['outputData'] as Map<String, dynamic>?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
  bool get isPending => status == 'PENDING';
  bool get isProcessing => status == 'PROCESSING';
}

/// Generation Response
class GenerationResponse {
  final bool success;
  final GenerationJob? job;
  final String? message;

  GenerationResponse({
    required this.success,
    this.job,
    this.message,
  });

  factory GenerationResponse.fromJson(Map<String, dynamic> json) {
    return GenerationResponse(
      success: json['success'] as bool,
      job: json['job'] != null
          ? GenerationJob.fromJson(json['job'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Job List Response
class JobListResponse {
  final bool success;
  final List<GenerationJob> data;

  JobListResponse({
    required this.success,
    required this.data,
  });

  factory JobListResponse.fromJson(Map<String, dynamic> json) {
    return JobListResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => GenerationJob.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Job Response
class JobResponse {
  final bool success;
  final GenerationJob? data;
  final String? message;

  JobResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory JobResponse.fromJson(Map<String, dynamic> json) {
    return JobResponse(
      success: json['success'] as bool,
      data: json['data'] != null
          ? GenerationJob.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Analytics Response
class AnalyticsResponse {
  final bool success;
  final int? totalSeries;
  final int? totalEpisodes;
  final int? totalUsers;
  final int? totalViews;
  final int? totalLikes;

  AnalyticsResponse({
    required this.success,
    this.totalSeries,
    this.totalEpisodes,
    this.totalUsers,
    this.totalViews,
    this.totalLikes,
  });

  factory AnalyticsResponse.fromJson(Map<String, dynamic> json) {
    return AnalyticsResponse(
      success: json['success'] as bool,
      totalSeries: json['totalSeries'] as int?,
      totalEpisodes: json['totalEpisodes'] as int?,
      totalUsers: json['totalUsers'] as int?,
      totalViews: json['totalViews'] as int?,
      totalLikes: json['totalLikes'] as int?,
    );
  }
}
