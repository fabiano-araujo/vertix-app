import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'admin_service.dart';

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
        canonical: json['canonical'] as bool? ?? false,
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
        usePreviousLastFrame: json['usePreviousLastFrame'] as bool? ?? false,
        generateSeedanceAudio: json['generateSeedanceAudio'] as bool? ?? false,
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
        externalMusic: json['externalMusic'] as bool? ?? true,
        musicProvider: json['musicProvider'] as String? ?? 'API externa',
        musicPrompt: json['musicPrompt'] as String? ?? '',
        musicStatus: json['musicStatus'] as String? ?? 'DRAFT',
        musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.36,
        dialogueVolume: (json['dialogueVolume'] as num?)?.toDouble() ?? 0.9,
        ambienceVolume: (json['ambienceVolume'] as num?)?.toDouble() ?? 0.48,
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
        isLocal: json['isLocal'] as bool? ?? true,
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

class LocalProductionWorkspaceService {
  static const _workspaceKey = 'vertix_local_production_workspace_v5';
  static const _remoteOverlayPrefix = 'vertix_remote_production_editor_v2_';
  static final LocalProductionWorkspaceService _instance =
      LocalProductionWorkspaceService._internal();

  factory LocalProductionWorkspaceService() => _instance;
  LocalProductionWorkspaceService._internal();

  List<ProductionProject>? _cache;

  Future<List<ProductionProject>> getProjects() async {
    if (_cache != null) return List.unmodifiable(_cache!);
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
    return List.unmodifiable(_cache!);
  }

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
            'Noa perde o ar quando o colar respiratorio congela no Banco Termico. Lys o segura no lado esquerdo enquanto Tarik permanece no terminal a direita. Filme live-action fotorrealista, vertical 9:16, 10 segundos, movimento corporal com peso real, eixo espacial preservado e final com Lys sustentando Noa diante de Tarik.',
        audioPrompt:
            '[0.8-2.2s] SISTEMA, voz feminina sintetica pt-BR: "Credito termico recusado." [3.2-6.0s] LYS, urgente: "So uma carga. O colar dele esta parando." [6.8-8.7s] TARIK, firme: "Seu saldo acabou." Sem musica; tempestade, terminal, alarme, respiracao e tecido.',
        notes: 'Terminar durante a acao de Lys sustentando e baixando Noa.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t02',
        number: 2,
        title: 'O limite',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: sharedCharacters,
        visualPrompt:
            'Comece apos um corte seco, no meio da mesma acao: Lys termina de apoiar Noa no banco a esquerda e estende o pulso ao leitor. Tarik consulta o limite no terminal a direita. Use novo angulo lateral motivado, no mesmo lado do eixo, e termine quando Noa revela a primeira borda do fragmento.',
        audioPrompt:
            '[1.3-3.2s] LYS: "Entao desconta de mim." [4.5-6.9s] TARIK: "Voce ja passou do limite." Carregar tempestade, terminal, respiracao e alarme do take anterior; sem musica e sem fala improvisada.',
        notes:
            'O frame anterior define apenas bloqueio, postura, luz e objeto; identidade vem das fichas.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t03',
        number: 3,
        title: 'O fragmento de Mara',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Noa retira do colar o fragmento azul-negro e o entrega a Lys. Tarik reconhece o objeto, fecha a divisoria e baixa a voz. Preserve Lys e Noa a esquerda, Tarik a direita, o fragmento entre os lados e a geografia do Banco Termico.',
        audioPrompt:
            '[1.0-3.7s] NOA, fraco: "A mae disse pra usar so se eu piorasse." [5.0-8.8s] TARIK, tenso: "Isso nao tem registro. Se eu conectar, a coleta vem." Sem musica, legendas ou palavras extras.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t04',
        number: 4,
        title: 'O preco',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Lys empurra o fragmento para Tarik; ele o encaixa no soquete termico central enquanto Noa piora a esquerda. O terminal exige uma memoria e Noa tenta impedir a irma. Termine no olhar de decisao de Lys para o cristal.',
        audioPrompt:
            '[0.9-2.8s] LYS: "Se nao conectar, ele morre aqui." [3.8-5.8s] TARIK: "Ele vai cobrar uma lembranca." [6.6-8.8s] NOA: "Voce ja deu a voz do pai." Vozes fixas pt-BR; ambiente continuo; sem musica.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t05',
        number: 5,
        title: 'A escolha',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: sharedWithLumen,
        visualPrompt:
            'Lys toca o rosto de Noa, levanta e oferece a palma direita sobre o Lumen. Preserve o cordao vermelho, a luva removida e o fragmento no centro. O pulso ambar reconhece a lembranca e viaja ao terminal.',
        audioPrompt:
            '[0.8-2.6s] LYS: "E voce ainda esta aqui." [3.4-5.4s] TARIK: "Escolhe uma. Seja especifica." [6.2-8.3s] LYS: "O rosto da minha mae." Sem fala nas bordas e sem musica.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t06',
        number: 6,
        title: 'O nome conhecido',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: sharedWithLumen,
        visualPrompt:
            'O pulso revela um padrao no terminal. Tarik reconhece Mara e Lys percebe. O alarme de Noa fica continuo; Lys toca o cristal e o calor corre pelo tubo enquanto uma silhueta ambar comeca a se formar.',
        audioPrompt:
            '[1.1-2.4s] TARIK, surpreso: "Mara Arven?" [3.1-4.7s] LYS, desconfiada: "Como voce sabe?" Depois de 5s, sem dialogo: alarme, tubo aquecendo, respiracao e reverb frio.',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t07',
        number: 7,
        title: 'Quem e ela?',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: [
          'nivalis-lys',
          'nivalis-noa',
          'nivalis-banco',
          'nivalis-lumen',
        ],
        visualPrompt:
            'O calor derrete o gelo no colar e Noa volta a respirar. O eco de Mara se resolve acima do cristal. Lys observa sem reconhecer o rosto que acabou de perder. Termine quando a projecao se fragmenta apos o aviso.',
        audioPrompt:
            '[1.5-2.8s] LYS: "Quem e ela?" [3.2-4.3s] NOA: "Nossa mae." [5.0-9.0s] MARA, quente com reverb cristalino: "Lys, pega o Noa e foge. Eles querem o que ele lembra."',
      ),
      ProductionTakeItem(
        id: 'nivalis-ep01-t08',
        number: 8,
        title: 'Coleta autorizada',
        durationSeconds: 10,
        usePreviousLastFrame: true,
        referenceIds: sharedCharacters,
        visualPrompt:
            'A projecao desaparece, a porta de aco fecha e luzes vermelhas substituem o ambar. Tarik fica entre os agentes e os irmaos; Lys protege Noa. Tarik toca o bastao sem sacar. Corte antes de revelar seu lado.',
        audioPrompt:
            '[1.4-5.8s] SISTEMA, voz feminina fria: "Eco proibido detectado. Coleta autorizada: Noa Arven." Depois, passos armados, alarme e respiracao. Sem musica; sustentar o silencio do cliffhanger.',
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
      updatedAt: DateTime(2026, 8, 8),
      seriesBible: const {
        'logline':
            'Calor custa memorias; uma cartografa decide o que esquecer para manter o irmao vivo.',
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
