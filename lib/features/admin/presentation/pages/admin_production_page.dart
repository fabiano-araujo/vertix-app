import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/local_production_workspace_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';

class AdminProductionPage extends StatefulWidget {
  const AdminProductionPage({super.key});

  @override
  State<AdminProductionPage> createState() => _AdminProductionPageState();
}

class _AdminProductionPageState extends State<AdminProductionPage> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  final LocalProductionWorkspaceService _localService =
      LocalProductionWorkspaceService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductionCatalogItem> _series = [];
  bool _isLoading = true;
  String _scopeFilter = 'API';
  String _statusFilter = 'ALL';
  String? _error;
  bool _remoteUnavailable = false;

  bool get _isAdmin => _authService.currentUser?.isAdmin == true;

  int get _inProductionCount =>
      _series.where((item) => item.status == 'IN_PRODUCTION').length;

  int get _draftCount => _series.where((item) => item.status == 'DRAFT').length;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    if (!_isAdmin) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final remoteResponse = await _adminService.getAvailableSeries(
      status: _statusFilter == 'ALL' ? 'ALL' : _statusFilter,
      search: _searchController.text,
      limit: 100,
    );
    final query = _searchController.text.trim().toLowerCase();
    final items =
        remoteResponse.data
            .map(ProductionCatalogItem.fromRemote)
            .where((item) {
              if (_scopeFilter == 'API' && item.status == 'ARCHIVED') {
                return false;
              }
              if (_statusFilter != 'ALL' && item.status != _statusFilter) {
                return false;
              }
              if (query.isEmpty) return true;
              return item.title.toLowerCase().contains(query) ||
                  item.description.toLowerCase().contains(query) ||
                  item.genre.toLowerCase().contains(query);
            })
            .toList()
          ..sort(compareStudioCatalogItems);

    if (!mounted) return;
    setState(() {
      _series = items;
      _isLoading = false;
      _remoteUnavailable = !remoteResponse.success;
      _error = items.isEmpty && !remoteResponse.success
          ? 'Nao foi possivel carregar as series da API'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return _buildUnauthorized();

    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.background,
              title: const Text('Studio'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _openNewMicroDramaStudio,
                  tooltip: 'Novo microdrama',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSeries,
                  tooltip: 'Atualizar',
                ),
              ],
            ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadSeries,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            isDesktop ? Responsive.topNavHeight + 20 : 8,
            Responsive.horizontalPadding(context),
            96,
          ),
          children: [
            _buildHeader(isDesktop),
            if (_remoteUnavailable) ...[
              const SizedBox(height: 14),
              _buildRemoteWarning(),
            ],
            const SizedBox(height: 20),
            _buildToolbar(),
            const SizedBox(height: 22),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              _buildMessage(Icons.error_outline, _error!)
            else if (_series.isEmpty)
              _buildMessage(Icons.video_library_outlined, 'Nenhuma serie')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1480
                      ? 3
                      : constraints.maxWidth >= 820
                      ? 2
                      : 1;
                  final gap = 14.0;
                  final width = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: _series
                        .map(
                          (series) => SizedBox(
                            width: width,
                            child: _ProductionSeriesCard(
                              series: series,
                              onTap: () => _openSeries(series),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorized() {
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

  Widget _buildHeader(bool isDesktop) {
    final summary = _isLoading
        ? 'Carregando o catalogo do studio...'
        : _series.isEmpty
        ? 'Nenhuma obra neste filtro.'
        : [
            '${_series.length} ${_series.length == 1 ? 'obra' : 'obras'}',
            if (_inProductionCount > 0) '$_inProductionCount em producao',
            if (_draftCount > 0) '$_draftCount rascunhos',
          ].join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Studio',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (isDesktop) ...[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSeries,
            tooltip: 'Atualizar',
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _openNewMicroDramaStudio,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Novo microdrama'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _loadSeries(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar serie, genero ou descricao',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _loadSeries();
                    },
                  ),
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceLighter),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceLighter),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFilterButtons(
          options: const [
            _FilterOption('ALL', 'Todas'),
            _FilterOption('API', 'Na API'),
          ],
          selected: _scopeFilter,
          onSelected: (value) {
            setState(() => _scopeFilter = value);
            _loadSeries();
          },
        ),
        const SizedBox(height: 8),
        _buildFilterButtons(
          options: const [
            _FilterOption('IN_PRODUCTION', 'Em produção'),
            _FilterOption('DRAFT', 'Rascunhos'),
          ],
          selected: _statusFilter,
          allowDeselect: true,
          onSelected: (value) {
            setState(() => _statusFilter = value);
            _loadSeries();
          },
        ),
      ],
    );
  }

  Widget _buildFilterButtons({
    required List<_FilterOption> options,
    required String selected,
    required ValueChanged<String> onSelected,
    bool allowDeselect = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _StudioFilterButton(
            label: option.label,
            selected: selected == option.value,
            onTap: () {
              if (allowDeselect && selected == option.value) {
                onSelected('ALL');
              } else {
                onSelected(option.value);
              }
            },
          ),
      ],
    );
  }

  Widget _buildRemoteWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(65)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'A API nao respondeu. Atualize para carregar as series do catalogo.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSeries(ProductionCatalogItem series) async {
    await context.push(
      '/admin-production/${series.routeId}',
      extra: series,
    );
    if (mounted) await _loadSeries();
  }

  Future<void> _openNewMicroDramaStudio() async {
    final project = await _localService.createMicroDramaChatDraft();
    if (!mounted) return;
    await context.push(
      '/admin-production/${project.virtualId}',
      extra: ProductionCatalogItem.fromLocal(project),
    );
    if (mounted) await _loadSeries();
  }

  Widget _buildMessage(IconData icon, String message) {
    return Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FilterOption {
  final String value;
  final String label;

  const _FilterOption(this.value, this.label);
}

class _StudioFilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StudioFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: selected ? AppColors.primary : AppColors.surface,
        foregroundColor: selected ? Colors.white : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.surfaceLighter,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _ProductionSeriesCard extends StatefulWidget {
  final ProductionCatalogItem series;
  final VoidCallback onTap;

  const _ProductionSeriesCard({required this.series, required this.onTap});

  @override
  State<_ProductionSeriesCard> createState() => _ProductionSeriesCardState();
}

class _ProductionSeriesCardState extends State<_ProductionSeriesCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final status = _statusMeta(series.status);
    final progress = series.progress.clamp(0.0, 1.0);
    final progressLabel = progress <= 0
        ? 'Nao iniciado'
        : '${(progress * 100).round()}%';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovering
                ? AppColors.primary.withAlpha(140)
                : AppColors.surfaceLighter,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCover(series),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  series.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(meta: status),
                            ],
                          ),
                          if (series.genre.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              series.genre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _Metric(
                                icon: Icons.movie_filter_outlined,
                                label:
                                    '${series.episodeCount}/${series.targetEpisodeCount} eps',
                              ),
                              _Metric(
                                icon: Icons.videocam_outlined,
                                label: series.completedTakeCount > 0
                                    ? '${series.completedTakeCount}/${series.takeCount} takes'
                                    : '${series.takeCount} takes',
                              ),
                              _Metric(
                                icon: Icons.photo_library_outlined,
                                label: '${series.referenceCount} refs',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    minHeight: 5,
                                    value: progress,
                                    backgroundColor: AppColors.surfaceLighter,
                                    valueColor: AlwaysStoppedAnimation(
                                      status.color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                progressLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _coverHasImage(ProductionCatalogItem series) {
    return series.coverAssetPath?.trim().isNotEmpty == true ||
        series.coverUrl?.trim().isNotEmpty == true;
  }

  Future<void> _openCoverFullscreen(ProductionCatalogItem series) {
    return showFullscreenImageViewer(
      context,
      images: [
        FullscreenImageSource(
          title: series.title,
          subtitle: 'Capa da série',
          assetPath: series.coverAssetPath,
          networkUrl: series.coverUrl,
        ),
      ],
    );
  }

  Widget _buildCover(ProductionCatalogItem series) {
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 90,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (series.coverAssetPath != null)
              Image.asset(
                series.coverAssetPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _CoverFallback(series: series),
              )
            else if (series.coverUrl?.isNotEmpty ?? false)
              CachedNetworkImage(
                imageUrl: series.coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _CoverFallback(series: series),
              )
            else
              _CoverFallback(series: series),
          ],
        ),
      ),
    );
    if (!_coverHasImage(series)) return cover;
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openCoverFullscreen(series),
        child: cover,
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final ProductionCatalogItem series;

  const _CoverFallback({required this.series});

  @override
  Widget build(BuildContext context) {
    final hue = series.title.codeUnits.fold<int>(0, (sum, item) => sum + item);
    final color = HSVColor.fromAHSV(
      1,
      (hue % 360).toDouble(),
      0.55,
      0.58,
    ).toColor();
    final initials = series.title
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, AppColors.surface],
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? 'V' : initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _StatusMeta {
  final String label;
  final Color color;

  const _StatusMeta(this.label, this.color);
}

_StatusMeta _statusMeta(String status) {
  switch (status) {
    case 'IN_PRODUCTION':
      return const _StatusMeta('Em producao', AppColors.primary);
    case 'PUBLISHED':
      return const _StatusMeta('Publicada', AppColors.success);
    case 'ARCHIVED':
      return const _StatusMeta('Arquivada', AppColors.textTertiary);
    case 'DRAFT':
    default:
      return const _StatusMeta('Rascunho', AppColors.warning);
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusMeta meta;

  const _StatusBadge({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: meta.color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          color: meta.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
