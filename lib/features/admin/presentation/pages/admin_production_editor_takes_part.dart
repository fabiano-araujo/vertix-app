part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorTakesExtension
    on _AdminProductionEditorPageState {
  static const _studioBg = Color(0xFF111214);
  static const _promptBg = Color(0xFF1A1C20);
  static const _generateGold = Color(0xFFE6D3A8);

  int get _currentTakeIndex {
    final episode = _episode;
    if (episode == null || episode.takes.isEmpty) return 0;
    return _selectedTakeIndex.clamp(0, episode.takes.length - 1);
  }

  String _takeSceneLabel(ProductionTakeItem take) {
    final title = take.title.trim();
    if (title.isEmpty) return 'Cena ${take.number}';
    final lower = title.toLowerCase();
    if (lower.startsWith('cena ')) return title;
    return 'Cena ${take.number} · $title';
  }

  Widget _buildTakes() {
    final episode = _episode!;
    final hasScriptDraft = _hasEpisodeScriptDraft(_project!, episode.number);
    if (episode.takes.isEmpty) {
      return ListView(
        key: const PageStorageKey('production-takes-empty'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: [
          _panel(
            title: hasScriptDraft
                ? 'Roteiro gerado — revise e aprove'
                : 'Roteiro ainda não gerado',
            icon: hasScriptDraft
                ? Icons.fact_check_outlined
                : Icons.description_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasScriptDraft
                      ? 'O roteiro do EP${episode.number} já está salvo. Revise as cenas e aprove para liberar os takes de vídeo.'
                      : 'A produção só é liberada depois que o roteiro completo do episódio é gerado, revisado e aprovado.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: hasScriptDraft
                      ? () => setState(() {
                          _episodeProductionMode = false;
                          _showTechnicalEditor = false;
                          _showEpisodeScriptEditor = true;
                          _studioTabIndex = 1;
                        })
                      : _generatingScriptEpisodeNumber == episode.number
                      ? null
                      : () => _generateEpisodeScript(_episodeIndex),
                  icon: Icon(
                    hasScriptDraft
                        ? Icons.fact_check_outlined
                        : Icons.description_outlined,
                  ),
                  label: Text(
                    hasScriptDraft
                        ? 'Revisar e aprovar roteiro'
                        : 'Gerar roteiro por cenas',
                  ),
                ),
                if (hasScriptDraft) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isApprovingScript
                        ? null
                        : _approveEpisodeScriptForProduction,
                    icon: _isApprovingScript
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: Text(
                      _isApprovingScript
                          ? 'Preparando produção...'
                          : 'Aprovar e liberar produção',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final takeIndex = _currentTakeIndex;
    final take = episode.takes[takeIndex];
    return ColoredBox(
      color: _studioBg,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                if (stacked) {
                  return Column(
                    children: [
                      Expanded(flex: 5, child: _buildTakePreviewPane(take)),
                      Expanded(
                        flex: 6,
                        child: _buildTakePromptPane(episode, takeIndex, take),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _buildTakePromptPane(episode, takeIndex, take),
                    ),
                    Expanded(flex: 8, child: _buildTakePreviewPane(take)),
                    SizedBox(width: 92, child: _buildTakeVersionsRail(take)),
                  ],
                );
              },
            ),
          ),
          _buildTakeStrip(episode, takeIndex),
        ],
      ),
    );
  }

  Widget _buildTakePromptPane(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take,
  ) {
    final prompt = _takeEditorField == 'audio'
        ? take.audioPrompt
        : take.visualPrompt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
      child: Column(
        children: [
          _buildTakePromptToolbar(episode, takeIndex, take),
          if (!_storyReferencesReadyForVideo) ...[
            const SizedBox(height: 10),
            _buildMissingReferencesBanner(),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _promptBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLighter),
              ),
              child: TextFormField(
                key: ValueKey('${take.id}-$_takeEditorField'),
                initialValue: prompt,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                  hintText: _takeEditorField == 'audio'
                      ? 'Escreva o áudio, vozes e SFX desta cena...'
                      : 'Escreva a cena que você quer gerar...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
                onChanged: (value) {
                  final current = _episode!.takes[takeIndex];
                  _replaceTake(
                    takeIndex,
                    _takeEditorField == 'audio'
                        ? current.copyWith(audioPrompt: value)
                        : current.copyWith(visualPrompt: value),
                  );
                },
              ),
            ),
          ),
          if (take.status == 'QUEUED' || take.status == 'GENERATING') ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: take.progress <= 0 ? null : take.progress,
                backgroundColor: AppColors.surfaceLighter,
              ),
            ),
            if ((_activeDolaMessages[take.id] ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _activeDolaMessages[take.id]!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          if (take.status == 'FAILED') ...[
            const SizedBox(height: 10),
            _buildDolaErrorBanner(take),
          ],
          const SizedBox(height: 10),
          _buildTakePromptFooter(episode, takeIndex, take),
        ],
      ),
    );
  }

  Widget _buildTakePromptToolbar(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _studioChip(
          icon: Icons.description_outlined,
          label: 'Roteiro original',
        ),
        _studioMenuChip(
          icon: Icons.movie_filter_outlined,
          label: _takeSceneLabel(take),
          items: [
            for (final item in episode.takes)
              PopupMenuItem(
                value: item.number - 1,
                child: Text(_takeSceneLabel(item)),
              ),
          ],
          onSelected: (value) => setState(() => _selectedTakeIndex = value),
        ),
        _studioMenuChip(
          icon: Icons.notes_outlined,
          label: _takeEditorField == 'audio'
              ? 'Formato: Áudio e voz'
              : 'Formato: Descrição Natural',
          items: const [
            PopupMenuItem(
              value: 'visual',
              child: Text('Descrição Natural'),
            ),
            PopupMenuItem(value: 'audio', child: Text('Áudio e voz')),
          ],
          onSelected: (value) => setState(() => _takeEditorField = value),
        ),
        TextButton.icon(
          onPressed: () => _showTakeAdvancedSheet(episode, takeIndex, take),
          icon: const Icon(Icons.replay, size: 16),
          label: const Text('Solicitação de regeneração'),
        ),
      ],
    );
  }

  Widget _buildMissingReferencesBanner() {
    return Material(
      color: const Color(0xFF2A2218),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openProjectBoard(sectionIndex: 3),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 18, color: Color(0xFFE6D3A8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _missingStoryReferencesMessage,
                  style: const TextStyle(
                    color: Color(0xFFE6D3A8),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Abrir referências',
                style: TextStyle(
                  color: Color(0xFFE6D3A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDolaErrorBanner(ProductionTakeItem take) {
    final message = take.errorMessage.trim().isEmpty
        ? 'A geração no Dola falhou.'
        : take.errorMessage.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Erro na geração do Dola',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakePromptFooter(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take,
  ) {
    final generatingThis =
        take.status == 'GENERATING' || take.status == 'QUEUED';
    final generating = generatingThis || _isGeneratingEpisode;
    final referencesReady = _storyReferencesReadyForVideo;
    final failed = take.status == 'FAILED';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          () {
            final preset = VideoGenerationPreset.fromBible(
              _project?.seriesBible ?? const {},
            );
            final channel = preset.channel == 'dola' ? 'Dola Pre-Writes' : 'API';
            final profiles = _dolaProfiles;
            final profileBit = preset.channel == 'dola'
                ? (profiles == null
                      ? 'Playwright local'
                      : profiles.availableCount == 0
                      ? 'sem perfis hoje'
                      : '${profiles.availableCount} perfis livres')
                : preset.modelLabel;
            if (generatingThis) {
              return '$channel · $profileBit · gerando';
            }
            if (failed) {
              return '$channel · $profileBit · erro';
            }
            return '$channel · $profileBit · ${take.durationSeconds}s · 720p · ${_transitionLabel(take.transitionMode)}';
          }(),
          style: TextStyle(
            color: failed ? AppColors.error : AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          tooltip: 'Referências desta cena',
          onPressed: () => _showReferencePicker(takeIndex),
          icon: const Icon(Icons.alternate_email, size: 20),
        ),
        TextButton.icon(
          onPressed: () => _showMentalTake(takeIndex),
          icon: const Icon(Icons.bolt, size: 16),
          label: const Text('Take mental'),
        ),
        FilledButton.icon(
          onPressed: generatingThis
              ? () => unawaited(_stopDolaGeneration(take.id))
              : generating || !referencesReady
              ? null
              : () => _generateTakeWithDola(takeIndex),
          style: FilledButton.styleFrom(
            backgroundColor: generatingThis ? AppColors.error : _generateGold,
            foregroundColor: generatingThis ? Colors.white : Colors.black,
            disabledBackgroundColor: _generateGold.withAlpha(90),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: Icon(
            generatingThis
                ? Icons.stop_rounded
                : generating
                ? Icons.hourglass_top
                : !referencesReady
                ? Icons.lock_outline
                : failed || take.status == 'COMPLETED'
                ? Icons.replay
                : Icons.auto_awesome,
            size: 18,
          ),
          label: Text(
            generatingThis
                ? 'Parar geração'
                : generating
                ? 'Gerando...'
                : !referencesReady
                ? 'Gere as referências primeiro'
                : failed
                ? 'Tentar de novo'
                : take.status == 'COMPLETED'
                ? 'Refazer vídeo'
                : 'Gerar vídeo',
          ),
        ),
      ],
    );
  }

  Widget _buildTakePreviewPane(ProductionTakeItem take) {
    final references = _referencesForTake(take);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 10, 10),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: _InlineTakePlayer(
                  key: _inlineTakePlayerKey,
                  take: take,
                  cover: references.isEmpty
                      ? null
                      : _takeReferenceCollage(references, openOnTap: true),
                  onMentalTake: () => _showMentalTake(_currentTakeIndex),
                  onAdjust: () => _showTakeAdvancedSheet(
                    _episode!,
                    _currentTakeIndex,
                    take,
                  ),
                  onPlaybackTick: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildTakePlaybackBar(take),
        ],
      ),
    );
  }

  Widget _takeReferenceCollage(
    List<ProductionReferenceItem> references, {
    bool openOnTap = false,
    bool compact = false,
  }) {
    return _TakeReferenceCollage(
      references: references,
      compact: compact,
      itemBuilder: (reference) => _referencePreview(
        reference,
        openOnTap: openOnTap,
        gallery: references,
      ),
    );
  }

  Widget _buildTakePlaybackBar(ProductionTakeItem take) {
    final player = _inlineTakePlayerKey.currentState;
    final playing = player?.isPlaying ?? false;
    final loading = player?.isLoading ?? false;
    final position = player?.position ?? Duration.zero;
    final duration = player?.duration ?? Duration(seconds: take.durationSeconds);
    return Row(
      children: [
        Text(
          '${_formatClock(position)} / ${_formatClock(duration)}',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Cena anterior',
          onPressed: _currentTakeIndex == 0
              ? null
              : () =>
                    setState(() => _selectedTakeIndex = _currentTakeIndex - 1),
          icon: const Icon(Icons.skip_previous),
        ),
        IconButton.filled(
          tooltip: playing ? 'Pausar' : 'Reproduzir nesta tela',
          onPressed: loading
              ? null
              : () async {
                  await _inlineTakePlayerKey.currentState?.togglePlay();
                  if (mounted) setState(() {});
                },
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Próxima cena',
          onPressed:
              _episode == null ||
                  _currentTakeIndex >= _episode!.takes.length - 1
              ? null
              : () =>
                    setState(() => _selectedTakeIndex = _currentTakeIndex + 1),
          icon: const Icon(Icons.skip_next),
        ),
        const Spacer(),
        _studioChip(label: 'Cena única'),
      ],
    );
  }

  Widget _buildTakeVersionsRail(ProductionTakeItem take) {
    return ColoredBox(
      color: const Color(0xFF16181C),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: Text(
              'VERSÕES\nDE VÍDEO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _versionRailButton(
            icon: Icons.upload_outlined,
            label: 'Enviar',
            onTap: () => _showStudioMessage(
              'Envio de vídeo local entra na próxima etapa.',
            ),
          ),
          const SizedBox(height: 8),
          _versionRailButton(
            icon: Icons.dashboard_outlined,
            label: 'Quadro',
            onTap: _openProjectBoard,
          ),
          if (take.status == 'COMPLETED') ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(120)),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_outline, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTakeStrip(ProductionEpisodeItem episode, int selectedIndex) {
    return Container(
      height: 126,
      decoration: const BoxDecoration(
        color: Color(0xFF0E1013),
        border: Border(top: BorderSide(color: AppColors.surfaceLighter)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: episode.takes.length,
        separatorBuilder: (context, index) => Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Inserir cena',
              visualDensity: VisualDensity.compact,
              onPressed: () => _insertBlankTakeAfter(index),
              icon: const Icon(Icons.add_circle_outline, size: 18),
            ),
            const SizedBox(width: 6),
          ],
        ),
        itemBuilder: (context, index) {
          final take = episode.takes[index];
          final selected = index == selectedIndex;
          final references = _referencesForTake(take);
          return InkWell(
            onTap: () => setState(() => _selectedTakeIndex = index),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 118,
              child: Column(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : AppColors.surfaceLighter,
                          width: selected ? 2.4 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (references.isNotEmpty)
                              _takeReferenceCollage(
                                references,
                                compact: true,
                              )
                            else
                              ColoredBox(
                                color: AppColors.surfaceLight,
                                child: Center(
                                  child: Text(
                                    '${take.number}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            if (take.status == 'COMPLETED')
                              const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            if (take.status == 'FAILED')
                              const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.error,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cena ${take.number} (${take.durationSeconds}s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _studioChip({IconData? icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _studioMenuChip<T>({
    required IconData icon,
    required String label,
    required List<PopupMenuEntry<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: _studioChip(icon: icon, label: label),
    );
  }

  Widget _versionRailButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLighter),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _transitionLabel(String mode) => switch (mode) {
    'EPISODE_START' => 'início',
    'MATCH_ON_ACTION' => 'match on action',
    'HARD_CUT' => 'corte seco',
    _ => 'continuidade',
  };

  void _insertBlankTakeAfter(int index) {
    final episode = _episode;
    if (episode == null) return;
    final source = episode.takes[index];
    final inserted = ProductionTakeItem(
      id: 'take-${episode.number}-${DateTime.now().millisecondsSinceEpoch}',
      number: index + 2,
      title: 'Nova cena',
      durationSeconds: source.durationSeconds,
      visualPrompt: '',
      audioPrompt: '',
      transitionMode: 'SOFT_CONTINUITY',
      usePreviousLastFrame: true,
      generateSeedanceAudio: source.generateSeedanceAudio,
      referenceIds: List<String>.from(source.referenceIds),
    );
    final takes = [
      ...episode.takes.sublist(0, index + 1),
      inserted,
      ...episode.takes.sublist(index + 1),
    ];
    _replaceEpisode(
      episode.copyWith(
        takes: [
          for (var i = 0; i < takes.length; i++)
            takes[i].copyWith(number: i + 1),
        ],
        durationSeconds: takes.fold<int>(
          0,
          (sum, item) => sum + item.durationSeconds,
        ),
      ),
    );
    setState(() => _selectedTakeIndex = index + 1);
  }

  Future<void> _showMentalTake(int takeIndex) async {
    final project = _project;
    final episode = _episode;
    if (project == null || episode == null) return;
    final take = episode.takes[takeIndex];
    final references = _referencesForTake(take);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF15171B),
        title: Text('Take mental · Cena ${take.number}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: references.isNotEmpty
                      ? _takeReferenceCollage(
                          references,
                          openOnTap: true,
                        )
                      : const ColoredBox(
                          color: Color(0xFF1C1E24),
                          child: Center(
                            child: Icon(Icons.movie_filter_outlined, size: 42),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                take.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                take.visualPrompt.isEmpty
                    ? 'Escreva o prompt da cena para visualizar o take mental.'
                    : take.visualPrompt,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontSize: 12.5,
                ),
              ),
              if (references.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: references.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 42,
                        height: 58,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _referencePreview(
                              references[index],
                              gallery: references,
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: ColoredBox(
                                color: const Color(0x99000000),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '@Image${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: _storyReferencesReadyForVideo
                ? () {
                    Navigator.pop(dialogContext);
                    _generateTakeWithDola(takeIndex);
                  }
                : null,
            child: Text(
              _storyReferencesReadyForVideo
                  ? 'Gerar vídeo'
                  : 'Gere as referências primeiro',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTakeAdvancedSheet(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take,
  ) {
    final inheritedFrame = takeIndex > 0
        ? episode.takes[takeIndex - 1].lastFrameLabel
        : null;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _takeSceneLabel(take),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _buildTakeControls(
                  episode,
                  takeIndex,
                  take,
                  inheritedFrame: inheritedFrame,
                ),
                const SizedBox(height: 14),
                _buildTakeReferences(takeIndex, _referencesForTake(take)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: !_storyReferencesReadyForVideo
                        ? null
                        : _isGeneratingEpisode
                        ? () {
                            Navigator.pop(sheetContext);
                            unawaited(_stopDolaGeneration());
                          }
                        : () {
                            Navigator.pop(sheetContext);
                            _generateAllTakes();
                          },
                    icon: Icon(
                      _isGeneratingEpisode
                          ? Icons.stop_rounded
                          : Icons.auto_awesome,
                      size: 16,
                    ),
                    label: Text(
                      _isGeneratingEpisode
                          ? 'Parar geração'
                          : 'Gerar todos os takes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTakeControls(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take, {
    required String? inheritedFrame,
  }) {
    final canInherit = takeIndex > 0;
    final previousTake = canInherit ? episode.takes[takeIndex - 1] : null;
    final preset = VideoGenerationPreset.fromBible(
      _project?.seriesBible ?? const {},
    );
    final durations = preset.channel == 'dola' || preset.fixedShotDuration
        ? {5, 10, take.durationSeconds}.toList()
        : {5, 8, 10, 12, 15, 30, take.durationSeconds}.toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 235,
              child: DropdownButtonFormField<String>(
                key: ValueKey('${take.id}-transition'),
                initialValue: take.transitionMode,
                decoration: const InputDecoration(
                  labelText: 'Transição de entrada',
                  prefixIcon: Icon(Icons.swap_calls),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'EPISODE_START',
                    child: Text('Início do episódio'),
                  ),
                  DropdownMenuItem(
                    value: 'MATCH_ON_ACTION',
                    child: Text('Match on action'),
                  ),
                  DropdownMenuItem(
                    value: 'SOFT_CONTINUITY',
                    child: Text('Continuidade suave'),
                  ),
                  DropdownMenuItem(
                    value: 'HARD_CUT',
                    child: Text('Corte seco'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _replaceTake(
                      takeIndex,
                      take.copyWith(transitionMode: value),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            SizedBox(
              width: 185,
              child: DropdownButtonFormField<int>(
                key: ValueKey('${take.id}-duration'),
                initialValue: take.durationSeconds,
                decoration: const InputDecoration(
                  labelText: 'Duração',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: durations
                    .map(
                      (seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds segundos'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _replaceTake(
                      takeIndex,
                      take.copyWith(durationSeconds: value),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            Container(
              width: 355,
              constraints: const BoxConstraints(minHeight: 64),
              child: Material(
                color: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: take.usePreviousLastFrame
                        ? AppColors.primary.withAlpha(120)
                        : AppColors.surfaceLighter,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile.adaptive(
                  dense: true,
                  value: canInherit && take.usePreviousLastFrame,
                  onChanged: canInherit
                      ? (value) {
                          _replaceTake(
                            takeIndex,
                            take.copyWith(
                              usePreviousLastFrame: value,
                              transitionMode: value
                                  ? 'MATCH_ON_ACTION'
                                  : 'SOFT_CONTINUITY',
                            ),
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  title: const Text(
                    'Usar último frame anterior',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    !canInherit
                        ? 'Primeiro take inicia sem ponte visual.'
                        : inheritedFrame ??
                              'O frame final do take ${previousTake!.number} será capturado ao gerar.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            Container(
              width: 310,
              constraints: const BoxConstraints(minHeight: 64),
              child: Material(
                color: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.surfaceLighter),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile.adaptive(
                  dense: true,
                  value: take.generateSeedanceAudio,
                  onChanged: (value) {
                    _replaceTake(
                      takeIndex,
                      take.copyWith(generateSeedanceAudio: value),
                    );
                    Navigator.pop(context);
                  },
                  title: const Text(
                    'Áudio guia do Seedance',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'A música final continua em faixa separada.',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('${take.id}-title'),
          initialValue: take.title,
          decoration: const InputDecoration(
            labelText: 'Título da cena',
            prefixIcon: Icon(Icons.title),
          ),
          onChanged: (value) {
            _replaceTake(
              takeIndex,
              _episode!.takes[takeIndex].copyWith(title: value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('${take.id}-notes'),
          initialValue: take.notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Notas de direção e continuidade',
            prefixIcon: Icon(Icons.edit_note_outlined),
            alignLabelWithHint: true,
          ),
          onChanged: (value) {
            _replaceTake(
              takeIndex,
              _episode!.takes[takeIndex].copyWith(notes: value),
            );
          },
        ),
      ],
    );
  }

  List<ProductionReferenceItem> _referencesForTake(ProductionTakeItem take) {
    final project = _project;
    if (project == null) return const [];
    return _workspaceService.storyReferencesForTake(
      project,
      take,
      episodeNumber: _episode?.number,
    );
  }

  Widget _buildTakeReferences(
    int takeIndex,
    List<ProductionReferenceItem> references,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.collections_outlined,
                color: AppColors.primaryLight,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Imagens de referência deste take',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showReferencePicker(takeIndex),
                icon: const Icon(Icons.tune, size: 17),
                label: const Text('Selecionar'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (references.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Nenhuma referência vinculada a este take.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: references
                  .map(
                    (reference) => SizedBox(
                      width: 178,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 178,
                              height: 102,
                              child: _referencePreview(
                                reference,
                                gallery: references,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            reference.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            reference.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showReferencePicker(int takeIndex) async {
    final project = _project;
    final episode = _episode;
    if (project == null || episode == null) return;
    final take = episode.takes[takeIndex];
    final required = _workspaceService.storyReferencesForTake(
      project,
      take,
      episodeNumber: episode.number,
    );
    final selected = {
      ...take.referenceIds,
      ...required.map((item) => item.id),
    };
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Referências do take ${take.number}'),
          content: SizedBox(
            width: 540,
            height: 430,
            child: project.references.isEmpty
                ? const Center(child: Text('A obra ainda não possui assets.'))
                : ListView.separated(
                    itemCount: project.references.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final reference = project.references[index];
                      return CheckboxListTile(
                        value: selected.contains(reference.id),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(reference.id);
                            } else {
                              selected.remove(reference.id);
                            }
                          });
                        },
                        secondary: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: SizedBox(
                            width: 58,
                            height: 48,
                            child: _referencePreview(
                              reference,
                              gallery: project.references,
                            ),
                          ),
                        ),
                        title: Text(reference.label),
                        subtitle: Text(reference.category),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected.toList()),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    _replaceTake(
      takeIndex,
      _workspaceService.syncTakeStoryReferences(
        project,
        take.copyWith(referenceIds: result),
        episodeNumber: episode.number,
      ),
    );
  }
}

class _InlineTakePlayer extends StatefulWidget {
  const _InlineTakePlayer({
    super.key,
    required this.take,
    required this.cover,
    required this.onMentalTake,
    required this.onAdjust,
    required this.onPlaybackTick,
  });

  final ProductionTakeItem take;
  final Widget? cover;
  final VoidCallback onMentalTake;
  final VoidCallback onAdjust;
  final VoidCallback onPlaybackTick;

  @override
  State<_InlineTakePlayer> createState() => _InlineTakePlayerState();
}

class _InlineTakePlayerState extends State<_InlineTakePlayer> {
  final TransformationController _transform = TransformationController();
  VideoPlayerController? _controller;
  String? _loadedSource;
  bool _isLoading = false;
  bool _fullscreen = false;
  String? _error;

  bool get isPlaying => _controller?.value.isPlaying ?? false;
  bool get isLoading => _isLoading;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration get duration {
    final value = _controller?.value.duration;
    if (value != null && value > Duration.zero) return value;
    return Duration(seconds: widget.take.durationSeconds);
  }

  ({String source, bool isAsset})? get _source =>
      _playableTakeVideoSource(widget.take);

  @override
  void initState() {
    super.initState();
    unawaited(_prepareController(autoplay: false));
  }

  @override
  void didUpdateWidget(covariant _InlineTakePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.take.id != widget.take.id ||
        oldWidget.take.outputUrl != widget.take.outputUrl) {
      _transform.value = Matrix4.identity();
      unawaited(_prepareController(autoplay: false));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTick);
    _controller?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> togglePlay() async {
    final source = _source;
    if (source == null) {
      _showMissingVideo();
      return;
    }
    await _prepareController(autoplay: true);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration &&
          controller.value.duration > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    if (mounted) setState(() {});
    widget.onPlaybackTick();
  }

  Future<void> openFullscreen() async {
    final source = _source;
    if (source == null) {
      _showMissingVideo();
      return;
    }
    await _prepareController(autoplay: false);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || !mounted) {
      return;
    }
    setState(() => _fullscreen = true);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => _TakeFullscreenScaffold(
        title: widget.take.title,
        controller: controller,
        transform: _transform,
        onClose: () => Navigator.pop(dialogContext),
        onPlayPause: togglePlay,
        onZoomIn: () => _nudgeZoom(0.35),
        onZoomOut: () => _nudgeZoom(-0.35),
      ),
    );
    if (mounted) setState(() => _fullscreen = false);
    widget.onPlaybackTick();
  }

  Future<void> _prepareController({required bool autoplay}) async {
    final source = _source;
    if (source == null) {
      await _disposeController();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }
    if (_loadedSource == source.source &&
        _controller != null &&
        _controller!.value.isInitialized) {
      return;
    }
    await _disposeController();
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final controller = source.isAsset
        ? VideoPlayerController.asset(source.source)
        : VideoPlayerController.networkUrl(Uri.parse(source.source));
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handleTick);
      setState(() {
        _controller = controller;
        _loadedSource = source.source;
        _isLoading = false;
      });
      if (autoplay) await controller.play();
    } catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Não foi possível carregar o vídeo.';
      });
    }
  }

  Future<void> _disposeController() async {
    final previous = _controller;
    _controller = null;
    _loadedSource = null;
    previous?.removeListener(_handleTick);
    await previous?.dispose();
  }

  DateTime? _lastParentTick;

  void _handleTick() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying &&
        controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration) {
      unawaited(controller.pause());
    }
    setState(() {});
    final now = DateTime.now();
    final playing = controller?.value.isPlaying ?? false;
    if (!playing ||
        _lastParentTick == null ||
        now.difference(_lastParentTick!) >= const Duration(milliseconds: 250)) {
      _lastParentTick = now;
      widget.onPlaybackTick();
    }
  }

  void _nudgeZoom(double delta) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current + delta).clamp(1.0, 4.0);
    _transform.value = Matrix4.identity()..scaleByDouble(next, next, 1, 1);
    setState(() {});
  }

  void _showMissingVideo() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Gere o vídeo desta cena para reproduzir aqui.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0D10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.cover != null)
              widget.cover!
            else
              const ColoredBox(color: Color(0xFF15171B)),
            if (!_fullscreen &&
                _controller != null &&
                _controller!.value.isInitialized)
              GestureDetector(
                onTap: togglePlay,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      transformationController: _transform,
                      constrained: false,
                      minScale: 1,
                      maxScale: 4,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!_fullscreen && !isPlaying && !_isLoading)
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Color(0x99000000)],
                    ),
                  ),
                ),
              ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            if (!_fullscreen && !isPlaying && !_isLoading)
              _TakePreviewIdleOverlay(
                take: widget.take,
                hasCover: widget.cover != null,
                hasVideo: _source != null,
                onMentalTake: widget.onMentalTake,
                onAdjust: widget.onAdjust,
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TakePreviewIconButton(
                    tooltip: 'Diminuir',
                    icon: Icons.zoom_out,
                    onPressed: () => _nudgeZoom(-0.35),
                  ),
                  const SizedBox(width: 6),
                  _TakePreviewIconButton(
                    tooltip: 'Aumentar',
                    icon: Icons.zoom_in,
                    onPressed: () => _nudgeZoom(0.35),
                  ),
                  const SizedBox(width: 6),
                  _TakePreviewIconButton(
                    tooltip: 'Tela cheia',
                    icon: Icons.fullscreen,
                    onPressed: openFullscreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakePreviewGhostButton extends StatelessWidget {
  const _TakePreviewGhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        backgroundColor: Colors.black45,
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _TakePreviewIdleOverlay extends StatelessWidget {
  const _TakePreviewIdleOverlay({
    required this.take,
    required this.hasCover,
    required this.hasVideo,
    required this.onMentalTake,
    required this.onAdjust,
  });

  final ProductionTakeItem take;
  final bool hasCover;
  final bool hasVideo;
  final VoidCallback onMentalTake;
  final VoidCallback onAdjust;

  bool get _busy =>
      take.status == 'GENERATING' || take.status == 'QUEUED';

  bool get _failed => take.status == 'FAILED';

  bool get _showStatusMessage => _failed || _busy || !hasCover;

  String get _message {
    if (_failed) {
      final error = take.errorMessage.trim();
      return error.isEmpty ? 'Erro na geração do Dola' : error;
    }
    if (_busy) return 'Gerando no Dola...';
    if (!hasVideo) return 'Edite o prompt e clique em Gerar vídeo';
    return take.title;
  }

  @override
  Widget build(BuildContext context) {
    final buttons = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _TakePreviewGhostButton(
          icon: Icons.visibility_outlined,
          label: 'Ver take mental',
          onTap: onMentalTake,
        ),
        _TakePreviewGhostButton(
          icon: Icons.tune,
          label: 'Ajustar cena',
          onTap: onAdjust,
        ),
      ],
    );
    if (!_showStatusMessage) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: buttons,
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: _failed ? const Color(0xFFFECACA) : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            buttons,
          ],
        ),
      ),
    );
  }
}

class _TakeReferenceCollage extends StatelessWidget {
  const _TakeReferenceCollage({
    required this.references,
    required this.itemBuilder,
    this.compact = false,
  });

  final List<ProductionReferenceItem> references;
  final Widget Function(ProductionReferenceItem reference) itemBuilder;
  final bool compact;

  static const _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) {
      return const ColoredBox(color: Color(0xFF15171B));
    }
    if (references.length == 1) {
      return itemBuilder(references.first);
    }
    final visible = references.take(_maxVisible).toList();
    final hidden = references.length - visible.length;
    return ColoredBox(
      color: const Color(0xFF0C0D10),
      child: Column(
        children: [
          for (var index = 0; index < visible.length; index++) ...[
            if (index > 0)
              const ColoredBox(
                color: Color(0xFF111214),
                child: SizedBox(height: 1),
              ),
            Expanded(
              flex: _flexFor(visible[index]),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  itemBuilder(visible[index]),
                  if (!compact)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      right: 8,
                      child: _TakeReferenceBadge(
                        index: index + 1,
                        label: visible[index].label,
                        extra: index == visible.length - 1 && hidden > 0
                            ? hidden
                            : 0,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _flexFor(ProductionReferenceItem reference) {
    final category = reference.category.toUpperCase();
    if (category.contains('CHARACTER') || category.contains('OPPOSING')) {
      return 3;
    }
    if (category.contains('PROP') || category.contains('OBJECT')) {
      return 1;
    }
    return 2;
  }
}

class _TakeReferenceBadge extends StatelessWidget {
  const _TakeReferenceBadge({
    required this.index,
    required this.label,
    this.extra = 0,
  });

  final int index;
  final String label;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final suffix = extra > 0 ? '  +$extra' : '';
    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC0C0D10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            '@Image$index  $label$suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _TakePreviewIconButton extends StatelessWidget {
  const _TakePreviewIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TakeFullscreenScaffold extends StatelessWidget {
  const _TakeFullscreenScaffold({
    required this.title,
    required this.controller,
    required this.transform,
    required this.onClose,
    required this.onPlayPause,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final String title;
  final VideoPlayerController controller;
  final TransformationController transform;
  final VoidCallback onClose;
  final Future<void> Function() onPlayPause;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: InteractiveViewer(
                  transformationController: transform,
                  constrained: false,
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    height: MediaQuery.sizeOf(context).height,
                    child: value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: value.size.width,
                              height: value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Diminuir',
                      color: Colors.white,
                      onPressed: onZoomOut,
                      icon: const Icon(Icons.zoom_out),
                    ),
                    IconButton(
                      tooltip: 'Aumentar',
                      color: Colors.white,
                      onPressed: onZoomIn,
                      icon: const Icon(Icons.zoom_in),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      color: Colors.white,
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: IconButton.filled(
                    tooltip: value.isPlaying ? 'Pausar' : 'Reproduzir',
                    onPressed: onPlayPause,
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
