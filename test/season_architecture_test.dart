import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';
import 'package:vertix/core/services/season_architecture.dart';

const _config = MicroDramaProjectConfig(
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
  maxShotDurationSeconds: 10,
);

void main() {
  test('8-episode series reserves paywall and does not spend the finale early', () {
    final profile = SeasonArchitecture.buildRetentionProfile(episodeCount: 8);
    expect(profile.paywallEpisode, 3);
    expect(profile.payoffAfterPaywallEpisode, 5);
    expect(profile.centralQuestionPayoffWindow, '7-8');

    final blocks = SeasonArchitecture.plannedSeasonBlocks(8, profile.paywallEpisode);
    expect(SeasonArchitecture.blockForEpisode(blocks, 1)?.id, 'premise_hook');
    expect(
      SeasonArchitecture.blockForEpisode(blocks, 3)?.conversionRole,
      'paywall_cliffhanger',
    );
    expect(SeasonArchitecture.blockForEpisode(blocks, 4)?.id, 'paid_payoff');
    expect(SeasonArchitecture.blockForEpisode(blocks, 8)?.id, 'ceiling');
    for (var episode = 1; episode <= 8; episode++) {
      expect(SeasonArchitecture.blockForEpisode(blocks, episode), isNotNull);
    }
  });

  test('60-episode series plans funnel, dark middle and ceiling', () {
    final profile = SeasonArchitecture.buildRetentionProfile(episodeCount: 60);
    expect(profile.paywallEpisode, 8);
    expect(profile.payoffAfterPaywallEpisode, 10);
    expect(profile.centralQuestionPayoffWindow, '49-60');

    final blocks = SeasonArchitecture.plannedSeasonBlocks(60, profile.paywallEpisode);
    expect(
      SeasonArchitecture.blockForEpisode(blocks, 8)?.conversionRole,
      'paywall_cliffhanger',
    );
    expect(SeasonArchitecture.blockForEpisode(blocks, 9)?.id, 'paid_payoff');
    expect(SeasonArchitecture.blockForEpisode(blocks, 20)?.id, 'escalation');
    expect(SeasonArchitecture.blockForEpisode(blocks, 40)?.id, 'dark_middle');
    expect(SeasonArchitecture.blockForEpisode(blocks, 55)?.id, 'ceiling');
  });

  test('beat engine cuts the button in the last seconds', () {
    final sixty = SeasonArchitecture.beatEngineForDuration(60);
    expect(sixty.hook, '0-12s');
    expect(sixty.button, '54-60s');
    expect(sixty.freezeFrameCheck, '3s');
    final first = SeasonArchitecture.beatEngineForDuration(120);
    expect(first.hook, '0-15s');
    expect(first.button, '110-120s');
  });

  test('local builder seeds architecture, spine and reserved reveals', () {
    final service = LocalProductionWorkspaceService();
    final project = service.buildMicroDramaProjectForTesting(_config);
    final architecture =
        project.seriesBible['season_architecture'] as Map<dynamic, dynamic>;
    expect(architecture['paywall_episode'], 3);
    expect(project.seriesBible['episode_spine'], hasLength(8));
    expect(project.seriesBible['reserved_reveals'], isNotEmpty);
    final cards = (project.seriesBible['episode_cards'] as List)
        .whereType<Map>()
        .toList();
    expect(cards[2]['paywall_role'], 'paywall_cliffhanger');
    expect(cards.first['beat_engine'], isA<Map>());
    expect(
      cards.first['withheld_answer'].toString(),
      contains('central_question'),
    );
  });
}
