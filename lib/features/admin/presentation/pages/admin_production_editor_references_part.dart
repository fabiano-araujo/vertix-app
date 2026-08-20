part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorReferencesExtension
    on _AdminProductionEditorPageState {
  Widget _buildReferences({
    Set<String>? categories,
    String title = 'Pacote visual canônico',
    String description = '',
    String emptyLabel =
        'Adicione identidades, locais, objetos ou frames de continuidade.',
    String addLabel = 'Adicionar referência',
    String initialCategory = 'CHARACTER_REFERENCE',
    String sheetFamily = 'all',
  }) {
    final project = _project!;
    final references = categories == null
        ? project.references
        : project.references
              .where((reference) => categories.contains(reference.category))
              .toList();
    final missingImageCount = _workspaceService
        .automaticReferenceTargets(project, family: sheetFamily)
        .length;
    return ListView(
      key: PageStorageKey('production-references-$title'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: title,
          icon: Icons.collections_bookmark_outlined,
          trailing: FilledButton.icon(
            onPressed: _isAnyGenerationBusy
                ? null
                : () => _showAddReferenceDialog(
                    initialCategory: initialCategory,
                  ),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(addLabel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _buildReferenceRegenerateActions(
                sheetFamily: sheetFamily,
                missingImageCount: missingImageCount,
              ),
              const SizedBox(height: 12),
              if (_isReferenceImageBusy) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _activeReferenceImageProgress / 100,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _activeReferenceImageMessage ??
                      'Gerando imagens na tarefa do Codex...',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                  ),
                ),
                if (_activeCoverImageStatus != null) ...[
                  const SizedBox(height: 8),
                  _pill(
                    switch (_activeCoverImageStatus) {
                      'GENERATING' => 'Gerando arte da capa da série',
                      'UPLOADING' => 'Enviando arte da capa da série',
                      'COMPLETED' => 'Capa da série pronta',
                      'FAILED' => 'Capa da série falhou',
                      _ => 'Capa da série na fila',
                    },
                    _activeCoverImageStatus == 'FAILED'
                        ? AppColors.error
                        : _activeCoverImageStatus == 'COMPLETED'
                        ? AppColors.success
                        : AppColors.primaryLight,
                  ),
                ],
                if (_referenceImageBridgeNeedsRetry) ...[
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _isAnyGenerationBusy
                        ? null
                        : _retryOpeningReferenceImageJob,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Tentar abrir o Codex novamente'),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('${references.length} fichas'),
                  if (missingImageCount > 0)
                    _pill('$missingImageCount sem imagem', AppColors.warning),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (references.isEmpty)
          _panel(
            title: 'Ainda não gerado',
            icon: Icons.image_not_supported_outlined,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  emptyLabel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          sheetFamily == 'characters'
              ? _buildCharacterBible(references)
              : LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final cardWidth =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: references
                    .map(
                      (reference) => SizedBox(
                        width: cardWidth,
                        child: _buildReferenceCard(
                          reference,
                          gallery: references,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildReferenceRegenerateActions({
    required String sheetFamily,
    required int missingImageCount,
  }) {
    final busy = _isAnyGenerationBusy || _isReferenceImageBusy;
    final familyNoun = switch (sheetFamily) {
      'characters' => 'personagens',
      'locations' => 'ambientes',
      'props' => 'adereços',
      _ => 'fichas',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (sheetFamily != 'all')
              _referenceCombinedActionButton(
                emphasized: true,
                busy: busy,
                icon: Icons.auto_awesome,
                title: 'Todos os $familyNoun',
                subtitle: 'Escolha fichas, imagens ou os dois',
                onPressed: () => _generateSheetsThenImagesWithCodex(
                  family: sheetFamily,
                ),
              ),
            _referenceCombinedActionButton(
              emphasized: sheetFamily == 'all',
              busy: busy,
              icon: Icons.collections_bookmark_outlined,
              title: 'Obra inteira',
              subtitle: 'Escolha fichas, imagens ou os dois',
              onPressed: () =>
                  _generateSheetsThenImagesWithCodex(family: 'all'),
            ),
            if (missingImageCount > 0)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _generateReferenceImagesWithCodex(
                        family: sheetFamily,
                      ),
                icon: _isReferenceImageBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _isReferenceImageBusy
                      ? 'Codex · $_activeReferenceImageProgress%'
                      : _referenceImageRetryAvailable
                      ? 'Tentar imagens faltantes ($missingImageCount)'
                      : 'Só imagens faltantes ($missingImageCount)',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _referenceCombinedActionButton({
    required bool emphasized,
    required bool busy,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: emphasized
                ? Colors.white.withAlpha(210)
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
    if (emphasized) {
      return FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: label,
      );
    }
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: label,
    );
  }

  Widget _buildReferenceCard(
    ProductionReferenceItem reference, {
    List<ProductionReferenceItem>? gallery,
  }) {
    final isGenerating = _referenceImageIdsInProgress.contains(reference.id);
    final canGenerate =
        LocalProductionWorkspaceService.isStoryMasterReference(reference);
    final hasImage = LocalProductionWorkspaceService.referenceHasGeneratedImage(
      reference,
    );
    final usage = _project!.episodes
        .expand((episode) => episode.takes)
        .where((take) => take.referenceIds.contains(reference.id))
        .length;
    final metadata = reference.metadata;
    final role = metadata['role']?.toString();
    final traits =
        (metadata['personality'] as List<dynamic>? ??
                metadata['permanent_elements'] as List<dynamic>? ??
                const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .where((item) => !item.trim().startsWith('{'))
            .take(4)
            .toList();
    final summary = _workspaceService.referenceDisplayDescription(
      _project!,
      reference,
    );
    final storyNote = reference.storyNote;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reference.canonical
              ? AppColors.primary.withAlpha(110)
              : AppColors.surfaceLighter,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _referencePreview(
                  reference,
                  gallery: gallery,
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xC9000000)],
                      ),
                    ),
                  ),
                ),
                if (reference.canonical)
                  Positioned(
                    top: 9,
                    left: 9,
                    child: IgnorePointer(
                      child: _pill('MASTER', AppColors.primaryLight),
                    ),
                  ),
                if (hasImage)
                  const Positioned(
                    top: 9,
                    right: 9,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x99000000),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.zoom_in,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isGenerating)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withAlpha(120),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: IgnorePointer(
                    child: Text(
                      reference.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(_referenceCategoryLabel(reference.category)),
                    if (role?.trim().isNotEmpty == true) _pill(role!),
                    _pill('$usage beats'),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  reference.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.isNotEmpty
                      ? summary
                      : 'Sem descrição textual nesta ficha.',
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: summary.isNotEmpty
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                if (traits.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: traits.map(_referenceTag).toList(),
                  ),
                ],
                if (storyNote.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      storyNote,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, height: 1.35),
                    ),
                  ),
                ],
                if (reference.publicUrl?.isNotEmpty != true &&
                    reference.assetPath?.isNotEmpty != true) ...[
                  const SizedBox(height: 12),
                  Text(
                    isGenerating
                        ? 'O Codex está gerando esta imagem e a enviará automaticamente.'
                        : 'Imagem pendente. Gere no Codex ou anexe uma referência local.',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
                if (canGenerate) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isAnyGenerationBusy
                            ? null
                            : () => _generateStorySheetsWithCodex(
                                family:
                                    LocalProductionWorkspaceService.storySheetFamilyOf(
                                      reference,
                                    ),
                                regenerate: true,
                                reference: reference,
                              ),
                        icon: const Icon(Icons.description_outlined, size: 17),
                        label: const Text('Gerar ficha novamente'),
                      ),
                      const SizedBox(height: 8),
                      hasImage
                          ? OutlinedButton.icon(
                              onPressed:
                                  _isAnyGenerationBusy || _isReferenceImageBusy
                                  ? null
                                  : () => _generateReferenceImagesWithCodex(
                                      reference: reference,
                                      regenerateExisting: true,
                                    ),
                              icon: const Icon(Icons.refresh, size: 17),
                              label: const Text('Gerar imagem novamente'),
                            )
                          : FilledButton.icon(
                              onPressed:
                                  _isAnyGenerationBusy || _isReferenceImageBusy
                                  ? null
                                  : () => _generateReferenceImagesWithCodex(
                                      reference: reference,
                                    ),
                              icon: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 17,
                              ),
                              label: Text(
                                isGenerating
                                    ? 'Gerando imagem...'
                                    : 'Gerar imagem',
                              ),
                            ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _referencePreview(
    ProductionReferenceItem reference, {
    bool openOnTap = true,
    List<ProductionReferenceItem>? gallery,
  }) {
    Widget preview;
    if (reference.assetPath?.isNotEmpty == true) {
      preview = Image.asset(
        reference.assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _referenceFallback(reference),
      );
    } else if (reference.publicUrl?.isNotEmpty == true) {
      preview = CachedNetworkImage(
        imageUrl: _resolveProductionMediaUrl(reference.publicUrl!),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _referenceFallback(reference),
      );
    } else {
      preview = _referenceFallback(reference);
    }
    if (!openOnTap ||
        !LocalProductionWorkspaceService.referenceHasGeneratedImage(
          reference,
        )) {
      return preview;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openReferenceFullscreen(reference, gallery: gallery),
        child: preview,
      ),
    );
  }

  FullscreenImageSource _fullscreenImageSourceFromReference(
    ProductionReferenceItem reference,
  ) {
    final publicUrl = reference.publicUrl?.trim();
    return FullscreenImageSource(
      title: reference.label,
      subtitle: _referenceCategoryLabel(reference.category),
      assetPath: reference.assetPath,
      networkUrl: publicUrl == null || publicUrl.isEmpty
          ? null
          : _resolveProductionMediaUrl(publicUrl),
    );
  }

  Future<void> _openReferenceFullscreen(
    ProductionReferenceItem reference, {
    List<ProductionReferenceItem>? gallery,
  }) {
    final items =
        (gallery ?? _project?.references ?? const <ProductionReferenceItem>[])
            .where(LocalProductionWorkspaceService.referenceHasGeneratedImage)
            .toList();
    if (items.isEmpty) {
      items.add(reference);
    }
    var index = items.indexWhere((item) => item.id == reference.id);
    if (index < 0) {
      items.insert(0, reference);
      index = 0;
    }
    return showFullscreenImageViewer(
      context,
      images: items.map(_fullscreenImageSourceFromReference).toList(),
      initialIndex: index,
    );
  }

  Widget _referenceFallback(ProductionReferenceItem reference) {
    final isLocation =
        reference.category.contains('LOCATION') ||
        reference.category.contains('ENVIRONMENT');
    final isProp =
        reference.category.contains('PROP') ||
        reference.category.contains('OBJECT');
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25395C), AppColors.surfaceLight],
        ),
      ),
      child: Center(
        child: Icon(
          isLocation
              ? Icons.landscape_outlined
              : isProp
              ? Icons.inventory_2_outlined
              : Icons.person_outline,
          color: AppColors.primaryLight,
          size: 34,
        ),
      ),
    );
  }

  String _referenceCategoryLabel(String category) {
    if (category.contains('CHARACTER') || category.contains('OPPOSING_FORCE')) {
      return 'Personagem';
    }
    if (category.contains('LOCATION') ||
        category.contains('ENVIRONMENT') ||
        category.contains('WORLD')) {
      return 'Ambiente';
    }
    if (category.contains('PROP') || category.contains('OBJECT')) {
      return 'Adereço';
    }
    if (category.contains('CONTINUITY')) return 'Continuidade';
    if (category.contains('FRAME')) return 'Frame';
    return category.replaceAll('_', ' ').toLowerCase();
  }

  Widget _referenceTag(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withAlpha(24),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.primary.withAlpha(55)),
    ),
    child: Text(
      value,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
    ),
  );

  Future<void> _showAddReferenceDialog({
    String initialCategory = 'CHARACTER_REFERENCE',
  }) async {
    final labelController = TextEditingController();
    final pathController = TextEditingController();
    final descriptionController = TextEditingController();
    var category = initialCategory;
    var canonical = true;
    final reference = await showDialog<ProductionReferenceItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar referencia local'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(
                        value: 'CHARACTER_REFERENCE',
                        child: Text('Identidade de personagem'),
                      ),
                      DropdownMenuItem(
                        value: 'LOCATION_MASTER',
                        child: Text('Master de local'),
                      ),
                      DropdownMenuItem(
                        value: 'WORLD_ENVIRONMENT_MASTER',
                        child: Text('Master de mundo'),
                      ),
                      DropdownMenuItem(
                        value: 'OBJECT_REFERENCE',
                        child: Text('Objeto / prop'),
                      ),
                      DropdownMenuItem(
                        value: 'TRANSITION_FRAME',
                        child: Text('Frame de transicao'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pathController,
                    decoration: const InputDecoration(
                      labelText: 'URL publica ou caminho de asset Flutter',
                      helperText:
                          'Caminhos locais precisam estar incluidos no build web.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Contrato visual / observacoes',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: canonical,
                    onChanged: (value) {
                      setDialogState(() => canonical = value);
                    },
                    title: const Text('Referencia canonica'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelController.text.trim();
                if (label.isEmpty) return;
                final path = pathController.text.trim();
                Navigator.pop(
                  dialogContext,
                  ProductionReferenceItem(
                    id: 'ref-${DateTime.now().microsecondsSinceEpoch}',
                    label: label,
                    category: category,
                    assetPath: path.isNotEmpty && !path.startsWith('http')
                        ? path
                        : null,
                    publicUrl: path.startsWith('http') ? path : null,
                    description: descriptionController.text.trim(),
                    canonical: canonical,
                  ),
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
    pathController.dispose();
    descriptionController.dispose();
    if (reference == null || !mounted) return;
    final project = _project!;
    setState(
      () => _project = project.copyWith(
        references: [...project.references, reference],
      ),
    );
    _schedulePersist();
  }
}
