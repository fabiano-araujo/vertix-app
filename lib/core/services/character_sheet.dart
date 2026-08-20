const appearanceFieldSpecs = <({String key, List<String> aliases, String label})>[
  (
    key: 'height_cm',
    aliases: ['height_cm', 'height', 'altura'],
    label: 'Altura',
  ),
  (
    key: 'head_body_ratio',
    aliases: [
      'head_body_ratio',
      'head-body-ratio',
      'proporcao_cabeca_corpo',
      'proporção cabeça-corpo',
      'proporcao cabeca-corpo',
    ],
    label: 'Proporção cabeça-corpo',
  ),
  (
    key: 'ethnicity',
    aliases: ['ethnicity', 'etnia', 'origin', 'origem', 'ancestry'],
    label: 'Etnia',
  ),
  (
    key: 'build',
    aliases: ['build', 'compleicao', 'compleição', 'body'],
    label: 'Compleição',
  ),
  (
    key: 'hair',
    aliases: ['hair', 'cabelo', 'hairstyle'],
    label: 'Cabelo',
  ),
  (
    key: 'facial_features',
    aliases: [
      'facial_features',
      'face',
      'tracos_faciais',
      'traços faciais',
      'tracos faciais',
    ],
    label: 'Traços faciais',
  ),
  (
    key: 'clothing',
    aliases: [
      'clothing',
      'wardrobe',
      'outfit',
      'roupa',
      'roupa e adereços',
      'roupa e aderecos',
    ],
    label: 'Roupa e adereços',
  ),
];

bool isCharacterLookCategory(String category) {
  final value = category.toUpperCase();
  return value.contains('LOOK') ||
      value.contains('OUTFIT') ||
      value.contains('VARIANT');
}

bool isCharacterLookReference({
  required String category,
  Map<String, dynamic>? metadata,
}) {
  if (isCharacterLookCategory(category)) return true;
  final parent = metadata?['parent_character_id'] ?? metadata?['parentId'];
  return parent != null && parent.toString().trim().isNotEmpty;
}

bool isCharacterIdentityCategory(String category) {
  final value = category.toUpperCase();
  if (isCharacterLookCategory(value)) return false;
  return value.contains('CHARACTER') || value.contains('OPPOSING_FORCE');
}

String _cleanSheetText(dynamic value) {
  if (value == null) return '';
  if (value is Map || value is Iterable) return '';
  return value.toString().trim();
}

String _normalizeSheetKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

String _formatHeight(dynamic value) {
  if (value is num) return '${value.round()}cm';
  final text = _cleanSheetText(value);
  if (text.isEmpty) return '';
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return '${text}cm';
  return text;
}

Map<String, String> appearanceCardFields(
  dynamic appearance, {
  dynamic card,
}) {
  final fields = <String, String>{};

  void assign(String key, dynamic value, {bool overwrite = false}) {
    var text = key == 'height_cm'
        ? _formatHeight(value)
        : _cleanSheetText(value);
    if (text.isEmpty) return;
    if (!overwrite && (fields[key]?.isNotEmpty ?? false)) return;
    fields[key] = text;
  }

  void absorbMap(dynamic value, {bool overwrite = false}) {
    if (value is! Map) return;
    final map = Map<dynamic, dynamic>.from(value);
    for (final spec in appearanceFieldSpecs) {
      for (final entry in map.entries) {
        final entryKey = _normalizeSheetKey(entry.key.toString());
        if (spec.aliases.any(
          (alias) => _normalizeSheetKey(alias) == entryKey,
        )) {
          assign(spec.key, entry.value, overwrite: overwrite);
        }
      }
    }
  }

  void absorbLabeledString(String text, {bool overwrite = false}) {
    if (text.trim().isEmpty) return;
    final labeled = <String, String>{};
    final pattern = RegExp(
      r'(Altura|Propor[cç][aã]o cabe[cç]a-corpo|Etnia|Origem|Complei[cç][aã]o|Cabelo|Tra[cç]os faciais|Roupa e adere[cç]os|Roupa)\s*:\s*',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(text).toList();
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : text.length;
      final label = match.group(1) ?? '';
      var body = text.substring(match.end, end).trim();
      if (body.endsWith('.')) body = body.substring(0, body.length - 1).trim();
      if (body.isEmpty) continue;
      for (final spec in appearanceFieldSpecs) {
        if (_normalizeSheetKey(spec.label) == _normalizeSheetKey(label) ||
            (spec.key == 'ethnicity' &&
                _normalizeSheetKey(label) == 'origem')) {
          labeled[spec.key] = spec.key == 'height_cm'
              ? _formatHeight(body)
              : body;
        }
      }
    }
    for (final entry in labeled.entries) {
      assign(entry.key, entry.value, overwrite: overwrite);
    }
  }

  absorbMap(card, overwrite: true);
  absorbMap(appearance, overwrite: fields.isEmpty);
  if (appearance is String) {
    absorbLabeledString(appearance, overwrite: false);
  }
  return fields;
}

