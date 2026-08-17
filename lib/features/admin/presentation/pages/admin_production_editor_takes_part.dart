part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorTakesExtension
    on _AdminProductionEditorPageState {
  Widget _buildTakes() {
    final episode = _episode!;
    final hasScriptDraft = _episodeScriptFor(
      _project!,
      episode.number,
    ).isNotEmpty;
    return ListView(
      key: const PageStorageKey('production-takes'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _buildTakeToolbar(episode),
        const SizedBox(height: 12),
        if (episode.takes.isEmpty)
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
          )
        else
          ...List.generate(
            episode.takes.length,
            (index) => _buildTakeCard(episode, index),
          ),
      ],
    );
  }

  Widget _buildTakeToolbar(ProductionEpisodeItem episode) {
    final allLinked = episode.takes
        .skip(1)
        .every((take) => take.usePreviousLastFrame);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          const Icon(Icons.movie_filter_outlined, color: AppColors.primary),
          Text(
            '${episode.takes.length} takes na sequencia',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          _pill('${_timecode(episode.durationSeconds)} total'),
          FilterChip(
            selected: allLinked,
            avatar: const Icon(Icons.link, size: 17),
            label: const Text('Ultimo frame automatico'),
            onSelected: episode.takes.isEmpty
                ? null
                : (value) {
                    final takes = episode.takes.toList();
                    for (var index = 1; index < takes.length; index++) {
                      takes[index] = takes[index].copyWith(
                        usePreviousLastFrame: value,
                        transitionMode: value
                            ? 'MATCH_ON_ACTION'
                            : 'SOFT_CONTINUITY',
                      );
                    }
                    _replaceEpisode(episode.copyWith(takes: takes));
                  },
          ),
          OutlinedButton.icon(
            onPressed: episode.takes.isEmpty
                ? null
                : () => setState(() => _sectionIndex = 4),
            icon: const Icon(Icons.view_timeline_outlined, size: 18),
            label: const Text('Ver montagem'),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeCard(ProductionEpisodeItem episode, int takeIndex) {
    final take = episode.takes[takeIndex];
    final start = _takeStartSeconds(episode, takeIndex);
    final end = start + take.durationSeconds;
    final references = _referencesForTake(take);
    final inheritedFrame = takeIndex > 0
        ? episode.takes[takeIndex - 1].lastFrameLabel
        : null;
    final statusColor = _statusColor(take.status);
    return Card(
      key: ValueKey(take.id),
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: take.status == 'GENERATING'
              ? AppColors.primary
              : AppColors.surfaceLighter,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: take.number <= 2,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: statusColor.withAlpha(28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withAlpha(90)),
          ),
          child: Text(
            '${take.number}'.padLeft(2, '0'),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          take.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _pill('${_timecode(start)}–${_timecode(end)}'),
              _pill(take.status, statusColor),
              _pill('${references.length} refs'),
              _pill(take.transitionMode),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 118,
          child: FilledButton.icon(
            onPressed: take.status == 'GENERATING'
                ? null
                : () => _simulateTake(takeIndex),
            icon: Icon(
              take.status == 'COMPLETED' ? Icons.replay : Icons.auto_awesome,
              size: 17,
            ),
            label: Text(take.status == 'COMPLETED' ? 'Refazer' : 'Gerar'),
          ),
        ),
        children: [
          if (take.status == 'QUEUED' || take.status == 'GENERATING') ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: take.progress,
                backgroundColor: AppColors.surfaceLighter,
              ),
            ),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final visual = _buildPromptEditor(
                title: 'Prompt visual / Seedance',
                icon: Icons.visibility_outlined,
                value: take.visualPrompt,
                onChanged: (value) {
                  _replaceTake(takeIndex, take.copyWith(visualPrompt: value));
                },
              );
              final audio = _buildPromptEditor(
                title: 'Prompt de voz e som',
                icon: Icons.graphic_eq,
                value: take.audioPrompt,
                onChanged: (value) {
                  _replaceTake(takeIndex, take.copyWith(audioPrompt: value));
                },
              );
              if (!wide) {
                return Column(
                  children: [visual, const SizedBox(height: 12), audio],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: visual),
                  const SizedBox(width: 12),
                  Expanded(child: audio),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _buildTakeControls(
            episode,
            takeIndex,
            take,
            inheritedFrame: inheritedFrame,
          ),
          const SizedBox(height: 14),
          _buildTakeReferences(takeIndex, references),
          if (take.lastFrameLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withAlpha(55)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: AppColors.success,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(take.lastFrameLabel!)),
                  const Text(
                    'Pronto para o proximo take',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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

  Widget _buildPromptEditor({
    required String title,
    required IconData icon,
    required String value,
    required ValueChanged<String> onChanged,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.surfaceLighter),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: value,
          minLines: 6,
          maxLines: 12,
          style: const TextStyle(fontSize: 12, height: 1.4),
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.all(12),
          ),
          onChanged: onChanged,
        ),
      ],
    ),
  );

  Widget _buildTakeControls(
    ProductionEpisodeItem episode,
    int takeIndex,
    ProductionTakeItem take, {
    required String? inheritedFrame,
  }) {
    final canInherit = takeIndex > 0;
    final previousTake = canInherit ? episode.takes[takeIndex - 1] : null;
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
                initialValue: take.transitionMode,
                decoration: const InputDecoration(
                  labelText: 'Transicao de entrada',
                  prefixIcon: Icon(Icons.swap_calls),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'EPISODE_START',
                    child: Text('Inicio do episodio'),
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
                  }
                },
              ),
            ),
            SizedBox(
              width: 185,
              child: DropdownButtonFormField<int>(
                initialValue: take.durationSeconds,
                decoration: const InputDecoration(
                  labelText: 'Duracao',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const [5, 8, 10, 12, 15]
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
                  }
                },
              ),
            ),
            Container(
              width: 355,
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: take.usePreviousLastFrame
                      ? AppColors.primary.withAlpha(120)
                      : AppColors.surfaceLighter,
                ),
              ),
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
                      }
                    : null,
                title: const Text(
                  'Usar ultimo frame anterior',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  !canInherit
                      ? 'Primeiro take inicia sem ponte visual.'
                      : inheritedFrame ??
                            'O frame final do take ${previousTake!.number} sera capturado ao gerar.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            Container(
              width: 310,
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLighter),
              ),
              child: SwitchListTile.adaptive(
                dense: true,
                value: take.generateSeedanceAudio,
                onChanged: (value) {
                  _replaceTake(
                    takeIndex,
                    take.copyWith(generateSeedanceAudio: value),
                  );
                },
                title: const Text(
                  'Audio guia do Seedance',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'A musica final continua em faixa separada.',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: take.notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Notas de direcao e continuidade',
            prefixIcon: Icon(Icons.edit_note_outlined),
            alignLabelWithHint: true,
          ),
          onChanged: (value) {
            _replaceTake(takeIndex, take.copyWith(notes: value));
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
                  'Imagens de referencia deste take',
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
                  'Nenhuma referencia vinculada a este take.',
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
          title: Text('Referencias do take ${take.number}'),
          content: SizedBox(
            width: 540,
            height: 430,
            child: project.references.isEmpty
                ? const Center(child: Text('A obra ainda nao possui assets.'))
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
