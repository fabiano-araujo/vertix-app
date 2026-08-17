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

  Widget _buildTakes() {
    final episode = _episode!;
    final hasScriptDraft = _episodeScriptFor(
      _project!,
      episode.number,
    ).isNotEmpty;
    if (episode.takes.isEmpty) {
      return ListView(
        key: const PageStorageKey('production-takes-empty'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: [
          _panel(
            title: 'Roteiro ainda não gerado',
            icon: Icons.description_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A produção só é liberada depois que o roteiro completo do episódio é revisado e aprovado.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: hasScriptDraft
                      ? () => setState(() {
                          _showTechnicalEditor = false;
                          _showEpisodeScriptEditor = true;
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
          label: 'Cena ${take.number} · ${take.title}',
          items: [
            for (final item in episode.takes)
              PopupMenuItem(
                value: item.number - 1,
                child: Text('Cena ${item.number} · ${item.title}'),
              ),
          ],
          onSelected: (value) => setState(() => _selectedTakeIndex = value),
        ),
        _studioMenuChip(
          icon: Icons.notes_outlined,
          label: _takeEditorField == 'audio'
              ? 'Formato: Áudio e voz'
              : 'Formato: Prompt visual',
          items: const [
            PopupMenuItem(value: 'visual', child: Text('Prompt visual')),
            PopupMenuItem(value: 'audio', child: Text('Áudio e voz')),
          ],
          onSelected: (value) => setState(() => _takeEditorField = value),
        ),
        TextButton.icon(
          onPressed: () => _showTakeAdvancedSheet(episode, takeIndex, take),
          icon: const Icon(Icons.tune, size: 16),
          label: const Text('Mais opções'),
        ),
      ],
    );
  }

  Widget _buildTakePromptFooter(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take,
  ) {
    final generating = take.status == 'GENERATING' || take.status == 'QUEUED';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Seedance 2.5 · ${take.durationSeconds}s · 720p · ${_transitionLabel(take.transitionMode)}',
          style: const TextStyle(
            color: AppColors.textTertiary,
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
          onPressed: generating ? null : () => _simulateTake(takeIndex),
          style: FilledButton.styleFrom(
            backgroundColor: _generateGold,
            foregroundColor: Colors.black,
            disabledBackgroundColor: _generateGold.withAlpha(90),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: Icon(
            generating
                ? Icons.hourglass_top
                : take.status == 'COMPLETED'
                ? Icons.replay
                : Icons.auto_awesome,
            size: 18,
          ),
          label: Text(
            generating
                ? 'Gerando...'
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
    final cover = references.isNotEmpty ? references.first : null;
    final hasOutput =
        take.outputUrl != null &&
        take.outputUrl!.trim().isNotEmpty &&
        !take.outputUrl!.startsWith('local://');
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 10, 10),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: DecoratedBox(
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
                        if (cover != null)
                          _referencePreview(cover)
                        else
                          const ColoredBox(color: Color(0xFF15171B)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x33000000), Color(0xCC000000)],
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasOutput
                                      ? take.title
                                      : 'Edite o prompt e clique em Gerar vídeo',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _previewGhostButton(
                                      icon: Icons.visibility_outlined,
                                      label: 'Ver take mental',
                                      onTap: () =>
                                          _showMentalTake(_currentTakeIndex),
                                    ),
                                    _previewGhostButton(
                                      icon: Icons.tune,
                                      label: 'Ajustar cena',
                                      onTap: () => _showTakeAdvancedSheet(
                                        _episode!,
                                        _currentTakeIndex,
                                        take,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildTakePlaybackBar(ProductionTakeItem take) {
    return Row(
      children: [
        Text(
          '0:00 / ${_timecode(take.durationSeconds)}',
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
          tooltip: 'Prévia da montagem',
          onPressed: _showEpisodePreview,
          icon: const Icon(Icons.play_arrow),
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
            onTap: () => setState(() => _showTechnicalEditor = true),
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
                              _referencePreview(references.first)
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

  Widget _previewGhostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
                      ? _referencePreview(references.first)
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
                        child: _referencePreview(references[index]),
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
            onPressed: () {
              Navigator.pop(dialogContext);
              _simulateTake(takeIndex);
            },
            child: const Text('Gerar vídeo'),
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
                  'Cena ${take.number} · ${take.title}',
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
    final durations = {5, 8, 10, 12, 15, take.durationSeconds}.toList()..sort();
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
    final references =
        _project?.references ?? const <ProductionReferenceItem>[];
    return references
        .where((reference) => take.referenceIds.contains(reference.id))
        .toList();
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
                              child: _referencePreview(reference),
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
    final selected = take.referenceIds.toSet();
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
                            child: _referencePreview(reference),
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
    _replaceTake(takeIndex, take.copyWith(referenceIds: result));
  }
}
