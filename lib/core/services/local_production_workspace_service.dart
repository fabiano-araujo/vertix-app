import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_service.dart';

bool _readBool(dynamic value, {required bool fallback}) {
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

class ProductionCatalogItem {
  final int routeId;
  final String stableKey;
  final String title;
  final String description;
  final String genre;
  final String status;
  final String sourceLabel;
  final String? sourcePath;
  final String? coverAssetPath;
  final String? coverUrl;
  final int episodeCount;
  final int targetEpisodeCount;
  final int takeCount;
  final int completedTakeCount;
  final int referenceCount;
  final double progress;
  final bool isLocal;
  final AdminSeriesSummary? remoteSummary;

  const ProductionCatalogItem({
    required this.routeId,
    required this.stableKey,
    required this.title,
    required this.description,
    required this.genre,
    required this.status,
    required this.sourceLabel,
    this.sourcePath,
    this.coverAssetPath,
    this.coverUrl,
    required this.episodeCount,
    required this.targetEpisodeCount,
    required this.takeCount,
    required this.completedTakeCount,
    required this.referenceCount,
    required this.progress,
    required this.isLocal,
    this.remoteSummary,
  });

  factory ProductionCatalogItem.fromLocal(ProductionProject project) {
    final takes = project.episodes.expand((episode) => episode.takes).toList();
    final completed = takes.where((take) => take.status == 'COMPLETED').length;
    return ProductionCatalogItem(
      routeId: project.virtualId,
      stableKey: 'local:${project.id}',
      title: project.title,
      description: project.description,
      genre: project.genre,
      status: project.status,
      sourceLabel: 'Workspace local',
      sourcePath: project.sourcePath,
      coverAssetPath: project.coverAssetPath,
      coverUrl: project.coverUrl,
      episodeCount: project.episodes.length,
      targetEpisodeCount: project.targetEpisodeCount,
      takeCount: takes.length,
      completedTakeCount: completed,
      referenceCount: project.references.length,
      progress: takes.isEmpty
          ? 0
          : takes.fold<double>(0, (sum, take) => sum + take.progress) /
                takes.length,
      isLocal: true,
    );
  }

  factory ProductionCatalogItem.fromRemote(AdminSeriesSummary summary) {
    return ProductionCatalogItem(
      routeId: summary.id,
      stableKey: 'remote:${summary.id}',
      title: summary.title,
      description: summary.description,
      genre: summary.genre,
      status: summary.status,
      sourceLabel: summary.productionPlan?.source ?? 'Vertix API',
      coverUrl: summary.coverUrl,
      episodeCount: summary.episodeCount,
      targetEpisodeCount: summary.totalEpisodes,
      takeCount: summary.storyPointCount,
      completedTakeCount: 0,
      referenceCount: summary.referenceCount,
      progress: summary.hasProductionPlan ? 0.55 : 0.12,
      isLocal: false,
      remoteSummary: summary,
    );
  }
}

class ProductionReferenceItem {
  final String id;
  final String label;
  final String category;
  final String? assetPath;
  final String? publicUrl;
  final String description;
  final bool canonical;

  const ProductionReferenceItem({
    required this.id,
    required this.label,
    required this.category,
    this.assetPath,
    this.publicUrl,
    this.description = '',
    this.canonical = false,
  });

  factory ProductionReferenceItem.fromJson(Map<String, dynamic> json) =>
      ProductionReferenceItem(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? 'Referencia',
        category: json['category'] as String? ?? 'REFERENCE',
        assetPath: json['assetPath'] as String?,
        publicUrl: json['publicUrl'] as String?,
        description: json['description'] as String? ?? '',
        canonical: _readBool(json['canonical'], fallback: false),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'category': category,
    'assetPath': assetPath,
    'publicUrl': publicUrl,
    'description': description,
    'canonical': canonical,
  };
}

class ProductionTakeItem {
  final String id;
  final int number;
  final String title;
  final int durationSeconds;
  final String status;
  final double progress;
  final String visualPrompt;
  final String audioPrompt;
  final String transitionMode;
  final bool usePreviousLastFrame;
  final bool generateSeedanceAudio;
  final List<String> referenceIds;
  final String? outputUrl;
  final String? lastFrameLabel;
  final String notes;

  const ProductionTakeItem({
    required this.id,
    required this.number,
    required this.title,
    required this.durationSeconds,
    this.status = 'READY',
    this.progress = 0,
    this.visualPrompt = '',
    this.audioPrompt = '',
    this.transitionMode = 'MATCH_ON_ACTION',
    this.usePreviousLastFrame = false,
    this.generateSeedanceAudio = false,
    this.referenceIds = const [],
    this.outputUrl,
    this.lastFrameLabel,
    this.notes = '',
  });

  factory ProductionTakeItem.fromJson(Map<String, dynamic> json) =>
      ProductionTakeItem(
        id: json['id'] as String? ?? '',
        number: json['number'] as int? ?? 1,
        title: json['title'] as String? ?? 'Take',
        durationSeconds: json['durationSeconds'] as int? ?? 10,
        status: json['status'] as String? ?? 'READY',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        visualPrompt: json['visualPrompt'] as String? ?? '',
        audioPrompt: json['audioPrompt'] as String? ?? '',
        transitionMode: json['transitionMode'] as String? ?? 'MATCH_ON_ACTION',
        usePreviousLastFrame: _readBool(
          json['usePreviousLastFrame'],
          fallback: false,
        ),
        generateSeedanceAudio: _readBool(
          json['generateSeedanceAudio'],
          fallback: false,
        ),
        referenceIds: (json['referenceIds'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        outputUrl: json['outputUrl'] as String?,
        lastFrameLabel: json['lastFrameLabel'] as String?,
        notes: json['notes'] as String? ?? '',
      );

  ProductionTakeItem copyWith({
    String? title,
    int? durationSeconds,
    String? status,
    double? progress,
    String? visualPrompt,
    String? audioPrompt,
    String? transitionMode,
    bool? usePreviousLastFrame,
    bool? generateSeedanceAudio,
    List<String>? referenceIds,
    String? outputUrl,
    String? lastFrameLabel,
    String? notes,
  }) => ProductionTakeItem(
    id: id,
    number: number,
    title: title ?? this.title,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    visualPrompt: visualPrompt ?? this.visualPrompt,
    audioPrompt: audioPrompt ?? this.audioPrompt,
    transitionMode: transitionMode ?? this.transitionMode,
    usePreviousLastFrame: usePreviousLastFrame ?? this.usePreviousLastFrame,
    generateSeedanceAudio: generateSeedanceAudio ?? this.generateSeedanceAudio,
    referenceIds: referenceIds ?? this.referenceIds,
    outputUrl: outputUrl ?? this.outputUrl,
    lastFrameLabel: lastFrameLabel ?? this.lastFrameLabel,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'title': title,
    'durationSeconds': durationSeconds,
    'status': status,
    'progress': progress,
    'visualPrompt': visualPrompt,
    'audioPrompt': audioPrompt,
    'transitionMode': transitionMode,
    'usePreviousLastFrame': usePreviousLastFrame,
    'generateSeedanceAudio': generateSeedanceAudio,
    'referenceIds': referenceIds,
    'outputUrl': outputUrl,
    'lastFrameLabel': lastFrameLabel,
    'notes': notes,
  };
}

class ProductionEpisodeItem {
  final int number;
  final String title;
  final String summary;
  final String cliffhanger;
  final int durationSeconds;
  final String status;
  final List<ProductionTakeItem> takes;
  final bool externalMusic;
  final String musicProvider;
  final String musicPrompt;
  final String musicStatus;
  final double musicVolume;
  final double dialogueVolume;
  final double ambienceVolume;
  final String? assembledOutputUrl;

  const ProductionEpisodeItem({
    required this.number,
    required this.title,
    required this.summary,
    required this.cliffhanger,
    required this.durationSeconds,
    this.status = 'IN_PROGRESS',
    required this.takes,
    this.externalMusic = true,
    this.musicProvider = 'API externa',
    this.musicPrompt = '',
    this.musicStatus = 'DRAFT',
    this.musicVolume = 0.36,
    this.dialogueVolume = 0.9,
    this.ambienceVolume = 0.48,
    this.assembledOutputUrl,
  });

  factory ProductionEpisodeItem.fromJson(Map<String, dynamic> json) =>
      ProductionEpisodeItem(
        number: json['number'] as int? ?? 1,
        title: json['title'] as String? ?? 'Episodio',
        summary: json['summary'] as String? ?? '',
        cliffhanger: json['cliffhanger'] as String? ?? '',
        durationSeconds: json['durationSeconds'] as int? ?? 60,
        status: json['status'] as String? ?? 'IN_PROGRESS',
        takes: (json['takes'] as List<dynamic>? ?? const [])
            .map(
              (item) => ProductionTakeItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        externalMusic: _readBool(json['externalMusic'], fallback: true),
        musicProvider: json['musicProvider'] as String? ?? 'API externa',
        musicPrompt: json['musicPrompt'] as String? ?? '',
        musicStatus: json['musicStatus'] as String? ?? 'DRAFT',
        musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.36,
        dialogueVolume: (json['dialogueVolume'] as num?)?.toDouble() ?? 0.9,
        ambienceVolume: (json['ambienceVolume'] as num?)?.toDouble() ?? 0.48,
        assembledOutputUrl: json['assembledOutputUrl'] as String?,
      );

  ProductionEpisodeItem copyWith({
    String? title,
    String? summary,
    String? cliffhanger,
    int? durationSeconds,
    String? status,
    List<ProductionTakeItem>? takes,
    bool? externalMusic,
    String? musicProvider,
    String? musicPrompt,
    String? musicStatus,
    double? musicVolume,
    double? dialogueVolume,
    double? ambienceVolume,
    String? assembledOutputUrl,
  }) => ProductionEpisodeItem(
    number: number,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    cliffhanger: cliffhanger ?? this.cliffhanger,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    status: status ?? this.status,
    takes: takes ?? this.takes,
    externalMusic: externalMusic ?? this.externalMusic,
    musicProvider: musicProvider ?? this.musicProvider,
    musicPrompt: musicPrompt ?? this.musicPrompt,
    musicStatus: musicStatus ?? this.musicStatus,
    musicVolume: musicVolume ?? this.musicVolume,
    dialogueVolume: dialogueVolume ?? this.dialogueVolume,
    ambienceVolume: ambienceVolume ?? this.ambienceVolume,
    assembledOutputUrl: assembledOutputUrl ?? this.assembledOutputUrl,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'summary': summary,
    'cliffhanger': cliffhanger,
    'durationSeconds': durationSeconds,
    'status': status,
    'takes': takes.map((take) => take.toJson()).toList(),
    'externalMusic': externalMusic,
    'musicProvider': musicProvider,
    'musicPrompt': musicPrompt,
    'musicStatus': musicStatus,
    'musicVolume': musicVolume,
    'dialogueVolume': dialogueVolume,
    'ambienceVolume': ambienceVolume,
    'assembledOutputUrl': assembledOutputUrl,
  };
}

class ProductionProject {
  final String id;
  final int virtualId;
  final String title;
  final String description;
  final String genre;
  final String formatFamily;
  final String status;
  final String sourcePath;
  final String? coverAssetPath;
  final String? coverUrl;
  final int targetEpisodeCount;
  final bool isLocal;
  final DateTime updatedAt;
  final Map<String, dynamic> seriesBible;
  final List<ProductionEpisodeItem> episodes;
  final List<ProductionReferenceItem> references;

  const ProductionProject({
    required this.id,
    required this.virtualId,
    required this.title,
    required this.description,
    required this.genre,
    required this.formatFamily,
    required this.status,
    required this.sourcePath,
    this.coverAssetPath,
    this.coverUrl,
    required this.targetEpisodeCount,
    required this.isLocal,
    required this.updatedAt,
    required this.seriesBible,
    required this.episodes,
    required this.references,
  });

  factory ProductionProject.fromJson(Map<String, dynamic> json) =>
      ProductionProject(
        id: json['id'] as String? ?? '',
        virtualId: json['virtualId'] as int? ?? -9999,
        title: json['title'] as String? ?? 'Obra sem titulo',
        description: json['description'] as String? ?? '',
        genre: json['genre'] as String? ?? 'vertical',
        formatFamily: json['formatFamily'] as String? ?? 'vertical_series',
        status: json['status'] as String? ?? 'DRAFT',
        sourcePath: json['sourcePath'] as String? ?? 'Local',
        coverAssetPath: json['coverAssetPath'] as String?,
        coverUrl: json['coverUrl'] as String?,
        targetEpisodeCount: json['targetEpisodeCount'] as int? ?? 12,
        isLocal: _readBool(json['isLocal'], fallback: true),
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        seriesBible: Map<String, dynamic>.from(
          json['seriesBible'] as Map? ?? const {},
        ),
        episodes: (json['episodes'] as List<dynamic>? ?? const [])
            .map(
              (item) => ProductionEpisodeItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        references: (json['references'] as List<dynamic>? ?? const [])
            .map(
              (item) => ProductionReferenceItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );

  ProductionProject copyWith({
    String? title,
    String? description,
    String? genre,
    String? formatFamily,
    String? status,
    String? sourcePath,
    String? coverAssetPath,
    String? coverUrl,
    int? targetEpisodeCount,
    bool? isLocal,
    DateTime? updatedAt,
    Map<String, dynamic>? seriesBible,
    List<ProductionEpisodeItem>? episodes,
    List<ProductionReferenceItem>? references,
  }) => ProductionProject(
    id: id,
    virtualId: virtualId,
    title: title ?? this.title,
    description: description ?? this.description,
    genre: genre ?? this.genre,
    formatFamily: formatFamily ?? this.formatFamily,
    status: status ?? this.status,
    sourcePath: sourcePath ?? this.sourcePath,
    coverAssetPath: coverAssetPath ?? this.coverAssetPath,
    coverUrl: coverUrl ?? this.coverUrl,
    targetEpisodeCount: targetEpisodeCount ?? this.targetEpisodeCount,
    isLocal: isLocal ?? this.isLocal,
    updatedAt: updatedAt ?? this.updatedAt,
    seriesBible: seriesBible ?? this.seriesBible,
    episodes: episodes ?? this.episodes,
    references: references ?? this.references,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'virtualId': virtualId,
    'title': title,
    'description': description,
    'genre': genre,
    'formatFamily': formatFamily,
    'status': status,
    'sourcePath': sourcePath,
    'coverAssetPath': coverAssetPath,
    'coverUrl': coverUrl,
    'targetEpisodeCount': targetEpisodeCount,
    'isLocal': isLocal,
    'updatedAt': updatedAt.toIso8601String(),
    'seriesBible': seriesBible,
    'episodes': episodes.map((episode) => episode.toJson()).toList(),
    'references': references.map((reference) => reference.toJson()).toList(),
  };
}

class MicroDramaProjectConfig {
  final String title;
  final String logline;
  final String centralQuestion;
  final String protagonist;
  final String opposingForce;
  final String stakes;
  final String genre;
  final String background;
  final String trope;
  final String visualStyle;
  final String language;
  final String rating;
  final int episodeCount;
  final int firstEpisodeDurationSeconds;
  final int episodeDurationSeconds;
  final bool automaticReview;

  const MicroDramaProjectConfig({
    required this.title,
    required this.logline,
    required this.centralQuestion,
    required this.protagonist,
    required this.opposingForce,
    required this.stakes,
    required this.genre,
    required this.background,
    required this.trope,
    required this.visualStyle,
    required this.language,
    required this.rating,
    required this.episodeCount,
    required this.firstEpisodeDurationSeconds,
    required this.episodeDurationSeconds,
    this.automaticReview = true,
  });

  String get distributionProfile =>
      episodeCount >= 50 ? 'app_native' : 'validation_pilot';
}

class _MicroDramaEpisodePlan {
  final String title;
  final String job;
  final String coldOpen;
  final String goal;
  final String protagonistStep;
  final String countermove;
  final String valueChange;
  final String summary;
  final String cliffhanger;

  const _MicroDramaEpisodePlan({
    required this.title,
    required this.job,
    required this.coldOpen,
    required this.goal,
    required this.protagonistStep,
    required this.countermove,
    required this.valueChange,
    required this.summary,
    required this.cliffhanger,
  });
}

class LocalProductionWorkspaceService {
  static const _workspaceKey = 'vertix_local_production_workspace_v5';
  static const _remoteOverlayPrefix = 'vertix_remote_production_editor_v2_';
  static const _generatedIndexPath = 'generated-production/index.json';
  static const _nativeGeneratedMediaBaseUrl = String.fromEnvironment(
    'VERTIX_GENERATED_PRODUCTION_BASE_URL',
  );
  static final LocalProductionWorkspaceService _instance =
      LocalProductionWorkspaceService._internal();

  factory LocalProductionWorkspaceService() => _instance;
  LocalProductionWorkspaceService._internal();

  List<ProductionProject>? _cache;
  final Dio _generatedMediaClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ),
  );

  Future<List<ProductionProject>> getProjects() async {
    if (_cache == null) {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_workspaceKey);
      final projects = <ProductionProject>[];
      if (saved != null && saved.isNotEmpty) {
        try {
          final decoded = jsonDecode(saved) as List<dynamic>;
          projects.addAll(
            decoded.map(
              (item) => ProductionProject.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
        } catch (_) {
          projects.clear();
        }
      }
      for (final seed in _seedProjects()) {
        if (!projects.any((project) => project.id == seed.id)) {
          projects.add(seed);
        }
      }
      _cache = projects;
      await _persistLocalProjects();
    }
    final overlaid = await _applyGeneratedProductionOverlays(_cache!);
    return List.unmodifiable(overlaid);
  }

  Future<List<ProductionProject>> _applyGeneratedProductionOverlays(
    List<ProductionProject> projects,
  ) async {
    if (!kIsWeb && _nativeGeneratedMediaBaseUrl.isEmpty) return projects;
    try {
      final index = await _getGeneratedJson(_generatedIndexPath);
      final entries = Map<String, dynamic>.from(
        index['projects'] as Map? ?? const {},
      );
      if (entries.isEmpty) return projects;

      final result = projects.toList();
      for (final entry in entries.entries) {
        final projectIndex = result.indexWhere(
          (project) => project.id == entry.key,
        );
        if (projectIndex < 0 || entry.value is! String) continue;
        final manifest = await _getGeneratedJson(entry.value as String);
        result[projectIndex] = _mergeGeneratedManifest(
          result[projectIndex],
          manifest,
        );
      }
      return result;
    } catch (_) {
      // The generated-production bridge is optional outside configured builds.
      return projects;
    }
  }

  Uri get _generatedMediaBaseUri {
    if (kIsWeb) return Uri.base;
    final value = _nativeGeneratedMediaBaseUrl.endsWith('/')
        ? _nativeGeneratedMediaBaseUrl
        : '$_nativeGeneratedMediaBaseUrl/';
    return Uri.parse(value);
  }

  String? _resolveGeneratedMediaUrl(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty || kIsWeb) return value;
    final parsed = Uri.tryParse(value);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return value;
    }
    if (_nativeGeneratedMediaBaseUrl.isEmpty) return value;
    final relative = value.startsWith('/') ? value.substring(1) : value;
    return _generatedMediaBaseUri.resolve(relative).toString();
  }

  Future<Map<String, dynamic>> _getGeneratedJson(String path) async {
    final relative = path.startsWith('/') ? path.substring(1) : path;
    final resolved = _generatedMediaBaseUri.resolve(relative);
    final uri = resolved.replace(
      queryParameters: {
        ...resolved.queryParameters,
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await _generatedMediaClient.getUri<dynamic>(
      uri,
      options: Options(
        responseType: ResponseType.json,
        headers: const {'Cache-Control': 'no-cache'},
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      return Map<String, dynamic>.from(jsonDecode(data) as Map);
    }
    throw const FormatException('Manifesto de producao local invalido');
  }

  ProductionProject _mergeGeneratedManifest(
    ProductionProject project,
    Map<String, dynamic> manifest,
  ) {
    if (manifest['projectId'] != project.id) return project;
    final episodeManifests =
        (manifest['episodes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    if (episodeManifests.isEmpty) return project;

    final generatedReferences = <ProductionReferenceItem>[];
    final episodes = project.episodes.map((episode) {
      final generated = episodeManifests
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (item) => item?['number'] == episode.number,
            orElse: () => null,
          );
      if (generated == null) return episode;

      final generatedTakes = (generated['takes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final generatedByNumber = <int, Map<String, dynamic>>{
        for (final item in generatedTakes)
          if (item['number'] is int) item['number'] as int: item,
      };
      final takes = episode.takes.map((take) {
        final media = generatedByNumber[take.number];
        if (media == null) {
          if (take.outputUrl?.startsWith('local://simulation/') == true) {
            return ProductionTakeItem(
              id: take.id,
              number: take.number,
              title: take.title,
              durationSeconds: take.durationSeconds,
              status: 'READY',
              progress: 0,
              visualPrompt: take.visualPrompt,
              audioPrompt: take.audioPrompt,
              transitionMode: take.transitionMode,
              usePreviousLastFrame: take.usePreviousLastFrame,
              generateSeedanceAudio: take.generateSeedanceAudio,
              referenceIds: take.referenceIds,
              notes: take.notes,
            );
          }
          return take;
        }

        final contactUrl = _resolveGeneratedMediaUrl(
          media['contactSheetUrl'] as String?,
        );
        final lastFrameUrl = _resolveGeneratedMediaUrl(
          media['lastFrameUrl'] as String?,
        );
        final pencilFrameUrl = _resolveGeneratedMediaUrl(
          media['pencilFrameUrl'] as String?,
        );
        final continuitySheetUrl = _resolveGeneratedMediaUrl(
          media['continuitySheetUrl'] as String?,
        );
        if (contactUrl?.isNotEmpty == true) {
          generatedReferences.add(
            ProductionReferenceItem(
              id: 'generated-${project.id}-e${episode.number}-t${take.number}-contact',
              label: 'Take ${take.number} • 4 quadros de revisão',
              category: 'GENERATED_REVIEW',
              publicUrl: contactUrl,
              description: 'Quadros reais extraídos do vídeo gerado.',
            ),
          );
        }
        if (lastFrameUrl?.isNotEmpty == true) {
          generatedReferences.add(
            ProductionReferenceItem(
              id: 'generated-${project.id}-e${episode.number}-t${take.number}-last',
              label: 'Take ${take.number} • último frame real',
              category: 'GENERATED_LAST_FRAME',
              publicUrl: lastFrameUrl,
              description: 'Último frame exato usado para continuidade.',
            ),
          );
        }
        if (pencilFrameUrl?.isNotEmpty == true) {
          generatedReferences.add(
            ProductionReferenceItem(
              id: 'generated-${project.id}-e${episode.number}-t${take.number}-pencil',
              label: 'Take ${take.number} • último frame com rostos desenhados',
              category: 'GENERATED_CONTINUITY_FRAME',
              publicUrl: pencilFrameUrl,
              description:
                  'Último frame real com rostos simplificados para continuidade segura.',
            ),
          );
        }
        if (continuitySheetUrl?.isNotEmpty == true) {
          generatedReferences.add(
            ProductionReferenceItem(
              id: 'generated-${project.id}-e${episode.number}-t${take.number}-continuity-sheet',
              label: 'Take ${take.number} • contexto temporal em 4 quadros',
              category: 'GENERATED_CONTINUITY_SHEET',
              publicUrl: continuitySheetUrl,
              description:
                  'Quatro momentos do take anterior com rostos desenhados, usados apenas como contexto espacial e de ação.',
            ),
          );
        }
        return take.copyWith(
          status: media['status'] as String? ?? 'COMPLETED',
          progress: (media['progress'] as num?)?.toDouble() ?? 1,
          outputUrl: _resolveGeneratedMediaUrl(media['outputUrl'] as String?),
          lastFrameLabel: lastFrameUrl?.isNotEmpty == true
              ? 'Último frame real • Take ${take.number}'
              : take.lastFrameLabel,
        );
      }).toList();
      final completed = takes
          .where((take) => take.status == 'COMPLETED')
          .length;
      return episode.copyWith(
        status: completed == takes.length ? 'COMPLETED' : 'IN_PROGRESS',
        takes: takes,
        assembledOutputUrl: _resolveGeneratedMediaUrl(
          generated['assembledOutputUrl'] as String?,
        ),
      );
    }).toList();

    final references =
        project.references
            .where(
              (reference) =>
                  !reference.id.startsWith('generated-${project.id}-'),
            )
            .toList()
          ..addAll(generatedReferences);
    final generatedAt = DateTime.tryParse(
      manifest['updatedAt'] as String? ?? '',
    );
    return project.copyWith(
      updatedAt: generatedAt ?? project.updatedAt,
      episodes: episodes,
      references: references,
      seriesBible: {
        ...project.seriesBible,
        'generated_media_manifest': manifest['manifestUrl'],
        'generated_media_updated_at': manifest['updatedAt'],
      },
    );
  }

  @visibleForTesting
  ProductionProject mergeGeneratedManifestForTesting(
    ProductionProject project,
    Map<String, dynamic> manifest,
  ) => _mergeGeneratedManifest(project, manifest);

  Future<List<ProductionCatalogItem>> getLocalCatalog() async {
    final projects = await getProjects();
    return projects.map(ProductionCatalogItem.fromLocal).toList();
  }

  Future<ProductionProject?> getLocalProjectByVirtualId(int virtualId) async {
    for (final project in await getProjects()) {
      if (project.virtualId == virtualId) return project;
    }
    return null;
  }

  Future<ProductionProject> loadEditorProject(
    ProductionCatalogItem item, {
    AdminSeriesProductionPlan? remotePlan,
  }) async {
    if (item.isLocal) {
      return (await getLocalProjectByVirtualId(item.routeId)) ??
          _blankProjectFromCatalog(item);
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('$_remoteOverlayPrefix${item.routeId}');
    if (saved != null && saved.isNotEmpty) {
      try {
        return ProductionProject.fromJson(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      } catch (_) {}
    }
    return _projectFromRemote(item, remotePlan);
  }

  Future<void> saveProject(ProductionProject project) async {
    final updated = project.copyWith(updatedAt: DateTime.now());
    if (updated.isLocal) {
      final projects = (await getProjects()).toList();
      final index = projects.indexWhere((item) => item.id == updated.id);
      if (index >= 0) {
        projects[index] = updated;
      } else {
        projects.add(updated);
      }
      _cache = projects;
      await _persistLocalProjects();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_remoteOverlayPrefix${updated.virtualId}',
      jsonEncode(updated.toJson()),
    );
  }

  Future<ProductionProject> createProject({
    required String title,
    required String genre,
    required String formatFamily,
  }) async {
    final projects = (await getProjects()).toList();
    final minId = projects.fold<int>(
      -1000,
      (value, item) => item.virtualId < value ? item.virtualId : value,
    );
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final project = _draftProject(
      id: '${slug.isEmpty ? 'obra' : slug}-${DateTime.now().millisecondsSinceEpoch}',
      virtualId: minId - 1,
      title: title,
      description: 'Projeto vertical local criado no editor Vertix.',
      genre: genre,
      formatFamily: formatFamily,
      sourcePath: 'Workspace local / $title',
    );
    projects.insert(0, project);
    _cache = projects;
    await _persistLocalProjects();
    return project;
  }

  Future<ProductionProject> createMicroDramaProject(
    MicroDramaProjectConfig config,
  ) async {
    final projects = (await getProjects()).toList();
    final minId = projects.fold<int>(
      -1000,
      (value, item) => item.virtualId < value ? item.virtualId : value,
    );
    final slug = _slugify(config.title);
    final now = DateTime.now();
    final project = _buildMicroDramaProject(
      config,
      id: '${slug.isEmpty ? 'microdrama' : slug}-${now.millisecondsSinceEpoch}',
      virtualId: minId - 1,
      updatedAt: now,
    );
    projects.insert(0, project);
    _cache = projects;
    await _persistLocalProjects();
    return project;
  }

  @visibleForTesting
  ProductionProject buildMicroDramaProjectForTesting(
    MicroDramaProjectConfig config,
  ) => _buildMicroDramaProject(
    config,
    id: 'microdrama-test',
    virtualId: -9001,
    updatedAt: DateTime(2026, 8, 16),
  );

  static ProductionProject _buildMicroDramaProject(
    MicroDramaProjectConfig config, {
    required String id,
    required int virtualId,
    required DateTime updatedAt,
  }) {
    final protagonistId = '$id-character-protagonist';
    final opposingForceId = '$id-character-opposing-force';
    final locationId = '$id-location-master';
    final propId = '$id-prop-master';
    final referenceIds = [protagonistId, opposingForceId, locationId, propId];
    final episodes = <ProductionEpisodeItem>[];
    final episodeCards = <Map<String, dynamic>>[];
    final hookChain = <Map<String, dynamic>>[];
    final pressureLedger = <Map<String, dynamic>>[];
    var previousHook =
        'Uma consequência visível torna a premissa impossível de ignorar.';

    for (var index = 0; index < config.episodeCount; index++) {
      final episodeNumber = index + 1;
      final duration = index == 0
          ? config.firstEpisodeDurationSeconds
          : config.episodeDurationSeconds;
      final plan = _microDramaEpisodePlan(config, episodeNumber: episodeNumber);
      final openingPickup = episodeNumber == 1
          ? 'Abrir já na consequência concreta da premissa: ${config.logline}'
          : 'Pagar imediatamente o gancho anterior sem reiniciar a história: $previousHook';
      final takes = _microDramaTakes(
        config,
        projectId: id,
        episodeNumber: episodeNumber,
        durationSeconds: duration,
        episodeSummary: plan.summary,
        cliffhanger: plan.cliffhanger,
        referenceIds: referenceIds,
      );
      episodes.add(
        ProductionEpisodeItem(
          number: episodeNumber,
          title: plan.title,
          summary: plan.summary,
          cliffhanger: plan.cliffhanger,
          durationSeconds: duration,
          status: 'DRAFT',
          takes: takes,
          externalMusic: true,
          musicProvider: 'API externa',
          musicPrompt:
              '${config.genre}, ${config.trope}. Trilha contínua sem voz para o episódio $episodeNumber, crescendo até o corte no pico e sem competir com o áudio já presente nos vídeos.',
        ),
      );
      final questions = [
        config.centralQuestion,
        'Qual será o custo imediato para ${config.protagonist}?',
        'Como ${config.opposingForce} vai reagir à nova posição de poder?',
      ];
      episodeCards.add({
        'episode': episodeNumber,
        'episode_job': plan.job,
        'previous_promise_payoff': openingPickup,
        'cold_open': plan.coldOpen,
        'dominant_question': config.centralQuestion,
        'immediate_goal': plan.goal,
        'obstacle': config.opposingForce,
        'stakes_and_why_now': config.stakes,
        'protagonist_step': plan.protagonistStep,
        'antagonist_countermove': plan.countermove,
        'peak_action': plan.cliffhanger,
        'exact_cut_point': 'Cortar no pico, antes da reação ou explicação.',
        'next_episode_question': questions.first,
        'status': 'DRAFT_REVIEW_REQUIRED',
      });
      hookChain.add({
        'episode': episodeNumber,
        'opening_pickup': openingPickup,
        'final_hook': plan.cliffhanger,
        'unresolved_questions': questions,
      });
      pressureLedger.add({
        'episode': episodeNumber,
        'primary_pressure': plan.job,
        'choice_type': plan.protagonistStep,
        'value_changed': plan.valueChange,
        'adjacent_similarity': 'review_required',
      });
      previousHook = plan.cliffhanger;
    }

    final profileEvidence = config.episodeCount >= 50
        ? 'platform_default'
        : 'hypothesis';
    return ProductionProject(
      id: id,
      virtualId: virtualId,
      title: config.title,
      description: config.logline,
      genre: config.genre,
      formatFamily: 'micro_drama_vertical',
      status: 'DRAFT',
      sourcePath: 'Workspace local / Microdrama / ${config.title}',
      targetEpisodeCount: config.episodeCount,
      isLocal: true,
      updatedAt: updatedAt,
      seriesBible: {
        'creation_workflow': 'guided_microdrama_v1',
        'package_status': 'DRAFT_REVIEW_REQUIRED',
        'distribution_profile': config.distributionProfile,
        'evidence_status': profileEvidence,
        'aspect_ratio': '9:16',
        'language': config.language,
        'rating': config.rating,
        'visual_style': config.visualStyle,
        'genre': config.genre,
        'background': config.background,
        'trope': config.trope,
        'logline': config.logline,
        'central_question': config.centralQuestion,
        'protagonist': config.protagonist,
        'opposing_force': config.opposingForce,
        'stakes': config.stakes,
        'episode_engine':
            'Cada episódio paga o gancho anterior, força uma escolha de ${config.protagonist} e provoca uma contrajogada de ${config.opposingForce}.',
        'relationship_engine':
            'O vínculo central muda por decisões observáveis, não por mal-entendidos adiados.',
        'antagonist_counterplay':
            '${config.opposingForce} aprende com cada avanço e responde de acordo com objetivo próprio.',
        'escalation_ceiling':
            'A resposta completa para "${config.centralQuestion}" fica reservada ao bloco final.',
        'audio_strategy':
            'Cada vídeo já contém diálogo, ambiente e efeitos; somente a música permanece em faixa separada.',
        'automatic_review': config.automaticReview,
        'workflow': {
          'settings': 'COMPLETE',
          'series_contract': 'DRAFT',
          'outline': 'DRAFT_REVIEW_REQUIRED',
          'characters_locations_props': 'PLACEHOLDERS_CREATED',
          'scripts': 'BEAT_SHEETS_CREATED',
          'production': 'NOT_STARTED',
        },
        'promise_ledger': [
          {
            'promise': config.centralQuestion,
            'opened_episode': 1,
            'payoff_window':
                '${config.episodeCount - 1}-${config.episodeCount}',
            'planned_payoff':
                'A escolha final de ${config.protagonist} responde à pergunta e cria uma consequência.',
            'status': 'open',
          },
        ],
        'episode_cards': episodeCards,
        'hook_chain': hookChain,
        'pressure_ledger': pressureLedger,
      },
      episodes: episodes,
      references: [
        ProductionReferenceItem(
          id: protagonistId,
          label: config.protagonist,
          category: 'CHARACTER_MASTER',
          description:
              'Protagonista. Definir aparência canônica, personalidade, desejo, ferida, necessidade e figurinos antes da geração.',
          canonical: true,
        ),
        ProductionReferenceItem(
          id: opposingForceId,
          label: config.opposingForce,
          category: 'OPPOSING_FORCE_MASTER',
          description:
              'Força oposta. Definir aparência, objetivo concorrente, recurso de poder e padrão de contrajogada.',
          canonical: true,
        ),
        ProductionReferenceItem(
          id: locationId,
          label: config.background,
          category: 'LOCATION_MASTER',
          description:
              'Ambiente mestre do microdrama. Fixar geografia, luz, objetos permanentes e limites de produção.',
          canonical: true,
        ),
        ProductionReferenceItem(
          id: propId,
          label: 'Objeto narrativo principal',
          category: 'PROP_MASTER',
          description:
              'Escolher um objeto que seja introduzido, transferido, alterado e pago ao longo da temporada.',
          canonical: true,
        ),
      ],
    );
  }

  static _MicroDramaEpisodePlan _microDramaEpisodePlan(
    MicroDramaProjectConfig config, {
    required int episodeNumber,
  }) {
    final progress = episodeNumber / config.episodeCount;
    late final String stage;
    late final String job;
    late final String action;
    late final String valueChange;
    if (episodeNumber == 1) {
      stage = 'O impacto';
      job = 'Provar a premissa e tornar o conflito inevitável.';
      action = 'transforma a consequência inicial em uma escolha pública';
      valueChange = 'segurança para risco';
    } else if (progress <= 0.25) {
      stage = 'A negação';
      job = 'Pagar o choque e mostrar por que a solução simples não funciona.';
      action = 'tenta preservar o controle e perde uma vantagem concreta';
      valueChange = 'controle para exposição';
    } else if (progress <= 0.42) {
      stage = 'A proposta';
      job = 'Criar proximidade forçada e um custo emocional verificável.';
      action = 'aceita uma condição que aproxima o perigo';
      valueChange = 'distância para intimidade perigosa';
    } else if (progress <= 0.58) {
      stage = 'A prova';
      job = 'Ativar uma pista ou objeto que mude a estratégia.';
      action = 'usa uma prova física e força a força oposta a reagir';
      valueChange = 'suspeita para evidência';
    } else if (progress <= 0.72) {
      stage = 'O preço';
      job = 'Cobrar a decisão anterior e retirar uma rota de fuga.';
      action = 'protege o que mais importa e sacrifica uma vantagem';
      valueChange = 'esperança para perda';
    } else if (progress <= 0.86) {
      stage = 'A contrajogada';
      job = 'Dar à força oposta uma vitória real que reorganize o poder.';
      action = 'responde à contrajogada com uma decisão irreversível';
      valueChange = 'equilíbrio para desvantagem';
    } else if (episodeNumber < config.episodeCount) {
      stage = 'Sem saída';
      job = 'Preparar o clímax com agência, perdas e promessas convergentes.';
      action = 'recusa a solução fácil e escolhe o confronto final';
      valueChange = 'reação para agência';
    } else {
      stage = 'A escolha final';
      job =
          'Pagar a pergunta central por uma escolha causada pelo protagonista.';
      action = 'faz a escolha que responde à promessa da temporada';
      valueChange = 'promessa aberta para consequência';
    }
    final suffix = config.episodeCount > 8
        ? ' ${episodeNumber.toString().padLeft(2, '0')}'
        : '';
    final coldOpen = episodeNumber == 1
        ? '${config.protagonist} já enfrenta a consequência visível de ${config.logline}'
        : '${config.protagonist} recebe a consequência do corte anterior antes de conseguir se recompor.';
    final summary =
        '$coldOpen Em ${config.background}, ${config.protagonist} $action. '
        '${config.opposingForce} responde por objetivo próprio, elevando o risco: ${config.stakes} '
        'O episódio muda o valor de $valueChange e termina antes da reação.';
    final cliffhanger = episodeNumber == config.episodeCount
        ? '${config.protagonist} executa a escolha final ligada a "${config.centralQuestion}"; a consequência aparece no quadro e corta antes de explicar o futuro.'
        : '${config.protagonist} descobre uma consequência concreta da própria escolha enquanto ${config.opposingForce} ativa a próxima ameaça; corte no primeiro instante irreversível.';
    return _MicroDramaEpisodePlan(
      title: '$stage$suffix',
      job: job,
      coldOpen: coldOpen,
      goal: 'Avançar uma resposta para: ${config.centralQuestion}',
      protagonistStep: action,
      countermove:
          '${config.opposingForce} observa a mudança e retira uma opção segura.',
      valueChange: valueChange,
      summary: summary,
      cliffhanger: cliffhanger,
    );
  }

  static List<ProductionTakeItem> _microDramaTakes(
    MicroDramaProjectConfig config, {
    required String projectId,
    required int episodeNumber,
    required int durationSeconds,
    required String episodeSummary,
    required String cliffhanger,
    required List<String> referenceIds,
  }) {
    const beatTitles = [
      'Gancho visível',
      'Objetivo e risco',
      'Pressão causal',
      'Escolha do protagonista',
      'Contrajogada',
      'Reversão',
      'Custo irreversível',
      'Cliffhanger',
    ];
    const takeLimit = 15;
    final takeCount = (durationSeconds / takeLimit).ceil();
    var remaining = durationSeconds;
    return List.generate(takeCount, (index) {
      final number = index + 1;
      final duration = remaining > takeLimit ? takeLimit : remaining;
      remaining -= duration;
      final beatIndex = takeCount == 1
          ? beatTitles.length - 1
          : ((index * (beatTitles.length - 1)) / (takeCount - 1)).round();
      final beat = beatTitles[beatIndex];
      final isLast = index == takeCount - 1;
      return ProductionTakeItem(
        id: '$projectId-ep$episodeNumber-take$number',
        number: number,
        title: beat,
        durationSeconds: duration,
        status: 'DRAFT',
        visualPrompt:
            '${config.visualStyle}, ${config.genre}, vertical 9:16, exatamente ${duration}s. '
            'Episódio $episodeNumber: $episodeSummary Função deste take: $beat. '
            '${isLast ? 'Encerrar exatamente em: $cliffhanger' : 'Terminar em ação incompleta que cause o próximo take.'}',
        audioPrompt:
            'Áudio integrado ao vídeo: diálogo natural em ${config.language}, ambiente e efeitos sincronizados com a ação. '
            'Sem música dentro do vídeo; a trilha será adicionada separadamente. Sem repetir contexto na borda do take.',
        transitionMode: number == 1 ? 'EPISODE_START' : 'MATCH_ON_ACTION',
        usePreviousLastFrame: false,
        generateSeedanceAudio: true,
        referenceIds: referenceIds,
        notes: isLast
            ? 'Cortar no pico antes da reação, resposta ou explicação.'
            : 'Preservar estado de saída para a entrada do próximo take.',
      );
    });
  }

  static String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  Future<void> _persistLocalProjects() async {
    if (_cache == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _workspaceKey,
      jsonEncode(_cache!.map((project) => project.toJson()).toList()),
    );
  }

  ProductionProject _blankProjectFromCatalog(ProductionCatalogItem item) =>
      _draftProject(
        id: item.stableKey.replaceAll(':', '-'),
        virtualId: item.routeId,
        title: item.title,
        description: item.description,
        genre: item.genre,
        formatFamily: 'vertical_series',
        sourcePath: item.sourcePath ?? item.sourceLabel,
        coverAssetPath: item.coverAssetPath,
        coverUrl: item.coverUrl,
        isLocal: item.isLocal,
        targetEpisodeCount: item.targetEpisodeCount,
      );

  ProductionProject _projectFromRemote(
    ProductionCatalogItem item,
    AdminSeriesProductionPlan? plan,
  ) {
    final references = (plan?.referenceAssets ?? const <AdminReferenceAsset>[])
        .map(
          (asset) => ProductionReferenceItem(
            id: 'remote-${asset.id}',
            label: asset.label,
            category: asset.category,
            publicUrl: asset.publicUrl,
            description: _stringify(asset.metadata),
            canonical:
                _stringify(asset.metadata).contains('LOCATION_MASTER') ||
                _stringify(asset.metadata).contains('WORLD_ENVIRONMENT_MASTER'),
          ),
        )
        .toList();
    final points = (plan?.storyPoints ?? const <AdminStoryPoint>[]).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final prompts = points.where((point) => point.isPrompt).toList();
    final takes = <ProductionTakeItem>[];
    for (var index = 0; index < prompts.length; index++) {
      final point = prompts[index];
      takes.add(
        ProductionTakeItem(
          id: 'remote-${item.routeId}-take-${index + 1}',
          number: index + 1,
          title: point.title,
          durationSeconds: 15,
          visualPrompt: _stringify(point.body),
          audioPrompt: _stringify(point.metadata),
          transitionMode: index == 0 ? 'EPISODE_START' : 'SOFT_CONTINUITY',
          referenceIds: references.map((reference) => reference.id).toList(),
        ),
      );
    }
    final safeTakes = takes.isEmpty
        ? _defaultTakes(item.title, count: 4)
        : takes;
    return ProductionProject(
      id: 'remote-${item.routeId}',
      virtualId: item.routeId,
      title: item.title,
      description: item.description,
      genre: item.genre,
      formatFamily: 'vertical_series',
      status: item.status,
      sourcePath: 'Vertix API / serie ${item.routeId}',
      coverUrl: item.coverUrl,
      targetEpisodeCount: item.targetEpisodeCount,
      isLocal: false,
      updatedAt: DateTime.now(),
      seriesBible: {
        'source': plan?.source ?? 'Vertix API',
        'seriesBible': plan?.seriesBible,
        'seasonArc': plan?.seasonArc,
        'episodeMap': plan?.episodeMap,
      },
      episodes: [
        ProductionEpisodeItem(
          number: 1,
          title: 'Episodio 1',
          summary: _stringify(plan?.episodeTreatments),
          cliffhanger: 'Defina o cliffhanger do episodio.',
          durationSeconds: safeTakes.fold(
            0,
            (sum, take) => sum + take.durationSeconds,
          ),
          takes: safeTakes,
          musicPrompt:
              'Cama musical continua para o episodio, sem competir com as falas.',
        ),
      ],
      references: references,
    );
  }

  static String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  static List<ProductionProject> _seedProjects() => [
    _nivalisProject(),
    _draftProject(
      id: 'kuroshiro-lamina-do-vazio',
      virtualId: -1002,
      title: 'Kuroshiro: Lamina do Vazio',
      description:
          'Anime vertical de acao sobre um guerreiro marcado por uma lamina que apaga memorias.',
      genre: 'anime / acao / fantasia',
      formatFamily: 'anime_vertical',
      sourcePath: 'series_bibles/kuroshiro-lamina-do-vazio',
      coverAssetPath:
          'series_bibles/kuroshiro-lamina-do-vazio/storyboards_v8_keyframes_contact.jpg',
      takeCount: 5,
    ),
    _draftProject(
      id: 'ilha-dos-ventos',
      virtualId: -1003,
      title: 'Ilha dos Ventos',
      description:
          'Aventura vertical em uma ilha movida por correntes de vento e segredos antigos.',
      genre: 'aventura / fantasia',
      formatFamily: 'animated_vertical',
      sourcePath: 'series_bibles/ilha-dos-ventos',
    ),
    _draftProject(
      id: 'relogio-do-ceu',
      virtualId: -1004,
      title: 'Relogio do Ceu',
      description:
          'Fantasia de misterio sobre um relogio capaz de alterar o tempo de uma cidade.',
      genre: 'fantasia / misterio',
      formatFamily: 'vertical_series',
      sourcePath: 'series_bibles/relogio-do-ceu',
    ),
    _draftProject(
      id: 'ponto-cego',
      virtualId: -1005,
      title: 'Ponto Cego',
      description:
          'Thriller vertical de vigilancia, paranoia e uma gravacao que nao deveria existir.',
      genre: 'thriller / misterio',
      formatFamily: 'vertical_series',
      sourcePath: 'ponto_cego_assets',
    ),
    _draftProject(
      id: 'punhos-da-aurora',
      virtualId: -1006,
      title: 'Punhos da Aurora',
      description:
          'Serie vertical de luta com progressao, rivalidade e poderes ligados ao amanhecer.',
      genre: 'acao / shonen',
      formatFamily: 'anime_vertical',
      sourcePath: 'punhos_da_aurora_assets',
      takeCount: 5,
    ),
    _draftProject(
      id: 'ultima-orbita',
      virtualId: -1007,
      title: 'Ultima Orbita',
      description:
          'Ficcao cientifica vertical sobre uma tripulacao presa na ultima orbita habitavel.',
      genre: 'ficcao cientifica',
      formatFamily: 'vertical_series',
      sourcePath: 'ultima_orbita_assets',
    ),
    _draftProject(
      id: 'anel-zero',
      virtualId: -1008,
      title: 'Anel Zero',
      description:
          'Suspense de ficcao cientifica sobre um artefato orbital que reinicia a memoria.',
      genre: 'sci-fi / suspense',
      formatFamily: 'vertical_series',
      sourcePath: 'anel_zero_assets',
    ),
    _draftProject(
      id: 'promethea-ultima-neve',
      virtualId: -1009,
      title: 'Promethea: A Ultima Neve',
      description:
          'Acao mecha vertical com montagem de armadura, tanques e uma guerra no gelo.',
      genre: 'mecha / ficcao cientifica',
      formatFamily: 'vertical_series',
      sourcePath: 'seedance_notion_prompts',
    ),
  ];

  static ProductionProject _nivalisProject() {
    const references = [
      ProductionReferenceItem(
        id: 'nivalis-lys',
        label: 'Lys Arven',
        category: 'CHARACTER_REFERENCE',
        assetPath:
            'series_bibles/nivalis-memorias-de-gelo/character_references/character_reference_lys_hybrid_v2.png',
        description: 'Identidade hibrida canonica da protagonista.',
        canonical: true,
      ),
      ProductionReferenceItem(
        id: 'nivalis-noa',
        label: 'Noa Arven',
        category: 'CHARACTER_REFERENCE',
        assetPath:
            'series_bibles/nivalis-memorias-de-gelo/character_references/character_reference_noa_hybrid_v4.png',
        description: 'Identidade hibrida canonica e apropriada para a idade.',
        canonical: true,
      ),
      ProductionReferenceItem(
        id: 'nivalis-tarik',
        label: 'Tarik Voss',
        category: 'CHARACTER_REFERENCE',
        assetPath:
            'series_bibles/nivalis-memorias-de-gelo/character_references/character_reference_tarik_hybrid_v3.png',
        description: 'Identidade hibrida canonica do fiscal.',
        canonical: true,
      ),
      ProductionReferenceItem(
        id: 'nivalis-banco',
        label: 'Banco Termico de Emergencia',
        category: 'LOCATION_MASTER',
        assetPath:
            'series_bibles/nivalis-memorias-de-gelo/location_references/location_reference_banco_termico_film_real_v6.png',
        description:
            'Location master unico; novos angulos devem ser controlados no prompt.',
        canonical: true,
      ),
      ProductionReferenceItem(
        id: 'nivalis-lumen',
        label: 'Fragmento de Lumen',
        category: 'PROP_REFERENCE',
        description: 'Cristal azul-negro que troca memoria por calor.',
        canonical: true,
      ),
    ];

    const sharedCharacters = [
      'nivalis-lys',
      'nivalis-noa',
      'nivalis-tarik',
      'nivalis-banco',
    ];
    const sharedWithLumen = [...sharedCharacters, 'nivalis-lumen'];
    const takes = [
      ProductionTakeItem(
        id: 'nivalis-ep01-t01',
        number: 1,
        title: 'Credito recusado',
        durationSeconds: 10,
        transitionMode: 'EPISODE_START',
        referenceIds: sharedCharacters,
        visualPrompt:
            'Live-action fotorrealista, drama sci-fi, vertical 9:16, exatamente 10s. Noa perde o ar quando o aro respiratorio congela; Lys o segura a esquerda, Tarik permanece no terminal a direita e a porta dos coletores fica atras dele. Movimento corporal com peso real, luz pratica ciano e textura natural. De 8.3-10.0s, Lys comeca a baixar Noa para o banco; cortar durante a acao.',
        audioPrompt:
            'VOICE LOCK SISTEMA: voz feminina sintetica, registro medio, timbre frio vitreo, cadencia uniforme, articulacao mecanica; nenhuma boca visivel faz lip sync. VOICE LOCK LYS: mulher brasileira de 23 anos, registro medio-grave, timbre quente levemente rouco, cadencia habitual agil, consoantes claras. VOICE LOCK TARIK: homem brasileiro de 28 anos, registro grave, timbre escuro limpo, cadencia medida, consoantes controladas. [1.0-2.3s] SISTEMA: "Crédito térmico recusado." [3.0-5.8s] LYS: "Só uma carga. O colar dele está parando." [6.6-8.3s] TARIK: "Seu saldo acabou." Pt-BR apenas, linhas exatas, sem improviso; tempestade, terminal, alarme, respiracao e tecido.',
        notes:
            'V4 / pacote 4.0.0. Terminar durante a acao de Lys baixando Noa; sem first_frame no proximo take.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t02',
        number: 2,
        title: 'O limite',
        durationSeconds: 10,
        transitionMode: 'MATCH_ON_ACTION',
        referenceIds: sharedCharacters,
        visualPrompt:
            'Live-action fotorrealista, vertical 9:16, exatamente 10s. Comece apos corte seco, no meio da mesma acao, sem reconstruir o frame anterior: Lys termina de apoiar Noa no banco a esquerda e estende o pulso ao leitor; Tarik consulta o limite a direita. Novo angulo lateral motivado no mesmo lado do eixo. De 7.2-10.0s, Noa procura dentro do aro; termine quando a primeira borda do fragmento aparece.',
        audioPrompt:
            'VOICE LOCK LYS: mulher brasileira de 23 anos, registro medio-grave, timbre quente levemente rouco, cadencia habitual agil, consoantes claras. VOICE LOCK TARIK: homem brasileiro de 28 anos, registro grave, timbre escuro limpo, cadencia medida, consoantes controladas. [1.2-3.1s] LYS: "Então desconta de mim." [4.4-6.8s] TARIK: "Você já passou do limite." Pt-BR apenas, linhas exatas, sem improviso. Continuar tempestade, terminal, respiracao e alarme; sem musica final.',
        notes:
            'Corte em acao sem first_frame: repetir estado, direcao, luz e geografia por prompt e referencias canonicas.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t03',
        number: 3,
        title: 'O fragmento de Mara',
        durationSeconds: 10,
        transitionMode: 'MATCH_ON_ACTION',
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Live-action fotorrealista, vertical 9:16, exatamente 10s. Comece com a mao de Noa ja retirando o fragmento azul-negro do aro; ele o entrega a Lys. Tarik reconhece o objeto, verifica o corredor, fecha a divisoria e baixa a voz. Preserve Lys e Noa a esquerda, Tarik a direita, fragmento unico na mao direita de Lys e geografia do Banco Termico. Termine quando Lys comeca a estende-lo ao centro.',
        audioPrompt:
            'VOICE LOCK NOA: garoto brasileiro de 14 anos, registro medio-agudo adolescente, timbre claro e soproso, cadencia calma, articulacao suave. VOICE LOCK TARIK: homem brasileiro de 28 anos, registro grave, timbre escuro limpo, cadencia medida, consoantes controladas. [1.0-3.6s] NOA: "A mãe disse pra usar só se eu piorasse." [4.8-8.4s] TARIK: "Isso não tem registro. Se eu conectar, a coleta vem." Pt-BR apenas, falas exatas, sem sobreposicao ou improviso.',
        notes:
            'Corte no movimento da mao de Noa; Lumen percorre Noa -> Lys e continua unico.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t04',
        number: 4,
        title: 'O preco',
        durationSeconds: 10,
        transitionMode: 'MATCH_ON_ACTION',
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Live-action fotorrealista, vertical 9:16, exatamente 10s. Comece com Lys ja entregando o fragmento pelo centro e Tarik recebendo-o pela direita. Ele encaixa o Lumen no soquete termico enquanto Noa piora no banco esquerdo; o terminal pulsa um pedido abstrato de memoria e Noa tenta impedir a irma. Termine com a mao de Lys comecando a subir em direcao ao rosto de Noa.',
        audioPrompt:
            'VOICE LOCK LYS: mulher brasileira de 23 anos, registro medio-grave, timbre quente levemente rouco, cadencia agil. VOICE LOCK TARIK: homem brasileiro de 28 anos, registro grave, timbre escuro limpo, cadencia medida. VOICE LOCK NOA: garoto brasileiro de 14 anos, registro medio-agudo, timbre claro e soproso, articulacao suave. [1.0-2.8s] LYS: "Se não conectar, ele morre aqui." [3.6-5.6s] TARIK: "Ele vai cobrar uma lembrança." [6.4-8.6s] NOA: "Você já deu a voz do pai." Pt-BR apenas; linhas exatas; ambiente continuo.',
        notes:
            'Corte na entrega do fragmento; apos 3.6s ele permanece encaixado no soquete central.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t05',
        number: 5,
        title: 'A escolha',
        durationSeconds: 10,
        transitionMode: 'SOFT_CONTINUITY',
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Live-action fotorrealista, drama intimo, vertical 9:16, exatamente 10s. Lys conclui o gesto no rosto de Noa, levanta, remove somente a luva direita e oferece a palma sobre o Lumen sem toca-lo. Preserve o cordao vermelho no pulso direito, a luva mecanica no antebraco esquerdo e o fragmento no soquete central. De 8.2-10.0s, um pulso ambar viaja ao terminal; cortar durante o movimento.',
        audioPrompt:
            'VOICE LOCK LYS: mulher brasileira de 23 anos, registro medio-grave, timbre quente levemente rouco, cadencia agil, consoantes claras. VOICE LOCK TARIK: homem brasileiro de 28 anos, registro grave, timbre escuro limpo, cadencia medida, finais controlados. [1.0-2.6s] LYS: "E você ainda está aqui." [3.3-5.4s] TARIK: "Escolhe uma. Seja específica." [6.2-8.2s] LYS: "O rosto da minha mãe." Pt-BR apenas, falas exatas, sem voz nas bordas ou improviso.',
        notes:
            'A palma direita ainda fica acima do cristal; o contato so ocorre no take 6.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t06',
        number: 6,
        title: 'O nome conhecido',
        durationSeconds: 10,
        transitionMode: 'MATCH_ON_ACTION',
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Live-action fotorrealista, misterio sci-fi, vertical 9:16, exatamente 10s. Comece com o pulso ambar ja chegando ao terminal. Tarik reconhece Mara; Lys percebe. Aos 4.6s, o alarme de Noa fica continuo e ele perde o ar. Lys abandona a pergunta e pressiona a palma direita no cristal. O calor corre pelo tubo e uma silhueta ambar incompleta comeca a se formar; terminar antes do rosto aparecer.',
        audioPrompt:
            'VOICE LOCK TARIK: homem brasileiro de 28 anos, registro grave, timbre escuro limpo, cadencia medida, consoantes controladas. VOICE LOCK LYS: mulher brasileira de 23 anos, registro medio-grave, timbre quente levemente rouco, cadencia agil. [1.0-2.3s] TARIK: "Mara Arven?" [3.0-4.6s] LYS: "Como você sabe?" Depois de 4.6s, nenhuma fala: alarme continuo, perda de respiracao, tubo aquecendo e reverb frio. Pt-BR apenas, sem improviso.',
        notes:
            'Corte no pulso ambar; calor e silhueta continuam diretamente no take 7 sem first_frame.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t07',
        number: 7,
        title: 'Quem e ela?',
        durationSeconds: 10,
        transitionMode: 'MATCH_ON_ACTION',
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Live-action fotorrealista, revelacao emocional sci-fi, vertical 9:16, exatamente 10s. Comece com o calor ja entrando no aro e a silhueta ainda incompleta. O gelo derrete, Noa respira e o eco de Mara se resolve acima do cristal. Lys observa com desconhecimento genuino. Mara e uma identidade ficticia propria, 45 anos, cabelos escuros com fios prateados e cicatriz curta no queixo; nao clonar o rosto de Lys. Termine quando a projecao comeca a fragmentar.',
        audioPrompt:
            'VOICE LOCK LYS: mulher brasileira de 23 anos, registro medio-grave e timbre quente levemente rouco. VOICE LOCK NOA: garoto brasileiro de 14 anos, registro medio-agudo e timbre claro soproso. VOICE LOCK MARA: mulher brasileira de 45 anos, registro medio-grave, timbre quente cheio, cadencia precisa e reverb cristalino discreto permanente como eco. [1.2-2.4s] LYS: "Quem é ela?" [3.0-4.0s] NOA: "Nossa mãe." [4.8-8.8s] MARA: "Lys, pega o Noa e foge. Eles querem o que ele lembra." Pt-BR apenas, linhas exatas.',
        notes:
            'Tarik permanece visivel e silencioso a direita. Mara e prompt-only ate existir referencia visual canonica propria.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t08',
        number: 8,
        title: 'Coleta autorizada',
        durationSeconds: 10,
        transitionMode: 'MATCH_ON_ACTION',
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Live-action fotorrealista, thriller sci-fi, vertical 9:16, exatamente 10s. Comece com a projecao terminando de desaparecer. A porta de aco atras de Tarik fecha e luzes vermelhas substituem o ambar. Tarik se coloca entre a porta e os irmaos; Lys protege Noa a esquerda. De 8.0-9.2s, a mao direita de Tarik vai ao bastao; de 9.2-10.0s, os dedos fazem primeiro contato. Corte imediato, sem sacar ou revelar seu lado.',
        audioPrompt:
            'VOICE LOCK SISTEMA: voz feminina sintetica, registro medio, timbre frio vitreo, cadencia uniforme, articulacao mecanica e processamento leve de terminal; nenhuma boca visivel faz lip sync. [1.2-5.6s] SISTEMA: "Eco proibido detectado. Coleta autorizada: Noa Arven." Depois, sem fala: porta, passos armados, alarme e respiracao. Pt-BR apenas, sem ordens de agentes, gritos ou improviso; musica sem resolucao.',
        notes:
            'Corte exato no primeiro contato da mao de Tarik com o bastao; nenhuma reacao ou resposta depois do pico.',
      ),
    ];

    return ProductionProject(
      id: 'nivalis-memorias-de-gelo',
      virtualId: -1001,
      title: 'Nivalis: Memórias de Gelo',
      description:
          'Em um planeta congelado, calor custa memorias. Lys sacrifica o rosto da mae para salvar o irmao e desperta um segredo proibido.',
      genre: 'ficcao cientifica / drama familiar',
      formatFamily: 'vertical_series',
      status: 'IN_PRODUCTION',
      sourcePath: 'series_bibles/nivalis-memorias-de-gelo',
      coverAssetPath:
          'series_bibles/nivalis-memorias-de-gelo/location_references/location_reference_banco_termico_film_real_v6.png',
      targetEpisodeCount: 12,
      isLocal: true,
      updatedAt: DateTime(2026, 8, 10),
      seriesBible: const {
        'package_version': '4.0.0',
        'package_status': 'LOCKED',
        'story_source':
            'series_bibles/nivalis-memorias-de-gelo/locked_script_package_v4.md',
        'production_source':
            'series_bibles/nivalis-memorias-de-gelo/episode_01_takes_10s_v4.md',
        'logline':
            'Em um planeta onde calor custa lembrancas, Lys sacrifica o rosto da mae para salvar o irmao e descobre que o inverno eterno e mantido pela familia do fiscal obrigado a caca-la.',
        'distribution_profile': 'validation_pilot',
        'provider_take_limit_seconds': 10,
        'first_frame_policy': 'disabled_in_vertix_flow',
        'visual_reference_mode': 'hybrid_face_compat',
        'world_environment_master': 'Mercado Baixo exterior',
        'location_master': 'Banco Termico de Emergencia',
        'audio_strategy':
            'Seedance sem musica final; vozes, musica, ambiente e SFX em faixas separadas.',
        'spatial_axis':
            'Lys/Noa a esquerda, Lumen no centro, Tarik/terminal a direita, coletores ao fundo direito.',
      },
      episodes: [
        ProductionEpisodeItem(
          number: 1,
          title: 'O ultimo fragmento',
          summary:
              'O credito termico e recusado. Lys usa um fragmento ilegal e entrega a lembranca do rosto da mae para impedir que o colar de Noa congele.',
          cliffhanger:
              'O sistema autoriza a coleta de Noa; Tarik toca o bastao e precisa escolher um lado.',
          durationSeconds: 80,
          takes: takes,
          externalMusic: true,
          musicProvider: 'API de musica (a definir)',
          musicPrompt:
              'Cama minimalista glacial de 80 segundos, cordas graves, pulsacao baixa e cristal discreto; crescer apos 50s e cortar antes de resolver no cliffhanger. Sem voz.',
          musicStatus: 'READY',
        ),
      ],
      references: references,
    );
  }

  static ProductionProject _draftProject({
    required String id,
    required int virtualId,
    required String title,
    required String description,
    required String genre,
    required String formatFamily,
    required String sourcePath,
    String? coverAssetPath,
    String? coverUrl,
    int targetEpisodeCount = 12,
    int takeCount = 4,
    bool isLocal = true,
  }) {
    final takes = _defaultTakes(title, count: takeCount);
    return ProductionProject(
      id: id,
      virtualId: virtualId,
      title: title,
      description: description,
      genre: genre,
      formatFamily: formatFamily,
      status: 'DRAFT',
      sourcePath: sourcePath,
      coverAssetPath: coverAssetPath,
      coverUrl: coverUrl,
      targetEpisodeCount: targetEpisodeCount,
      isLocal: isLocal,
      updatedAt: DateTime(2026, 8, 8),
      seriesBible: {
        'logline': description,
        'pipeline': 'episode-first / takes de ate 15 segundos',
        'audio_strategy':
            'Musica externa, dialogo, ambiente e efeitos em faixas separadas.',
      },
      episodes: [
        ProductionEpisodeItem(
          number: 1,
          title: 'Piloto',
          summary:
              'Tratamento local pronto para ser refinado antes da geracao dos takes.',
          cliffhanger:
              'Defina o corte que faz o publico pedir o proximo episodio.',
          durationSeconds: takes.fold(
            0,
            (sum, take) => sum + take.durationSeconds,
          ),
          takes: takes,
          musicPrompt:
              'Criar uma cama musical continua coerente com $genre, sem voz e com espaco para dialogo.',
        ),
      ],
      references: const [],
    );
  }

  static List<ProductionTakeItem> _defaultTakes(String title, {int count = 4}) {
    const beats = [
      'Gancho visual',
      'Pressao e escolha',
      'Reversao',
      'Cliffhanger',
      'Consequencia',
    ];
    return List.generate(count, (index) {
      final number = index + 1;
      return ProductionTakeItem(
        id: '${title.toLowerCase().replaceAll(' ', '-')}-take-$number',
        number: number,
        title: beats[index % beats.length],
        durationSeconds: 15,
        status: index == 0 ? 'READY' : 'DRAFT',
        transitionMode: number > 1 ? 'SOFT_CONTINUITY' : 'EPISODE_START',
        usePreviousLastFrame: number > 1,
        visualPrompt:
            '$title — Take $number. Vertical 9:16, 15 segundos. Descreva um unico beat visivel, preserve o estado herdado e termine com uma ponte clara para o proximo take.',
        audioPrompt:
            'Dialogo pt-BR dentro de 1.0s-14.0s. Sem musica final do gerador; manter voz e ambiente apenas como rascunho.',
      );
    });
  }
}
