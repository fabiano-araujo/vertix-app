String _factsFor(String description, Map<String, dynamic> metadata) {
  final parts = <String>[
    _clean(description),
    _clean(metadata['appearance']),
    _clean(metadata['visual_lock'] ?? metadata['visualLock']),
    _clean(
      metadata['outfit_lock'] ?? metadata['outfitLock'] ?? metadata['wardrobe'],
    ),
    _clean(metadata['age']),
    _clean(metadata['role']),
  ].where((item) => item.isNotEmpty).toList();
  final seen = <String>{};
  return parts.where((item) {
    final key = item.toLowerCase();
    if (seen.contains(key)) return false;
    seen.add(key);
    return true;
  }).join(' ');
}

bool _isMinor(String facts) {
  final text = facts.toLowerCase();
  final age = RegExp(
    r'\b(\d{1,2})\s*(?:anos?|years?(?:\s+old)?)\b',
  ).firstMatch(text);
  if (age != null) return int.parse(age.group(1)!) < 18;
  return RegExp(
    r'\b(crian[cç]a|menino|menina|beb[eê]|child|kid|toddler|infantil)\b',
  ).hasMatch(text);
}

String _clean(Object? value, [int maxLength = 4000]) {
  final text = (value ?? '').toString().trim();
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength);
}

String _outfitLookPrompt({
  required String label,
  required String description,
  required Map<String, dynamic> metadata,
  required String stored,
}) {
  final candidates = [stored, description, metadata['prompt']];
  final hasCompiled = candidates.any(
    (item) => _clean(item).toLowerCase().contains(
      'image 1 is the canonical identity sheet',
    ),
  );
  if (hasCompiled) {
    return stored.isNotEmpty
        ? stored
        : _clean(description.isNotEmpty ? description : metadata['prompt']);
  }
  final keep = candidates
      .map(_clean)
      .firstWhere(
        (item) => item.toLowerCase().contains(
          'keep the character from image 1',
        ),
        orElse: () => '',
      );
  final wardrobe = _clean(
    metadata['wardrobe'] ?? metadata['outfit_lock'] ?? metadata['clothing'],
  );
  final instruction = keep.isNotEmpty
      ? keep
      : (wardrobe.isEmpty
            ? 'Keep the character from image 1 unchanged. Change the outfit to the approved wardrobe for this look.'
            : 'Keep the character from image 1 unchanged. Change the outfit to: $wardrobe');
  final identity = _clean(
    metadata['appearance'] ?? metadata['visual_lock'] ?? '',
  );
  final name = _clean(label, 180);
  return '''$instruction

IMAGE 1 is the canonical identity sheet of $name. Keep the same face, age, height, ethnicity, bone structure, body and hair identity. Change only clothes, shoes, accessories and any hair styling or handheld prop named in the outfit.

IDENTITY FACTS TO PRESERVE: ${identity.isNotEmpty ? identity : 'Preserve the approved face, age, body and ethnicity from image 1.'}

Photorealistic live-action continuity photograph, full body visible, clean off-white studio, 3:2. Exactly one person. No new identity. No extra people. No text, logo or watermark.''';
}

