import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';

void main() {
  test('microdrama builder creates the guided narrative pipeline', () {
    final service = LocalProductionWorkspaceService();
    const config = MicroDramaProjectConfig(
      title: 'Segunda Chance',
      logline:
          'Uma chef reencontra o ex-noivo que agora controla o futuro do restaurante dela.',
      centralQuestion:
          'Ela revelará o segredo antes que a segunda chance destrua sua família?',
      protagonist: 'Marta',
      opposingForce: 'Helena',
      stakes: 'O restaurante fecha em 30 dias e o filho pode ser exposto.',
      genre: 'Romance com reviravolta',
      background: 'Cidade moderna',
      trope: 'Segunda chance',
      visualStyle: 'Microdrama moderno',
      language: 'Português (Brasil)',
      rating: '14 anos',
      episodeCount: 8,
      firstEpisodeDurationSeconds: 120,
      episodeDurationSeconds: 60,
    );

    final project = service.buildMicroDramaProjectForTesting(config);

    expect(project.formatFamily, 'micro_drama_vertical');
    expect(project.status, 'DRAFT');
    expect(project.targetEpisodeCount, 8);
    expect(project.episodes, hasLength(8));
    expect(project.references, hasLength(4));
    expect(project.episodes.first.durationSeconds, 120);
    expect(project.episodes.first.takes, hasLength(8));
    expect(project.episodes[1].takes, hasLength(4));
    expect(
      project.episodes.expand((episode) => episode.takes),
      everyElement(
        isA<ProductionTakeItem>()
            .having(
              (take) => take.durationSeconds,
              'duration',
              lessThanOrEqualTo(15),
            )
            .having(
              (take) => take.generateSeedanceAudio,
              'embedded audio',
              isTrue,
            )
            .having(
              (take) => take.usePreviousLastFrame,
              'no first frame',
              isFalse,
            ),
      ),
    );
    expect(
      project.seriesBible['audio_strategy'],
      contains('música permanece em faixa separada'),
    );
    expect(project.seriesBible['episode_cards'], isA<List<dynamic>>());
    expect(
      project.seriesBible['hook_chain'] as List<dynamic>,
      hasLength(project.episodes.length),
    );
    expect(
      project.episodes.every(
        (episode) =>
            episode.summary.isNotEmpty && episode.cliffhanger.isNotEmpty,
      ),
      isTrue,
    );
  });
}
