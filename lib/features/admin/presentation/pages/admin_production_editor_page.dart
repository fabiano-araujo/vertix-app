import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/local_production_workspace_service.dart';
import '../../../../core/theme/app_colors.dart';

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
    setState(() {
      _isGeneratingEpisode = true;
      _sectionIndex = 1;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_project?.title ?? 'Studio de producao'),
        actions: [
          IconButton(
            tooltip: 'Salvar localmente',
            onPressed: _isSaving ? null : _saveProject,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: _loadProject,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : _buildEditor(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.movie_creation_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadProject,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );

  Widget _buildEditor() {
    final project = _project!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth > 1440 ? 1440 : constraints.maxWidth,
            child: Column(
              children: [
                _buildProjectHeader(project, constraints.maxWidth),
                _buildSectionBar(),
                Expanded(child: _buildSelectedSection()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectHeader(ProductionProject project, double width) {
    final episode = _episode!;
    final progress = episode.takes.isEmpty
        ? 0.0
        : episode.takes.fold<double>(0, (sum, take) => sum + take.progress) /
              episode.takes.length;
    final compact = width < 720;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProjectTitle(project),
                const SizedBox(height: 14),
                _buildEpisodeSelector(project),
                const SizedBox(height: 14),
                _buildProgressAndAction(episode, progress, compact: true),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: _buildProjectTitle(project)),
                const SizedBox(width: 18),
                Expanded(flex: 3, child: _buildEpisodeSelector(project)),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: _buildProgressAndAction(episode, progress),
                ),
              ],
            ),
    );
  }

  Widget _buildProjectTitle(ProductionProject project) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _pill(
            project.isLocal ? 'LOCAL' : 'API',
            project.isLocal ? AppColors.success : AppColors.primary,
          ),
          _pill(project.status),
          _pill(project.formatFamily),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        project.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 5),
      Text(
        project.sourcePath,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ],
  );

  Widget _buildEpisodeSelector(ProductionProject project) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'EPISODIO ATIVO',
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 7),
      DropdownButtonFormField<int>(
        initialValue: _episodeIndex,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.playlist_play),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        items: List.generate(project.episodes.length, (index) {
          final episode = project.episodes[index];
          return DropdownMenuItem(
            value: index,
            child: Text('EP ${episode.number} • ${episode.title}'),
          );
        }),
        onChanged: (value) {
          if (value != null) setState(() => _episodeIndex = value);
        },
      ),
    ],
  );

  Widget _buildProgressAndAction(
    ProductionEpisodeItem episode,
    double progress, {
    bool compact = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${episode.takes.length} takes • ${_timecode(episode.durationSeconds)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          minHeight: 7,
          value: progress,
          backgroundColor: AppColors.surfaceLighter,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _isGeneratingEpisode ? null : _simulateEpisode,
        icon: _isGeneratingEpisode
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isGeneratingEpisode ? 'Simulando episodio...' : 'Simular episodio',
        ),
      ),
    ],
  );

  Widget _buildSectionBar() {
    const sections = [
      (Icons.dashboard_outlined, 'Resumo'),
      (Icons.movie_filter_outlined, 'Takes'),
      (Icons.collections_outlined, 'Referencias'),
      (Icons.view_timeline_outlined, 'Timeline'),
      (Icons.graphic_eq, 'Audio'),
    ];
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _sectionIndex == index;
          return ChoiceChip(
            avatar: Icon(sections[index].$1, size: 18),
            label: Text(sections[index].$2),
            selected: selected,
            selectedColor: AppColors.primary.withAlpha(55),
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.surfaceLighter,
            ),
            onSelected: (_) => setState(() => _sectionIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildSelectedSection() => switch (_sectionIndex) {
    0 => _buildOverview(),
    1 => _buildTakes(),
    2 => _buildReferences(),
    3 => _buildTimeline(),
    _ => _buildAudio(),
  };

  Widget _buildOverview() {
    final project = _project!;
    final episode = _episode!;
    return ListView(
      key: const PageStorageKey('production-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final treatment = _panel(
              title: 'Tratamento do episodio',
              icon: Icons.description_outlined,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: episode.summary,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Historia linear antes de dividir em takes',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      _replaceEpisode(episode.copyWith(summary: value));
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: episode.cliffhanger,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Cliffhanger',
                      prefixIcon: Icon(Icons.bolt),
                    ),
                    onChanged: (value) {
                      _replaceEpisode(episode.copyWith(cliffhanger: value));
                    },
                  ),
                ],
              ),
            );
            final pipeline = _panel(
              title: 'Pipeline da obra',
              icon: Icons.account_tree_outlined,
              child: Column(
                children: const [
                  _WorkflowStep(
                    icon: Icons.menu_book_outlined,
                    title: 'Biblia da obra',
                    subtitle: 'Genero, arco, personagens e regras do mundo',
                    done: true,
                  ),
                  _WorkflowStep(
                    icon: Icons.people_outline,
                    title: 'Identidades e ambientes',
                    subtitle: 'Masters canonicos e mapa espacial',
                    done: true,
                  ),
                  _WorkflowStep(
                    icon: Icons.description_outlined,
                    title: 'Episodio linear',
                    subtitle: 'Gancho, escalada, virada e cliffhanger',
                    done: true,
                  ),
                  _WorkflowStep(
                    icon: Icons.movie_filter_outlined,
                    title: 'Takes tecnicos',
                    subtitle: 'Prompts, referencias e pontes de continuidade',
                    done: false,
                  ),
                  _WorkflowStep(
                    icon: Icons.graphic_eq,
                    title: 'Pos-producao',
                    subtitle: 'Montagem, vozes, musica, ambiente e SFX',
                    done: false,
                    last: true,
                  ),
                ],
              ),
            );
            if (!wide) {
              return Column(
                children: [treatment, const SizedBox(height: 12), pipeline],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: treatment),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: pipeline),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Biblia de producao',
          icon: Icons.hub_outlined,
          trailing: _pill('${project.seriesBible.length} contratos'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: project.seriesBible.entries
                .map(
                  (entry) => Container(
                    width: 310,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          entry.value?.toString() ?? '',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.35,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTakes() {
    final episode = _episode!;
    return ListView(
      key: const PageStorageKey('production-takes'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _buildTakeToolbar(episode),
        const SizedBox(height: 12),
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
            onSelected: (value) {
              final takes = episode.takes.toList();
              for (var index = 1; index < takes.length; index++) {
                takes[index] = takes[index].copyWith(
                  usePreviousLastFrame: value,
                  transitionMode: value ? 'MATCH_ON_ACTION' : 'SOFT_CONTINUITY',
                );
              }
              _replaceEpisode(episode.copyWith(takes: takes));
            },
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _sectionIndex = 3),
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
    return Container(
      key: ValueKey(take.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
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

  Widget _buildReferences() {
    final project = _project!;
    final byCategory = <String, int>{};
    for (final reference in project.references) {
      byCategory.update(
        reference.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return ListView(
      key: const PageStorageKey('production-references'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: 'Pacote visual canonico',
          icon: Icons.collections_bookmark_outlined,
          trailing: FilledButton.icon(
            onPressed: _showAddReferenceDialog,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Adicionar referencia'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Identidade de personagem e estado de transicao sao contratos diferentes. Use um LOCATION_MASTER por local fisico e marque os masters canonicos.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('${project.references.length} assets'),
                  ...byCategory.entries.map(
                    (entry) => _pill('${entry.value} ${entry.key}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (project.references.isEmpty)
          _panel(
            title: 'Sem referencias',
            icon: Icons.image_not_supported_outlined,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Adicione identidades, locais, objetos ou frames de continuidade.',
                  style: TextStyle(color: AppColors.textSecondary),
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
                children: project.references
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
                  children: [_pill(reference.category), _pill('$usage takes')],
                ),
                if (reference.description.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    reference.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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
        imageUrl: reference.publicUrl!,
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
          isLocation ? Icons.landscape_outlined : Icons.person_outline,
          color: AppColors.primaryLight,
          size: 34,
        ),
      ),
    );
  }

  Future<void> _showAddReferenceDialog() async {
    final labelController = TextEditingController();
    final pathController = TextEditingController();
    final descriptionController = TextEditingController();
    var category = 'CHARACTER_REFERENCE';
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

  Widget _buildTimeline() {
    final episode = _episode!;
    final totalSeconds = episode.takes.fold<int>(
      0,
      (sum, take) => sum + take.durationSeconds,
    );
    final calculatedWidth = totalSeconds * 11.0;
    final trackWidth = calculatedWidth < 820 ? 820.0 : calculatedWidth;
    return ListView(
      key: const PageStorageKey('production-timeline'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: 'Montagem do episodio',
          icon: Icons.view_timeline_outlined,
          trailing: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'EDL local preparada para a futura integracao de exportacao.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('EDL'),
              ),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Preview local: a montagem acompanha o estado simulado dos takes.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 19),
                label: const Text('Reproduzir'),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('${episode.takes.length} takes'),
              _pill('${_timecode(totalSeconds)} de video'),
              _pill('9:16 vertical'),
              _pill('24 fps'),
              _pill('audio multifaixa'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final preview = _buildSequencePreview(episode, totalSeconds);
            final timeline = _buildTimelineCanvas(
              episode,
              totalSeconds,
              trackWidth,
            );
            if (constraints.maxWidth < 920) {
              return Column(
                children: [
                  Align(alignment: Alignment.center, child: preview),
                  const SizedBox(height: 12),
                  timeline,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 230, child: preview),
                const SizedBox(width: 12),
                Expanded(child: timeline),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSequencePreview(
    ProductionEpisodeItem episode,
    int totalSeconds,
  ) {
    final completed = episode.takes
        .where((take) => take.status == 'COMPLETED')
        .length;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _projectPreview(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22000000), Color(0xE9000000)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(155),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                      ),
                      child: const Icon(Icons.play_arrow, size: 32),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EP ${episode.number} • ${episode.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$completed/${episode.takes.length} renders • ${_timecode(totalSeconds)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Monitor vertical',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Preview conceitual da montagem local. Os arquivos simulados nao enviam dados a provedores externos.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectPreview() {
    final project = _project!;
    if (project.coverAssetPath?.isNotEmpty == true) {
      return Image.asset(
        project.coverAssetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _projectPreviewFallback(),
      );
    }
    if (project.coverUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: project.coverUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _projectPreviewFallback(),
      );
    }
    return _projectPreviewFallback();
  }

  Widget _projectPreviewFallback() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF183153), Color(0xFF121212)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 54,
        color: AppColors.primaryLight,
      ),
    ),
  );

  Widget _buildTimelineCanvas(
    ProductionEpisodeItem episode,
    int totalSeconds,
    double trackWidth,
  ) {
    final video = <_TimelineClip>[];
    final continuity = <_TimelineClip>[];
    final dialogue = <_TimelineClip>[];
    final sfx = <_TimelineClip>[];
    var cursor = 0;
    for (final take in episode.takes) {
      final completed = take.status == 'COMPLETED';
      video.add(
        _TimelineClip(
          start: cursor.toDouble(),
          duration: take.durationSeconds.toDouble(),
          label: 'T${take.number} ${take.title}',
          color: completed ? AppColors.success : AppColors.primary,
          icon: completed ? Icons.check_circle_outline : Icons.movie_outlined,
        ),
      );
      if (take.usePreviousLastFrame) {
        continuity.add(
          _TimelineClip(
            start: cursor.toDouble(),
            duration: 1.4,
            label: 'Frame T${take.number - 1}',
            color: AppColors.warning,
            icon: Icons.link,
          ),
        );
      }
      if (take.audioPrompt.trim().isNotEmpty) {
        dialogue.add(
          _TimelineClip(
            start: cursor + 0.6,
            duration: take.durationSeconds - 1.2,
            label: 'Voz / T${take.number}',
            color: const Color(0xFF8B5CF6),
            icon: Icons.record_voice_over_outlined,
          ),
        );
      }
      final sfxStart = cursor + (take.durationSeconds * 0.58);
      sfx.add(
        _TimelineClip(
          start: sfxStart,
          duration: take.durationSeconds * 0.3,
          label: 'SFX T${take.number}',
          color: const Color(0xFFF97316),
          icon: Icons.bolt,
        ),
      );
      cursor += take.durationSeconds;
    }
    final music = episode.externalMusic
        ? [
            _TimelineClip(
              start: 0,
              duration: totalSeconds.toDouble(),
              label: '${episode.musicProvider} • ${episode.musicStatus}',
              color: const Color(0xFFEC4899),
              icon: Icons.music_note,
            ),
          ]
        : const <_TimelineClip>[];
    final ambience = [
      _TimelineClip(
        start: 0,
        duration: totalSeconds.toDouble(),
        label: 'Ambiente continuo',
        color: const Color(0xFF14B8A6),
        icon: Icons.air,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _timelineRuler(totalSeconds, trackWidth),
              const SizedBox(height: 5),
              _timelineLane(
                label: 'VIDEO',
                icon: Icons.movie_outlined,
                clips: video,
                totalSeconds: totalSeconds,
                trackWidth: trackWidth,
              ),
              _timelineLane(
                label: 'PONTE',
                icon: Icons.link,
                clips: continuity,
                totalSeconds: totalSeconds,
                trackWidth: trackWidth,
              ),
              _timelineLane(
                label: 'DIALOGO',
                icon: Icons.mic_none,
                clips: dialogue,
                totalSeconds: totalSeconds,
                trackWidth: trackWidth,
              ),
              _timelineLane(
                label: 'MUSICA',
                icon: Icons.music_note,
                clips: music,
                totalSeconds: totalSeconds,
                trackWidth: trackWidth,
              ),
              _timelineLane(
                label: 'AMBIENTE',
                icon: Icons.air,
                clips: ambience,
                totalSeconds: totalSeconds,
                trackWidth: trackWidth,
              ),
              _timelineLane(
                label: 'SFX',
                icon: Icons.graphic_eq,
                clips: sfx,
                totalSeconds: totalSeconds,
                trackWidth: trackWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineRuler(int totalSeconds, double trackWidth) {
    final interval = totalSeconds <= 60 ? 5 : 10;
    final marks = <int>[];
    for (var second = 0; second <= totalSeconds; second += interval) {
      marks.add(second);
    }
    if (marks.isEmpty || marks.last != totalSeconds) marks.add(totalSeconds);
    return SizedBox(
      width: trackWidth + 116,
      height: 28,
      child: Row(
        children: [
          const SizedBox(
            width: 116,
            child: Text(
              'TIMEcode',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: trackWidth,
            child: Stack(
              children: marks
                  .map(
                    (second) => Positioned(
                      left: totalSeconds == 0
                          ? 0
                          : (second / totalSeconds) * (trackWidth - 32),
                      top: 3,
                      child: Text(
                        _timecode(second),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineLane({
    required String label,
    required IconData icon,
    required List<_TimelineClip> clips,
    required int totalSeconds,
    required double trackWidth,
  }) {
    final safeTotal = totalSeconds == 0 ? 1 : totalSeconds;
    return Container(
      width: trackWidth + 116,
      height: 61,
      margin: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 110,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: trackWidth,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.surfaceLighter),
            ),
            child: Stack(
              children: clips.map((clip) {
                final left = (clip.start / safeTotal) * trackWidth;
                final calculated = (clip.duration / safeTotal) * trackWidth;
                final preferredWidth = calculated < 32 ? 32.0 : calculated;
                final availableWidth = trackWidth - left;
                final width = preferredWidth > availableWidth
                    ? availableWidth
                    : preferredWidth;
                final compactClip = width < 66;
                return Positioned(
                  left: left,
                  top: 5,
                  bottom: 5,
                  width: width,
                  child: Container(
                    padding: compactClip
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: clip.color.withAlpha(45),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: clip.color.withAlpha(150)),
                    ),
                    child: compactClip
                        ? Icon(clip.icon, color: clip.color, size: 13)
                        : Row(
                            children: [
                              Icon(clip.icon, color: clip.color, size: 14),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  clip.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudio() {
    final episode = _episode!;
    return ListView(
      key: const PageStorageKey('production-audio'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: 'Pos-producao de audio',
          icon: Icons.graphic_eq,
          trailing: _pill(
            episode.musicStatus,
            _statusColor(episode.musicStatus),
          ),
          child: const Text(
            'A musica final fica fora do Seedance. Dialogo, musica, ambiente e efeitos permanecem em faixas independentes para mixagem e substituicao.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final music = _buildMusicConfiguration(episode);
            final mixer = _buildAudioMixer(episode);
            if (constraints.maxWidth < 820) {
              return Column(
                children: [music, const SizedBox(height: 12), mixer],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: music),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: mixer),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Faixas do episodio',
          icon: Icons.multitrack_audio_outlined,
          trailing: OutlinedButton.icon(
            onPressed: () => setState(() => _sectionIndex = 3),
            icon: const Icon(Icons.view_timeline_outlined, size: 18),
            label: const Text('Abrir timeline'),
          ),
          child: Column(
            children: [
              _buildStemCard(
                icon: Icons.record_voice_over_outlined,
                color: const Color(0xFF8B5CF6),
                title: 'Dialogo',
                subtitle: 'Vozes e timecodes definidos em cada take',
                status: 'EDITAVEL',
                waveformSeed: 3,
              ),
              const SizedBox(height: 9),
              _buildStemCard(
                icon: Icons.music_note,
                color: const Color(0xFFEC4899),
                title: 'Musica',
                subtitle: episode.externalMusic
                    ? '${episode.musicProvider} • arquivo independente'
                    : 'Faixa musical desativada',
                status: episode.musicStatus,
                waveformSeed: 7,
              ),
              const SizedBox(height: 9),
              _buildStemCard(
                icon: Icons.air,
                color: const Color(0xFF14B8A6),
                title: 'Ambiente',
                subtitle: 'Room tone e ambiencia continua entre cortes',
                status: 'PRONTO',
                waveformSeed: 11,
              ),
              const SizedBox(height: 9),
              _buildStemCard(
                icon: Icons.bolt,
                color: const Color(0xFFF97316),
                title: 'Efeitos / SFX',
                subtitle: 'Eventos pontuais alinhados aos takes',
                status: 'EDITAVEL',
                waveformSeed: 17,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMusicConfiguration(ProductionEpisodeItem episode) {
    const providers = [
      'API de musica (a definir)',
      'API externa',
      'Suno',
      'ElevenLabs Music',
      'Arquivo proprio',
    ];
    final provider = providers.contains(episode.musicProvider)
        ? episode.musicProvider
        : providers.first;
    final generating = episode.musicStatus == 'GENERATING';
    return _panel(
      title: 'Gerador de musica externo',
      icon: Icons.library_music_outlined,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: episode.externalMusic,
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(externalMusic: value));
            },
            title: const Text(
              'Manter musica fora do Seedance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Permite trocar, regenerar e mixar sem refazer o video.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: provider,
            decoration: const InputDecoration(
              labelText: 'Provedor / origem',
              prefixIcon: Icon(Icons.cloud_outlined),
            ),
            items: providers
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: episode.externalMusic
                ? (value) {
                    if (value != null) {
                      _replaceEpisode(episode.copyWith(musicProvider: value));
                    }
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: episode.musicPrompt,
            enabled: episode.externalMusic,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Prompt da trilha musical',
              alignLabelWithHint: true,
              helperText:
                  'Inclua duracao, arco emocional, instrumentos, pontos de virada e "sem voz".',
            ),
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(musicPrompt: value));
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !episode.externalMusic || generating
                  ? null
                  : _simulateMusic,
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                generating
                    ? 'Simulando geracao...'
                    : episode.musicStatus == 'COMPLETED'
                    ? 'Gerar outra versao'
                    : 'Simular faixa musical',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMixer(ProductionEpisodeItem episode) {
    return _panel(
      title: 'Mixer',
      icon: Icons.tune,
      trailing: _pill('MASTER -6 dB'),
      child: Column(
        children: [
          _buildMixerChannel(
            icon: Icons.record_voice_over_outlined,
            color: const Color(0xFF8B5CF6),
            label: 'Dialogo',
            value: episode.dialogueVolume,
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(dialogueVolume: value));
            },
          ),
          _buildMixerChannel(
            icon: Icons.music_note,
            color: const Color(0xFFEC4899),
            label: 'Musica',
            value: episode.musicVolume,
            onChanged: episode.externalMusic
                ? (value) {
                    _replaceEpisode(episode.copyWith(musicVolume: value));
                  }
                : null,
          ),
          _buildMixerChannel(
            icon: Icons.air,
            color: const Color(0xFF14B8A6),
            label: 'Ambiente',
            value: episode.ambienceVolume,
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(ambienceVolume: value));
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLighter),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ducking de musica durante falas e continuidade de room tone habilitados.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixerChannel({
    required IconData icon,
    required Color color,
    required String label,
    required double value,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStemCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String status,
    required int waveformSeed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 165,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 38,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(52, (index) {
                  final raw = ((index + waveformSeed) * 37) % 29;
                  final height = 7.0 + raw;
                  return Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color.withAlpha(145),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _pill(status, _statusColor(status)),
        ],
      ),
    );
  }

  Future<void> _simulateMusic() async {
    final episode = _episode;
    if (episode == null || episode.musicStatus == 'GENERATING') return;
    _replaceEpisode(episode.copyWith(musicStatus: 'GENERATING'));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _episode == null) return;
    _replaceEpisode(_episode!.copyWith(musicStatus: 'COMPLETED'));
    await _saveProject(notify: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Faixa musical externa simulada e adicionada a timeline'),
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(32),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 19),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (trailing != null && constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleWidget, const SizedBox(height: 10), trailing],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleWidget),
                  if (trailing != null) trailing,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _pill(String text, [Color? color]) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withAlpha(50)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: effectiveColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status.toUpperCase()) {
    'COMPLETED' || 'PUBLISHED' || 'PRONTO' => AppColors.success,
    'GENERATING' || 'IN_PROGRESS' || 'IN_PRODUCTION' => AppColors.primary,
    'QUEUED' || 'READY' || 'EDITAVEL' => AppColors.warning,
    'FAILED' || 'ERROR' => AppColors.error,
    _ => AppColors.textSecondary,
  };
}

class _WorkflowStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool last;

  const _WorkflowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withAlpha(100)),
                  ),
                  child: Icon(
                    done ? Icons.check : icon,
                    color: color,
                    size: 16,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: AppColors.surfaceLighter),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineClip {
  final double start;
  final double duration;
  final String label;
  final Color color;
  final IconData icon;

  const _TimelineClip({
    required this.start,
    required this.duration,
    required this.label,
    required this.color,
    required this.icon,
  });
}
