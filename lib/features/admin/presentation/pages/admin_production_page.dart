import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class AdminProductionPage extends StatefulWidget {
  const AdminProductionPage({super.key});

  @override
  State<AdminProductionPage> createState() => _AdminProductionPageState();
}

class _AdminProductionPageState extends State<AdminProductionPage> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminSeriesSummary> _series = [];
  bool _isLoading = true;
  String _statusFilter = 'ALL';
  String? _error;

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

    final response = await _adminService.getAvailableSeries(
      status: _statusFilter,
      search: _searchController.text,
    );

    if (!mounted) return;
    setState(() {
      _series = response.data;
      _isLoading = false;
      _error = response.success ? null : 'Erro ao carregar producoes';
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
              ..._series.map(_buildSeriesCard),
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
                const Text(
                  'Series em producao',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prompts, takes, assets e pontos da pipeline.',
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip('ALL', 'Todas'),
        _buildFilterChip('DRAFT', 'Rascunhos'),
        _buildFilterChip('PUBLISHED', 'Publicadas'),
        _buildFilterChip('ARCHIVED', 'Arquivadas'),
      ],
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

  Widget _buildSeriesCard(AdminSeriesSummary series) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              context.push('/admin-production/${series.id}', extra: series),
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
                    child: series.coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: series.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.movie),
                          )
                        : const Icon(Icons.movie),
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
                          _buildInfoPill(series.status),
                          _buildInfoPill(series.genre),
                          _buildInfoPill('${series.episodeCount} eps'),
                          _buildInfoPill('${series.referenceCount} assets'),
                          _buildInfoPill('${series.storyPointCount} pontos'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        series.hasProductionPlan
                            ? 'Pipeline: ${series.productionPlan!.source}'
                            : 'Sem pipeline salva',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: series.hasProductionPlan
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
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