String formatCharacterAppearance(
  dynamic appearance, {
  dynamic card,
}) {
  final fields = appearanceCardFields(appearance, card: card);
  if (fields.isNotEmpty) {
    return appearanceFieldSpecs
        .where((spec) => (fields[spec.key] ?? '').isNotEmpty)
        .map((spec) => '${spec.label}: ${fields[spec.key]}')
        .join('\n');
  }
  if (appearance is String) return appearance.trim();
  return '';
}

String identityAppearanceWithoutClothing(
  dynamic appearance, {
  dynamic card,
}) {
  final fields = Map<String, String>.from(
    appearanceCardFields(appearance, card: card),
  )..remove('clothing');
  if (fields.isEmpty) {
    return formatCharacterAppearance(appearance, card: card);
  }
  return appearanceFieldSpecs
      .where((spec) => (fields[spec.key] ?? '').isNotEmpty)
      .map((spec) => '${spec.label}: ${fields[spec.key]}')
      .join('\n');
}

String slugCharacterLookId(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'look' : slug;
}

bool _lookIsDefault(Map<String, dynamic> look) {
  final kind = (look['kind'] ?? look['type'] ?? '').toString().toLowerCase();
  if (kind == 'default' || kind == 'identity' || kind == 'principal') {
    return true;
  }
  if (look['primary'] == true) return true;
  final id = (look['id'] ?? '').toString().toLowerCase();
  if (id == 'default' || id == 'principal') return true;
  final label = (look['label'] ?? look['name'] ?? '').toString().toLowerCase();
  return label.contains('aparência padrão') ||
      label.contains('aparencia padrao') ||
      label == 'padrão' ||
      label == 'padrao';
}

String characterLookReferenceId(String characterId, Map<String, dynamic> look) {
  final lookId = (look['id'] ?? slugCharacterLookId(
    (look['label'] ?? look['name'] ?? 'visual').toString(),
  )).toString();
  return '$characterId-look-$lookId';
}

String defaultLookWardrobe(Map<String, dynamic> character) {
  final card = appearanceCardFields(
    character['appearance'],
    card: character['appearance_card'],
  );
  for (final key in ['clothing', 'wardrobe', 'outfit_lock']) {
    final value = _cleanSheetText(character[key]);
    if (value.isNotEmpty) return value;
  }
  return card['clothing'] ?? '';
}

