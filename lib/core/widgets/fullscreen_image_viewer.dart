import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class FullscreenImageSource {
  const FullscreenImageSource({
    this.title,
    this.subtitle,
    this.networkUrl,
    this.assetPath,
  });

  final String? title;
  final String? subtitle;
  final String? networkUrl;
  final String? assetPath;

  bool get hasImage =>
      (networkUrl?.trim().isNotEmpty ?? false) ||
      (assetPath?.trim().isNotEmpty ?? false);
}

Future<void> showFullscreenImageViewer(
  BuildContext context, {
  required List<FullscreenImageSource> images,
  int initialIndex = 0,
}) {
  final items = images.where((image) => image.hasImage).toList();
  if (items.isEmpty) return Future.value();
  final index = initialIndex.clamp(0, items.length - 1);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (context, _, __) {
        return FullscreenImageViewer(
          images: items,
          initialIndex: index,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<FullscreenImageSource> images;
  final int initialIndex;

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  static const _minScale = 1.0;
  static const _maxScale = 8.0;

  late final PageController _pageController;
  late final TransformationController _transform;
  late int _index;
  double _scale = 1;
  int _quarterTurns = 0;
  Offset? _doubleTapLocal;
  Size _viewport = Size.zero;

  FullscreenImageSource get _current => widget.images[_index];
  bool get _canPage => widget.images.length > 1 && _scale <= 1.02;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _index);
    _transform = TransformationController()..addListener(_handleTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_handleTransform);
    _transform.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleTransform() {
    final next = _transform.value.getMaxScaleOnAxis();
    final nextPercent = (next * 100).round();
    final currentPercent = (_scale * 100).round();
    final panChanged = (next > 1.05) != (_scale > 1.05);
    if (nextPercent == currentPercent && !panChanged) return;
    setState(() => _scale = next);
  }

  void _resetView() {
    _transform.value = Matrix4.identity();
    setState(() {
      _scale = 1;
      _quarterTurns = 0;
    });
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  void _nudgeZoom(double factor, {Offset? focalPoint}) {
    _applyScale(_scale * factor, focalPoint: focalPoint);
  }

  void _applyScale(double nextScale, {Offset? focalPoint}) {
    final clamped = nextScale.clamp(_minScale, _maxScale);
    final current = _transform.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale == 0 || (clamped - currentScale).abs() < 0.001) return;
    final factor = clamped / currentScale;
    final focal =
        focalPoint ?? Offset(_viewport.width / 2, _viewport.height / 2);
    final inverse = Matrix4.tryInvert(current.clone());
    if (inverse == null) return;
    final sceneFocal = MatrixUtils.transformPoint(inverse, focal);
    current
      ..translateByDouble(sceneFocal.dx, sceneFocal.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-sceneFocal.dx, -sceneFocal.dy, 0, 1);
    _transform.value = current;
  }

  void _handleDoubleTap() {
    final focal = _doubleTapLocal;
    if (_scale > 1.15) {
      _resetView();
      return;
    }
    _applyScale(3, focalPoint: focal);
  }

  void _goTo(int page) {
    if (page < 0 || page >= widget.images.length || page == _index) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int page) {
    _transform.value = Matrix4.identity();
    setState(() {
      _index = page;
      _scale = 1;
      _quarterTurns = 0;
    });
  }

  Future<void> _openOriginal() async {
    final url = _current.networkUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = _current.title?.trim().isNotEmpty == true
        ? _current.title!
        : 'Imagem';
    final subtitle = _current.subtitle?.trim();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goTo(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goTo(_index + 1),
        const SingleActivator(LogicalKeyboardKey.equal): () => _nudgeZoom(1.25),
        const SingleActivator(LogicalKeyboardKey.add): () => _nudgeZoom(1.25),
        const SingleActivator(LogicalKeyboardKey.numpadAdd): () =>
            _nudgeZoom(1.25),
        const SingleActivator(LogicalKeyboardKey.minus): () =>
            _nudgeZoom(1 / 1.25),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): () =>
            _nudgeZoom(1 / 1.25),
        const SingleActivator(LogicalKeyboardKey.digit0): _resetView,
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
          _transform.value = Matrix4.identity();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final zoom = event.scrollDelta.dy < 0 ? 1.12 : 0.89;
                          _nudgeZoom(zoom, focalPoint: event.localPosition);
                        }
                      },
                      child: PageView.builder(
                        controller: _pageController,
                        physics: _canPage
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        itemCount: widget.images.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onDoubleTapDown: (details) {
                              _doubleTapLocal = details.localPosition;
                            },
                            onDoubleTap: _handleDoubleTap,
                            child: InteractiveViewer(
                              transformationController: index == _index
                                  ? _transform
                                  : null,
                              minScale: _minScale,
                              maxScale: _maxScale,
                              panEnabled: _scale > 1.05,
                              child: SizedBox.expand(
                                child: RotatedBox(
                                  quarterTurns: index == _index
                                      ? _quarterTurns
                                      : 0,
                                  child: _FullscreenImage(
                                    source: widget.images[index],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  left: 12,
                  right: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            if (subtitle?.isNotEmpty == true ||
                                widget.images.length > 1)
                              Text(
                                [
                                  if (subtitle?.isNotEmpty == true) subtitle,
                                  if (widget.images.length > 1)
                                    '${_index + 1} de ${widget.images.length}',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _ViewerIconButton(
                        tooltip: 'Fechar',
                        icon: Icons.close,
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
                if (widget.images.length > 1 && _canPage) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ViewerIconButton(
                        tooltip: 'Anterior',
                        icon: Icons.chevron_left,
                        onPressed: _index == 0
                            ? null
                            : () => _goTo(_index - 1),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ViewerIconButton(
                        tooltip: 'Próxima',
                        icon: Icons.chevron_right,
                        onPressed: _index >= widget.images.length - 1
                            ? null
                            : () => _goTo(_index + 1),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              _ViewerIconButton(
                                tooltip: 'Diminuir',
                                icon: Icons.zoom_out,
                                compact: true,
                                onPressed: _scale <= _minScale
                                    ? null
                                    : () => _nudgeZoom(1 / 1.25),
                              ),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '${(_scale * 100).round()}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              _ViewerIconButton(
                                tooltip: 'Aumentar',
                                icon: Icons.zoom_in,
                                compact: true,
                                onPressed: _scale >= _maxScale
                                    ? null
                                    : () => _nudgeZoom(1.25),
                              ),
                              _ViewerIconButton(
                                tooltip: 'Ajustar à tela',
                                icon: Icons.fit_screen_outlined,
                                compact: true,
                                onPressed: _resetView,
                              ),
                              _ViewerIconButton(
                                tooltip: 'Girar',
                                icon: Icons.rotate_90_degrees_cw_outlined,
                                compact: true,
                                onPressed: () {
                                  setState(
                                    () => _quarterTurns = (_quarterTurns + 1) % 4,
                                  );
                                  _transform.value = Matrix4.identity();
                                },
                              ),
                              if (_current.networkUrl?.trim().isNotEmpty ==
                                  true)
                                _ViewerIconButton(
                                  tooltip: 'Abrir original',
                                  icon: Icons.open_in_new,
                                  compact: true,
                                  onPressed: _openOriginal,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.source});

  final FullscreenImageSource source;

  @override
  Widget build(BuildContext context) {
    final assetPath = source.assetPath?.trim();
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _ImageError(),
      );
    }
    final networkUrl = source.networkUrl?.trim();
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => const _ImageError(),
      );
    }
    return const _ImageError();
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 42),
        SizedBox(height: 10),
        Text(
          'Não foi possível carregar a imagem',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  const _ViewerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        color: Colors.white,
        disabledColor: Colors.white24,
        icon: Icon(icon, size: compact ? 20 : 22),
      ),
    );
  }
}
