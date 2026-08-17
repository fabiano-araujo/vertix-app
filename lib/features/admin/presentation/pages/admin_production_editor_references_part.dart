part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorReferencesExtension
    on _AdminProductionEditorPageState {
  Widget _buildReferences({
    Set<String>? categories,
    String title = 'Pacote visual canônico',
    String description =
        'Identidades, locais, objetos e frames formam contratos visuais separados. Preserve os masters canônicos durante toda a produção.',
    String emptyLabel =
        'Adicione identidades, locais, objetos ou frames de continuidade.',
    String addLabel = 'Adicionar referência',
    String initialCategory = 'CHARACTER_REFERENCE',
  }) {
    final project = _project!;
    final references = categories == null
        ? project.references
        : project.references
              .where((reference) => categories.contains(reference.category))
              .toList();
    final byCategory = <String, int>{};
    for (final reference in references) {
      byCategory.update(
        reference.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return ListView(
      key: PageStorageKey('production-references-$title'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: title,
          icon: Icons.collections_bookmark_outlined,
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isAnyGenerationBusy
                    ? null
                    : _showAutomaticPreparationDialog,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Gerar fichas com Codex'),
              ),
              FilledButton.icon(
                onPressed: _isAnyGenerationBusy
                    ? null
                    : () => _showAddReferenceDialog(
                        initialCategory: initialCategory,
                      ),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(addLabel),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('${references.length} fichas'),
                  _pill(
                    '${references.where((item) => item.canonical).length} canônicas',
                    AppColors.success,
                  ),
                  ...byCategory.entries.map(
                    (entry) => _pill(
                      '${entry.value} ${_referenceCategoryLabel(entry.key)}',
                    ),
                  ),
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
          LayoutBuilder(
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
                        child: _buildReferenceCard(reference),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildReferenceCard(ProductionReferenceItem reference) {
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
            .take(4)
            .toList();
    final storyFunction =
        metadata['dramatic_function']?.toString() ??
        metadata['story_function']?.toString() ??
        metadata['visual_contract']?.toString();
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
                _referencePreview(reference),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xC9000000)],
                    ),
                  ),
                ),
                if (reference.canonical)
                  Positioned(
                    top: 9,
                    left: 9,
                    child: _pill('MASTER', AppColors.primaryLight),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
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
                if (reference.description.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    reference.description,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
                if (traits.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: traits.map(_referenceTag).toList(),
                  ),
                ],
                if (storyFunction?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      storyFunction!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, height: 1.35),
                    ),
                  ),
                ],
                if (reference.publicUrl?.isNotEmpty != true &&
                    reference.assetPath?.isNotEmpty != true) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Imagem não gerada automaticamente. Anexe uma referência quando quiser.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _referencePreview(ProductionReferenceItem reference) {
    if (reference.assetPath?.isNotEmpty == true) {
      return Image.asset(
        reference.assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _referenceFallback(reference),
      );
    }
    if (reference.publicUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: _resolveProductionMediaUrl(reference.publicUrl!),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _referenceFallback(reference),
      );
    }
    return _referenceFallback(reference);
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
  }
}
