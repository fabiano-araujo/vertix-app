import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';

class AdminProductionDetailPage extends StatefulWidget {
  final int seriesId;
  final AdminSeriesSummary? summary;

  const AdminProductionDetailPage({
    super.key,
    required this.seriesId,
    this.summary,
  });

  @override
  State<AdminProductionDetailPage> createState() =>
      _AdminProductionDetailPageState();
}

class _AdminProductionDetailPageState extends State<AdminProductionDetailPage> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();

  AdminSeriesProductionPlan? _production;
  bool _isLoading = true;
  String? _error;

  bool get _isAdmin => _authService.currentUser?.isAdmin == true;

  @override
  void initState() {
    super.initState();
    _loadProduction();
  }

  Future<void> _loadProduction() async {
    if (!_isAdmin) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _adminService.getSeriesProduction(widget.seriesId);

    if (!mounted) return;
    setState(() {
      _production = response.data;
      _isLoading = false;
      _error = response.success
          ? null
          : response.message ?? 'Dados de producao nao encontrados';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return _buildUnauthorized();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(widget.summary?.title ?? 'Producao'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProduction,
              tooltip: 'Atualizar',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Visao'),
              Tab(text: 'Prompts'),
              Tab(text: 'Assets'),
              Tab(text: 'JSON'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? _buildError()
            : _buildTabs(),
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProduction,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final production = _production;
    if (production == null) return const SizedBox.shrink();

    return TabBarView(
      children: [
        _buildOverviewTab(production),
        _buildPromptsTab(production),
        _buildAssetsTab(production),
        _buildJsonTab(production),
      ],
    );
  }

  Widget _buildOverviewTab(AdminSeriesProductionPlan production) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildSummaryHeader(production),
        const SizedBox(height: 16),
        _buildValueSection('Series bible', production.seriesBible),
        _buildValueSection('Personagens', production.characterBible),
        _buildValueSection('Locacoes', production.locationBible),
        _buildValueSection('Objetos', production.objectBible),
        _buildValueSection('Mapa espacial', production.spatialMaps),
        _buildValueSection('Audio', production.audioBible),
        _buildValueSection('Arco da temporada', production.seasonArc),
        _buildValueSection('Mapa de episodios', production.episodeMap),
        _buildValueSection('Tratamentos', production.episodeTreatments),
        _buildValueSection('Storyboards', production.storyboardPlan),
        _buildValueSection('Notas Seedance', production.seedanceNotes),
      ],
    );
  }

  Widget _buildSummaryHeader(AdminSeriesProductionPlan production) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.summary?.title ?? 'Serie ${production.seriesId}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildPill(production.source, AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill('${production.referenceAssets.length} assets'),
              _buildPill('${production.storyPoints.length} pontos'),
              _buildPill('${_prompts(production).length} prompts'),
              _buildPill('${_takes(production).length} takes'),
            ],
          ),
          if (widget.summary?.description.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(
              widget.summary!.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptsTab(AdminSeriesProductionPlan production) {
    final prompts = _prompts(production);
    final takes = _takes(production);
    final others = production.storyPoints
        .where((point) => !point.isPrompt && !point.isTake)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildPointGroup('Prompts Seedance', prompts),
        _buildPointGroup('Takes e cenas', takes),
        _buildPointGroup('Outros pontos da pipeline', others),
      ],
    );
  }

  Widget _buildPointGroup(String title, List<AdminStoryPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        ...points.map(_buildStoryPointCard),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildStoryPointCard(AdminStoryPoint point) {
    final meta = [
      if (point.episodeNumber != null) 'Ep ${point.episodeNumber}',
      if (point.sceneNumber != null) 'Cena ${point.sceneNumber}',
      if (point.segment != null) point.segment!,
    ].join(' / ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  point.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildCopyButton(_formatValue(point.body)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(point.pointType),
              if (meta.isNotEmpty) _buildPill(meta),
            ],
          ),
          const SizedBox(height: 12),
          _buildSelectableBlock(point.body),
          if (_hasValue(point.metadata)) ...[
            const SizedBox(height: 12),
            _buildValueSection('Metadata', point.metadata, compact: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetsTab(AdminSeriesProductionPlan production) {
    if (production.referenceAssets.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum asset salvo',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: production.referenceAssets.length,
      itemBuilder: (context, index) {
        return _buildAssetCard(
          production.referenceAssets[index],
          assets: production.referenceAssets,
        );
      },
    );
  }

  Widget _buildAssetCard(
    AdminReferenceAsset asset, {
    List<AdminReferenceAsset> assets = const [],
  }) {
    if (asset.isVideo && asset.publicUrl.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLighter),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AssetVideoPreview(url: asset.publicUrl),
            const SizedBox(height: 12),
            _buildAssetDetails(asset),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 92,
              height: 92,
              color: AppColors.surfaceLight,
              child: asset.isImage && asset.publicUrl.isNotEmpty
                  ? MouseRegion(
                      cursor: SystemMouseCursors.zoomIn,
                      child: GestureDetector(
                        onTap: () => _openAssetFullscreen(asset, assets),
                        child: CachedNetworkImage(
                          imageUrl: asset.publicUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _assetFallback(asset),
                        ),
                      ),
                    )
                  : _assetFallback(asset),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildAssetDetails(asset),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetDetails(AdminReferenceAsset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                asset.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildCopyButton(asset.publicUrl),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPill(asset.category),
            if (asset.contentType != null) _buildPill(asset.contentType!),
            if (asset.episodeId != null) _buildPill('Ep ${asset.episodeId}'),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          asset.publicUrl,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        if (_hasValue(asset.prompt)) ...[
          const SizedBox(height: 10),
          _buildValueSection(
            'Prompt do asset',
            asset.prompt,
            compact: true,
          ),
        ],
        if (_hasValue(asset.metadata)) ...[
          const SizedBox(height: 10),
          _buildValueSection('Metadata', asset.metadata, compact: true),
        ],
      ],
    );
  }

  Future<void> _openAssetFullscreen(
    AdminReferenceAsset asset,
    List<AdminReferenceAsset> assets,
  ) {
    final images = assets
        .where((item) => item.isImage && item.publicUrl.trim().isNotEmpty)
        .toList();
    if (images.isEmpty) {
      images.add(asset);
    }
    var index = images.indexWhere((item) => item.id == asset.id);
    if (index < 0) {
      images.insert(0, asset);
      index = 0;
    }
    return showFullscreenImageViewer(
      context,
      images: images
          .map(
            (item) => FullscreenImageSource(
              title: item.label,
              subtitle: item.category,
              networkUrl: item.publicUrl,
            ),
          )
          .toList(),
      initialIndex: index,
    );
  }

  Widget _assetFallback(AdminReferenceAsset asset) {
    return Icon(
      asset.isVideo ? Icons.movie : Icons.image_outlined,
      color: AppColors.textSecondary,
      size: 34,
    );
  }

  Widget _buildJsonTab(AdminSeriesProductionPlan production) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildValueSection('Raw payload', production.rawPayload),
        _buildValueSection('Plano completo', production.toJson()),
      ],
    );
  }

  Widget _buildValueSection(
    String title,
    dynamic value, {
    bool compact = false,
  }) {
    if (!_hasValue(value)) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 12),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: compact ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildCopyButton(_formatValue(value)),
            ],
          ),
          const SizedBox(height: 10),
          _buildSelectableBlock(value),
        ],
      ),
    );
  }

  Widget _buildSelectableBlock(dynamic value) {
    return SelectableText(
      _formatValue(value),
      style: const TextStyle(
        color: AppColors.textSecondary,
        height: 1.35,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildPill(String text, [Color? color]) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCopyButton(String text) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 18),
      color: AppColors.textSecondary,
      visualDensity: VisualDensity.compact,
      onPressed: text.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copiado')));
            },
    );
  }

  List<AdminStoryPoint> _prompts(AdminSeriesProductionPlan production) {
    return production.storyPoints.where((point) => point.isPrompt).toList();
  }

  List<AdminStoryPoint> _takes(AdminSeriesProductionPlan production) {
    return production.storyPoints.where((point) => point.isTake).toList();
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}

class _AssetVideoPreview extends StatefulWidget {
  final String url;

  const _AssetVideoPreview({required this.url});

  @override
  State<_AssetVideoPreview> createState() => _AssetVideoPreviewState();
}

class _AssetVideoPreviewState extends State<_AssetVideoPreview> {
  late final VideoPlayerController _controller;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      if (!mounted) return;
      setState(() => _isReady = true);
      _controller.addListener(_handleVideoChange);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Nao foi possivel carregar o video');
    }
  }

  void _handleVideoChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleVideoChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller.value.isPlaying;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _isReady ? _controller.value.aspectRatio : 16 / 9,
        child: Container(
          color: Colors.black,
          child: _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : !_isReady
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_controller),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        },
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(160),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