List<Map<String, dynamic>> normalizeCharacterLooks(
  Map<String, dynamic> character,
) {
  final raw = character['looks'];
  final parsed = <Map<String, dynamic>>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        final look = Map<String, dynamic>.from(item);
        final label = (look['label'] ?? look['name'] ?? '').toString().trim();
        if (label.isEmpty && (look['wardrobe'] ?? '').toString().trim().isEmpty) {
          continue;
        }
        parsed.add(look);
      } else {
        final label = item.toString().trim();
        if (label.isEmpty) continue;
        parsed.add({'label': label});
      }
    }
  }

  Map<String, dynamic> withDefaults(Map<String, dynamic> look) {
    final label = (look['label'] ?? look['name'] ?? 'Visual').toString().trim();
    final isDefault = _lookIsDefault(look);
    final id = isDefault
        ? 'default'
        : (look['id']?.toString().trim().isNotEmpty == true
              ? look['id'].toString().trim()
              : slugCharacterLookId(label));
    final wardrobeRaw = _cleanSheetText(look['wardrobe'] ?? look['clothing']);
    final wardrobe = wardrobeRaw.isNotEmpty
        ? wardrobeRaw
        : (isDefault ? defaultLookWardrobe(character) : '');
    final prompt = _cleanSheetText(look['prompt']);
    return {
      ...look,
      'id': id,
      'label': isDefault
          ? (label.toLowerCase().contains('padrão') ||
                    label.toLowerCase().contains('padrao')
                ? label
                : 'Aparência padrão')
          : label,
      'kind': isDefault ? 'default' : (look['kind'] ?? 'wardrobe'),
      'primary': isDefault,
      if (wardrobe.isNotEmpty) 'wardrobe': wardrobe,
      if (!isDefault)
        'prompt': prompt.isNotEmpty
            ? prompt
            : (wardrobe.isEmpty
                  ? 'Keep the character from image 1 unchanged. Change the outfit to:'
                  : 'Keep the character from image 1 unchanged. Change the outfit to: $wardrobe'),
    };
  }

  final normalized = parsed.map(withDefaults).toList();
  final defaultIndex = normalized.indexWhere(_lookIsDefault);
  if (defaultIndex < 0) {
    normalized.insert(0, withDefaults({
      'id': 'default',
      'label': 'Aparência padrão',
      'kind': 'default',
      'primary': true,
      'wardrobe': defaultLookWardrobe(character),
    }));
  } else if (defaultIndex > 0) {
    final defaultLook = normalized.removeAt(defaultIndex);
    normalized.insert(0, defaultLook);
  }

  final seen = <String>{};
  return [
    for (final look in normalized)
      if (seen.add((look['id'] ?? '').toString())) look,
  ];
}

Map<String, dynamic> characterLookReferenceJson({
  required Map<String, dynamic> character,
  required Map<String, dynamic> look,
}) {
  final characterId = (character['reference_id'] ?? character['id'] ?? '')
      .toString()
      .trim();
  final name = (character['name'] ?? character['label'] ?? characterId)
      .toString()
      .trim();
  final lookLabel = (look['label'] ?? 'visual').toString().trim();
  final wardrobe = _cleanSheetText(look['wardrobe']);
  final prompt = _cleanSheetText(look['prompt']);
  final identity = identityAppearanceWithoutClothing(
    character['appearance'],
    card: character['appearance_card'],
  );
  return {
    'id': characterLookReferenceId(characterId, look),
    'label': '$name-$lookLabel',
    'category': 'CHARACTER_LOOK',
    'description': prompt.isNotEmpty
        ? prompt
        : 'Keep the character from image 1 unchanged. Change the outfit to: $wardrobe',
    'canonical': true,
    'metadata': {
      'parent_character_id': characterId,
      'look_id': look['id'],
      'look_kind': look['kind'] ?? 'wardrobe',
      'needed_because': look['needed_because'],
      'wardrobe': wardrobe,
      'outfit_lock': wardrobe,
      'prompt': prompt,
      'role': character['role'],
      'name': name,
      'appearance': identity,
      'appearance_card': character['appearance_card'],
      'personality': character['personality'],
    },
  };
}

const _lookStopwords = {
  'aparencia',
  'aparência',
  'padrao',
  'padrão',
  'visual',
  'look',
  'default',
  'wardrobe',
  'roupa',
  'traje',
  'com',
  'para',
  'pelo',
  'pela',
  'uma',
  'uns',
  'das',
  'dos',
  'the',
  'and',
  'for',
  'from',
  'fora',
  'servico',
  'serviço',
};

const _lookCueGroups = <List<String>>[
  ['casa', 'home', 'intimo', 'íntimo', 'casual', 'domestico', 'doméstico'],
  ['jantar', 'dinner', 'gala', 'formal', 'cerimonia', 'cerimônia'],
  ['escola', 'school', 'uniforme', 'aula', 'colegio', 'colégio'],
  ['trabalho', 'work', 'escritorio', 'escritório', 'reuniao', 'reunião'],
  ['cozinha', 'chef', 'restaurante', 'kitchen'],
  ['hospital', 'clinica', 'clínica', 'medico', 'médico'],
  ['luto', 'funeral', 'mourning'],
];