String characterSheetGenerationPrompt({
  required String label,
  required String category,
  String description = '',
  Map<String, dynamic> metadata = const {},
}) {
  final stored = _clean(metadata['compiledPrompt'] ?? metadata['prompt'], 20000);
  final categoryValue = category.toUpperCase();
  final isLook =
      categoryValue.contains('LOOK') ||
      categoryValue.contains('OUTFIT') ||
      categoryValue.contains('VARIANT') ||
      (metadata['parent_character_id'] ?? metadata['parentId'] ?? '')
          .toString()
          .trim()
          .isNotEmpty;
  if (!isLook &&
      (stored.contains('LEFT 70%') || stored.contains('identity sheet'))) {
    return stored;
  }
  final isCharacter =
      categoryValue.contains('CHARACTER') ||
      categoryValue.contains('OPPOSING_FORCE');
  if (!isCharacter) {
    return stored.isNotEmpty ? stored : description;
  }

  if (isLook) {
    return _outfitLookPrompt(
      label: label,
      description: description,
      metadata: metadata,
      stored: stored,
    );
  }

  final facts = _factsFor(description, metadata);
  if (_isMinor('$description $facts')) {
    return stored.isNotEmpty ? stored : description;
  }

  final name = _clean(label, 180);
  final approved = facts.isNotEmpty
      ? facts
      : 'Use only the approved identity and wardrobe facts supplied for this character.';

  return '''Create one clean horizontal 3:2 character identity sheet on an off-white
background for the original fictional adult character $name. Put the exact name
“$name” once in large, correctly spelled, readable editorial type at the top,
centered across the complete sheet.

APPROVED CHARACTER FACTS — PRESERVE EXACTLY: $approved

LEFT 70% — THREE FULL-BODY TURNAROUND VIEWS: show exactly three believable,
unretouched, live-action color bodies at matching head-to-toe scale: (1)
straight-on front, (2) strict 90-degree side profile, and (3) direct back. Use the
same neutral stance, body proportions, complete outfit, accessories, colors and
materials in all three views. Keep both shoes fully inside the sheet. Necks below
the jaw, clothing, arms, hands, legs and footwear remain continuous photographic
images with no cracks, glass or missing areas. The back view must face completely
away and reveal no facial feature or facial profile; its back-of-head hair remains
a normal photorealistic photograph.

HEAD-TO-BODY SCALE LOCK: every head — drawn or photographic — must be a normal
adult head on that same body, about 1/7.5 to 1/8 of the full standing height. The
drawn jaw sits exactly on the photographic neck and matches its width. Hard
failure: bobblehead, oversized sketch cranium, manga-scale head, or a drawn head
wider than the shoulders.

DRAWN HEADS ON FRONT AND SIDE BODIES: replace the complete visible head region in
the front and side views — face, ears, hairline and all head hair — with a clean,
unmistakably hand-drawn graphite-pencil or fine-ink illustration aligned naturally
to the photographic neck. The front body receives one frontal drawn head; the
side body receives one strict 90-degree-profile drawn head. Never show any
photographic face, photographic skin or photographic hair inside those two heads.
Do not break or fragment them. Use simple editorial drawing: confident outer
contours, light varied line pressure, simplified facial planes, open white paper
inside the head silhouette, minimal tonal buildup and sparse delicate hatching in
the hair and beneath the chin. Group hair into readable locks with few interior
strokes; keep most facial skin unshaded. Do not use dense scribbling, heavy
cross-hatching, hyperreal pencil shading, photographic gradients, a desaturated
photograph, digital airbrush or 3D rendering.

RIGHT 30% — LARGE BROKEN PHOTOGRAPHIC PORTRAIT: after one thin black vertical
divider, show one dominant, large, front-facing head-and-shoulders portrait of the
same character. It must be unmistakably photorealistic — a believable real
photograph taken on a professional camera in natural daylight — with natural skin
variation, stable asymmetry, realistic eyes, individual hair and flyaways,
restrained contrast, true-to-life color and subtle sensor grain.

RIGHT PANEL GROUND: the entire right 30% uses the SAME flat off-white sheet
background as the left (#F7F6F2). Do NOT place snow, trees, sky, street, bokeh
landscape, studio seamless or any real environment behind the portrait. Shoulders,
collar, tie and upper chest remain one intact photographic garment on off-white.
Only the head plus all head hair is shattered. A winter scene or outdoor
background anywhere on the sheet is a hard failure.

THE RIGHT PORTRAIT IS THE ONLY SHATTERED ELEMENT: this is NOT cracked glass laid
over an intact photo. Cut the COMPLETE VISIBLE PHOTOGRAPHIC HEAD — FACE PLUS ALL
SURROUNDING HEAD HAIR — into EXACTLY SIX large, physically disconnected, closed
glass polygons floating on empty off-white. Together, the six pieces must
unmistakably reconstruct one aligned readable head: eyes/brow, nose, cheeks, lips,
chin, jaw, skin, hairline and outer hair silhouette. Every piece carries
substantial photographic face and/or hair content; never create transparent empty
panes, blank wedges or a hollow mask. Use exactly two upper pieces, two middle
pieces and two lower pieces — upper-left, upper-right, middle-left, middle-right,
lower-left and lower-right — around one empty pure-white impact opening near the
lower nose or mouth. There is NO central seventh piece and NO star-shaped hole
that eats the eyes.

PURE-WHITE GAP CONTRACT: use broad clean gaps around 6-8% of the complete
head-portrait width and a central opening around 12-15%. Between all six pieces
show ONLY flat pure white #FFFFFF, completely empty. No face, hair, skin, body,
coat, landscape, portrait continuation, texture, reflection, translucent glass or
hidden intact head may exist beneath or between the shards. Shadows may touch only
the immediate shard edge and must not fill or darken a gap. Each piece has its own
complete thin silver-gray perimeter; the pieces do not touch or share a center
ring. No drawn crack-line overlay, secondary cracks, small chips or internal
subdivisions.

IDENTITY SOURCE CONTRACT: the large broken photograph on the right is the
canonical source for facial identity, skin, eyes and hair. The photographic
bodies on the left are the source for body proportions, outfit, colors,
accessories and materials. The two left drawings are only front/profile
orientation guides. Preserve the same identity, hairstyle, age, body and wardrobe
across every view.

Functional editorial reference only: exactly one character, exactly three
full-body turnaround views on the left plus one large broken photographic portrait
on the right, no extra faces, no thumbnail collage, no text besides $name, no
logo and no watermark. Any intact photographic face anywhere on the sheet is a
hard failure. Glass appears only on the large right portrait.''';
}
