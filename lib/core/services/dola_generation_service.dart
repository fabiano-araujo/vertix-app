import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

class DolaGenerationJob {
  final String id;
  final String status;
  final double progress;
  final String message;
  final int? profile;
  final String? creditProfile;
  final String? videoUrl;
  final String? error;

  const DolaGenerationJob({
    required this.id,
    required this.status,
    this.progress = 0,
    this.message = '',
    this.profile,
    this.creditProfile,
    this.videoUrl,
    this.error,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'queued' || status == 'running';

  factory DolaGenerationJob.fromJson(Map<String, dynamic> json) =>
      DolaGenerationJob(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'queued',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        message: json['message']?.toString() ?? '',
        profile: json['profile'] is num ? (json['profile'] as num).toInt() : null,
        creditProfile: json['creditProfile']?.toString(),
        videoUrl: json['videoUrl']?.toString(),
        error: json['error']?.toString(),
      );
}

class DolaProfileInventory {
  final String today;
  final String creditProfile;
  final int availableCount;
  final List<int> available;

  const DolaProfileInventory({
    required this.today,
    required this.creditProfile,
    required this.availableCount,
    required this.available,
  });

  factory DolaProfileInventory.fromJson(Map<String, dynamic> json) =>
      DolaProfileInventory(
        today: json['today']?.toString() ?? '',
        creditProfile: json['creditProfile']?.toString() ?? 'Pre-Writes',
        availableCount: json['availableCount'] as int? ?? 0,
        available: (json['available'] as List<dynamic>? ?? const [])
            .map((item) => (item as num).toInt())
            .toList(),
      );
}

class DolaGenerationService {
  DolaGenerationService._internal()
    : _client = Dio(
        BaseOptions(
          baseUrl: ApiConstants.dolaBaseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

  static final DolaGenerationService _instance =
      DolaGenerationService._internal();
  factory DolaGenerationService() => _instance;

  final Dio _client;

  Future<DolaProfileInventory> listProfiles() async {
    final response = await _client.get(ApiConstants.dolaProfiles);
    final payload = Map<String, dynamic>.from(response.data as Map);
    if (payload['success'] != true || payload['data'] is! Map) {
      throw StateError(
        payload['message']?.toString() ??
            'Não foi possível ler os perfis Dola disponíveis.',
      );
    }
    return DolaProfileInventory.fromJson(
      Map<String, dynamic>.from(payload['data'] as Map),
    );
  }

  Future<DolaGenerationJob> startJob({
    required String prompt,
    required String takeId,
    String? takeTitle,
    int durationSeconds = 10,
    String aspectRatio = '9:16',
    String model = 'Dreamina Seedance 2.5',
    String creditProfile = 'Pre-Writes',
    List<Map<String, dynamic>> references = const [],
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.dolaJobs,
        data: {
          'prompt': prompt,
          'takeId': takeId,
          if (takeTitle != null) 'takeTitle': takeTitle,
          'durationSeconds': durationSeconds,
          'aspectRatio': aspectRatio,
          'model': model,
          'creditProfile': creditProfile,
          'references': references,
        },
      );
      return _jobFromResponse(response.data);
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<DolaGenerationJob> getJob(String jobId) async {
    try {
      final response = await _client.get('${ApiConstants.dolaJobs}/$jobId');
      return _jobFromResponse(response.data);
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<DolaGenerationJob> waitForJob(
    String jobId, {
    Duration timeout = const Duration(minutes: 18),
    Duration pollInterval = const Duration(seconds: 2),
    void Function(DolaGenerationJob job)? onProgress,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final job = await getJob(jobId);
      onProgress?.call(job);
      if (job.isCompleted) return job;
      if (job.isFailed) {
        throw StateError(job.error ?? job.message);
      }
      await Future<void>.delayed(pollInterval);
    }
    throw StateError('A geração Dola ainda não terminou.');
  }

  DolaGenerationJob _jobFromResponse(dynamic data) {
    final payload = Map<String, dynamic>.from(data as Map);
    if (payload['success'] != true || payload['data'] is! Map) {
      throw StateError(
        payload['message']?.toString() ?? 'O gerador Dola recusou o pedido.',
      );
    }
    return DolaGenerationJob.fromJson(
      Map<String, dynamic>.from(payload['data'] as Map),
    );
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'O gerador Dola local não está no ar. Rode yarn dola:serve na pasta server/.';
    }
    return error.message ?? 'Falha ao falar com o gerador Dola.';
  }
}
