import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/dola_generation_service.dart';
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

({String source, bool isAsset})? _playableTakeVideoSource(
  ProductionTakeItem take,
) {
  final output = take.outputUrl?.trim() ?? '';
  if (output.isEmpty || output.startsWith('local://')) return null;
  if (output.startsWith('asset://')) {
    return (source: output.substring('asset://'.length), isAsset: true);
  }
  final source = _resolveProductionMediaUrl(output);
  final uri = Uri.tryParse(source);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return (source: source, isAsset: false);
}

int? _studioEpisodeNumber(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

class _StudioChatTurn {
  const _StudioChatTurn({
    required this.role,
    required this.text,
    this.busy = false,
  });

  final String role;
  final String text;
  final bool busy;

  _StudioChatTurn copyWith({String? text, bool? busy}) => _StudioChatTurn(
    role: role,
    text: text ?? this.text,
    busy: busy ?? this.busy,
  );
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
  final DolaGenerationService _dolaGenerationService = DolaGenerationService();
  final LocalProductionWorkspaceService _workspaceService =
      LocalProductionWorkspaceService();

  ProductionProject? _project;
  int _episodeIndex = 0;
  int _sectionIndex = 1;
  int _selectedTakeIndex = 0;
  String _takeEditorField = 'visual';
  final GlobalKey<_InlineTakePlayerState> _inlineTakePlayerKey = GlobalKey();
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
  final List<_StudioChatTurn> _assistantTurns = [];
  final ScrollController _assistantScrollController = ScrollController();
  MicroDramaProjectConfig? _pendingChatContract;
  bool _allowPop = false;
  Future<void>? _ongoingSave;
  Timer? _persistDebounce;
  String? _error;

  bool get _isAdmin => _authService.currentUser?.isAdmin == true;
  bool get _isAiBusy => _activeAiAction != null;
  bool get _isAnyGenerationBusy =>
      _isAiBusy ||
      _isAutomaticPreparationRunning ||
      _generatingScriptEpisodeNumber != null ||
      _isApprovingScript;
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
    _persistDebounce?.cancel();
    final project = _project;
    if (project != null) {
      unawaited(_workspaceService.saveProject(_projectWithSession(project)));
    }
    _assistantController.dispose();
    _assistantScrollController.dispose();
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
      _restoreStudioSession(project);
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
    final previous = _ongoingSave;
    if (previous != null) await previous;
    final project = _project;
    if (project == null) return;
    final done = Completer<void>();
    _ongoingSave = done.future;
    if (mounted) setState(() => _isSaving = true);
    try {
      final saved = await _workspaceService.saveProject(
        _projectWithSession(project),
      );
      if (!mounted) return;
      setState(() => _project = _adoptSaved(saved));
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved.isLocal
                  ? 'Produção salva neste aparelho. A API ainda não confirmou o catálogo.'
                  : 'Produção salva na Vertix API',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível salvar a produção no servidor: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      done.complete();
      if (identical(_ongoingSave, done.future)) {
        _ongoingSave = null;
      }
    }
  }

  Future<ProductionProject> _persistProject(ProductionProject project) async {
    final saved = await _workspaceService.saveProject(
      _projectWithSession(project),
    );
    final adopted = _project == null ? saved : _adoptSaved(saved);
    if (mounted) setState(() => _project = adopted);
    return adopted;
  }

  ProductionProject _adoptSaved(ProductionProject saved) {
    final current = _project;
    if (current == null) return saved;
    return _workspaceService.adoptSavedProject(current: current, saved: saved);
  }

  ProductionProject _projectWithSession([ProductionProject? project]) {
    final current = project ?? _project!;
    return _workspaceService.attachStudioSession(
      current,
      chat: [
        for (final turn in _assistantTurns)
          if (!turn.busy || turn.text.trim().isNotEmpty)
            {'role': turn.role, 'text': turn.text},
      ],
      ui: {
        'episodeIndex': _episodeIndex,
        'studioTabIndex': _studioTabIndex,
        'episodeProductionMode': _episodeProductionMode,
        'showEpisodeScriptEditor': _showEpisodeScriptEditor,
        'showTechnicalEditor': _showTechnicalEditor,
        'assistantWriterMode': _assistantWriterMode,
        'sectionIndex': _sectionIndex,
        'selectedTakeIndex': _selectedTakeIndex,
      },
    );
  }

  void _restoreStudioSession(ProductionProject project) {
    final chat = _workspaceService.studioChatOf(project);
    final ui = _workspaceService.studioUiOf(project);
    final restoredTurns = [
      for (final item in chat)
        if ((item['text']?.toString().trim().isNotEmpty ?? false) ||
            item['role']?.toString() == 'user')
          _StudioChatTurn(
            role: item['role']?.toString() == 'user' ? 'user' : 'assistant',
            text: item['text']?.toString() ?? '',
          ),
    ];
    var episodeIndex = _readStudioInt(ui['episodeIndex'], fallback: 0);
    if (project.episodes.isNotEmpty) {
      episodeIndex = episodeIndex.clamp(0, project.episodes.length - 1);
    }
    var shouldPersistUnlockedTakes = false;
    setState(() {
      _assistantTurns
        ..clear()
        ..addAll(restoredTurns);
      _episodeIndex = episodeIndex;
      _studioTabIndex = _readStudioInt(ui['studioTabIndex'], fallback: 1);
      _sectionIndex = _readStudioInt(ui['sectionIndex'], fallback: 1);
      _selectedTakeIndex = _readStudioInt(ui['selectedTakeIndex'], fallback: 0);
      _episodeProductionMode = ui['episodeProductionMode'] == true;
      _showEpisodeScriptEditor = ui['showEpisodeScriptEditor'] == true;
      _showTechnicalEditor = ui['showTechnicalEditor'] == true;
      if (_episodeProductionMode) {
        final hadTakes = _episode?.takes.isNotEmpty == true;
        _unlockEpisodeTakesFromScript();
        shouldPersistUnlockedTakes =
            !hadTakes && _episode?.takes.isNotEmpty == true;
      }
      final writerMode = ui['assistantWriterMode']?.toString().trim();
      if (writerMode != null && writerMode.isNotEmpty) {
        _assistantWriterMode = writerMode;
      }
    });
    if (shouldPersistUnlockedTakes) _schedulePersist();
  }

  int _readStudioInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _schedulePersist() {
    if (_isAnyGenerationBusy) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _project == null || _isAnyGenerationBusy) return;
      unawaited(_saveProject(notify: false));
    });
  }

  void _selectStudioTab(int index) {
    setState(() => _studioTabIndex = index);
    _schedulePersist();
  }

  void _replaceEpisode(ProductionEpisodeItem episode) {
    final project = _project;
    if (project == null) return;
    final episodes = project.episodes.toList();
    episodes[_episodeIndex] = episode;
    setState(() => _project = project.copyWith(episodes: episodes));
    _schedulePersist();
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
    String? userPrompt,
    void Function(Map<String, dynamic> output)? onPartial,
  }) async {
    final project = _project;
    if (project == null) throw StateError('Projeto não carregado.');
    if (_isAiBusy) throw StateError('Já existe uma geração em andamento.');
    if (!await _ensureAiAccess()) {
      throw StateError('Login administrativo necessário.');
    }
    if (!mounted) throw StateError('Editor fechado.');
    final prompt = (userPrompt ?? instruction)?.trim();
    _beginAssistantTurn(
      prompt == null || prompt.isEmpty
          ? _promptForAiAction(action, episodeNumber: episodeNumber)
          : prompt,
    );
    setState(() {
      _activeAiAction = action;
      _activeAiProgress = 0;
      _activeAiMessage = 'Enviando ação autenticada ao servidor...';
    });
    _scrollAssistantToEnd();
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
      _updateLastAssistantTurn('Job ${job.id} criado. Aguardando a IA...');
      final completed = await _adminService.waitForGenerationJob(
        job.id,
        pollInterval: const Duration(milliseconds: 700),
        onProgress: (current) {
          if (!mounted) return;
          final output = current.outputData;
          final conversation = output?['conversation']?.toString().trim();
          final message =
              output?['message']?.toString() ?? 'Gerando com IA...';
          setState(() {
            _activeAiProgress = current.progress;
            _activeAiMessage = message;
            if (conversation != null && conversation.isNotEmpty) {
              _assistantStreamText = conversation;
              _replaceLastAssistantTurn(conversation, busy: true);
            } else {
              _replaceLastAssistantTurn(message, busy: true);
            }
          });
          _scrollAssistantToEnd();
          if (output != null) onPartial?.call(output);
        },
      );
      final output = completed.outputData;
      if (output == null) {
        throw StateError('O job terminou sem resultado estruturado.');
      }
      final conversation = output['conversation']?.toString().trim();
      final summary = output['summary']?.toString().trim();
      _finishLastAssistantTurn(
        conversation?.isNotEmpty == true
            ? conversation!
            : (summary?.isNotEmpty == true
                  ? summary!
                  : 'Ação concluída.'),
      );
      return output;
    } catch (error) {
      _finishLastAssistantTurn('Não foi possível concluir: $error');
      rethrow;
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

  String _promptForAiAction(String action, {int? episodeNumber}) {
    final episode = _episode;
    switch (action) {
      case 'GENERATE_SERIES_OUTLINE':
        return 'Gere o esboço completo da série, com contrato, episódios e corrente de gancho.';
      case 'GENERATE_EPISODE_SCRIPT':
        return 'Gere o roteiro completo do EP${episodeNumber ?? episode?.number ?? ''} · ${episode?.title ?? ''} em cenas e shots, seguindo o esboço deste episódio.';
      case 'GENERATE_PRODUCTION_SCENES':
        return 'Aprove o roteiro do EP${episodeNumber ?? episode?.number ?? ''} e libere a produção de vídeo.';
      case 'REVISE_PROJECT':
        return 'Revise o projeto com a instrução enviada.';
      default:
        return 'Executar ação de IA.';
    }
  }

  void _beginAssistantTurn(String userText) {
    setState(() {
      _assistantRequest = userText;
      _assistantStreamText = '';
      _assistantTurns
        ..add(_StudioChatTurn(role: 'user', text: userText))
        ..add(const _StudioChatTurn(role: 'assistant', text: '', busy: true));
    });
    _scrollAssistantToEnd();
  }

  void _updateLastAssistantTurn(String text, {bool busy = true}) {
    _replaceLastAssistantTurn(text, busy: busy);
  }

  void _replaceLastAssistantTurn(String text, {required bool busy}) {
    if (_assistantTurns.isEmpty) return;
    final index = _assistantTurns.lastIndexWhere(
      (turn) => turn.role == 'assistant',
    );
    if (index < 0) return;
    _assistantTurns[index] = _assistantTurns[index].copyWith(
      text: text,
      busy: busy,
    );
  }

  void _finishLastAssistantTurn(String text) {
    if (!mounted) return;
    setState(() {
      _assistantStreamText = text;
      _replaceLastAssistantTurn(text, busy: false);
    });
    _scrollAssistantToEnd();
  }

  void _scrollAssistantToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_assistantScrollController.hasClients) return;
      _assistantScrollController.animateTo(
        _assistantScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _generateSeriesOutlineWithCodex() async {
    final project = _project;
    if (project == null || _isAnyGenerationBusy) return;
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_SERIES_OUTLINE',
        userPrompt:
            'Gere o esboço completo da série, com contrato, episódios e corrente de gancho.',
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
    await _persistProject(current);

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
      await _persistProject(current);
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
      await _persistProject(current);
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
      _studioTabIndex = 1;
      _showEpisodeScriptEditor = true;
      _episodeProductionMode = false;
    });
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_EPISODE_SCRIPT',
        episodeNumber: episode.number,
        userPrompt:
            'Gere o roteiro completo do EP${episode.number} · ${episode.title} em cenas e shots, seguindo o esboço deste episódio — sem inventar outra história.',
        onPartial: (partial) => _applyStreamingScript(
          partial,
          episodeNumber: episode.number,
        ),
      );
      _applyStreamingScript(
        output,
        episodeNumber: episode.number,
        persist: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Roteiro detalhado do EP${episode.number} gerado. Revise as cenas à direita e aprove para liberar a produção.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o roteiro: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingScriptEpisodeNumber = null);
      }
    }
  }

  void _applyStreamingScript(
    Map<String, dynamic> output, {
    required int episodeNumber,
    bool persist = false,
  }) {
    final project = _project;
    if (project == null || output['result'] == null || !mounted) return;
    try {
      final updated = _workspaceService.applyCodexEpisodeScript(
        project,
        output,
        episodeNumber: episodeNumber,
        allowPartial: output['partial'] == true && !persist,
      );
      setState(() {
        _project = updated;
        _showEpisodeScriptEditor = true;
        _studioTabIndex = 1;
        final conversation = output['conversation']?.toString().trim();
        if (conversation != null && conversation.isNotEmpty) {
          _assistantStreamText = conversation;
          _replaceLastAssistantTurn(
            conversation,
            busy: output['partial'] == true && !persist,
          );
        }
      });
      if (persist) {
        unawaited(_persistProject(updated));
      }
    } catch (_) {
      if (persist && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A IA retornou um roteiro, mas ele ainda precisa de ajuste para ser salvo.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _approveEpisodeScriptForProduction() async {
    final project = _project;
    final episode = _episode;
    if (project == null ||
        episode == null ||
        _isApprovingScript ||
        _generatingScriptEpisodeNumber != null) {
      return;
    }
    setState(() => _isApprovingScript = true);
    try {
      final released = _workspaceService
          .approveMicroDramaEpisodeScriptForProduction(
            project,
            episodeNumber: episode.number,
          );
      if (!mounted) return;
      setState(() {
        _project = released;
        _isApprovingScript = false;
        _showEpisodeScriptEditor = false;
        _episodeProductionMode = true;
        _sectionIndex = 2;
        _selectedTakeIndex = 0;
      });
      unawaited(_persistProject(released));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Produção do EP${episode.number} liberada. Gere os takes um a um ou todos de uma vez.',
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

  bool _unlockEpisodeTakesFromScript() {
    final project = _project;
    final episode = _episode;
    if (project == null || episode == null) return false;
    if (episode.takes.isNotEmpty) return true;
    if (!_hasEpisodeScriptDraft(project, episode.number)) return false;
    try {
      final released = _workspaceService
          .approveMicroDramaEpisodeScriptForProduction(
            project,
            episodeNumber: episode.number,
          );
      _project = released;
      return released.episodes
          .firstWhere((item) => item.number == episode.number)
          .takes
          .isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _openEpisodeProduction({int? episodeIndex}) {
    setState(() {
      if (episodeIndex != null) _episodeIndex = episodeIndex;
      _unlockEpisodeTakesFromScript();
      _showEpisodeScriptEditor = false;
      _episodeProductionMode = true;
      _sectionIndex = 2;
      _selectedTakeIndex = 0;
    });
    _schedulePersist();
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
        userPrompt: instruction,
      );
      final updated = _workspaceService.applyCodexProjectRevision(
        project,
        output,
      );
      if (!mounted) return;
      setState(() => _project = updated);
      await _persistProject(updated);
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
    await _persistProject(updated);
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
        fillMissingSlots: output['partial'] == true && !persist,
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
          _replaceLastAssistantTurn(
            conversation,
            busy: output['partial'] == true && !persist,
          );
        }
      });
      if (persist) {
        unawaited(_persistProject(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Série "${updated.title}" gerada com IA: ${updated.episodes.where((item) => item.status != 'GENERATING').length} episódios no esboço.',
            ),
          ),
        );
      }
    } catch (error) {
      if (persist && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar o esboço: $error'),
          ),
        );
      }
    }
  }

  Future<void> _developSeriesFromChat(String idea) async {
    final project = _project;
    if (project == null || idea.trim().isEmpty || _isAnyGenerationBusy) return;
    final bible = project.seriesBible;
    try {
      final output = await _runAiWorkflow(
        action: 'GENERATE_SERIES_OUTLINE',
        userPrompt: idea.trim(),
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
    await _persistProject(updated);
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

  Future<void> _generateTakeWithDola(
    int takeIndex, {
    bool silent = false,
  }) async {
    final episode = _episode;
    if (episode == null) return;
    var take = episode.takes[takeIndex];
    if (take.status == 'GENERATING' || take.status == 'QUEUED') return;
    final prompt = take.visualPrompt.trim();
    if (prompt.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escreva o prompt da cena antes de gerar no Dola.'),
          ),
        );
      }
      return;
    }

    final references = _referencesForTake(take)
        .map(
          (reference) => <String, dynamic>{
            'id': reference.id,
            'label': reference.label,
            if (reference.publicUrl?.trim().isNotEmpty == true)
              'url': reference.publicUrl!.trim(),
            if (reference.assetPath?.trim().isNotEmpty == true)
              'path': reference.assetPath!.trim(),
          },
        )
        .toList();

    _replaceTake(
      takeIndex,
      take.copyWith(status: 'QUEUED', progress: 0.04),
    );
    try {
      final job = await _dolaGenerationService.startJob(
        prompt: prompt,
        takeId: take.id,
        takeTitle: take.title,
        durationSeconds: take.durationSeconds,
        references: references,
      );
      if (!mounted) return;
      _replaceTake(
        takeIndex,
        take.copyWith(
          status: 'GENERATING',
          progress: job.progress <= 0 ? 0.12 : job.progress,
        ),
      );
      final completed = await _dolaGenerationService.waitForJob(
        job.id,
        onProgress: (current) {
          if (!mounted) return;
          final latest = _episode?.takes[takeIndex];
          if (latest == null) return;
          _replaceTake(
            takeIndex,
            latest.copyWith(
              status: current.isCompleted ? 'GENERATING' : 'GENERATING',
              progress: current.progress <= 0 ? 0.12 : current.progress,
            ),
          );
        },
      );
      if (!mounted) return;
      take = _episode!.takes[takeIndex];
      final videoUrl = completed.videoUrl?.trim() ?? '';
      if (videoUrl.isEmpty) {
        throw StateError('O Dola terminou sem devolver o MP4.');
      }
      final endpoint =
          _takeStartSeconds(_episode!, takeIndex) + take.durationSeconds;
      final profileLabel = completed.profile == null
          ? 'Pre-Writes'
          : 'perfil ${completed.profile} · Pre-Writes';
      _replaceTake(
        takeIndex,
        take.copyWith(
          status: 'COMPLETED',
          progress: 1,
          outputUrl: videoUrl,
          lastFrameLabel: 'Dola $profileLabel • ${_timecode(endpoint)}',
        ),
      );
      await _saveProject(notify: false);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Take ${take.number} gerado no Dola $profileLabel'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      take = _episode!.takes[takeIndex];
      _replaceTake(
        takeIndex,
        take.copyWith(status: 'READY', progress: 0),
      );
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  Future<void> _generateAllTakes() async {
    if (_isGeneratingEpisode || _episode == null) return;
    if (_episode!.takes.isEmpty) {
      await _approveEpisodeScriptForProduction();
      if (!mounted || (_episode?.takes.isEmpty ?? true)) return;
    }
    setState(() {
      _isGeneratingEpisode = true;
      _sectionIndex = 2;
      _episodeProductionMode = true;
    });
    var generated = 0;
    var failed = 0;
    try {
      for (var index = 0; index < _episode!.takes.length; index++) {
        if (!mounted) return;
        final status = _episode!.takes[index].status;
        if (status == 'COMPLETED') continue;
        setState(() => _selectedTakeIndex = index);
        await _generateTakeWithDola(index, silent: true);
        if (!mounted) return;
        if (_episode!.takes[index].status == 'COMPLETED') {
          generated += 1;
        } else {
          failed += 1;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? 'Geração dos takes concluída ($generated).'
                : 'Takes gerados: $generated. Falhas: $failed.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingEpisode = false);
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

  String _formatClock(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 0) return _timecode(0);
    return _timecode(seconds);
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
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveProject(notify: false);
        if (!mounted) return;
        setState(() => _allowPop = true);
        context.pop();
      },
      child: _buildEditorShell(),
    );
  }

  Widget _buildEditorShell() {
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
    if (_showTechnicalEditor) {
      return _withDesktopNavOffset(_buildTechnicalEditorScaffold());
    }
    return _withDesktopNavOffset(_buildStudioWorkbenchScaffold());
  }
}
