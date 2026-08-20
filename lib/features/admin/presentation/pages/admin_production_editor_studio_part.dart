part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorStudioExtension
    on _AdminProductionEditorPageState {
  Widget _buildEpisodeProductionScaffold() {
    final episode = _episode!;
    return Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: SafeArea(
        child: Column(
          children: [
            _buildEpisodeProductionTopBar(episode),
            const Divider(height: 1, color: AppColors.surfaceLighter),
            Expanded(child: _buildTakes()),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeProductionTopBar(ProductionEpisodeItem episode) {
    final beats = episode.takes.length;
    final duration = episode.takes.fold<int>(
      0,
      (sum, take) => sum + take.durationSeconds,
    );
    final displayTitle = _episodeDisplayTitle(
      episode,
      _episodeCardFor(_project!, episode.number),
    );
    final backButton = TextButton.icon(
      onPressed: _leaveEpisodeProduction,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('De volta à bancada'),
    );
    final boardButton = OutlinedButton.icon(
      onPressed: _openProjectBoard,
      icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
      label: const Text('Abrir quadro do projeto'),
    );
    final exportButton = FilledButton(
      onPressed: _showEpisodePreview,
      child: const Text('Exportar'),
    );
    final saveButton = IconButton(
      tooltip: 'Salvar',
      onPressed: _isSaving ? null : _saveProject,
      icon: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
    );
    return ColoredBox(
      color: const Color(0xFF17191D),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final title = Column(
            children: [
              Text(
                'Episódio ${episode.number} $displayTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$beats batidas · ${duration}s',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          if (compact) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'De volta à bancada',
                        onPressed: _leaveEpisodeProduction,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(child: title),
                      saveButton,
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openProjectBoard,
                            icon: const Icon(
                              Icons.dashboard_customize_outlined,
                              size: 16,
                            ),
                            label: const Text('Quadro do projeto'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _showEpisodePreview,
                          child: const Text('Exportar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  backButton,
                  TextButton(
                    onPressed: () => _showStudioMessage(
                      'Envie seu feedback pelo canal da equipe.',
                    ),
                    child: const Text('Feedback'),
                  ),
                  Expanded(child: title),
                  boardButton,
                  const SizedBox(width: 8),
                  exportButton,
                  saveButton,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInlineEpisodeScriptPane() {
    final project = _project!;
    final episode = _episode;
    if (episode == null) {
      return const ColoredBox(
        color: Color(0xFF121418),
        child: Center(child: Text('Selecione um episódio.')),
      );
    }
    final script = _episodeScriptFor(project, episode.number);
    final scenes = (script['scenes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final scriptLocked = script['status'] == 'LOCKED_FOR_PRODUCTION';
    final productionReady = episode.takes.isNotEmpty;
    final generating = _generatingScriptEpisodeNumber == episode.number;
    final displayTitle = _episodeDisplayTitle(
      episode,
      _episodeCardFor(project, episode.number),
    );
    final durationWarning = (script['quality_gate'] as Map?)?['persist_warning']
        ?.toString();
    return ColoredBox(
      color: const Color(0xFF121418),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final approveButton = FilledButton.icon(
                onPressed: productionReady
                    ? () => _openEpisodeProduction()
                    : generating || _isApprovingScript || scenes.isEmpty
                    ? null
                    : _approveEpisodeScriptForProduction,
                icon: _isApprovingScript
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        productionReady
                            ? Icons.movie_filter_outlined
                            : Icons.lock_outline,
                        size: 18,
                      ),
                label: Text(
                  productionReady
                      ? (compact ? 'Produção' : 'Produção de vídeo')
                      : _isApprovingScript
                      ? 'Preparando...'
                      : (compact ? 'Aprovar' : 'Aprovar produção'),
                ),
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Voltar ao esboço',
                                onPressed: () => setState(
                                  () => _showEpisodeScriptEditor = false,
                                ),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Expanded(
                                child: Text(
                                  'EP${episode.number} · $displayTitle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Salvar',
                                onPressed: _isSaving ? null : _saveProject,
                                icon: const Icon(Icons.save_outlined),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 4, 6),
                            child: approveButton,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          IconButton(
                            tooltip: 'Voltar ao esboço',
                            onPressed: () => setState(
                              () => _showEpisodeScriptEditor = false,
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Expanded(
                            child: Text(
                              'EP${episode.number} · $displayTitle · Roteiro',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isSaving ? null : _saveProject,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Salvar'),
                          ),
                          const SizedBox(width: 8),
                          approveButton,
                        ],
                      ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: scenes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        generating
                            ? 'A IA está escrevendo o roteiro deste episódio...'
                            : 'Ainda não há cenas. Gere o roteiro para editar.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _panel(
                        title: 'Roteiro do episódio',
                        icon: Icons.description_outlined,
                        trailing: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _pill('${scenes.length} cenas'),
                            _pill('${script['shot_count'] ?? 0} shots'),
                            _pill(_timecode(episode.durationSeconds)),
                            _pill(
                              scriptLocked ? 'BLOQUEADO' : 'EDITÁVEL',
                              scriptLocked
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        child: Text(
                          durationWarning == null || durationWarning.isEmpty
                              ? 'Revise falas, ações e durações à direita. O progresso da geração aparece no chat.'
                              : 'Roteiro salvo para revisão. Ajuste as durações se necessário: $durationWarning',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...scenes.asMap().entries.map(
                        (entry) => _buildEditableScriptSceneCard(
                          entry.value,
                          sceneIndex: entry.key,
                          locked: scriptLocked,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableScriptSceneCard(
    Map<String, dynamic> scene, {
    required int sceneIndex,
    required bool locked,
  }) {
    final shots = (scene['shots'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceLight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Cena ${_sceneNumber(scene, fallback: sceneIndex + 1)} · ${_sceneTitle(scene)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _pill('${shots.length} planos'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    _sceneLocation(scene),
                    scene['time_of_day'],
                    scene['interior_exterior'],
                  ].where((item) => _visibleText(item).isNotEmpty).join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: scene['story']?.toString() ?? '',
                  minLines: 2,
                  maxLines: 5,
                  enabled: !locked,
                  decoration: const InputDecoration(
                    labelText: 'Beats da cena',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) => _patchEpisodeScriptField(
                    sceneIndex: sceneIndex,
                    updater: (current) => {...current, 'story': value},
                  ),
                ),
                const SizedBox(height: 16),
                ...shots.asMap().entries.map(
                  (entry) => _buildEditableScriptShot(
                    entry.value,
                    sceneIndex: sceneIndex,
                    shotIndex: entry.key,
                    locked: locked,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableScriptShot(
    Map<String, dynamic> shot, {
    required int sceneIndex,
    required int shotIndex,
    required bool locked,
  }) {
    final rows = (shot['rows'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plano ${shot['number']} · ${shot['duration_seconds']}s',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...rows.asMap().entries.map((entry) {
            final row = entry.value;
            final duration = row['duration_seconds'];
            final isDialogue = row['type'] == 'dialogue';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                initialValue: isDialogue
                    ? '${row['speaker']}: ${row['text']}'
                    : row['text']?.toString() ?? '',
                minLines: 1,
                maxLines: 4,
                enabled: !locked,
                decoration: InputDecoration(
                  labelText: isDialogue
                      ? 'Diálogo (${duration}s)'
                      : 'Ação (${duration}s)',
                ),
                onChanged: (value) => _patchEpisodeScriptRow(
                  sceneIndex: sceneIndex,
                  shotIndex: shotIndex,
                  rowIndex: entry.key,
                  text: value,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _patchEpisodeScriptField({
    required int sceneIndex,
    required Map<String, dynamic> Function(Map<String, dynamic> scene) updater,
  }) {
    _rewriteCurrentEpisodeScript((script) {
      final scenes = (script['scenes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (sceneIndex < 0 || sceneIndex >= scenes.length) return script;
      scenes[sceneIndex] = updater(scenes[sceneIndex]);
      return {...script, 'scenes': scenes};
    });
  }

  void _patchEpisodeScriptRow({
    required int sceneIndex,
    required int shotIndex,
    required int rowIndex,
    required String text,
  }) {
    _rewriteCurrentEpisodeScript((script) {
      final scenes = (script['scenes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (sceneIndex < 0 || sceneIndex >= scenes.length) return script;
      final scene = Map<String, dynamic>.from(scenes[sceneIndex]);
      final shots = (scene['shots'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (shotIndex < 0 || shotIndex >= shots.length) return script;
      final shot = Map<String, dynamic>.from(shots[shotIndex]);
      final rows = (shot['rows'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (rowIndex < 0 || rowIndex >= rows.length) return script;
      final row = Map<String, dynamic>.from(rows[rowIndex]);
      if (row['type'] == 'dialogue') {
        final split = text.split(':');
        if (split.length > 1) {
          row['speaker'] = split.first.trim();
          row['text'] = split.sublist(1).join(':').trim();
        } else {
          row['text'] = text.trim();
        }
      } else {
        row['text'] = text.trim();
      }
      rows[rowIndex] = row;
      shot['rows'] = rows;
      shots[shotIndex] = shot;
      scene['shots'] = shots;
      scenes[sceneIndex] = scene;
      return {...script, 'scenes': scenes};
    });
  }

  void _rewriteCurrentEpisodeScript(
    Map<String, dynamic> Function(Map<String, dynamic> script) update,
  ) {
    final project = _project;
    final episode = _episode;
    if (project == null || episode == null) return;
    final scripts =
        (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final index = scripts.indexWhere(
      (item) => _studioEpisodeNumber(item['episode']) == episode.number,
    );
    if (index < 0) return;
    final updatedScript = update(Map<String, dynamic>.from(scripts[index]));
    scripts[index] = updatedScript;
    final otherScenes =
        (project.seriesBible['scene_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (item) => _studioEpisodeNumber(item['episode']) != episode.number,
            )
            .toList();
    final sceneCards = [
      ...otherScenes,
      ...(updatedScript['scenes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)),
    ];
    setState(() {
      _project = project.copyWith(
        seriesBible: {
          ...project.seriesBible,
          'episode_scripts': scripts,
          'scene_cards': sceneCards,
        },
      );
    });
    _schedulePersist();
  }

  Widget _buildStudioMainPane() {
    return switch (_studioTabIndex) {
      0 => ColoredBox(color: const Color(0xFF121418), child: _buildOverview()),
      1 =>
        _showEpisodeScriptEditor
            ? _buildInlineEpisodeScriptPane()
            : _buildScript(),
      2 => _buildReferences(
        categories: const {
          'CHARACTER_MASTER',
          'CHARACTER_REFERENCE',
          'OPPOSING_FORCE_MASTER',
        },
        title: 'Personagens',
        emptyLabel: 'Nenhum personagem foi definido para esta obra.',
        addLabel: 'Adicionar personagem',
        initialCategory: 'CHARACTER_REFERENCE',
        sheetFamily: 'characters',
      ),
      3 => _buildReferences(
        categories: const {
          'LOCATION_MASTER',
          'LOCATION_REFERENCE',
          'ENVIRONMENT_MASTER',
          'WORLD_ENVIRONMENT_MASTER',
        },
        title: 'Ambientes',
        emptyLabel: 'Nenhum ambiente foi definido para esta obra.',
        addLabel: 'Adicionar ambiente',
        initialCategory: 'LOCATION_MASTER',
        sheetFamily: 'locations',
      ),
      4 => _buildReferences(
        categories: const {
          'PROP_MASTER',
          'PROP_REFERENCE',
          'OBJECT_MASTER',
          'OBJECT_REFERENCE',
        },
        title: 'Adereços',
        emptyLabel: 'Nenhum adereço foi definido para esta obra.',
        addLabel: 'Adicionar adereço',
        initialCategory: 'OBJECT_REFERENCE',
        sheetFamily: 'props',
      ),
      _ => _buildScript(),
    };
  }

  Widget _buildTechnicalEditorScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showTechnicalEditor = false),
        ),
        title: Text('${_project?.title ?? 'Studio'} · quadro do projeto'),
        actions: [
          IconButton(
            tooltip: 'Salvar na API',
            onPressed: _isSaving ? null : _saveProject,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: _loadProject,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildEditor(),
    );
  }

  Widget _buildStudioWorkbenchScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildStudioTopBar(),
            const Divider(height: 1),
            ?_seriesCoverGenerationBanner(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chatBrief = _isChatBrief;
                  final showAssistant =
                      chatBrief || constraints.maxWidth >= 900;
                  if (chatBrief && constraints.maxWidth < 900) {
                    return _buildWritingAssistant();
                  }
                  return Row(
                    children: [
                      if (showAssistant) ...[
                        SizedBox(
                          width: (constraints.maxWidth * .38).clamp(360, 500),
                          child: _buildWritingAssistant(),
                        ),
                        const VerticalDivider(width: 1),
                      ],
                      Expanded(child: _buildStudioMainPane()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioTopBar() {
    final project = _project!;
    const tabs = [
      (Icons.tune, 'Ajustes'),
      (Icons.auto_stories_outlined, 'Esboço e roteiro'),
      (Icons.people_outline, 'Personagens'),
      (Icons.landscape_outlined, 'Ambientes'),
      (Icons.inventory_2_outlined, 'Adereços'),
    ];
    return ColoredBox(
      color: const Color(0xFF17191D),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final wide = constraints.maxWidth >= 1180;
          final saveButton = IconButton(
            tooltip: 'Salvar',
            onPressed: _isSaving ? null : _saveProject,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          );
          final boardButton = compact
              ? IconButton(
                  tooltip: 'Quadro do projeto',
                  onPressed: () => setState(() => _showTechnicalEditor = true),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                )
              : OutlinedButton.icon(
                  onPressed: () => setState(() => _showTechnicalEditor = true),
                  icon: const Icon(
                    Icons.dashboard_customize_outlined,
                    size: 18,
                  ),
                  label: Text(wide ? 'Abrir quadro do projeto' : 'Quadro'),
                );
          final title = Text(
            project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          );
          if (compact) {
            return Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Voltar',
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(child: title),
                      if (_isAutomaticPreparationRunning)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '$_automaticPreparationCompleted/$_automaticPreparationTotal',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      boardButton,
                      saveButton,
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final selected = _studioTabIndex == index;
                      return ChoiceChip(
                        avatar: Icon(tabs[index].$1, size: 16),
                        label: Text(tabs[index].$2),
                        selected: selected,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.primary.withAlpha(55),
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceLighter,
                        ),
                        onSelected: (_) => _selectStudioTab(index),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          return SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Flexible(flex: 2, child: title),
                  if (wide) ...[
                    const SizedBox(width: 22),
                    TextButton(
                      onPressed: () => _showStudioMessage(
                        'Envie seu feedback pelo canal da equipe.',
                      ),
                      child: const Text('Feedback'),
                    ),
                  ],
                  const SizedBox(width: 12),
                  if (wide)
                    ...List.generate(tabs.length, (index) {
                      final selected = _studioTabIndex == index;
                      return _studioTopTab(
                        icon: tabs[index].$1,
                        label: tabs[index].$2,
                        selected: selected,
                        onTap: () => _selectStudioTab(index),
                      );
                    })
                  else
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<int>(
                          tooltip: 'Seções do projeto',
                          initialValue: _studioTabIndex,
                          onSelected: _selectStudioTab,
                          itemBuilder: (_) => List.generate(
                            tabs.length,
                            (index) => PopupMenuItem(
                              value: index,
                              child: Row(
                                children: [
                                  Icon(tabs[index].$1, size: 18),
                                  const SizedBox(width: 10),
                                  Text(tabs[index].$2),
                                ],
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tabs[_studioTabIndex].$1, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    tabs[_studioTabIndex].$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  boardButton,
                  if (_isAutomaticPreparationRunning) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Preparação $_automaticPreparationCompleted/$_automaticPreparationTotal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  saveButton,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _studioTopTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? AppColors.primaryLight : AppColors.textTertiary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildWritingAssistant() {
    if (_isChatBrief) return _buildCreationAssistant();
    final project = _project!;
    final episode = _episode;
    if (episode == null) {
      return const ColoredBox(
        color: Color(0xFF14161A),
        child: Center(
          child: Text(
            'Descreva a ideia no chat para gerar o esboço.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final hasDetailedScript = _hasEpisodeScriptDraft(project, episode.number);
    final productionReady = episode.takes.isNotEmpty;
    final hasReadyOutline = _episodeHasReadyOutline(episode);
    final continueBatch = _nextOutlineBatch(project);
    final characterCount = project.references
        .where((item) => item.category.contains('CHARACTER'))
        .length;
    final nextEpisodeIndex = _episodeIndex + 1;
    final hasNextEpisode = nextEpisodeIndex < project.episodes.length;
    final nextEpisode = hasNextEpisode
        ? project.episodes[nextEpisodeIndex]
        : null;
    final previewText = _visibleText(episode.summary).isNotEmpty
        ? _visibleText(episode.summary)
        : _bibleText(project, 'logline', fallback: project.description);
    return ColoredBox(
      color: const Color(0xFF14161A),
      child: Column(
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF9B8CFF)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Assistente de redação de IA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _assistantConversationScroller(
              children: [
                _buildAssistantTurns(
                  fallback: Text(
                    previewText,
                    maxLines: 12,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.55,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  continueBatch != null
                      ? '${_readyOutlineCount(project)} de ${project.targetEpisodeCount} episódios têm texto-base. O próximo lote é EP${continueBatch['fromEpisode']}-${continueBatch['throughEpisode']}.'
                      : productionReady
                      ? 'O EP${episode.number} · ${episode.title} está pronto para produção de vídeo.'
                      : hasDetailedScript
                      ? 'O roteiro do EP${episode.number} · ${episode.title} está pronto. Como você quer seguir?'
                      : hasReadyOutline
                      ? 'O esboço do EP${episode.number} · ${episode.title} está na área de trabalho. Escolha o próximo passo.'
                      : 'Este episódio ainda não tem o texto-base. Continue o esboço antes de gerar o roteiro.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                if (continueBatch != null) ...[
                  _assistantChoiceButton(
                    label:
                        'Continuar o texto-base EP${continueBatch['fromEpisode']}-${continueBatch['throughEpisode']}',
                    onTap: _isAnyGenerationBusy
                        ? null
                        : () => _generateSeriesOutlineWithCodex(
                            fromEpisode: continueBatch['fromEpisode'] as int,
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
                _assistantChoiceButton(
                  label: characterCount == 0
                      ? 'Gerar personagens/locações/props antes de continuar'
                      : 'Revisar personagens, locações e props',
                  onTap: _isAnyGenerationBusy
                      ? null
                      : () {
                          if (characterCount == 0) {
                            _generateStorySheetsWithCodex();
                          } else {
                            setState(() => _studioTabIndex = 2);
                          }
                        },
                ),
                const SizedBox(height: 8),
                _assistantChoiceButton(
                  label: continueBatch != null
                      ? 'Quero revisar o texto-base do Episódio ${episode.number}'
                      : hasNextEpisode &&
                            nextEpisode != null &&
                            _episodeHasReadyOutline(nextEpisode)
                      ? 'Continuar direto para o roteiro do Episódio ${nextEpisode.number}'
                      : productionReady
                      ? 'Entrar na produção de vídeo deste episódio'
                      : hasDetailedScript
                      ? 'Aprovar e liberar a produção de vídeo'
                      : hasReadyOutline
                      ? 'Gerar o roteiro detalhado deste episódio'
                      : 'Gerar o texto-base deste episódio',
                  onTap: _isAnyGenerationBusy
                      ? null
                      : () {
                          if (continueBatch != null && !hasReadyOutline) {
                            _generateSeriesOutlineWithCodex(
                              fromEpisode: continueBatch['fromEpisode'] as int,
                            );
                            return;
                          }
                          if (hasNextEpisode &&
                              nextEpisode != null &&
                              _episodeHasReadyOutline(nextEpisode) &&
                              continueBatch == null) {
                            setState(() => _episodeIndex = nextEpisodeIndex);
                            _generateEpisodeScript(nextEpisodeIndex);
                            return;
                          }
                          if (productionReady || hasDetailedScript) {
                            _openEpisodeProduction();
                            return;
                          }
                          if (hasReadyOutline) {
                            _generateEpisodeScript(_episodeIndex);
                            return;
                          }
                          _generateSeriesOutlineWithCodex(
                            fromEpisode: episode.number,
                          );
                        },
                ),
                const SizedBox(height: 8),
                _assistantChoiceButton(
                  label: 'Quero revisar algo no Episódio ${episode.number}',
                  onTap: () => setState(() {
                    _studioTabIndex = 1;
                    _showEpisodeScriptEditor = hasDetailedScript;
                  }),
                ),
              ],
            ),
          ),
          _buildAssistantComposer(),
        ],
      ),
    );
  }

  Widget _buildCreationAssistant() {
    final project = _project!;
    final bible = project.seriesBible;
    final styleFamily =
        bible['creation_style_family']?.toString() ?? 'live_action';
    final visualStyle =
        bible['visual_style']?.toString() ?? 'Microdrama moderno';
    final genre = bible['genre']?.toString() ?? project.genre;
    final background = bible['background']?.toString() ?? 'Cidade moderna';
    final trope = bible['trope']?.toString() ?? 'Segunda chance';
    final language = bible['language']?.toString() ?? 'Português (Brasil)';
    final rating = bible['rating']?.toString() ?? '14 anos';
    final episodeCount = project.targetEpisodeCount.clamp(1, 80);
    final firstDuration =
        (bible['first_episode_duration_seconds'] as num?)?.toInt() ?? 120;
    final otherDuration =
        (bible['episode_duration_seconds'] as num?)?.toInt() ?? 60;
    final automaticPreparation =
        bible['automatic_preparation_requested'] == true;
    final styles = styleFamily == 'animation'
        ? const ['Animação cinematográfica']
        : styleFamily == 'custom'
        ? MicroDramaThemeComposer.visualStyleOptions
        : MicroDramaThemeComposer.liveActionStyles;
    return ColoredBox(
      color: const Color(0xFF14161A),
      child: Column(
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF9B8CFF)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Assistente de redação de IA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _assistantConversationScroller(
              children: [
                const Text(
                  'Comece a criar seu drama curto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _creationFamilyTabs(styleFamily, visualStyle),
                const SizedBox(height: 12),
                _creationStyleGrid(visualStyle, styles),
                const SizedBox(height: 18),
                const Text(
                  'Ajustes básicos',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _videoGenerationPresetPicker(
                  selectedId:
                      bible['video_generation_profile']?.toString() ?? '',
                ),
                const SizedBox(height: 10),
                _creationEpisodeMode(episodeCount),
                const SizedBox(height: 10),
                _creationSettingDropdown<int>(
                  label: 'Número de episódios',
                  value: episodeCount,
                  values: episodeCount == 1
                      ? const [1]
                      : const [8, 12, 20, 50, 80],
                  labelFor: (value) =>
                      value == 1 ? 'Episódio único' : '$value episódios',
                  onChanged: episodeCount == 1
                      ? null
                      : (value) =>
                            unawaited(_patchChatBrief(episodeCount: value)),
                ),
                const SizedBox(height: 10),
                _creationSettingDropdown<int>(
                  label: 'Duração do primeiro episódio',
                  value: firstDuration,
                  values: const [60, 90, 120],
                  labelFor: (value) => '$value segundos',
                  onChanged: (value) => unawaited(
                    _patchChatBrief(firstEpisodeDurationSeconds: value),
                  ),
                ),
                if (episodeCount > 1) ...[
                  const SizedBox(height: 10),
                  _creationSettingDropdown<int>(
                    label: 'Duração dos demais',
                    value: otherDuration,
                    values: const [45, 60, 90],
                    labelFor: (value) => '$value segundos',
                    onChanged: (value) => unawaited(
                      _patchChatBrief(episodeDurationSeconds: value),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _creationSettingDropdown<String>(
                  label: 'Idioma do vídeo',
                  value: language,
                  values: const [
                    'Português (Brasil)',
                    'Português (Portugal)',
                    'English',
                    'Español',
                  ],
                  labelFor: (value) => value,
                  onChanged: (value) =>
                      unawaited(_patchChatBrief(language: value)),
                ),
                const SizedBox(height: 10),
                _creationSettingDropdown<String>(
                  label: 'Classificação',
                  value: rating,
                  values: const [
                    'Livre',
                    '10 anos',
                    '12 anos',
                    '14 anos',
                    '16 anos',
                  ],
                  labelFor: (value) => value,
                  onChanged: (value) =>
                      unawaited(_patchChatBrief(rating: value)),
                ),
                const SizedBox(height: 10),
                _creationSettingDropdown<String>(
                  label: 'Gênero',
                  value: genre,
                  values: MicroDramaThemeComposer.genreOptions,
                  labelFor: (value) => value,
                  onChanged: (value) =>
                      unawaited(_patchChatBrief(genre: value)),
                ),
                const SizedBox(height: 10),
                _creationSettingDropdown<String>(
                  label: 'Cenário',
                  value: background,
                  values: MicroDramaThemeComposer.backgroundOptions,
                  labelFor: (value) => value,
                  onChanged: (value) =>
                      unawaited(_patchChatBrief(background: value)),
                ),
                const SizedBox(height: 10),
                _creationSettingDropdown<String>(
                  label: 'Tropo / tema',
                  value: trope,
                  values: MicroDramaThemeComposer.tropeOptions,
                  labelFor: (value) => value,
                  onChanged: (value) =>
                      unawaited(_patchChatBrief(trope: value)),
                ),
                const SizedBox(height: 14),
                _creationAutoGenerateTile(automaticPreparation),
                const SizedBox(height: 14),
                _buildAssistantTurns(
                  fallback: const Text(
                    'Descreva a ideia da sua história no bate-papo abaixo. O contrato da série — logline, protagonista, força oposta, pergunta central e risco — será pensado aqui, a partir do tema escolhido.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.55,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_pendingChatContract != null && !automaticPreparation) ...[
                  const SizedBox(height: 10),
                  _assistantChoiceButton(
                    label: 'Criar esboço da série com este contrato',
                    onTap: _isAnyGenerationBusy
                        ? null
                        : () => unawaited(_applyPendingChatContract()),
                  ),
                ],
              ],
            ),
          ),
          _buildAssistantComposer(),
        ],
      ),
    );
  }

  Widget _creationFamilyTabs(String selected, String visualStyle) {
    const tabs = [
      ('live_action', 'Live Action'),
      ('animation', 'Animação'),
      ('custom', 'Personalizado'),
    ];
    return Row(
      children: tabs
          .map(
            (tab) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: tab.$1 == 'custom' ? 0 : 8),
                child: InkWell(
                  onTap: () {
                    String? nextStyle;
                    if (tab.$1 == 'animation') {
                      nextStyle = 'Animação cinematográfica';
                    } else if (tab.$1 == 'live_action' &&
                        visualStyle == 'Animação cinematográfica') {
                      nextStyle = 'Microdrama moderno';
                    }
                    unawaited(
                      _patchChatBrief(
                        styleFamily: tab.$1,
                        visualStyle: nextStyle,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected == tab.$1
                          ? Colors.white12
                          : const Color(0xFF1A1C21),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected == tab.$1
                            ? Colors.white38
                            : const Color(0xFF3A3D45),
                      ),
                    ),
                    child: Text(
                      tab.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected == tab.$1
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _creationStyleGrid(String selected, List<String> styles) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: styles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final style = styles[index];
        final active = style == selected;
        return InkWell(
          onTap: () => unawaited(_patchChatBrief(visualStyle: style)),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1E24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? const Color(0xFF9B8CFF)
                    : const Color(0xFF3A3D45),
                width: active ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _creationStyleIcon(style),
                      size: 18,
                      color: const Color(0xFF9B8CFF),
                    ),
                    const Spacer(),
                    if (active)
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Color(0xFF9B8CFF),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _creationStyleIcon(String style) => switch (style) {
    'Cinema teatral realista' => Icons.theaters_outlined,
    'K-drama moderno' => Icons.favorite_border,
    'Noir urbano' => Icons.nights_stay_outlined,
    'Animação cinematográfica' => Icons.animation,
    _ => Icons.movie_outlined,
  };

  Widget _creationEpisodeMode(int episodeCount) {
    final single = episodeCount <= 1;
    return Row(
      children: [
        Expanded(
          child: _creationModeChip(
            label: 'Episódio único',
            selected: single,
            onTap: () => unawaited(_patchChatBrief(episodeCount: 1)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _creationModeChip(
            label: 'Vários episódios',
            selected: !single,
            onTap: () => unawaited(_patchChatBrief(episodeCount: 8)),
          ),
        ),
      ],
    );
  }

  Widget _creationModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withAlpha(38)
            : const Color(0xFF1A1C21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFF3A3D45),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _videoGenerationPresetPicker({required String selectedId}) {
    final selected = VideoGenerationPreset.fromBible(
      _project?.seriesBible ?? const {},
    );
    final effectiveId = selectedId.isNotEmpty ? selectedId : selected.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Geração de vídeo',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...VideoGenerationPreset.catalog.map((preset) {
          final isSelected = effectiveId == preset.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => unawaited(_setVideoGenerationPreset(preset.id)),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2A2D34)
                      : const Color(0xFF1A1C21),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white38
                        : const Color(0xFF3A3D45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                preset.modelLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              _videoPresetBadge(
                                preset.durationLabel,
                                const Color(0xFF3A3D45),
                              ),
                              if (preset.recommended)
                                _videoPresetBadge(
                                  'Recomendado',
                                  const Color(0xFF6D5AE6),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 2),
                        child: Icon(Icons.check, size: 18),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _videoPresetBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _creationSettingDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T>? onChanged,
  }) {
    final effectiveValue = values.contains(value) ? value : values.first;
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-${values.join('|')}'),
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF1C1E24),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
    );
  }

  Widget _creationAutoGenerateTile(bool value) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: (next) =>
            unawaited(_patchChatBrief(automaticPreparation: next)),
        title: const Text('Gerar tudo automaticamente'),
        subtitle: const Text(
          'Ao enviar a ideia no chat, a API de IA cria o título, o contrato, o esboço, personagens, ambientes e adereços.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        secondary: const Icon(Icons.auto_awesome_motion_outlined),
      ),
    );
  }

  Widget _creationContractCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contrato da série',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Gerado a partir do tema e da ideia. Revise no chat antes de avançar.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contractTitleController,
          decoration: const InputDecoration(labelText: 'Título de trabalho'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contractLoglineController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Logline / premissa em uma frase',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contractProtagonistController,
          decoration: const InputDecoration(labelText: 'Protagonista'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contractOpposingController,
          decoration: const InputDecoration(
            labelText: 'Força oposta / antagonista',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contractQuestionController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Grande expectativa / pergunta central',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contractStakesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Risco e urgência',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _assistantConversationScroller({required List<Widget> children}) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onAssistantScrollNotification(notification);
            return false;
          },
          child: ListView(
            controller: _assistantScrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: children,
          ),
        ),
        if (!_assistantFollowBottom)
          Positioned(
            right: 12,
            bottom: 8,
            child: FloatingActionButton.small(
              tooltip: 'Ir para o fim',
              backgroundColor: const Color(0xFF2A2D34),
              foregroundColor: AppColors.textPrimary,
              onPressed: () {
                setState(() => _assistantFollowBottom = true);
                _scrollAssistantToEnd(force: true);
              },
              child: const Icon(Icons.arrow_downward, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildAssistantTurns({required Widget fallback}) {
    if (_assistantTurns.isEmpty) {
      return _assistantAiBubble(
        copyText: _assistantStreamText,
        child: _assistantConversationBody(fallback: fallback),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _assistantTurns.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          if (_assistantTurns[index].role == 'user')
            _assistantUserBubble(_assistantTurns[index].text)
          else
            _assistantAiBubble(
              copyText: _assistantTurns[index].text,
              child: _buildAssistantTurnBody(_assistantTurns[index]),
            ),
        ],
      ],
    );
  }

  Widget _buildAssistantTurnBody(_StudioChatTurn turn) {
    final text = turn.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.55,
              fontSize: 13,
            ),
          )
        else if (_pendingChatContract != null)
          _creationContractCard(),
        if (turn.busy) ...[
          if (text.isNotEmpty || _pendingChatContract != null)
            const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activeAiMessage ??
                      _automaticPreparationMessage ??
                      'escrevendo...',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          if (_activeAiProgress > 0 || _isAutomaticPreparationRunning) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _isAutomaticPreparationRunning
                  ? (_automaticPreparationTotal <= 0
                        ? null
                        : _automaticPreparationCompleted /
                              _automaticPreparationTotal)
                  : (_activeAiProgress <= 0 ? null : _activeAiProgress / 100),
            ),
          ],
        ],
        if (!turn.busy && turn.actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var index = 0; index < turn.actions.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _assistantChoiceButton(
              label: turn.actions[index].label,
              onTap: _isAnyGenerationBusy
                  ? null
                  : () => _handleStudioChatAction(turn.actions[index].id),
            ),
          ],
        ],
      ],
    );
  }

  Widget _assistantConversationBody({required Widget fallback}) {
    final stream = _assistantStreamText?.trim() ?? '';
    if (stream.isEmpty && _pendingChatContract != null) {
      return _creationContractCard();
    }
    if (stream.isEmpty) return fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stream,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.55,
            fontSize: 13,
          ),
        ),
        if (_isAiBusy) ...[
          const SizedBox(height: 10),
          const Text(
            'escrevendo...',
            style: TextStyle(
              color: AppColors.primaryLight,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _assistantUserBubble(String text) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D34),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(height: 1.4, fontSize: 13)),
    ),
  );

  Widget _assistantAiBubble({required Widget child, String? copyText}) {
    final trimmed = copyText?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: child,
          ),
          if (trimmed.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Copiar mensagem',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.copy, size: 16),
                color: AppColors.textSecondary,
                onPressed: () => _copyChatText(trimmed),
              ),
            ),
        ],
      ),
    );
  }

  Widget _assistantChoiceButton({
    required String label,
    required VoidCallback? onTap,
  }) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: const BorderSide(color: Color(0xFF3A3D45)),
        backgroundColor: const Color(0xFF1A1C21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(height: 1.35)),
    ),
  );

  Widget _buildAssistantComposer() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1E24),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.surfaceLighter),
    ),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Anexar referência',
              onPressed: () => setState(() => _studioTabIndex = 2),
              icon: const Icon(
                Icons.attach_file,
                color: AppColors.textTertiary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _assistantController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (_canStopGeneration) {
                    unawaited(_cancelActiveGeneration());
                    return;
                  }
                  _submitAssistantRequest();
                },
                decoration: InputDecoration(
                  hintText: _canStopGeneration
                      ? 'Gerando... toque em parar para interromper'
                      : _isChatBrief
                      ? 'Converse sobre ideias...'
                      : 'Peça um ajuste no roteiro...',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            PopupMenuButton<String>(
              initialValue: _assistantWriterMode,
              onSelected: (value) =>
                  setState(() => _assistantWriterMode = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'Melhor roteirista',
                  child: Text('Melhor roteirista'),
                ),
                PopupMenuItem(value: 'Rápido', child: Text('Rápido')),
                PopupMenuItem(value: 'Revisor', child: Text('Revisor')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _assistantWriterMode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton.filled(
              tooltip: _canStopGeneration ? 'Parar' : 'Enviar',
              onPressed: _canStopGeneration
                  ? () => unawaited(_cancelActiveGeneration())
                  : _submitAssistantRequest,
              icon: Icon(
                _canStopGeneration ? Icons.stop_rounded : Icons.arrow_upward,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _submitAssistantRequest() {
    final value = _assistantController.text.trim();
    if (value.isEmpty || _isAnyGenerationBusy) return;
    _assistantController.clear();
    if (_isChatBrief) {
      unawaited(_developSeriesFromChat(value));
      return;
    }
    unawaited(_reviseProjectWithCodex('[$_assistantWriterMode] $value'));
  }

  Future<void> _copyChatText(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    _showStudioMessage('Mensagem copiada');
  }

  void _showStudioMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.movie_creation_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadProject,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
