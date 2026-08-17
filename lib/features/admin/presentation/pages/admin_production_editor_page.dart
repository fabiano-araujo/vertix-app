import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/local_production_workspace_service.dart';
import '../../../../core/services/micro_drama_theme_composer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

part 'admin_production_editor_studio_part.dart';
part 'admin_production_editor_content_part.dart';
part 'admin_production_editor_takes_part.dart';
part 'admin_production_editor_references_part.dart';
part 'admin_production_editor_timeline_part.dart';
part 'admin_production_editor_audio_part.dart';
part 'admin_production_editor_shared_part.dart';
part 'admin_production_editor_preview_part.dart';

String _resolveProductionMediaUrl(String source) {
  final value = source.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return value;
  }
  if (value.startsWith('/generated-production/')) {
    return Uri.base.resolve(value.substring(1)).toString();
  }
  if (value.startsWith('generated-production/')) {
    return Uri.base.resolve(value).toString();
  }
  if (value.startsWith('/')) return '${ApiConstants.baseUrl}$value';
  return value;
}

class AdminProductionEditorPage extends StatefulWidget {
  final int seriesId;
  final ProductionCatalogItem? item;

  const AdminProductionEditorPage({
    super.key,
    required this.seriesId,
    this.item,
  });

  @override
  State<AdminProductionEditorPage> createState() =>
      _AdminProductionEditorPageState();
}

