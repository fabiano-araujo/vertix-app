import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';

void main() {
  test('generated manifest replaces simulations and exposes review media', () {
    final project = ProductionProject(
      id: 'test-series',
      virtualId: -1,
      title: 'Test Series',
      description: '',
      genre: 'test',
      formatFamily: 'vertical_series',
      status: 'IN_PRODUCTION',
      sourcePath: 'test',
      targetEpisodeCount: 1,
      isLocal: true,
      updatedAt: DateTime(2026),
      seriesBible: const {},
      references: const [],
      episodes: const [
        ProductionEpisodeItem(
          number: 1,
          title: 'Episode',
          summary: '',
          cliffhanger: '',
          durationSeconds: 20,
          takes: [
            ProductionTakeItem(
              id: 'take-1',
              number: 1,
              title: 'One',
              durationSeconds: 10,
              status: 'COMPLETED',
              progress: 1,
              outputUrl: 'local://simulation/take-1.mp4',
            ),
            ProductionTakeItem(
              id: 'take-2',
              number: 2,
              title: 'Two',
              durationSeconds: 10,
              status: 'COMPLETED',
              progress: 1,
              outputUrl: 'local://simulation/take-2.mp4',
            ),
          ],
        ),
      ],
    );

    final merged = LocalProductionWorkspaceService().mergeGeneratedManifestForTesting(
      project,
      {
        'projectId': 'test-series',
        'updatedAt': '2026-08-11T01:00:00-03:00',
        'manifestUrl': '/generated-production/test-series/manifest.json',
        'episodes': [
          {
            'number': 1,
            'assembledOutputUrl':
                '/generated-production/test-series/episode-01/assembled.mp4',
            'takes': [
              {
                'number': 1,
                'status': 'COMPLETED',
                'progress': 1,
                'outputUrl':
                    '/generated-production/test-series/episode-01/take-01.mp4',
                'lastFrameUrl':
                    '/generated-production/test-series/episode-01/take-01-last.png',
                'contactSheetUrl':
                    '/generated-production/test-series/episode-01/take-01-contact.jpg',
                'pencilFrameUrl':
                    '/generated-production/test-series/episode-01/take-01-last-pencil.png',
                'continuitySheetUrl':
                    '/generated-production/test-series/episode-01/take-01-continuity.jpg',
              },
            ],
          },
        ],
      },
    );

    final episode = merged.episodes.single;
    expect(episode.durationSeconds, 20);
    expect(episode.status, 'IN_PROGRESS');
    expect(
      episode.assembledOutputUrl,
      '/generated-production/test-series/episode-01/assembled.mp4',
    );
    expect(episode.takes.first.status, 'COMPLETED');
    expect(
      episode.takes.first.outputUrl,
      '/generated-production/test-series/episode-01/take-01.mp4',
    );
    expect(episode.takes.last.status, 'READY');
    expect(episode.takes.last.outputUrl, isNull);
    expect(merged.references, hasLength(4));
    expect(
      merged.references.map((item) => item.category),
      containsAll([
        'GENERATED_REVIEW',
        'GENERATED_LAST_FRAME',
        'GENERATED_CONTINUITY_FRAME',
        'GENERATED_CONTINUITY_SHEET',
      ]),
    );
  });
}
