import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_service.dart';

int? _asEpisodeNumber(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

final _genericEpisodeTitlePattern = RegExp(
  r'^epis[oó]dio\s*\d+$',
  caseSensitive: false,
);

final _generatingEpisodeTitlePattern = RegExp(
  r'^gerando epis[oó]dio',
  caseSensitive: false,
);

bool _isPlaceholderEpisodeTitle(String title) {
  final value = title.trim();
  if (value.isEmpty) return true;
  return _genericEpisodeTitlePattern.hasMatch(value) ||
      _generatingEpisodeTitlePattern.hasMatch(value);
}

bool _looksLikeJsonBlob(String value) {
  final text = value.trim();
  if (text.length < 2) return false;
  return (text.startsWith('{') && text.contains('}')) ||
      (text.startsWith('[') && text.contains(']'));
}

String _humanReadableText(dynamic value) {
  if (value == null) return '';
  if (value is Map) {
    for (final key in const [
      'summary',
      'treatment',
      'story',
      'text',
      'description',
      'cold_open',
      'logline',
      'title',
    ]) {
      final nested = _humanReadableText(value[key]);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  if (value is Iterable && value is! String) {
    for (final item in value) {
      final nested = _humanReadableText(item);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null' || text == 'undefined') return '';
  if (_looksLikeJsonBlob(text)) {
    try {
      return _humanReadableText(jsonDecode(text));
    } catch (_) {
      return '';
    }
  }
  return text;
}

List<Map<String, dynamic>> _asObjectList(dynamic value) {
  if (value is String && _looksLikeJsonBlob(value)) {
    try {
      return _asObjectList(jsonDecode(value));
    } catch (_) {
      return const [];
    }
  }
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _normalizeSceneCard(
  Map<String, dynamic> scene, {
  required int fallbackNumber,
}) {
  final number =
      _asEpisodeNumber(scene['scene']) ??
      _asEpisodeNumber(scene['scene_number']) ??
      _asEpisodeNumber(scene['sceneNumber']) ??
      _asEpisodeNumber(scene['number']) ??
      fallbackNumber;
  final location = _humanReadableText(
    scene['location'] ??
        scene['location_name'] ??
        scene['locationName'] ??
        scene['setting'] ??
        scene['place'] ??
        scene['time_and_location'] ??
        scene['environment'],
  );
  final castRaw = scene['cast'] ?? scene['characters'] ?? scene['speakers'];
  final cast = castRaw is List
      ? castRaw
            .map(_humanReadableText)
            .where((item) => item.isNotEmpty)
            .toList()
      : [
          if (_humanReadableText(castRaw).isNotEmpty)
            _humanReadableText(castRaw),
        ];
  final title = _humanReadableText(
    scene['title'] ?? scene['name'] ?? scene['heading'],
  );
  final story = _humanReadableText(
    scene['story'] ??
        scene['description'] ??
        scene['synopsis'] ??
        scene['beats'] ??
        scene['action'] ??
        scene['summary'],
  );
  return {
    ...scene,
    'scene': number,
    if (title.isNotEmpty) 'title': title,
    if (location.isNotEmpty) 'location': location,
    'cast': cast,
    if (story.isNotEmpty) 'story': story,
  };
}

List<Map<String, dynamic>> _normalizeSceneCards(dynamic value) {
  final cards = _asObjectList(value);
  return [
    for (var index = 0; index < cards.length; index++)
      _normalizeSceneCard(cards[index], fallbackNumber: index + 1),
  ];
}

Map<String, dynamic> _flattenSeriesBible(Map<String, dynamic> bible) {
  final nested = bible['seriesBible'];
  if (nested is! Map) return Map<String, dynamic>.from(bible);
  final flattened = <String, dynamic>{
    ...Map<String, dynamic>.from(nested),
    ...bible,
  };
  flattened.remove('seriesBible');
  return flattened;
}

const _microDramaFormatFamily = 'micro_drama_vertical';

bool _bibleLooksLikeMicroDrama(Map<String, dynamic> bible) {
  final workflow = bible['creation_workflow']?.toString() ?? '';
  if (workflow.contains('microdrama') ||
      workflow.contains('chat_first') ||
      workflow.contains('openrouter') ||
      workflow.contains('outline_first')) {
    return true;
  }
  final stage = bible['creation_stage']?.toString() ?? '';
  if (stage.isNotEmpty) return true;
  final preset = bible['style_preset_id']?.toString() ?? '';
  if (preset.contains('microdrama')) return true;
  if (bible['studio_chat'] != null || bible['studio_ui'] != null) {
    return true;
  }
  if (_asObjectList(bible['episode_scripts']).isNotEmpty) return true;
  final source = bible['source']?.toString() ?? '';
  if (source == 'vertix-app') return true;
  return false;
}

String _resolvedFormatFamily(
  String? explicit, {
  required Map<String, dynamic> bible,
}) {
  if (explicit == _microDramaFormatFamily || _bibleLooksLikeMicroDrama(bible)) {
    return _microDramaFormatFamily;
  }
  return (explicit == null || explicit.trim().isEmpty)
      ? 'vertical_series'
      : explicit;
}

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

int _readInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
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
  final DateTime? updatedAt;
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
    this.updatedAt,
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
      updatedAt: project.updatedAt,
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
      updatedAt: summary.updatedAt ?? summary.productionPlan?.updatedAt,
      remoteSummary: summary,
    );
  }
}

int studioCatalogStatusRank(String status) {
  switch (status) {
    case 'IN_PRODUCTION':
      return 0;
    case 'PUBLISHED':
      return 1;
    case 'DRAFT':
      return 2;
    default:
      return 3;
  }
}

int compareStudioCatalogItems(
  ProductionCatalogItem a,
  ProductionCatalogItem b,
) {
  final rank = studioCatalogStatusRank(
    a.status,
  ).compareTo(studioCatalogStatusRank(b.status));
  if (rank != 0) return rank;
  final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bTime.compareTo(aTime);
}

class ProductionReferenceItem {
  final String id;
  final String label;
  final String category;
  final String? assetPath;
  final String? publicUrl;
  final String description;
  final bool canonical;
  final Map<String, dynamic> metadata;

  const ProductionReferenceItem({
    required this.id,
    required this.label,
    required this.category,
    this.assetPath,
    this.publicUrl,
    this.description = '',
    this.canonical = false,
    this.metadata = const {},
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
        metadata: Map<String, dynamic>.from(
          json['metadata'] as Map? ?? const {},
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'category': category,
    'assetPath': assetPath,
    'publicUrl': publicUrl,
    'description': description,
    'canonical': canonical,
    'metadata': metadata,
  };
}

class ProductionTakeItem {
  final String id;
  final int number;
  final String title;
  final int durationSeconds;
  final String status;
  final double progress;
  final String aiShortCore;
  final String visualPrompt;
  final String audioPrompt;
  final String stylePresetId;
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
    this.aiShortCore = '',
    this.visualPrompt = '',
    this.audioPrompt = '',
    this.stylePresetId = '',
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
        number: _readInt(json['number'], fallback: 1),
        title: json['title'] as String? ?? 'Take',
        durationSeconds: _readInt(json['durationSeconds'], fallback: 10),
        status: json['status'] as String? ?? 'READY',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        aiShortCore: json['aiShortCore'] as String? ?? '',
        visualPrompt: json['visualPrompt'] as String? ?? '',
        audioPrompt: json['audioPrompt'] as String? ?? '',
        stylePresetId: json['stylePresetId'] as String? ?? '',
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
    String? id,
    int? number,
    String? title,
    int? durationSeconds,
    String? status,
    double? progress,
    String? aiShortCore,
    String? visualPrompt,
    String? audioPrompt,
    String? stylePresetId,
    String? transitionMode,
    bool? usePreviousLastFrame,
    bool? generateSeedanceAudio,
    List<String>? referenceIds,
    String? outputUrl,
    String? lastFrameLabel,
    String? notes,
  }) => ProductionTakeItem(
    id: id ?? this.id,
    number: number ?? this.number,
    title: title ?? this.title,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    aiShortCore: aiShortCore ?? this.aiShortCore,
    visualPrompt: visualPrompt ?? this.visualPrompt,
    audioPrompt: audioPrompt ?? this.audioPrompt,
    stylePresetId: stylePresetId ?? this.stylePresetId,
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
    'aiShortCore': aiShortCore,
    'visualPrompt': visualPrompt,
    'audioPrompt': audioPrompt,
    'stylePresetId': stylePresetId,
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
        number: _readInt(json['number'], fallback: 1),
        title: json['title'] as String? ?? 'Episodio',
        summary: json['summary'] as String? ?? '',
        cliffhanger: json['cliffhanger'] as String? ?? '',
        durationSeconds: _readInt(json['durationSeconds'], fallback: 60),
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
        virtualId: _readInt(json['virtualId'], fallback: -9999),
        title: json['title'] as String? ?? 'Obra sem titulo',
        description: json['description'] as String? ?? '',
        genre: json['genre'] as String? ?? 'vertical',
        formatFamily: _resolvedFormatFamily(
          json['formatFamily'] as String?,
          bible: Map<String, dynamic>.from(
            json['seriesBible'] as Map? ?? const {},
          ),
        ),
        status: json['status'] as String? ?? 'DRAFT',
        sourcePath: json['sourcePath'] as String? ?? 'Local',
        coverAssetPath: json['coverAssetPath'] as String?,
        coverUrl: json['coverUrl'] as String?,
        targetEpisodeCount: _readInt(json['targetEpisodeCount'], fallback: 12),
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
    String? id,
    int? virtualId,
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
    id: id ?? this.id,
    virtualId: virtualId ?? this.virtualId,
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
  final int maxShotDurationSeconds;
  final bool automaticReview;
  final bool automaticPreparation;

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
    this.maxShotDurationSeconds = 10,
    this.automaticReview = true,
    this.automaticPreparation = false,
  });

  String get distributionProfile =>
      episodeCount >= 50 ? 'app_native' : 'validation_pilot';

  bool get isSingleEpisode => episodeCount <= 1;

  MicroDramaProjectConfig copyWith({
    String? title,
    String? logline,
    String? centralQuestion,
    String? protagonist,
    String? opposingForce,
    String? stakes,
    String? genre,
    String? background,
    String? trope,
    String? visualStyle,
    String? language,
    String? rating,
    int? episodeCount,
    int? firstEpisodeDurationSeconds,
    int? episodeDurationSeconds,
    int? maxShotDurationSeconds,
    bool? automaticReview,
    bool? automaticPreparation,
  }) => MicroDramaProjectConfig(
    title: title ?? this.title,
    logline: logline ?? this.logline,
    centralQuestion: centralQuestion ?? this.centralQuestion,
    protagonist: protagonist ?? this.protagonist,
    opposingForce: opposingForce ?? this.opposingForce,
    stakes: stakes ?? this.stakes,
    genre: genre ?? this.genre,
    background: background ?? this.background,
    trope: trope ?? this.trope,
    visualStyle: visualStyle ?? this.visualStyle,
    language: language ?? this.language,
    rating: rating ?? this.rating,
    episodeCount: episodeCount ?? this.episodeCount,
    firstEpisodeDurationSeconds:
        firstEpisodeDurationSeconds ?? this.firstEpisodeDurationSeconds,
    episodeDurationSeconds:
        episodeDurationSeconds ?? this.episodeDurationSeconds,
    maxShotDurationSeconds:
        maxShotDurationSeconds ?? this.maxShotDurationSeconds,
    automaticReview: automaticReview ?? this.automaticReview,
    automaticPreparation: automaticPreparation ?? this.automaticPreparation,
  );
}

class _MicroDramaStylePreset {
  final String id;
  final String label;
  final String mediaCategory;
  final String cinematographyLock;
  final String audioLock;
  final String visualStyleLock;
  final String textLock;
  final String negativeLock;
  final String mediumLock;

  const _MicroDramaStylePreset({
    required this.id,
    required this.label,
    required this.mediaCategory,
    required this.cinematographyLock,
    required this.audioLock,
    required this.visualStyleLock,
    required this.textLock,
    required this.negativeLock,
    required this.mediumLock,
  });

  String get compiledSuffix => <String>[
    '$cinematographyLock $audioLock',
    'Visual style: $visualStyleLock',
    textLock,
    negativeLock,
    mediumLock,
  ].join('\n\n');
}

class _MicroDramaEpisodePlan {
  final String title;
  final String job;
  final String coldOpen;
  final String goal;
  final String emotionalBeat;
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
    required this.emotionalBeat,
    required this.protagonistStep,
    required this.countermove,
    required this.valueChange,
    required this.summary,
    required this.cliffhanger,
  });
}

class _MicroDramaCreativePackage {
  final List<Map<String, dynamic>> characters;
  final List<Map<String, dynamic>> environments;
  final List<Map<String, dynamic>> props;
  final List<ProductionReferenceItem> references;

  const _MicroDramaCreativePackage({
    required this.characters,
    required this.environments,
    required this.props,
    required this.references,
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
      _cache = projects.map(_ensureMicroDramaCreativePackage).toList();
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
    ProductionProject? fromApi;
    final snapshot = _projectFromEditorSnapshot(item, remotePlan);
    if (snapshot != null) {
      fromApi = _hydrateRemoteProject(snapshot, remotePlan);
    }
    ProductionProject? overlay;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('$_remoteOverlayPrefix${item.routeId}');
    if (saved != null && saved.isNotEmpty) {
      try {
        overlay = _hydrateRemoteProject(
          ProductionProject.fromJson(
            Map<String, dynamic>.from(jsonDecode(saved) as Map),
          ),
          remotePlan,
        );
      } catch (_) {}
    }
    final remote = _hydrateRemoteProject(
      _projectFromRemote(item, remotePlan),
      remotePlan,
    );
    return selectPersistedProject(
      apiProject: fromApi,
      overlayProject: overlay,
      remoteProject: remote,
    );
  }

  @visibleForTesting
  ProductionProject hydrateRemoteProjectForTesting(
    ProductionProject project, [
    AdminSeriesProductionPlan? plan,
  ]) => _hydrateRemoteProject(project, plan);

  @visibleForTesting
  ProductionProject projectFromRemoteForTesting(
    ProductionCatalogItem item, [
    AdminSeriesProductionPlan? plan,
  ]) => _hydrateRemoteProject(_projectFromRemote(item, plan), plan);

  Future<ProductionProject> saveProject(ProductionProject project) async {
    var updated = _withSyncedEpisodeCards(
      project.copyWith(updatedAt: DateTime.now()),
    );
    try {
      await _persistLocalCopy(updated);
    } catch (error) {
      debugPrint('Falha ao persistir a producao localmente: $error');
    }
    updated = await persistProjectToApi(updated);
    try {
      await _persistLocalCopy(updated);
    } catch (error) {
      debugPrint('Falha ao atualizar a copia local da producao: $error');
    }
    return updated;
  }

  Future<void> _persistLocalCopy(ProductionProject project) async {
    if (project.isLocal || project.virtualId <= 0) {
      await _upsertLocalProject(project);
    }
    if (project.virtualId <= 0) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_remoteOverlayPrefix${project.virtualId}',
      jsonEncode(project.toJson()),
    );
  }

  @visibleForTesting
  bool shouldPersistProjectToApi(ProductionProject project) {
    final title = project.title.trim();
    if (title.isEmpty) return false;
    final emptyBrief =
        isMicroDramaChatBrief(project) &&
        project.episodes.isEmpty &&
        title == 'Novo microdrama';
    return !emptyBrief;
  }

  @visibleForTesting
  Map<String, dynamic> productionApiPayload(ProductionProject project) {
    final synced = _withSyncedEpisodeCards(project);
    final bible = Map<String, dynamic>.from(synced.seriesBible)
      ..remove('editor_project');
    final editor = synced
        .copyWith(seriesBible: Map<String, dynamic>.from(bible))
        .toJson();
    bible['editor_project'] = editor;
    final episodeCards = _asObjectList(bible['episode_cards']);
    return {
      'source': 'vertix-app',
      'replaceExisting': false,
      'collectImplicitReferences': false,
      'pipelineData': {
        'seriesBible': bible,
        'characterBible':
            bible['characters'] ?? bible['character_bible'] ?? const [],
        'locationBible':
            bible['environments'] ?? bible['location_bible'] ?? const [],
        'objectBible': bible['props'] ?? bible['object_bible'] ?? const [],
        'episodeMap': episodeCards.isNotEmpty
            ? episodeCards
            : bible['episodeMap'] ?? const [],
        'episodeTreatments': synced.episodes
            .map((episode) => episode.toJson())
            .toList(),
        'sceneCards': bible['scene_cards'] ?? const [],
        'generationPlan': bible['generation_plan'] ?? const [],
        'seedanceNotes': bible['seedance_notes'] ?? const {},
        'editor_project': Map<String, dynamic>.from(editor),
      },
    };
  }

  ProductionProject attachStudioSession(
    ProductionProject project, {
    required List<Map<String, dynamic>> chat,
    Map<String, dynamic> ui = const {},
  }) {
    final trimmedChat = chat.length <= 120
        ? chat
        : chat.sublist(chat.length - 120);
    return _withSyncedEpisodeCards(
      project.copyWith(
        seriesBible: {
          ...project.seriesBible,
          'studio_chat': trimmedChat,
          'studio_ui': ui,
        },
      ),
    );
  }

  List<Map<String, dynamic>> studioChatOf(ProductionProject project) =>
      _asObjectList(project.seriesBible['studio_chat']);

