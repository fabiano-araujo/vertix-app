part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorContentExtension
    on _AdminProductionEditorPageState {
  Widget _buildEditor() {
    final project = _project!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth > 1440 ? 1440 : constraints.maxWidth,
            child: Column(
              children: [
                _buildProjectHeader(project, constraints.maxWidth),
                _buildSectionBar(),
                Expanded(child: _buildSelectedSection()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectHeader(ProductionProject project, double width) {
    final episode = _episode!;
    final progress = episode.takes.isEmpty
        ? 0.0
        : episode.takes.fold<double>(0, (sum, take) => sum + take.progress) /
              episode.takes.length;
    final compact = width < 720;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProjectTitle(project),
                const SizedBox(height: 14),
                _buildEpisodeSelector(project),
                const SizedBox(height: 14),
                _buildProgressAndAction(episode, progress, compact: true),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: _buildProjectTitle(project)),
                const SizedBox(width: 18),
                Expanded(flex: 3, child: _buildEpisodeSelector(project)),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: _buildProgressAndAction(episode, progress),
                ),
              ],
            ),
    );
  }

  Widget _buildProjectTitle(ProductionProject project) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _pill(
            project.isLocal ? 'LOCAL' : 'API',
            project.isLocal ? AppColors.success : AppColors.primary,
          ),
          _pill(project.status),
          _pill(project.formatFamily),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        project.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 5),
      Text(
        project.sourcePath,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ],
  );

  Widget _buildEpisodeSelector(ProductionProject project) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'EPISODIO ATIVO',
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 7),
      DropdownButtonFormField<int>(
        initialValue: _episodeIndex,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.playlist_play),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        items: List.generate(project.episodes.length, (index) {
          final episode = project.episodes[index];
          return DropdownMenuItem(
            value: index,
            child: Text('EP ${episode.number} • ${episode.title}'),
          );
        }),
        onChanged: (value) {
          if (value != null) setState(() => _episodeIndex = value);
        },
      ),
    ],
  );

  Widget _buildProgressAndAction(
    ProductionEpisodeItem episode,
    double progress, {
    bool compact = false,
  }) {
    final hasScript = episode.takes.isNotEmpty;
    final hasScriptDraft = _episodeScriptFor(
      _project!,
      episode.number,
    ).isNotEmpty;
    final generatingScript = _generatingScriptEpisodeNumber == episode.number;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${episode.takes.length} takes • ${_timecode(episode.durationSeconds)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress,
            backgroundColor: AppColors.surfaceLighter,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isGeneratingEpisode || generatingScript
              ? null
              : hasScript
              ? _simulateEpisode
              : hasScriptDraft
              ? () => setState(() {
                  _showTechnicalEditor = false;
                  _showEpisodeScriptEditor = true;
                })
              : () => _generateEpisodeScript(_episodeIndex),
          icon: _isGeneratingEpisode || generatingScript
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  hasScript
                      ? Icons.auto_awesome
                      : hasScriptDraft
                      ? Icons.fact_check_outlined
                      : Icons.description_outlined,
                ),
          label: Text(
            generatingScript
                ? 'Gerando roteiro por cenas...'
                : _isGeneratingEpisode
                ? 'Simulando episodio...'
                : hasScript
                ? 'Simular episodio'
                : hasScriptDraft
                ? 'Revisar roteiro por cenas'
                : 'Gerar roteiro por cenas',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBar() {
    const sections = [
      (Icons.dashboard_outlined, 'Resumo'),
      (Icons.account_tree_outlined, 'Roteiro'),
      (Icons.movie_filter_outlined, 'Takes'),
      (Icons.collections_outlined, 'Referencias'),
      (Icons.view_timeline_outlined, 'Timeline'),
      (Icons.graphic_eq, 'Audio'),
    ];
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _sectionIndex == index;
          return ChoiceChip(
            avatar: Icon(sections[index].$1, size: 18),
            label: Text(sections[index].$2),
            selected: selected,
            selectedColor: AppColors.primary.withAlpha(55),
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.surfaceLighter,
            ),
            onSelected: (_) => setState(() => _sectionIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildSelectedSection() => switch (_sectionIndex) {
    0 => _buildOverview(),
    1 => _buildScript(),
    2 => _buildTakes(),
    3 => _buildReferences(),
    4 => _buildTimeline(),
    _ => _buildAudio(),
  };

  Widget _buildOverview() {
    final project = _project!;
    final episode = _episode!;
    final bibleEntries = project.seriesBible.entries
        .where(
          (entry) =>
              entry.value is! Map &&
              entry.value is! Iterable &&
              entry.value != null,
        )
        .toList();
    final hasContract =
        _bibleText(project, 'logline', fallback: '').isNotEmpty &&
        _bibleText(project, 'central_question', fallback: '').isNotEmpty;
    final assetsReady = project.references.isNotEmpty;
    final outlineReady = project.episodes.every(
      (item) =>
          item.summary.trim().isNotEmpty && item.cliffhanger.trim().isNotEmpty,
    );
    final beatsReady = project.episodes.every((item) => item.takes.isNotEmpty);
    final productionReady = project.episodes
        .expand((item) => item.takes)
        .any((take) => take.status == 'COMPLETED');
    return ListView(
      key: const PageStorageKey('production-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final treatment = _panel(
              title: 'Tratamento do episodio',
              icon: Icons.description_outlined,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: episode.summary,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Historia linear antes de dividir em takes',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      _replaceEpisode(episode.copyWith(summary: value));
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: episode.cliffhanger,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Cliffhanger',
                      prefixIcon: Icon(Icons.bolt),
                    ),
                    onChanged: (value) {
                      _replaceEpisode(episode.copyWith(cliffhanger: value));
                    },
                  ),
                ],
              ),
            );
            final pipeline = _panel(
              title: 'Pipeline da obra',
              icon: Icons.account_tree_outlined,
              child: Column(
                children: [
                  _WorkflowStep(
                    icon: Icons.tune,
                    title: 'Ajustes e contrato',
                    subtitle: 'Formato, logline, pergunta central e risco',
                    done: hasContract,
                  ),
                  _WorkflowStep(
                    icon: Icons.account_tree_outlined,
                    title: 'Outline e ganchos',
                    subtitle: 'Pagamento, escalada, virada e corte no pico',
                    done: outlineReady,
                  ),
                  _WorkflowStep(
                    icon: Icons.people_outline,
                    title: 'Personagens e assets',
                    subtitle: 'Identidades, ambientes e objetos canonicos',
                    done: assetsReady,
                  ),
                  _WorkflowStep(
                    icon: Icons.description_outlined,
                    title: 'Roteiro por beats',
                    subtitle:
                        'Acoes filmaveis e dialogo aprovado antes dos takes',
                    done: beatsReady,
                  ),
                  _WorkflowStep(
                    icon: Icons.movie_filter_outlined,
                    title: 'Producao',
                    subtitle: 'Videos com audio integrado e musica separada',
                    done: productionReady,
                    last: true,
                  ),
                ],
              ),
            );
            if (!wide) {
              return Column(
                children: [treatment, const SizedBox(height: 12), pipeline],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: treatment),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: pipeline),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Biblia de producao',
          icon: Icons.hub_outlined,
          trailing: _pill('${bibleEntries.length} contratos'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: bibleEntries
                .map(
                  (entry) => Container(
                    width: 310,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.35,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildScript() {
    final project = _project!;
    final totalSeconds = project.episodes.fold<int>(
      0,
      (sum, episode) => sum + episode.durationSeconds,
    );
    return ListView(
      key: const PageStorageKey('production-script'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: 'Visao geral do projeto',
          icon: Icons.auto_stories_outlined,
          trailing: _pill(
            _bibleText(project, 'package_status', fallback: 'DRAFT'),
            AppColors.warning,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LOGLINE',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _bibleText(project, 'logline', fallback: project.description),
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              const Text(
                'GRANDE EXPECTATIVA',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _bibleText(
                  project,
                  'central_question',
                  fallback: 'Defina a pergunta central da temporada.',
                ),
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('${project.episodes.length} episodios'),
                  _pill(_longDuration(totalSeconds)),
                  _pill('${project.references.length} assets'),
                  _pill(project.genre),
                  _pill('9:16'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceLighter),
          ),
          child: Row(
            children: [
              Expanded(
                child: _scriptModeButton(
                  label: 'Lista de episodios',
                  icon: Icons.view_list_outlined,
                  selected: !_showHookChain,
                  onTap: () => setState(() => _showHookChain = false),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _scriptModeButton(
                  label: 'Corrente de gancho',
                  icon: Icons.account_tree_outlined,
                  selected: _showHookChain,
                  onTap: () => setState(() => _showHookChain = true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_showHookChain)
          ..._buildHookChain(project)
        else
          ...List.generate(
            project.episodes.length,
            (index) => _buildOutlineEpisodeCard(project.episodes[index], index),
          ),
      ],
    );
  }

  Widget _scriptModeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => Material(
    color: selected ? AppColors.primary.withAlpha(42) : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? AppColors.primaryLight
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildOutlineEpisodeCard(
    ProductionEpisodeItem episode,
    int episodeIndex,
  ) {
    final selected = episodeIndex == _episodeIndex;
    final sceneCards = _sceneCardsForEpisode(_project!, episode.number);
    final episodeScript = _episodeScriptFor(_project!, episode.number);
    final outlineCard = _episodeCardFor(_project!, episode.number);
    final stageGoal = outlineCard['stage_goal']?.toString().trim() ?? '';
    final emotionalBeat =
        outlineCard['emotional_beat']?.toString().trim() ?? '';
    final valueShift = outlineCard['value_shift']?.toString().trim() ?? '';
    final hasDetailedScript = episodeScript.isNotEmpty && sceneCards.isNotEmpty;
    final productionReady = episode.takes.isNotEmpty;
    final shotCount = episodeScript['shot_count'] as int? ?? 0;
    final generatingScript = _generatingScriptEpisodeNumber == episode.number;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.surfaceLighter,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _episodeIndex = episodeIndex),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'EP${episode.number}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      episode.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (stageGoal.isNotEmpty || emotionalBeat.isNotEmpty) ...[
                Text(
                  [
                    if (stageGoal.isNotEmpty) '[Objetivo da etapa: $stageGoal]',
                    if (emotionalBeat.isNotEmpty)
                      '[Batida emocional: $emotionalBeat]',
                  ].join(' '),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                episode.summary,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              if (valueShift.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  'Mudança de valor: $valueShift.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt, color: AppColors.warning, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        episode.cliffhanger,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(_timecode(episode.durationSeconds)),
                  if (hasDetailedScript) ...[
                    _pill('${sceneCards.length} cenas'),
                    _pill('$shotCount shots'),
                    _pill(
                      productionReady
                          ? 'Produção liberada'
                          : 'Roteiro em revisão',
                      productionReady ? AppColors.success : AppColors.warning,
                    ),
                  ] else
                    _pill('Roteiro não iniciado', AppColors.textTertiary),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: productionReady
                    ? FilledButton.icon(
                        onPressed: () => setState(() {
                          _episodeIndex = episodeIndex;
                          _episodeProductionMode = true;
                          _sectionIndex = 2;
                        }),
                        icon: const Icon(Icons.movie_filter_outlined, size: 17),
                        label: const Text('Entrar na produção de vídeo'),
                      )
                    : hasDetailedScript
                    ? OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _episodeIndex = episodeIndex;
                          _showEpisodeScriptEditor = true;
                        }),
                        icon: const Icon(Icons.fact_check_outlined, size: 17),
                        label: const Text('Ver / aprovar roteiro por cenas'),
                      )
                    : FilledButton.icon(
                        onPressed: generatingScript
                            ? null
                            : () => _generateEpisodeScript(episodeIndex),
                        icon: generatingScript
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.description_outlined, size: 17),
                        label: Text(
                          generatingScript
                              ? 'Gerando roteiro detalhado...'
                              : 'Gerar roteiro detalhado por cenas',
                        ),
                      ),
              ),
              if (selected && sceneCards.isNotEmpty) ...[
                const Divider(height: 22),
                const Text(
                  'ROTEIRO POR CENAS',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                ...sceneCards.map(
                  (scene) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cena ${scene['scene']} · ${scene['title']}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${scene['location']} · ${(scene['cast'] as List<dynamic>? ?? const []).join(', ')}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          scene['story']?.toString() ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHookChain(ProductionProject project) {
    final entries = _hookEntries(project);
    return List.generate(project.episodes.length, (index) {
      final episode = project.episodes[index];
      final entry = entries.firstWhere(
        (item) => item['episode'] == episode.number,
        orElse: () => const <String, dynamic>{},
      );
      final opening =
          entry['opening_pickup']?.toString() ??
          (index == 0
              ? 'Abrir na consequencia visivel da premissa.'
              : 'Pagar imediatamente o gancho anterior.');
      final unresolved =
          (entry['unresolved_questions'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLighter),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hookBlock(
              icon: Icons.bolt,
              color: AppColors.warning,
              eyebrow: index == project.episodes.length - 1
                  ? 'GANCHO FINAL • FIM DA TEMPORADA'
                  : 'GANCHO FINAL • LANCA PARA EP${episode.number + 1}',
              title: 'EP${episode.number} • ${episode.title}',
              body: episode.cliffhanger,
            ),
            Container(
              height: 24,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_downward,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
            _hookBlock(
              icon: Icons.play_circle_outline,
              color: AppColors.success,
              eyebrow: 'COLETA DE ABERTURA',
              title: index == 0
                  ? 'EP1 • Descoberta fria'
                  : 'EP${episode.number} • Do gancho anterior',
              body: opening,
            ),
            if (unresolved.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NAO RESOLVIDO',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      ...unresolved.map(
                        (question) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            '• $question',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _hookBlock({
    required IconData icon,
    required Color color,
    required String eyebrow,
    required String title,
    required String body,
  }) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  List<Map<String, dynamic>> _hookEntries(ProductionProject project) =>
      (project.seriesBible['hook_chain'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Map<String, dynamic> _episodeCardFor(
    ProductionProject project,
    int episodeNumber,
  ) => (project.seriesBible['episode_cards'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .firstWhere(
        (item) => item['episode'] == episodeNumber,
        orElse: () => const <String, dynamic>{},
      );

  Map<String, dynamic> _episodeScriptFor(
    ProductionProject project,
    int episodeNumber,
  ) => (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .firstWhere(
        (item) => item['episode'] == episodeNumber,
        orElse: () => const <String, dynamic>{},
      );

  List<Map<String, dynamic>> _sceneCardsForEpisode(
    ProductionProject project,
    int episodeNumber,
  ) => (project.seriesBible['scene_cards'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => item['episode'] == episodeNumber)
      .toList();

  String _bibleText(
    ProductionProject project,
    String key, {
    required String fallback,
  }) {
    final value = project.seriesBible[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String _longDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
