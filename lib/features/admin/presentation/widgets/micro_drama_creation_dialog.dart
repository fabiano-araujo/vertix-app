import 'package:flutter/material.dart';

import '../../../../core/services/local_production_workspace_service.dart';
import '../../../../core/theme/app_colors.dart';

class MicroDramaCreationDialog extends StatefulWidget {
  const MicroDramaCreationDialog({super.key});

  @override
  State<MicroDramaCreationDialog> createState() =>
      _MicroDramaCreationDialogState();
}

class _MicroDramaCreationDialogState extends State<MicroDramaCreationDialog> {
  final _titleController = TextEditingController();
  final _loglineController = TextEditingController();
  final _centralQuestionController = TextEditingController();
  final _protagonistController = TextEditingController();
  final _opposingForceController = TextEditingController();
  final _stakesController = TextEditingController();

  int _step = 0;
  String _genre = 'Romance com reviravolta';
  String _background = 'Cidade moderna';
  String _trope = 'Segunda chance';
  String _visualStyle = 'Microdrama moderno';
  String _language = 'Português (Brasil)';
  String _rating = '14 anos';
  int _episodeCount = 8;
  int _firstEpisodeDuration = 120;
  int _episodeDuration = 60;
  bool _automaticReview = true;
  String? _error;

  static const _stepLabels = [
    'Ajustes',
    'Posicionamento',
    'Contrato da série',
    'Revisão',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _loglineController.dispose();
    _centralQuestionController.dispose();
    _protagonistController.dispose();
    _opposingForceController.dispose();
    _stakesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: (screen.height - 32).clamp(520, 760),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      _buildError(_error!),
                      const SizedBox(height: 14),
                    ],
                    switch (_step) {
                      0 => _buildSettings(),
                      1 => _buildPositioning(),
                      2 => _buildContract(),
                      _ => _buildReview(),
                    },
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_stories_outlined,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Criar microdrama',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Da premissa ao outline, ganchos, assets e beats de produção.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_stepLabels.length, (index) {
              final active = index == _step;
              final done = index < _step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _stepLabels.length - 1 ? 0 : 7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 4,
                        decoration: BoxDecoration(
                          color: active || done
                              ? AppColors.primary
                              : AppColors.surfaceLighter,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stepLabels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Ajustes básicos',
          'Defina o formato de distribuição antes de escrever a história.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _titleController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Título de trabalho',
            prefixIcon: Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 14),
        _responsiveFields([
          _dropdown<int>(
            label: 'Número de episódios',
            icon: Icons.video_library_outlined,
            value: _episodeCount,
            values: const [8, 12, 20, 50, 80],
            labelFor: (value) => '$value episódios',
            onChanged: (value) => setState(() => _episodeCount = value),
          ),
          _dropdown<String>(
            label: 'Idioma do vídeo',
            icon: Icons.language,
            value: _language,
            values: const [
              'Português (Brasil)',
              'Português (Portugal)',
              'English',
              'Español',
            ],
            labelFor: (value) => value,
            onChanged: (value) => setState(() => _language = value),
          ),
          _dropdown<int>(
            label: 'Duração do primeiro episódio',
            icon: Icons.timer_outlined,
            value: _firstEpisodeDuration,
            values: const [60, 90, 120],
            labelFor: (value) => '$value segundos',
            onChanged: (value) => setState(() => _firstEpisodeDuration = value),
          ),
          _dropdown<int>(
            label: 'Duração dos demais',
            icon: Icons.timelapse,
            value: _episodeDuration,
            values: const [45, 60, 90],
            labelFor: (value) => '$value segundos',
            onChanged: (value) => setState(() => _episodeDuration = value),
          ),
          _dropdown<String>(
            label: 'Classificação',
            icon: Icons.shield_outlined,
            value: _rating,
            values: const ['Livre', '10 anos', '12 anos', '14 anos', '16 anos'],
            labelFor: (value) => value,
            onChanged: (value) => setState(() => _rating = value),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceLighter),
          ),
          child: SwitchListTile(
            value: _automaticReview,
            onChanged: (value) => setState(() => _automaticReview = value),
            title: const Text('Revisão narrativa automática'),
            subtitle: const Text(
              'Prepara cartões, cadeia de ganchos e portas de qualidade para revisão humana.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            secondary: const Icon(Icons.fact_check_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildPositioning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Posicionamento criativo',
          'Separe gênero, cenário, tropo e tratamento visual.',
        ),
        const SizedBox(height: 18),
        _choiceSection(
          'Gênero',
          Icons.theater_comedy_outlined,
          const [
            'Romance com reviravolta',
            'Drama de vingança',
            'Segredos de família',
            'Suspense e mistério',
            'Fantasia urbana',
            'Drama médico',
            'Legal / crime',
            'Comédia leve',
          ],
          _genre,
          (value) => setState(() => _genre = value),
        ),
        const SizedBox(height: 18),
        _choiceSection(
          'Cenário principal',
          Icons.location_city_outlined,
          const [
            'Cidade moderna',
            'Mansão de luxo',
            'Escritório corporativo',
            'Campus universitário',
            'Hospital',
            'Tribunal',
            'Cidade pequena',
            'Reino sobrenatural',
          ],
          _background,
          (value) => setState(() => _background = value),
        ),
        const SizedBox(height: 18),
        _choiceSection(
          'Tropo / promessa familiar',
          Icons.favorite_border,
          const [
            'Segunda chance',
            'Casamento por contrato',
            'Bebê secreto',
            'Identidade oculta',
            'De inimigos a amantes',
            'Retorno vingativo',
            'Amor proibido',
            'Família escolhida',
          ],
          _trope,
          (value) => setState(() => _trope = value),
        ),
        const SizedBox(height: 18),
        _choiceSection(
          'Estilo visual',
          Icons.palette_outlined,
          const [
            'Microdrama moderno',
            'Cinema teatral realista',
            'K-drama moderno',
            'Noir urbano',
            'Animação cinematográfica',
          ],
          _visualStyle,
          (value) => setState(() => _visualStyle = value),
        ),
      ],
    );
  }

  Widget _buildContract() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Contrato da série',
          'A temporada só avança quando desejo, oposição, risco e pergunta central estão claros.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _loglineController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Logline / premissa em uma frase',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.short_text),
            hintText:
                'Quem é o protagonista, o que acontece, o que ele precisa fazer e o que está em risco?',
          ),
        ),
        const SizedBox(height: 14),
        _responsiveFields([
          TextField(
            controller: _protagonistController,
            decoration: const InputDecoration(
              labelText: 'Protagonista',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          TextField(
            controller: _opposingForceController,
            decoration: const InputDecoration(
              labelText: 'Força oposta / antagonista',
              prefixIcon: Icon(Icons.flash_on_outlined),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _centralQuestionController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Grande expectativa / pergunta central',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.help_outline),
            hintText: 'A pergunta que sustenta a temporada até o bloco final.',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _stakesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Risco e urgência',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.warning_amber_outlined),
            hintText: 'O que se perde, por que agora e qual é o prazo?',
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final totalSeconds =
        _firstEpisodeDuration + ((_episodeCount - 1) * _episodeDuration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Revisar e criar',
          'O Vertix criará o outline, a cadeia de ganchos, placeholders canônicos e os beats de cada episódio.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.trim(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loglineController.text.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _reviewPill('$_episodeCount episódios'),
                  _reviewPill(_formatDuration(totalSeconds)),
                  _reviewPill('9:16'),
                  _reviewPill(_genre),
                  _reviewPill(_trope),
                  _reviewPill(_language),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _reviewRow(
          Icons.tune,
          'Ajustes e posicionamento',
          '$_visualStyle • $_background • $_rating',
        ),
        _reviewRow(
          Icons.menu_book_outlined,
          'Contrato narrativo',
          '${_protagonistController.text.trim()} × ${_opposingForceController.text.trim()}',
        ),
        _reviewRow(
          Icons.account_tree_outlined,
          'Outline e corrente de ganchos',
          'Cada abertura paga o corte anterior; cada episódio termina no pico.',
        ),
        _reviewRow(
          Icons.people_outline,
          'Assets canônicos',
          'Protagonista, força oposta, ambiente mestre e objeto narrativo.',
        ),
        _reviewRow(
          Icons.movie_filter_outlined,
          'Roteiro de produção',
          'Beats de até 15s, vídeo com áudio integrado e música separada.',
          last: true,
        ),
        const SizedBox(height: 14),
        const Text(
          'Status inicial: RASCUNHO. A criação não trava o roteiro; a aprovação humana continua obrigatória antes da produção.',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: () => setState(() {
                _step -= 1;
                _error = null;
              }),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _step == _stepLabels.length - 1 ? _finish : _advance,
            icon: Icon(
              _step == _stepLabels.length - 1
                  ? Icons.auto_awesome
                  : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(
              _step == _stepLabels.length - 1
                  ? 'Criar microdrama'
                  : 'Continuar',
            ),
          ),
        ],
      ),
    );
  }

  void _advance() {
    final error = _validationError(_step);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _step += 1;
      _error = null;
    });
  }

  void _finish() {
    for (var step = 0; step < 3; step++) {
      final error = _validationError(step);
      if (error != null) {
        setState(() {
          _step = step;
          _error = error;
        });
        return;
      }
    }
    Navigator.pop(
      context,
      MicroDramaProjectConfig(
        title: _titleController.text.trim(),
        logline: _loglineController.text.trim(),
        centralQuestion: _centralQuestionController.text.trim(),
        protagonist: _protagonistController.text.trim(),
        opposingForce: _opposingForceController.text.trim(),
        stakes: _stakesController.text.trim(),
        genre: _genre,
        background: _background,
        trope: _trope,
        visualStyle: _visualStyle,
        language: _language,
        rating: _rating,
        episodeCount: _episodeCount,
        firstEpisodeDurationSeconds: _firstEpisodeDuration,
        episodeDurationSeconds: _episodeDuration,
        automaticReview: _automaticReview,
      ),
    );
  }

  String? _validationError(int step) {
    if (step == 0 && _titleController.text.trim().isEmpty) {
      return 'Informe um título de trabalho para continuar.';
    }
    if (step == 2) {
      if (_loglineController.text.trim().isEmpty) {
        return 'A logline é obrigatória: ela orienta todos os episódios.';
      }
      if (_protagonistController.text.trim().isEmpty ||
          _opposingForceController.text.trim().isEmpty) {
        return 'Defina protagonista e força oposta.';
      }
      if (_centralQuestionController.text.trim().isEmpty) {
        return 'Defina a grande expectativa que sustenta a temporada.';
      }
      if (_stakesController.text.trim().isEmpty) {
        return 'Explique o risco e a urgência da história.';
      }
    }
    return null;
  }

  Widget _stepTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    ],
  );

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var index = 0; index < children.length; index += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[index]),
                if (index + 1 < children.length) ...[
                  const SizedBox(width: 12),
                  Expanded(child: children[index + 1]),
                ] else
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
          if (index + 2 < children.length) rows.add(const SizedBox(height: 14));
        }
        return Column(children: rows);
      },
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _choiceSection(
    String title,
    IconData icon,
    List<String> values,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                  selectedColor: AppColors.primary.withAlpha(48),
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                    color: value == selected
                        ? AppColors.primary
                        : AppColors.surfaceLighter,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildError(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withAlpha(18),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withAlpha(70)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(message)),
      ],
    ),
  );

  Widget _reviewPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surfaceLighter,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11)),
  );

  Widget _reviewRow(
    IconData icon,
    String title,
    String subtitle, {
    bool last = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.primaryLight),
          ),
          if (!last)
            Container(width: 1, height: 34, color: AppColors.surfaceLighter),
        ],
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (rest == 0) return '${minutes}m';
    return '${minutes}m ${rest}s';
  }
}
