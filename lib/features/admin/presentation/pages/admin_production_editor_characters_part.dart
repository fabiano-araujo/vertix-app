part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorCharactersExtension
    on _AdminProductionEditorPageState {
  List<ProductionReferenceItem> _characterIdentities(
    List<ProductionReferenceItem> references,
  ) {
    return references
        .where(LocalProductionWorkspaceService.isCharacterIdentityItem)
        .toList();
  }

  Map<String, dynamic> _characterEntry(ProductionReferenceItem identity) {
    final fromBible = _workspaceService.characterSheetEntry(
      _project!,
      identity.id,
    );
    return {
      ...identity.metadata,
      ...fromBible,
      'reference_id': identity.id,
      'name': fromBible['name'] ?? identity.label,
    };
  }

  Widget _buildCharacterBible(List<ProductionReferenceItem> references) {
    final identities = _characterIdentities(references);
    if (identities.isEmpty) {
      return _panel(
        title: 'Ainda não gerado',
        icon: Icons.image_not_supported_outlined,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Nenhum personagem foi definido para esta obra.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    final selectedId = identities.any((item) => item.id == _selectedCharacterId)
        ? _selectedCharacterId!
        : identities.first.id;
    final identity = identities.firstWhere((item) => item.id == selectedId);
    final character = _characterEntry(identity);
    final looks = normalizeCharacterLooks(character);
    final selectedLookId = looks.any((look) => look['id'] == _selectedLookId)
        ? _selectedLookId!
        : (looks.first['id']?.toString() ?? 'default');
    final selectedLook = looks.firstWhere(
      (look) => look['id'] == selectedLookId,
      orElse: () => looks.first,
    );
    final isDefaultLook =
        selectedLook['primary'] == true || selectedLook['kind'] == 'default';
    final lookReference = isDefaultLook
        ? identity
        : _lookReferenceFor(identity.id, selectedLook);
    final parentHasImage =
        LocalProductionWorkspaceService.referenceHasGeneratedImage(identity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in identities) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: item.id == selectedId,
                    label: Text(item.label),
                    onSelected: (_) => setState(() {
                      _selectedCharacterId = item.id;
                      _selectedLookId = 'default';
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: identity.label,
          icon: Icons.person_outline,
          trailing: identities.length > 1
              ? _pill('${identities.length} no elenco')
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final look in looks)
                    _lookTab(
                      characterName: identity.label,
                      look: look,
                      selected: look['id'] == selectedLookId,
                      isPrimary: look['primary'] == true,
                      onTap: () => setState(() {
                        _selectedCharacterId = selectedId;
                        _selectedLookId = look['id']?.toString();
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar visual'),
                    onPressed: () => _addCharacterLook(identity),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                identity.label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((character['role'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  character['role'].toString(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              if (!isDefaultLook) ...[
                const SizedBox(height: 12),
                Text(
                  'Edição [ ${identity.label} · ${selectedLook['label']} ]',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gere a aparência padrão primeiro; os outros trajes usarão essa imagem como referência da imagem 1.',
                  style: TextStyle(
                    color: AppColors.warning.withAlpha(230),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (isDefaultLook)
                _characterDefaultLookBody(
                  identity: identity,
                  character: character,
                  lookReference: identity,
                )
              else
                _characterVariantLookBody(
                  identity: identity,
                  look: selectedLook,
                  lookReference: lookReference,
                  parentHasImage: parentHasImage,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lookTab({
    required String characterName,
    required Map<String, dynamic> look,
    required bool selected,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final label = '$characterName-${look['label']}';
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: isPrimary
          ? Icon(
              Icons.star,
              size: 14,
              color: selected ? Colors.white : AppColors.warning,
            )
          : null,
      label: Text(isPrimary ? 'Principal · $label' : label),
    );
  }

  ProductionReferenceItem? _lookReferenceFor(
    String characterId,
    Map<String, dynamic> look,
  ) {
    final id = characterLookReferenceId(characterId, look);
    for (final item in _project!.references) {
      if (item.id == id) return item;
    }
    return null;
  }

  Widget _characterDefaultLookBody({
    required ProductionReferenceItem identity,
    required Map<String, dynamic> character,
    required ProductionReferenceItem lookReference,
  }) {
    final fields = appearanceCardFields(
      character['appearance'] ?? identity.description,
      card: character['appearance_card'],
    );
    final personality = (character['personality'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final hasImage = LocalProductionWorkspaceService.referenceHasGeneratedImage(
      lookReference,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _characterImageRow(lookReference, gallery: [lookReference]),
        const SizedBox(height: 18),
        const Text(
          'APARÊNCIA',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        if (fields.isEmpty)
          Text(
            identity.description.isNotEmpty
                ? identity.description
                : 'Sem ficha de aparência ainda. Gere a ficha para preencher altura, etnia, cabelo e figurino.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          )
        else
          ...appearanceFieldSpecs
              .where((spec) => (fields[spec.key] ?? '').isNotEmpty)
              .map(
                (spec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${spec.label}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        TextSpan(
                          text: fields[spec.key],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        if (personality.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'PERSONALIDADE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: personality.map(_referenceTag).toList(),
          ),
        ],
        const SizedBox(height: 16),
        _characterVoiceSection(identity),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isAnyGenerationBusy
                  ? null
                  : () => _generateStorySheetsWithCodex(
                      family: 'characters',
                      regenerate: true,
                      reference: identity,
                    ),
              icon: const Icon(Icons.description_outlined, size: 17),
              label: const Text('Gerar ficha novamente'),
            ),
            hasImage
                ? OutlinedButton.icon(
                    onPressed: _isAnyGenerationBusy || _isReferenceImageBusy
                        ? null
                        : () => _generateReferenceImagesWithCodex(
                            reference: identity,
                            regenerateExisting: true,
                          ),
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Gerar imagem novamente'),
                  )
                : FilledButton.icon(
                    onPressed: _isAnyGenerationBusy || _isReferenceImageBusy
                        ? null
                        : () => _generateReferenceImagesWithCodex(
                            reference: identity,
                          ),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: const Text('Gerar imagem'),
                  ),
          ],
        ),
      ],
    );
  }

  Widget _characterVariantLookBody({
    required ProductionReferenceItem identity,
    required Map<String, dynamic> look,
    required ProductionReferenceItem? lookReference,
    required bool parentHasImage,
  }) {
    final prompt = (look['prompt'] ?? '').toString().trim().isNotEmpty
        ? look['prompt'].toString()
        : 'Keep the character from image 1 unchanged. Change the outfit to: ${look['wardrobe'] ?? ''}';
    final hasImage =
        lookReference != null &&
        LocalProductionWorkspaceService.referenceHasGeneratedImage(
          lookReference,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _identitySlot(
              title: parentHasImage ? 'Imagem 1' : 'Imagem 1 pendente',
              locked: !parentHasImage,
              reference: identity,
            ),
            if (lookReference != null)
              _identitySlot(
                title: hasImage ? look['label'].toString() : 'Visual pendente',
                locked: false,
                reference: lookReference,
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: ValueKey('look-prompt-${identity.id}-${look['id']}'),
          initialValue: prompt,
          minLines: 4,
          maxLines: 8,
          onChanged: (value) => _patchCharacterLook(
            identity.id,
            look['id']?.toString() ?? '',
            {'prompt': value},
          ),
          decoration: InputDecoration(
            labelText: 'Prompt do visual',
            alignLabelWithHint: true,
            helperText: (look['needed_because'] ?? '').toString().trim().isEmpty
                ? 'O figurino muda; o rosto permanece o da aparência padrão.'
                : look['needed_because'].toString(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill('@ G-Image2', AppColors.primaryLight),
            _pill('✦ 0.8'),
          ],
        ),
        const SizedBox(height: 16),
        _characterVoiceSection(identity),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _isAnyGenerationBusy || _isReferenceImageBusy
                  ? null
                  : () => _generateCharacterLookImage(identity, look),
              icon: Icon(
                hasImage ? Icons.refresh : Icons.auto_awesome_outlined,
                size: 17,
              ),
              label: Text(
                hasImage ? 'Gerar visual novamente' : 'Gerar visual',
              ),
            ),
            if (!parentHasImage)
              _pill('Gere a aparência padrão antes', AppColors.warning),
          ],
        ),
      ],
    );
  }

  Widget _identitySlot({
    required String title,
    required bool locked,
    required ProductionReferenceItem reference,
  }) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLighter),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _referencePreview(reference, openOnTap: !locked),
                    if (locked)
                      const ColoredBox(
                        color: Color(0x66000000),
                        child: Center(
                          child: Icon(Icons.lock_outline, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _characterImageRow(
    ProductionReferenceItem reference, {
    List<ProductionReferenceItem>? gallery,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _referencePreview(reference, gallery: gallery),
      ),
    );
  }

  Widget _characterVoiceSection(ProductionReferenceItem identity) {
    final voice = (identity.metadata['voice_reference'] ??
            identity.metadata['voice_identity'])
        ?.toString()
        .trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REFERÊNCIA DE VOZ',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'A referência de voz fica na ficha do personagem. O áudio de 2–15s entra na produção de diálogo.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.graphic_eq, size: 18),
          label: Text(
            voice == null || voice.isEmpty
                ? 'Enviar áudio de referência (2-15s)'
                : 'Áudio de referência anexado',
          ),
        ),
      ],
    );
  }

  void _patchCharacterLook(
    String characterId,
    String lookId,
    Map<String, dynamic> patch,
  ) {
    final project = _project;
    if (project == null || lookId.isEmpty) return;
    final identity = project.references.firstWhere(
      (item) => item.id == characterId,
    );
    final character = _characterEntry(identity);
    final looks = [
      for (final look in normalizeCharacterLooks(character))
        if (look['id'] == lookId) {...look, ...patch} else look,
    ];
    _replaceCharacterEntry(characterId, {...character, 'looks': looks});
  }

  void _replaceCharacterEntry(
    String characterId,
    Map<String, dynamic> character,
  ) {
    final project = _project!;
    final current = _asProjectCharacterList(project);
    final next = [
      for (final item in current)
        if ((item['reference_id'] ?? item['id']) == characterId)
          character
        else
          item,
    ];
    if (!next.any((item) => (item['reference_id'] ?? item['id']) == characterId)) {
      next.add(character);
    }
    final identityIndex = project.references.indexWhere(
      (item) => item.id == characterId,
    );
    final references = project.references.toList();
    if (identityIndex >= 0) {
      references[identityIndex] = references[identityIndex].copyWith(
        metadata: {
          ...references[identityIndex].metadata,
          ...character,
        },
      );
    }
    setState(() {
      _project = project.copyWith(
        references: references,
        seriesBible: {
          ...project.seriesBible,
          'characters': next,
          'character_bible': next,
        },
      );
    });
    _schedulePersist();
  }

  List<Map<String, dynamic>> _asProjectCharacterList(ProductionProject project) {
    final fromBible = project.seriesBible['characters'] ??
        project.seriesBible['character_bible'];
    if (fromBible is! List) return const [];
    return fromBible
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _addCharacterLook(ProductionReferenceItem identity) async {
    final labelController = TextEditingController();
    final wardrobeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar visual'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome do visual',
                  hintText: 'jantar de trabalho, uniforme escolar…',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wardrobeController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Roupa deste visual',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    final label = labelController.text.trim();
    final wardrobe = wardrobeController.text.trim();
    labelController.dispose();
    wardrobeController.dispose();
    if (confirmed != true || label.isEmpty || !mounted) return;
    final character = _characterEntry(identity);
    final looks = normalizeCharacterLooks(character);
    final look = {
      'id': slugCharacterLookId(label),
      'label': label,
      'kind': 'wardrobe',
      'needed_because': 'adicionado na ficha',
      'wardrobe': wardrobe,
      'prompt': wardrobe.isEmpty
          ? 'Keep the character from image 1 unchanged. Change the outfit to:'
          : 'Keep the character from image 1 unchanged. Change the outfit to: $wardrobe',
    };
    looks.add(look);
    _replaceCharacterEntry(identity.id, {...character, 'looks': looks});
    final synced = _workspaceService.syncCharacterLookReferences(
      _project!,
      onlyCharacterId: identity.id,
    );
    setState(() {
      _project = synced;
      _selectedCharacterId = identity.id;
      _selectedLookId = look['id']?.toString();
    });
    _schedulePersist();
  }

  Future<void> _generateCharacterLookImage(
    ProductionReferenceItem identity,
    Map<String, dynamic> look,
  ) async {
    if (!LocalProductionWorkspaceService.referenceHasGeneratedImage(identity)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gere primeiro a aparência padrão. Os outros visuais usam essa imagem como referência 1.',
          ),
        ),
      );
      return;
    }
    var project = _workspaceService.syncCharacterLookReferences(
      _project!,
      onlyCharacterId: identity.id,
    );
    setState(() => _project = project);
    final lookRef = _lookReferenceFor(identity.id, look);
    if (lookRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível criar o visual.')),
      );
      return;
    }
    await _generateReferenceImagesWithCodex(
      reference: lookRef,
      regenerateExisting:
          LocalProductionWorkspaceService.referenceHasGeneratedImage(lookRef),
    );
  }
}
