#!/usr/bin/env python3
"""Cliente restrito para jobs de imagens de referencia do Vertix."""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


def required_value(argument: str | None, env_name: str) -> str:
    value = (argument or os.environ.get(env_name) or "").strip()
    if not value:
        raise SystemExit(f"Entrada ausente: {env_name}")
    return value


def context(args: argparse.Namespace) -> tuple[str, int, str]:
    api_base = required_value(args.api_base, "VERTIX_REFERENCE_API_BASE").rstrip("/")
    raw_job_id = required_value(args.job_id, "VERTIX_REFERENCE_JOB_ID")
    token = required_value(args.token, "VERTIX_REFERENCE_JOB_TOKEN")
    try:
        job_id = int(raw_job_id)
    except ValueError as error:
        raise SystemExit("VERTIX_REFERENCE_JOB_ID invalido") from error
    if job_id <= 0:
        raise SystemExit("VERTIX_REFERENCE_JOB_ID invalido")
    return api_base, job_id, token


def request_json(
    method: str,
    url: str,
    token: str,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    body = None
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "Vertix-Codex-Reference-Images/1.0",
    }
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=180) as response:
            decoded = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8", errors="replace")
        try:
            message = json.loads(raw).get("message", raw)
        except json.JSONDecodeError:
            message = raw
        raise SystemExit(f"Vertix API {error.code}: {message}") from error
    except urllib.error.URLError as error:
        raise SystemExit(f"Falha de rede ao acessar a Vertix API: {error.reason}") from error
    if not isinstance(decoded, dict) or decoded.get("success") is not True:
        raise SystemExit(str(decoded.get("message", "Resposta invalida da Vertix API")))
    return decoded


def endpoint(api_base: str, job_id: int, suffix: str = "") -> str:
    return f"{api_base}/codex/reference-image-jobs/{job_id}{suffix}"


def emit(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def manifest(args: argparse.Namespace) -> None:
    api_base, job_id, token = context(args)
    emit(request_json("GET", endpoint(api_base, job_id), token)["data"])


def item_status(args: argparse.Namespace) -> None:
    api_base, job_id, token = context(args)
    reference_id = urllib.parse.quote(args.reference_id, safe="")
    payload: dict[str, Any] = {"status": args.status}
    if args.error:
        payload["error"] = args.error[:4000]
    result = request_json(
        "POST",
        endpoint(api_base, job_id, f"/items/{reference_id}/status"),
        token,
        payload,
    )
    emit(result["data"])


def upload(args: argparse.Namespace) -> None:
    api_base, job_id, token = context(args)
    file_path = Path(args.file).expanduser().resolve()
    if not file_path.is_file():
        raise SystemExit(f"Imagem nao encontrada: {file_path}")
    if file_path.stat().st_size <= 0:
        raise SystemExit(f"Imagem vazia: {file_path}")
    content_type = mimetypes.guess_type(file_path.name)[0] or "image/png"
    if not content_type.startswith("image/"):
        raise SystemExit(f"Arquivo nao e uma imagem reconhecida: {file_path}")
    encoded = base64.b64encode(file_path.read_bytes()).decode("ascii")
    reference_id = urllib.parse.quote(args.reference_id, safe="")
    result = request_json(
        "POST",
        endpoint(api_base, job_id, f"/items/{reference_id}/upload"),
        token,
        {
            "base64": encoded,
            "filename": file_path.name,
            "contentType": content_type,
        },
    )
    emit(result["data"])


def complete(args: argparse.Namespace) -> None:
    api_base, job_id, token = context(args)
    result = request_json(
        "POST",
        endpoint(api_base, job_id, "/complete"),
        token,
        {},
    )
    emit(result["data"])


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    root.add_argument("--api-base")
    root.add_argument("--job-id")
    root.add_argument("--token")
    commands = root.add_subparsers(dest="command", required=True)

    manifest_parser = commands.add_parser("manifest")
    manifest_parser.set_defaults(func=manifest)

    status_parser = commands.add_parser("status")
    status_parser.add_argument("--reference-id", required=True)
    status_parser.add_argument(
        "--status",
        required=True,
        choices=["GENERATING", "UPLOADING", "FAILED"],
    )
    status_parser.add_argument("--error")
    status_parser.set_defaults(func=item_status)

    upload_parser = commands.add_parser("upload")
    upload_parser.add_argument("--reference-id", required=True)
    upload_parser.add_argument("--file", required=True)
    upload_parser.set_defaults(func=upload)

    complete_parser = commands.add_parser("complete")
    complete_parser.set_defaults(func=complete)
    return root


def main() -> int:
    args = parser().parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
