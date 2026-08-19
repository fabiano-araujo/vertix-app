import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/api_client.dart';
import '../constants/api_constants.dart';

bool _readAdminBool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'sim':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'nao':
        return false;
    }
  }
  return fallback;
}

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

  Future<Map<String, dynamic>> createSeries({
    required String title,
    String? description,
    String? genre,
    int totalEpisodes = 0,
    String status = 'DRAFT',
  }) async {
    final response = await _client.post(
      ApiConstants.adminCreateSeries,
      data: {
        'title': title,
        if (description != null) 'description': description,
        if (genre != null) 'genre': genre,
        'totalEpisodes': totalEpisodes,
        'status': status,
        'isAiGenerated': true,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateSeries({
    required int seriesId,
    required String title,
    String? description,
    String? genre,
    String? status,
    String? coverUrl,
  }) async {
    final response = await _client.put(
      '${ApiConstants.series}/$seriesId',
      data: {
        'title': title,
        if (description != null) 'description': description,
        if (genre != null) 'genre': genre,
        if (status != null) 'status': status,
        if (coverUrl != null) 'coverUrl': coverUrl,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveSeriesProduction({
    required int seriesId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      '${ApiConstants.admin}/series/$seriesId/production',
      data: payload,
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> ingestSeriesReference({
    required int seriesId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      '${ApiConstants.admin}/series/$seriesId/references',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get all series available to admins, including drafts.
  Future<AdminSeriesListResponse> getAvailableSeries({
    int limit = 50,
    int offset = 0,
    String status = 'ALL',
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'status': status,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      final response = await _client.get(
        ApiConstants.adminAvailableSeries,
        queryParameters: queryParameters,
      );

      return AdminSeriesListResponse.fromJson(response.data);
    } catch (e) {
      return AdminSeriesListResponse(success: false, data: []);
    }
  }

  /// Get all generation jobs
  Future<JobListResponse> getJobs({int limit = 20, int offset = 0}) async {
    try {
      final response = await _client.get(
        ApiConstants.adminJobs,
        queryParameters: {'limit': limit, 'offset': offset},
      );

      return JobListResponse.fromJson(response.data);
    } catch (e) {
      return JobListResponse(success: false, data: []);
    }
  }

  /// Get single job status
  Future<JobResponse> getJobStatus(int jobId) async {
    try {
      final response = await _client.get('${ApiConstants.adminJobs}/$jobId');
      return JobResponse.fromJson(response.data);
    } on DioException catch (error) {
      return JobResponse(success: false, message: _apiErrorMessage(error));
    } catch (error) {
      return JobResponse(success: false, message: error.toString());
    }
  }

  /// Send an authenticated project action to the server-side story model (OpenRouter).
  Future<GenerationJob> startCodexWorkflow({
    required String action,
    required Map<String, dynamic> project,
    int? episodeNumber,
    int? fromEpisode,
    int? batchSize,
    String? instruction,
    String? codexThreadId,
  }) async {
    if (!await _client.isAuthenticated()) {
      throw StateError('Faça login para usar a geração com IA.');
    }
    try {
      final response = await _client.post(
        ApiConstants.adminCodexJobs,
        data: {
          'action': action,
          'project': project,
          if (episodeNumber != null) 'episodeNumber': episodeNumber,
          if (fromEpisode != null) 'fromEpisode': fromEpisode,
          if (batchSize != null) 'batchSize': batchSize,
          if (instruction?.trim().isNotEmpty == true)
            'instruction': instruction!.trim(),
          if (codexThreadId?.trim().isNotEmpty == true)
            'codexThreadId': codexThreadId!.trim(),
        },
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (payload['success'] != true || payload['data'] is! Map) {
        throw StateError(
          payload['message']?.toString() ?? 'A ação não foi aceita pela IA.',
        );
      }
      return GenerationJob.fromJson(
        Map<String, dynamic>.from(payload['data'] as Map),
      );
    } on DioException catch (error) {
      throw StateError(_apiErrorMessage(error));
    }
  }

  /// Create a capability-scoped image job to be processed by a local Codex task.
  Future<ReferenceImageJobLaunch> startReferenceImageJob({
    required int seriesId,
    required List<Map<String, dynamic>> references,
  }) async {
    if (!await _client.isAuthenticated()) {
      throw StateError('Faça login para gerar referências com o Codex.');
    }
    try {
      final response = await _client.post(
        '${ApiConstants.admin}/series/$seriesId/reference-image-jobs',
        data: {'references': references},
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (payload['success'] != true || payload['data'] is! Map) {
        throw StateError(
          payload['message']?.toString() ??
              'O job de imagens não foi aceito pela API.',
        );
      }
      return ReferenceImageJobLaunch.fromJson(
        Map<String, dynamic>.from(payload['data'] as Map),
      );
    } on DioException catch (error) {
      throw StateError(_apiErrorMessage(error));
    }
  }

  /// Poll a queued story-generation job until it reaches a terminal state.
  ///
  /// A season of 50 outline cards can keep a job busy for far longer than 20
  /// minutes. We only abort when the job stops reporting progress, or after
  /// the hard ceiling.
  Future<GenerationJob> waitForGenerationJob(
    int jobId, {
    Duration timeout = const Duration(hours: 3),
    Duration stallTimeout = const Duration(minutes: 40),
    Duration pollInterval = const Duration(milliseconds: 1400),
    void Function(GenerationJob job)? onProgress,
    bool Function()? isCancelled,
    Future<void>? cancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var lastChange = DateTime.now();
    var lastFingerprint = '';
    GenerationJob? latest;
    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled?.call() == true) {
        throw const GenerationCancelledException();
      }
      final response = await getJobStatus(jobId);
      final job = response.data;
      if (!response.success || job == null) {
        throw StateError(
          response.message ?? 'Não foi possível consultar o job.',
        );
      }
      latest = job;
      onProgress?.call(job);
      if (job.isCancelled || isCancelled?.call() == true) {
        throw const GenerationCancelledException();
      }
      if (job.isCompleted) return job;
      if (job.isFailed) {
        throw StateError(job.errorMessage ?? 'A geração falhou no servidor.');
      }
      final fingerprint =
          '${job.status}|${job.progress}|${job.outputData?['message']}|${job.outputData?['conversation']?.toString().length ?? 0}';
      if (fingerprint != lastFingerprint) {
        lastFingerprint = fingerprint;
        lastChange = DateTime.now();
      } else if (DateTime.now().difference(lastChange) > stallTimeout) {
        throw GenerationJobTimeoutException(jobId, lastJob: job);
      }
      final delay = Future<void>.delayed(pollInterval);
      if (cancelled == null) {
        await delay;
      } else {
        await Future.any<void>([delay, cancelled]);
      }
    }
    throw GenerationJobTimeoutException(jobId, lastJob: latest);
  }

  /// Stop a pending or processing generation job.
  Future<void> cancelJob(int jobId) async {
    if (!await _client.isAuthenticated()) {
      throw StateError('Faça login para cancelar a geração.');
    }
    try {
      await _client.delete('${ApiConstants.adminJobs}/$jobId');
    } on DioException catch (error) {
      throw StateError(_apiErrorMessage(error));
    }
  }

  String _apiErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.response?.statusCode == 401) {
      return 'Sua sessão expirou. Faça login novamente.';
    }
    if (error.response?.statusCode == 403) {
      return 'Essa geração exige uma conta administradora.';
    }
    return error.message ?? 'Falha de comunicação com o servidor.';
  }

  /// Get full production data for an admin series.
  Future<AdminSeriesProductionResponse> getSeriesProduction(
    int seriesId,
  ) async {
    try {
      final response = await _client.get(
        '${ApiConstants.admin}/series/$seriesId/production',
      );
      return AdminSeriesProductionResponse.fromJson(response.data);
    } catch (e) {
      return AdminSeriesProductionResponse(
        success: false,
        message: 'Dados de producao nao encontrados',
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

Map<String, dynamic>? _jsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

/// Admin-facing Series summary with production counts.
class AdminSeriesSummary {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String? thumbnailUrl;
  final String genre;
  final String status;
  final bool isAiGenerated;
  final int totalEpisodes;
  final int episodeCount;
  final int referenceCount;
  final int storyPointCount;
  final DateTime? updatedAt;
  final AdminProductionPlanSummary? productionPlan;

  AdminSeriesSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    this.thumbnailUrl,
    required this.genre,
    required this.status,
    required this.isAiGenerated,
    required this.totalEpisodes,
    required this.episodeCount,
    required this.referenceCount,
    required this.storyPointCount,
    this.updatedAt,
    this.productionPlan,
  });

  factory AdminSeriesSummary.fromJson(Map<String, dynamic> json) {
    final count = _jsonMap(json['_count']) ?? {};
    return AdminSeriesSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Serie',
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      genre: json['genre'] as String? ?? 'N/A',
      status: json['status'] as String? ?? 'DRAFT',
      isAiGenerated: _readAdminBool(json['isAiGenerated'], fallback: false),
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      episodeCount: count['episodes'] as int? ?? 0,
      referenceCount: count['referenceAssets'] as int? ?? 0,
      storyPointCount: count['storyPoints'] as int? ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      productionPlan: json['productionPlan'] != null
          ? AdminProductionPlanSummary.fromJson(
              json['productionPlan'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  bool get hasProductionPlan => productionPlan != null;
}

class AdminProductionPlanSummary {
  final int id;
  final String source;
  final DateTime? updatedAt;

  AdminProductionPlanSummary({
    required this.id,
    required this.source,
    this.updatedAt,
  });

  factory AdminProductionPlanSummary.fromJson(Map<String, dynamic> json) {
    return AdminProductionPlanSummary(
      id: json['id'] as int,
      source: json['source'] as String? ?? 'seedance-series-pipeline',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

class AdminSeriesListResponse {
  final bool success;
  final List<AdminSeriesSummary> data;

  AdminSeriesListResponse({required this.success, required this.data});

  factory AdminSeriesListResponse.fromJson(Map<String, dynamic> json) {
    return AdminSeriesListResponse(
      success: _readAdminBool(json['success'], fallback: false),
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (e) => AdminSeriesSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class AdminSeriesProductionResponse {
  final bool success;
  final AdminSeriesProductionPlan? data;
  final String? message;

  AdminSeriesProductionResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory AdminSeriesProductionResponse.fromJson(Map<String, dynamic> json) {
    return AdminSeriesProductionResponse(
      success: _readAdminBool(json['success'], fallback: false),
      data: json['data'] != null
          ? AdminSeriesProductionPlan.fromJson(
              json['data'] as Map<String, dynamic>,
            )
          : null,
      message: json['message'] as String?,
    );
  }
}

class AdminSeriesProductionPlan {
  final int id;
  final int seriesId;
  final String source;
  final dynamic seriesBible;
  final dynamic characterBible;
  final dynamic locationBible;
  final dynamic objectBible;
  final dynamic spatialMaps;
  final dynamic audioBible;
  final dynamic seasonArc;
  final dynamic episodeMap;
  final dynamic episodeTreatments;
  final dynamic sceneCards;
  final dynamic storyboardPlan;
  final dynamic generationPlan;
  final dynamic seedanceNotes;
  final dynamic rawPayload;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<AdminReferenceAsset> referenceAssets;
  final List<AdminStoryPoint> storyPoints;

  AdminSeriesProductionPlan({
    required this.id,
    required this.seriesId,
    required this.source,
    this.seriesBible,
    this.characterBible,
    this.locationBible,
    this.objectBible,
    this.spatialMaps,
    this.audioBible,
    this.seasonArc,
    this.episodeMap,
    this.episodeTreatments,
    this.sceneCards,
    this.storyboardPlan,
    this.generationPlan,
    this.seedanceNotes,
    this.rawPayload,
    this.createdAt,
    this.updatedAt,
    required this.referenceAssets,
    required this.storyPoints,
  });

  factory AdminSeriesProductionPlan.fromJson(Map<String, dynamic> json) {
    return AdminSeriesProductionPlan(
      id: json['id'] as int,
      seriesId: json['seriesId'] as int,
      source: json['source'] as String? ?? 'seedance-series-pipeline',
      seriesBible: json['seriesBible'],
      characterBible: json['characterBible'],
      locationBible: json['locationBible'],
      objectBible: json['objectBible'],
      spatialMaps: json['spatialMaps'],
      audioBible: json['audioBible'],
      seasonArc: json['seasonArc'],
      episodeMap: json['episodeMap'],
      episodeTreatments: json['episodeTreatments'],
      sceneCards: json['sceneCards'],
      storyboardPlan: json['storyboardPlan'],
      generationPlan: json['generationPlan'],
      seedanceNotes: json['seedanceNotes'],
      rawPayload: json['rawPayload'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      referenceAssets:
          (json['referenceAssets'] as List<dynamic>?)
              ?.map(
                (item) =>
                    AdminReferenceAsset.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      storyPoints:
          (json['storyPoints'] as List<dynamic>?)
              ?.map(
                (item) =>
                    AdminStoryPoint.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'source': source,
      'seriesBible': seriesBible,
      'characterBible': characterBible,
      'locationBible': locationBible,
      'objectBible': objectBible,
      'spatialMaps': spatialMaps,
      'audioBible': audioBible,
      'seasonArc': seasonArc,
      'episodeMap': episodeMap,
      'episodeTreatments': episodeTreatments,
      'sceneCards': sceneCards,
      'storyboardPlan': storyboardPlan,
      'generationPlan': generationPlan,
      'seedanceNotes': seedanceNotes,
      'rawPayload': rawPayload,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'referenceAssets': referenceAssets.map((item) => item.toJson()).toList(),
      'storyPoints': storyPoints.map((item) => item.toJson()).toList(),
    };
  }
}

class AdminReferenceAsset {
  final int id;
  final int seriesId;
  final int? episodeId;
  final int? productionPlanId;
  final String category;
  final String label;
  final String? sourceUrl;
  final String storageKey;
  final String publicUrl;
  final String? contentType;
  final int? sizeBytes;
  final dynamic prompt;
  final dynamic metadata;
  final DateTime? createdAt;

  AdminReferenceAsset({
    required this.id,
    required this.seriesId,
    this.episodeId,
    this.productionPlanId,
    required this.category,
    required this.label,
    this.sourceUrl,
    required this.storageKey,
    required this.publicUrl,
    this.contentType,
    this.sizeBytes,
    this.prompt,
    this.metadata,
    this.createdAt,
  });

  factory AdminReferenceAsset.fromJson(Map<String, dynamic> json) {
    return AdminReferenceAsset(
      id: json['id'] as int,
      seriesId: json['seriesId'] as int,
      episodeId: json['episodeId'] as int?,
      productionPlanId: json['productionPlanId'] as int?,
      category: json['category'] as String? ?? 'REFERENCE',
      label: json['label'] as String? ?? 'Referencia',
      sourceUrl: json['sourceUrl'] as String?,
      storageKey: json['storageKey'] as String? ?? '',
      publicUrl: json['publicUrl'] as String? ?? '',
      contentType: json['contentType'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
      prompt: json['prompt'],
      metadata: json['metadata'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  bool get isImage {
    final type = contentType?.toLowerCase() ?? '';
    final url = publicUrl.toLowerCase();
    return type.startsWith('image/') ||
        url.endsWith('.png') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.webp') ||
        url.endsWith('.gif');
  }

  bool get isVideo {
    final type = contentType?.toLowerCase() ?? '';
    final url = publicUrl.toLowerCase();
    return type.startsWith('video/') ||
        url.endsWith('.mp4') ||
        url.endsWith('.webm');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'episodeId': episodeId,
      'productionPlanId': productionPlanId,
      'category': category,
      'label': label,
      'sourceUrl': sourceUrl,
      'storageKey': storageKey,
      'publicUrl': publicUrl,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'prompt': prompt,
      'metadata': metadata,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class AdminStoryPoint {
  final int id;
  final int seriesId;
  final int? episodeId;
  final int? productionPlanId;
  final String pointType;
  final String title;
  final dynamic body;
  final int? episodeNumber;
  final int? sceneNumber;
  final String? segment;
  final int orderIndex;
  final dynamic metadata;
  final DateTime? createdAt;

  AdminStoryPoint({
    required this.id,
    required this.seriesId,
    this.episodeId,
    this.productionPlanId,
    required this.pointType,
    required this.title,
    this.body,
    this.episodeNumber,
    this.sceneNumber,
    this.segment,
    required this.orderIndex,
    this.metadata,
    this.createdAt,
  });

  factory AdminStoryPoint.fromJson(Map<String, dynamic> json) {
    return AdminStoryPoint(
      id: json['id'] as int,
      seriesId: json['seriesId'] as int,
      episodeId: json['episodeId'] as int?,
      productionPlanId: json['productionPlanId'] as int?,
      pointType: json['pointType'] as String? ?? 'PIPELINE_POINT',
      title: json['title'] as String? ?? 'Ponto',
      body: json['body'],
      episodeNumber: json['episodeNumber'] as int?,
      sceneNumber: json['sceneNumber'] as int?,
      segment: json['segment'] as String?,
      orderIndex: json['orderIndex'] as int? ?? 0,
      metadata: json['metadata'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  bool get isPrompt => pointType == 'SEEDANCE_PROMPT';
  bool get isTake =>
      pointType == 'GENERATION_SEGMENT' || pointType == 'SCENE_CARD';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'episodeId': episodeId,
      'productionPlanId': productionPlanId,
      'pointType': pointType,
      'title': title,
      'body': body,
      'episodeNumber': episodeNumber,
      'sceneNumber': sceneNumber,
      'segment': segment,
      'orderIndex': orderIndex,
      'metadata': metadata,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

/// Generation Job Model
class GenerationJob {
  final int id;
  final int? seriesId;
  final String status;
  final String type;
  final int progress;
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
    this.progress = 0,
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
      progress: json['progress'] as int? ?? 0,
      inputData: _jsonMap(json['inputData']),
      outputData: _jsonMap(json['outputData']),
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
  bool get isActive => isPending || isProcessing;
  bool get isCancelled {
    if (!isFailed) return false;
    final message = (errorMessage ?? '').toLowerCase();
    return message.contains('cancelled by user') ||
        message.contains('cancelada pelo');
  }
}

class GenerationCancelledException implements Exception {
  const GenerationCancelledException();

  @override
  String toString() => 'Geração cancelada.';
}

class GenerationJobTimeoutException extends TimeoutException {
  GenerationJobTimeoutException(this.jobId, {this.lastJob})
    : super('A geração ainda não terminou. Consulte o job $jobId.');

  final int jobId;
  final GenerationJob? lastJob;
}

class ReferenceImageJobLaunch {
  final GenerationJob job;
  final String capabilityToken;
  final DateTime capabilityExpiresAt;

  const ReferenceImageJobLaunch({
    required this.job,
    required this.capabilityToken,
    required this.capabilityExpiresAt,
  });

  factory ReferenceImageJobLaunch.fromJson(Map<String, dynamic> json) {
    final token = json['capabilityToken']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(
      json['capabilityExpiresAt']?.toString() ?? '',
    );
    if (token.isEmpty || expiresAt == null) {
      throw const FormatException('Credencial do job de imagens inválida.');
    }
    return ReferenceImageJobLaunch(
      job: GenerationJob.fromJson(json),
      capabilityToken: token,
      capabilityExpiresAt: expiresAt,
    );
  }
}

/// Generation Response
class GenerationResponse {
  final bool success;
  final GenerationJob? job;
  final String? message;

  GenerationResponse({required this.success, this.job, this.message});

  factory GenerationResponse.fromJson(Map<String, dynamic> json) {
    final jobJson = json['job'] ?? json['data'];
    return GenerationResponse(
      success: _readAdminBool(json['success'], fallback: false),
      job: jobJson is Map<String, dynamic> && jobJson.containsKey('id')
          ? GenerationJob.fromJson(jobJson)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Job List Response
class JobListResponse {
  final bool success;
  final List<GenerationJob> data;

  JobListResponse({required this.success, required this.data});

  factory JobListResponse.fromJson(Map<String, dynamic> json) {
    return JobListResponse(
      success: _readAdminBool(json['success'], fallback: false),
      data:
          (json['data'] as List<dynamic>?)
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

  JobResponse({required this.success, this.data, this.message});

  factory JobResponse.fromJson(Map<String, dynamic> json) {
    return JobResponse(
      success: _readAdminBool(json['success'], fallback: false),
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
      success: _readAdminBool(json['success'], fallback: false),
      totalSeries: json['totalSeries'] as int?,
      totalEpisodes: json['totalEpisodes'] as int?,
      totalUsers: json['totalUsers'] as int?,
      totalViews: json['totalViews'] as int?,
      totalLikes: json['totalLikes'] as int?,
    );
  }
}