  Map<String, dynamic> studioUiOf(ProductionProject project) {
    final raw = project.seriesBible['studio_ui'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  @visibleForTesting
  ProductionProject adoptSavedProject({
    required ProductionProject current,
    required ProductionProject saved,
  }) {
    final seriesId = saved.virtualId > 0 ? saved.virtualId : current.virtualId;
    final currentWithIds = current.copyWith(
      id: seriesId > 0 ? 'remote-$seriesId' : current.id,
      virtualId: seriesId > 0 ? seriesId : current.virtualId,
      isLocal: seriesId > 0 ? false : current.isLocal,
      sourcePath: saved.sourcePath.isNotEmpty
          ? saved.sourcePath
          : current.sourcePath,
      seriesBible: {
        ...current.seriesBible,
        if (seriesId > 0) 'api_series_id': seriesId,
      },
    );
    return selectPersistedProject(
      apiProject: saved,
      overlayProject: currentWithIds,
      remoteProject: currentWithIds,
    );
  }

  @visibleForTesting
  ProductionProject selectPersistedProject({
    ProductionProject? apiProject,
    ProductionProject? overlayProject,
    required ProductionProject remoteProject,
  }) {
    var best = remoteProject;
    var bestScore = _projectPersistenceScore(remoteProject);
    for (final candidate in [apiProject, overlayProject]) {
      if (candidate == null) continue;
      final score = _projectPersistenceScore(candidate);
      final newer = candidate.updatedAt.isAfter(best.updatedAt);
      if (score > bestScore || (score == bestScore && newer)) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  int _projectPersistenceScore(ProductionProject project) {
    final outlined = project.episodes
        .where((episode) => episode.summary.trim().isNotEmpty)
        .length;
    final generating = project.episodes
        .where((episode) => episode.status == 'GENERATING')
        .length;
    final takes = project.episodes.fold<int>(
      0,
      (sum, episode) => sum + episode.takes.length,
    );
    var scriptScenes = 0;
    var scriptShots = 0;
    for (final script in _asObjectList(project.seriesBible['episode_scripts'])) {
      scriptScenes += _scriptSceneCount(script);
      scriptShots += _scriptShotCount(script);
    }
    return project.episodes.length * 10 +
        outlined * 25 +
        _asObjectList(project.seriesBible['episode_scripts']).length * 40 +
        scriptScenes * 20 +
        scriptShots * 4 +
        _asObjectList(project.seriesBible['episode_cards']).length * 8 +
        studioChatOf(project).length * 2 +
        takes * 6 -
        generating * 30 +
        (project.description.trim().isNotEmpty ? 4 : 0) +
        ((project.seriesBible['logline']?.toString().trim().isNotEmpty ??
                false)
            ? 4
            : 0);
  }

  int _scriptSceneCount(Map<String, dynamic> script) =>
      _asObjectList(script['scenes']).length;

  int _scriptShotCount(Map<String, dynamic> script) => _asObjectList(
    script['scenes'],
  ).fold<int>(0, (total, scene) => total + _asObjectList(scene['shots']).length);

  ProductionProject _withSyncedEpisodeCards(ProductionProject project) {
    final cards = _syncedEpisodeCards(
      episodes: project.episodes,
      existing: _asObjectList(project.seriesBible['episode_cards']),
      generated: const [],
    );
    if (_sameEpisodeCards(project.seriesBible['episode_cards'], cards)) {
      return project;
    }
    return project.copyWith(
      seriesBible: {...project.seriesBible, 'episode_cards': cards},
    );
  }

  bool _sameEpisodeCards(dynamic current, List<Map<String, dynamic>> next) {
    final existing = _asObjectList(current);
    if (existing.length != next.length) return false;
    for (var index = 0; index < existing.length; index++) {
      if (existing[index]['episode'] != next[index]['episode'] ||
          existing[index]['title'] != next[index]['title'] ||
          existing[index]['summary'] != next[index]['summary'] ||
          existing[index]['treatment'] != next[index]['treatment'] ||
          existing[index]['cliffhanger'] != next[index]['cliffhanger']) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _syncedEpisodeCards({
    required List<ProductionEpisodeItem> episodes,
    required List<Map<String, dynamic>> existing,
    required List<Map<String, dynamic>> generated,
  }) {
    final byNumber = <int, Map<String, dynamic>>{};
    for (final card in [...existing, ...generated]) {
      final number =
          _asEpisodeNumber(card['episode']) ?? _asEpisodeNumber(card['number']);
      if (number == null) continue;
      byNumber[number] = {...?byNumber[number], ...card, 'episode': number};
    }
    for (final episode in episodes) {
      final current =
          byNumber[episode.number] ??
          <String, dynamic>{'episode': episode.number};
      byNumber[episode.number] = {
        ...current,
        'title': episode.title,
        if (episode.summary.trim().isNotEmpty) 'summary': episode.summary,
        if (episode.summary.trim().isNotEmpty)
          'treatment': current['treatment'] ?? episode.summary,
        if (episode.cliffhanger.trim().isNotEmpty)
          'cliffhanger': episode.cliffhanger,
        if (episode.cliffhanger.trim().isNotEmpty)
          'peak_action': current['peak_action'] ?? episode.cliffhanger,
        'duration_seconds': episode.durationSeconds,
        'status': episode.status,
        'script_status':
            current['script_status'] ??
            (episode.takes.isEmpty ? 'NOT_STARTED' : 'DRAFT_REVIEW_REQUIRED'),
      };
    }
    final numbers = byNumber.keys.toList()..sort();
    return [for (final number in numbers) byNumber[number]!];
  }

  final Map<String, int> _knownApiIds = {};
  final Map<String, Future<ProductionProject>> _persistInFlight = {};

  Future<ProductionProject> persistProjectToApi(
    ProductionProject project,
  ) async {
    if (!shouldPersistProjectToApi(project)) return project;
    final key = project.id;
    final inFlight = _persistInFlight[key];
    if (inFlight != null) {
      final promoted = await inFlight;
      project = project.copyWith(
        id: promoted.id,
        virtualId: promoted.virtualId,
        isLocal: false,
        sourcePath: promoted.sourcePath,
        seriesBible: {
          ...project.seriesBible,
          'api_series_id': promoted.virtualId,
        },
      );
    }
    final run = _persistProjectToApiBody(project);
    _persistInFlight[key] = run;
    try {
      return await run;
    } finally {
      if (identical(_persistInFlight[key], run)) {
        _persistInFlight.remove(key);
      }
    }
  }

  Future<ProductionProject> _persistProjectToApiBody(
    ProductionProject project,
  ) async {
    final admin = AdminService();
    var seriesId = project.virtualId > 0
        ? project.virtualId
        : _apiSeriesId(project) ?? _knownApiIds[project.id];
    final previousId = project.id;
    final previousVirtualId = project.virtualId;
    final wasLocal = project.isLocal || previousVirtualId <= 0;

    if (seriesId == null || seriesId <= 0) {
      final created = await admin.createSeries(
        title: project.title,
        description: project.description,
        genre: project.genre,
        totalEpisodes: project.targetEpisodeCount,
        status: project.status,
      );
      seriesId = _readSeriesId(created);
      if (seriesId == null) {
        throw StateError('A API nao devolveu o id da serie.');
      }
    } else {
      await admin.updateSeries(
        seriesId: seriesId,
        title: project.title,
        description: project.description,
        genre: project.genre,
        status: project.status,
        coverUrl: project.coverUrl,
      );
    }

    _knownApiIds[previousId] = seriesId;
    _knownApiIds['remote-$seriesId'] = seriesId;

    await admin.saveSeriesProduction(
      seriesId: seriesId,
      payload: productionApiPayload(project),
    );

    final remote = project.copyWith(
      id: 'remote-$seriesId',
      virtualId: seriesId,
      isLocal: false,
      sourcePath: 'Vertix API / serie $seriesId',
      seriesBible: {...project.seriesBible, 'api_series_id': seriesId},
    );
    if (wasLocal) {
      await _upsertLocalProject(
        remote.copyWith(id: previousId, virtualId: previousVirtualId),
      );
    }
    return remote;
  }

  int? _apiSeriesId(ProductionProject project) {
    final raw = project.seriesBible['api_series_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  int? _readSeriesId(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      final id = data['id'];
      if (id is int) return id;
      if (id is num) return id.toInt();
      return int.tryParse(id?.toString() ?? '');
    }
    return null;
  }

  Future<void> _upsertLocalProject(ProductionProject project) async {
    final projects = (await getProjects()).toList();
    final index = projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.add(project);
    }
    _cache = projects;
    await _persistLocalProjects();
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

  Future<ProductionProject> createMicroDramaChatDraft() async {
    final projects = (await getProjects()).toList();
    final minId = projects.fold<int>(
      -1000,
      (value, item) => item.virtualId < value ? item.virtualId : value,
    );
    final now = DateTime.now();
    final project = ProductionProject(
      id: 'microdrama-chat-${now.millisecondsSinceEpoch}',
      virtualId: minId - 1,
      title: 'Novo microdrama',
      description: 'Descreva a ideia no chat para gerar o contrato e o esboço.',
      genre: 'Romance com reviravolta',
      formatFamily: 'micro_drama_vertical',
      status: 'DRAFT',
      sourcePath: 'Workspace local / Microdrama / Novo microdrama',
      targetEpisodeCount: 8,
      isLocal: true,
      updatedAt: now,
      seriesBible: {
        'creation_stage': 'chat_brief',
        'creation_workflow': 'chat_first_v1',
        'creation_style_family': 'live_action',
        'package_status': 'AWAITING_CHAT_BRIEF',
        'distribution_profile': 'validation_pilot',
        'aspect_ratio': '9:16',
        'language': 'Português (Brasil)',
        'rating': '14 anos',
        'visual_style': 'Microdrama moderno',
        'style_preset_id': 'live_action_modern_microdrama_v1',
        'style_preset_media_category': 'live_action',
        'genre': 'Romance com reviravolta',
        'background': 'Cidade moderna',
        'trope': 'Segunda chance',
        'max_shot_duration_seconds': 10,
        'first_episode_duration_seconds': 120,
        'episode_duration_seconds': 60,
        'automatic_review': true,
        'automatic_preparation_requested': false,
        'automatic_preparation_status': 'MANUAL',
        'workflow': {
          'settings': 'DRAFT',
          'series_contract': 'NOT_STARTED',
          'outline': 'NOT_STARTED',
          'characters': 'NOT_STARTED',
          'environments': 'NOT_STARTED',
          'props': 'NOT_STARTED',
          'scripts': 'NOT_STARTED',
          'production': 'BLOCKED_BY_SCRIPT',
        },
      },
      episodes: const [],
      references: const [],
    );
    projects.insert(0, project);
    _cache = projects;
    await _persistLocalProjects();
    return project;
  }

  ProductionProject applyMicroDramaConfig(
    ProductionProject project,
    MicroDramaProjectConfig config, {
    String? creationIdea,
  }) {
    final built = _buildMicroDramaProject(
      config,
      id: project.id,
      virtualId: project.virtualId,
      updatedAt: DateTime.now(),
    );
    return built.copyWith(
      coverAssetPath: project.coverAssetPath,
      coverUrl: project.coverUrl,
      seriesBible: {
        ...built.seriesBible,
        'creation_stage': 'outline_ready',
        if (creationIdea != null && creationIdea.trim().isNotEmpty)
          'creation_idea': creationIdea.trim(),
        if (project.seriesBible['codex_thread_id'] != null)
          'codex_thread_id': project.seriesBible['codex_thread_id'],
        'creation_style_family':
            project.seriesBible['creation_style_family'] ??
            (config.visualStyle == 'Animação cinematográfica'
                ? 'animation'
                : 'live_action'),
      },
    );
  }

  ProductionProject patchMicroDramaChatBrief(
    ProductionProject project, {
    String? title,
    String? genre,
    String? background,
    String? trope,
    String? visualStyle,
    String? language,
    String? rating,
    String? styleFamily,
    int? episodeCount,
    int? firstEpisodeDurationSeconds,
    int? episodeDurationSeconds,
    int? maxShotDurationSeconds,
    bool? automaticReview,
    bool? automaticPreparation,
  }) {
    final bible = Map<String, dynamic>.from(project.seriesBible);
    if (genre != null) bible['genre'] = genre;
    if (background != null) bible['background'] = background;
    if (trope != null) bible['trope'] = trope;
    if (visualStyle != null) {
      bible['visual_style'] = visualStyle;
      bible['style_preset_id'] = _microDramaStylePreset(visualStyle).id;
      bible['style_preset_media_category'] = _microDramaStylePreset(
        visualStyle,
      ).mediaCategory;
    }
    if (language != null) bible['language'] = language;
    if (rating != null) bible['rating'] = rating;
    if (styleFamily != null) bible['creation_style_family'] = styleFamily;
    if (maxShotDurationSeconds != null) {
      bible['max_shot_duration_seconds'] = maxShotDurationSeconds;
    }
    if (firstEpisodeDurationSeconds != null) {
      bible['first_episode_duration_seconds'] = firstEpisodeDurationSeconds;
    }
    if (episodeDurationSeconds != null) {
      bible['episode_duration_seconds'] = episodeDurationSeconds;
    }
    if (automaticReview != null) bible['automatic_review'] = automaticReview;
    if (automaticPreparation != null) {
      bible['automatic_preparation_requested'] = automaticPreparation;
      bible['automatic_preparation_status'] = automaticPreparation
          ? 'QUEUED'
          : 'MANUAL';
    }
    return project.copyWith(
      title: title ?? project.title,
      genre: genre ?? project.genre,
      targetEpisodeCount: episodeCount ?? project.targetEpisodeCount,
      updatedAt: DateTime.now(),
      seriesBible: bible,
    );
  }

  static bool isMicroDramaVertical(ProductionProject project) =>
      project.formatFamily == _microDramaFormatFamily ||
      _bibleLooksLikeMicroDrama(project.seriesBible);

  static ProductionProject _ensureMicroDramaFormat(ProductionProject project) {
    if (project.formatFamily == _microDramaFormatFamily) return project;
    if (!isMicroDramaVertical(project)) return project;
    return project.copyWith(formatFamily: _microDramaFormatFamily);
  }

  static bool isMicroDramaChatBrief(ProductionProject project) {
    if (!isMicroDramaVertical(project)) return false;
    final stage = project.seriesBible['creation_stage']?.toString();
    return stage == 'chat_brief' || project.episodes.isEmpty;
  }

  @visibleForTesting
  ProductionProject buildMicroDramaChatDraftForTesting() => ProductionProject(
    id: 'microdrama-chat-test',
    virtualId: -9002,
    title: 'Novo microdrama',
    description: 'Descreva a ideia no chat para gerar o contrato e o esboço.',
    genre: 'Romance com reviravolta',
    formatFamily: 'micro_drama_vertical',
    status: 'DRAFT',
    sourcePath: 'Workspace local / Microdrama / Novo microdrama',
    targetEpisodeCount: 8,
    isLocal: true,
    updatedAt: DateTime(2026, 8, 17),
    seriesBible: const {
      'creation_stage': 'chat_brief',
      'visual_style': 'Microdrama moderno',
      'genre': 'Romance com reviravolta',
      'background': 'Cidade moderna',
      'trope': 'Segunda chance',
      'language': 'Português (Brasil)',
      'rating': '14 anos',
      'automatic_preparation_requested': false,
    },
    episodes: const [],
    references: const [],
  );

  @visibleForTesting
  ProductionProject buildMicroDramaProjectForTesting(
    MicroDramaProjectConfig config,
  ) => _buildMicroDramaProject(
    config,
    id: 'microdrama-test',
    virtualId: -9001,
    updatedAt: DateTime(2026, 8, 16),
  );

  @visibleForTesting
  ProductionProject ensureMicroDramaCreativePackageForTesting(
    ProductionProject project,
  ) => _ensureMicroDramaCreativePackage(project);

  ProductionProject generateMicroDramaEpisodeScript(
    ProductionProject project, {
    required int episodeNumber,
  }) {
    project = _ensureMicroDramaFormat(project);
    if (project.formatFamily != _microDramaFormatFamily) {
      throw ArgumentError('O projeto não é um microdrama vertical.');
    }
    final episodeIndex = project.episodes.indexWhere(
      (episode) => episode.number == episodeNumber,
    );
    if (episodeIndex < 0) {
      throw ArgumentError('Episódio $episodeNumber não encontrado.');
    }

    final config = _microDramaConfigFromProject(project);
    final creativePackage = _buildMicroDramaCreativePackage(config, project.id);
    final episodeCards =
        (project.seriesBible['episode_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final existingCardIndex = episodeCards.indexWhere(
      (card) => card['episode'] == episodeNumber,
    );
    final plan = _microDramaEpisodePlan(config, episodeNumber: episodeNumber);
    final card = existingCardIndex >= 0
        ? episodeCards[existingCardIndex]
        : <String, dynamic>{
            'episode': episodeNumber,
            'title': plan.title,
            'duration_seconds': project.episodes[episodeIndex].durationSeconds,
            'episode_job': plan.job,
            'stage_goal': plan.goal,
            'emotional_beat': plan.emotionalBeat,
            'treatment': plan.summary,
            'value_shift': plan.valueChange,
            'cold_open': plan.coldOpen,
            'immediate_goal': plan.goal,
            'antagonist_countermove': plan.countermove,
            'peak_action': plan.cliffhanger,
            'status': 'OUTLINE_REVIEW_REQUIRED',
            'script_status': 'NOT_STARTED',
          };
    if (existingCardIndex < 0) episodeCards.add(card);

    final episode = project.episodes[episodeIndex];
    final script = _buildMicroDramaEpisodeScript(
      config,
      projectId: project.id,
      episode: episode,
      card: card,
      creativePackage: creativePackage,
    );
    final episodes = project.episodes.toList();
    episodes[episodeIndex] = episode.copyWith(
      status: 'SCRIPT_DRAFT_REVIEW_REQUIRED',
      takes: const [],
    );

    card['script_status'] = 'DRAFT_REVIEW_REQUIRED';
    card['production_status'] = 'BLOCKED_BY_SCRIPT_APPROVAL';
    final episodeScripts =
        (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['episode'] != episodeNumber)
            .toList()
          ..add(script);
    episodeScripts.sort(
      (a, b) =>
          (a['episode'] as num? ?? 0).compareTo(b['episode'] as num? ?? 0),
    );
    final existingScenes =
        (project.seriesBible['scene_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((scene) => scene['episode'] != episodeNumber)
            .toList();
    final generatedScenes = (script['scenes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final sceneCards = [...existingScenes, ...generatedScenes]
      ..sort((a, b) {
        final episodeOrder = (a['episode'] as num? ?? 0).compareTo(
          b['episode'] as num? ?? 0,
        );
        if (episodeOrder != 0) return episodeOrder;
        return (a['scene'] as num? ?? 0).compareTo(b['scene'] as num? ?? 0);
      });
    final scriptedEpisodes = episodeScripts.length;
    final allScriptsCreated = scriptedEpisodes == episodes.length;
    final productionReadyEpisodes = episodes
        .where((item) => item.takes.isNotEmpty)
        .length;
    final shotCount = episodeScripts.fold<int>(0, (total, item) {
      final scenes = item['scenes'] as List<dynamic>? ?? const [];
      return total +
          scenes.whereType<Map>().fold<int>(
            0,
            (sceneTotal, scene) =>
                sceneTotal +
                (scene['shots'] as List<dynamic>? ?? const []).length,
          );
    });
    final workflow = Map<String, dynamic>.from(
      project.seriesBible['workflow'] as Map? ?? const {},
    );

    return project.copyWith(
      episodes: episodes,
      seriesBible: {
        ...project.seriesBible,
        'creation_workflow': 'guided_microdrama_v3_outline_first',
        'workflow': {
          ...workflow,
          'scripts': allScriptsCreated
              ? 'ALL_EPISODE_SCRIPT_DRAFTS_CREATED'
              : 'PARTIAL_EPISODE_SCRIPT_DRAFTS_CREATED',
          'production': productionReadyEpisodes == 0
              ? 'BLOCKED_BY_SCRIPT_APPROVAL'
              : 'PARTIAL_EPISODES_READY',
        },
        'episode_cards': episodeCards,
        'episode_scripts': episodeScripts,
        'scene_cards': sceneCards,
        'script_package': {
          'status': 'HUMAN_REVIEW_REQUIRED',
          'episodes': scriptedEpisodes,
          'scenes': sceneCards.length,
          'shots': shotCount,
          'duration_mode': 'VARIABLE_UP_TO_LIMIT',
          'max_shot_duration_seconds': config.maxShotDurationSeconds,
          'production_ready_episodes': productionReadyEpisodes,
          'generation_order': [
            'season_outline',
            'characters',
            'environments',
            'props',
            'episode_script_draft_on_demand',
            'human_script_approval',
            'production_prompt_compilation',
          ],
        },
      },
    );
  }

  /// Applies the compact result returned by the server-side Codex outline job.
  /// Existing locked/production-ready episodes and generated images are preserved.
  ProductionProject applyCodexSeriesOutline(
    ProductionProject project,
    Map<String, dynamic> output, {
    bool allowPartial = false,
    bool fillMissingSlots = false,
  }) {
    final result = _codexResult(output);
    final biblePatch = Map<String, dynamic>.from(
      result['seriesBiblePatch'] as Map? ?? const {},
    );
    final generatedEpisodes = (result['episodes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (generatedEpisodes.isEmpty && !allowPartial) {
      throw StateError('O Codex não retornou o esboço dos episódios.');
    }

    final existingByNumber = {
      for (final episode in project.episodes) episode.number: episode,
    };
    var episodes =
        generatedEpisodes
            .where((item) => ((item['number'] as num?)?.toInt() ?? 0) > 0)
            .map((item) {
              final number = (item['number'] as num?)?.toInt() ?? 0;
              if (number <= 0) throw StateError('Número de episódio inválido.');
              final existing = existingByNumber[number];
              if (existing != null &&
                  (existing.takes.isNotEmpty ||
                      existing.status.contains('PRODUCTION') ||
                      existing.status.contains('LOCKED'))) {
                return existing;
              }
              return ProductionEpisodeItem(
                number: number,
                title: item['title']?.toString().trim().isNotEmpty == true
                    ? item['title'].toString().trim()
                    : existing?.title ?? 'Episódio $number',
                summary: item['summary']?.toString() ?? existing?.summary ?? '',
                cliffhanger:
                    item['cliffhanger']?.toString() ??
                    existing?.cliffhanger ??
                    '',
                durationSeconds:
                    (item['durationSeconds'] as num?)?.toInt() ??
                    existing?.durationSeconds ??
                    60,
                status: 'OUTLINE_REVIEW_REQUIRED',
                takes: const [],
                externalMusic: existing?.externalMusic ?? true,
                musicProvider: existing?.musicProvider ?? 'API externa',
                musicPrompt: existing?.musicPrompt ?? '',
                musicStatus: existing?.musicStatus ?? 'DRAFT',
                musicVolume: existing?.musicVolume ?? 0.36,
                dialogueVolume: existing?.dialogueVolume ?? 0.9,
                ambienceVolume: existing?.ambienceVolume ?? 0.48,
              );
            })
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));

    if (fillMissingSlots) {
      final firstDuration =
          (project.seriesBible['first_episode_duration_seconds'] as num?)
              ?.toInt() ??
          120;
      final otherDuration =
          (project.seriesBible['episode_duration_seconds'] as num?)?.toInt() ??
          60;
      final byNumber = {
        for (final episode in episodes) episode.number: episode,
      };
      for (var number = 1; number <= project.targetEpisodeCount; number++) {
        if (byNumber.containsKey(number)) continue;
        final existing = existingByNumber[number];
        if (existing != null &&
            (existing.takes.isNotEmpty ||
                existing.status.contains('PRODUCTION') ||
                existing.status.contains('LOCKED'))) {
          byNumber[number] = existing;
          continue;
        }
        byNumber[number] = ProductionEpisodeItem(
          number: number,
          title: existing?.title ?? 'Gerando episódio $number...',
          summary: existing?.summary ?? '',
          cliffhanger: existing?.cliffhanger ?? '',
          durationSeconds:
              existing?.durationSeconds ??
              (number == 1 ? firstDuration : otherDuration),
          status: 'GENERATING',
          takes: const [],
          externalMusic: existing?.externalMusic ?? true,
          musicProvider: existing?.musicProvider ?? 'API externa',
          musicPrompt: existing?.musicPrompt ?? '',
          musicStatus: existing?.musicStatus ?? 'DRAFT',
          musicVolume: existing?.musicVolume ?? 0.36,
          dialogueVolume: existing?.dialogueVolume ?? 0.9,
          ambienceVolume: existing?.ambienceVolume ?? 0.48,
        );
      }
      episodes = byNumber.values.toList()
        ..sort((a, b) => a.number.compareTo(b.number));
    } else if (!allowPartial &&
        episodes.length != project.targetEpisodeCount) {
      throw StateError(
        'O Codex retornou ${episodes.length} episódios; o projeto exige ${project.targetEpisodeCount}.',
      );
    }

    final generatedReferences =
        (result['references'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => ProductionReferenceItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList();
    final referencesById = {
      for (final reference in generatedReferences) reference.id: reference,
    };
    for (final existing in project.references) {
      final generated = referencesById[existing.id];
      if (generated == null) {
        referencesById[existing.id] = existing;
      } else if (existing.publicUrl?.isNotEmpty == true ||
          existing.assetPath?.isNotEmpty == true) {
        referencesById[existing.id] = ProductionReferenceItem(
          id: existing.id,
          label: generated.label,
          category: generated.category,
          assetPath: existing.assetPath,
          publicUrl: existing.publicUrl,
          description: generated.description,
          canonical: existing.canonical || generated.canonical,
          metadata: {...existing.metadata, ...generated.metadata},
        );
      }
    }

    final generatedHookChain =
        (biblePatch['hook_chain'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final generatedEpisodeCards =
        (biblePatch['episode_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final mergedBible = <String, dynamic>{
      ...project.seriesBible,
      ...biblePatch,
      'creation_stage': 'outline_ready',
      'creation_workflow': 'openrouter_outline_first_v1',
      'workflow': {
        ...Map<String, dynamic>.from(
          project.seriesBible['workflow'] as Map? ?? const {},
        ),
        'outline': 'CODEX_DRAFT_REVIEW_REQUIRED',
        'scripts': 'NOT_STARTED',
        'production': 'BLOCKED_BY_SCRIPT_APPROVAL',
      },
      if (_codexThreadId(output) != null)
        'codex_thread_id': _codexThreadId(output),
      'codex_outline_summary': output['summary'],
    };
    mergedBible['hook_chain'] = _syncMicroDramaHookChain(
      episodes: episodes,
      generated: generatedHookChain,
      logline: mergedBible['logline']?.toString() ?? project.description,
      protagonist: mergedBible['protagonist']?.toString() ?? 'o protagonista',
      opposingForce:
          mergedBible['opposing_force']?.toString() ?? 'a força oposta',
      centralQuestion: mergedBible['central_question']?.toString() ?? '',
      language: mergedBible['language']?.toString() ?? 'Português (Brasil)',
    );
    mergedBible['episode_cards'] = _syncedEpisodeCards(
      episodes: episodes,
      existing: _asObjectList(project.seriesBible['episode_cards']),
      generated: generatedEpisodeCards,
    );

    final generatedTitle = [result['title'], biblePatch['title']]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (generatedTitle.isNotEmpty) {
      mergedBible['title'] = generatedTitle;
    }

    final lockedNumbers = {
      for (final episode in episodes)
        if (episode.takes.isNotEmpty ||
            episode.status.contains('PRODUCTION') ||
            episode.status.contains('LOCKED'))
          episode.number,
    };
    mergedBible['episode_scripts'] =
        (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (item) =>
                  lockedNumbers.contains(_asEpisodeNumber(item['episode'])),
            )
            .toList();
    mergedBible['scene_cards'] =
        (project.seriesBible['scene_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (item) =>
                  lockedNumbers.contains(_asEpisodeNumber(item['episode'])),
            )
            .toList();

    return _ensureMicroDramaFormat(project).copyWith(
      formatFamily: _microDramaFormatFamily,
      title: generatedTitle.isNotEmpty ? generatedTitle : project.title,
      description: biblePatch['logline']?.toString() ?? project.description,
      updatedAt: DateTime.now(),
      episodes: episodes,
      references: referencesById.values.toList(),
      seriesBible: mergedBible,
    );
  }

  /// Applies one detailed episode script returned by Codex after validating all
  /// row, shot, and episode duration sums.
  ProductionProject applyCodexEpisodeScript(
    ProductionProject project,
    Map<String, dynamic> output, {
    required int episodeNumber,
    bool allowPartial = false,
  }) {
    final result = _codexResult(output);
    final script = Map<String, dynamic>.from(
      result['episodeScript'] as Map? ?? const {},
    );
    if (script.isEmpty) {
      throw StateError('O Codex não retornou o roteiro do EP$episodeNumber.');
    }
    final returnedEpisode = _asEpisodeNumber(script['episode']);
    if (!allowPartial &&
        returnedEpisode != null &&
        returnedEpisode != episodeNumber) {
      throw StateError('O Codex não retornou o roteiro do EP$episodeNumber.');
    }
    script['episode'] = episodeNumber;
    final scenes = (script['scenes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) {
          final scene = Map<String, dynamic>.from(item);
          scene['episode'] = episodeNumber;
          return scene;
        })
        .toList();
    script['scenes'] = scenes;
    if (scenes.isEmpty && !allowPartial) {
      throw StateError('O roteiro não contém cenas.');
    }
    final existingScript =
        (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (item) => _asEpisodeNumber(item?['episode']) == episodeNumber,
              orElse: () => null,
            );
    final existingSceneCount = existingScript == null
        ? 0
        : _scriptSceneCount(existingScript);
    final existingShotCount = existingScript == null
        ? 0
        : _scriptShotCount(existingScript);
    final incomingShotCount = _scriptShotCount(script);
    if (allowPartial &&
        (scenes.length < existingSceneCount ||
            (scenes.length == existingSceneCount &&
                incomingShotCount < existingShotCount))) {
      return project;
    }
    if (allowPartial && scenes.isEmpty) {
      return project;
    }
    if (scenes.isNotEmpty) {
      try {
        _validateCodexEpisodeScript(project, script, episodeNumber);
      } catch (error) {
        if (!allowPartial) {
          final gate = Map<String, dynamic>.from(
            script['quality_gate'] as Map? ?? const {},
          );
          script['quality_gate'] = {
            ...gate,
            'decision': 'PASS_HUMAN_REVIEW_REQUIRED',
            'duration_sums': 'NEEDS_HUMAN_FIX',
            'persist_warning': error.toString(),
          };
        }
      }
    }

    final episodeIndex = project.episodes.indexWhere(
      (episode) => episode.number == episodeNumber,
    );
    if (episodeIndex < 0) throw StateError('Episódio não encontrado.');
    final episodePatch = Map<String, dynamic>.from(
      result['episode'] as Map? ?? const {},
    );
    final currentEpisode = project.episodes[episodeIndex];
    final patchTitle = episodePatch['title']?.toString().trim() ?? '';
    final nextTitle = patchTitle.isNotEmpty && !_isPlaceholderEpisodeTitle(patchTitle)
        ? patchTitle
        : currentEpisode.title;
    final patchSummary = episodePatch['summary']?.toString().trim() ?? '';
    final patchCliffhanger =
        episodePatch['cliffhanger']?.toString().trim() ?? '';
    final episodes = project.episodes.toList();
    episodes[episodeIndex] = currentEpisode.copyWith(
      title: nextTitle,
      summary: patchSummary.isNotEmpty ? patchSummary : currentEpisode.summary,
      cliffhanger: patchCliffhanger.isNotEmpty
          ? patchCliffhanger
          : currentEpisode.cliffhanger,
      status: scenes.isEmpty ? currentEpisode.status : 'SCRIPT_DRAFT_REVIEW_REQUIRED',
      takes: currentEpisode.takes,
    );

    final scripts =
        (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => _asEpisodeNumber(item['episode']) != episodeNumber)
            .toList()
          ..add(script);
    scripts.sort(
      (a, b) => (_asEpisodeNumber(a['episode']) ?? 0).compareTo(
        _asEpisodeNumber(b['episode']) ?? 0,
      ),
    );
    final sceneCards =
        (project.seriesBible['scene_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => _asEpisodeNumber(item['episode']) != episodeNumber)
            .toList()
          ..addAll(scenes);
    final episodeCards =
        (project.seriesBible['episode_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(
              (item) => _asEpisodeNumber(item['episode']) == episodeNumber
                  ? {
                      ...item,
                      'script_status': scenes.isEmpty
                          ? 'GENERATING'
                          : 'DRAFT_REVIEW_REQUIRED',
                      'production_status': 'BLOCKED_BY_SCRIPT_APPROVAL',
                    }
                  : item,
            )
            .toList();

    return project.copyWith(
      updatedAt: DateTime.now(),
      episodes: episodes,
      seriesBible: {
        ...project.seriesBible,
        'episode_cards': episodeCards,
        'episode_scripts': scripts,
        'scene_cards': sceneCards,
        'workflow': {
          ...Map<String, dynamic>.from(
            project.seriesBible['workflow'] as Map? ?? const {},
          ),
          'scripts': 'PARTIAL_CODEX_SCRIPT_DRAFTS_CREATED',
          'production': 'BLOCKED_BY_SCRIPT_APPROVAL',
        },
        if (_codexThreadId(output) != null)
          'codex_thread_id': _codexThreadId(output),
        'codex_script_summary_ep$episodeNumber': output['summary'],
      },
    );
  }

  /// Locks the approved script using the existing deterministic workflow, then
  /// replaces only the dynamic prompt cores with Codex output. Fixed style and
  /// negative locks remain compiled by app code.
  ProductionProject applyCodexProductionScenes(
    ProductionProject project,
    Map<String, dynamic> output, {
    required int episodeNumber,
  }) {
    final locked = approveMicroDramaEpisodeScriptForProduction(
      _ensureMicroDramaFormat(project),
      episodeNumber: episodeNumber,
    );
    final result = _codexResult(output);
    final generatedTakes = (result['takes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final episodeIndex = locked.episodes.indexWhere(
      (episode) => episode.number == episodeNumber,
    );
    final episode = locked.episodes[episodeIndex];
    if (generatedTakes.length != episode.takes.length) {
      throw StateError(
        'O Codex retornou ${generatedTakes.length} takes; o roteiro bloqueado exige ${episode.takes.length}.',
      );
    }
    final generatedByNumber = {
      for (final item in generatedTakes)
        (item['number'] as num?)?.toInt() ?? -1: item,
    };
    final config = _microDramaConfigFromProject(locked);
    final fixedSuffix = _microDramaStylePreset(
      config.visualStyle,
    ).compiledSuffix;
    final takes = episode.takes.map((base) {
      final generated = generatedByNumber[base.number];
      if (generated == null) {
        throw StateError('Take ${base.number} ausente no retorno do Codex.');
      }
      final core = generated['aiShortCore']?.toString().trim() ?? '';
      if (core.isEmpty) {
        throw StateError('Take ${base.number} sem descrição de produção.');
      }
      return base.copyWith(
        title: generated['title']?.toString() ?? base.title,
        durationSeconds: base.durationSeconds,
        aiShortCore: core,
        visualPrompt: '$core\n\n$fixedSuffix',
        audioPrompt: generated['audioPrompt']?.toString() ?? base.audioPrompt,
        transitionMode:
            generated['transitionMode']?.toString() ?? base.transitionMode,
        usePreviousLastFrame: _readBool(
          generated['usePreviousLastFrame'],
          fallback: base.usePreviousLastFrame,
        ),
        generateSeedanceAudio: _readBool(
          generated['generateSeedanceAudio'],
          fallback: base.generateSeedanceAudio,
        ),
        referenceIds:
            (generated['referenceIds'] as List<dynamic>? ?? base.referenceIds)
                .map((item) => item.toString())
                .toList(),
        notes: generated['notes']?.toString() ?? base.notes,
      );
    }).toList();
    final episodes = locked.episodes.toList();
    episodes[episodeIndex] = episode.copyWith(takes: takes);

    final packages =
        (locked.seriesBible['production_prompt_packages'] as List<dynamic>? ??
                const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(
              (item) => (item['episode'] as num?)?.toInt() == episodeNumber
                  ? {
                      ...item,
                      ...Map<String, dynamic>.from(
                        result['productionPackage'] as Map? ?? const {},
                      ),
                      'episode': episodeNumber,
                      'style_decoration': 'CODE_OWNED_FIXED_PRESET',
                    }
                  : item,
            )
            .toList();
    return locked.copyWith(
      updatedAt: DateTime.now(),
      episodes: episodes,
      seriesBible: {
        ...locked.seriesBible,
        'production_prompt_packages': packages,
        if (_codexThreadId(output) != null)
          'codex_thread_id': _codexThreadId(output),
        'codex_production_summary_ep$episodeNumber': output['summary'],
      },
    );
  }

  ProductionProject applyGeneratedReferenceImage(
    ProductionProject project,
    Map<String, dynamic> output,
  ) {
    final result = _codexResult(output);
    final raw = Map<String, dynamic>.from(
      result['reference'] as Map? ?? const {},
    );
    if (raw['id'] == null || raw['publicUrl'] == null) {
      throw StateError('O servidor não retornou a imagem gerada.');
    }
    final generated = ProductionReferenceItem.fromJson(raw);
    final references = project.references.toList();
    final index = references.indexWhere((item) => item.id == generated.id);
    if (index >= 0) {
      final existing = references[index];
      references[index] = ProductionReferenceItem(
        id: existing.id,
        label: generated.label.isNotEmpty ? generated.label : existing.label,
        category: generated.category.isNotEmpty
            ? generated.category
            : existing.category,
        assetPath: existing.assetPath,
        publicUrl: generated.publicUrl,
        description: generated.description.isNotEmpty
            ? generated.description
            : existing.description,
        canonical: generated.canonical || existing.canonical,
        metadata: {...existing.metadata, ...generated.metadata},
      );
    } else {
      references.add(generated);
    }
    return project.copyWith(
      updatedAt: DateTime.now(),
      references: references,
      seriesBible: {
        ...project.seriesBible,
        'last_image_provider': 'gpt-image-2',
      },
    );
  }

  List<ProductionReferenceItem> automaticReferenceTargets(
    ProductionProject project, {
    bool regenerateExisting = false,
  }) {
    return project.references.where((reference) {
      final category = reference.category.toUpperCase();
      final isStoryMaster =
          category.contains('CHARACTER') ||
          category.contains('OPPOSING_FORCE') ||
          category.contains('LOCATION') ||
          category.contains('ENVIRONMENT') ||
          category.contains('WORLD') ||
          category.contains('PROP') ||
          category.contains('OBJECT');
      if (!reference.canonical || !isStoryMaster) return false;
      if (regenerateExisting) return true;
      final hasAsset = reference.assetPath?.trim().isNotEmpty == true;
      final hasPublicImage = reference.publicUrl?.trim().isNotEmpty == true;
      return !hasAsset && !hasPublicImage;
    }).toList();
  }

  ProductionProject applyCodexProjectRevision(
    ProductionProject project,
    Map<String, dynamic> output,
  ) {
    final result = _codexResult(output);
    final patch = Map<String, dynamic>.from(
      result['projectPatch'] as Map? ?? const {},
    );
    final biblePatch = Map<String, dynamic>.from(
      patch['seriesBiblePatch'] as Map? ?? const {},
    );
    final episodesByNumber = {
      for (final episode in project.episodes) episode.number: episode,
    };
    for (final raw
        in (patch['episodes'] as List<dynamic>? ?? const []).whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final number = (item['number'] as num?)?.toInt();
      final existing = number == null ? null : episodesByNumber[number];
      if (existing == null ||
          existing.takes.isNotEmpty ||
          existing.status.contains('LOCKED')) {
        continue;
      }
      episodesByNumber[number!] = existing.copyWith(
        title: item['title']?.toString() ?? existing.title,
        summary: item['summary']?.toString() ?? existing.summary,
        cliffhanger: item['cliffhanger']?.toString() ?? existing.cliffhanger,
      );
    }
    final referencesById = {
      for (final reference in project.references) reference.id: reference,
    };
    for (final raw
        in (patch['references'] as List<dynamic>? ?? const [])
            .whereType<Map>()) {
      final generated = ProductionReferenceItem.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (generated.id.isEmpty) continue;
      final existing = referencesById[generated.id];
      referencesById[generated.id] = existing == null
          ? generated
          : ProductionReferenceItem(
              id: existing.id,
              label: generated.label,
              category: generated.category,
              assetPath: existing.assetPath,
              publicUrl: existing.publicUrl,
              description: generated.description,
              canonical: existing.canonical || generated.canonical,
              metadata: {...existing.metadata, ...generated.metadata},
            );
    }
    final episodes = episodesByNumber.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return project.copyWith(
      description: patch['description']?.toString() ?? project.description,
      updatedAt: DateTime.now(),
      episodes: episodes,
      references: referencesById.values.toList(),
      seriesBible: {
        ...project.seriesBible,
        ...biblePatch,
        if (_codexThreadId(output) != null)
          'codex_thread_id': _codexThreadId(output),
        'codex_revision_summary': output['summary'],
      },
    );
  }

  static Map<String, dynamic> _codexResult(Map<String, dynamic> output) {
    final result = output['result'];
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw StateError('Resultado estruturado da IA ausente.');
  }

  static String? _codexThreadId(Map<String, dynamic> output) {
    final value = output['codexThreadId']?.toString().trim();
    return value?.isNotEmpty == true ? value : null;
  }

  static void _validateCodexEpisodeScript(
    ProductionProject project,
    Map<String, dynamic> script,
    int episodeNumber,
  ) {
    final episode = project.episodes.firstWhere(
      (item) => item.number == episodeNumber,
    );
    final maxDuration =
        (script['max_shot_duration_seconds'] as num?)?.toInt() ??
        (project.seriesBible['config'] as Map?)?['max_shot_duration_seconds']
            as int? ??
        10;
    var total = 0;
    var expectedShot = 1;
    final scenes = (script['scenes'] as List<dynamic>? ?? const [])
        .whereType<Map>();
    if (scenes.isEmpty) throw StateError('O roteiro não contém cenas.');
    for (final scene in scenes) {
      for (final shot
          in (scene['shots'] as List<dynamic>? ?? const []).whereType<Map>()) {
        final number = (shot['number'] as num?)?.toInt() ?? -1;
        final duration = (shot['duration_seconds'] as num?)?.toInt() ?? 0;
        if (number != expectedShot) {
          throw StateError('A numeração dos shots não é contínua.');
        }
        if (duration < 1 || duration > maxDuration) {
          throw StateError(
            'Shot $number possui ${duration}s; o limite é ${maxDuration}s.',
          );
        }
        final rowTotal = (shot['rows'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .fold<int>(
              0,
              (sum, row) =>
                  sum + ((row['duration_seconds'] as num?)?.toInt() ?? 0),
            );
        if (rowTotal != duration) {
          throw StateError(
            'As falas e ações do shot $number somam ${rowTotal}s, mas o shot tem ${duration}s.',
          );
        }
        total += duration;
        expectedShot += 1;
      }
    }
    if (total != episode.durationSeconds) {
      throw StateError(
        'O roteiro soma ${total}s; o EP$episodeNumber exige ${episode.durationSeconds}s.',
      );
    }
  }

  @visibleForTesting
  ProductionProject generateMicroDramaEpisodeScriptForTesting(
    ProductionProject project, {
    required int episodeNumber,
  }) => generateMicroDramaEpisodeScript(project, episodeNumber: episodeNumber);

  ProductionProject approveMicroDramaEpisodeScriptForProduction(
    ProductionProject project, {
    required int episodeNumber,
  }) {
    project = _ensureMicroDramaFormat(project);
    if (project.formatFamily != _microDramaFormatFamily) {
      throw ArgumentError('O projeto não é um microdrama vertical.');
    }
    final episodeIndex = project.episodes.indexWhere(
      (episode) => episode.number == episodeNumber,
    );
    if (episodeIndex < 0) {
      throw ArgumentError('Episódio $episodeNumber não encontrado.');
    }
    final episodeScripts =
        (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final scriptIndex = episodeScripts.indexWhere(
      (script) => _asEpisodeNumber(script['episode']) == episodeNumber,
    );
    if (scriptIndex < 0) {
      throw StateError('Gere o roteiro detalhado antes da produção.');
    }

    final script = Map<String, dynamic>.from(episodeScripts[scriptIndex]);
    final qualityGate = Map<String, dynamic>.from(
      script['quality_gate'] as Map? ?? const {},
    );
    if (qualityGate['decision'] == 'BLOCK') {
      throw StateError('O roteiro possui bloqueios críticos de qualidade.');
    }
    final dialogueMaster = Map<String, dynamic>.from(
      script['episode_dialogue_master'] as Map? ?? const {},
    );
    final lockedDialogueMaster = {...dialogueMaster, 'status': 'LOCKED'};
    final lockedScript = {
      ...script,
      'status': 'LOCKED_FOR_PRODUCTION',
      'approved_by_user': true,
      'approved_at': DateTime.now().toIso8601String(),
      'episode_dialogue_master': lockedDialogueMaster,
    };
    episodeScripts[scriptIndex] = lockedScript;

    final config = _microDramaConfigFromProject(project);
    final creativePackage = _buildMicroDramaCreativePackage(config, project.id);
    final takes = _productionTakesFromEpisodeScript(
      config,
      projectId: project.id,
      script: lockedScript,
      creativePackage: creativePackage,
    );
    final stylePreset = _microDramaStylePreset(config.visualStyle);
    final episodes = project.episodes.toList();
    episodes[episodeIndex] = episodes[episodeIndex].copyWith(
      status: 'PRODUCTION_READY',
      takes: takes,
    );

    final episodeCards =
        (project.seriesBible['episode_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final cardIndex = episodeCards.indexWhere(
      (card) => _asEpisodeNumber(card['episode']) == episodeNumber,
    );
    if (cardIndex >= 0) {
      episodeCards[cardIndex] = {
        ...episodeCards[cardIndex],
        'script_status': 'LOCKED_FOR_PRODUCTION',
        'production_status': 'PROMPTS_READY_FOR_REVIEW',
      };
    }
    final productionPackages =
        (project.seriesBible['production_prompt_packages'] as List<dynamic>? ??
                const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['episode'] != episodeNumber)
            .toList()
          ..add({
            'episode': episodeNumber,
            'status': 'PROMPTS_READY_FOR_REVIEW',
            'source_script_status': 'LOCKED_FOR_PRODUCTION',
            'delivery_mode': 'episode_segment',
            'take_count': takes.length,
            'duration_mode': 'VARIABLE_UP_TO_LIMIT',
            'max_take_duration_seconds': config.maxShotDurationSeconds,
            'prompt_contract': 'ai_short_core_plus_code_style_preset_v1',
            'ai_short_core': 'SCENE_SPECIFIC_DYNAMIC_PROSE',
            'style_decoration': 'CODE_OWNED_FIXED_PRESET',
            'style_preset_id': stylePreset.id,
            'style_preset_label': stylePreset.label,
            'media_category': stylePreset.mediaCategory,
          });
    productionPackages.sort(
      (a, b) =>
          (a['episode'] as num? ?? 0).compareTo(b['episode'] as num? ?? 0),
    );
    final workflow = Map<String, dynamic>.from(
      project.seriesBible['workflow'] as Map? ?? const {},
    );
    final lockedCount = episodeScripts
        .where((item) => item['status'] == 'LOCKED_FOR_PRODUCTION')
        .length;

    return project.copyWith(
      episodes: episodes,
      seriesBible: {
        ...project.seriesBible,
        'workflow': {
          ...workflow,
          'scripts': lockedCount == episodes.length
              ? 'ALL_EPISODE_SCRIPTS_LOCKED'
              : 'PARTIAL_EPISODE_SCRIPTS_LOCKED',
          'production': lockedCount == episodes.length
              ? 'ALL_EPISODES_READY'
              : 'PARTIAL_EPISODES_READY',
        },
        'episode_cards': episodeCards,
        'episode_scripts': episodeScripts,
        'production_prompt_packages': productionPackages,
        'locked_script_package': {
          'package_version': 'microdrama-script-v1',
          'status': lockedCount == episodes.length ? 'LOCKED' : 'PARTIAL_LOCK',
          'approved_episode_count': lockedCount,
          'locked_scripts': episodeScripts
              .where((item) => item['status'] == 'LOCKED_FOR_PRODUCTION')
              .toList(),
          'production_handoff': {
            'target': 'seedance-series-pipeline',
            'preserve_exact_dialogue': true,
            'preserve_scene_and_shot_order': true,
            'preserve_cliffhanger_cut': true,
            'provider_duration_mode': 'VARIABLE_UP_TO_LIMIT',
            'provider_duration_limit_seconds': config.maxShotDurationSeconds,
          },
        },
      },
    );
  }

  @visibleForTesting
  ProductionProject approveMicroDramaEpisodeScriptForProductionForTesting(
    ProductionProject project, {
    required int episodeNumber,
  }) => approveMicroDramaEpisodeScriptForProduction(
    project,
    episodeNumber: episodeNumber,
  );

  static ProductionProject _buildMicroDramaProject(
    MicroDramaProjectConfig config, {
    required String id,
    required int virtualId,
    required DateTime updatedAt,
  }) {
    final creativePackage = _buildMicroDramaCreativePackage(config, id);
    final episodes = <ProductionEpisodeItem>[];
    final episodeCards = <Map<String, dynamic>>[];
    final pressureLedger = <Map<String, dynamic>>[];
    var previousHook =
        'Uma consequência visível torna a premissa impossível de ignorar.';

    for (var index = 0; index < config.episodeCount; index++) {
      final episodeNumber = index + 1;
      final duration = index == 0
          ? config.firstEpisodeDurationSeconds
          : config.episodeDurationSeconds;
      final plan = _microDramaEpisodePlan(config, episodeNumber: episodeNumber);
      final openingPickup = _microDramaOpeningPickup(
        language: config.language,
        episodeNumber: episodeNumber,
        logline: config.logline,
        previousHook: previousHook,
      );
      episodes.add(
        ProductionEpisodeItem(
          number: episodeNumber,
          title: plan.title,
          summary: plan.summary,
          cliffhanger: plan.cliffhanger,
          durationSeconds: duration,
          status: 'OUTLINE_REVIEW_REQUIRED',
          takes: const [],
          externalMusic: true,
          musicProvider: 'API externa',
          musicPrompt:
              '${config.genre}, ${config.trope}. Trilha contínua sem voz para o episódio $episodeNumber, crescendo até o corte no pico e sem competir com o áudio já presente nos vídeos.',
        ),
      );
      final questions = _microDramaUnresolvedQuestions(
        language: config.language,
        episodeNumber: episodeNumber,
        episodeCount: config.episodeCount,
        protagonist: config.protagonist,
        opposingForce: config.opposingForce,
        centralQuestion: config.centralQuestion,
        cliffhanger: plan.cliffhanger,
      );
      episodeCards.add({
        'episode': episodeNumber,
        'title': plan.title,
        'duration_seconds': duration,
        'episode_job': plan.job,
        'stage_goal': plan.goal,
        'emotional_beat': plan.emotionalBeat,
        'treatment': plan.summary,
        'value_shift': plan.valueChange,
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
        'status': 'OUTLINE_REVIEW_REQUIRED',
        'script_status': 'NOT_STARTED',
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
    final hookChain = _syncMicroDramaHookChain(
      episodes: episodes,
      logline: config.logline,
      protagonist: config.protagonist,
      opposingForce: config.opposingForce,
      centralQuestion: config.centralQuestion,
      language: config.language,
    );

    const sceneCards = <Map<String, dynamic>>[];
    final profileEvidence = config.episodeCount >= 50
        ? 'platform_default'
        : 'hypothesis';
    final stylePreset = _microDramaStylePreset(config.visualStyle);
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
        'creation_workflow': 'guided_microdrama_v3_outline_first',
        'package_status': 'DRAFT_REVIEW_REQUIRED',
        'distribution_profile': config.distributionProfile,
        'evidence_status': profileEvidence,
        'aspect_ratio': '9:16',
        'language': config.language,
        'rating': config.rating,
        'visual_style': config.visualStyle,
        'style_preset_id': stylePreset.id,
        'style_preset_media_category': stylePreset.mediaCategory,
        'style_decoration_source': 'CODE_OWNED_FIXED_PRESET',
        'max_shot_duration_seconds': config.maxShotDurationSeconds,
        'provider_duration_seconds': config.maxShotDurationSeconds,
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
        'automatic_preparation_requested': config.automaticPreparation,
        'automatic_preparation_status': config.automaticPreparation
            ? 'QUEUED'
            : 'MANUAL',
        'workflow': {
          'settings': 'COMPLETE',
          'series_contract': 'DRAFT',
          'outline': 'GENERATED_REVIEW_REQUIRED',
          'characters': 'GENERATED_REVIEW_REQUIRED',
          'environments': 'GENERATED_REVIEW_REQUIRED',
          'props': 'GENERATED_REVIEW_REQUIRED',
          'characters_locations_props': 'GENERATED_REVIEW_REQUIRED',
          'scripts': 'NOT_STARTED',
          'production': 'BLOCKED_BY_SCRIPT',
        },
        'season_outline': {
          'title': config.title,
          'logline': config.logline,
          'central_question': config.centralQuestion,
          'stakes': config.stakes,
          'episode_count': config.episodeCount,
          'status': 'DRAFT_REVIEW_REQUIRED',
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
        'characters': creativePackage.characters,
        'character_bible': creativePackage.characters,
        'environments': creativePackage.environments,
        'location_bible': creativePackage.environments,
        'props': creativePackage.props,
        'object_bible': creativePackage.props,
        'scene_cards': sceneCards,
        'script_package': {
          'status': 'NOT_STARTED',
          'episodes': 0,
          'scenes': 0,
          'shots': 0,
          'max_shot_duration_seconds': config.maxShotDurationSeconds,
          'generation_order': [
            'season_outline',
            'characters',
            'environments',
            'props',
            'episode_script_on_demand',
          ],
        },
      },
      episodes: episodes,
      references: creativePackage.references,
    );
  }

  static _MicroDramaCreativePackage _buildMicroDramaCreativePackage(
    MicroDramaProjectConfig config,
    String projectId,
  ) {
    final protagonistId = '$projectId-character-protagonist';
    final opposingForceId = '$projectId-character-opposing-force';
    final supportingNames = _microDramaSupportingNames(config.language);
    final characters = <Map<String, dynamic>>[
      {
        'reference_id': protagonistId,
        'name': config.protagonist,
        'role': 'Protagonista',
        'appearance':
            'Presença central imediatamente reconhecível, silhueta limpa e expressiva em 9:16. Visual-base em ${config.visualStyle}, com figurino funcional ligado a ${config.background}; rosto, cabelo, proporções, acessórios e paleta devem permanecer constantes entre episódios.',
        'personality': [
          'determinado sob pressão',
          'afetivamente contraditório',
          'observador',
          'capaz de decisões irreversíveis',
        ],
        'dramatic_function':
            'Conduz a ação e responde progressivamente à pergunta central.',
        'desire': config.centralQuestion,
        'fear': config.stakes,
        'arc':
            'Parte tentando preservar controle e termina obrigado a escolher diante do custo máximo.',
        'looks': ['Aparência padrão', 'Estado íntimo', 'Confronto final'],
      },
      {
        'reference_id': opposingForceId,
        'name': config.opposingForce,
        'role': 'Força oposta',
        'appearance':
            'Visual de contraste com ${config.protagonist}: linhas, postura e paleta comunicam poder antes do diálogo. Aparência coerente com ${config.visualStyle}, incluindo um acessório-assinatura preservado em todos os episódios.',
        'personality': [
          'estratégico',
          'controlador',
          'persuasivo',
          'perigoso quando perde vantagem',
        ],
        'dramatic_function':
            'Age por objetivo próprio, aprende com cada avanço e remove uma opção segura.',
        'desire': 'Manter o controle do conflito central.',
        'fear': 'Perder poder, reputação ou o vínculo que usa como alavanca.',
        'arc':
            'Começa dominando as regras e termina exposto pela consequência das próprias contrajogadas.',
        'looks': ['Aparência padrão', 'Imagem pública', 'Estado de ruptura'],
      },
      {
        'reference_id': '$projectId-character-confidant',
        'name': supportingNames[0],
        'role': 'Confidente',
        'appearance':
            'Coadjuvante de leitura calorosa e prática, com paleta complementar à de ${config.protagonist}. Figurino cotidiano, um detalhe visual memorável e expressão corporal direta.',
        'personality': [
          'leal',
          'prático',
          'franco',
          'corajoso no momento crítico',
        ],
        'dramatic_function':
            'Força ${config.protagonist} a verbalizar escolhas sem substituir sua agência.',
        'desire': 'Proteger o protagonista sem encobrir seus erros.',
        'fear': 'Ser usado como álibi para mais uma fuga.',
        'arc': 'De apoio discreto a testemunha ativa da verdade.',
        'looks': ['Aparência padrão', 'Variação de crise'],
      },
      {
        'reference_id': '$projectId-character-catalyst',
        'name': supportingNames[1],
        'role': 'Catalisador',
        'appearance':
            'Figura ligada ao segredo de ${config.trope}, visual simples e emocionalmente legível em close. Um elemento de figurino conecta esta pessoa ao objeto narrativo principal.',
        'personality': ['curioso', 'espontâneo', 'perceptivo', 'imprevisível'],
        'dramatic_function':
            'Torna a premissa visível e dispara revelações sem depender de exposição verbal.',
        'desire': 'Entender o vínculo que os adultos tentam esconder.',
        'fear': 'Ser abandonado quando a verdade vier à tona.',
        'arc': 'De peça protegida do segredo a agente que exige uma resposta.',
        'looks': ['Aparência padrão'],
      },
      {
        'reference_id': '$projectId-character-wildcard',
        'name': supportingNames[2],
        'role': 'Aliado ambíguo',
        'appearance':
            'Presença institucional ou social associada a ${config.background}; composição visual sóbria, adereço funcional e postura capaz de mudar de lado sem perder coerência.',
        'personality': [
          'cauteloso',
          'bem informado',
          'ambíguo',
          'sensível a provas',
        ],
        'dramatic_function':
            'Valida consequências externas e impede que o clímax dependa apenas da palavra dos protagonistas.',
        'desire': 'Sair do conflito com posição e consciência preservadas.',
        'fear': 'Ser responsabilizado pela decisão errada.',
        'arc': 'Da neutralidade conveniente a uma tomada de posição pública.',
        'looks': ['Aparência padrão', 'Variação formal'],
      },
    ];

    final environments = <Map<String, dynamic>>[
      {
        'reference_id': '$projectId-location-master',
        'name': '${config.background} — ambiente principal',
        'role': 'Palco recorrente',
        'description':
            'Espaço recorrente que concentra trabalho, encontros e interrupções. Deve oferecer primeiro plano, profundidade e entradas visíveis para encenar confrontos verticais sem perder orientação.',
        'visual_contract':
            '${config.visualStyle}; geografia fixa, paleta reconhecível, materiais táteis e três marcos permanentes enquadráveis em 9:16.',
        'lighting':
            'Base motivada e repetível, com versões de dia, noite e crise.',
        'permanent_elements': [
          'entrada principal visível',
          'superfície de ação',
          'marco vertical de profundidade',
        ],
        'continuity':
            'Não inverter portas, eixos ou posição dos marcos entre takes.',
      },
      {
        'reference_id': '$projectId-location-private',
        'name': 'Espaço íntimo de ${config.protagonist}',
        'role': 'Refúgio e vulnerabilidade',
        'description':
            'Ambiente privado onde o custo emocional aparece em objetos, silêncio e rotina. Mais compacto e quente que o ambiente principal.',
        'visual_contract':
            'Paleta pessoal derivada do protagonista, sinais de uso real e composição que permita close, reflexo e revelação de objeto.',
        'lighting':
            'Luz lateral suave com contraste reservado para cenas de segredo.',
        'permanent_elements': [
          'fotografia ou memória',
          'assento recorrente',
          'fonte de luz prática',
        ],
        'continuity':
            'Objetos pessoais mantêm posição e estado narrativo por episódio.',
      },
      {
        'reference_id': '$projectId-location-opposition',
        'name': 'Território de ${config.opposingForce}',
        'role': 'Centro de poder',
        'description':
            'Espaço organizado para favorecer a força oposta: linhas rígidas, distância controlada e sinais concretos de autoridade.',
        'visual_contract':
            'Contraste cromático com o mundo de ${config.protagonist}, superfícies controladas e enquadramentos simétricos que possam se romper no clímax.',
        'lighting':
            'Luz precisa, fria ou recortada, sem áreas visualmente acidentais.',
        'permanent_elements': [
          'mesa ou barreira de poder',
          'símbolo de status',
          'saída controlada',
        ],
        'continuity':
            'A perda de controle deve ser mostrada alterando um elemento antes impecável.',
      },
      {
        'reference_id': '$projectId-location-threshold',
        'name': 'Limiar de encontro e fuga',
        'role': 'Transição recorrente',
        'description':
            'Corredor, entrada, portão ou passagem onde chegadas interrompem decisões e personagens podem ouvir sem serem vistos.',
        'visual_contract':
            'Perspectiva profunda, uma porta dominante, textura sonora própria e espaço suficiente para entradas em match-on-action.',
        'lighting':
            'Contraluz ou recorte que diferencie os dois lados do limiar.',
        'permanent_elements': [
          'porta dominante',
          'marco de espera',
          'rota de fuga',
        ],
        'continuity': 'Preservar direção de entrada, saída e lado da tela.',
      },
      {
        'reference_id': '$projectId-location-climax',
        'name': 'Arena pública do clímax',
        'role': 'Exposição e consequência',
        'description':
            'Versão pública e ampliada do conflito, com testemunhas, rota de entrada da ameaça e ponto visual para a prova final.',
        'visual_contract':
            'Espaço legível em plano geral vertical, fundo com público controlável e eixo claro entre ${config.protagonist} e ${config.opposingForce}.',
        'lighting':
            'Luz mais aberta, permitindo que a verdade seja vista sem esconderijos.',
        'permanent_elements': [
          'área de testemunhas',
          'ponto de confronto',
          'saída final',
        ],
        'continuity':
            'Reservar este ambiente para a escalada final e não banalizá-lo antes.',
      },
    ];

    final propNames = _microDramaPropNames(config.trope);
    final props = <Map<String, dynamic>>[
      {
        'reference_id': '$projectId-prop-master',
        'name': propNames[0],
        'role': 'Prova do segredo',
        'type': 'Símbolo',
        'description':
            'Objeto pequeno, reconhecível em close e ligado diretamente a ${config.trope}. Possui marca única, desgaste coerente e informação visual que muda a leitura da história.',
        'story_function':
            'Introduzir a dúvida, circular entre personagens e pagar a revelação central.',
        'continuity':
            'Registrar lado, orientação, danos, inscrições e quem o possui ao fim de cada cena.',
        'introduced_episode': 1,
        'payoff_episode': (config.episodeCount * .75).ceil(),
      },
      {
        'reference_id': '$projectId-prop-bond',
        'name': propNames[1],
        'role': 'Símbolo do vínculo',
        'type': 'Símbolo',
        'description':
            'Peça afetiva de material e cor opostos à prova do segredo. Deve funcionar em mão, bolso e detalhe de cenário.',
        'story_function':
            'Materializar a relação quando os personagens não conseguem verbalizá-la.',
        'continuity': 'Toda transferência de posse precisa aparecer em cena.',
        'introduced_episode': 2,
        'payoff_episode': config.episodeCount,
      },
      {
        'reference_id': '$projectId-prop-power',
        'name': propNames[2],
        'role': 'Instrumento de poder',
        'type': 'Outro',
        'description':
            'Documento, dispositivo ou chave visualmente associado a ${config.opposingForce}; design formal, detalhe verificável e versão íntegra e alterada.',
        'story_function':
            'Converter ameaça abstrata em prazo, condição ou perda concreta.',
        'continuity':
            'Manter versão, assinatura, tela ou dano sincronizados com o episódio.',
        'introduced_episode': 1,
        'payoff_episode': (config.episodeCount * .65).ceil(),
      },
      {
        'reference_id': '$projectId-prop-climax',
        'name': propNames[3],
        'role': 'Objeto do clímax',
        'type': 'Símbolo',
        'description':
            'Objeto visualmente simples que reúne memória, escolha e consequência. A versão final deve mostrar uma transformação concreta em relação à primeira aparição.',
        'story_function':
            'Fechar a promessa emocional no quadro, sem depender de epílogo explicativo.',
        'continuity':
            'Preparar a transformação em pelo menos dois episódios antes do clímax.',
        'introduced_episode': (config.episodeCount * .4).ceil(),
        'payoff_episode': config.episodeCount,
      },
    ];

    final references = <ProductionReferenceItem>[
      ...characters.map(
        (item) => ProductionReferenceItem(
          id: item['reference_id'] as String,
          label: item['name'] as String,
          category: 'CHARACTER_MASTER',
          description: item['appearance'] as String,
          canonical: true,
          metadata: item,
        ),
      ),
      ...environments.map(
        (item) => ProductionReferenceItem(
          id: item['reference_id'] as String,
          label: item['name'] as String,
          category: 'LOCATION_MASTER',
          description: item['description'] as String,
          canonical: true,
          metadata: item,
        ),
      ),
      ...props.map(
        (item) => ProductionReferenceItem(
          id: item['reference_id'] as String,
          label: item['name'] as String,
          category: 'PROP_MASTER',
          description: item['description'] as String,
          canonical: true,
          metadata: item,
        ),
      ),
    ];
    return _MicroDramaCreativePackage(
      characters: characters,
      environments: environments,
      props: props,
      references: references,
    );
  }

  static List<String> _microDramaSupportingNames(String language) {
    final normalized = language.toLowerCase();
    if (normalized.contains('english')) return const ['Maya', 'Theo', 'Morgan'];
    if (normalized.contains('español')) return const ['Lucía', 'Teo', 'Álex'];
    return const ['Lia', 'Theo', 'Alex'];
  }

  static String? _nonEmptyHookText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _hookQuestionSeed(String cliffhanger) {
    final trimmed = cliffhanger.trim();
    if (trimmed.length <= 140) return trimmed;
    return '${trimmed.substring(0, 137).trimRight()}...';
  }

  static String _microDramaOpeningPickup({
    required String language,
    required int episodeNumber,
    required String logline,
    required String previousHook,
  }) {
    final normalized = language.toLowerCase();
    if (normalized.contains('english')) {
      return episodeNumber == 1
          ? 'Open already on the concrete consequence of the premise: $logline'
          : 'Pay off the previous ending hook immediately without restarting the story: $previousHook';
    }
    if (normalized.contains('español')) {
      return episodeNumber == 1
          ? 'Abrir ya en la consecuencia concreta de la premisa: $logline'
          : 'Pagar de inmediato el gancho anterior sin reiniciar la historia: $previousHook';
    }
    return episodeNumber == 1
        ? 'Abrir já na consequência concreta da premissa: $logline'
        : 'Pagar imediatamente o gancho anterior sem reiniciar a história: $previousHook';
  }

  static List<String> _microDramaUnresolvedQuestions({
    required String language,
    required int episodeNumber,
    required int episodeCount,
    required String protagonist,
    required String opposingForce,
    required String centralQuestion,
    required String cliffhanger,
  }) {
    final normalized = language.toLowerCase();
    final isLast = episodeNumber == episodeCount;
    final seed = _hookQuestionSeed(cliffhanger);
    if (normalized.contains('english')) {
      return [
        'Will $protagonist read the irreversible consequence of this cut in time?',
        'How far will $opposingForce go to use this turn against $protagonist?',
        isLast
            ? 'Does the visible consequence of "$centralQuestion" stay in frame, or does the cut hide the future?'
            : 'What stays unanswered for EP${episodeNumber + 1} after: $seed',
      ];
    }
    if (normalized.contains('español')) {
      return [
        '¿$protagonist alcanzará a leer a tiempo la consecuencia irreversible de este corte?',
        '¿Hasta dónde llegará $opposingForce para usar este giro contra $protagonist?',
        isLast
            ? '¿La consecuencia visible de "$centralQuestion" permanece en cuadro, o el corte esconde el futuro?'
            : '¿Qué queda abierto para el EP${episodeNumber + 1} después de: $seed',
      ];
    }
    return [
      '$protagonist consegue ler a tempo o que este corte tornou irreversível?',
      'Até onde $opposingForce vai para usar esta virada contra $protagonist?',
      isLast
          ? 'A consequência visível de "$centralQuestion" permanece no quadro, ou o corte esconde o futuro?'
          : 'O que permanece em aberto para o EP${episodeNumber + 1} depois de: $seed',
    ];
  }

  static List<Map<String, dynamic>> _syncMicroDramaHookChain({
    required List<ProductionEpisodeItem> episodes,
    List<Map<String, dynamic>> generated = const [],
    String logline = '',
    String protagonist = 'o protagonista',
    String opposingForce = 'a força oposta',
    String centralQuestion = '',
    String language = 'Português (Brasil)',
  }) {
    final generatedByEpisode = <int, Map<String, dynamic>>{
      for (final entry in generated)
        if ((entry['episode'] as num?)?.toInt() != null)
          (entry['episode'] as num).toInt(): entry,
    };
    var previousHook = logline;
    final chain = <Map<String, dynamic>>[];
    for (final episode in episodes) {
      final generatedEntry =
          generatedByEpisode[episode.number] ?? const <String, dynamic>{};
      final finalHook =
          _nonEmptyHookText(generatedEntry['final_hook']) ??
          episode.cliffhanger;
      final openingPickup =
          _nonEmptyHookText(generatedEntry['opening_pickup']) ??
          _microDramaOpeningPickup(
            language: language,
            episodeNumber: episode.number,
            logline: logline,
            previousHook: previousHook,
          );
      final generatedQuestions =
          (generatedEntry['unresolved_questions'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
      chain.add({
        'episode': episode.number,
        'opening_pickup': openingPickup,
        'final_hook': finalHook,
        'unresolved_questions': generatedQuestions.length >= 2
            ? generatedQuestions
            : _microDramaUnresolvedQuestions(
                language: language,
                episodeNumber: episode.number,
                episodeCount: episodes.length,
                protagonist: protagonist,
                opposingForce: opposingForce,
                centralQuestion: centralQuestion,
                cliffhanger: finalHook,
              ),
      });
      previousHook = finalHook;
    }
    return chain;
  }

  static List<String> _microDramaPropNames(String trope) => switch (trope) {
    'Segunda chance' => const [
      'Mensagem nunca entregue',
      'Lembrança do primeiro vínculo',
      'Documento que encerra o prazo',
      'Promessa restaurada',
    ],
    'Casamento por contrato' => const [
      'Contrato com cláusula oculta',
      'Aliança provisória',
      'Pasta jurídica da família',
      'Contrato rasgado e refeito',
    ],
    'Bebê secreto' => const [
      'Prova de origem escondida',
      'Desenho de família',
      'Documento de custódia',
      'Presente de aniversário',
    ],
    'Identidade oculta' => const [
      'Fotografia reveladora',
      'Objeto da vida verdadeira',
      'Crachá ou chave de acesso',
      'Símbolo da identidade assumida',
    ],
    'Retorno vingativo' => const [
      'Prova arquivada do passado',
      'Lembrança da perda',
      'Dossiê de exposição',
      'Objeto poupado da vingança',
    ],
    _ => const [
      'Prova do segredo',
      'Símbolo do vínculo',
      'Instrumento de poder',
      'Objeto da escolha final',
    ],
  };

  static _MicroDramaEpisodePlan _microDramaEpisodePlan(
    MicroDramaProjectConfig config, {
    required int episodeNumber,
  }) {
    final progress = episodeNumber / config.episodeCount;
    late final String stage;
    late final String job;
    late final String goal;
    late final String emotionalBeat;
    late final String action;
    late final String valueChange;
    if (episodeNumber == 1) {
      stage = 'O impacto';
      job = 'Provar a premissa e tornar o conflito inevitável.';
      goal =
          '${config.protagonist} precisa sobreviver ao impacto inicial e escolher uma reação que torne o conflito inevitável.';
      emotionalBeat = 'choque / urgência';
      action = 'transforma a consequência inicial em uma escolha pública';
      valueChange = 'segurança para risco';
    } else if (progress <= 0.25) {
      stage = 'A negação';
      job = 'Pagar o choque e mostrar por que a solução simples não funciona.';
      goal =
          '${config.protagonist} tenta recuperar o controle antes que a consequência anterior se torne pública.';
      emotionalBeat = 'resistência / ameaça crescente';
      action = 'tenta preservar o controle e perde uma vantagem concreta';
      valueChange = 'controle para exposição';
    } else if (progress <= 0.42) {
      stage = 'A proposta';
      job = 'Criar proximidade forçada e um custo emocional verificável.';
      goal =
          '${config.protagonist} aceita uma condição perigosa para proteger o que ainda pode salvar.';
      emotionalBeat = 'proximidade forçada / vulnerabilidade';
      action = 'aceita uma condição que aproxima o perigo';
      valueChange = 'distância para intimidade perigosa';
    } else if (progress <= 0.58) {
      stage = 'A prova';
      job = 'Ativar uma pista ou objeto que mude a estratégia.';
      goal =
          '${config.protagonist} busca uma prova física capaz de mudar a estratégia do conflito.';
      emotionalBeat = 'suspeita / validação perigosa';
      action = 'usa uma prova física e força a força oposta a reagir';
      valueChange = 'suspeita para evidência';
    } else if (progress <= 0.72) {
      stage = 'O preço';
      job = 'Cobrar a decisão anterior e retirar uma rota de fuga.';
      goal =
          '${config.protagonist} tenta proteger o vínculo central sem perder a última vantagem disponível.';
      emotionalBeat = 'esperança / perda';
      action = 'protege o que mais importa e sacrifica uma vantagem';
      valueChange = 'esperança para perda';
    } else if (progress <= 0.86) {
      stage = 'A contrajogada';
      job = 'Dar à força oposta uma vitória real que reorganize o poder.';
      goal =
          '${config.protagonist} precisa responder à vitória de ${config.opposingForce} antes que a derrota se torne permanente.';
      emotionalBeat = 'confiança rompida / desvantagem';
      action = 'responde à contrajogada com uma decisão irreversível';
      valueChange = 'equilíbrio para desvantagem';
    } else if (episodeNumber < config.episodeCount) {
      stage = 'Sem saída';
      job = 'Preparar o clímax com agência, perdas e promessas convergentes.';
      goal =
          '${config.protagonist} abandona a solução fácil e prepara o confronto que decidirá a temporada.';
      emotionalBeat = 'desespero / determinação';
      action = 'recusa a solução fácil e escolhe o confronto final';
      valueChange = 'reação para agência';
    } else {
      stage = 'A escolha final';
      job =
          'Pagar a pergunta central por uma escolha causada pelo protagonista.';
      goal =
          '${config.protagonist} faz a escolha irreversível que responde à grande expectativa da temporada.';
      emotionalBeat = 'medo / catarse';
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
      goal: goal,
      emotionalBeat: emotionalBeat,
      protagonistStep: action,
      countermove:
          '${config.opposingForce} observa a mudança e retira uma opção segura.',
      valueChange: valueChange,
      summary: summary,
      cliffhanger: cliffhanger,
    );
  }

  static Map<String, dynamic> _buildMicroDramaEpisodeScript(
    MicroDramaProjectConfig config, {
    required String projectId,
    required ProductionEpisodeItem episode,
    required Map<String, dynamic> card,
    required _MicroDramaCreativePackage creativePackage,
  }) {
    final shotLimit = config.maxShotDurationSeconds.clamp(5, 10).toInt();
    final shotDurations = _microDramaShotDurations(
      episode.durationSeconds,
      shotLimit,
    );
    final shotCount = shotDurations.length;
    final sceneCount = shotCount.clamp(1, 3).toInt();
    final shotsPerScene = List<int>.filled(sceneCount, shotCount ~/ sceneCount);
    for (var index = 0; index < shotCount % sceneCount; index++) {
      shotsPerScene[index] += 1;
    }

    final episodePosition = episode.number - 1;
    final environments = creativePackage.environments;
    final characters = creativePackage.characters;
    final protagonistId = characters.first['reference_id'] as String;
    final opposingId = characters[1]['reference_id'] as String;
    final supportingId = characters[2]['reference_id'] as String;
    final sceneTitles = _localizedScriptSceneTitles(config.language);
    final scenes = <Map<String, dynamic>>[];
    final dialogueLines = <Map<String, dynamic>>[];
    var shotNumber = 1;

    for (var sceneIndex = 0; sceneIndex < sceneCount; sceneIndex++) {
      final environment =
          environments[(episodePosition + sceneIndex) % environments.length];
      final usesSupporting = sceneIndex == 1;
      final counterName = usesSupporting
          ? characters[2]['name'] as String
          : config.opposingForce;
      final counterId = usesSupporting ? supportingId : opposingId;
      final cast = [config.protagonist, counterName];
      final castIds = [protagonistId, counterId];
      final shots = <Map<String, dynamic>>[];

      for (
        var localIndex = 0;
        localIndex < shotsPerScene[sceneIndex];
        localIndex++
      ) {
        final duration = shotDurations[shotNumber - 1];
        final dialogue = _microDramaDialogueSet(
          config,
          shotNumber: shotNumber,
          counterName: counterName,
        );
        final actions = _microDramaShotActions(
          config,
          episode: episode,
          card: card,
          shotNumber: shotNumber,
          shotCount: shotCount,
          location: environment['name'] as String,
          counterName: counterName,
        );
        final linePrefix = 'ep${episode.number.toString().padLeft(2, '0')}-l';
        final firstLineId =
            '$linePrefix${(dialogueLines.length + 1).toString().padLeft(3, '0')}';
        final secondLineId =
            '$linePrefix${(dialogueLines.length + 2).toString().padLeft(3, '0')}';
        late final List<Map<String, dynamic>> rows;
        if (duration <= 5) {
          final rowDurations = _microDramaRowDurations(duration, rowCount: 3);
          final protagonistOwnsLine = shotNumber.isOdd;
          rows = [
            {
              'type': 'action',
              'text': actions.$1,
              'provider_text': actions.$3,
              'duration_seconds': rowDurations[0],
            },
            {
              'type': 'dialogue',
              'line_id': firstLineId,
              'speaker': protagonistOwnsLine ? config.protagonist : counterName,
              'performance': protagonistOwnsLine ? dialogue.$1 : dialogue.$3,
              'provider_performance': protagonistOwnsLine
                  ? 'holding pressure behind a controlled breath'
                  : 'closing the distance without raising the voice',
              'text': protagonistOwnsLine ? dialogue.$2 : dialogue.$4,
              'duration_seconds': rowDurations[1],
            },
            {
              'type': 'action',
              'text': actions.$2,
              'provider_text': actions.$4,
              'duration_seconds': rowDurations[2],
            },
          ];
        } else {
          final rowDurations = _microDramaRowDurations(duration, rowCount: 4);
          final counterOpens = shotNumber.isEven;
          rows = [
            {
              'type': 'action',
              'text': actions.$1,
              'provider_text': actions.$3,
              'duration_seconds': rowDurations[0],
            },
            {
              'type': 'dialogue',
              'line_id': firstLineId,
              'speaker': counterOpens ? counterName : config.protagonist,
              'performance': counterOpens ? dialogue.$3 : dialogue.$1,
              'provider_performance': counterOpens
                  ? 'closing the distance without raising the voice'
                  : 'holding pressure behind a controlled breath',
              'text': counterOpens ? dialogue.$4 : dialogue.$2,
              'duration_seconds': rowDurations[1],
            },
            {
              'type': 'dialogue',
              'line_id': secondLineId,
              'speaker': counterOpens ? config.protagonist : counterName,
              'performance': counterOpens ? dialogue.$5 : dialogue.$3,
              'provider_performance': counterOpens
                  ? 'meeting the challenge and committing to the choice'
                  : 'answering with restrained authority',
              'text': counterOpens ? dialogue.$6 : dialogue.$4,
              'duration_seconds': rowDurations[2],
            },
            {
              'type': 'action',
              'text': actions.$2,
              'provider_text': actions.$4,
              'duration_seconds': rowDurations[3],
            },
          ];
        }
        final shotDialogueRows = rows
            .where((item) => item['type'] == 'dialogue')
            .toList();
        for (var rowIndex = 0; rowIndex < shotDialogueRows.length; rowIndex++) {
          final row = shotDialogueRows[rowIndex];
          dialogueLines.add({
            'line_id': row['line_id'],
            'speaker': row['speaker'],
            'text': row['text'],
            'purpose': row['speaker'] == config.protagonist
                ? 'choice_or_resistance'
                : 'pressure_or_counterplay',
            'responds_to': dialogueLines.isEmpty
                ? 'visible opening pressure'
                : dialogueLines.last['line_id'],
            'causes': rowIndex == shotDialogueRows.length - 1
                ? 'visible end-state change'
                : 'the next dialogue or action beat',
          });
        }
        shots.add({
          'number': shotNumber,
          'title': _localizedShotTitle(config.language, shotNumber),
          'duration_seconds': duration,
          'rows': rows,
          'final_state': actions.$2,
          'status': 'DRAFT_REVIEW_REQUIRED',
        });
        shotNumber += 1;
      }

      scenes.add({
        'episode': episode.number,
        'scene': sceneIndex + 1,
        'title':
            sceneTitles[sceneIndex.clamp(0, sceneTitles.length - 1).toInt()],
        'location_id': environment['reference_id'],
        'location': environment['name'],
        'time_of_day': 'NIGHT',
        'interior_exterior': 'INT',
        'dramatic_beat':
            sceneTitles[sceneIndex.clamp(0, sceneTitles.length - 1).toInt()],
        'cast_ids': castIds,
        'cast': cast,
        'story': sceneIndex == 0
            ? '${card['cold_open']} ${card['stage_goal']}'
            : sceneIndex == sceneCount - 1
            ? '${card['peak_action']} ${episode.cliffhanger}'
            : episode.summary,
        'shots': shots,
        'status': 'DRAFT_REVIEW_REQUIRED',
      });
    }

    final displayScript = _renderMicroDramaEpisodeScript(
      episode: episode,
      scenes: scenes,
    );
    return {
      'episode': episode.number,
      'title': episode.title,
      'version': 1,
      'status': 'DRAFT_REVIEW_REQUIRED',
      'approved_by_user': false,
      'duration_seconds': episode.durationSeconds,
      'max_shot_duration_seconds': shotLimit,
      'scene_count': scenes.length,
      'shot_count': shotCount,
      'display_script': displayScript,
      'scenes': scenes,
      'episode_dialogue_master': {
        'status': 'DRAFT_REVIEW_REQUIRED',
        'language': config.language,
        'lines': dialogueLines,
        'voices': {
          for (final speaker
              in dialogueLines
                  .map((line) => line['speaker'].toString())
                  .toSet())
            speaker: _microDramaVoiceIdentityLock(
              config,
              speaker: speaker,
              protagonist: speaker == config.protagonist,
            ),
        },
      },
      'quality_gate': {
        'decision': 'PASS_HUMAN_REVIEW_REQUIRED',
        'duration_sums': 'PASS',
        'dialogue_ownership': 'PASS',
        'scene_and_shot_order': 'PASS',
        'cliffhanger_cut': 'PASS',
        'human_approval': 'REQUIRED',
      },
      'production_status': 'BLOCKED_BY_SCRIPT_APPROVAL',
      'source_project_id': projectId,
    };
  }

  static List<ProductionTakeItem> _productionTakesFromEpisodeScript(
    MicroDramaProjectConfig config, {
    required String projectId,
    required Map<String, dynamic> script,
    required _MicroDramaCreativePackage creativePackage,
  }) {
    final episodeNumber = script['episode'] as int? ?? 1;
    final scenes = (script['scenes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final dialogueMaster = Map<String, dynamic>.from(
      script['episode_dialogue_master'] as Map? ?? const {},
    );
    final voiceLocks = Map<String, dynamic>.from(
      dialogueMaster['voices'] as Map? ?? const {},
    );
    final takes = <ProductionTakeItem>[];
    final propId = creativePackage.props.first['reference_id'] as String;
    var globalTakeNumber = 1;

    for (final scene in scenes) {
      final shots = (scene['shots'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      for (final shot in shots) {
        final rows = (shot['rows'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final dialogueRows = rows
            .where((row) => row['type'] == 'dialogue')
            .toList();
        final referenceIds = <String>{
          ...(scene['cast_ids'] as List<dynamic>? ?? const []).map(
            (item) => item.toString(),
          ),
          if (scene['location_id'] != null) scene['location_id'].toString(),
          propId,
        }.toList();
        final aiShortCore = _buildMicroDramaAiShortCore(
          scene: scene,
          shot: shot,
          rows: rows,
          creativePackage: creativePackage,
        );
        final providerPrompt = _compileMicroDramaProviderPrompt(
          config,
          rows: rows,
          referenceIds: referenceIds,
          voiceLocks: voiceLocks,
          creativePackage: creativePackage,
          aiShortCore: aiShortCore,
        );
        final audioPrompt = _compileMicroDramaAudioPrompt(
          config,
          dialogueRows: dialogueRows,
          voiceLocks: voiceLocks,
        );
        final isLast = globalTakeNumber == (script['shot_count'] as int? ?? 0);
        takes.add(
          ProductionTakeItem(
            id: '$projectId-ep$episodeNumber-take$globalTakeNumber',
            number: globalTakeNumber,
            title:
                'Cena ${scene['scene']} · Shot ${shot['number']} · ${scene['title']}',
            durationSeconds:
                shot['duration_seconds'] as int? ??
                config.maxShotDurationSeconds,
            status: 'READY',
            aiShortCore: aiShortCore,
            visualPrompt: providerPrompt,
            audioPrompt: audioPrompt,
            stylePresetId: _microDramaStylePreset(config.visualStyle).id,
            transitionMode: globalTakeNumber == 1
                ? 'EPISODE_START'
                : 'MATCH_ON_ACTION',
            usePreviousLastFrame: false,
            generateSeedanceAudio: true,
            referenceIds: referenceIds,
            notes: isLast
                ? 'Fonte bloqueada: roteiro aprovado. Cortar no cliffhanger sem cauda de reação.'
                : 'Fonte bloqueada: preservar ordem, falas e estado final para o próximo take.',
          ),
        );
        globalTakeNumber += 1;
      }
    }
    return takes;
  }

  static List<int> _microDramaShotDurations(int total, int maximum) {
    final minimum = switch (maximum) {
      >= 10 => 6,
      >= 8 => 5,
      _ => 3,
    };
    final targetAverage = (minimum + maximum) / 2;
    final minimumCount = (total / maximum).ceil();
    final maximumCount = (total / minimum).floor().clamp(1, total).toInt();
    final shotCount = (total / targetAverage)
        .round()
        .clamp(minimumCount, maximumCount)
        .toInt();
    final pattern = switch (maximum) {
      >= 10 => const [8, 10, 7, 9, 6],
      >= 8 => const [6, 8, 5, 7, 6],
      _ => const [4, 5, 3, 4, 5],
    };
    final durations = List<int>.generate(
      shotCount,
      (index) =>
          pattern[index % pattern.length].clamp(minimum, maximum).toInt(),
    );
    var difference = total - durations.fold<int>(0, (sum, item) => sum + item);
    var cursor = 0;
    while (difference != 0) {
      final index = cursor % durations.length;
      if (difference > 0 && durations[index] < maximum) {
        durations[index] += 1;
        difference -= 1;
      } else if (difference < 0 && durations[index] > minimum) {
        durations[index] -= 1;
        difference += 1;
      }
      cursor += 1;
    }
    if (durations.length > 1) {
      final longestIndex = durations.indexOf(
        durations.reduce((a, b) => a > b ? a : b),
      );
      final lastIndex = durations.length - 1;
      final lastDuration = durations[lastIndex];
      durations[lastIndex] = durations[longestIndex];
      durations[longestIndex] = lastDuration;
    }
    return durations;
  }

  static List<int> _microDramaRowDurations(int total, {required int rowCount}) {
    final weights = switch (rowCount) {
      3 => const [1, 3, 1],
      4 => const [2, 3, 3, 2],
      _ => List<int>.filled(rowCount, 1),
    };
    final weightTotal = weights.fold<int>(0, (sum, item) => sum + item);
    final durations = weights
        .map(
          (weight) =>
              ((total * weight) / weightTotal).floor().clamp(1, total).toInt(),
        )
        .toList();
    var difference = total - durations.fold<int>(0, (sum, item) => sum + item);
    final adjustmentOrder = rowCount == 4
        ? const [1, 2, 0, 3]
        : const [1, 0, 2];
    var cursor = 0;
    while (difference != 0) {
      final index = adjustmentOrder[cursor % adjustmentOrder.length];
      if (difference > 0) {
        durations[index] += 1;
        difference -= 1;
      } else if (durations[index] > 1) {
        durations[index] -= 1;
        difference += 1;
      }
      cursor += 1;
    }
    return durations;
  }

  static String _microDramaVoiceIdentityLock(
    MicroDramaProjectConfig config, {
    required String speaker,
    required bool protagonist,
  }) {
    final traits = protagonist
        ? 'adult lower-mid register; warm lightly textured timbre; grounded resonance; measured conversational cadence; clear articulation with restrained phrase endings'
        : 'adult mid-low register; clean controlled timbre; firm resonance; deliberate cadence; precise articulation with contained phrase endings';
    return '$speaker always has the same original fictional voice: native ${config.language}; $traits. Keep vocal age, register, timbre, resonance, accent, pronunciation habits and habitual cadence unchanged.';
  }

  static List<String> _localizedScriptSceneTitles(String language) {
    if (language.toLowerCase().startsWith('english')) {
      return const [
        'Hook and consequence',
        'Pressure and choice',
        'Reversal and peak cut',
      ];
    }
    if (language.toLowerCase().startsWith('español')) {
      return const [
        'Gancho y consecuencia',
        'Presión y elección',
        'Reversión y corte en el pico',
      ];
    }
    return const [
      'Gancho e consequência',
      'Pressão e escolha',
      'Reversão e corte no pico',
    ];
  }

  static String _localizedShotTitle(String language, int shotNumber) {
    if (language.toLowerCase().startsWith('english')) {
      return 'Narrative beat $shotNumber';
    }
    if (language.toLowerCase().startsWith('español')) {
      return 'Latido narrativo $shotNumber';
    }
    return 'Batida narrativa $shotNumber';
  }

  static (String, String, String, String, String, String)
  _microDramaDialogueSet(
    MicroDramaProjectConfig config, {
    required int shotNumber,
    required String counterName,
  }) {
    final index = (shotNumber - 1) % 4;
    if (config.language.toLowerCase().startsWith('english')) {
      const protagonistLines = [
        "I won't let them choose again.",
        'If I retreat, I lose everything.',
        'This choice is still mine.',
        "I'm done running from this.",
      ];
      const counterLines = [
        'Impulse is not freedom.',
        'Protection is fear wearing armor.',
        'One move cannot erase your debt.',
        'Running is why you survived.',
      ];
      const responseLines = [
        'Then the consequence carries my name.',
        'I know the price. I still choose.',
        "I'm choosing who pays.",
        'This time, I decide the ending.',
      ];
      return (
        'holding the pressure behind a controlled breath',
        protagonistLines[index],
        'closing the distance without raising the voice',
        counterLines[index],
        'meeting $counterName’s eyes and committing to the choice',
        responseLines[index],
      );
    }
    if (config.language.toLowerCase().startsWith('español')) {
      const protagonistLines = [
        'No dejaré que vuelvan a elegir.',
        'Si retrocedo, lo pierdo todo.',
        'Esta elección todavía es mía.',
        'Ya no voy a seguir huyendo.',
      ];
      const counterLines = [
        'El impulso no es libertad.',
        'Protección es miedo con armadura.',
        'Un gesto no borra tu deuda.',
        'Huir fue lo que te salvó.',
      ];
      const responseLines = [
        'Entonces la consecuencia llevará mi nombre.',
        'Conozco el precio. Igual elijo.',
        'Yo elegiré quién lo paga.',
        'Esta vez, yo decido el final.',
      ];
      return (
        'conteniendo la presión detrás de una respiración controlada',
        protagonistLines[index],
        'acortando la distancia sin levantar la voz',
        counterLines[index],
        'sosteniendo la mirada de $counterName y asumiendo la elección',
        responseLines[index],
      );
    }
    const protagonistLines = [
      'Não deixo decidirem de novo.',
      'Se eu recuar, perco tudo.',
      'Essa escolha ainda é minha.',
      'Eu cansei de fugir.',
    ];
    const counterLines = [
      'Impulso não é liberdade.',
      'Proteção é medo com outro nome.',
      'Um gesto não apaga sua dívida.',
      'Fugir foi o que salvou você.',
    ];
    const responseLines = [
      'Então a consequência leva meu nome.',
      'Sei o preço. Mesmo assim, escolho.',
      'Eu escolho quem paga.',
      'Desta vez, eu decido o final.',
    ];
    return (
      'segurando a pressão atrás de uma respiração controlada',
      protagonistLines[index],
      'encurtando a distância sem elevar a voz',
      counterLines[index],
      'sustentando o olhar de $counterName e assumindo a escolha',
      responseLines[index],
    );
  }

  static (String, String, String, String) _microDramaShotActions(
    MicroDramaProjectConfig config, {
    required ProductionEpisodeItem episode,
    required Map<String, dynamic> card,
    required int shotNumber,
    required int shotCount,
    required String location,
    required String counterName,
  }) {
    final isLast = shotNumber == shotCount;
    final stageGoal = card['stage_goal']?.toString().trim();
    final openingPressure = stageGoal?.isNotEmpty == true
        ? stageGoal!
        : episode.summary;
    final providerOpening =
        '$location is already under immediate visible pressure. ${config.protagonist} occupies the active foreground with the consequence of the previous beat still physically present while $counterName blocks the safest exit.';
    final providerEnding = isLast
        ? '${config.protagonist} completes the irreversible action; hold only until its visible consequence reads clearly, then cut before any explanatory reaction.'
        : '${config.protagonist} makes one visible choice that changes the balance of power. $counterName reacts first; both settle into a readable continuity plateau without replaying the action.';
    if (config.language.toLowerCase().startsWith('english')) {
      return (
        '$location is already under visible pressure: $openingPressure ${config.protagonist} enters frame with the consequence of the previous beat still active while $counterName blocks the safest exit.',
        isLast
            ? '${config.protagonist} completes an irreversible move tied to ${episode.cliffhanger}; hold only until the consequence becomes readable, then cut before any answer.'
            : '${config.protagonist} makes a visible choice that changes the balance of power; $counterName reacts first, and the unfinished movement carries directly into the next shot.',
        providerOpening,
        providerEnding,
      );
    }
    if (config.language.toLowerCase().startsWith('español')) {
      return (
        '$location ya está bajo presión visible: $openingPressure ${config.protagonist} entra en cuadro con la consecuencia anterior todavía activa mientras $counterName bloquea la salida más segura.',
        isLast
            ? '${config.protagonist} completa un movimiento irreversible ligado a ${episode.cliffhanger}; mantener solo hasta que la consecuencia sea legible y cortar antes de la respuesta.'
            : '${config.protagonist} toma una decisión visible que cambia el poder; $counterName reacciona primero y el movimiento inconcluso continúa en el siguiente shot.',
        providerOpening,
        providerEnding,
      );
    }
    return (
      '$location já está sob pressão visível: $openingPressure ${config.protagonist} entra no quadro com a consequência anterior ainda ativa enquanto $counterName bloqueia a saída mais segura.',
      isLast
          ? '${config.protagonist} completa um movimento irreversível ligado a ${episode.cliffhanger}; sustentar apenas até a consequência ficar legível e cortar antes da resposta.'
          : '${config.protagonist} faz uma escolha visível que muda o equilíbrio de poder; $counterName reage primeiro, e o movimento incompleto continua diretamente no próximo shot.',
      providerOpening,
      providerEnding,
    );
  }

  static String _renderMicroDramaEpisodeScript({
    required ProductionEpisodeItem episode,
    required List<Map<String, dynamic>> scenes,
  }) {
    final buffer = StringBuffer();
    for (var sceneIndex = 0; sceneIndex < scenes.length; sceneIndex++) {
      final scene = scenes[sceneIndex];
      if (sceneIndex > 0) buffer.writeln();
      buffer.writeln(
        '[Episode ${episode.number} - Scene ${scene['scene']} | ${scene['location']} | ${scene['time_of_day']} ${scene['interior_exterior']} | ${scene['dramatic_beat']}]',
      );
      buffer.writeln(
        'Cast: ${(scene['cast'] as List<dynamic>? ?? const []).join(', ')}',
      );
      buffer.writeln();
      buffer.writeln('Story:');
      buffer.writeln(scene['story']);
      buffer.writeln();
      final shots = (scene['shots'] as List<dynamic>? ?? const [])
          .whereType<Map>();
      for (final shot in shots) {
        buffer.writeln('Shot ${shot['number']}');
        final rows = (shot['rows'] as List<dynamic>? ?? const [])
            .whereType<Map>();
        for (final row in rows) {
          final duration = row['duration_seconds'];
          if (row['type'] == 'dialogue') {
            buffer.writeln(
              '${row['speaker']}: (${row['performance']}) ${row['text']} (${duration}s)',
            );
          } else {
            buffer.writeln('(action) ${row['text']} (${duration}s)');
          }
        }
        buffer.writeln('Duration: ${shot['duration_seconds']}s');
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  static String _buildMicroDramaAiShortCore({
    required Map<String, dynamic> scene,
    required Map<String, dynamic> shot,
    required List<Map<String, dynamic>> rows,
    required _MicroDramaCreativePackage creativePackage,
  }) {
    Map<String, dynamic> findReference(
      List<Map<String, dynamic>> values,
      String referenceId,
    ) => values.firstWhere(
      (item) => item['reference_id'] == referenceId,
      orElse: () => const <String, dynamic>{},
    );

    final chronologicalBeats = <String>[];
    var cursor = 0;
    for (final row in rows) {
      final duration = row['duration_seconds'] as int? ?? 1;
      final end = cursor + duration;
      if (row['type'] == 'dialogue') {
        final performance =
            row['provider_performance']?.toString() ??
            'natural restrained dramatic delivery';
        chronologicalBeats.add(
          'From $cursor to $end seconds, ${row['speaker']}, $performance, says: "${row['text']}" The listener gives an immediate readable reaction without interrupting.',
        );
      } else {
        chronologicalBeats.add(
          'From $cursor to $end seconds, ${row['provider_text'] ?? row['text']}',
        );
      }
      cursor = end;
    }

    final cast = (scene['cast'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final environment = findReference(
      creativePackage.environments,
      scene['location_id']?.toString() ?? '',
    );
    final providerFinalState = rows.isNotEmpty
        ? rows.last['provider_text']?.toString() ??
              shot['final_state']?.toString() ??
              'the dramatic consequence remains visible at the cut'
        : shot['final_state']?.toString() ??
              'the dramatic consequence remains visible at the cut';
    final duration = shot['duration_seconds'] as int? ?? 10;
    return <String>[
      '${_microDramaEnvironmentProviderDescription(environment)} ${cast.join(' and ')} are already physically present in ${scene['location']} at frame 1, wearing their canonical wardrobe, with the immediate pressure and story-critical prop state already readable.',
      chronologicalBeats.join(' '),
      _microDramaCameraCoverage(duration, cast, providerFinalState),
      '${_microDramaLightingProviderDescription(environment)} Exposure, white balance and practical-source direction remain stable while faces, hands and the active prop stay readable.',
    ].join('\n\n');
  }

  static String _compileMicroDramaProviderPrompt(
    MicroDramaProjectConfig config, {
    required List<Map<String, dynamic>> rows,
    required List<String> referenceIds,
    required Map<String, dynamic> voiceLocks,
    required _MicroDramaCreativePackage creativePackage,
    required String aiShortCore,
  }) {
    Map<String, dynamic> findReference(
      List<Map<String, dynamic>> values,
      String referenceId,
    ) => values.firstWhere(
      (item) => item['reference_id'] == referenceId,
      orElse: () => const <String, dynamic>{},
    );

    final referenceLines = <String>[];
    for (var index = 0; index < referenceIds.length; index++) {
      final referenceId = referenceIds[index];
      final character = findReference(creativePackage.characters, referenceId);
      final environment = findReference(
        creativePackage.environments,
        referenceId,
      );
      final prop = findReference(creativePackage.props, referenceId);
      if (character.isNotEmpty) {
        referenceLines.add(
          '@Image${index + 1} = Use ${character['name']} from this image.',
        );
      } else if (environment.isNotEmpty) {
        referenceLines.add(
          '@Image${index + 1} = ${environment['name']} LOCATION MASTER; use only its established geometry, materials and motivated lighting.',
        );
      } else if (prop.isNotEmpty) {
        referenceLines.add(
          '@Image${index + 1} = ${prop['name']} PROP MASTER; preserve its design, condition and scale without duplication.',
        );
      }
    }

    final activeSpeakers = rows
        .where((row) => row['type'] == 'dialogue')
        .map((row) => row['speaker'].toString())
        .toSet();
    final voiceBlocks = activeSpeakers
        .where((speaker) => voiceLocks[speaker] != null)
        .map(
          (speaker) =>
              'VOICE IDENTITY LOCK — ${speaker.toUpperCase()} — COPY VERBATIM\n${voiceLocks[speaker]}',
        )
        .join('\n\n');
    final performances = rows
        .where((row) => row['type'] == 'dialogue')
        .map(
          (row) =>
              '${row['speaker']}: ${row['provider_performance'] ?? 'natural restrained dramatic delivery'}',
        )
        .toSet();
    final hasDialogue = activeSpeakers.isNotEmpty;
    final preset = _microDramaStylePreset(config.visualStyle);

    return <String>[
      if (referenceLines.isNotEmpty)
        'REFERENCE INDEX CONTRACT — DO NOT REORDER\n${referenceLines.join('\n')}',
      aiShortCore,
      if (voiceBlocks.isNotEmpty) voiceBlocks,
      if (performances.isNotEmpty)
        'PERFORMANCE THIS TAKE: ${performances.join('; ')}. Natural pauses, breathing and reactions; no theatrical overstatement.',
      if (hasDialogue)
        'SPOKEN LANGUAGE LOCK — ${config.language}\nAll intelligible speech is limited to the exact quoted lines in the scene direction above, in order and with the assigned speaker. Never translate, paraphrase, improvise or add speech.',
      'CONTINUITY CONTRACT: This is one causal segment of the approved episode. Preserve character appearance, wardrobe, established location geometry, light direction, prop condition and the 180-degree axis. Do not replay a completed action, invert screen sides or reset the emotional state.',
      preset.compiledSuffix,
    ].join('\n\n');
  }

  static String _compileMicroDramaAudioPrompt(
    MicroDramaProjectConfig config, {
    required List<Map<String, dynamic>> dialogueRows,
    required Map<String, dynamic> voiceLocks,
  }) {
    final activeSpeakers = dialogueRows
        .map((row) => row['speaker'].toString())
        .toSet();
    final activeVoiceLocks = activeSpeakers
        .where((speaker) => voiceLocks[speaker] != null)
        .map((speaker) => '$speaker: ${voiceLocks[speaker]}')
        .join(' | ');
    final exactLines = dialogueRows
        .map((row) => '${row['speaker']}: "${row['text']}"')
        .join(' | ');
    return 'Áudio nativo em ${config.language}. Vozes bloqueadas: $activeVoiceLocks. Falas autorizadas, na ordem e sem paráfrase: $exactLines. Vozes naturais e distintas, com pausas respiratórias entre turnos. Sem música, efeitos ambientes, legendas, narração ou fala fora desta lista.';
  }

  static String _microDramaEnvironmentProviderDescription(
    Map<String, dynamic> environment,
  ) => switch (environment['role']) {
    'Refúgio e vulnerabilidade' =>
      'A compact private refuge with tactile signs of daily use, one practical side light, a recurring seat and personal objects arranged for intimate close coverage.',
    'Centro de poder' =>
      'A controlled authority space with rigid lines, a physical power barrier, precise surfaces and a clearly readable controlled exit.',
    'Transição recorrente' =>
      'A deep threshold space with one dominant doorway, a fixed waiting mark and a readable escape route, preserving entrance and exit direction.',
    'Exposição e consequência' =>
      'A public confrontation arena with controlled witnesses in depth, a clear confrontation axis and a visible route for the arriving threat.',
    _ =>
      'A practical recurring location with tactile materials, clear foreground action space, visible entrances and stable depth landmarks designed for a vertical dramatic frame.',
  };

  static String _microDramaLightingProviderDescription(
    Map<String, dynamic> environment,
  ) => switch (environment['role']) {
    'Refúgio e vulnerabilidade' =>
      'Soft warm side light from a visible practical source, with reserved shadow contrast for secrecy.',
    'Centro de poder' =>
      'Precise cool or sharply shaped practical light that reinforces order without artificial rim lighting.',
    'Transição recorrente' =>
      'Motivated backlight separates both sides of the threshold while preserving readable faces.',
    'Exposição e consequência' =>
      'Open motivated light makes the public consequence legible without flattening depth.',
    _ =>
      'Repeatable motivated night lighting from practical fixtures, with stable direction and tactile local contrast.',
  };

  static String _microDramaCameraCoverage(
    int duration,
    List<String> cast,
    String finalState,
  ) {
    final primary = cast.isEmpty ? 'the active character' : cast.first;
    final counter = cast.length > 1 ? cast.last : primary;
    if (duration <= 5) {
      final cut = (duration / 2).round().clamp(1, duration - 1);
      return 'The camera opens in a readable medium shot on $primary and makes one restrained push that preserves the location anchor. At $cut seconds, a clean same-axis cut finds $counter and the visible consequence, settling on the dramatic button: $finalState';
    }
    final firstCut = (duration * .3).round().clamp(2, duration - 4);
    final secondCut = (duration * .65).round().clamp(
      firstCut + 2,
      duration - 2,
    );
    return 'Coverage opens in a medium-wide spatial anchor with a restrained push toward the active pressure, keeping both positions and the practical geometry readable. At $firstCut seconds, cut on the same axis to a medium close on the speaker applying pressure so the line and the listener’s reaction remain legible. At $secondCut seconds, move to a clean reverse or decisive close on the response and physical consequence, then settle without a dead tail on this final visible state: $finalState';
  }

  static _MicroDramaStylePreset _microDramaStylePreset(
    String style,
  ) => switch (style) {
    'Cinema teatral realista' => const _MicroDramaStylePreset(
      id: 'live_action_theatrical_cinema_v1',
      label: 'Cinema teatral realista',
      mediaCategory: 'live_action',
      cinematographyLock:
          'Master-level theatrical cinematography and composition, controlled blocking, deliberate shot variation and restrained dramatic pacing.',
      audioLock:
          'Do not add any background music or ambient sound effects. Use only the scripted dialogue; no narration, announcer voice or extra speech.',
      visualStyleLock:
          'Naturalistic live-action narrative film, premium theatrical television composition, tactile production design and restrained color.',
      textLock:
          'Do not generate subtitles, dialogue text, titles, timestamps, logos, watermarks or any written text anywhere in the video.',
      negativeLock:
          'Avoid shaky footage, floating camera motion, distorted limbs, malformed hands, deformed facial features, character identity drift, duplicated people or props, temporal flicker, texture pulsing and impossible reflections.',
      mediumLock:
          'Realistic film profile: physical camera behavior with restrained motivated movement; moderate depth of field with gradual detail falloff; natural motion blur; motivated practical light; real skin, worn fabric and tactile material response; weighted motion with inertia, contact and recovery; soft highlight roll-off; no beauty smoothing, waxy skin, artificial HDR, CGI or game-engine gloss.',
    ),
    'K-drama moderno' => const _MicroDramaStylePreset(
      id: 'live_action_modern_k_drama_v1',
      label: 'K-drama moderno',
      mediaCategory: 'live_action',
      cinematographyLock:
          'Master-level contemporary K-drama cinematography and composition, elegant motivated coverage, precise reaction close-ups and controlled shot variation.',
      audioLock:
          'Do not add any background music or ambient sound effects. Use only the scripted dialogue; no narration, announcer voice or extra speech.',
      visualStyleLock:
          'Premium contemporary live-action television drama, polished urban production design, clean emotional close-ups and restrained romantic color.',
      textLock:
          'Do not generate subtitles, dialogue text, titles, timestamps, logos, watermarks or any written text anywhere in the video.',
      negativeLock:
          'Avoid shaky footage, floating camera motion, distorted limbs, malformed hands, deformed facial features, character identity drift, duplicated people or props, temporal flicker, texture pulsing, overexposed beauty lighting and impossible reflections.',
      mediumLock:
          'Realistic film profile: physical camera behavior with smooth motivated movement; moderate depth of field; natural motion blur; soft motivated practical light; real skin and fabric response; restrained contrast and saturation with soft highlight roll-off; no beauty smoothing, waxy skin, artificial HDR, CGI or game-engine gloss.',
    ),
    'Noir urbano' => const _MicroDramaStylePreset(
      id: 'live_action_urban_noir_v1',
      label: 'Noir urbano',
      mediaCategory: 'live_action',
      cinematographyLock:
          'Master-level urban-noir cinematography and composition, tense motivated camera coverage, graphic shadow geometry and decisive shot variation.',
      audioLock:
          'Do not add any background music or ambient sound effects. Use only the scripted dialogue; no narration, announcer voice or extra speech.',
      visualStyleLock:
          'Naturalistic live-action urban noir, motivated practical contrast, controlled shadows, wet tactile surfaces and restrained color.',
      textLock:
          'Do not generate subtitles, dialogue text, titles, timestamps, logos, watermarks or any written text anywhere in the video.',
      negativeLock:
          'Avoid shaky footage, floating camera motion, crushed unreadable faces, unmotivated neon, distorted limbs, malformed hands, deformed facial features, character identity drift, duplicated people or props, temporal flicker, texture pulsing and impossible reflections.',
      mediumLock:
          'Realistic film profile: physical camera behavior with restrained motivated movement; moderate depth of field; natural motion blur; practical low-key light with preserved shadow detail; real skin, wet surfaces and worn fabric; weighted motion and soft highlight roll-off; no beauty smoothing, waxy skin, artificial HDR, CGI or game-engine gloss.',
    ),
    'Animação cinematográfica' => const _MicroDramaStylePreset(
      id: 'cinematic_animation_v1',
      label: 'Animação cinematográfica',
      mediaCategory: 'animation_cartoon',
      cinematographyLock:
          'Master-level animated cinematography and composition, readable silhouettes, one motivated camera operation per shot and controlled shot variation.',
      audioLock:
          'Do not add any background music or ambient sound effects. Use only the scripted dialogue; no narration, announcer voice or extra speech.',
      visualStyleLock:
          'Premium stylized cinematic animation, coherent modeled materials, stable character proportions, restrained acting and physically weighted motion.',
      textLock:
          'Do not generate subtitles, dialogue text, titles, timestamps, logos, watermarks or any written text anywhere in the video.',
      negativeLock:
          'Avoid character-design drift, changing proportions, morphing surfaces, unstable line or material treatment, duplicated people or props, temporal flicker, texture pulsing, broken silhouettes and impossible contact physics.',
      mediumLock:
          'Animation profile: preserve the selected stylized medium, coherent surfaces, stable proportions, decisive poses and weighted motion; no drift into live-action, photorealism or another animation medium.',
    ),
    _ => const _MicroDramaStylePreset(
      id: 'live_action_modern_microdrama_v1',
      label: 'Microdrama moderno',
      mediaCategory: 'live_action',
      cinematographyLock:
          'Master-level cinematography and composition, fast-paced shot variation.',
      audioLock:
          'Do not add any background music or ambient sound effects. Use only the scripted dialogue; no narration, announcer voice or extra speech.',
      visualStyleLock:
          'Live-action TV drama style, premium short drama aesthetic, masterful composition.',
      textLock:
          'Do not generate subtitles, dialogue text, titles, timestamps, logos, watermarks or any written text anywhere in the video.',
      negativeLock:
          'Avoid shaky footage, floating camera motion, distorted limbs, malformed hands, deformed facial features, character identity drift, duplicated people or props, temporal flicker, texture pulsing and impossible reflections.',
      mediumLock:
          'Realistic film profile: naturalistic live-action narrative film; physical camera behavior with restrained motivated movement; moderate depth of field with gradual detail falloff; natural motion blur; motivated practical or environmental light; real skin, worn fabric and tactile material response; weighted motion with inertia, contact and recovery; restrained saturation with soft highlight roll-off; no beauty smoothing, waxy skin, artificial HDR, CGI or game-engine gloss.',
    ),
  };

  @visibleForTesting
  String microDramaStyleSuffixForTesting(String style) =>
      _microDramaStylePreset(style).compiledSuffix;

  static String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  static MicroDramaProjectConfig _microDramaConfigFromProject(
    ProductionProject project,
  ) {
    final bible = project.seriesBible;
    final episodeCount = project.episodes.isNotEmpty
        ? project.episodes.length
        : project.targetEpisodeCount.clamp(1, 80);
    return MicroDramaProjectConfig(
      title: project.title,
      logline: bible['logline']?.toString().trim().isNotEmpty == true
          ? bible['logline'].toString()
          : project.description,
      centralQuestion:
          bible['central_question']?.toString().trim().isNotEmpty == true
          ? bible['central_question'].toString()
          : 'Qual escolha irreversível encerrará o conflito da temporada?',
      protagonist: bible['protagonist']?.toString().trim().isNotEmpty == true
          ? bible['protagonist'].toString()
          : 'Protagonista',
      opposingForce:
          bible['opposing_force']?.toString().trim().isNotEmpty == true
          ? bible['opposing_force'].toString()
          : 'Força oposta',
      stakes: bible['stakes']?.toString().trim().isNotEmpty == true
          ? bible['stakes'].toString()
          : 'A perda se torna pública e irreversível antes do prazo final.',
      genre: bible['genre']?.toString().trim().isNotEmpty == true
          ? bible['genre'].toString()
          : project.genre,
      background: bible['background']?.toString().trim().isNotEmpty == true
          ? bible['background'].toString()
          : 'Cidade moderna',
      trope: bible['trope']?.toString().trim().isNotEmpty == true
          ? bible['trope'].toString()
          : 'Segunda chance',
      visualStyle: bible['visual_style']?.toString().trim().isNotEmpty == true
          ? bible['visual_style'].toString()
          : 'Microdrama moderno',
      language: bible['language']?.toString().trim().isNotEmpty == true
          ? bible['language'].toString()
          : 'Português (Brasil)',
      rating: bible['rating']?.toString().trim().isNotEmpty == true
          ? bible['rating'].toString()
          : '14 anos',
      episodeCount: episodeCount,
      firstEpisodeDurationSeconds: project.episodes.isNotEmpty
          ? project.episodes.first.durationSeconds
          : ((bible['first_episode_duration_seconds'] as num?)?.toInt() ?? 120),
      episodeDurationSeconds: project.episodes.length > 1
          ? project.episodes[1].durationSeconds
          : ((bible['episode_duration_seconds'] as num?)?.toInt() ?? 60),
      maxShotDurationSeconds:
          ((bible['max_shot_duration_seconds'] as num?)?.toInt() ?? 10)
              .clamp(5, 10)
              .toInt(),
      automaticReview: _readBool(bible['automatic_review'], fallback: true),
      automaticPreparation: _readBool(
        bible['automatic_preparation_requested'],
        fallback: false,
      ),
    );
  }

  static ProductionProject _ensureMicroDramaCreativePackage(
    ProductionProject project,
  ) {
    project = _ensureMicroDramaFormat(project);
    if (project.formatFamily != _microDramaFormatFamily) return project;
    final bible = project.seriesBible;
    final hasCharacters =
        bible['characters'] is List && (bible['characters'] as List).isNotEmpty;
    final hasEnvironments =
        bible['environments'] is List &&
        (bible['environments'] as List).isNotEmpty;
    final hasProps =
        bible['props'] is List && (bible['props'] as List).isNotEmpty;
    final hasScenes =
        bible['scene_cards'] is List &&
        (bible['scene_cards'] as List).isNotEmpty;
    final workflowName = bible['creation_workflow']?.toString() ?? '';
    if (hasCharacters &&
        hasEnvironments &&
        hasProps &&
        (workflowName == 'guided_microdrama_v3_outline_first' ||
            workflowName.startsWith('openrouter_'))) {
      return project;
    }

    final episodeCount = project.episodes.isNotEmpty
        ? project.episodes.length
        : project.targetEpisodeCount.clamp(1, 80);
    final config = _microDramaConfigFromProject(project);
    final creativePackage = _buildMicroDramaCreativePackage(config, project.id);
    final rawEpisodeCards = bible['episode_cards'];
    var episodeCards = <Map<String, dynamic>>[];
    if (rawEpisodeCards is List) {
      episodeCards = rawEpisodeCards
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (episodeCards.length != project.episodes.length) {
      episodeCards = project.episodes.map((episode) {
        final plan = _microDramaEpisodePlan(
          config,
          episodeNumber: episode.number,
        );
        return <String, dynamic>{
          'episode': episode.number,
          'title': episode.title,
          'duration_seconds': episode.durationSeconds,
          'episode_job': plan.job,
          'stage_goal': plan.goal,
          'emotional_beat': plan.emotionalBeat,
          'treatment': episode.summary,
          'value_shift': plan.valueChange,
          'cold_open': episode.summary,
          'immediate_goal': plan.goal,
          'antagonist_countermove':
              '${config.opposingForce} remove uma opção segura.',
          'peak_action': episode.cliffhanger,
          'status': 'OUTLINE_REVIEW_REQUIRED',
          'script_status': episode.takes.isEmpty
              ? 'NOT_STARTED'
              : 'DRAFT_REVIEW_REQUIRED',
        };
      }).toList();
    }
    final sceneCards = (bible['scene_cards'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final scriptedEpisodes = project.episodes
        .where((episode) => episode.takes.isNotEmpty)
        .length;
    final allScriptsCreated =
        project.episodes.isNotEmpty &&
        scriptedEpisodes == project.episodes.length;
    final scriptState = scriptedEpisodes == 0
        ? 'NOT_STARTED'
        : allScriptsCreated
        ? 'ALL_EPISODE_SCRIPTS_CREATED'
        : 'PARTIAL_EPISODE_SCRIPTS_CREATED';

    final generatedById = {
      for (final reference in creativePackage.references)
        reference.id: reference,
    };
    final references = project.references.map((existing) {
      final generated = generatedById.remove(existing.id);
      if (generated == null) return existing;
      final legacyPlaceholder =
          existing.description.contains('Definir ') ||
          existing.description.contains('Escolher um objeto');
      return ProductionReferenceItem(
        id: existing.id,
        label: existing.label,
        category: existing.category,
        assetPath: existing.assetPath,
        publicUrl: existing.publicUrl,
        description: existing.description.isEmpty || legacyPlaceholder
            ? generated.description
            : existing.description,
        canonical: existing.canonical || generated.canonical,
        metadata: existing.metadata.isEmpty
            ? generated.metadata
            : existing.metadata,
      );
    }).toList()..addAll(generatedById.values);
    final workflow = Map<String, dynamic>.from(
      bible['workflow'] as Map? ?? const {},
    );
    return project.copyWith(
      seriesBible: {
        ...bible,
        'creation_workflow': 'guided_microdrama_v3_outline_first',
        'workflow': {
          ...workflow,
          'outline': workflow['outline'] ?? 'GENERATED_REVIEW_REQUIRED',
          'characters': 'GENERATED_REVIEW_REQUIRED',
          'environments': 'GENERATED_REVIEW_REQUIRED',
          'props': 'GENERATED_REVIEW_REQUIRED',
          'characters_locations_props': 'GENERATED_REVIEW_REQUIRED',
          'scripts': scriptState,
          'production': allScriptsCreated
              ? workflow['production'] ?? 'NOT_STARTED'
              : 'BLOCKED_BY_SCRIPT',
        },
        'season_outline':
            bible['season_outline'] ??
            {
              'title': config.title,
              'logline': config.logline,
              'central_question': config.centralQuestion,
              'stakes': config.stakes,
              'episode_count': episodeCount,
              'status': 'DRAFT_REVIEW_REQUIRED',
            },
        'characters': hasCharacters
            ? bible['characters']
            : creativePackage.characters,
        'character_bible':
            bible['character_bible'] ??
            (hasCharacters ? bible['characters'] : creativePackage.characters),
        'environments': hasEnvironments
            ? bible['environments']
            : creativePackage.environments,
        'location_bible':
            bible['location_bible'] ??
            (hasEnvironments
                ? bible['environments']
                : creativePackage.environments),
        'props': hasProps ? bible['props'] : creativePackage.props,
        'object_bible':
            bible['object_bible'] ??
            (hasProps ? bible['props'] : creativePackage.props),
        'episode_cards': episodeCards,
        'scene_cards': hasScenes ? bible['scene_cards'] : const [],
        'script_package':
            bible['script_package'] ??
            {
              'status': scriptedEpisodes == 0
                  ? 'NOT_STARTED'
                  : allScriptsCreated
                  ? 'DRAFT_REVIEW_REQUIRED'
                  : 'PARTIAL_DRAFT',
              'episodes': scriptedEpisodes,
              'scenes': sceneCards.length,
              'beats': project.episodes.fold<int>(
                0,
                (total, episode) => total + episode.takes.length,
              ),
            },
      },
      references: references,
    );
  }

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

  ProductionProject? _projectFromEditorSnapshot(
    ProductionCatalogItem item,
    AdminSeriesProductionPlan? plan,
  ) {
    Map<String, dynamic>? snapshot;
    final bible = plan?.seriesBible;
    if (bible is Map && bible['editor_project'] is Map) {
      snapshot = Map<String, dynamic>.from(bible['editor_project'] as Map);
    }
    if (snapshot == null && plan?.rawPayload is Map) {
      final raw = Map<String, dynamic>.from(plan!.rawPayload as Map);
      final pipeline = raw['pipelineData'];
      if (pipeline is Map && pipeline['editor_project'] is Map) {
        snapshot = Map<String, dynamic>.from(pipeline['editor_project'] as Map);
      }
    }
    if (snapshot == null) return null;
    try {
      final project = ProductionProject.fromJson(snapshot);
      return project.copyWith(
        id: 'remote-${item.routeId}',
        virtualId: item.routeId,
        isLocal: false,
        sourcePath: 'Vertix API / serie ${item.routeId}',
        title: project.title.trim().isEmpty ? item.title : project.title,
        status: item.status,
        coverUrl: item.coverUrl ?? project.coverUrl,
      );
    } catch (_) {
      return null;
    }
  }

  ProductionProject _hydrateRemoteProject(
    ProductionProject project, [
    AdminSeriesProductionPlan? plan,
  ]) {
    var bible = _flattenSeriesBible(
      Map<String, dynamic>.from(project.seriesBible),
    );
    if (plan != null) {
      final extras = _bibleFromRemotePlan(plan);
      for (final entry in extras.entries) {
        final current = bible[entry.key];
        final empty =
            current == null ||
            (current is String && current.trim().isEmpty) ||
            (current is List && current.isEmpty) ||
            (current is Map && current.isEmpty);
        if (empty) bible[entry.key] = entry.value;
      }
    }
    bible['scene_cards'] = _normalizeSceneCards(
      bible['scene_cards'] ?? plan?.sceneCards,
    );
    final fromRecords = _episodesFromRemoteSources(
      current: project.episodes,
      bible: bible,
      plan: plan,
    );
    final episodes = _mergeEpisodeLists(project.episodes, fromRecords);
    return project.copyWith(
      formatFamily: _resolvedFormatFamily(project.formatFamily, bible: bible),
      seriesBible: bible,
      episodes: episodes.isEmpty ? project.episodes : episodes,
    );
  }

  Map<String, dynamic> _bibleFromRemotePlan(AdminSeriesProductionPlan plan) {
    final fromPlan = plan.seriesBible is Map
        ? Map<String, dynamic>.from(plan.seriesBible as Map)
        : <String, dynamic>{};
    final bible = _flattenSeriesBible({
      ...fromPlan,
      'source': plan.source,
      if (plan.characterBible != null) 'character_bible': plan.characterBible,
      if (plan.locationBible != null) 'location_bible': plan.locationBible,
      if (plan.objectBible != null) 'object_bible': plan.objectBible,
      if (plan.seasonArc != null) 'seasonArc': plan.seasonArc,
      if (plan.episodeMap != null) 'episodeMap': plan.episodeMap,
      if (plan.generationPlan != null) 'generation_plan': plan.generationPlan,
      if (plan.seedanceNotes != null) 'seedance_notes': plan.seedanceNotes,
    });
    if (bible['scene_cards'] == null && plan.sceneCards != null) {
      bible['scene_cards'] = plan.sceneCards;
    }
    if (bible['episode_cards'] == null) {
      final cards = _asObjectList(plan.episodeMap);
      if (cards.isNotEmpty) bible['episode_cards'] = cards;
    }
    return bible;
  }

  String _displayEpisodeTitle(ProductionEpisodeItem episode) {
    final title = _humanReadableText(episode.title);
    return title.isEmpty ? episode.title : title;
  }

  String _displayEpisodeSummary(ProductionEpisodeItem episode) {
    final summary = _humanReadableText(episode.summary);
    return summary;
  }

  String _displayEpisodeCliffhanger(ProductionEpisodeItem episode) {
    final cliffhanger = _humanReadableText(episode.cliffhanger);
    return cliffhanger;
  }

  List<ProductionEpisodeItem> _mergeEpisodeLists(
    List<ProductionEpisodeItem> current,
    List<ProductionEpisodeItem> incoming,
  ) {
    final byNumber = <int, ProductionEpisodeItem>{};
    for (final episode in [...current, ...incoming]) {
      final existing = byNumber[episode.number];
      byNumber[episode.number] = existing == null
          ? episode.copyWith(
              title: _displayEpisodeTitle(episode),
              summary: _displayEpisodeSummary(episode),
              cliffhanger: _displayEpisodeCliffhanger(episode),
            )
          : _richerEpisode(existing, episode);
    }
    if (byNumber.isEmpty) return current;
    final numbers = byNumber.keys.toList()..sort();
    return [for (final number in numbers) byNumber[number]!];
  }

  ProductionEpisodeItem _richerEpisode(
    ProductionEpisodeItem current,
    ProductionEpisodeItem incoming,
  ) {
    final currentTitle = _displayEpisodeTitle(current);
    final incomingTitle = _displayEpisodeTitle(incoming);
    final currentSummary = _displayEpisodeSummary(current);
    final incomingSummary = _displayEpisodeSummary(incoming);
    final currentCliffhanger = _displayEpisodeCliffhanger(current);
    final incomingCliffhanger = _displayEpisodeCliffhanger(incoming);
    final preferIncomingTitle =
        incomingTitle.isNotEmpty &&
        !_genericEpisodeTitlePattern.hasMatch(incomingTitle) &&
        (currentTitle.isEmpty ||
            _genericEpisodeTitlePattern.hasMatch(currentTitle) ||
            incomingTitle.length > currentTitle.length);
    return ProductionEpisodeItem(
      number: current.number,
      title: preferIncomingTitle
          ? incomingTitle
          : (currentTitle.isNotEmpty ? currentTitle : incomingTitle),
      summary: incomingSummary.trim().length > currentSummary.trim().length
          ? incomingSummary
          : currentSummary,
      cliffhanger:
          incomingCliffhanger.trim().length > currentCliffhanger.trim().length
          ? incomingCliffhanger
          : currentCliffhanger,
      durationSeconds: incoming.durationSeconds > current.durationSeconds
          ? incoming.durationSeconds
          : current.durationSeconds,
      status: incoming.takes.length >= current.takes.length
          ? incoming.status
          : current.status,
      takes: incoming.takes.length >= current.takes.length
          ? incoming.takes
          : current.takes,
      externalMusic: current.externalMusic,
      musicProvider: current.musicProvider,
      musicPrompt: incoming.musicPrompt.trim().isNotEmpty
          ? incoming.musicPrompt
          : current.musicPrompt,
      musicStatus: incoming.musicStatus != 'DRAFT'
          ? incoming.musicStatus
          : current.musicStatus,
      musicVolume: current.musicVolume,
      dialogueVolume: current.dialogueVolume,
      ambienceVolume: current.ambienceVolume,
      assembledOutputUrl:
          incoming.assembledOutputUrl ?? current.assembledOutputUrl,
    );
  }

  List<ProductionEpisodeItem> _episodesFromRemoteSources({
    required List<ProductionEpisodeItem> current,
    required Map<String, dynamic> bible,
    AdminSeriesProductionPlan? plan,
  }) {
    final records = <Map<String, dynamic>>[
      ..._asObjectList(plan?.episodeTreatments),
      ..._asObjectList(bible['episode_cards']),
      ..._asObjectList(plan?.episodeMap),
      ..._asObjectList(bible['episodeMap']),
    ];
    if (records.isEmpty) {
      return [
        for (final episode in current)
          episode.copyWith(
            title: _displayEpisodeTitle(episode),
            summary: _displayEpisodeSummary(episode),
            cliffhanger: _displayEpisodeCliffhanger(episode),
          ),
      ];
    }
    final byNumber = <int, Map<String, dynamic>>{};
    for (final record in records) {
      final number =
          _asEpisodeNumber(record['episode']) ??
          _asEpisodeNumber(record['number']);
      if (number == null) continue;
      final existing = byNumber[number];
      byNumber[number] = existing == null
          ? record
          : {...existing, ...record, 'episode': number};
    }
    if (byNumber.isEmpty) return current;
    final existingByNumber = {
      for (final episode in current) episode.number: episode,
    };
    final numbers = byNumber.keys.toList()..sort();
    return [
      for (final number in numbers)
        _episodeFromRecord(
          byNumber[number]!,
          fallbackNumber: number,
          existing: existingByNumber[number],
        ),
    ];
  }

  ProductionEpisodeItem _episodeFromRecord(
    Map<String, dynamic> item, {
    required int fallbackNumber,
    ProductionEpisodeItem? existing,
  }) {
    final number =
        _asEpisodeNumber(item['episode']) ??
        _asEpisodeNumber(item['number']) ??
        fallbackNumber;
    final title = _humanReadableText(item['title']);
    final summary = _humanReadableText(
      item['summary'] ??
          item['treatment'] ??
          item['cold_open'] ??
          item['story'] ??
          item['description'],
    );
    final cliffhanger = _humanReadableText(
      item['cliffhanger'] ?? item['peak_action'] ?? item['hook'],
    );
    final duration =
        _asEpisodeNumber(item['durationSeconds']) ??
        _asEpisodeNumber(item['duration_seconds']) ??
        _asEpisodeNumber(item['duration']) ??
        existing?.durationSeconds ??
        60;
    final existingSummary = existing == null
        ? ''
        : _displayEpisodeSummary(existing);
    final existingCliffhanger = existing == null
        ? ''
        : _displayEpisodeCliffhanger(existing);
    final existingTitle = existing == null
        ? ''
        : _displayEpisodeTitle(existing);
    return ProductionEpisodeItem(
      number: number,
      title: title.isNotEmpty
          ? title
          : existingTitle.isNotEmpty &&
                !_genericEpisodeTitlePattern.hasMatch(existingTitle)
          ? existingTitle
          : 'Episódio $number',
      summary: summary.isNotEmpty ? summary : existingSummary,
      cliffhanger: cliffhanger.isNotEmpty ? cliffhanger : existingCliffhanger,
      durationSeconds: duration <= 0 ? 60 : duration,
      status:
          existing?.status ??
          item['status']?.toString() ??
          'OUTLINE_REVIEW_REQUIRED',
      takes: existing?.takes ?? const [],
      externalMusic: existing?.externalMusic ?? true,
      musicProvider: existing?.musicProvider ?? 'API externa',
      musicPrompt: existing?.musicPrompt ?? '',
      musicStatus: existing?.musicStatus ?? 'DRAFT',
      musicVolume: existing?.musicVolume ?? 0.36,
      dialogueVolume: existing?.dialogueVolume ?? 0.9,
      ambienceVolume: existing?.ambienceVolume ?? 0.48,
      assembledOutputUrl: existing?.assembledOutputUrl,
    );
  }

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
            description: _humanReadableText(asset.metadata).isNotEmpty
                ? _humanReadableText(asset.metadata)
                : _stringify(asset.metadata),
            canonical:
                _stringify(asset.metadata).contains('LOCATION_MASTER') ||
                _stringify(asset.metadata).contains('WORLD_ENVIRONMENT_MASTER'),
            metadata: asset.metadata is Map
                ? Map<String, dynamic>.from(asset.metadata as Map)
                : const {},
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
    final bible = plan == null
        ? <String, dynamic>{'source': item.sourceLabel}
        : _bibleFromRemotePlan(plan);
    bible['scene_cards'] = _normalizeSceneCards(
      bible['scene_cards'] ?? plan?.sceneCards,
    );
    var episodes = _episodesFromRemoteSources(
      current: const [],
      bible: bible,
      plan: plan,
    );
    if (episodes.isEmpty) {
      episodes = [
        ProductionEpisodeItem(
          number: 1,
          title: 'Episódio 1',
          summary: '',
          cliffhanger: '',
          durationSeconds: takes.fold<int>(
            0,
            (sum, take) => sum + take.durationSeconds,
          ),
          takes: takes,
          musicPrompt:
              'Cama musical continua para o episódio, sem competir com as falas.',
        ),
      ];
    } else if (takes.isNotEmpty && episodes.first.takes.isEmpty) {
      episodes = [
        ProductionEpisodeItem(
          number: episodes.first.number,
          title: episodes.first.title,
          summary: episodes.first.summary,
          cliffhanger: episodes.first.cliffhanger,
          durationSeconds: episodes.first.durationSeconds,
          status: episodes.first.status,
          takes: takes,
          externalMusic: episodes.first.externalMusic,
          musicProvider: episodes.first.musicProvider,
          musicPrompt: episodes.first.musicPrompt,
          musicStatus: episodes.first.musicStatus,
          musicVolume: episodes.first.musicVolume,
          dialogueVolume: episodes.first.dialogueVolume,
          ambienceVolume: episodes.first.ambienceVolume,
          assembledOutputUrl: episodes.first.assembledOutputUrl,
        ),
        ...episodes.skip(1),
      ];
    }
    return ProductionProject(
      id: 'remote-${item.routeId}',
      virtualId: item.routeId,
      title: item.title,
      description: item.description,
      genre: item.genre,
      formatFamily: _resolvedFormatFamily(null, bible: bible),
      status: item.status,
      sourcePath: 'Vertix API / serie ${item.routeId}',
      coverUrl: item.coverUrl,
      targetEpisodeCount: item.targetEpisodeCount < 1
          ? episodes.length
          : item.targetEpisodeCount,
      isLocal: false,
      updatedAt: DateTime.now(),
      seriesBible: bible,
      episodes: episodes,
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
