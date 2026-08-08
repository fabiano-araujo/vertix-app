#!/usr/bin/env python3
"""
Small Seedance/Segmind production helper for short-form series.

The script keeps fixed language, voice, reference, and output settings in a
JSON episode file, then generates takes, post-processes previews, and assembles
the final vertical episode.
"""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import mimetypes
import os
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SEGMIND_ENDPOINT = "https://api.segmind.com/v1/seedance-2.0"
DIALOGUE_EDGE_SILENCE_SECONDS = 1.0
TIME_EPSILON = 0.001


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=2)
        file.write("\n")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def json_hash(data: Any) -> str:
    encoded = json.dumps(data, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(cmd: list[str], *, quiet: bool = False) -> None:
    if not quiet:
        print(" ".join(cmd))
    subprocess.run(cmd, check=True)


def get_api_key(config: dict[str, Any], cli_key: str | None) -> str:
    if cli_key:
        return cli_key
    env_name = config.get("api_key_env", "SEGMIND_API_KEY")
    api_key = os.environ.get(env_name)
    if not api_key:
        raise SystemExit(f"Missing API key. Set ${env_name} or pass --api-key.")
    return api_key


def resolve_path(root: Path, value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return root / path


def scene_by_id(config: dict[str, Any], scene_id: str) -> dict[str, Any]:
    for scene in config["scenes"]:
        if scene["id"] == scene_id:
            return scene
    raise SystemExit(f"Scene not found: {scene_id}")


def character_profile(config: dict[str, Any], name: str) -> dict[str, Any]:
    return config.get("character_assets", {}).get(name, {})


def voice_profile(config: dict[str, Any], name: str) -> str | None:
    profile = character_profile(config, name).get("voice_profile")
    if profile:
        return profile
    return config.get("voice_profiles", {}).get(name)


def voice_contract(config: dict[str, Any], speakers: list[str]) -> str:
    parts = []
    for speaker in speakers:
        profile = voice_profile(config, speaker)
        if profile:
            parts.append(f"{speaker}: {profile}")
        else:
            parts.append(f"{speaker}: missing voice profile; add it before generation.")
    return " ".join(parts)


def fmt_seconds(value: Any) -> str:
    try:
        return f"{float(value):.1f}s"
    except (TypeError, ValueError):
        return "?.?s"


def dialogue_time(item: dict[str, Any], primary: str, fallback: str) -> float:
    value = item.get(primary, item.get(fallback))
    if value is None:
        raise SystemExit(f"Dialogue line is missing {primary!r}: {item}")
    try:
        return float(value)
    except (TypeError, ValueError) as error:
        raise SystemExit(f"Dialogue line has invalid {primary!r}: {item}") from error


def validate_dialogue_boundaries(scene: dict[str, Any]) -> None:
    duration = float(scene.get("duration", 15))
    safe_start = DIALOGUE_EDGE_SILENCE_SECONDS
    safe_end = duration - DIALOGUE_EDGE_SILENCE_SECONDS

    for item in scene.get("dialogue", []):
        start = dialogue_time(item, "start", "start_seconds")
        end = dialogue_time(item, "end", "end_seconds")
        speaker = item.get("speaker") or item.get("character") or "Unknown"
        line = item.get("pt_BR") or item.get("line_pt_BR") or item.get("line") or ""

        if end <= start:
            raise SystemExit(
                f"{scene['id']} dialogue for {speaker!r} ends before it starts: "
                f"{start:.1f}s-{end:.1f}s."
            )

        if start < safe_start - TIME_EPSILON:
            raise SystemExit(
                f"{scene['id']} dialogue for {speaker!r} starts at {start:.1f}s. "
                f"Keep speech after {safe_start:.1f}s so the take has a clean entry."
            )

        if end > safe_end + TIME_EPSILON:
            raise SystemExit(
                f"{scene['id']} dialogue for {speaker!r} ends at {end:.1f}s in a "
                f"{duration:.1f}s take. Keep speech before {safe_end:.1f}s. "
                f"If the line lands at {duration:.1f}s, move it to 1.0s of the "
                f"next take, which is {duration + 1.0:.1f}s in this local episode "
                f"window. Line: {line!r}"
            )

        if abs(start - duration) <= TIME_EPSILON or abs(end - duration) <= TIME_EPSILON:
            raise SystemExit(
                f"{scene['id']} dialogue for {speaker!r} is placed on the exact "
                f"{duration:.1f}s cut point. {duration:.1f}s is not usable speech "
                f"time; move it to 1.0s of the next take."
            )


def dialogue_timing_contract(config: dict[str, Any], scene: dict[str, Any]) -> str:
    dialogue = scene.get("dialogue", [])
    if not dialogue:
        return "Timed dialogue: no spoken dialogue in this take."

    lines = []
    for item in dialogue:
        speaker = item.get("speaker") or item.get("character") or "Unknown"
        line = item.get("pt_BR") or item.get("line_pt_BR") or item.get("line") or ""
        start = fmt_seconds(item.get("start", item.get("start_seconds")))
        end = fmt_seconds(item.get("end", item.get("end_seconds")))
        tone = item.get("tone") or item.get("emotional_tone") or item.get("emotion") or "natural"
        pace = item.get("pace") or item.get("delivery_pace") or "natural"
        continuity = (
            item.get("continuity_status")
            or item.get("continuity")
            or "complete_in_this_take"
        )
        profile = voice_profile(config, speaker) or "missing voice profile; add it before generation"
        lines.append(
            f"{start}-{end} {speaker} ({tone}, {pace}; voice: {profile}): "
            f"\"{line}\" [{continuity}]"
        )

    return "Timed dialogue: " + " ".join(lines)


def dialogue_boundary_contract() -> str:
    return (
        "Dialogue boundary: finish complete words only. Do not cut a word, "
        "syllable, or phoneme at the segment edge. In a 15s take, 15.0s is "
        "the cut point, not usable speech time; keep speech inside 1.0s-14.0s. "
        "If a thought continues, split at a clean phrase and continue the same "
        "speaker, voice, tone, and topic at 1.0s of the next take."
    )


def speech_clarity_contract(config: dict[str, Any], scene: dict[str, Any]) -> str | None:
    if not scene.get("speaking_characters"):
        return None
    fixed = config.get("fixed", {})
    return fixed.get(
        "speech_clarity_lock",
        (
            "Brazilian Portuguese audio lock for this entire take: all spoken "
            "dialogue, reactions, vocalizations, background voices, and improvised "
            "audio must be in Portuguese from Brazil only. Speak the exact written "
            "dialogue lines without rewriting, translating, shortening, adding "
            "words, or inventing language. No English, Spanish, European "
            "Portuguese, gibberish, mumbling, or mixed-language speech."
        ),
    )


def active_take_rhythm_contract(config: dict[str, Any], scene: dict[str, Any]) -> str | None:
    fixed = config.get("fixed", {})
    configured = fixed.get("active_take_rhythm_contract")
    if configured is False:
        return None
    if isinstance(configured, str) and configured.strip():
        return configured.strip()

    return (
        "Narrative logic contract: every generated take must feel like a "
        "readable slice of one continuous story, not disconnected shots or "
        "random dialogue. Each visible beat needs a cause, a character "
        "reaction, and a consequence that motivates the next beat. Before a "
        "character speaks, show what they are reacting to, what they want, or "
        "what just changed between the characters. Before a command, decision, "
        "confession, joke, reveal, interruption, or protective action, show the "
        "trigger that makes it necessary. Dialogue must advance relationship, "
        "information, pressure, choice, emotion, or the next action; avoid "
        "lines that could be said in any scene. For any genre or mood, preserve "
        "motivation and continuity: characters notice, interpret, choose, and "
        "react based on the immediately previous beat. Avoid sudden mood "
        "changes, random commands, unexplained objects or effects, exposition "
        "without a trigger, static posing, and camera holds that do not reveal "
        "new information or emotion."
    )


def compact_spatial_value(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        return "; ".join(compact_spatial_value(item) for item in value if compact_spatial_value(item))
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            text = compact_spatial_value(item)
            if text:
                parts.append(f"{key}: {text}")
        return "; ".join(parts)
    if value is None:
        return ""
    return str(value)


def spatial_continuity_contract(scene: dict[str, Any]) -> str | None:
    spatial = (
        scene.get("spatial_continuity")
        or scene.get("spatial_notes")
        or scene.get("spatial_note")
    )
    if not spatial:
        return None
    text = compact_spatial_value(spatial)
    if not text:
        return None
    return (
        "Spatial continuity: preserve the established map, screen direction, "
        "character path, eyelines, and landmark positions. If the camera turns "
        "or reverses, keep objects on the side where the map says they should be. "
        f"{text}"
    )


def append_generation_contracts(config: dict[str, Any], scene: dict[str, Any], prompt: str) -> str:
    fixed = config["fixed"]
    speakers = scene.get("speaking_characters", [])
    contracts = []
    rhythm_contract = active_take_rhythm_contract(config, scene)
    if rhythm_contract:
        contracts.append(rhythm_contract)
    spatial_contract = spatial_continuity_contract(scene)
    if spatial_contract:
        contracts.append(spatial_contract)
    if speakers:
        contracts.append(
            "Voice contract, repeat exactly for this take: "
            + voice_contract(config, speakers)
        )
        contracts.append(dialogue_timing_contract(config, scene))
        contracts.append(dialogue_boundary_contract())
        clarity_contract = speech_clarity_contract(config, scene)
        if clarity_contract:
            contracts.append(clarity_contract)
        contracts.append(f"Brazilian Portuguese lock: {fixed['brazilian_portuguese_lock']}")
    return "\n\n".join([prompt.strip(), *contracts])


def reference_urls(config: dict[str, Any], scene: dict[str, Any]) -> list[str]:
    refs = config["references"]
    keys = []

    for character in scene.get("visible_characters", []):
        keys.extend(character_profile(config, character).get("reference_keys", []))

    for vehicle in scene.get("visible_vehicles", []):
        keys.extend(config.get("vehicle_assets", {}).get(vehicle, {}).get("reference_keys", []))

    for location in scene.get("visible_locations", []):
        keys.extend(config.get("location_assets", {}).get(location, {}).get("reference_keys", []))

    keys.extend(scene.get("reference_keys", []))
    if scene.get("storyboard_reference_key"):
        keys.append(scene["storyboard_reference_key"])

    deduped_keys = []
    seen = set()
    for key in keys:
        if key not in seen:
            deduped_keys.append(key)
            seen.add(key)

    urls = []
    for key in deduped_keys:
        if key not in refs:
            raise SystemExit(f"Reference key {key!r} is missing in config.references")
        urls.append(refs[key])
    return urls


def reference_audio_urls(config: dict[str, Any], scene: dict[str, Any]) -> list[str]:
    refs = config.get("audio_references", {})
    keys = []
    for speaker in scene.get("speaking_characters", []):
        keys.extend(character_profile(config, speaker).get("reference_audio_keys", []))

    deduped_keys = []
    seen = set()
    for key in keys:
        if key not in seen:
            deduped_keys.append(key)
            seen.add(key)

    urls = []
    for key in deduped_keys:
        if key not in refs:
            raise SystemExit(f"Audio reference key {key!r} is missing in config.audio_references")
        urls.append(refs[key])
    return urls


def reference_contract(config: dict[str, Any], scene: dict[str, Any]) -> str:
    parts = []
    visible_characters = scene.get("visible_characters", [])
    if visible_characters:
        character_bits = []
        for character in visible_characters:
            profile = character_profile(config, character)
            keys = ", ".join(profile.get("reference_keys", [])) or "no visual reference"
            character_bits.append(f"{character} visual reference keys: {keys}")
        parts.append("Visible character references sent: " + "; ".join(character_bits) + ".")

    visible_vehicles = scene.get("visible_vehicles", [])
    if visible_vehicles:
        vehicle_bits = []
        for vehicle in visible_vehicles:
            profile = config.get("vehicle_assets", {}).get(vehicle, {})
            keys = ", ".join(profile.get("reference_keys", [])) or "no visual reference"
            note = profile.get("description", "")
            vehicle_bits.append(f"{vehicle} reference keys: {keys}. {note}".strip())
        parts.append("Visible recurring vehicle/object references sent: " + "; ".join(vehicle_bits) + ".")

    visible_locations = scene.get("visible_locations", [])
    if visible_locations:
        location_bits = []
        for location in visible_locations:
            profile = config.get("location_assets", {}).get(location, {})
            keys = ", ".join(profile.get("reference_keys", [])) or "no visual reference"
            location_bits.append(f"{location} reference keys: {keys}")
        parts.append("Location references sent: " + "; ".join(location_bits) + ".")

    if scene.get("reference_notes"):
        parts.append(scene["reference_notes"])

    if scene.get("storyboard_reference_key"):
        parts.append(
            f"Storyboard/composition reference sent: {scene['storyboard_reference_key']}. "
            "Use it only for scene logic, staging, camera direction, and action continuity. "
            "Do not use it to override character identity, character voices, vehicle identity, or dialogue."
        )

    audio_urls = reference_audio_urls(config, scene)
    if audio_urls:
        parts.append("Voice reference audio files are sent for the speaking characters in this take.")
    else:
        parts.append("No voice audio reference file is available, so preserve voice using the written voice contract exactly.")

    return " ".join(parts)


def build_prompt(config: dict[str, Any], scene: dict[str, Any]) -> str:
    fixed = config["fixed"]
    visible = ", ".join(scene["visible_characters"])
    speaking = ", ".join(scene.get("speaking_characters", [])) or "none"
    vehicles = ", ".join(scene.get("visible_vehicles", [])) or "none"
    locations = ", ".join(scene.get("visible_locations", [])) or "none"
    references = reference_contract(config, scene)
    action_lines = []
    for beat in scene["action_timing"]:
        action_lines.append(f"{beat['time']}: {beat['text']}")

    sections = [
        (
            f"{fixed['format']}, {scene['duration']} seconds, episode "
            f"{config['episode_number']} scene {scene['scene_number']} of "
            f"{len(config['scenes'])}. Low test resolution, {fixed['resolution']}. "
            "No subtitles, no logos, no on-screen text, no existing franchise."
        ),
        (
            f"Take casting: visible recurring characters are {visible}. "
            f"Speaking characters are {speaking}. Visible recurring vehicles/objects are {vehicles}. "
            f"Visible recurring locations are {locations}. {references}"
        ),
        f"Transition mode: {scene['transition']}",
        f"Voice contract, repeat exactly for this take: {voice_contract(config, scene.get('speaking_characters', []))}",
        dialogue_timing_contract(config, scene),
        dialogue_boundary_contract(),
        speech_clarity_contract(config, scene) or "",
        f"Brazilian Portuguese lock: {fixed['brazilian_portuguese_lock']}",
        f"Scene: {scene['scene']}",
        spatial_continuity_contract(scene) or "",
        active_take_rhythm_contract(config, scene) or "",
        "Action timing: " + " ".join(action_lines),
        f"Camera and motion: {scene['camera']}",
        f"Audio: {scene['audio']}",
        f"Constraints: {fixed['negative_constraints']}",
    ]
    return "\n\n".join(section.strip() for section in sections if section.strip())


def build_payload(config: dict[str, Any], scene: dict[str, Any]) -> dict[str, Any]:
    fixed = config["fixed"]
    validate_dialogue_boundaries(scene)
    audio_refs = reference_audio_urls(config, scene)
    explicit_prompt = scene.get("prompt")
    prompt = explicit_prompt or build_prompt(config, scene)
    if explicit_prompt and fixed.get("append_voice_contracts_to_prompt", True):
        prompt = append_generation_contracts(config, scene, prompt)
    first_frame_url = scene.get("first_frame_url")
    reference_image_urls = reference_urls(config, scene)
    payload: dict[str, Any] = {
        "generate_audio": fixed.get("generate_audio", True),
        "skip_moderation": fixed.get("skip_moderation", False),
        "prompt": prompt,
        "resolution": fixed["resolution"],
        "aspect_ratio": fixed["aspect_ratio"],
        "duration": scene["duration"],
        "seed": scene["seed"],
        "return_last_frame": fixed.get("return_last_frame", True),
    }
    if first_frame_url:
        payload["first_frame_url"] = first_frame_url
        if fixed.get("send_reference_images_with_first_frame") or scene.get("send_reference_images_with_first_frame"):
            payload["reference_images"] = reference_image_urls
    else:
        payload["reference_images"] = reference_image_urls
    if audio_refs:
        payload["reference_audios"] = audio_refs
    return payload


def post_segmind(payload: dict[str, Any], output: Path, headers_output: Path, api_key: str, endpoint: str) -> dict[str, Any]:
    output.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=data,
        headers={
            "x-api-key": api_key,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        timeout = int(os.environ.get("SEGMIND_HTTP_TIMEOUT_SECONDS", "900"))
        with urllib.request.urlopen(request, timeout=timeout) as response:
            headers = dict(response.headers)
            headers_output.write_text(json.dumps(headers, indent=2), encoding="utf-8")
            output.write_bytes(response.read())
            return headers
    except urllib.error.HTTPError as error:
        body = error.read()
        output.with_suffix(".error.txt").write_bytes(body)
        raise


def generate_scene(config: dict[str, Any], scene: dict[str, Any], root: Path, api_key: str) -> Path:
    out_dir = resolve_path(root, config["output_dir"])
    payload = build_payload(config, scene)
    payload_path = out_dir / f"{scene['id']}_payload.json"
    output_path = out_dir / scene["output"]
    headers_path = out_dir / f"{scene['id']}_response_headers.json"
    pending_path = out_dir / f"{scene['id']}_generation_pending.json"
    manifest_path = out_dir / f"{scene['id']}_generation_manifest.json"
    force_regenerate = os.environ.get("SEGMIND_FORCE_REGENERATE") == "1"
    write_json(payload_path, payload)
    if output_path.exists() and output_path.stat().st_size > 0 and not force_regenerate:
        print(f"Skipping {scene['id']} -> {output_path} already exists")
        return output_path
    if pending_path.exists() and not force_regenerate:
        raise SystemExit(
            f"{scene['id']} has a pending/unknown Segmind submission at {pending_path}. "
            f"Not resubmitting to avoid duplicate API cost. Check the Segmind dashboard or "
            f"generation history, download the completed video to {output_path}, then remove "
            f"the pending file. To intentionally submit again, set SEGMIND_FORCE_REGENERATE=1."
        )
    write_json(pending_path, {
        "scene_id": scene["id"],
        "output": str(output_path),
        "payload": str(payload_path),
        "payload_sha256": json_hash(payload),
        "endpoint": config.get("endpoint", SEGMIND_ENDPOINT),
        "submitted_at_utc": utc_now(),
        "status": "submitted_or_in_progress",
        "note": "If the local request times out, do not resubmit before checking the Segmind dashboard or generation history.",
    })
    print(f"Generating {scene['id']} -> {output_path}")
    try:
        headers = post_segmind(payload, output_path, headers_path, api_key, config.get("endpoint", SEGMIND_ENDPOINT))
    except urllib.error.HTTPError as error:
        pending_path.unlink(missing_ok=True)
        raise SystemExit(f"Segmind error HTTP {error.code}. See {output_path.with_suffix('.error.txt')}")
    except (TimeoutError, http.client.RemoteDisconnected, urllib.error.URLError) as error:
        write_json(pending_path, {
            "scene_id": scene["id"],
            "output": str(output_path),
            "payload": str(payload_path),
            "payload_sha256": json_hash(payload),
            "endpoint": config.get("endpoint", SEGMIND_ENDPOINT),
            "submitted_at_utc": utc_now(),
            "status": "unknown_remote_status",
            "error_type": type(error).__name__,
            "error": str(error),
            "note": "The request may still have completed remotely. Check Segmind before retrying to avoid duplicate cost.",
        })
        raise
    pending_path.unlink(missing_ok=True)
    write_json(manifest_path, {
        "scene_id": scene["id"],
        "output": str(output_path),
        "payload": str(payload_path),
        "payload_sha256": json_hash(payload),
        "completed_at_utc": utc_now(),
        "request_id": headers.get("X-Request-ID"),
        "generation_time": headers.get("X-Generation-Time"),
        "cost": headers.get("X-Cost"),
        "remaining_credits": headers.get("X-remaining-credits"),
        "last_frame_url": headers.get("X-Last-Frame-URL"),
    })
    return output_path


def ffmpeg_path(config: dict[str, Any], root: Path) -> str:
    return str(resolve_path(root, config["tools"]["ffmpeg"]))


def ffprobe_path(config: dict[str, Any], root: Path) -> str:
    return str(resolve_path(root, config["tools"]["ffprobe"]))


def postprocess_scene(config: dict[str, Any], scene: dict[str, Any], root: Path) -> None:
    out_dir = resolve_path(root, config["output_dir"])
    video = out_dir / scene["output"]
    ffmpeg = ffmpeg_path(config, root)
    run([
        ffmpeg,
        "-v",
        "error",
        "-y",
        "-i",
        str(video),
        "-vf",
        "fps=1/3,scale=160:-1,tile=5x1",
        "-frames:v",
        "1",
        str(out_dir / f"{scene['id']}_contact_sheet.jpg"),
    ])
    run([
        ffmpeg,
        "-v",
        "error",
        "-y",
        "-ss",
        str(scene.get("reference_frame_second", 12)),
        "-i",
        str(video),
        "-frames:v",
        "1",
        str(out_dir / f"{scene['id']}_reference_frame.png"),
    ])
    run([
        ffmpeg,
        "-v",
        "error",
        "-y",
        "-i",
        str(video),
        "-vn",
        "-acodec",
        "libmp3lame",
        "-q:a",
        "4",
        str(out_dir / f"{scene['id']}_audio.mp3"),
    ])


def assemble(config: dict[str, Any], root: Path) -> Path:
    out_dir = resolve_path(root, config["output_dir"])
    output = out_dir / config["final_output"]
    ffmpeg = ffmpeg_path(config, root)
    final = config["final"]
    inputs: list[str] = []
    filter_parts: list[str] = []
    concat_parts: list[str] = []
    for index, scene in enumerate(config["scenes"]):
        inputs.extend(["-i", str(out_dir / scene["output"])])
        filter_parts.append(
            f"[{index}:v]scale={final['width']}:{final['height']}:"
            f"force_original_aspect_ratio=increase,crop={final['width']}:{final['height']},"
            f"setsar=1,fps={final['fps']},setpts=PTS-STARTPTS[v{index}]"
        )
        filter_parts.append(f"[{index}:a]aresample=48000,asetpts=PTS-STARTPTS[a{index}]")
        concat_parts.append(f"[v{index}][a{index}]")
    filter_complex = ";".join(filter_parts)
    filter_complex += ";" + "".join(concat_parts)
    filter_complex += f"concat=n={len(config['scenes'])}:v=1:a=1[v][a];[a]loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[aout]"
    run([
        ffmpeg,
        "-v",
        "error",
        "-y",
        *inputs,
        "-filter_complex",
        filter_complex,
        "-map",
        "[v]",
        "-map",
        "[aout]",
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-crf",
        str(final.get("crf", 20)),
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-ar",
        "48000",
        "-movflags",
        "+faststart",
        str(output),
    ])
    return output


def make_final_contact_sheet(config: dict[str, Any], root: Path) -> None:
    out_dir = resolve_path(root, config["output_dir"])
    ffmpeg = ffmpeg_path(config, root)
    run([
        ffmpeg,
        "-v",
        "error",
        "-y",
        "-i",
        str(out_dir / config["final_output"]),
        "-vf",
        "fps=1/5,scale=160:-1,tile=4x3",
        "-frames:v",
        "1",
        str(out_dir / config["final_contact_sheet"]),
    ])


def write_srt(path: Path, lines: list[dict[str, Any]], language_key: str) -> None:
    def fmt(seconds: float) -> str:
        millis = int(round(seconds * 1000))
        h = millis // 3_600_000
        millis %= 3_600_000
        m = millis // 60_000
        millis %= 60_000
        s = millis // 1000
        ms = millis % 1000
        return f"{h:02}:{m:02}:{s:02},{ms:03}"

    chunks = []
    for index, line in enumerate(lines, start=1):
        chunks.append(
            f"{index}\n{fmt(line['start'])} --> {fmt(line['end'])}\n{line[language_key]}\n"
        )
    path.write_text("\n".join(chunks), encoding="utf-8")


def write_subtitles_and_timeline(config: dict[str, Any], root: Path) -> None:
    out_dir = resolve_path(root, config["output_dir"])
    pt_lines = []
    en_lines = []
    timeline_scenes = []
    scene_start = 0.0
    for scene in config["scenes"]:
        validate_dialogue_boundaries(scene)
        scene_seconds = float(scene.get("duration", 15))
        scene_dialogue = []
        for dialogue in scene.get("dialogue", []):
            item = {
                "start": scene_start + dialogue["start"],
                "end": scene_start + dialogue["end"],
                "speaker": dialogue["speaker"],
                "pt_BR": dialogue["pt_BR"],
                "en_US": dialogue["en_US"],
            }
            pt_lines.append(item)
            en_lines.append(item)
            scene_dialogue.append(item)
        timeline_scenes.append({
            "scene": scene["scene_number"],
            "id": scene["id"],
            "start": round(scene_start, 1),
            "end": round(scene_start + scene_seconds, 1),
            "visible_characters": scene["visible_characters"],
            "reference_keys": scene.get("reference_keys", []),
            "dialogue": scene_dialogue,
        })
        scene_start += scene_seconds
    write_srt(out_dir / config["pt_br_srt"], pt_lines, "pt_BR")
    write_srt(out_dir / config["en_us_srt"], en_lines, "en_US")
    write_json(out_dir / config["timeline_json"], {
        "series": config["series"],
        "episode": config["episode_number"],
        "duration_seconds": round(scene_start, 1),
        "dialogue_timings_are_approximate": True,
        "generation_fps_note": "Segmind Seedance 2.0 endpoint does not expose an fps parameter; fps is only controlled during final assembly.",
        "scenes": timeline_scenes,
    })


def upload_catbox(path: Path) -> str:
    result = subprocess.run(
        [
            "curl.exe",
            "--ssl-no-revoke",
            "-s",
            "-S",
            "-F",
            "reqtype=fileupload",
            "-F",
            f"fileToUpload=@{path}",
            "https://catbox.moe/user/api.php",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def upload_outputs(config: dict[str, Any], root: Path) -> dict[str, str]:
    out_dir = resolve_path(root, config["output_dir"])
    files = {
        "video": out_dir / config["final_output"],
        "contact_sheet": out_dir / config["final_contact_sheet"],
        "pt_br_srt": out_dir / config["pt_br_srt"],
        "en_us_srt": out_dir / config["en_us_srt"],
        "timeline": out_dir / config["timeline_json"],
    }
    urls = {name: upload_catbox(path) for name, path in files.items() if path.exists()}
    write_json(out_dir / config["result_json"], {
        "series": config["series"],
        "episode": config["episode_number"],
        "local_files": {name: str(path) for name, path in files.items()},
        "remote_urls": urls,
    })
    return urls


def vertix_api_config(config: dict[str, Any], args: argparse.Namespace) -> dict[str, Any] | None:
    configured = config.get("vertix_api") or config.get("production_api") or {}
    enabled = bool(args.sync_api or configured.get("enabled") or os.environ.get("VERTIX_SYNC_API") == "1")
    if not enabled:
        return None

    base_url = (
        args.api_url
        or configured.get("base_url")
        or os.environ.get("VERTIX_API_URL")
        or os.environ.get("VERTIX_API_BASE_URL")
        or "https://vertix-api.snapdark.com"
    ).rstrip("/")
    token_env = configured.get("token_env", "VERTIX_API_TOKEN")
    token = args.api_token or configured.get("token") or os.environ.get(token_env)
    series_id = args.series_id or configured.get("series_id") or os.environ.get("VERTIX_SERIES_ID")

    if not token:
        raise SystemExit(f"Missing Vertix API token. Set ${token_env} or pass --api-token.")
    if not series_id:
        raise SystemExit("Missing Vertix series id. Set VERTIX_SERIES_ID, config.vertix_api.series_id, or pass --series-id.")

    try:
        series_id_int = int(series_id)
    except (TypeError, ValueError) as error:
        raise SystemExit(f"Invalid Vertix series id: {series_id!r}") from error

    return {
        "base_url": base_url,
        "token": token,
        "series_id": series_id_int,
    }


def api_json_request(method: str, url: str, token: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            response_body = response.read().decode("utf-8")
            return json.loads(response_body) if response_body else {}
    except urllib.error.HTTPError as error:
        response_body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Vertix API error HTTP {error.code}: {response_body}") from error


def put_file(upload_url: str, path: Path, content_type: str) -> None:
    request = urllib.request.Request(
        upload_url,
        data=path.read_bytes(),
        headers={"Content-Type": content_type},
        method="PUT",
    )
    with urllib.request.urlopen(request, timeout=900):
        return


def content_type_for(path: Path) -> str:
    guessed, _ = mimetypes.guess_type(str(path))
    if guessed:
        return guessed
    if path.suffix.lower() == ".srt":
        return "application/x-subrip"
    return "application/octet-stream"


def asset_category(path: Path) -> str:
    suffix = path.suffix.lower()
    name = path.name.lower()
    if suffix in {".mp4", ".webm", ".mov"}:
        return "video"
    if suffix in {".png", ".jpg", ".jpeg", ".webp", ".gif"}:
        if "contact" in name:
            return "contact_sheet"
        if "storyboard" in name:
            return "storyboard"
        if "frame" in name:
            return "frame"
        return "image"
    if suffix in {".mp3", ".wav", ".m4a", ".aac"}:
        return "audio"
    if suffix in {".json"}:
        return "metadata"
    if suffix in {".srt", ".vtt"}:
        return "subtitle"
    return "pipeline"


def collect_pipeline_files(config: dict[str, Any], root: Path) -> dict[str, Path]:
    out_dir = resolve_path(root, config["output_dir"])
    files: dict[str, Path] = {
        "config": resolve_path(root, str(config.get("_config_path", ""))) if config.get("_config_path") else Path(),
        "final_video": out_dir / config["final_output"],
        "final_contact_sheet": out_dir / config["final_contact_sheet"],
        "pt_br_srt": out_dir / config["pt_br_srt"],
        "en_us_srt": out_dir / config["en_us_srt"],
        "timeline": out_dir / config["timeline_json"],
        "result": out_dir / config["result_json"],
    }
    for scene in config.get("scenes", []):
        scene_id = scene["id"]
        files[f"{scene_id}_video"] = out_dir / scene["output"]
        files[f"{scene_id}_payload"] = out_dir / f"{scene_id}_payload.json"
        files[f"{scene_id}_headers"] = out_dir / f"{scene_id}_response_headers.json"
        files[f"{scene_id}_manifest"] = out_dir / f"{scene_id}_generation_manifest.json"
        files[f"{scene_id}_contact_sheet"] = out_dir / f"{scene_id}_contact_sheet.jpg"
        files[f"{scene_id}_reference_frame"] = out_dir / f"{scene_id}_reference_frame.png"
        files[f"{scene_id}_audio"] = out_dir / f"{scene_id}_audio.mp3"

    return {label: path for label, path in files.items() if str(path) and path.exists() and path.is_file()}


def upload_file_to_vertix(
    api: dict[str, Any],
    path: Path,
    label: str,
    cache: dict[str, Any],
) -> dict[str, Any]:
    digest = file_hash(path)
    cached = cache.get(label)
    if cached and cached.get("sha256") == digest and cached.get("publicUrl") and cached.get("storageKey"):
        return cached

    content_type = content_type_for(path)
    category = asset_category(path)
    url = f"{api['base_url']}/admin/series/{api['series_id']}/production/upload-url"
    upload_response = api_json_request(
        "POST",
        url,
        api["token"],
        {
            "filename": path.name,
            "category": category,
            "contentType": content_type,
        },
    )
    data = upload_response.get("data") or {}
    if not data.get("uploadUrl"):
        raise SystemExit(f"Vertix API did not return uploadUrl for {path}")

    put_file(data["uploadUrl"], path, content_type)
    uploaded = {
        "label": label,
        "path": str(path),
        "filename": path.name,
        "category": category,
        "contentType": content_type,
        "sizeBytes": path.stat().st_size,
        "sha256": digest,
        "storageKey": data["key"],
        "publicUrl": data["publicUrl"],
        "uploadedAt": utc_now(),
    }
    cache[label] = uploaded
    return uploaded


def scene_story_points(config: dict[str, Any]) -> list[dict[str, Any]]:
    points: list[dict[str, Any]] = []
    for index, scene in enumerate(config.get("scenes", [])):
        scene_number = scene.get("scene_number")
        points.append({
            "pointType": "SCENE_CARD",
            "title": f"{scene.get('id', index + 1)} - {scene.get('scene', 'Cena')}",
            "body": scene,
            "episodeNumber": config.get("episode_number"),
            "sceneNumber": scene_number,
            "segment": scene.get("id"),
            "orderIndex": len(points),
        })
        prompt = scene.get("prompt")
        if prompt:
            points.append({
                "pointType": "SEEDANCE_PROMPT",
                "title": scene.get("id", f"prompt_{index + 1}"),
                "body": prompt,
                "episodeNumber": config.get("episode_number"),
                "sceneNumber": scene_number,
                "segment": scene.get("id"),
                "orderIndex": len(points),
            })
    return points


def production_payload(config: dict[str, Any], uploaded_assets: list[dict[str, Any]], sync_note: str) -> dict[str, Any]:
    references = []
    for asset in uploaded_assets:
        references.append({
            "label": asset["label"],
            "category": asset["category"],
            "publicUrl": asset["publicUrl"],
            "storageKey": asset["storageKey"],
            "contentType": asset["contentType"],
            "metadata": {
                "filename": asset["filename"],
                "localPath": asset["path"],
                "sha256": asset["sha256"],
                "sizeBytes": asset["sizeBytes"],
                "uploadedAt": asset["uploadedAt"],
            },
        })

    return {
        "source": "seedance-series-pipeline",
        "replaceExisting": True,
        "pipelineData": {
            "source": "seedance-series-pipeline",
            "seriesBible": config.get("series_bible") or config.get("seriesBible") or {
                "title": config.get("series"),
                "episode": config.get("episode_number"),
                "fixed": config.get("fixed", {}),
            },
            "characterBible": config.get("character_assets") or config.get("characters"),
            "locationBible": config.get("location_assets") or config.get("locations"),
            "objectBible": config.get("vehicle_assets") or config.get("objects") or config.get("props"),
            "audioBible": {
                "voiceProfiles": config.get("voice_profiles", {}),
                "audioReferences": config.get("audio_references", {}),
                "finalStrategy": config.get("audio_strategy"),
            },
            "seasonArc": config.get("season_arc"),
            "episodeMap": config.get("episode_map"),
            "sceneCards": config.get("scenes", []),
            "generationPlan": config.get("scenes", []),
            "storyboardPlan": config.get("storyboard_plan"),
            "seedanceNotes": {
                "syncNote": sync_note,
                "endpoint": config.get("endpoint", SEGMIND_ENDPOINT),
                "outputDir": config.get("output_dir"),
                "syncedAt": utc_now(),
            },
            "storyPoints": scene_story_points(config),
            "referenceAssets": references,
            "prompts": {
                scene["id"]: scene["prompt"]
                for scene in config.get("scenes", [])
                if scene.get("prompt")
            },
        },
    }


def sync_vertix_production(config: dict[str, Any], root: Path, api: dict[str, Any], note: str) -> dict[str, Any]:
    out_dir = resolve_path(root, config["output_dir"])
    cache_path = out_dir / config.get("r2_uploads_json", "vertix_r2_uploads.json")
    cache = load_json(cache_path) if cache_path.exists() else {}
    files = collect_pipeline_files(config, root)
    uploaded_assets = [
        upload_file_to_vertix(api, path, label, cache)
        for label, path in sorted(files.items())
    ]
    write_json(cache_path, cache)
    response = api_json_request(
        "POST",
        f"{api['base_url']}/admin/series/{api['series_id']}/production",
        api["token"],
        production_payload(config, uploaded_assets, note),
    )
    write_json(out_dir / config.get("vertix_sync_json", "vertix_production_sync.json"), {
        "syncedAt": utc_now(),
        "seriesId": api["series_id"],
        "baseUrl": api["base_url"],
        "filesSynced": len(uploaded_assets),
        "apiResponse": response,
    })
    print(f"Synced {len(uploaded_assets)} files to Vertix production series {api['series_id']}")
    return response


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Seedance short-series scenes.")
    parser.add_argument("command", choices=["payload", "scene", "scene-post", "assemble", "subtitles", "upload", "sync-api", "run-scene", "run-all"])
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--scene")
    parser.add_argument("--api-key")
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--sync-api", action="store_true", help="Sync generated files and production data to Vertix API/R2.")
    parser.add_argument("--api-url", help="Vertix API base URL. Defaults to VERTIX_API_URL or production.")
    parser.add_argument("--api-token", help="Admin bearer token for Vertix API. Defaults to VERTIX_API_TOKEN.")
    parser.add_argument("--series-id", type=int, help="Vertix series id. Defaults to VERTIX_SERIES_ID or config.vertix_api.series_id.")
    args = parser.parse_args()

    root = Path.cwd()
    config = load_json(args.config)
    config["_config_path"] = str(args.config)
    vertix_api = vertix_api_config(config, args)

    if args.command in {"payload", "scene", "scene-post", "run-scene"} and not args.scene:
        raise SystemExit("--scene is required for this command")

    if args.command == "payload":
        scene = scene_by_id(config, args.scene)
        out_dir = resolve_path(root, config["output_dir"])
        write_json(out_dir / f"{scene['id']}_payload.json", build_payload(config, scene))
        return 0

    if args.command == "scene":
        api_key = get_api_key(config, args.api_key)
        generate_scene(config, scene_by_id(config, args.scene), root, api_key)
        return 0

    if args.command == "scene-post":
        postprocess_scene(config, scene_by_id(config, args.scene), root)
        return 0

    if args.command == "run-scene":
        api_key = get_api_key(config, args.api_key)
        scene = scene_by_id(config, args.scene)
        generate_scene(config, scene, root, api_key)
        postprocess_scene(config, scene, root)
        if vertix_api:
            sync_vertix_production(config, root, vertix_api, f"scene {scene['id']} generated")
        return 0

    if args.command == "assemble":
        assemble(config, root)
        make_final_contact_sheet(config, root)
        return 0

    if args.command == "subtitles":
        write_subtitles_and_timeline(config, root)
        return 0

    if args.command == "upload":
        urls = upload_outputs(config, root)
        print(json.dumps(urls, indent=2))
        return 0

    if args.command == "sync-api":
        if not vertix_api:
            raise SystemExit("Enable API sync with --sync-api, VERTIX_SYNC_API=1, or config.vertix_api.enabled=true.")
        print(json.dumps(sync_vertix_production(config, root, vertix_api, "manual sync"), indent=2))
        return 0

    if args.command == "run-all":
        api_key = get_api_key(config, args.api_key)
        for scene in config["scenes"]:
            generate_scene(config, scene, root, api_key)
            postprocess_scene(config, scene, root)
            if vertix_api:
                sync_vertix_production(config, root, vertix_api, f"scene {scene['id']} generated")
        assemble(config, root)
        make_final_contact_sheet(config, root)
        write_subtitles_and_timeline(config, root)
        if args.upload:
            print(json.dumps(upload_outputs(config, root), indent=2))
        if vertix_api:
            print(json.dumps(sync_vertix_production(config, root, vertix_api, "run-all complete"), indent=2))
        return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
