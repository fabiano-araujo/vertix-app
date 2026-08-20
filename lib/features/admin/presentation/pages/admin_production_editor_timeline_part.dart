part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorTimelineExtension
    on _AdminProductionEditorPageState {
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
                onPressed: episode.takes.isEmpty ? null : _showEpisodePreview,
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
              _pill('video com audio'),
              _pill('musica separada'),
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
    final generatingCover =
        _activeCoverImageStatus == 'GENERATING' ||
        _activeCoverImageStatus == 'UPLOADING';
    Widget preview;
    if (project.coverAssetPath?.isNotEmpty == true) {
      preview = Image.asset(
        project.coverAssetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _projectPreviewFallback(),
      );
    } else if (project.coverUrl?.isNotEmpty == true) {
      preview = CachedNetworkImage(
        imageUrl: project.coverUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _projectPreviewFallback(),
      );
    } else {
      preview = _projectPreviewFallback();
    }
    if (!generatingCover && _activeCoverImageStatus != 'PENDING') {
      return preview;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        ColoredBox(
          color: Colors.black.withAlpha(130),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (generatingCover)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.image_outlined, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  generatingCover
                      ? 'Gerando a arte da capa da série'
                      : 'Capa da série na fila',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                label: 'VIDEO + AUDIO',
                icon: Icons.movie_outlined,
                clips: video,
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
}
