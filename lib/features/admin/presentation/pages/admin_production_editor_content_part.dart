part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorContentExtension
    on _AdminProductionEditorPageState {
  Widget _buildEditor() {
    final project = _project!;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_sectionIndex == 2) {
          return Column(
            children: [
              _buildSectionBar(),
              Expanded(child: _buildTakes()),
            ],
          );
        }
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
          if (value != null) {
            setState(() {
              _episodeIndex = value;
              _selectedTakeIndex = 0;
            });
          }
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
    final hasScriptDraft = _hasEpisodeScriptDraft(_project!, episode.number);
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
                  _episodeProductionMode = false;
                  _showTechnicalEditor = false;
                  _showEpisodeScriptEditor = true;
                  _studioTabIndex = 1;
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
    final episode = _episode;
    if (episode == null) return _buildChatBriefEmptyState();
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
        _panel(
          title: 'Geração de vídeo',
          icon: Icons.movie_filter_outlined,
          child: _videoGenerationPresetPicker(
            selectedId:
                project.seriesBible['video_generation_profile']?.toString() ??
                '',
          ),
        ),
        const SizedBox(height: 12),
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
                    title: 'Mapa, outline e ganchos',
                    subtitle:
                        'Blocos da temporada, paywall, revelações reservadas e corte no pico',
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
    final characterCount = project.references
        .where((item) => item.category.contains('CHARACTER'))
        .length;
    final locationCount = project.references
        .where(
          (item) =>
              item.category.contains('LOCATION') ||
              item.category.contains('ENVIRONMENT'),
        )
        .length;
    return ColoredBox(
      color: const Color(0xFF121418),
      child: ListView(
        key: const PageStorageKey('production-script'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildOutlineToolbar(),
          const SizedBox(height: 16),
          if (_project != null && _canContinueOutline(_project!)) ...[
            _buildContinueOutlineBanner(_project!),
            const SizedBox(height: 16),
          ],
          if (project.episodes.isEmpty)
            _buildChatBriefEmptyState()
          else if (_showHookChain)
            ..._buildHookChain(project)
          else ...[
            _buildProjectOverviewCard(
              project,
              totalSeconds: totalSeconds,
              characterCount: characterCount,
              locationCount: locationCount,
            ),
            const SizedBox(height: 16),
            if (_seasonArchitecture(project).isNotEmpty) ...[
              _buildSeasonArchitectureCard(project),
              const SizedBox(height: 16),
            ],
            ...List.generate(
              project.episodes.length,
              (index) =>
                  _buildOutlineEpisodeCard(project.episodes[index], index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatBriefEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 52,
            color: AppColors.textTertiary.withAlpha(160),
          ),
          const SizedBox(height: 18),
          const Text(
            'Ainda não há descrição do episódio',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Descreva a ideia da sua história no bate-papo à esquerda e a IA gerará o contrato e o esboço a partir do tema escolhido.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _addBlankEpisode,
            icon: const Icon(Icons.add),
            label: const Text('Criar episódio manualmente'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final buttons = [
          _outlineToolButton(
            icon: Icons.add,
            label: compact ? 'Episódio' : 'Adicionar episódio',
            onTap: _addBlankEpisode,
          ),
          _outlineToolButton(
            icon: Icons.auto_awesome,
            label: compact
                ? 'Esboço'
                : _project != null && _canContinueOutline(_project!)
                ? () {
                    final batch = _nextOutlineBatch(_project!)!;
                    return 'Continuar esboço (EP${batch['fromEpisode']}-${batch['throughEpisode']})';
                  }()
                : 'Gerar esboço com IA',
            onTap: _isAnyGenerationBusy || _isChatBrief
                ? null
                : () {
                    final next = _project == null
                        ? null
                        : _nextOutlineEpisode(_project!);
                    _generateSeriesOutlineWithCodex(
                      fromEpisode: next != null && next > 1 ? next : 1,
                    );
                  },
          ),
          if (_project != null && _canContinueOutline(_project!))
            _outlineToolButton(
              icon: Icons.playlist_add,
              label: compact
                  ? 'Mais 5'
                  : () {
                      final batch = _nextOutlineBatch(_project!)!;
                      return 'Continuar esboço (EP${batch['fromEpisode']}-${batch['throughEpisode']})';
                    }(),
              onTap: _isAnyGenerationBusy
                  ? null
                  : () => _generateSeriesOutlineWithCodex(
                      fromEpisode: _nextOutlineEpisode(_project!),
                    ),
            ),
          _outlineToolButton(
            icon: Icons.ios_share_outlined,
            label: compact ? 'Exportar' : 'Exportar script e ativos',
            onTap: _saveProject,
          ),
          _outlineToolButton(
            icon: Icons.view_list_outlined,
            label: compact ? 'Cenas' : 'Lista de cenas',
            selected: !_showHookChain,
            onTap: () => setState(() => _showHookChain = false),
          ),
          _outlineToolButton(
            icon: Icons.account_tree_outlined,
            label: compact ? 'Ganchos' : 'Corrente de gancho',
            selected: _showHookChain,
            onTap: () => setState(() => _showHookChain = true),
          ),
        ];
        if (compact) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < buttons.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  buttons[index],
                ],
              ],
            ),
          );
        }
        return Wrap(spacing: 8, runSpacing: 8, children: buttons);
      },
    );
  }

  Widget _buildContinueOutlineBanner(ProductionProject project) {
    final batch = _nextOutlineBatch(project);
    if (batch == null) return const SizedBox.shrink();
    final ready = _readyOutlineCount(project);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2438),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9B8CFF).withAlpha(160)),
      ),
      child: Row(
        children: [
          const Icon(Icons.playlist_add, color: Color(0xFF9B8CFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'O texto-base parou: $ready de ${project.targetEpisodeCount} episódios. '
              'Continuar EP${batch['fromEpisode']}-${batch['throughEpisode']}.',
              style: const TextStyle(height: 1.35, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isAnyGenerationBusy
                ? null
                : () => _generateSeriesOutlineWithCodex(
                    fromEpisode: batch['fromEpisode'] as int,
                  ),
            child: Text('Continuar EP${batch['fromEpisode']}-${batch['throughEpisode']}'),
          ),
        ],
      ),
    );
  }

  Widget _outlineToolButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : AppColors.textSecondary,
        backgroundColor: selected ? Colors.white12 : Colors.transparent,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: selected ? Colors.white38 : AppColors.surfaceLighter,
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _buildProjectOverviewCard(
    ProductionProject project, {
    required int totalSeconds,
    required int characterCount,
    required int locationCount,
  }) {
    const purple = Color(0xFF8B7CFF);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple.withAlpha(160), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_outlined, color: purple, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Visão geral do projeto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'LINHA DE REGISTRO',
            style: TextStyle(
              color: purple,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _bibleText(project, 'logline', fallback: project.description),
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'GRANDE EXPECTATIVA',
            style: TextStyle(
              color: purple,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                _countNoun(project.episodes.length, 'episódio', 'episódios'),
                purple,
              ),
              _pill(_longDuration(totalSeconds)),
              _pill(_countNoun(characterCount, 'personagem', 'personagens')),
              _pill(_countNoun(locationCount, 'ambiente', 'ambientes')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonArchitectureCard(ProductionProject project) {
    const gold = Color(0xFFE6D3A8);
    final architecture = _seasonArchitecture(project);
    final blocks = (architecture['blocks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final reveals =
        (project.seriesBible['reserved_reveals'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final paywall = architecture['paywall_episode'];
    final freeCount = architecture['free_episode_count'];
    final payoffWindow = architecture['central_question_payoff_window']
        ?.toString()
        .trim();
    final outlinedCount = project.episodes.where(_episodeHasReadyOutline).length;
    final irony = _bibleText(
      project,
      'viewer_dramatic_irony',
      fallback: '',
    ).trim();
    final canContinue = _canContinueOutline(project);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withAlpha(140), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: gold, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mapa da temporada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'O mapa da temporada (paywall e revelações) é travado inteiro. Os cartões saem em lotes; o EP1 não gasta o que o bloco final precisa.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (freeCount != null)
                _pill('$freeCount episódios no funil grátis', gold),
              if (paywall != null) _pill('Paywall no EP$paywall', gold),
              if (payoffWindow != null && payoffWindow.isNotEmpty)
                _pill('Pergunta central: EP$payoffWindow', gold),
              if (reveals.isNotEmpty)
                _pill('${reveals.length} revelações reservadas', gold),
              if (outlinedCount > 0 &&
                  outlinedCount < project.targetEpisodeCount)
                _pill(
                  '$outlinedCount de ${project.targetEpisodeCount} cartões no esboço',
                  gold,
                ),
            ],
          ),
          if (irony.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Ironia dramática: $irony',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (reveals.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'REVELAÇÕES RESERVADAS',
              style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            ...reveals.take(6).map((reveal) {
              final fact = reveal['fact']?.toString().trim() ?? '';
              final earliest = reveal['earliest_episode'];
              if (fact.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'A partir do EP$earliest: $fact',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              );
            }),
          ],
          if (blocks.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...blocks.map((block) {
              final range = block['episodes']?.toString() ?? '';
              final role = block['role']?.toString() ?? '';
              final turn = block['irreversible_turn']?.toString().trim() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EP$range · ${block['conversion_role'] ?? role}',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      turn.isNotEmpty ? turn : role.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (canContinue) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isAnyGenerationBusy
                    ? null
                    : () => _generateSeriesOutlineWithCodex(
                        fromEpisode: _nextOutlineEpisode(project),
                      ),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: Text(() {
                  final batch = _nextOutlineBatch(project)!;
                  return 'Continuar texto-base EP${batch['fromEpisode']}-${batch['throughEpisode']}';
                }()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addBlankEpisode() {
    final project = _project;
    if (project == null) return;
    final next = project.episodes.length + 1;
    final episode = ProductionEpisodeItem(
      number: next,
      title: 'Episódio $next',
      summary: '',
      cliffhanger: '',
      durationSeconds: 60,
      takes: const [],
    );
    setState(() {
      _project = project.copyWith(
        episodes: [...project.episodes, episode],
        targetEpisodeCount: next,
      );
      _episodeIndex = project.episodes.length;
      _showHookChain = false;
    });
    _schedulePersist();
  }

  ({String label, VoidCallback? onPressed}) _episodePrimaryAction({
    required ProductionEpisodeItem episode,
    required int episodeIndex,
    required bool generatingScript,
    required bool hasDetailedScript,
    required bool productionReady,
  }) {
    if (!_episodeHasReadyOutline(episode)) {
      final batch = _project == null ? null : _nextOutlineBatch(_project!);
      return (
        label: batch == null
            ? 'Gerar texto-base'
            : 'Continuar texto-base EP${batch['fromEpisode']}-${batch['throughEpisode']}',
        onPressed: _isAnyGenerationBusy
            ? null
            : () {
                setState(() => _episodeIndex = episodeIndex);
                _generateSeriesOutlineWithCodex(
                  fromEpisode: _nextOutlineEpisode(_project!),
                );
              },
      );
    }
    return (
      label: generatingScript
          ? 'Gerando roteiro...'
          : hasDetailedScript || productionReady
          ? 'Ver/Editar script'
          : 'Gerar script',
      onPressed: generatingScript
          ? null
          : () {
              setState(() => _episodeIndex = episodeIndex);
              if (productionReady || hasDetailedScript) {
                setState(() {
                  _studioTabIndex = 1;
                  _showEpisodeScriptEditor = true;
                });
              } else {
                _generateEpisodeScript(episodeIndex);
              }
            },
    );
  }

  Widget _buildOutlineEpisodeCard(
    ProductionEpisodeItem episode,
    int episodeIndex,
  ) {
    final selected = episodeIndex == _episodeIndex;
    final sceneCards = _sceneCardsForEpisode(_project!, episode.number);
    final outlineCard = _episodeCardFor(_project!, episode.number);
    final stageGoal = outlineCard['stage_goal']?.toString().trim() ?? '';
    final emotionalBeat =
        outlineCard['emotional_beat']?.toString().trim() ?? '';
    final valueShift = outlineCard['value_shift']?.toString().trim() ?? '';
    final paywallRole = outlineCard['paywall_role']?.toString().trim() ?? '';
    final pressureType = outlineCard['pressure_type']?.toString().trim() ?? '';
    final hasDetailedScript = _hasEpisodeScriptDraft(_project!, episode.number);
    final productionReady = episode.takes.isNotEmpty;
    final generatingScript = _generatingScriptEpisodeNumber == episode.number;
    final hasReadyOutline = _episodeHasReadyOutline(episode);
    final waitingOutline =
        episode.status == 'GENERATING' &&
        _activeAiAction == 'GENERATE_SERIES_OUTLINE';
    final displayTitle = _episodeDisplayTitle(episode, outlineCard);
    final displaySummary = _episodeDisplaySummary(episode, outlineCard);
    final displayCliffhanger = _episodeDisplayCliffhanger(episode, outlineCard);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final primary = _episodePrimaryAction(
      episode: episode,
      episodeIndex: episodeIndex,
      generatingScript: generatingScript,
      hasDetailedScript: hasDetailedScript,
      productionReady: productionReady,
    );
    return Card(
      color: const Color(0xFF1A1C22),
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: hasDetailedScript
              ? const Color(0xFF7DCE82)
              : selected
              ? AppColors.primary
              : AppColors.surfaceLighter,
          width: hasDetailedScript || selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _episodeIndex = episodeIndex),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 15),
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
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (waitingOutline)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (selected)
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
              if (displaySummary.isNotEmpty || waitingOutline || !hasReadyOutline) ...[
                Text(
                  displaySummary.isNotEmpty
                      ? displaySummary
                      : waitingOutline
                      ? 'A IA está escrevendo este episódio...'
                      : 'Ainda não há o texto-base deste episódio.',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
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
                        displayCliffhanger.isNotEmpty
                            ? displayCliffhanger
                            : 'Defina o cliffhanger do episódio.',
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
                  if (paywallRole.isNotEmpty)
                    _pill(_paywallRoleLabel(paywallRole), const Color(0xFFE6D3A8)),
                  if (pressureType.isNotEmpty) _pill(pressureType),
                  if (hasDetailedScript) ...[
                    _pill(
                      'Script concluído (${sceneCards.length} cenas)',
                      const Color(0xFF7DCE82),
                    ),
                    _pill(
                      'Vídeo ${episode.takes.where((take) => take.status == 'COMPLETED').length}/${episode.takes.isEmpty ? sceneCards.length : episode.takes.length}',
                    ),
                  ] else
                    _pill('Roteiro não iniciado', AppColors.textTertiary),
                ],
              ),
              const SizedBox(height: 12),
              if (compact)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: primary.onPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(primary.label),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            _openEpisodeProduction(episodeIndex: episodeIndex),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.movie_filter_outlined, size: 18),
                        label: const Text('Produção de vídeo'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: primary.onPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(primary.label),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _openEpisodeProduction(episodeIndex: episodeIndex),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.movie_filter_outlined, size: 18),
                        label: const Text('Produção de vídeo'),
                      ),
                    ),
                  ],
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
                ...sceneCards.asMap().entries.map((entry) {
                  final scene = entry.value;
                  final title = _sceneTitle(scene);
                  final meta = _sceneMetaLine(scene);
                  final story = _sceneStory(scene);
                  return Container(
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
                          title.isEmpty
                              ? 'Cena ${_sceneNumber(scene, fallback: entry.key + 1)}'
                              : 'Cena ${_sceneNumber(scene, fallback: entry.key + 1)} · $title',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                        if (story.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            story,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHookChain(ProductionProject project) {
    final episodes = project.episodes;
    if (episodes.isEmpty) {
      return const [
        Text(
          'Gere o esboço da temporada para ver a corrente de gancho.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Corrente de gancho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Veja as conexões entre episódios por gancho final → coleta de abertura → suspense não resolvido.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      ...List.generate(episodes.length, (index) {
        final episode = episodes[index];
        final next = index + 1 < episodes.length ? episodes[index + 1] : null;
        final endingEntry = _hookEntryFor(project, episode.number);
        final nextEntry = next == null
            ? const <String, dynamic>{}
            : _hookEntryFor(project, next.number);
        final endingHook =
            endingEntry['final_hook']?.toString().trim().isNotEmpty == true
            ? endingEntry['final_hook'].toString()
            : episode.cliffhanger;
        final openingPickup = nextEntry['opening_pickup']?.toString().trim();
        final unresolved =
            (endingEntry['unresolved_questions'] as List<dynamic>? ??
                    const <dynamic>[])
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
                eyebrow: next == null
                    ? 'GANCHO FINAL • FIM DA TEMPORADA'
                    : 'GANCHO FINAL • LANÇA PARA EP${next.number}',
                title: 'EP${episode.number} · ${episode.title}',
                subtitle: next == null
                    ? 'Corte da temporada'
                    : 'Lança para o EP${next.number}',
                body: endingHook,
                questions: unresolved,
              ),
              if (next != null) ...[
                const SizedBox(
                  height: 24,
                  child: Icon(
                    Icons.arrow_downward,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
                _hookBlock(
                  icon: Icons.play_circle_outline,
                  color: AppColors.success,
                  eyebrow: 'COLETA DE ABERTURA',
                  title: 'EP${next.number} · ${next.title}',
                  subtitle: 'Do gancho final do EP${episode.number}',
                  body: (openingPickup == null || openingPickup.isEmpty)
                      ? 'Pagar imediatamente o gancho anterior sem reiniciar a história.'
                      : openingPickup,
                ),
              ],
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
                          'NÃO RESOLVIDO',
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
                              question,
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
      }),
    ];
  }

  Widget _hookBlock({
    required IconData icon,
    required Color color,
    required String eyebrow,
    required String title,
    required String body,
    String? subtitle,
    List<String> questions = const [],
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
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withAlpha(210),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (questions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...questions.map(
                  (question) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      question,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Map<String, dynamic> _hookEntryFor(
    ProductionProject project,
    int episodeNumber,
  ) => _hookEntries(project).firstWhere(
    (item) => (item['episode'] as num?)?.toInt() == episodeNumber,
    orElse: () => const <String, dynamic>{},
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
        (item) => _studioEpisodeNumber(item['episode']) == episodeNumber,
        orElse: () => const <String, dynamic>{},
      );

  Map<String, dynamic> _episodeScriptFor(
    ProductionProject project,
    int episodeNumber,
  ) => (project.seriesBible['episode_scripts'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .firstWhere(
        (item) => _studioEpisodeNumber(item['episode']) == episodeNumber,
        orElse: () => const <String, dynamic>{},
      );

  bool _hasEpisodeScriptDraft(ProductionProject project, int episodeNumber) {
    final scenes = _episodeScriptFor(project, episodeNumber)['scenes'];
    return scenes is List && scenes.isNotEmpty;
  }

  List<Map<String, dynamic>> _sceneCardsForEpisode(
    ProductionProject project,
    int episodeNumber,
  ) {
    var cards =
        (project.seriesBible['scene_cards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (item) => _studioEpisodeNumber(item['episode']) == episodeNumber,
            )
            .toList();
    if (cards.isEmpty) {
      cards =
          (_episodeScriptFor(project, episodeNumber)['scenes']
                      as List<dynamic>? ??
                  const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
    }
    return cards;
  }

  String _bibleText(
    ProductionProject project,
    String key, {
    required String fallback,
  }) {
    dynamic raw = project.seriesBible[key];
    if (raw == null) {
      final nested = project.seriesBible['seriesBible'];
      if (nested is Map) raw = nested[key];
    }
    final value = _visibleText(raw);
    return value.isEmpty ? fallback : value;
  }

  Map<String, dynamic> _seasonArchitecture(ProductionProject project) {
    final raw = project.seriesBible['season_architecture'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _paywallRoleLabel(String role) => switch (role) {
    'funnel' || 'free_funnel' => 'Funil grátis',
    'paywall_question' || 'paywall_cliffhanger' => 'Corte do paywall',
    'post_paywall_payoff' => 'Pagamento pós-paywall',
    'midgame' || 'binge_midgame' => 'Meio da temporada',
    'sunk_cost' => 'Ponto mais baixo',
    'finale' || 'season_payoff' => 'Bloco final',
    'acquisition_clip' => 'Gancho de aquisição',
    _ => role.replaceAll('_', ' '),
  };

  String _longDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _countNoun(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  String _visibleText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'undefined') return '';
    if (_looksLikeJsonText(text)) return '';
    return text;
  }

  bool _looksLikeJsonText(String value) {
    final text = value.trim();
    return (text.startsWith('{') && text.contains('}')) ||
        (text.startsWith('[') && text.contains(']'));
  }

  String _episodeDisplayTitle(
    ProductionEpisodeItem episode,
    Map<String, dynamic> outlineCard,
  ) {
    final cardTitle = _visibleText(outlineCard['title']);
    final title = _visibleText(episode.title);
    final generic = RegExp(r'^epis[oó]dio\s*\d+$', caseSensitive: false);
    final generating = RegExp(r'^gerando epis[oó]dio', caseSensitive: false);
    if (title.isEmpty ||
        generic.hasMatch(title) ||
        generating.hasMatch(title)) {
      return cardTitle.isNotEmpty ? cardTitle : 'Episódio ${episode.number}';
    }
    return title;
  }

  String _episodeDisplaySummary(
    ProductionEpisodeItem episode,
    Map<String, dynamic> outlineCard,
  ) {
    final summary = _visibleText(episode.summary);
    if (summary.isNotEmpty) return summary;
    for (final key in const ['treatment', 'cold_open', 'summary', 'story']) {
      final value = _visibleText(outlineCard[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _episodeDisplayCliffhanger(
    ProductionEpisodeItem episode,
    Map<String, dynamic> outlineCard,
  ) {
    final cliffhanger = _visibleText(episode.cliffhanger);
    final placeholder = RegExp(r'^defina o cliffhanger', caseSensitive: false);
    if (cliffhanger.isNotEmpty && !placeholder.hasMatch(cliffhanger)) {
      return cliffhanger;
    }
    for (final key in const ['peak_action', 'cliffhanger', 'exact_cut_point']) {
      final value = _visibleText(outlineCard[key]);
      if (value.isNotEmpty) return value;
    }
    return cliffhanger;
  }

  int _sceneNumber(Map<String, dynamic> scene, {required int fallback}) =>
      _studioEpisodeNumber(scene['scene']) ??
      _studioEpisodeNumber(scene['scene_number']) ??
      _studioEpisodeNumber(scene['sceneNumber']) ??
      _studioEpisodeNumber(scene['number']) ??
      fallback;

  String _sceneTitle(Map<String, dynamic> scene) =>
      _visibleText(scene['title'] ?? scene['name'] ?? scene['heading']);

  String _sceneLocation(Map<String, dynamic> scene) => _visibleText(
    scene['location'] ??
        scene['location_name'] ??
        scene['locationName'] ??
        scene['setting'] ??
        scene['place'] ??
        scene['time_and_location'] ??
        scene['environment'],
  );

  String _sceneStory(Map<String, dynamic> scene) => _visibleText(
    scene['story'] ??
        scene['description'] ??
        scene['synopsis'] ??
        scene['beats'] ??
        scene['action'] ??
        scene['summary'],
  );

  String _sceneMetaLine(Map<String, dynamic> scene) {
    final castRaw = scene['cast'] ?? scene['characters'] ?? scene['speakers'];
    final cast = castRaw is List
        ? castRaw.map(_visibleText).where((item) => item.isNotEmpty).join(', ')
        : _visibleText(castRaw);
    return [
      _sceneLocation(scene),
      cast,
    ].where((item) => item.isNotEmpty).join(' · ');
  }
}
