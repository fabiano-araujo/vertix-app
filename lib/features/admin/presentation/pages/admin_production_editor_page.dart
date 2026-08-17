import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/local_production_workspace_service.dart';
import '../../../../core/theme/app_colors.dart';

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
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGeneratingEpisode = false;
  bool _isApprovingScript = false;
  int? _generatingScriptEpisodeNumber;
  bool _showHookChain = false;
  bool _episodeProductionMode = false;
  bool _showEpisodeScriptEditor = false;
  bool _showTechnicalEditor = false;
  int _studioTabIndex = 1;
  final TextEditingController _assistantController = TextEditingController();
  String? _assistantRequest;
  String? _error;

  bool get _isAdmin => _authService.currentUser?.isAdmin == true;
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Nao foi possivel abrir o editor: $error';
        _isLoading = false;
      });
    }
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

  Future<void> _generateEpisodeScript(int episodeIndex) async {
    final project = _project;
    if (project == null ||
        episodeIndex < 0 ||
        episodeIndex >= project.episodes.length ||
        _generatingScriptEpisodeNumber != null) {
      return;
    }
    final episode = project.episodes[episodeIndex];
    setState(() {
      _generatingScriptEpisodeNumber = episode.number;
      _episodeIndex = episodeIndex;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    try {
      final updated = _workspaceService.generateMicroDramaEpisodeScript(
        project,
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
            'Roteiro detalhado do EP${episode.number} gerado em cenas e beats.',
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
    if (project == null || episode == null || _isApprovingScript) return;
    setState(() => _isApprovingScript = true);
    try {
      final updated = _workspaceService
          .approveMicroDramaEpisodeScriptForProduction(
            project,
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
            'Roteiro do EP${episode.number} aprovado. Prompts de produção liberados.',
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
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _buildError(),
      );
    }
    if (_episodeProductionMode) return _buildEpisodeProductionScaffold();
    if (_showEpisodeScriptEditor) return _buildEpisodeScriptScaffold();
    if (_showTechnicalEditor) return _buildTechnicalEditorScaffold();
    return _buildStudioWorkbenchScaffold();
  }
}
