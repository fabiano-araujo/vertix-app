import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/local_production_workspace_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/micro_drama_creation_dialog.dart';

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
  String _statusFilter = 'ALL';
  String _sourceFilter = 'ALL';
  String? _error;
  bool _remoteUnavailable = false;

  bool get _isAdmin => _authService.currentUser?.isAdmin == true;

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

    final localFuture = _localService.getLocalCatalog();
    final remoteFuture = _adminService.getAvailableSeries(
      status: _statusFilter,
      search: _searchController.text,
    );
    final localItems = await localFuture;
    final remoteResponse = await remoteFuture;

    final query = _searchController.text.trim().toLowerCase();
    final filteredLocal = localItems.where((item) {
      final statusMatches =
          _statusFilter == 'ALL' || item.status == _statusFilter;
      final searchMatches =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.genre.toLowerCase().contains(query) ||
          (item.sourcePath?.toLowerCase().contains(query) ?? false);
      return statusMatches && searchMatches;
    });
    final remoteItems = remoteResponse.data.map(
      ProductionCatalogItem.fromRemote,
    );
    final merged =
        <ProductionCatalogItem>[
          if (_sourceFilter != 'REMOTE') ...filteredLocal,
          if (_sourceFilter != 'LOCAL') ...remoteItems,
        ]..sort((a, b) {
          if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
          return a.title.compareTo(b.title);
        });

    if (!mounted) return;
    setState(() {
      _series = merged;
      _isLoading = false;
      _remoteUnavailable = !remoteResponse.success;
      _error = merged.isEmpty && !remoteResponse.success
          ? 'Nao foi possivel carregar producoes'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return _buildUnauthorized();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Producoes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: _showCreateProjectDialog,
            tooltip: 'Criar microdrama',
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _buildHeader(),
            if (_remoteUnavailable) ...[
              const SizedBox(height: 12),
              _buildRemoteWarning(),
            ],
            const SizedBox(height: 16),
            _buildSearch(),
            const SizedBox(height: 14),
            _buildFilters(),
            const SizedBox(height: 16),
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
                  final columns = constraints.maxWidth >= 880 ? 2 : 1;
                  final width = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _series
                        .map(
                          (series) => SizedBox(
                            width: width,
                            child: _buildSeriesCard(series),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_series.length} obras no studio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Microdramas do contrato narrativo à produção em vídeo.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: AppColors.textPrimary),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _loadSeries(),
      decoration: InputDecoration(
        hintText: 'Buscar serie, genero ou descricao',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: _loadSeries,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSourceChip('ALL', 'Tudo'),
            _buildSourceChip('LOCAL', 'Workspace local'),
            _buildSourceChip('REMOTE', 'Vertix API'),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('ALL', 'Todos os status'),
            _buildFilterChip('IN_PRODUCTION', 'Em producao'),
            _buildFilterChip('DRAFT', 'Rascunhos'),
            _buildFilterChip('PUBLISHED', 'Publicadas'),
            _buildFilterChip('ARCHIVED', 'Arquivadas'),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceChip(String value, String label) {
    final selected = _sourceFilter == value;
    return ChoiceChip(
      avatar: Icon(
        value == 'LOCAL' ? Icons.computer : Icons.cloud_outlined,
        size: 16,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary.withAlpha(50),
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() => _sourceFilter = value);
        _loadSeries();
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary.withAlpha(50),
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _loadSeries();
      },
    );
  }

  Widget _buildSeriesCard(ProductionCatalogItem series) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/admin-production/${series.routeId}', extra: series),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 68,
                  height: 92,
                  color: AppColors.surfaceLight,
                  child: series.coverAssetPath != null
                      ? Image.asset(
                          series.coverAssetPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildCoverFallback(series),
                        )
                      : (series.coverUrl?.isNotEmpty ?? false)
                      ? CachedNetworkImage(
                          imageUrl: series.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _buildCoverFallback(series),
                        )
                      : _buildCoverFallback(series),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoPill(
                          series.isLocal ? 'LOCAL' : 'API',
                          color: series.isLocal
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        _buildInfoPill(series.status),
                        _buildInfoPill(series.genre),
                        _buildInfoPill(
                          '${series.episodeCount}/${series.targetEpisodeCount} eps',
                        ),
                        _buildInfoPill('${series.referenceCount} assets'),
                        _buildInfoPill('${series.takeCount} takes'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      series.sourcePath ?? series.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: series.progress.clamp(0.0, 1.0),
                              backgroundColor: AppColors.surfaceLighter,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(series.progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFallback(ProductionCatalogItem series) {
    final hue = series.title.codeUnits.fold<int>(0, (sum, item) => sum + item);
    final color = HSVColor.fromAHSV(
      1,
      (hue % 360).toDouble(),
      0.65,
      0.72,
    ).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(180), AppColors.surface],
        ),
      ),
      child: const Center(child: Icon(Icons.movie_creation_outlined, size: 30)),
    );
  }

  Widget _buildInfoPill(String text, {Color? color}) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: effectiveColor, fontSize: 11)),
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
              'A API nao respondeu. Os projetos e as edicoes locais continuam disponiveis.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateProjectDialog() async {
    final config = await showDialog<MicroDramaProjectConfig>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MicroDramaCreationDialog(),
    );
    if (config == null || !mounted) return;
    final project = await _localService.createMicroDramaProject(config);
    if (!mounted) return;
    await _loadSeries();
    if (!mounted) return;
    context.push(
      '/admin-production/${project.virtualId}',
      extra: ProductionCatalogItem.fromLocal(project),
    );
  }

  Widget _buildMessage(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
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
