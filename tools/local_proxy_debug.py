from __future__ import annotations

import select
import socket
import threading

LOG = r"C:\Users\Fabiano\AppData\Local\Temp\opencode\proxy-debug.log"


def log(msg: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(msg + "\n")


def tunnel(a: socket.socket, b: socket.socket) -> None:
    sockets = [a, b]
    try:
        while True:
            r, _, _ = select.select(sockets, [], [], 120)
            if not r:
                return
            for s in r:
                data = s.recv(65536)
                if not data:
                    return
                (b if s is a else a).sendall(data)
    except OSError as e:
        log(f"tunnel exc: {e}")
    finally:
        for s in (a, b):
            try:
                s.close()
            except OSError:
                pass


def handle(client: socket.socket) -> None:
    try:
        req = b""
        while b"\r\n\r\n" not in req:
            chunk = client.recv(4096)
            if not chunk:
                return
            req += chunk
        log(f"RECEIVED: {req[:120]!r}")
        head = req.split(b"\r\n", 1)[0]
        parts = head.split(b" ")
        log(f"PARTS: {parts}")
        if len(parts) < 2:
            client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            return
        method = parts[0].upper()
        target = parts[1]

        if method == b"CONNECT":
            host, _, port = target.partition(b":")
            port = int(port or 443)
            log(f"CONNECT to {host}:{port}")
            try:
                remote = socket.create_connection((host.decode("ascii"), port), timeout=30)
            except OSError as e:
                log(f"CONNECT FAIL: {e}")
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                return
            client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            log("200 sent")
            tunnel(client, remote)
            return

        if target.startswith(b"http://"):
            rest = target[len(b"http://"):]
            host, _, path = rest.partition(b"/")
            host, _, port = host.partition(b":")
            port = int(port or 80)
            path = b"/" + path
            log(f"HTTP GET to {host}:{port} {path}")
            try:
                remote = socket.create_connection((host.decode("ascii"), port), timeout=30)
            except OSError as e:
                log(f"HTTP FAIL: {e}")
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                return
            req = req.replace(target, path)
            remote.sendall(req)
            tunnel(client, remote)
            return

        log(f"UNHANDLED: {method} {target}")
        client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
    except Exception as e:  # noqa: BLE001
        log(f"EXC: {e!r}")
    finally:
        try:
            client.close()
        except OSError:
            pass


def main() -> None:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 8899))
    srv.listen(128)
    log("listening on 8899")
    try:
        while True:
            conn, _ = srv.accept()
            threading.Thread(target=handle, args=(conn,), daemon=True).start()
    except KeyboardInterrupt:
        pass
    finally:
        srv.close()


if __name__ == "__main__":
    main()