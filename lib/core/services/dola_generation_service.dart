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
  bool get isCancelled => status == 'cancelled';
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

  Future<DolaProfileInventory?> tryListProfiles() async {
    try {
      return await listProfiles();
    } catch (_) {
      return null;
    }
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
    List<int> profiles = const [],
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
          'profiles': profiles,
        },
      );
      return _jobFromResponse(response.data);
    } on DioException catch (error) {
      throw DolaGenerationException(_errorMessage(error));
    }
  }

  Future<DolaGenerationJob> getJob(String jobId) async {
    try {
      final response = await _client.get('${ApiConstants.dolaJobs}/$jobId');
      return _jobFromResponse(response.data);
    } on DioException catch (error) {
      throw DolaGenerationException(_errorMessage(error));
    }
  }

  Future<void> cancelJob(String jobId) async {
    try {
      await _client.post('${ApiConstants.dolaJobs}/$jobId/cancel');
    } on DioException catch (error) {
      throw DolaGenerationException(_errorMessage(error));
    }
  }

  Future<DolaGenerationJob> waitForJob(
    String jobId, {
    Duration timeout = const Duration(minutes: 18),
    Duration pollInterval = const Duration(seconds: 2),
    void Function(DolaGenerationJob job)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled?.call() == true) {
        throw const DolaCancelledException();
      }
      final job = await getJob(jobId);
      if (isCancelled?.call() == true || job.isCancelled) {
        throw const DolaCancelledException();
      }
      onProgress?.call(job);
      if (job.isCompleted) return job;
      if (job.isFailed) {
        throw DolaGenerationException(
          describeDolaError(job.error ?? job.message),
        );
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const DolaGenerationException(
      'O Dola estourou o tempo de espera. Tente gerar de novo.',
    );
  }

  DolaGenerationJob _jobFromResponse(dynamic data) {
    final payload = Map<String, dynamic>.from(data as Map);
    if (payload['success'] != true || payload['data'] is! Map) {
      throw DolaGenerationException(
        describeDolaError(
          payload['message']?.toString() ?? 'O gerador Dola recusou o pedido.',
        ),
      );
    }
    return DolaGenerationJob.fromJson(
      Map<String, dynamic>.from(payload['data'] as Map),
    );
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return describeDolaError(data['message'].toString());
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível falar com o Playwright local. O clique precisa abrir o gerador em 127.0.0.1:3847.';
    }
    return describeDolaError(
      error.message ?? 'Falha ao falar com o gerador Dola.',
    );
  }
}

String describeDolaError(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return 'Falha ao gerar no Dola.';
  final providerSentence = _extractProviderSentence(text);
  if (providerSentence != null) return providerSentence;
  if (RegExp(r'interrompida|cancelled by user', caseSensitive: false)
      .hasMatch(text)) {
    return 'Geração interrompida.';
  }
  if (RegExp(r'DOLA_DAILY_LIMIT|daily_limit', caseSensitive: false)
      .hasMatch(text)) {
    return 'Este perfil Dola já usou o crédito de hoje. Tente gerar de novo para usar outro perfil.';
  }
  if (RegExp(r'DOLA_HIGH_DEMAND|high_demand', caseSensitive: false)
      .hasMatch(text)) {
    return 'O Dola está com alta demanda. Espere alguns minutos e tente de novo.';
  }
  if (RegExp(
    r'DOLA_AUTH_LOST|authentication_lost|AUTH_LOST',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'A sessão do Dola expirou neste perfil. Faça login de novo e tente gerar outra vez.';
  }
  if (RegExp(
    r'DOLA_REJECTED_NO_POINT|rejected_before_consumption|REJECTED_NO_POINT',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'O Dola recusou a cena antes de gastar crédito. Revise o prompt e as referências.';
  }
  if (RegExp(
    r'DOLA_DURATION_CLARIFICATION|duration_clarification',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'O Dola pediu para confirmar a duração. Gere de novo com 5s ou 10s.';
  }
  if (RegExp(
    r'DOLA_TERMINAL_REJECTION|terminal_rejection',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'O Dola recusou a cena por direitos de imagem, copyright ou áudio. Ajuste as referências ou o prompt.';
  }
  if (RegExp(
    r'DOLA_UNRECOGNIZED_RESPONSE|unrecognized_provider_response',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'O Dola não confirmou a geração. Tente de novo.';
  }
  if (RegExp(
    r'DOLA_CONFIRMATION_UNRESOLVED|confirmation_unresolved',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'O Dola não iniciou a geração depois da confirmação. Tente de novo.';
  }
  if (RegExp(r'DOLA_TIMEOUT|Timed out after', caseSensitive: false)
      .hasMatch(text)) {
    return 'O Dola estourou o tempo de espera. Tente gerar de novo.';
  }
  if (RegExp(
    r'ECONNREFUSED|não está no ar',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'O Playwright local não está no ar. Clique em Gerar de novo para abrir o Chrome neste PC.';
  }
  final cleaned = text
      .replaceFirst(RegExp(r'^Bad state:\s*'), '')
      .replaceFirst(RegExp(r'^profile-\d+:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^DOLA_[A-Z0-9_]+:\s*'), '')
      .trim();
  if (cleaned.isEmpty || _looksLikeJsonBlob(cleaned)) {
    return 'Falha ao gerar no Dola.';
  }
  return cleaned;
}

bool _looksLikeJsonBlob(String text) =>
    text.trimLeft().startsWith('{') || text.contains('"event"');

String? _extractProviderSentence(String raw) {
  final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final patterns = <RegExp>[
    RegExp(
      r'Para proteger os direitos de imagem[\s\S]{0,400}?baseado em texto\.?',
      caseSensitive: false,
    ),
    RegExp(
      r'Para proteger os direitos autorais[\s\S]{0,400}?(?:tente novamente|try again)\.?',
      caseSensitive: false,
    ),
    RegExp(
      r'To protect image rights[\s\S]{0,400}?(?:text-based video|based on text)\.?',
      caseSensitive: false,
    ),
    RegExp(
      r'To protect copyright[\s\S]{0,400}?(?:try again|edit the prompt)[^.]*\.?',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(normalized);
    if (match != null) {
      return match.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return null;
}

class DolaCancelledException implements Exception {
  const DolaCancelledException();

  @override
  String toString() => 'Geração Dola interrompida.';
}

class DolaGenerationException implements Exception {
  const DolaGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
