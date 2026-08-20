import 'local_production_workspace_service.dart';

class MicroDramaThemeComposer {
  const MicroDramaThemeComposer._();

  static const genreOptions = [
    'Romance com reviravolta',
    'Drama de vingança',
    'Segredos de família',
    'Suspense e mistério',
    'Fantasia urbana',
    'Drama médico',
    'Legal / crime',
    'Comédia leve',
  ];

  static const backgroundOptions = [
    'Cidade moderna',
    'Mansão de luxo',
    'Escritório corporativo',
    'Campus universitário',
    'Hospital',
    'Tribunal',
    'Cidade pequena',
    'Reino sobrenatural',
  ];

  static const tropeOptions = [
    'Segunda chance',
    'Casamento por contrato',
    'Bebê secreto',
    'Identidade oculta',
    'De inimigos a amantes',
    'Retorno vingativo',
    'Amor proibido',
    'Família escolhida',
  ];

  static const visualStyleOptions = [
    'Microdrama moderno',
    'Cinema teatral realista',
    'K-drama moderno',
    'Noir urbano',
    'Animação cinematográfica',
  ];

  static const liveActionStyles = [
    'Microdrama moderno',
    'Cinema teatral realista',
    'K-drama moderno',
    'Noir urbano',
  ];

  static MicroDramaProjectConfig compose({
    required String idea,
    required String genre,
    required String background,
    required String trope,
    required String visualStyle,
    required String language,
    required String rating,
    required int episodeCount,
    required int firstEpisodeDurationSeconds,
    required int episodeDurationSeconds,
    int maxShotDurationSeconds = 10,
    bool automaticReview = true,
    bool automaticPreparation = false,
    String videoGenerationPresetId = '',
  }) {
    final seed =
        idea.hashCode ^ genre.hashCode ^ background.hashCode ^ trope.hashCode;
    final names = _names(language, seed);
    final protagonist = names.$1;
    final opposing = names.$2;
    final title = _title(idea: idea, trope: trope, language: language);
    final presetId = videoGenerationPresetId.trim();
    final resolvedMax = presetId.isNotEmpty
        ? VideoGenerationPreset.byId(presetId).maxShotDurationSeconds
        : maxShotDurationSeconds;
    return MicroDramaProjectConfig(
      title: title,
      logline: _logline(
        language: language,
        protagonist: protagonist,
        opposing: opposing,
        genre: genre,
        background: background,
        trope: trope,
        idea: idea,
      ),
      centralQuestion: _centralQuestion(
        language: language,
        protagonist: protagonist,
        opposing: opposing,
        trope: trope,
      ),
      protagonist: protagonist,
      opposingForce: opposing,
      stakes: _stakes(
        language: language,
        background: background,
        trope: trope,
        episodeCount: episodeCount,
      ),
      genre: genre,
      background: background,
      trope: trope,
      visualStyle: visualStyle,
      language: language,
      rating: rating,
      episodeCount: episodeCount,
      firstEpisodeDurationSeconds: firstEpisodeDurationSeconds,
      episodeDurationSeconds: episodeDurationSeconds,
      maxShotDurationSeconds: resolvedMax,
      automaticReview: automaticReview,
      automaticPreparation: automaticPreparation,
      videoGenerationPresetId: presetId,
    );
  }

  static (String, String) _names(String language, int seed) {
    final pairs = switch (_languageKey(language)) {
      'en' => const [
        ('Mara Quinn', 'Julian Voss'),
        ('Elena Hart', 'Victor Hale'),
        ('Noah Blake', 'Helena Crowe'),
        ('Lina Park', 'Adrian Cole'),
        ('Sofia Reed', 'Marcus Vane'),
      ],
      'es' => const [
        ('Mara Vidal', 'Julián Voss'),
        ('Elena Cruz', 'Víctor Hale'),
        ('Noa Blake', 'Helena Crowe'),
        ('Lina Park', 'Adrián Cole'),
        ('Sofía Ríos', 'Marcos Vane'),
      ],
      _ => const [
        ('Mara Vidal', 'Caio Voss'),
        ('Helena Cruz', 'Vicente Hale'),
        ('Lara Bennett', 'André Crowe'),
        ('Marina Dias', 'Rafael Cole'),
        ('Sofia Rios', 'Ícaro Vane'),
      ],
    };
    return pairs[seed.abs() % pairs.length];
  }

  static String _title({
    required String idea,
    required String trope,
    required String language,
  }) {
    final firstLine = idea.trim().split(RegExp(r'[\n.?!]')).first.trim();
    if (firstLine.length >= 3 &&
        firstLine.length <= 42 &&
        !_looksLikePremise(firstLine)) {
      return firstLine;
    }
    return switch ((_languageKey(language), trope)) {
      ('en', 'Casamento por contrato') => 'The Contract',
      ('en', 'Bebê secreto') => 'The Hidden Child',
      ('en', 'Identidade oculta') => 'The Other Name',
      ('en', 'De inimigos a amantes') => 'Enemy Terms',
      ('en', 'Retorno vingativo') => 'The Return',
      ('en', 'Amor proibido') => 'Forbidden Line',
      ('en', 'Família escolhida') => 'Chosen House',
      ('en', _) => 'Second Chance',
      ('es', 'Casamento por contrato') => 'El contrato',
      ('es', 'Bebê secreto') => 'El hijo oculto',
      ('es', 'Identidade oculta') => 'El otro nombre',
      ('es', 'De inimigos a amantes') => 'Términos de guerra',
      ('es', 'Retorno vingativo') => 'La vuelta',
      ('es', 'Amor proibido') => 'Línea prohibida',
      ('es', 'Família escolhida') => 'Casa elegida',
      ('es', _) => 'Segunda oportunidad',
      (_, 'Casamento por contrato') => 'O contrato',
      (_, 'Bebê secreto') => 'O filho oculto',
      (_, 'Identidade oculta') => 'O outro nome',
      (_, 'De inimigos a amantes') => 'Termos de guerra',
      (_, 'Retorno vingativo') => 'A volta',
      (_, 'Amor proibido') => 'Linha proibida',
      (_, 'Família escolhida') => 'Casa escolhida',
      _ => 'Segunda chance',
    };
  }

