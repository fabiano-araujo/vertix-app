import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/local_production_workspace_service.dart';

ProductionCatalogItem _item({
  required int id,
  required String title,
  required String status,
  DateTime? updatedAt,
}) {
  return ProductionCatalogItem(
    routeId: id,
    stableKey: 'remote:$id',
    title: title,
    description: '',
    genre: 'Drama',
    status: status,
    sourceLabel: 'Vertix API',
    episodeCount: 8,
    targetEpisodeCount: 8,
    takeCount: 0,
    completedTakeCount: 0,
    referenceCount: 0,
    progress: 0.2,
    isLocal: false,
    updatedAt: updatedAt,
  );
}

void main() {
  test('studio lists production series before drafts, newest first inside each group', () {
    final olderProduction = _item(
      id: 1,
      title: 'Anel Zero',
      status: 'IN_PRODUCTION',
      updatedAt: DateTime(2026, 8, 1),
    );
    final newerProduction = _item(
      id: 2,
      title: 'Promethea',
      status: 'IN_PRODUCTION',
      updatedAt: DateTime(2026, 8, 17),
    );
    final newerDraft = _item(
      id: 3,
      title: 'Novo microdrama gerado',
      status: 'DRAFT',
      updatedAt: DateTime(2026, 8, 18),
    );
    final olderDraft = _item(
      id: 4,
      title: 'Rascunho antigo',
      status: 'DRAFT',
      updatedAt: DateTime(2026, 7, 1),
    );

    final items = [olderDraft, newerDraft, olderProduction, newerProduction]
      ..sort(compareStudioCatalogItems);

    expect(items.map((item) => item.title).toList(), [
      'Promethea',
      'Anel Zero',
      'Novo microdrama gerado',
      'Rascunho antigo',
    ]);
  });

  test('empty chat brief stays local until title or episodes exist', () {
    final service = LocalProductionWorkspaceService();
    final empty = service.buildMicroDramaChatDraftForTesting();
    expect(service.shouldPersistProjectToApi(empty), isFalse);

    final titled = empty.copyWith(title: 'Ponto Cego');
    expect(service.shouldPersistProjectToApi(titled), isTrue);
  });

  test('API payload keeps editor project without wiping existing references', () {
    final service = LocalProductionWorkspaceService();
    final project = service.buildMicroDramaChatDraftForTesting().copyWith(
      title: 'Ponto Cego',
      episodes: const [],
    );
    final payload = service.productionApiPayload(project);
    expect(payload['source'], 'vertix-app');
    expect(payload['replaceExisting'], isFalse);
    expect(payload['collectImplicitReferences'], isFalse);
    final pipeline = payload['pipelineData'] as Map<String, dynamic>;
    final bible = pipeline['seriesBible'] as Map<String, dynamic>;
    expect(bible['editor_project'], isA<Map>());
    expect((bible['editor_project'] as Map)['title'], 'Ponto Cego');
    expect(pipeline['editor_project'], isA<Map>());
    expect(
      () => jsonEncode(payload),
      returnsNormally,
      reason: 'payload cannot contain cyclic references',
    );
    final encodedEditor =
        (jsonDecode(jsonEncode(payload))['pipelineData']
            as Map)['seriesBible']['editor_project'] as Map;
    expect(encodedEditor.containsKey('seriesBible'), isTrue);
    expect(
      (encodedEditor['seriesBible'] as Map).containsKey('editor_project'),
      isFalse,
    );
  });

  test('API payload stores chat, episode map and episode treatments', () {
    final service = LocalProductionWorkspaceService();
    final project = service
        .attachStudioSession(
          service.buildMicroDramaChatDraftForTesting().copyWith(
            title: 'Fragmentos do Passado',
            description: 'Dois ex-namorados se reencontram por acaso.',
            episodes: const [
              ProductionEpisodeItem(
                number: 1,
                title: 'A estação',
                summary: 'Eles se reconhecem no andamento do trem.',
                cliffhanger: 'Uma carta cai no chão.',
                durationSeconds: 120,
                takes: [],
              ),
              ProductionEpisodeItem(
                number: 2,
                title: 'A carta',
                summary: 'O conteúdo da carta reabre o passado.',
                cliffhanger: 'Alguém observa os dois.',
                durationSeconds: 60,
                takes: [],
              ),
            ],
          ),
          chat: const [
            {'role': 'user', 'text': 'Gere o esboço da série.'},
            {
              'role': 'assistant',
              'text': 'O esboço do EP1 está na área de trabalho.',
            },
          ],
          ui: const {'episodeIndex': 0, 'studioTabIndex': 1},
        );
    final payload = service.productionApiPayload(project);
    final pipeline = payload['pipelineData'] as Map<String, dynamic>;
    final bible = pipeline['seriesBible'] as Map<String, dynamic>;
    final editor = bible['editor_project'] as Map;
    expect(pipeline['episodeTreatments'], hasLength(2));
    expect(pipeline['episodeMap'], hasLength(2));
    expect(bible['studio_chat'], hasLength(2));
    expect(editor['episodes'], hasLength(2));
    expect(service.studioChatOf(project).first['text'], contains('esboço'));
  });

  test('reload prefers the overlay with episodes over a stale API snapshot', () {
    final service = LocalProductionWorkspaceService();
    ProductionProject base({
      required int episodeCount,
      required DateTime updatedAt,
      String summary = '',
    }) {
      return ProductionProject(
        id: 'remote-9',
        virtualId: 9,
        title: 'Fragmentos do Passado',
        description: 'Dois ex-namorados se reencontram.',
        genre: 'romance',
        formatFamily: 'micro_drama_vertical',
        status: 'DRAFT',
        sourcePath: 'Vertix API / serie 9',
        targetEpisodeCount: 8,
        isLocal: false,
        updatedAt: updatedAt,
        seriesBible: const {'logline': 'Dois ex-namorados se reencontram.'},
        episodes: [
          for (var number = 1; number <= episodeCount; number++)
            ProductionEpisodeItem(
              number: number,
              title: episodeCount == 1 ? 'Episódio $number' : 'Corte $number',
              summary: summary,
              cliffhanger: summary.isEmpty ? '' : 'A carta reaparece.',
              durationSeconds: 60,
              takes: const [],
            ),
        ],
        references: const [],
      );
    }

    final staleApi = base(
      episodeCount: 1,
      updatedAt: DateTime(2026, 8, 17, 10),
    );
    final overlay = base(
      episodeCount: 8,
      updatedAt: DateTime(2026, 8, 17, 11),
      summary: 'Eles precisam enfrentar o que os separou.',
    );
    final remote = base(
      episodeCount: 1,
      updatedAt: DateTime(2026, 8, 17, 9),
    );

    final selected = service.selectPersistedProject(
      apiProject: staleApi,
      overlayProject: overlay,
      remoteProject: remote,
    );
    expect(selected.episodes, hasLength(8));
    expect(selected.episodes.first.summary, contains('separou'));
  });

  test('adoptSavedProject keeps newer episode text over a generating snapshot', () {
    final service = LocalProductionWorkspaceService();
    ProductionEpisodeItem episode({
      required int number,
      required String title,
      required String summary,
      required String status,
    }) {
      return ProductionEpisodeItem(
        number: number,
        title: title,
        summary: summary,
        cliffhanger: summary.isEmpty ? '' : 'O grupo descobre o símbolo.',
        durationSeconds: 60,
        status: status,
        takes: const [],
      );
    }

    final current = ProductionProject(
      id: 'local-draft',
      virtualId: -1,
      title: 'Cicatrizes do Passado',
      description: 'Uma mulher volta à cidade.',
      genre: 'thriller',
      formatFamily: 'micro_drama_vertical',
      status: 'DRAFT',
      sourcePath: 'Local',
      targetEpisodeCount: 8,
      isLocal: true,
      updatedAt: DateTime(2026, 8, 18, 1),
      seriesBible: const {'logline': 'Uma mulher volta à cidade.'},
      episodes: [
        episode(
          number: 4,
          title: 'A porta do café',
          summary: 'Lúcia encontra o símbolo gravado na porta.',
          status: 'OUTLINE_REVIEW_REQUIRED',
        ),
      ],
      references: const [],
    );
    final saved = current.copyWith(
      id: 'remote-5',
      virtualId: 5,
      isLocal: false,
      sourcePath: 'Vertix API / serie 5',
      updatedAt: DateTime(2026, 8, 18, 2),
      episodes: [
        episode(
          number: 4,
          title: 'Gerando episódio 4...',
          summary: '',
          status: 'GENERATING',
        ),
      ],
    );

    final adopted = service.adoptSavedProject(current: current, saved: saved);
    expect(adopted.virtualId, 5);
    expect(adopted.isLocal, isFalse);
    expect(adopted.episodes.first.title, 'A porta do café');
    expect(adopted.episodes.first.status, isNot('GENERATING'));
    expect(adopted.seriesBible['api_series_id'], 5);
  });
}
