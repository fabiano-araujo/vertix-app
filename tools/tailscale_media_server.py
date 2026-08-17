from __future__ import annotations

import argparse
import mimetypes
import os
import shutil
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class RangeRequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send_head(self):  # noqa: N802 - inherited API name
        path = Path(self.translate_path(self.path))
        if path.is_dir():
            self._range_length = None
            return super().send_head()

        try:
            size = path.stat().st_size
            file_handle = path.open("rb")
        except OSError:
            self.send_error(404, "File not found")
            return None

        content_type = self.guess_type(str(path)) or "application/octet-stream"
        start = 0
        end = size - 1
        status = 200
        range_header = self.headers.get("Range")

        if range_header and range_header.startswith("bytes="):
            # Serve one byte range, which is what mobile MP4 players request.
            spec = range_header[6:].split(",", 1)[0].strip()
            try:
                first, last = spec.split("-", 1)
                if first:
                    start = int(first)
                    if last:
                        end = min(int(last), size - 1)
                else:
                    suffix = int(last)
                    start = max(size - suffix, 0)
                if start < 0 or start >= size or end < start:
                    raise ValueError
                status = 206
            except (ValueError, TypeError):
                file_handle.close()
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{size}")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return None

        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Last-Modified", self.date_time_string(path.stat().st_mtime))
        if status == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        file_handle.seek(start)
        self._range_length = length
        return file_handle

    def do_GET(self):  # noqa: N802 - inherited API name
        file_handle = self.send_head()
        if file_handle is None:
            return
        try:
            remaining = self._range_length
            if remaining is None:
                shutil.copyfileobj(file_handle, self.wfile)
                return
            while remaining:
                chunk = file_handle.read(min(1024 * 1024, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)
        finally:
            file_handle.close()

    def do_HEAD(self):  # noqa: N802 - inherited API name
        file_handle = self.send_head()
        if file_handle is not None:
            file_handle.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--bind", default="0.0.0.0")
    args = parser.parse_args()
    os.chdir(args.root)
    server = ThreadingHTTPServer((args.bind, args.port), RangeRequestHandler)
    print(f"Serving {args.root} on {args.bind}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
