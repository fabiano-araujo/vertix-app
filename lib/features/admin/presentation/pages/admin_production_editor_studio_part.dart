part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorStudioExtension
    on _AdminProductionEditorPageState {
  Widget _buildEpisodeProductionScaffold() {
    final episode = _episode!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Voltar ao roteiro',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _episodeProductionMode = false;
            _showEpisodeScriptEditor = true;
          }),
        ),
        title: Text(
          'EP${episode.number} · ${episode.title} · Produção de vídeo',
        ),
        actions: [
          IconButton(
            tooltip: 'Salvar localmente',
            onPressed: _isSaving ? null : _saveProject,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _buildEditor(),
    );
  }

  Widget _buildEpisodeScriptScaffold() {
    final project = _project!;
    final episode = _episode!;
    final script = _episodeScriptFor(project, episode.number);
    final scenes = (script['scenes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final scriptLocked = script['status'] == 'LOCKED_FOR_PRODUCTION';
    final productionReady = episode.takes.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Voltar aos episódios',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showEpisodeScriptEditor = false),
        ),
        title: Text(
          'EP${episode.number} · ${episode.title} · Roteiro por cenas',
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProject,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar rascunho'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: productionReady
                  ? () => setState(() {
                      _showEpisodeScriptEditor = false;
                      _episodeProductionMode = true;
                      _sectionIndex = 2;
                    })
                  : _isApprovingScript || scenes.isEmpty
                  ? null
                  : _approveEpisodeScriptForProduction,
              icon: _isApprovingScript
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      productionReady
                          ? Icons.movie_filter_outlined
                          : Icons.lock_outline,
                    ),
              label: Text(
                productionReady
                    ? 'Entrar na produção de vídeo'
                    : _isApprovingScript
                    ? 'Preparando produção...'
                    : 'Aprovar e liberar produção',
              ),
            ),
          ),
        ],
      ),
      body: scenes.isEmpty
          ? Center(
              child: FilledButton.icon(
                onPressed: () => _generateEpisodeScript(_episodeIndex),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Gerar roteiro detalhado'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 110),
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
                      _pill(
                        'até ${script['max_shot_duration_seconds'] ?? 10}s por shot',
                      ),
                      _pill(_timecode(episode.durationSeconds)),
                      _pill(
                        scriptLocked ? 'ROTEIRO BLOQUEADO' : 'EM REVISÃO',
                        scriptLocked ? AppColors.success : AppColors.warning,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Revise cenas, falas, ações e durações. Ao aprovar, o texto e a ordem causal ficam bloqueados e cada Shot passa para a produção como um prompt independente.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...scenes.map(_buildScriptSceneCard),
              ],
            ),
    );
  }

  Widget _buildScriptSceneCard(Map<String, dynamic> scene) {
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
                    'Cena ${scene['scene']} · ${scene['title']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _pill('${shots.length} shots'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '[Episode ${scene['episode']} - Scene ${scene['scene']} | ${scene['location']} | ${scene['time_of_day']} ${scene['interior_exterior']} | ${scene['dramatic_beat']}]',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'Cast: ${(scene['cast'] as List<dynamic>? ?? const []).join(', ')}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Story:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  scene['story']?.toString() ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const Divider(height: 32),
                ...shots.map(_buildScriptShot),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptShot(Map<String, dynamic> shot) {
    final rows = (shot['rows'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shot ${shot['number']}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final duration = row['duration_seconds'];
            final text = row['type'] == 'dialogue'
                ? '${row['speaker']}: (${row['performance']}) ${row['text']} (${duration}s)'
                : '(action) ${row['text']} (${duration}s)';
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SelectableText(
                text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            );
          }),
          Text(
            'Duration: ${shot['duration_seconds']}s',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioMainPane() {
    return switch (_studioTabIndex) {
      2 => _buildReferences(
        categories: const {
          'CHARACTER_MASTER',
          'CHARACTER_REFERENCE',
          'OPPOSING_FORCE_MASTER',
        },
        title: 'Personagens',
        description:
            'Fichas canônicas de aparência, personalidade, função dramática, arco e variações visuais.',
        emptyLabel: 'Nenhum personagem foi definido para esta obra.',
        addLabel: 'Adicionar personagem',
        initialCategory: 'CHARACTER_REFERENCE',
      ),
      3 => _buildReferences(
        categories: const {
          'LOCATION_MASTER',
          'LOCATION_REFERENCE',
          'ENVIRONMENT_MASTER',
          'WORLD_ENVIRONMENT_MASTER',
        },
        title: 'Ambientes',
        description:
            'Geografia, luz, elementos permanentes e regras de continuidade dos espaços da história.',
        emptyLabel: 'Nenhum ambiente foi definido para esta obra.',
        addLabel: 'Adicionar ambiente',
        initialCategory: 'LOCATION_MASTER',
      ),
      4 => _buildReferences(
        categories: const {
          'PROP_MASTER',
          'PROP_REFERENCE',
          'OBJECT_MASTER',
          'OBJECT_REFERENCE',
        },
        title: 'Adereços',
        description:
            'Objetos narrativos com função, estado, posse e pagamento planejados ao longo dos episódios.',
        emptyLabel: 'Nenhum adereço foi definido para esta obra.',
        addLabel: 'Adicionar adereço',
        initialCategory: 'OBJECT_REFERENCE',
      ),
      _ => _buildEditor(),
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
        title: Text('${_project?.title ?? 'Studio'} • editor tecnico'),
        actions: [
          IconButton(
            tooltip: 'Salvar localmente',
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showAssistant = constraints.maxWidth >= 980;
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
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF17191D),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          return Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 210 : 150),
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 22),
                TextButton(
                  onPressed: () => _showStudioMessage(
                    'Envie seu feedback pelo canal da equipe.',
                  ),
                  child: const Text('Feedback'),
                ),
              ],
              const Spacer(),
              if (wide)
                ...List.generate(tabs.length, (index) {
                  final selected = _studioTabIndex == index;
                  return _studioTopTab(
                    icon: tabs[index].$1,
                    label: tabs[index].$2,
                    selected: selected,
                    onTap: () => setState(() => _studioTabIndex = index),
                  );
                })
              else
                PopupMenuButton<int>(
                  tooltip: 'Seções do projeto',
                  initialValue: _studioTabIndex,
                  onSelected: (value) =>
                      setState(() => _studioTabIndex = value),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(tabs[_studioTabIndex].$1, size: 18),
                        const SizedBox(width: 8),
                        Text(tabs[_studioTabIndex].$2),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showTechnicalEditor = true),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: Text(wide ? 'Quadro do projeto' : 'Quadro'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Salvar',
                onPressed: _isSaving ? null : _saveProject,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
              ),
            ],
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
    final episode = _episode!;
    final firstTake = episode.takes.isEmpty ? null : episode.takes.first;
    final episodeScript = _episodeScriptFor(_project!, episode.number);
    final hasDetailedScript = episodeScript.isNotEmpty;
    final shotCount = episodeScript['shot_count'] as int? ?? 0;
    return ColoredBox(
      color: const Color(0xFF181A1E),
      child: Column(
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.centerLeft,
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primaryLight),
                SizedBox(width: 12),
                Text(
                  'Assistente de roteiro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceLighter),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            firstTake != null
                                ? 'Produção liberada (${episode.takes.length} prompts)'
                                : hasDetailedScript
                                ? 'Roteiro por cenas ($shotCount shots)'
                                : 'Esboço geral do episódio',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'EP${episode.number} · ${episode.title}',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      episode.summary,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    if (firstTake != null) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Cena ${firstTake.number} · ${firstTake.title}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        firstTake.visualPrompt,
                        maxLines: 12,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceLighter),
                        ),
                        child: Text(
                          hasDetailedScript
                              ? 'O roteiro completo está pronto para revisão. A produção de vídeo permanece bloqueada até a aprovação das cenas, falas, ações e durações.'
                              : 'O esboço vem primeiro. O roteiro detalhado por cenas ainda não foi gerado para este episódio.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: hasDetailedScript
                              ? () => setState(
                                  () => _showEpisodeScriptEditor = true,
                                )
                              : _generatingScriptEpisodeNumber == episode.number
                              ? null
                              : () => _generateEpisodeScript(_episodeIndex),
                          icon:
                              !hasDetailedScript &&
                                  _generatingScriptEpisodeNumber ==
                                      episode.number
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  hasDetailedScript
                                      ? Icons.fact_check_outlined
                                      : Icons.description_outlined,
                                ),
                          label: Text(
                            hasDetailedScript
                                ? 'Revisar e aprovar roteiro'
                                : _generatingScriptEpisodeNumber ==
                                      episode.number
                                ? 'Gerando roteiro...'
                                : 'Gerar roteiro detalhado por cenas',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              episode.cliffhanger,
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_assistantRequest != null) ...[
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text(
                        'ÚLTIMO PEDIDO',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _assistantRequest!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _buildAssistantComposer(),
        ],
      ),
    );
  }

  Widget _buildAssistantComposer() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.fromLTRB(14, 6, 7, 6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.surfaceLighter),
    ),
    child: Row(
      children: [
        const Icon(Icons.attach_file, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _assistantController,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitAssistantRequest(),
            decoration: const InputDecoration(
              hintText: 'Peça um ajuste no roteiro...',
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: 'Enviar',
          onPressed: _submitAssistantRequest,
          icon: const Icon(Icons.arrow_upward),
        ),
      ],
    ),
  );

  void _submitAssistantRequest() {
    final value = _assistantController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _assistantRequest = value;
      _assistantController.clear();
    });
    _showStudioMessage('Pedido anotado. Revise o roteiro antes de salvar.');
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
