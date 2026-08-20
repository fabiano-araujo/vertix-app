import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/core/services/character_sheet.dart';

void main() {
  test('formats a labeled appearance card from structured fields', () {
    final text = formatCharacterAppearance(
      {
        'height_cm': 167,
        'ethnicity': 'Europeia do Sul (portuguesa)',
        'hair': 'castanho-escuro ondulado',
        'clothing': 'jaqueta de chef branca',
      },
    );

    expect(text, contains('Altura: 167cm'));
    expect(text, contains('Etnia: Europeia do Sul (portuguesa)'));
    expect(text, contains('Roupa e adereços: jaqueta de chef branca'));
  });

  test('supporting characters keep only the default look unless extras exist', () {
    final looks = normalizeCharacterLooks({
      'reference_id': 'character-sora',
      'name': 'Sora',
      'role': 'Confidente',
      'appearance': 'Altura: 162cm\nRoupa e adereços: camisa oxford',
    });

    expect(looks, hasLength(1));
    expect(looks.first['id'], 'default');
    expect(looks.first['kind'], 'default');
  });

  test('extra looks become wardrobe variants with an image-1 prompt', () {
    final looks = normalizeCharacterLooks({
      'reference_id': 'character-marta',
      'name': 'Marta',
      'appearance_card': {
        'clothing': 'jaqueta de chef branca',
      },
      'looks': [
        'Aparência padrão',
        {
          'label': 'jantar de trabalho',
          'wardrobe': 'blusa de seda verde-garrafa',
        },
      ],
    });

    expect(looks, hasLength(2));
    expect(looks.first['primary'], isTrue);
    expect(looks.last['kind'], 'wardrobe');
    expect(
      looks.last['prompt'],
      contains('Keep the character from image 1 unchanged'),
    );
    expect(looks.last['prompt'], contains('blusa de seda verde-garrafa'));
  });

  test('resolves the scene look from intimate cues, kitchen default, or explicit cast_looks', () {
    final marta = {
      'reference_id': 'character-marta',
      'name': 'Marta',
      'looks': [
        {
          'id': 'default',
          'label': 'Aparência padrão',
          'kind': 'default',
          'primary': true,
          'wardrobe': 'jaqueta de chef branca e avental',
        },
        {
          'id': 'em-casa',
          'label': 'fora de serviço em casa',
          'kind': 'wardrobe',
          'needed_because': 'espaço íntimo, longe da cozinha',
          'wardrobe': 'camisola de malha creme e calças de ganga',
        },
      ],
    };

    expect(
      resolveSceneCharacterLookId(
        character: marta,
        haystack: 'Espaço íntimo de Marta, silêncio em casa',
      ),
      'em-casa',
    );
    expect(
      resolveSceneCharacterLookId(
        character: marta,
        haystack: 'Cozinha do restaurante, serviço no passe',
      ),
      'default',
    );
    expect(
      resolveSceneCharacterLookId(
        character: marta,
        haystack: 'Cozinha do restaurante',
        explicitLookId: 'em-casa',
      ),
      'em-casa',
    );
    expect(
      explicitSceneLookId(
        characterId: 'character-marta',
        characterName: 'Marta',
        scene: {
          'cast_looks': {'character-marta': 'em-casa'},
        },
      ),
      'em-casa',
    );
  });
}
