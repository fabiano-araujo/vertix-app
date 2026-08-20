part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorSharedExtension
    on _AdminProductionEditorPageState {
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

  Widget? _seriesCoverGenerationBanner() {
    if (!_isReferenceImageBusy || _activeCoverImageStatus == null) {
      return null;
    }
    final status = _activeCoverImageStatus!;
    final generating =
        status == 'GENERATING' || status == 'UPLOADING';
    final text = switch (status) {
      'GENERATING' => 'Gerando a arte da capa da série...',
      'UPLOADING' => 'Enviando a arte da capa da série...',
      'COMPLETED' => 'Arte da capa da série pronta.',
      'FAILED' => 'Não foi possível gerar a arte da capa da série.',
      _ => 'A arte da capa da série entra em seguida nesta tarefa.',
    };
    final color = switch (status) {
      'COMPLETED' => AppColors.success,
      'FAILED' => AppColors.error,
      _ => AppColors.primaryLight,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withAlpha(28),
      child: Row(
        children: [
          if (generating)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(
              status == 'COMPLETED'
                  ? Icons.check_circle_outline
                  : Icons.image_outlined,
              size: 18,
              color: color,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCoverStatusCard() {
    final project = _project;
    final generating =
        _activeCoverImageStatus == 'GENERATING' ||
        _activeCoverImageStatus == 'UPLOADING';
    final queued = _isReferenceImageBusy &&
        (_activeCoverImageStatus == 'PENDING' || generating);
    final hasCover = project?.coverUrl?.trim().isNotEmpty == true ||
        project?.coverAssetPath?.trim().isNotEmpty == true;
    final statusText = generating
        ? 'Gerando a arte da capa da série...'
        : _activeCoverImageStatus == 'PENDING'
        ? 'A arte da capa da série entra em seguida nesta tarefa.'
        : _activeCoverImageStatus == 'FAILED'
        ? 'Não foi possível gerar a arte da capa da série.'
        : hasCover
        ? 'Capa atual da série no catálogo.'
        : 'Ainda não há arte de capa. Use “Obra inteira” para gerar fichas, imagens e a capa.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seriesCoverPreview(openOnTap: hasCover && !queued),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                generating ? 'Gerando a arte da capa da série' : 'Arte da capa',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                statusText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seriesCoverPreview({bool openOnTap = false}) {
    final generating =
        _activeCoverImageStatus == 'GENERATING' ||
        _activeCoverImageStatus == 'UPLOADING';
    final queued = _isReferenceImageBusy &&
        (_activeCoverImageStatus == 'PENDING' || generating);
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 78,
        height: 112,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _seriesCoverPreviewImage(),
            if (queued)
              ColoredBox(
                color: Colors.black.withAlpha(140),
                child: Center(
                  child: generating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.hourglass_top,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!openOnTap) return preview;
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openSeriesCoverFullscreen,
        child: preview,
      ),
    );
  }

  Future<void> _openSeriesCoverFullscreen() {
    final project = _project;
    if (project == null) return Future.value();
    final coverUrl = project.coverUrl?.trim();
    return showFullscreenImageViewer(
      context,
      images: [
        FullscreenImageSource(
          title: project.title,
          subtitle: 'Capa da série',
          assetPath: project.coverAssetPath,
          networkUrl: coverUrl == null || coverUrl.isEmpty
              ? null
              : _resolveProductionMediaUrl(coverUrl),
        ),
      ],
    );
  }

  Widget _seriesCoverPreviewImage() {
    final project = _project;
    if (project?.coverAssetPath?.isNotEmpty == true) {
      return Image.asset(
        project!.coverAssetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _seriesCoverPreviewFallback(),
      );
    }
    if (project?.coverUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: _resolveProductionMediaUrl(project!.coverUrl!),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _seriesCoverPreviewFallback(),
      );
    }
    return _seriesCoverPreviewFallback();
  }

  Widget _seriesCoverPreviewFallback() => const ColoredBox(
    color: Color(0xFF1B2230),
    child: Center(
      child: Icon(
        Icons.movie_creation_outlined,
        color: AppColors.primaryLight,
        size: 28,
      ),
    ),
  );

  Color _statusColor(String status) => switch (status.toUpperCase()) {
    'COMPLETED' || 'PUBLISHED' || 'PRONTO' => AppColors.success,
    'GENERATING' || 'IN_PROGRESS' || 'IN_PRODUCTION' => AppColors.primary,
    'QUEUED' || 'READY' || 'EDITAVEL' => AppColors.warning,
    'FAILED' || 'ERROR' => AppColors.error,
    _ => AppColors.textSecondary,
  };
}