String _normalizeLookHaystack(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9à-ü\s-]+'), ' ');
}

Iterable<String> _lookTokens(String value) sync* {
  for (final raw in _normalizeLookHaystack(value).split(RegExp(r'[\s/_-]+'))) {
    final token = raw.trim();
    if (token.length < 4 || _lookStopwords.contains(token)) continue;
    yield token;
  }
}

String lookIdFromCastLooks(
  dynamic source, {
  required String characterId,
  required String characterName,
}) {
  if (source is Map) {
    for (final key in [
      characterId,
      characterName,
      characterId.toLowerCase(),
      characterName.toLowerCase(),
    ]) {
      final value = source[key] ?? source[key.toString()];
      final text = _cleanSheetText(value);
      if (text.isNotEmpty) return text;
    }
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (_normalizeSheetKey(key) == _normalizeSheetKey(characterId) ||
          _normalizeSheetKey(key) == _normalizeSheetKey(characterName)) {
        final text = _cleanSheetText(entry.value);
        if (text.isNotEmpty) return text;
      }
    }
  }
  if (source is List) {
    for (final item in source) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = (map['character_id'] ?? map['reference_id'] ?? map['id'] ?? '')
          .toString();
      final name = (map['name'] ?? map['character'] ?? '').toString();
      if (_normalizeSheetKey(id) == _normalizeSheetKey(characterId) ||
          _normalizeSheetKey(name) == _normalizeSheetKey(characterName)) {
        final look = _cleanSheetText(
          map['look_id'] ?? map['look'] ?? map['visual'],
        );
        if (look.isNotEmpty) return look;
      }
    }
  }
  return '';
}

String explicitSceneLookId({
  required String characterId,
  required String characterName,
  required Map<String, dynamic> scene,
  Map<String, dynamic> shot = const {},
}) {
  for (final source in [shot['cast_looks'], scene['cast_looks']]) {
    final lookId = lookIdFromCastLooks(
      source,
      characterId: characterId,
      characterName: characterName,
    );
    if (lookId.isNotEmpty) return lookId;
  }
  return '';
}

int _lookCueOverlap(String left, String right) {
  final a = _normalizeLookHaystack(left);
  final b = _normalizeLookHaystack(right);
  var score = 0;
  for (final group in _lookCueGroups) {
    final leftHit = group.any((cue) => a.contains(cue));
    final rightHit = group.any((cue) => b.contains(cue));
    if (leftHit && rightHit) score += 3;
  }
  return score;
}

int scoreLookAgainstScene(Map<String, dynamic> look, String haystack) {
  if (_lookIsDefault(look)) return 0;
  final lookText = [
    look['id'],
    look['label'],
    look['wardrobe'],
  ].map(_cleanSheetText).where((item) => item.isNotEmpty).join(' ');
  var score = _lookCueOverlap(lookText, haystack);
  final haystackTokens = _lookTokens(haystack).toSet();
  for (final token in _lookTokens(lookText)) {
    if (haystackTokens.contains(token) ||
        _normalizeLookHaystack(haystack).contains(token)) {
      score += 2;
    }
  }
  return score;
}

String resolveSceneCharacterLookId({
  required Map<String, dynamic> character,
  required String haystack,
  String explicitLookId = '',
}) {
  final looks = normalizeCharacterLooks(character);
  Map<String, dynamic>? matchLook(String raw) {
    final wanted = raw.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final look in looks) {
      final id = (look['id'] ?? '').toString().toLowerCase();
      final label = (look['label'] ?? '').toString().toLowerCase();
      if (id == wanted ||
          label == wanted ||
          slugCharacterLookId(label) == slugCharacterLookId(raw)) {
        return look;
      }
    }
    return null;
  }

  final explicit = matchLook(explicitLookId);
  if (explicit != null) {
    return (explicit['id'] ?? 'default').toString();
  }

  var bestId = 'default';
  var bestScore = 0;
  for (final look in looks) {
    final score = scoreLookAgainstScene(look, haystack);
    if (score > bestScore) {
      bestScore = score;
      bestId = (look['id'] ?? 'default').toString();
    }
  }
  return bestScore >= 3 ? bestId : 'default';
}
