import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';
import 'package:vertix/core/services/micro_drama_theme_composer.dart';

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
    expect(project.seriesBible['season_architecture'], isA<Map>());
    expect(
      (project.seriesBible['season_architecture'] as Map)['paywall_episode'],
      3,
    );
    final hookChain = (project.seriesBible['hook_chain'] as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    expect(hookChain.first['final_hook'], project.episodes.first.cliffhanger);
    expect(
      hookChain[1]['opening_pickup'],
      contains(project.episodes.first.cliffhanger),
    );
    expect(hookChain.first['unresolved_questions'], hasLength(3));
    expect(
      hookChain.first['unresolved_questions'],
      isNot(contains(_config.centralQuestion)),
    );
    expect(
      (hookChain.first['unresolved_questions'] as List).last,
      contains('EP2'),
    );
    expect(
      project.episodes.every(
        (episode) =>
            episode.summary.isNotEmpty && episode.cliffhanger.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('automatic preparation is queued without skipping script gates', () {
    final service = LocalProductionWorkspaceService();
    const automaticConfig = MicroDramaProjectConfig(
      title: 'Segunda Chance Automática',
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
      automaticPreparation: true,
    );

    final project = service.buildMicroDramaProjectForTesting(automaticConfig);

    expect(project.seriesBible['automatic_preparation_requested'], isTrue);
    expect(project.seriesBible['automatic_preparation_status'], 'QUEUED');
    expect(project.episodes.every((episode) => episode.takes.isEmpty), isTrue);
    expect(project.seriesBible['scene_cards'] as List<dynamic>, isEmpty);
    expect((project.seriesBible['workflow'] as Map)['scripts'], 'NOT_STARTED');
    expect(
      (project.seriesBible['workflow'] as Map)['production'],
      'BLOCKED_BY_SCRIPT',
    );
  });

  test('automatic reference targets preserve approved images by default', () {
    final service = LocalProductionWorkspaceService();
    final project = service.buildMicroDramaProjectForTesting(_config);

    expect(service.automaticReferenceTargets(project), hasLength(15));
    final coverTarget = service.automaticReferenceTargets(project).last;
    expect(coverTarget.category, 'APP_COVER');
    expect(coverTarget.label, project.title);
    expect(coverTarget.metadata['targetField'], 'Series.coverUrl');
    final target = project.references.first;
    final withImage = service.applyGeneratedReferenceImage(project, {
      'result': {
        'reference': {
          ...target.toJson(),
          'publicUrl': 'https://cdn.example.com/approved-reference.png',
        },
      },
    });

    expect(service.automaticReferenceTargets(withImage), hasLength(14));
    expect(
      service.automaticReferenceTargets(withImage, regenerateExisting: true),
      hasLength(15),
    );
    expect(service.areStoryReferencesReadyForVideo(project), isFalse);
    expect(
      service.videoGenerationBlockedByReferencesReason(project),
      contains('personagens'),
    );

    var complete = project;
    for (final reference in project.references) {
      complete = service.applyGeneratedReferenceImage(complete, {
        'result': {
          'reference': {
            ...reference.toJson(),
            'publicUrl': 'https://cdn.example.com/${reference.id}.png',
          },
        },
      });
    }
    expect(service.missingStoryReferenceImages(complete), isEmpty);
    expect(service.areStoryReferencesReadyForVideo(complete), isTrue);
    expect(service.videoGenerationBlockedByReferencesReason(complete), isNull);
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
    final expectedStyleSuffix = service.microDramaStyleSuffixForTesting(
      _config.visualStyle,
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
              (take) => take.aiShortCore,
              'scene-specific AI short core',
              allOf([
                isNotEmpty,
                isNot(contains('REFERENCE INDEX CONTRACT')),
                isNot(contains('Visual style:')),
                isNot(contains('Do not generate subtitles')),
                isNot(contains('Avoid shaky footage')),
              ]),
            )
            .having(
              (take) => take.visualPrompt,
              'detailed visual prompt',
              allOf([
                isNotEmpty,
                contains('REFERENCE INDEX CONTRACT — DO NOT REORDER'),
                contains('From 0 to'),
                contains('CONTINUITY CONTRACT:'),
                contains('Visual style:'),
                contains(
                  'Do not add any background music or ambient sound effects.',
                ),
                contains('Do not generate subtitles'),
              ]),
            )
            .having(
              (take) => take.visualPrompt.endsWith(expectedStyleSuffix),
              'fixed style suffix appended byte-for-byte',
              isTrue,
            )
            .having(
              (take) => take.stylePresetId,
              'code-owned style preset',
              'live_action_modern_microdrama_v1',
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
    final promptPackages =
        production.seriesBible['production_prompt_packages'] as List<dynamic>;
    expect(
      promptPackages.first['prompt_contract'],
      'ai_short_core_plus_code_style_preset_v1',
    );
    expect(promptPackages.first['style_decoration'], 'CODE_OWNED_FIXED_PRESET');
    expect(
      promptPackages.first['style_preset_id'],
      'live_action_modern_microdrama_v1',
    );
  });

  test('Codex episode and production results keep code-owned style locks', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final localScripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );
    final generatedScript = Map<String, dynamic>.from(
      (localScripted.seriesBible['episode_scripts'] as List<dynamic>).first
          as Map,
    );
    final scripted = service.applyCodexEpisodeScript(outline, {
      'summary': 'Roteiro criado pelo Codex',
      'codexThreadId': 'thread-test-1',
      'result': {
        'episode': localScripted.episodes.first.toJson(),
        'episodeScript': generatedScript,
      },
    }, episodeNumber: 1);

    expect(scripted.seriesBible['codex_thread_id'], 'thread-test-1');
    expect(scripted.episodes.first.status, 'SCRIPT_DRAFT_REVIEW_REQUIRED');
    expect(scripted.episodes.first.takes, isEmpty);

    final deterministicProduction = service
        .approveMicroDramaEpisodeScriptForProductionForTesting(
          scripted,
          episodeNumber: 1,
        );
    final takes = deterministicProduction.episodes.first.takes
        .map(
          (take) => {
            'number': take.number,
            'title': take.title,
            'durationSeconds': take.durationSeconds,
            'aiShortCore':
                'Codex dynamic scene core for take ${take.number}, preserving the locked action and dialogue.',
            'audioPrompt': take.audioPrompt,
            'transitionMode': take.transitionMode,
            'usePreviousLastFrame': false,
            'generateSeedanceAudio': true,
            'referenceIds': take.referenceIds,
            'notes': 'Codex continuity note ${take.number}',
          },
        )
        .toList();
    final production = service.applyCodexProductionScenes(scripted, {
      'summary': 'Prompts dinâmicos criados pelo Codex',
      'codexThreadId': 'thread-test-1',
      'result': {
        'episodeNumber': 1,
        'takes': takes,
        'productionPackage': {
          'status': 'PROMPTS_READY_FOR_REVIEW',
          'prompt_contract': 'ai_short_core_plus_code_style_preset_v1',
        },
      },
    }, episodeNumber: 1);
    final suffix = service.microDramaStyleSuffixForTesting(_config.visualStyle);

    expect(
      production.episodes.first.takes,
      everyElement(
        isA<ProductionTakeItem>()
            .having(
              (take) => take.aiShortCore,
              'Codex dynamic core',
              startsWith('Codex dynamic scene core'),
            )
            .having(
              (take) => take.visualPrompt.endsWith(suffix),
              'fixed suffix',
              isTrue,
            ),
      ),
    );
    expect(
      production.episodes.first.takes.first.aiShortCore,
      isNot(contains('Do not generate subtitles')),
    );
    expect(
      production.episodes.first.takes.first.visualPrompt,
      contains('Do not generate subtitles'),
    );
  });

  test(
    'Codex production accepts numeric boolean flags from legacy payloads',
    () {
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
      final takes = production.episodes.first.takes
          .map(
            (take) => {
              'number': take.number,
              'aiShortCore': 'Descrição dinâmica do take ${take.number}.',
              'usePreviousLastFrame': take.number == 2 ? 1 : 0,
              'generateSeedanceAudio': take.number == 1 ? 1 : 0,
              'referenceIds': take.referenceIds,
            },
          )
          .toList();

      final applied = service.applyCodexProductionScenes(scripted, {
        'result': {'takes': takes},
      }, episodeNumber: 1);

      expect(applied.episodes.first.takes.first.generateSeedanceAudio, isTrue);
      expect(applied.episodes.first.takes[1].usePreviousLastFrame, isTrue);
    },
  );

  test(
    'approves production when a studio series was reloaded as vertical_series',
    () {
      final service = LocalProductionWorkspaceService();
      final outline = service.buildMicroDramaProjectForTesting(_config);
      final scripted = service.generateMicroDramaEpisodeScriptForTesting(
        outline,
        episodeNumber: 1,
      );
      final mislabeled = scripted.copyWith(formatFamily: 'vertical_series');

      final production = service
          .approveMicroDramaEpisodeScriptForProductionForTesting(
            mislabeled,
            episodeNumber: 1,
          );

      expect(production.formatFamily, 'micro_drama_vertical');
      expect(production.episodes.first.status, 'PRODUCTION_READY');
      expect(production.episodes.first.takes, isNotEmpty);
    },
  );

  test('fromJson recovers microdrama format from the studio bible', () {
    final project = ProductionProject.fromJson({
      'id': 'remote-1',
      'virtualId': 1,
      'title': 'Laços Invisíveis',
      'description': 'Uma família descobre um pendrive.',
      'genre': 'drama',
      'formatFamily': 'vertical_series',
      'status': 'DRAFT',
      'sourcePath': 'Vertix API / serie 1',
      'targetEpisodeCount': 8,
      'isLocal': false,
      'updatedAt': '2026-08-18T00:00:00.000',
      'seriesBible': {
        'creation_workflow': 'openrouter_outline_first_v1',
        'episode_scripts': [
          {'episode': 1, 'scenes': const []},
        ],
      },
      'episodes': const [],
      'references': const [],
    });

    expect(project.formatFamily, 'micro_drama_vertical');
  });

  test('Codex outline and GPT Image 2 reference merge into the project', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final generated = service.applyCodexSeriesOutline(outline, {
      'summary': 'Esboço completo',
      'codexThreadId': 'thread-outline',
      'result': {
        'title': 'O último brinde',
        'seriesBiblePatch': {
          'logline': 'Logline refinada pelo Codex.',
          'big_expectation': 'Uma revelação por episódio.',
          'season_architecture': {
            'paywall_episode': 3,
            'free_episode_count': 3,
            'central_question_payoff_window': '7-8',
            'blocks': [
              {
                'id': 'premise_hook',
                'episodes': '1-2',
                'role': 'detonate_premise_prove_fantasy',
                'conversion_role': 'free_funnel',
              },
            ],
          },
          'reserved_reveals': [
            {
              'id': 'r1',
              'fact': 'Helena forjou o contrato',
              'earliest_episode': 6,
              'payoff_episode': 8,
            },
          ],
          'episode_cards': outline.seriesBible['episode_cards'],
          'characters': outline.seriesBible['characters'],
          'environments': outline.seriesBible['environments'],
          'props': outline.seriesBible['props'],
        },
        'episodes': outline.episodes
            .map(
              (episode) => {
                ...episode.toJson(),
                if (episode.number == 1)
                  'cliffhanger':
                      'A TV da padaria mostra o rosto do príncipe; corte no preto.',
              },
            )
            .toList(),
        'references': outline.references
            .map((reference) => reference.toJson())
            .toList(),
      },
    });
    final target = generated.references.first;
    final withImage = service.applyGeneratedReferenceImage(generated, {
      'summary': 'Imagem gerada',
      'result': {
        'reference': {
          ...target.toJson(),
          'publicUrl': 'https://cdn.example.com/gpt-image-2/reference.png',
          'metadata': {...target.metadata, 'image_model': 'gpt-image-2'},
        },
      },
    });

    expect(generated.description, 'Logline refinada pelo Codex.');
    expect(generated.title, 'O último brinde');
    expect(generated.seriesBible['codex_thread_id'], 'thread-outline');
    expect(generated.seriesBible['season_architecture']['paywall_episode'], 3);
    expect(
      generated.seriesBible['reserved_reveals'],
      isNotEmpty,
    );
    expect(
      generated.episodes.first.cliffhanger,
      'A TV da padaria mostra o rosto do príncipe; corte no preto.',
    );
    final generatedChain =
        (generated.seriesBible['hook_chain'] as List<dynamic>)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    expect(
      generatedChain.first['final_hook'],
      'A TV da padaria mostra o rosto do príncipe; corte no preto.',
    );
    expect(
      generatedChain[1]['opening_pickup'],
      contains('A TV da padaria mostra o rosto do príncipe'),
    );
    expect(withImage.references.first.publicUrl, contains('gpt-image-2'));
    expect(withImage.references.first.metadata['image_model'], 'gpt-image-2');
  });

  test('style presets own immutable media-specific production locks', () {
    final service = LocalProductionWorkspaceService();
    final modern = service.microDramaStyleSuffixForTesting(
      'Microdrama moderno',
    );
    final animation = service.microDramaStyleSuffixForTesting(
      'Animação cinematográfica',
    );

    expect(
      modern,
      startsWith(
        'Master-level cinematography and composition, fast-paced shot variation.',
      ),
    );
    expect(modern, contains('Live-action TV drama style'));
    expect(modern, contains('Do not generate subtitles'));
    expect(modern, contains('Avoid shaky footage'));
    expect(animation, isNot(modern));
    expect(animation, contains('Animation profile:'));
    expect(animation, contains('no drift into live-action'));
    expect(animation, isNot(contains('Realistic film profile:')));
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
    expect(durations.fold<int>(0, (total, duration) => total + duration),
      scripted.episodes.first.durationSeconds,
    );
  });

  test('dola preset writes exact 10s shots instead of 15s or 30s beats', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(
      _config.copyWith(videoGenerationPresetId: 'seedance_2_5_dola'),
    );
    expect(outline.seriesBible['video_generation_profile'], 'seedance_2_5_dola');
    expect(outline.seriesBible['shot_duration_mode'], 'FIXED');
    expect(outline.seriesBible['max_shot_duration_seconds'], 10);

    final scripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );
    final script =
        (scripted.seriesBible['episode_scripts'] as List<dynamic>).first as Map;
    final durations = (script['scenes'] as List<dynamic>)
        .cast<Map>()
        .expand((scene) => (scene['shots'] as List<dynamic>).cast<Map>())
        .map((shot) => shot['duration_seconds'] as int)
        .toList();

    expect(script['shot_duration_mode'], 'FIXED');
    expect(durations, everyElement(equals(10)));
    expect(
      durations.fold<int>(0, (total, duration) => total + duration),
      scripted.episodes.first.durationSeconds,
    );
  });

  test('seedance 2.5 api plans variable shots up to 30 seconds', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(
      _config.copyWith(videoGenerationPresetId: 'seedance_2_5_api'),
    );
    expect(outline.seriesBible['max_shot_duration_seconds'], 30);
    expect(outline.seriesBible['shot_duration_mode'], 'VARIABLE_UP_TO_LIMIT');

    final scripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );
    final script =
        (scripted.seriesBible['episode_scripts'] as List<dynamic>).first as Map;
    final durations = (script['scenes'] as List<dynamic>)
        .cast<Map>()
        .expand((scene) => (scene['shots'] as List<dynamic>).cast<Map>())
        .map((shot) => shot['duration_seconds'] as int)
        .toList();

    expect(script['max_shot_duration_seconds'], 30);
    expect(durations, everyElement(lessThanOrEqualTo(30)));
    expect(durations.any((duration) => duration > 10), isTrue);
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

  test('chat brief draft stays empty until the theme contract is applied', () {
    final service = LocalProductionWorkspaceService();
    final draft = service.buildMicroDramaChatDraftForTesting();

    expect(
      LocalProductionWorkspaceService.isMicroDramaChatBrief(draft),
      isTrue,
    );
    expect(draft.episodes, isEmpty);
    expect(draft.seriesBible['creation_stage'], 'chat_brief');
    expect(draft.seriesBible['automatic_preparation_requested'], isFalse);

    final fromTheme = MicroDramaThemeComposer.compose(
      idea: 'Uma chef reencontra o ex no prédio que ele agora controla.',
      genre: 'Romance com reviravolta',
      background: 'Cidade moderna',
      trope: 'Segunda chance',
      visualStyle: 'K-drama moderno',
      language: 'Português (Brasil)',
      rating: '14 anos',
      episodeCount: 8,
      firstEpisodeDurationSeconds: 120,
      episodeDurationSeconds: 60,
      automaticPreparation: true,
    );

    expect(fromTheme.logline, isNotEmpty);
    expect(fromTheme.protagonist, isNotEmpty);
    expect(fromTheme.opposingForce, isNotEmpty);
    expect(fromTheme.centralQuestion, contains(fromTheme.protagonist));
    expect(fromTheme.stakes, isNotEmpty);
    expect(fromTheme.visualStyle, 'K-drama moderno');
    expect(fromTheme.automaticPreparation, isTrue);

    final applied = service.applyMicroDramaConfig(
      draft,
      fromTheme,
      creationIdea:
          'Uma chef reencontra o ex no prédio que ele agora controla.',
    );

    expect(applied.id, draft.id);
    expect(applied.virtualId, draft.virtualId);
    expect(
      LocalProductionWorkspaceService.isMicroDramaChatBrief(applied),
      isFalse,
    );
    expect(applied.episodes, hasLength(8));
    expect(applied.seriesBible['creation_stage'], 'outline_ready');
    expect(applied.seriesBible['creation_idea'], contains('chef'));
    expect(applied.seriesBible['visual_style'], 'K-drama moderno');
    expect(applied.seriesBible['automatic_preparation_requested'], isTrue);
  });

  test('Codex episode script persists even with duration drift and string episode', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final localScripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );
    final generatedScript = Map<String, dynamic>.from(
      (localScripted.seriesBible['episode_scripts'] as List<dynamic>).first
          as Map,
    );
    generatedScript['episode'] = '1';
    final scenes = (generatedScript['scenes'] as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final firstScene = Map<String, dynamic>.from(scenes.first);
    final shots = (firstScene['shots'] as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final firstShot = Map<String, dynamic>.from(shots.first);
    firstShot['duration_seconds'] =
        (firstShot['duration_seconds'] as num).toInt() + 1;
    shots[0] = firstShot;
    firstScene['shots'] = shots;
    scenes[0] = firstScene;
    generatedScript['scenes'] = scenes;

    final scripted = service.applyCodexEpisodeScript(outline, {
      'summary': 'Roteiro com duração irregular',
      'result': {
        'episode': {'number': 1, 'title': outline.episodes.first.title},
        'episodeScript': generatedScript,
      },
    }, episodeNumber: 1);

    final saved =
        (scripted.seriesBible['episode_scripts'] as List<dynamic>).first as Map;
    expect(saved['episode'], 1);
    expect((saved['scenes'] as List).length, greaterThan(0));
    expect(saved['quality_gate']['duration_sums'], 'NEEDS_HUMAN_FIX');
    expect(scripted.episodes.first.takes, isEmpty);
  });

  test('partial Codex script keeps the richer draft instead of shrinking it', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final rich = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );
    final richScenes =
        ((rich.seriesBible['episode_scripts'] as List).first as Map)['scenes']
            as List;
    expect(richScenes.length, greaterThan(1));

    final poorer = service.applyCodexEpisodeScript(
      rich,
      {
        'result': {
          'episodeScript': {
            'episode': 1,
            'scenes': [
              {'episode': 1, 'scene': 1, 'title': 'Só o começo', 'shots': []},
            ],
          },
        },
      },
      episodeNumber: 1,
      allowPartial: true,
    );

    final scenes =
        ((poorer.seriesBible['episode_scripts'] as List).first as Map)['scenes']
            as List;
    expect(scenes.length, richScenes.length);
  });

  test('new outline drops unlocked leftover episode scripts', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final scripted = service.generateMicroDramaEpisodeScriptForTesting(
      outline,
      episodeNumber: 1,
    );
    expect(
      (scripted.seriesBible['episode_scripts'] as List).length,
      greaterThan(0),
    );

    final refreshed = service.applyCodexSeriesOutline(scripted, {
      'summary': 'Novo esboço',
      'result': {
        'title': 'Café da Esquina',
        'seriesBiblePatch': {
          'title': 'Café da Esquina',
          'logline': 'Laura reencontra Pedro na cafeteria.',
          'episode_cards': [
            for (var number = 1; number <= 8; number++)
              {'episode': number, 'title': 'EP$number'},
          ],
          'hook_chain': [
            for (var number = 1; number <= 8; number++)
              {'episode': number, 'final_hook': 'gancho $number'},
          ],
        },
        'episodes': [
          for (var number = 1; number <= 8; number++)
            {
              'number': number,
              'title': number == 1 ? 'O Reencontro' : 'Episódio $number',
              'summary': 'Laura e Pedro na cafeteria.',
              'cliffhanger': 'Alguém entra na porta.',
              'durationSeconds': number == 1 ? 120 : 60,
            },
        ],
        'references': const [],
      },
    });

    expect(refreshed.episodes.first.title, 'O Reencontro');
    expect(refreshed.seriesBible['episode_scripts'], isEmpty);
    expect(refreshed.seriesBible['scene_cards'], isEmpty);
  });

  test('Codex story sheets keep title and episodes and fill character cards', () {
    final service = LocalProductionWorkspaceService();
    final outline = service.buildMicroDramaProjectForTesting(_config);
    final stripped = outline.copyWith(references: const []);
    final withSheets = service.applyCodexStorySheets(stripped, {
      'summary': 'Fichas de personagens',
      'result': {
        'title': 'Título inventado que não deve entrar',
        'seriesBiblePatch': {
          'title': 'Título inventado que não deve entrar',
          'logline': 'Logline nova que não deve entrar',
          'characters': [
            {
              'reference_id': 'character-marta',
              'name': 'Marta',
              'role': 'Protagonista',
              'appearance': 'Chef de 34 anos, cabelo preso, avental marcado.',
            },
          ],
          'environments': [
            {
              'reference_id': 'location-cozinha',
              'name': 'Cozinha',
              'description': 'Não deve aparecer no escopo de personagens.',
            },
          ],
          'episode_cards': const [],
        },
        'episodes': [
          {'number': 1, 'title': 'Episódio reescrito'},
        ],
        'references': [
          {
            'id': 'character-marta',
            'label': 'Marta',
            'category': 'CHARACTER_MASTER',
            'description': 'Chef de 34 anos, cabelo preso, avental marcado.',
            'canonical': true,
            'metadata': {'role': 'Protagonista'},
          },
        ],
      },
    }, family: 'characters');

    expect(withSheets.title, stripped.title);
    expect(withSheets.description, stripped.description);
    expect(withSheets.episodes.first.title, stripped.episodes.first.title);
    expect(withSheets.seriesBible['episode_cards'], isNotEmpty);
    expect(
      (withSheets.seriesBible['characters'] as List).first['name'],
      'Marta',
    );
    expect(
      withSheets.references.where((item) => item.category.contains('CHARACTER')),
      hasLength(1),
    );
    expect(
      withSheets.references.any((item) => item.id == 'location-cozinha'),
      isFalse,
    );
  });
}
