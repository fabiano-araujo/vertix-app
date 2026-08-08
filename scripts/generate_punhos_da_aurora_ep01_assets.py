#!/usr/bin/env python3
"""Create local production assets for Punhos da Aurora episode 1."""

from __future__ import annotations

import argparse
import json
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "punhos_da_aurora_assets" / "episodes" / "ep01"
STORYBOARD_DIR = OUT_DIR / "storyboards"


SEGMENTS = [
    {
        "id": "segment01",
        "label": "1A",
        "scene_number": 1,
        "duration": 12,
        "seed": 901101,
        "output": "punhos_da_aurora_ep01_1A.mp4",
        "title": "Chegada ao Mercado das Lanternas",
        "visible_characters": ["Kael", "Iro"],
        "speaking_characters": ["Kael", "Iro"],
        "visible_locations": ["Mercado das Lanternas"],
        "transition": "episode opening. Start with wonder and end with Kael under the Sino Solar.",
        "scene": "Kael and Iro enter the floating lantern market, establishing the magical city and Kael's dream.",
        "prompt": (
            "Kael and Iro in the Mercado das Lanternas, vertical 9:16 enchanting shonen anime, 12s. "
            "Floating lanterns and glowing fish surround Kael as he walks amazed, holding his gold pendant. "
            "Light curious rhythm, smooth low tracking camera, Brazilian Portuguese voices. Keep Kael and Iro matching references. "
            "No subtitles, logos, or extra foreground characters."
        ),
        "dialogue": [
            {"start": 3.0, "end": 5.3, "speaker": "Kael", "pt_BR": "E aqui que campeoes nascem.", "en_US": "This is where champions are born."},
            {"start": 5.4, "end": 8.1, "speaker": "Iro", "pt_BR": "Ou onde idiotas assinam sem ler.", "en_US": "Or where fools sign without reading."},
        ],
        "panels": [
            "Wide market: lanterns float above bridges, Kael and Iro enter.",
            "Kael holds the pendant and smiles at the tournament banners.",
            "Iro circles Kael, teasing him as glowing fish pass.",
            "Kael stops under the huge Sino Solar, unaware it is reacting.",
        ],
    },
    {
        "id": "segment02",
        "label": "1B",
        "scene_number": 2,
        "duration": 10,
        "seed": 901102,
        "output": "punhos_da_aurora_ep01_1B.mp4",
        "title": "O Sino Apaga",
        "visible_characters": ["Kael", "Iro", "Automato"],
        "speaking_characters": ["Automato", "Kael"],
        "visible_locations": ["Mercado das Lanternas"],
        "transition": "continuous from segment 1A. The wonder freezes into threat when the bell reacts.",
        "scene": "The solar bell dims and a masked automaton appears, confirming Kael as the target.",
        "prompt": (
            "The Sino Solar above Kael, vertical 9:16 shonen anime, 10s. The bell goes dark, the market freezes, "
            "and a masked automaton steps from behind lanterns, aiming at Kael's pendant. Wonder turns into threat, "
            "push-in on Kael's confused face. Keep Kael and automaton matching references. No subtitles, split-screen, or costume redesigns."
        ),
        "dialogue": [
            {"start": 3.0, "end": 5.0, "speaker": "Automato", "pt_BR": "Portador confirmado.", "en_US": "Bearer confirmed."},
            {"start": 5.2, "end": 7.0, "speaker": "Kael", "pt_BR": "Portador de que?", "en_US": "Bearer of what?"},
        ],
        "panels": [
            "Close on the Sino Solar dimming above the market.",
            "Crowd freezes, lanterns stop drifting, Kael looks up.",
            "The automaton unfolds from shadow with a white mask.",
            "Its red eye locks onto Kael's pendant.",
        ],
    },
    {
        "id": "segment03",
        "label": "1C",
        "scene_number": 3,
        "duration": 15,
        "seed": 901103,
        "output": "punhos_da_aurora_ep01_1C.mp4",
        "title": "Luta Caotica",
        "visible_characters": ["Kael", "Iro", "Automato"],
        "speaking_characters": ["Iro"],
        "visible_locations": ["Mercado das Lanternas"],
        "transition": "continuous from segment 1B. Start as the automaton lunges for the pendant.",
        "scene": "Kael fights with beautiful golden power but no control, putting the market at risk.",
        "prompt": (
            "Kael fighting the automaton in the lantern market, vertical 9:16 high-energy shonen anime, 15s. "
            "Kael throws golden light punches while shadow blades dodge between stalls, nearly dropping lanterns onto civilians. "
            "Fast chaotic rhythm, readable impacts, ending on Kael noticing the danger. Keep references consistent. "
            "No blood, logos, or random fighters."
        ),
        "dialogue": [
            {"start": 5.0, "end": 8.0, "speaker": "Iro", "pt_BR": "Kael, mira nele, nao no bairro inteiro!", "en_US": "Kael, aim at him, not the whole district!"},
        ],
        "panels": [
            "Automaton lunges, Kael blocks with a golden fist.",
            "Kael's punch misses and shakes a lantern stall.",
            "Shadow blades force Kael backward through the crowd path.",
            "Kael sees civilians under falling lanterns and hesitates.",
        ],
    },
    {
        "id": "segment04",
        "label": "1D",
        "scene_number": 4,
        "duration": 12,
        "seed": 901104,
        "output": "punhos_da_aurora_ep01_1D.mp4",
        "title": "Mira Da Direcao",
        "visible_characters": ["Kael", "Mira", "Automato"],
        "speaking_characters": ["Mira", "Kael"],
        "visible_locations": ["Mercado das Lanternas"],
        "transition": "continuous from segment 1C. Mira enters because Kael's uncontrolled attack endangers civilians.",
        "scene": "Mira redirects danger with wind ribbons and turns the conversation into a tactical lesson.",
        "prompt": (
            "Mira between Kael and civilians, vertical 9:16 enchanting shonen anime, 12s. She catches falling lanterns with wind ribbons, "
            "protects children, and faces Kael with calm pressure. Pause-tension-restart rhythm; Mira says in Brazilian Portuguese, "
            "\"Forca sem direcao so quebra coisa bonita.\" Keep Mira and Kael matching references. No subtitles, outfit changes, or shaky blur."
        ),
        "dialogue": [
            {"start": 3.0, "end": 6.2, "speaker": "Mira", "pt_BR": "Forca sem direcao so quebra coisa bonita.", "en_US": "Power without direction only breaks beautiful things."},
            {"start": 7.0, "end": 9.0, "speaker": "Kael", "pt_BR": "Entao me da uma direcao.", "en_US": "Then give me a direction."},
        ],
        "panels": [
            "Mira lands between falling lanterns and children.",
            "Wind ribbons lift debris while Kael turns toward her.",
            "Mira points at the automaton's rhythm, not at Kael.",
            "Kael lowers his stance, finally listening.",
        ],
    },
    {
        "id": "segment05",
        "label": "1E",
        "scene_number": 5,
        "duration": 13,
        "seed": 901105,
        "output": "punhos_da_aurora_ep01_1E.mp4",
        "title": "O Alvo Real",
        "visible_characters": ["Kael", "Mira", "Automato"],
        "speaking_characters": ["Kael"],
        "visible_locations": ["Mercado das Lanternas"],
        "transition": "continuous from segment 1D. Start with Kael and Mira coordinating for the first time.",
        "scene": "The automaton reveals that it wants the pendant, not the victory.",
        "prompt": (
            "The automaton grabbing for Kael's pendant, vertical 9:16 shonen anime, 13s. Shadow blades trap Kael's arm while Mira's wind ribbons "
            "hold the crowd back; the pendant glows and Kael understands the target. Tight urgent rhythm, closeups on hand, face, pendant. "
            "Keep references consistent. No subtitles, logos, or confusing cuts."
        ),
        "dialogue": [
            {"start": 8.0, "end": 11.0, "speaker": "Kael", "pt_BR": "Ele nao quer me vencer. Quer isso.", "en_US": "It does not want to beat me. It wants this."},
        ],
        "panels": [
            "Kael and Mira flank the automaton in the market lane.",
            "Shadow blade wraps Kael's wrist near the pendant.",
            "Closeup: pendant flares gold against black shadow.",
            "Kael's eyes focus; Mira clears space for his counter.",
        ],
    },
    {
        "id": "segment06",
        "label": "1F",
        "scene_number": 6,
        "duration": 15,
        "seed": 901106,
        "output": "punhos_da_aurora_ep01_1F.mp4",
        "title": "A Aurora Acorda",
        "visible_characters": ["Kael", "Mira", "Automato", "Ren"],
        "speaking_characters": ["Kael", "Ren"],
        "visible_locations": ["Mercado das Lanternas"],
        "transition": "continuous from segment 1E. Start with Kael focused and the pendant glowing.",
        "scene": "Kael turns fear into rhythm, defeats the automaton, and Ren names the hidden threat.",
        "prompt": (
            "Kael releasing the Aurora strike in the lantern market, vertical 9:16 enchanting shonen anime, 15s. He breathes, plants his feet, "
            "spirals golden light around both fists, and defeats the automaton as the Sino Solar reignites. Emotional silence becomes brilliant impact; "
            "end on Ren watching from a rooftop. No subtitles, split-screen, or storyboard panels."
        ),
        "dialogue": [
            {"start": 2.0, "end": 4.5, "speaker": "Kael", "pt_BR": "Eu nao vou perder isso tambem.", "en_US": "I will not lose this too."},
            {"start": 12.0, "end": 15.0, "speaker": "Ren", "pt_BR": "A Aurora Negra acordou.", "en_US": "The Black Aurora has awakened."},
        ],
        "panels": [
            "Kael breathes, feet planted, pendant glowing at his chest.",
            "Golden spiral wraps his fists; Mira shields the crowd.",
            "Uppercut of light defeats the automaton and relights the bell.",
            "Ren watches from a rooftop, blue lightning behind him.",
        ],
    },
]