  static bool _looksLikePremise(String value) {
    final lower = value.toLowerCase();
    if (value.trim().split(RegExp(r'\s+')).length == 1) return true;
    return lower.contains(' quando ') ||
        lower.contains(' que ') ||
        lower.contains(' uma ') ||
        lower.contains(' um ') ||
        lower.startsWith('a ') ||
        lower.startsWith('the ') ||
        value.split(' ').length >= 8;
  }

  static String _logline({
    required String language,
    required String protagonist,
    required String opposing,
    required String genre,
    required String background,
    required String trope,
    required String idea,
  }) {
    final premise = idea.trim();
    final setting = background.toLowerCase();
    final engine = _engine(trope, language);
    if (premise.length >= 24) {
      return switch (_languageKey(language)) {
        'en' =>
          '$protagonist is forced into $engine against $opposing in $setting. $premise The genre pressure of $genre makes every public choice irreversible.',
        'es' =>
          '$protagonist se ve forzada a $engine contra $opposing en $setting. $premise La presión de $genre vuelve irreversible cada elección pública.',
        _ =>
          '$protagonist é forçada a $engine contra $opposing em $setting. $premise A pressão de $genre torna cada escolha pública irreversível.',
      };
    }
    return switch (_languageKey(language)) {
      'en' =>
        '$protagonist must survive $engine with $opposing in $setting, while a $genre secret turns private desire into a public countdown.',
      'es' =>
        '$protagonist debe sobrevivir a $engine con $opposing en $setting, mientras un secreto de $genre convierte el deseo privado en una cuenta regresiva pública.',
      _ =>
        '$protagonist precisa sobreviver a $engine com $opposing em $setting, enquanto um segredo de $genre transforma o desejo privado em uma contagem regressiva pública.',
    };
  }

  static String _engine(String trope, String language) {
    return switch ((_languageKey(language), trope)) {
      ('en', 'Casamento por contrato') => 'a marriage contract with a deadline',
      ('en', 'Bebê secreto') => 'protecting a child the other side can expose',
      ('en', 'Identidade oculta') => 'keeping a false identity from collapsing',
      ('en', 'De inimigos a amantes') => 'a forced alliance with an enemy',
      ('en', 'Retorno vingativo') => 'a calculated return for payback',
      ('en', 'Amor proibido') => 'a forbidden attachment with a witness',
      ('en', 'Família escolhida') => 'choosing a found family over blood power',
      ('en', _) => 'a second chance that can be taken back',
      ('es', 'Casamento por contrato') => 'un contrato matrimonial con plazo',
      ('es', 'Bebê secreto') =>
        'proteger a un hijo que el otro bando puede exponer',
      ('es', 'Identidade oculta') =>
        'impedir que una identidad falsa se derrumbe',
      ('es', 'De inimigos a amantes') => 'una alianza forzada con el enemigo',
      ('es', 'Retorno vingativo') =>
        'un regreso calculado para cobrar venganza',
      ('es', 'Amor proibido') => 'un vínculo prohibido con testigos',
      ('es', 'Família escolhida') =>
        'elegir una familia hecha frente al poder de sangre',
      ('es', _) => 'una segunda oportunidad que pueden quitarle',
      (_, 'Casamento por contrato') => 'um casamento por contrato com prazo',
      (_, 'Bebê secreto') => 'proteger um filho que o outro lado pode expor',
      (_, 'Identidade oculta') => 'impedir que uma identidade falsa desabe',
      (_, 'De inimigos a amantes') => 'uma aliança forçada com o inimigo',
      (_, 'Retorno vingativo') => 'um retorno calculado para cobrar a dívida',
      (_, 'Amor proibido') => 'um vínculo proibido com testemunhas',
      (_, 'Família escolhida') =>
        'escolher uma família feita contra o poder de sangue',
      _ => 'uma segunda chance que pode ser retirada',
    };
  }

  static String _centralQuestion({
    required String language,
    required String protagonist,
    required String opposing,
    required String trope,
  }) {
    return switch (_languageKey(language)) {
      'en' =>
        'Will $protagonist tell the truth before $opposing uses $trope to lock the ending?',
      'es' =>
        '¿$protagonist dirá la verdad antes de que $opposing use $trope para cerrar el final?',
      _ =>
        '$protagonist vai revelar a verdade antes que $opposing use $trope para trancar o final?',
    };
  }

  static String _stakes({
    required String language,
    required String background,
    required String trope,
    required int episodeCount,
  }) {
    final window = episodeCount <= 8 ? '30 dias' : 'antes do último bloco';
    return switch (_languageKey(language)) {
      'en' =>
        'If the secret around $trope leaks in $background, reputation, custody and the last way out collapse within $window.',
      'es' =>
        'Si el secreto de $trope se filtra en $background, la reputación, la custodia y la última salida se derrumban en $window.',
      _ =>
        'Se o segredo de $trope vazar em $background, reputação, guarda e a última saída desabam em $window.',
    };
  }

  static String _languageKey(String language) {
    final value = language.toLowerCase();
    if (value.startsWith('en')) return 'en';
    if (value.startsWith('es')) return 'es';
    return 'pt';
  }
}