class _AdminProductionEditorPageState extends State<AdminProductionEditorPage> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  final LocalProductionWorkspaceService _workspaceService =
      LocalProductionWorkspaceService();

  ProductionProject? _project;
  int _episodeIndex = 0;
  int _sectionIndex = 1;
  int _selectedTakeIndex = 0;
  String _takeEditorField = 'visual';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGeneratingEpisode = false;
  bool _isApprovingScript = false;
  int? _generatingScriptEpisodeNumber;
  int? _activeAiJobId;
  int _activeAiProgress = 0;
  String? _activeAiAction;
  String? _activeAiMessage;
  bool _isAutomaticPreparationRunning = false;
  bool _automaticPreparationScheduled = false;
  int _automaticPreparationCompleted = 0;
  int _automaticPreparationTotal = 0;
  String? _automaticPreparationMessage;
  bool _showHookChain = false;
  bool _episodeProductionMode = false;
  bool _showEpisodeScriptEditor = false;
  bool _showTechnicalEditor = false;
  int _studioTabIndex = 1;
  String _assistantWriterMode = 'Melhor roteirista';
  final TextEditingController _assistantController = TextEditingController();
  final TextEditingController _contractTitleController =
      TextEditingController();
  final TextEditingController _contractLoglineController =
      TextEditingController();
  final TextEditingController _contractProtagonistController =
      TextEditingController();
  final TextEditingController _contractOpposingController =
      TextEditingController();
  final TextEditingController _contractQuestionController =
      TextEditingController();
  final TextEditingController _contractStakesController =
      TextEditingController();
  String? _assistantRequest;
  String? _assistantStreamText;
  MicroDramaProjectConfig? _pendingChatContract;
  String? _error;

  bool get _isAdmin => _authService.currentUser?.isAdmin == true;
  bool get _isAiBusy => _activeAiAction != null;
  bool get _isAnyGenerationBusy => _isAiBusy || _isAutomaticPreparationRunning;
  bool get _isChatBrief {
    final project = _project;
    if (project == null) return false;
    return LocalProductionWorkspaceService.isMicroDramaChatBrief(project);
  }

  ProductionEpisodeItem? get _episode {
    final project = _project;
    if (project == null || project.episodes.isEmpty) return null;
    return project.episodes[_episodeIndex.clamp(
      0,
      project.episodes.length - 1,
    )];
  }

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void dispose() {
    _assistantController.dispose();
    _contractTitleController.dispose();
    _contractLoglineController.dispose();
    _contractProtagonistController.dispose();
    _contractOpposingController.dispose();
    _contractQuestionController.dispose();
    _contractStakesController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    if (!_isAdmin) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var item = widget.item;
      AdminSeriesProductionPlan? remotePlan;
      if (item == null && widget.seriesId < 0) {
        final local = await _workspaceService.getLocalProjectByVirtualId(
          widget.seriesId,
        );
        if (local != null) item = ProductionCatalogItem.fromLocal(local);
      }
      if (item == null && widget.seriesId > 0) {
        final response = await _adminService.getAvailableSeries(limit: 100);
        for (final summary in response.data) {
          if (summary.id == widget.seriesId) {
            item = ProductionCatalogItem.fromRemote(summary);
            break;
          }
        }
      }
      if (item == null) throw StateError('Obra nao encontrada');
      if (!item.isLocal) {
        final response = await _adminService.getSeriesProduction(item.routeId);
        remotePlan = response.data;
      }
      final project = await _workspaceService.loadEditorProject(
        item,
        remotePlan: remotePlan,
      );
      if (!mounted) return;
      setState(() {
        _project = project;
        _episodeIndex = 0;
        _isLoading = false;
      });
      _scheduleAutomaticPreparationIfRequested(project);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Nao foi possivel abrir o editor: $error';
        _isLoading = false;
      });
    }
  }

  void _scheduleAutomaticPreparationIfRequested(ProductionProject project) {
    final raw = project.seriesBible['automatic_preparation_requested'];
    final requested = raw == true || raw?.toString().toLowerCase() == 'true';
    if (!requested || _automaticPreparationScheduled) return;
    if (LocalProductionWorkspaceService.isMicroDramaChatBrief(project)) return;
    _automaticPreparationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _prepareProjectAutomatically(
          updateOutline: true,
          requestedAtCreation: true,
        ),
      );
    });
  }

  Future<void> _saveProject({bool notify = true}) async {
    final project = _project;
    if (project == null || _isSaving) return;
    setState(() => _isSaving = true);
    await _workspaceService.saveProject(project);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (notify) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producao salva no workspace local')),
      );
    }
  }

  void _replaceEpisode(ProductionEpisodeItem episode) {
    final project = _project;
    if (project == null) return;
    final episodes = project.episodes.toList();
    episodes[_episodeIndex] = episode;
    setState(() => _project = project.copyWith(episodes: episodes));
  }

  Future<bool> _ensureAiAccess() async {
    final authenticated = await _authService.isAuthenticated();
    if (!mounted) return false;
    if (authenticated && _isAdmin) return true;
    final loggedIn = await context.push<bool>('/login');
    if (!mounted) return false;
    final authenticatedAfterLogin = await _authService.isAuthenticated();
    if (!mounted) return false;
    if (loggedIn == true && authenticatedAfterLogin && _isAdmin) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Faça login com uma conta administradora para usar o Codex.',
        ),
      ),
    );
    return false;
  }

  Future<Map<String, dynamic>> _runAiWorkflow({
    required String action,
    int? episodeNumber,
    String? instruction,
    void Function(Map<String, dynamic> output)? onPartial,
  }) async {
    final project = _project;
    if (project == null) throw StateError('Projeto não carregado.');
    if (_isAiBusy) throw StateError('Já existe uma geração em andamento.');
    if (!await _ensureAiAccess()) {
      throw StateError('Login administrativo necessário.');
    }
    if (!mounted) throw StateError('Editor fechado.');
    setState(() {
      _activeAiAction = action;
      _activeAiProgress = 0;
      _activeAiMessage = 'Enviando ação autenticada ao servidor...';
    });
    try {
      final job = await _adminService.startCodexWorkflow(
        action: action,
        project: project.toJson(),
        episodeNumber: episodeNumber,
        instruction: instruction,
        codexThreadId: project.seriesBible['codex_thread_id']?.toString(),
      );
      if (!mounted) throw StateError('Editor fechado.');
      setState(() {
        _activeAiJobId = job.id;
        _activeAiMessage = 'Job ${job.id} criado';
      });
      final completed = await _adminService.waitForGenerationJob(
        job.id,
        pollInterval: const Duration(milliseconds: 700),
        onProgress: (current) {
          if (!mounted) return;
          final output = current.outputData;
          setState(() {
            _activeAiProgress = current.progress;
            _activeAiMessage =
                output?['message']?.toString() ?? 'Gerando com IA...';
            final conversation = output?['conversation']?.toString().trim();
            if (conversation != null && conversation.isNotEmpty) {
              _assistantStreamText = conversation;
            }
          });
          if (output != null) onPartial?.call(output);
        },
      );
      final output = completed.outputData;
      if (output == null) {
        throw StateError('O job terminou sem resultado estruturado.');
      }
      return output;
    } finally {
      if (mounted) {
        setState(() {
          _activeAiJobId = null;
          _activeAiProgress = 0;
          _activeAiAction = null;
          _activeAiMessage = null;
        });
      }
    }
  }

  Future<void> _generateSeriesOutlineWithCodex() async {
    final project = _project;
    if (project == null || _isAnyGenerationBusy) return;
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_SERIES_OUTLINE',
        onPartial: _applyStreamingOutline,
      );
      _applyStreamingOutline(output, persist: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o esboço: $error')),
      );
    }
  }

  Future<void> _showAutomaticPreparationDialog() async {
    if (_project == null || _isAnyGenerationBusy) return;
    var updateOutline = true;
    final options = await showDialog<Map<String, bool>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_motion_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('Preparação automática')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escolha o que será preparado agora. O fluxo termina com tudo em revisão e não gera roteiros de episódios nem vídeos.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: updateOutline,
                  onChanged: (value) =>
                      setDialogState(() => updateOutline = value ?? false),
                  title: const Text('Atualizar esboço e objetivos'),
                  subtitle: const Text(
                    'Codex refina a temporada, os objetivos de cada episódio e as fichas de personagens, ambientes e adereços.',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'As fichas textuais são criadas pelo Codex. Imagens não são geradas automaticamente nesta etapa; você pode anexá-las depois.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: !updateOutline
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'updateOutline': updateOutline,
                    }),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Preparar automaticamente'),
            ),
          ],
        ),
      ),
    );
    if (options == null || !mounted) return;
    await _prepareProjectAutomatically(
      updateOutline: options['updateOutline'] ?? false,
    );
  }

  Future<void> _prepareProjectAutomatically({
    required bool updateOutline,
    bool requestedAtCreation = false,
  }) async {
    final initialProject = _project;
    if (initialProject == null || _isAnyGenerationBusy) return;
    var current = initialProject;
    if (!await _ensureAiAccess() || !mounted) return;

    final failures = <String>[];
    var completed = 0;
    var total = updateOutline ? 1 : 0;

    current = _withAutomaticPreparationState(
      current,
      status: 'RUNNING',
      requestedAtCreation: requestedAtCreation,
      updateOutline: updateOutline,
      failures: const [],
    );
    setState(() {
      _project = current;
      _isAutomaticPreparationRunning = true;
      _automaticPreparationCompleted = 0;
      _automaticPreparationTotal = total;
      _automaticPreparationMessage = 'Iniciando preparação automática...';
    });
    await _workspaceService.saveProject(current);

    try {
      if (updateOutline) {
        if (mounted) {
          setState(() {
            _automaticPreparationMessage =
                'Gerando esboço, objetivos e fichas narrativas...';
          });
        }
        try {
          final output = await _runAiWorkflow(
            action: 'GENERATE_SERIES_OUTLINE',
            onPartial: _applyStreamingOutline,
          );
          _applyStreamingOutline(output, persist: true);
          current = _project ?? current;
        } catch (error) {
          failures.add('Esboço e objetivos: $error');
        } finally {
          completed += 1;
          if (mounted) {
            setState(() => _automaticPreparationCompleted = completed);
          }
        }
      }

      final status = failures.isEmpty
          ? 'COMPLETED_REVIEW_REQUIRED'
          : 'PARTIAL_REVIEW_REQUIRED';
      current = _withAutomaticPreparationState(
        current,
        status: status,
        requestedAtCreation: requestedAtCreation,
        updateOutline: updateOutline,
        failures: failures,
      );
      if (mounted) setState(() => _project = current);
      await _workspaceService.saveProject(current);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failures.isEmpty
                ? 'Preparação concluída. Esboço, objetivos e fichas estão prontos para revisão.'
                : 'Preparação parcial: ${failures.length} itens precisam ser tentados novamente.',
          ),
        ),
      );
    } catch (error) {
      failures.add('Fluxo automático: $error');
      current = _withAutomaticPreparationState(
        current,
        status: 'PARTIAL_REVIEW_REQUIRED',
        requestedAtCreation: requestedAtCreation,
        updateOutline: updateOutline,
        failures: failures,
      );
      if (mounted) setState(() => _project = current);
      await _workspaceService.saveProject(current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A preparação automática foi interrompida: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAutomaticPreparationRunning = false;
          _automaticPreparationMessage = null;
        });
      }
    }
  }

  ProductionProject _withAutomaticPreparationState(
    ProductionProject project, {
    required String status,
    required bool requestedAtCreation,
    required bool updateOutline,
    required List<String> failures,
  }) {
    return project.copyWith(
      updatedAt: DateTime.now(),
      seriesBible: {
        ...project.seriesBible,
        'automatic_preparation_requested': false,
        'automatic_preparation_status': status,
        'automatic_preparation_summary': {
          'requested_at_creation': requestedAtCreation,
          'outline_and_objectives': updateOutline,
          'reference_images': false,
          'image_generation': 'DISABLED_BY_DESIGN',
          'generated_images': 0,
          'failures': failures,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'next_gate': 'HUMAN_REVIEW_BEFORE_EPISODE_SCRIPT',
        },
      },
    );
  }

  Future<void> _generateEpisodeScript(int episodeIndex) async {
    final project = _project;
    if (project == null ||
        episodeIndex < 0 ||
        episodeIndex >= project.episodes.length ||
        _generatingScriptEpisodeNumber != null ||
        _isAnyGenerationBusy) {
      return;
    }
    final episode = project.episodes[episodeIndex];
    setState(() {
      _generatingScriptEpisodeNumber = episode.number;
      _episodeIndex = episodeIndex;
    });
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_EPISODE_SCRIPT',
        episodeNumber: episode.number,
      );
      final updated = _workspaceService.applyCodexEpisodeScript(
        project,
        output,
        episodeNumber: episode.number,
      );
      setState(() {
        _project = updated;
        _generatingScriptEpisodeNumber = null;
        _showEpisodeScriptEditor = true;
      });
      await _workspaceService.saveProject(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Roteiro detalhado do EP${episode.number} gerado pelo Codex em cenas e shots.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _generatingScriptEpisodeNumber = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o roteiro: $error')),
      );
    }
  }

  Future<void> _approveEpisodeScriptForProduction() async {
    final project = _project;
    final episode = _episode;
    if (project == null ||
        episode == null ||
        _isApprovingScript ||
        _isAnyGenerationBusy) {
      return;
    }
    setState(() => _isApprovingScript = true);
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_PRODUCTION_SCENES',
        episodeNumber: episode.number,
      );
      final updated = _workspaceService.applyCodexProductionScenes(
        project,
        output,
        episodeNumber: episode.number,
      );
      setState(() {
        _project = updated;
        _isApprovingScript = false;
        _showEpisodeScriptEditor = false;
        _episodeProductionMode = true;
        _sectionIndex = 2;
      });
      await _workspaceService.saveProject(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Roteiro do EP${episode.number} aprovado. Prompts gerados pelo Codex e decorados pelo estilo fixo do app.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isApprovingScript = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível liberar a produção: $error')),
      );
    }
  }

  Future<void> _reviseProjectWithCodex(String instruction) async {
    final project = _project;
    if (project == null || instruction.trim().isEmpty || _isAnyGenerationBusy) {
      return;
    }
    try {
      final output = await _runAiWorkflow(
        action: 'REVISE_PROJECT',
        instruction: instruction,
      );
      final updated = _workspaceService.applyCodexProjectRevision(
        project,
        output,
      );
      if (!mounted) return;
      setState(() => _project = updated);
      await _workspaceService.saveProject(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajuste aplicado pelo Codex.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível aplicar o ajuste: $error')),
      );
    }
  }

  Future<void> _patchChatBrief({
    String? title,
    String? genre,
    String? background,
    String? trope,
    String? visualStyle,
    String? language,
    String? rating,
    String? styleFamily,
    int? episodeCount,
    int? firstEpisodeDurationSeconds,
    int? episodeDurationSeconds,
    int? maxShotDurationSeconds,
    bool? automaticReview,
    bool? automaticPreparation,
  }) async {
    final project = _project;
    if (project == null || !_isChatBrief) return;
    final updated = _workspaceService.patchMicroDramaChatBrief(
      project,
      title: title,
      genre: genre,
      background: background,
      trope: trope,
      visualStyle: visualStyle,
      language: language,
      rating: rating,
      styleFamily: styleFamily,
      episodeCount: episodeCount,
      firstEpisodeDurationSeconds: firstEpisodeDurationSeconds,
      episodeDurationSeconds: episodeDurationSeconds,
      maxShotDurationSeconds: maxShotDurationSeconds,
      automaticReview: automaticReview,
      automaticPreparation: automaticPreparation,
    );
    setState(() {
      _project = updated;
      if (_pendingChatContract != null) {
        _pendingChatContract = _pendingChatContract!.copyWith(
          title: title,
          genre: genre,
          background: background,
          trope: trope,
          visualStyle: visualStyle,
          language: language,
          rating: rating,
          episodeCount: episodeCount,
          firstEpisodeDurationSeconds: firstEpisodeDurationSeconds,
          episodeDurationSeconds: episodeDurationSeconds,
          maxShotDurationSeconds: maxShotDurationSeconds,
          automaticReview: automaticReview,
          automaticPreparation: automaticPreparation,
        );
      }
    });
    await _workspaceService.saveProject(updated);
  }

  void _fillPendingChatContract(MicroDramaProjectConfig config) {
    _pendingChatContract = config;
    _contractTitleController.text = config.title;
    _contractLoglineController.text = config.logline;
    _contractProtagonistController.text = config.protagonist;
    _contractOpposingController.text = config.opposingForce;
    _contractQuestionController.text = config.centralQuestion;
    _contractStakesController.text = config.stakes;
  }

  MicroDramaProjectConfig _configFromChatBrief({required String idea}) {
    final project = _project!;
    final bible = project.seriesBible;
    return MicroDramaThemeComposer.compose(
      idea: idea,
      genre: bible['genre']?.toString() ?? project.genre,
      background: bible['background']?.toString() ?? 'Cidade moderna',
      trope: bible['trope']?.toString() ?? 'Segunda chance',
      visualStyle: bible['visual_style']?.toString() ?? 'Microdrama moderno',
      language: bible['language']?.toString() ?? 'Português (Brasil)',
      rating: bible['rating']?.toString() ?? '14 anos',
      episodeCount: project.targetEpisodeCount.clamp(1, 80),
      firstEpisodeDurationSeconds:
          (bible['first_episode_duration_seconds'] as num?)?.toInt() ?? 120,
      episodeDurationSeconds:
          (bible['episode_duration_seconds'] as num?)?.toInt() ?? 60,
      maxShotDurationSeconds:
          (bible['max_shot_duration_seconds'] as num?)?.toInt() ?? 10,
      automaticReview: bible['automatic_review'] != false,
      automaticPreparation: bible['automatic_preparation_requested'] == true,
    );
  }

  void _applyStreamingOutline(
    Map<String, dynamic> output, {
    bool persist = false,
  }) {
    final project = _project;
    if (project == null || output['result'] == null || !mounted) return;
    try {
      final updated = _workspaceService.applyCodexSeriesOutline(
        project,
        output,
        allowPartial: output['partial'] == true || persist,
      );
      final readyIndex = updated.episodes.lastIndexWhere(
        (episode) => episode.status != 'GENERATING' && episode.summary.isNotEmpty,
      );
      setState(() {
        _project = updated;
        _pendingChatContract = null;
        _studioTabIndex = 1;
        if (readyIndex >= 0) _episodeIndex = readyIndex;
        final conversation = output['conversation']?.toString().trim();
        if (conversation != null && conversation.isNotEmpty) {
          _assistantStreamText = conversation;
        }
      });
      if (persist) {
        unawaited(_workspaceService.saveProject(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Série "${updated.title}" gerada com IA: ${updated.episodes.where((item) => item.status != 'GENERATING').length} episódios no esboço.',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _developSeriesFromChat(String idea) async {
    final project = _project;
    if (project == null || idea.trim().isEmpty || _isAnyGenerationBusy) return;
    final bible = project.seriesBible;
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_SERIES_OUTLINE',
        instruction: [
          'Ideia do usuario: ${idea.trim()}',
          'Modo do roteirista: $_assistantWriterMode',
          'Titulo atual do rascunho: ${project.title}',
          'Genero: ${bible['genre'] ?? project.genre}',
          'Cenario: ${bible['background'] ?? 'Cidade moderna'}',
          'Tropo: ${bible['trope'] ?? 'Segunda chance'}',
          'Estilo visual: ${bible['visual_style'] ?? 'Microdrama moderno'}',
          'Idioma: ${bible['language'] ?? 'Português (Brasil)'}',
          'Classificacao: ${bible['rating'] ?? '14 anos'}',
          'Episodios: ${project.targetEpisodeCount}',
          'Duracao do EP1: ${bible['first_episode_duration_seconds'] ?? 120}s',
          'Duracao dos demais: ${bible['episode_duration_seconds'] ?? 60}s',
          'Crie um TITULO original da serie (2 a 6 palavras). Nao use a ideia crua como titulo quando ela for so um genero, tropo ou uma palavra, por exemplo Romance.',
          'Gere o contrato completo, depois cada episodio em sequencia, com personagens, ambientes, aderecos e corrente de gancho.',
        ].join('\n'),
        onPartial: _applyStreamingOutline,
      );
      _applyStreamingOutline(output, persist: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar a série: $error')),
      );
    }
  }

  Future<void> _applyPendingChatContract() async {
    final project = _project;
    final pending = _pendingChatContract;
    if (project == null || pending == null || _isAnyGenerationBusy) return;
    final config = pending.copyWith(
      title: _contractTitleController.text.trim().isEmpty
          ? pending.title
          : _contractTitleController.text.trim(),
      logline: _contractLoglineController.text.trim().isEmpty
          ? pending.logline
          : _contractLoglineController.text.trim(),
      protagonist: _contractProtagonistController.text.trim().isEmpty
          ? pending.protagonist
          : _contractProtagonistController.text.trim(),
      opposingForce: _contractOpposingController.text.trim().isEmpty
          ? pending.opposingForce
          : _contractOpposingController.text.trim(),
      centralQuestion: _contractQuestionController.text.trim().isEmpty
          ? pending.centralQuestion
          : _contractQuestionController.text.trim(),
      stakes: _contractStakesController.text.trim().isEmpty
          ? pending.stakes
          : _contractStakesController.text.trim(),
    );
    if (config.logline.trim().isEmpty ||
        config.protagonist.trim().isEmpty ||
        config.opposingForce.trim().isEmpty) {
      _showStudioMessage(
        'Complete o contrato da série no chat para continuar.',
      );
      return;
    }
    final updated = _workspaceService.applyMicroDramaConfig(
      project,
      config,
      creationIdea: _assistantRequest,
    );
    setState(() {
      _project = updated;
      _pendingChatContract = null;
      _studioTabIndex = 1;
      _episodeIndex = 0;
    });
    await _workspaceService.saveProject(updated);
    if (!mounted) return;
    if (config.automaticPreparation) {
      _automaticPreparationScheduled = true;
      await _prepareProjectAutomatically(
        updateOutline: true,
        requestedAtCreation: true,
      );
    }
  }

  void _replaceTake(int takeIndex, ProductionTakeItem take) {
    final episode = _episode;
    if (episode == null) return;
    final takes = episode.takes.toList();
    takes[takeIndex] = take;
    _replaceEpisode(
      episode.copyWith(
        takes: takes,
        durationSeconds: takes.fold<int>(
          0,
          (sum, item) => sum + item.durationSeconds,
        ),
      ),
    );
  }

  Future<void> _simulateTake(int takeIndex, {bool silent = false}) async {
    final episode = _episode;
    if (episode == null) return;
    var take = episode.takes[takeIndex];
    if (take.status == 'GENERATING') return;
    _replaceTake(takeIndex, take.copyWith(status: 'QUEUED', progress: 0.04));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final progress in const [0.18, 0.37, 0.61, 0.82, 1.0]) {
      if (!mounted) return;
      take = _episode!.takes[takeIndex];
      _replaceTake(
        takeIndex,
        take.copyWith(status: 'GENERATING', progress: progress),
      );
      await Future<void>.delayed(const Duration(milliseconds: 360));
    }
    if (!mounted) return;
    take = _episode!.takes[takeIndex];
    final endpoint =
        _takeStartSeconds(_episode!, takeIndex) + take.durationSeconds;
    _replaceTake(
      takeIndex,
      take.copyWith(
        status: 'COMPLETED',
        progress: 1,
        outputUrl: 'local://simulation/${take.id}.mp4',
        lastFrameLabel: 'Frame final simulado • ${_timecode(endpoint)}',
      ),
    );
    await _saveProject(notify: false);
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Take ${take.number} simulado com sucesso')),
      );
    }
  }

  Future<void> _simulateEpisode() async {
    if (_isGeneratingEpisode || _episode == null) return;
    if (_episode!.takes.isEmpty) {
      await _generateEpisodeScript(_episodeIndex);
      return;
    }
    setState(() {
      _isGeneratingEpisode = true;
      _sectionIndex = 2;
    });
    for (var index = 0; index < _episode!.takes.length; index++) {
      if (!mounted) return;
      if (_episode!.takes[index].status != 'COMPLETED') {
        await _simulateTake(index, silent: true);
      }
    }
    if (!mounted) return;
    setState(() => _isGeneratingEpisode = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Episodio simulado e montado na timeline local'),
      ),
    );
  }

  Future<void> _showEpisodePreview() async {
    final project = _project;
    final episode = _episode;
    if (project == null || episode == null) return;
    if (episode.takes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aprove primeiro o roteiro detalhado para liberar a produção.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _EpisodePreviewDialog(project: project, episode: episode),
    );
  }

  int _takeStartSeconds(ProductionEpisodeItem episode, int takeIndex) {
    return episode.takes
        .take(takeIndex)
        .fold(0, (sum, take) => sum + take.durationSeconds);
  }

  String _timecode(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  Widget _withDesktopNavOffset(Widget child) {
    if (!Responsive.isDesktop(context)) return child;
    return Padding(
      padding: const EdgeInsets.only(top: Responsive.topNavHeight),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Acesso restrito a administradores',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (_isLoading || _error != null) {
      return _withDesktopNavOffset(
        Scaffold(
          backgroundColor: AppColors.background,
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _buildError(),
        ),
      );
    }
    if (_episodeProductionMode) {
      return _withDesktopNavOffset(_buildEpisodeProductionScaffold());
    }
    if (_showEpisodeScriptEditor) {
      return _withDesktopNavOffset(_buildEpisodeScriptScaffold());
    }
    if (_showTechnicalEditor) {
      return _withDesktopNavOffset(_buildTechnicalEditorScaffold());
    }
    return _withDesktopNavOffset(_buildStudioWorkbenchScaffold());
  }
}
