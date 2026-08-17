import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';

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
  test('microdrama builder creates the outline before scene scripts', () {
    final service = LocalProductionWorkspaceService();
    final project = service.buildMicroDramaProjectForTesting(_config);

    expect(project.formatFamily, 'micro_drama_vertical');
    expect(project.status, 'DRAFT');
    expect(project.targetEpisodeCount, 8);
    expect(project.episodes, hasLength(8));
    expect(project.references, hasLength(14));
    expect(project.episodes.first.durationSeconds, 120);
    expect(project.episodes.every((episode) => episode.takes.isEmpty), isTrue);
    expect(
      project.seriesBible['audio_strategy'],
      contains('música permanece em faixa separada'),
    );
    final episodeCards = project.seriesBible['episode_cards'] as List<dynamic>;
    expect(episodeCards, hasLength(8));
    expect(episodeCards.first['stage_goal'], isNotEmpty);
    expect(episodeCards.first['emotional_beat'], isNotEmpty);
    expect(episodeCards.first['value_shift'], isNotEmpty);
    expect(episodeCards.first['script_status'], 'NOT_STARTED');
    expect(project.seriesBible['characters'] as List<dynamic>, hasLength(5));
    expect(project.seriesBible['environments'] as List<dynamic>, hasLength(5));
    expect(project.seriesBible['props'] as List<dynamic>, hasLength(4));
    expect(project.seriesBible['scene_cards'] as List<dynamic>, isEmpty);
    expect(project.seriesBible['max_shot_duration_seconds'], 10);
    expect((project.seriesBible['workflow'] as Map)['scripts'], 'NOT_STARTED');
    expect(
      project.references.every((reference) => reference.metadata.isNotEmpty),
      isTrue,
    );
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

  test('episode script is generated on demand after the outline', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);

    final scripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );

    expect(scripted.episodes.first.takes, isEmpty);
    expect(scripted.episodes[1].takes, isEmpty);
    expect(scripted.seriesBible['scene_cards'] as List<dynamic>, hasLength(3));
    final scripts = scripted.seriesBible['episode_scripts'] as List<dynamic>;
    expect(scripts, hasLength(1));
    final script = scripts.first as Map;
    expect(script['status'], 'DRAFT_REVIEW_REQUIRED');
    expect(script['shot_count'], 15);
    expect(script['max_shot_duration_seconds'], 10);
    expect(script['display_script'], contains('Shot 1'));
    expect(script['display_script'], contains('Duration: 10s'));
    final scenes = script['scenes'] as List<dynamic>;
    final shotDurations = <int>[];
    for (final scene in scenes.cast<Map>()) {
      for (final shot in (scene['shots'] as List<dynamic>).cast<Map>()) {
        shotDurations.add(shot['duration_seconds'] as int);
        final rowTotal = (shot['rows'] as List<dynamic>).cast<Map>().fold<int>(
          0,
          (total, row) => total + row['duration_seconds'] as int,
        );
        expect(rowTotal, shot['duration_seconds']);
        for (final row in (shot['rows'] as List<dynamic>).cast<Map>()) {
          if (row['type'] != 'dialogue') continue;
          final wordCount = row['text']
              .toString()
              .trim()
              .split(RegExp(r'\s+'))
              .length;
          final wordsPerSecond = wordCount / (row['duration_seconds'] as int);
          expect(wordsPerSecond, lessThanOrEqualTo(3.4));
        }
      }
    }
    expect(shotDurations, everyElement(lessThanOrEqualTo(10)));
    expect(shotDurations.toSet().length, greaterThan(1));
    expect(
      shotDurations.fold<int>(0, (total, duration) => total + duration),
      scripted.episodes.first.durationSeconds,
    );
    expect(
      (scripted.seriesBible['workflow'] as Map)['scripts'],
      'PARTIAL_EPISODE_SCRIPT_DRAFTS_CREATED',
    );
    expect(
      (scripted.seriesBible['workflow'] as Map)['production'],
      'BLOCKED_BY_SCRIPT_APPROVAL',
    );
    final cards = scripted.seriesBible['episode_cards'] as List<dynamic>;
    expect(cards.first['script_status'], 'DRAFT_REVIEW_REQUIRED');
    expect(cards[1]['script_status'], 'NOT_STARTED');
  });

  test('video prompts are released only after script approval', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final scripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );

    final production = service
        .approveMicroDramaEpisodeScriptForProductionForTesting(
          scripted,
          episodeNumber: 1,
        );

    expect(production.episodes.first.takes, hasLength(15));
    expect(production.episodes[1].takes, isEmpty);
    expect(
      production.episodes.first.takes,
      everyElement(
        isA<ProductionTakeItem>()
            .having(
              (take) => take.durationSeconds,
              'duration',
              lessThanOrEqualTo(10),
            )
            .having(
              (take) => take.visualPrompt,
              'detailed visual prompt',
              allOf([
                isNotEmpty,
                contains('REFERENCE INDEX CONTRACT — DO NOT REORDER'),
                contains('ACTION AND TIMED BEATS:'),
                contains('CAMERA AND OPTICS:'),
                contains('END STATE:'),
                contains('VISUAL STYLE:'),
                contains(
                  'Do not add background music or ambient sound effects.',
                ),
                contains('Do not generate subtitles'),
              ]),
            )
            .having(
              (take) => take.generateSeedanceAudio,
              'embedded audio',
              isTrue,
            )
            .having(
              (take) => take.usePreviousLastFrame,
              'observed continuity is not assumed',
              isFalse,
            ),
      ),
    );
    final scripts = production.seriesBible['episode_scripts'] as List<dynamic>;
    final lockedScript = scripts.first as Map;
    expect(lockedScript['status'], 'LOCKED_FOR_PRODUCTION');
    expect(
      (lockedScript['episode_dialogue_master'] as Map)['status'],
      'LOCKED',
    );
    final firstLine =
        ((lockedScript['episode_dialogue_master'] as Map)['lines']
                    as List<dynamic>)
                .first
            as Map;
    expect(
      production.episodes.first.takes.first.visualPrompt,
      contains(firstLine['text']),
    );
    expect(
      production.episodes.first.takes.first.audioPrompt,
      contains(firstLine['text']),
    );
    final lockedShots = (lockedScript['scenes'] as List<dynamic>)
        .cast<Map>()
        .expand((scene) => (scene['shots'] as List<dynamic>).cast<Map>())
        .toList();
    expect(lockedShots, hasLength(production.episodes.first.takes.length));
    for (var index = 0; index < lockedShots.length; index++) {
      final shot = lockedShots[index];
      final take = production.episodes.first.takes[index];
      expect(take.durationSeconds, shot['duration_seconds']);
      expect(take.visualPrompt.length, lessThanOrEqualTo(6000));
      final dialogueRows = (shot['rows'] as List<dynamic>).cast<Map>().where(
        (row) => row['type'] == 'dialogue',
      );
      for (final row in dialogueRows) {
        expect(take.visualPrompt, contains(row['text']));
        expect(take.audioPrompt, contains(row['text']));
        expect(
          RegExp(
            RegExp.escape(row['text'].toString()),
          ).allMatches(take.visualPrompt).length,
          1,
        );
      }
    }
    expect(
      production.episodes.first.takes.fold<int>(
        0,
        (total, take) => total + take.durationSeconds,
      ),
      production.episodes.first.durationSeconds,
    );
    final cards = production.seriesBible['episode_cards'] as List<dynamic>;
    expect(cards.first['script_status'], 'LOCKED_FOR_PRODUCTION');
    expect(cards.first['production_status'], 'PROMPTS_READY_FOR_REVIEW');
    expect(
      (production.seriesBible['workflow'] as Map)['production'],
      'PARTIAL_EPISODES_READY',
    );
  });

  test('the configured cap is a maximum and shots choose shorter timings', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final fiveSecondOutline = outline.copyWith(
      seriesBible: {
        ...outline.seriesBible,
        'max_shot_duration_seconds': 5,
        'provider_duration_seconds': 5,
      },
    );

    final scripted = service.generateMicroDramaEpisodeScriptForTesting(
      fiveSecondOutline,
      episodeNumber: 1,
    );
    final script =
        (scripted.seriesBible['episode_scripts'] as List<dynamic>).first as Map;
    final durations = (script['scenes'] as List<dynamic>)
        .cast<Map>()
        .expand((scene) => (scene['shots'] as List<dynamic>).cast<Map>())
        .map((shot) => shot['duration_seconds'] as int)
        .toList();

    expect(script['max_shot_duration_seconds'], 5);
    expect(durations, everyElement(lessThanOrEqualTo(5)));
    expect(durations.toSet().length, greaterThan(1));
    expect(
      durations.fold<int>(0, (total, duration) => total + duration),
      scripted.episodes.first.durationSeconds,
    );
  });

  test('legacy microdramas gain missing bibles without losing assets', () {
    final service = LocalProductionWorkspaceService();
    final current = service.buildMicroDramaProjectForTesting(_config);
    final legacyBible = Map<String, dynamic>.from(current.seriesBible)
      ..remove('characters')
      ..remove('character_bible')
      ..remove('environments')
      ..remove('location_bible')
      ..remove('props')
      ..remove('object_bible')
      ..remove('scene_cards')
      ..remove('script_package');
    final protagonist = current.references.first;
    final legacy = current.copyWith(
      seriesBible: legacyBible,
      references: [
        ProductionReferenceItem(
          id: protagonist.id,
          label: protagonist.label,
          category: protagonist.category,
          assetPath: 'assets/images/existing-character.png',
          description: 'Referência aprovada pelo usuário.',
          canonical: true,
        ),
      ],
    );

    final upgraded = service.ensureMicroDramaCreativePackageForTesting(legacy);

    expect(upgraded.references, hasLength(14));
    expect(
      upgraded.references.first.assetPath,
      'assets/images/existing-character.png',
    );
    expect(
      upgraded.references.first.description,
      'Referência aprovada pelo usuário.',
    );
    expect(upgraded.references.first.metadata, isNotEmpty);
    expect(upgraded.seriesBible['scene_cards'] as List<dynamic>, isEmpty);
    expect(upgraded.episodes.every((episode) => episode.takes.isEmpty), isTrue);
  });
}