COLORS = {
    "bg": (20, 18, 35),
    "panel": (34, 29, 58),
    "ink": (243, 238, 220),
    "muted": (190, 185, 205),
    "gold": (255, 202, 70),
    "teal": (96, 223, 220),
    "blue": (75, 155, 255),
    "red": (240, 78, 78),
    "shadow": (23, 21, 32),
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


def wrap_text(text: str, width: int) -> str:
    return "\n".join(textwrap.wrap(text, width=width))


def draw_energy(draw: ImageDraw.ImageDraw, center: tuple[int, int], color: tuple[int, int, int], radius: int) -> None:
    x, y = center
    for step in range(4):
        r = radius + step * 18
        draw.ellipse((x - r, y - r, x + r, y + r), outline=color, width=max(2, 7 - step))


def draw_arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color=(75, 155, 255)) -> None:
    draw.line((*start, *end), fill=color, width=8)
    ex, ey = end
    sx, sy = start
    dx = 1 if ex >= sx else -1
    dy = 1 if ey >= sy else -1
    draw.polygon([(ex, ey), (ex - 24 * dx, ey - 8 * dy), (ex - 8 * dx, ey - 24 * dy)], fill=color)


def draw_character(draw: ImageDraw.ImageDraw, name: str, x: int, y: int, scale: float = 1.0) -> None:
    h = int(120 * scale)
    w = int(54 * scale)
    if name == "Kael":
        body = (245, 185, 60)
        accent = (255, 230, 105)
        hair = (24, 24, 30)
    elif name == "Mira":
        body = (64, 190, 185)
        accent = (190, 255, 245)
        hair = (35, 42, 65)
    elif name == "Ren":
        body = (65, 110, 240)
        accent = (160, 210, 255)
        hair = (20, 25, 52)
    elif name == "Automato":
        body = (36, 35, 44)
        accent = (225, 225, 220)
        hair = (13, 12, 18)
    else:
        body = (255, 205, 80)
        accent = (255, 248, 175)
        hair = (255, 205, 80)

    if name == "Iro":
        draw.ellipse((x - 28, y - 38, x + 28, y + 18), fill=body, outline=accent, width=5)
        draw.rectangle((x - 15, y + 12, x + 15, y + 45), fill=(120, 75, 25))
        draw_energy(draw, (x, y - 10), accent, 42)
        return

    draw.ellipse((x - w // 2, y - h, x + w // 2, y - h + w), fill=(230, 188, 142), outline=COLORS["ink"], width=3)
    draw.polygon([(x - w, y - h + 10), (x, y - h - 24), (x + w, y - h + 10)], fill=hair)
    draw.rounded_rectangle((x - w, y - h + w, x + w, y + 20), radius=18, fill=body, outline=COLORS["ink"], width=3)
    draw.line((x - w, y - h + w + 22, x - int(1.4 * w), y - 10), fill=accent, width=8)
    draw.line((x + w, y - h + w + 22, x + int(1.4 * w), y - 10), fill=accent, width=8)
    draw.line((x - 18, y + 20, x - 34, y + 74), fill=body, width=10)
    draw.line((x + 18, y + 20, x + 34, y + 74), fill=body, width=10)
    if name == "Automato":
        draw.rectangle((x - 22, y - h + 14, x + 22, y - h + 46), fill=accent)
        draw.ellipse((x + 8, y - h + 24, x + 18, y - h + 34), fill=COLORS["red"])


def draw_panel_art(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], segment: dict, index: int) -> None:
    x1, y1, x2, y2 = box
    cx = (x1 + x2) // 2
    cy = (y1 + y2) // 2
    draw.rounded_rectangle(box, radius=18, fill=COLORS["panel"], outline=(210, 44, 65), width=5)

    # Lantern market background.
    for offset in range(5):
        lx = x1 + 70 + offset * 90
        ly = y1 + 55 + (offset % 2) * 45
        draw.ellipse((lx, ly, lx + 34, ly + 42), fill=(255, 190, 75), outline=(255, 235, 160), width=2)
        draw.line((lx + 17, ly + 42, lx + 17, ly + 66), fill=(255, 225, 125), width=2)
    draw.rectangle((x1 + 30, y2 - 110, x2 - 30, y2 - 45), fill=(58, 45, 76))

    label = segment["label"]
    if label == "1A":
        draw_character(draw, "Kael", cx - 80 + index * 20, cy + 95, 0.9)
        draw_character(draw, "Iro", cx + 115, cy - 20 + index * 8, 0.8)
        if index == 3:
            draw.ellipse((cx - 95, y1 + 45, cx + 95, y1 + 235), outline=COLORS["gold"], width=10)
    elif label == "1B":
        draw_character(draw, "Kael", cx - 85, cy + 100, 0.9)
        if index >= 1:
            draw_character(draw, "Automato", cx + 95, cy + 105, 0.95)
        if index == 0:
            draw.ellipse((cx - 90, y1 + 45, cx + 90, y1 + 225), outline=(80, 70, 90), width=12)
        if index == 3:
            draw_arrow(draw, (cx + 75, cy - 45), (cx - 35, cy + 35), COLORS["red"])
    elif label == "1C":
        draw_character(draw, "Kael", cx - 110, cy + 115, 0.9)
        draw_character(draw, "Automato", cx + 110, cy + 105, 0.95)
        draw_energy(draw, (cx - 90, cy + 5), COLORS["gold"], 45)
        draw.line((cx + 80, cy - 30, cx - 10, cy + 65), fill=(80, 40, 100), width=11)
        draw_arrow(draw, (cx - 115, cy - 35), (cx + 85, cy - 55), COLORS["blue"])
    elif label == "1D":
        draw_character(draw, "Mira", cx - 75, cy + 115, 0.9)
        draw_character(draw, "Kael", cx + 95, cy + 120, 0.8)
        for k in range(3):
            draw.arc((cx - 160 + k * 26, cy - 95, cx + 95 + k * 28, cy + 95), 205, 340, fill=COLORS["teal"], width=8)
    elif label == "1E":
        draw_character(draw, "Kael", cx - 75, cy + 115, 0.9)
        draw_character(draw, "Automato", cx + 105, cy + 110, 0.9)
        draw.line((cx + 80, cy - 35, cx - 55, cy + 20), fill=(52, 25, 75), width=13)
        draw_energy(draw, (cx - 45, cy + 5), COLORS["gold"], 36)
    elif label == "1F":
        draw_character(draw, "Kael", cx - 55, cy + 120, 0.95)
        if index < 3:
            draw_character(draw, "Automato", cx + 110, cy + 110, 0.9)
            draw_energy(draw, (cx - 35, cy + 10), COLORS["gold"], 60 + index * 8)
            draw_arrow(draw, (cx - 55, cy + 10), (cx + 105, cy - 30), COLORS["gold"])
        else:
            draw_character(draw, "Ren", cx + 80, cy + 100, 0.9)
            draw.line((cx + 40, cy - 50, cx + 130, cy - 120), fill=COLORS["blue"], width=9)


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], width: int, fill, fnt, line_gap: int = 4) -> None:
    x, y = xy
    avg = max(1, int(fnt.size * 0.55)) if hasattr(fnt, "size") else 8
    for line in textwrap.wrap(text, width=max(12, width // avg)):
        draw.text((x, y), line, fill=fill, font=fnt)
        y += int((getattr(fnt, "size", 14) + line_gap) * 1.05)


def create_storyboard(segment: dict) -> Path:
    STORYBOARD_DIR.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGB", (1080, 1920), COLORS["bg"])
    draw = ImageDraw.Draw(image)

    title_font = font(42, True)
    small_font = font(24)
    note_font = font(26)

    draw.rectangle((0, 0, 1080, 128), fill=(15, 14, 28))
    draw.text((40, 24), f"Punhos da Aurora EP01 - Segmento {segment['label']}", fill=COLORS["ink"], font=title_font)
    draw.text((42, 78), f"{segment['title']} | {segment['duration']}s | storyboard de geracao", fill=COLORS["muted"], font=small_font)

    panel_boxes = [
        (45, 155, 520, 835),
        (560, 155, 1035, 835),
        (45, 875, 520, 1555),
        (560, 875, 1035, 1555),
    ]
    for index, box in enumerate(panel_boxes):
        draw_panel_art(draw, box, segment, index)
        x1, y1, x2, y2 = box
        draw.rectangle((x1 + 10, y2 - 145, x2 - 10, y2 - 10), fill=(18, 16, 30))
        time_label = ["inicio", "cedo", "meio", "ponte"][index]
        draw.text((x1 + 22, y2 - 134), f"{index + 1}. {time_label}", fill=COLORS["gold"], font=small_font)
        draw_wrapped(draw, segment["panels"][index], (x1 + 22, y2 - 96), x2 - x1 - 44, COLORS["ink"], note_font)

    bottom_y = 1605
    draw.rounded_rectangle((45, bottom_y, 1035, 1878), radius=24, fill=(26, 22, 42), outline=(95, 82, 130), width=3)
    draw.text((70, bottom_y + 24), "Continuidade", fill=COLORS["gold"], font=font(30, True))
    draw_wrapped(draw, segment["transition"], (70, bottom_y + 66), 610, COLORS["ink"], note_font)
    draw.text((720, bottom_y + 24), "Personagens", fill=COLORS["teal"], font=font(30, True))
    draw_wrapped(draw, ", ".join(segment["visible_characters"]), (720, bottom_y + 66), 270, COLORS["ink"], note_font)
    for idx, color in enumerate([COLORS["gold"], COLORS["teal"], COLORS["blue"], COLORS["red"], (255, 245, 170)]):
        draw.rectangle((720 + idx * 52, bottom_y + 148, 760 + idx * 52, bottom_y + 188), fill=color)

    path = STORYBOARD_DIR / f"punhos_da_aurora_ep01_{segment['label']}_storyboard.png"
    image.save(path, quality=95)
    return path


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.strip() + "\n", encoding="utf-8")


def make_config(reference_urls: dict[str, str]) -> dict:
    refs = {
        f"storyboard_{segment['label']}": reference_urls.get(
            segment["label"],
            str((STORYBOARD_DIR / f"punhos_da_aurora_ep01_{segment['label']}_storyboard.png").resolve()),
        )
        for segment in SEGMENTS
    }
    return {
        "series": "Punhos da Aurora",
        "episode_number": 1,
        "endpoint": "https://api.segmind.com/v1/seedance-2.0",
        "api_key_env": "SEGMIND_API_KEY",
        "output_dir": "punhos_da_aurora_assets/episodes/ep01",
        "final_output": "punhos_da_aurora_ep01_77s.mp4",
        "final_contact_sheet": "punhos_da_aurora_ep01_contact_sheet.jpg",
        "pt_br_srt": "punhos_da_aurora_ep01_pt-BR.srt",
        "en_us_srt": "punhos_da_aurora_ep01_en-US.srt",
        "timeline_json": "punhos_da_aurora_ep01_timeline.json",
        "result_json": "punhos_da_aurora_ep01_final_result.json",
        "tools": {
            "ffmpeg": ".codex_tools/ffmpeg/ffmpeg-8.1.1-essentials_build/bin/ffmpeg.exe",
            "ffprobe": ".codex_tools/ffmpeg/ffmpeg-8.1.1-essentials_build/bin/ffprobe.exe",
        },
        "fixed": {
            "format": "Original vertical 9:16 enchanting shonen anime scene with synchronized Brazilian Portuguese dialogue and sound",
            "resolution": "480p",
            "aspect_ratio": "9:16",
            "generate_audio": True,
            "return_last_frame": True,
            "skip_moderation": False,
            "brazilian_portuguese_lock": "All spoken dialogue must be Brazilian Portuguese from Brazil, neutral Brazilian accent, clear, short and natural. No European Portuguese, Spanish, English, invented language or mumbling.",
            "negative_constraints": "no subtitles, no logos, no watermark, no storyboard panels, no split-screen, no character redesign, no extra main characters, no gore",
        },
        "final": {"width": 480, "height": 854, "fps": 24, "crf": 20},
        "references": refs,
        "audio_references": {},
        "voice_profiles": {
            "Kael": "Brazilian Portuguese, neutral Brazil accent, 15-year-old boy, energetic but warm shonen protagonist, clear emotional delivery.",
            "Iro": "Brazilian Portuguese, neutral Brazil accent, tiny lantern spirit, high quick comic voice, clear diction.",
            "Mira": "Brazilian Portuguese, neutral Brazil accent, 16-year-old girl, calm precise strategist, firm but kind.",
            "Automato": "Brazilian Portuguese, neutral Brazil accent, mechanical low masked voice, short phrases, slight metallic processing.",
            "Ren": "Brazilian Portuguese, neutral Brazil accent, 16-year-old rival, quiet cold voice, controlled pace.",
        },
        "scenes": [
            {
                "id": segment["id"],
                "scene_number": segment["scene_number"],
                "duration": segment["duration"],
                "seed": segment["seed"],
                "output": segment["output"],
                "reference_frame_second": max(1, segment["duration"] - 2),
                "reference_keys": [f"storyboard_{segment['label']}"],
                "reference_notes": "Use image 1 only for storyboard sequence and staging. Render one full-screen 9:16 video, not panels, borders, arrows, labels, captions, palette blocks, character-sheet layout, or split-screen.",
                "visible_characters": segment["visible_characters"],
                "visible_vehicles": [],
                "visible_locations": segment["visible_locations"],
                "speaking_characters": segment["speaking_characters"],
                "transition": segment["transition"],
                "scene": segment["scene"],
                "prompt": segment["prompt"],
                "action_timing": [
                    {"time": "0-25%", "text": segment["panels"][0]},
                    {"time": "25-50%", "text": segment["panels"][1]},
                    {"time": "50-75%", "text": segment["panels"][2]},
                    {"time": "75-100%", "text": segment["panels"][3]},
                ],
                "camera": "Vertical phone composition, dynamic anime framing, readable faces and clean action silhouettes.",
                "audio": "Brazilian Portuguese only. Dialogue louder than music. Magical shonen percussion, lantern chimes, clean impact SFX.",
                "dialogue": segment["dialogue"],
            }
            for segment in SEGMENTS
        ],
    }


def make_contact_sheet(paths: list[Path]) -> None:
    thumbs = []
    for path in paths:
        img = Image.open(path).convert("RGB")
        img.thumbnail((260, 462))
        thumbs.append(img.copy())
    sheet = Image.new("RGB", (3 * 300, 2 * 515), (18, 16, 30))
    draw = ImageDraw.Draw(sheet)
    for idx, img in enumerate(thumbs):
        x = (idx % 3) * 300 + 20
        y = (idx // 3) * 515 + 20
        sheet.paste(img, (x, y))
        draw.text((x, y + img.height + 8), SEGMENTS[idx]["label"], fill=COLORS["ink"], font=font(24, True))
    sheet.save(STORYBOARD_DIR / "punhos_da_aurora_ep01_storyboards_contact.jpg", quality=92)


def episode_markdown() -> str:
    return """
# Punhos da Aurora - EP01 - O Garoto Que Acendeu o Sino

## Tratamento linear

Kael chega ao Mercado das Lanternas com Iro, maravilhado pela cidade viva de Hinora. Ele quer se inscrever no Torneio das Sete Chamas, mas finge confiança para esconder que nunca lutou numa arena real. Quando passa sob o Sino Solar, o sino apaga por um segundo e todos sentem o ar mudar. Um automato mascarado surge da multidao e ataca o pingente de Kael.

Kael responde com forca bruta, seus punhos dourados iluminam o mercado, mas ele quase fere civis e derruba barracas. Mira entra na luta, nao para salvar Kael, mas para proteger as pessoas e obriga-lo a lutar com direcao. O automato revela laminas de sombra e tenta arrancar o pingente. Kael entende que o inimigo nao quer vence-lo, quer testar sua energia. Ele respira, lembra da voz da mae e transforma o caos em ritmo: esquiva, protege, contra-ataca. O golpe final acende o Sino Solar inteiro. No telhado, Ren observa e diz que a maldicao acordou.

## Plano de segmentos

1A. Chegada encantadora: sonho, humor e mercado vivo.
1B. O sino apaga: pressagio e surgimento do automato.
1C. Luta caotica: poder bonito, mas sem controle.
1D. Mira intervem: protecao de civis e direcao emocional.
1E. O alvo real: o pingente vira centro da luta.
1F. Aurora: Kael encontra foco, vence e Ren cria o cliffhanger.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uploads", type=Path, help="Optional JSON mapping labels 1A..1F to uploaded storyboard URLs.")
    args = parser.parse_args()

    reference_urls = {}
    if args.uploads and args.uploads.exists():
        reference_urls = json.loads(args.uploads.read_text(encoding="utf-8"))

    paths = [create_storyboard(segment) for segment in SEGMENTS]
    make_contact_sheet(paths)
    write_text(OUT_DIR / "punhos_da_aurora_ep01_story_plan.md", episode_markdown())
    write_json(OUT_DIR / "punhos_da_aurora_ep01_storyboards_local.json", {
        segment["label"]: str(path) for segment, path in zip(SEGMENTS, paths)
    })
    write_json(OUT_DIR / "punhos_da_aurora_ep01_config.json", make_config(reference_urls))
    print(json.dumps({
        "output_dir": str(OUT_DIR),
        "storyboards": [str(path) for path in paths],
        "contact_sheet": str(STORYBOARD_DIR / "punhos_da_aurora_ep01_storyboards_contact.jpg"),
        "config": str(OUT_DIR / "punhos_da_aurora_ep01_config.json"),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
