import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/admin_service.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';

ProductionCatalogItem _catalogItem() => const ProductionCatalogItem(
  routeId: 42,
  stableKey: 'remote:42',
  title: 'O Contrato da Chuva',
  description:
      'Uma florista e o herdeiro de um hotel fingem um noivado para salvar duas famílias.',
  genre: 'romance',
  status: 'DRAFT',
  sourceLabel: 'Vertix API',
  episodeCount: 1,
  targetEpisodeCount: 1,
  takeCount: 0,
  completedTakeCount: 0,
  referenceCount: 5,
  progress: 0.1,
  isLocal: false,
);

AdminSeriesProductionPlan _plan() => AdminSeriesProductionPlan(
  id: 1,
  seriesId: 42,
  source: 'vertix-app',
  seriesBible: {
    'logline':
        'Uma florista e o herdeiro de um hotel fingem um noivado para salvar duas famílias.',
    'central_question': 'O contrato sobrevive à verdade?',
  },
  episodeTreatments: [
    {
      'episode': 1,
      'title': 'A Dívida Comprada',
      'duration': 75,
      'summary': 'Eles compram a dívida e mudam as regras da casa.',
      'cliffhanger': 'A carta de Eun-mi chega antes do jantar.',
    },
  ],
  sceneCards: [
    {
      'episode': 1,
      'title': 'Eles Compraram Nossa Dívida',
      'location_name': 'Loja de flores',
      'cast': ['Eun-mi', 'Min-jun'],
    },
    {'episode': 1, 'scene_number': 2, 'title': 'O Comprador'},
  ],
  referenceAssets: const [],
  storyPoints: const [],
);

void main() {
  test('remote plan hydrates episode title instead of dumping JSON', () {
    final service = LocalProductionWorkspaceService();
    final project = service.projectFromRemoteForTesting(
      _catalogItem(),
      _plan(),
    );

    expect(project.episodes, hasLength(1));
    expect(project.episodes.first.title, 'A Dívida Comprada');
    expect(project.episodes.first.summary, contains('dívida'));
    expect(project.episodes.first.summary.contains('['), isFalse);
    expect(project.episodes.first.durationSeconds, 75);
    expect(project.episodes.first.takes, isEmpty);
    expect(project.seriesBible['logline'], contains('florista'));
    expect(project.formatFamily, 'micro_drama_vertical');
  });

  test('scene cards get a number and location even with alternate keys', () {
    final service = LocalProductionWorkspaceService();
    final project = service.projectFromRemoteForTesting(
      _catalogItem(),
      _plan(),
    );
    final scenes = project.seriesBible['scene_cards'] as List<dynamic>;

    expect(scenes, hasLength(2));
    expect(scenes.first['scene'], 1);
    expect(scenes.first['location'], 'Loja de flores');
    expect(scenes[1]['scene'], 2);
  });

  test('saved JSON summary is rewritten into readable episode fields', () {
    final service = LocalProductionWorkspaceService();
    final dirty = ProductionProject(
      id: 'remote-42',
      virtualId: 42,
      title: 'O Contrato da Chuva',
      description: 'Uma florista e o herdeiro de um hotel.',
      genre: 'romance',
      formatFamily: 'vertical_series',
      status: 'DRAFT',
      sourcePath: 'Vertix API / serie 42',
      targetEpisodeCount: 1,
      isLocal: false,
      updatedAt: DateTime(2026, 8, 17),
      seriesBible: const {
        'seriesBible': {'logline': 'Contrato falso, amor verdadeiro.'},
        'scene_cards': [
          {'episode': 1, 'title': 'A Carta de Eun-mi'},
        ],
      },
      episodes: [
        ProductionEpisodeItem(
          number: 1,
          title: 'Episodio 1',
          summary:
              '[\n  {\n    "episode": 1,\n    "title": "A Dívida Comprada",\n    "duration": 75\n  }\n]',
          cliffhanger: 'Defina o cliffhanger do episodio.',
          durationSeconds: 75,
          takes: const [],
        ),
      ],
      references: const [],
    );

    final hydrated = service.hydrateRemoteProjectForTesting(dirty, _plan());
    expect(hydrated.episodes.first.title, 'A Dívida Comprada');
    expect(hydrated.episodes.first.summary.contains('['), isFalse);
    expect(hydrated.seriesBible['logline'], contains('Contrato falso'));
    expect(
      (hydrated.seriesBible['scene_cards'] as List).first['scene'],
      isNotNull,
    );
  });

  test('hydrate merges every remote episode instead of keeping a blank EP1', () {
    final service = LocalProductionWorkspaceService();
    final stale = ProductionProject(
      id: 'remote-42',
      virtualId: 42,
      title: 'Fragmentos do Passado',
      description:
          'Dois ex-namorados se reencontram por acaso e precisam confrontar os segredos que os separaram anos atrás.',
      genre: 'romance',
      formatFamily: 'micro_drama_vertical',
      status: 'DRAFT',
      sourcePath: 'Vertix API / serie 42',
      targetEpisodeCount: 8,
      isLocal: false,
      updatedAt: DateTime(2026, 8, 17),
      seriesBible: const {'logline': 'Dois ex-namorados se reencontram.'},
      episodes: const [
        ProductionEpisodeItem(
          number: 1,
          title: 'Episódio 1',
          summary: '',
          cliffhanger: '',
          durationSeconds: 60,
          takes: [],
        ),
      ],
      references: const [],
    );
    final plan = AdminSeriesProductionPlan(
      id: 1,
      seriesId: 42,
      source: 'vertix-app',
      seriesBible: {
        'logline': 'Dois ex-namorados se reencontram.',
        'central_question': 'O segredo ainda pode ser perdoado?',
      },
      episodeTreatments: [
        for (var number = 1; number <= 8; number++)
          {
            'number': number,
            'title': 'Corte $number',
            'summary': 'O reencontro força uma escolha no episódio $number.',
            'cliffhanger': 'A carta antiga reaparece.',
            'durationSeconds': number == 1 ? 120 : 60,
          },
      ],
      episodeMap: [
        for (var number = 1; number <= 8; number++)
          {
            'episode': number,
            'title': 'Corte $number',
            'treatment': 'O reencontro força uma escolha no episódio $number.',
          },
      ],
      referenceAssets: const [],
      storyPoints: const [],
    );

    final hydrated = service.hydrateRemoteProjectForTesting(stale, plan);
    expect(hydrated.episodes, hasLength(8));
    expect(hydrated.episodes.first.title, 'Corte 1');
    expect(hydrated.episodes.first.summary, contains('reencontro'));
    expect(hydrated.episodes.last.number, 8);
    expect(hydrated.seriesBible['central_question'], contains('segredo'));
  });
}
