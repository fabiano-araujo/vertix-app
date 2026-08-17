from __future__ import annotations

import select
import socket
import sys
import threading


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
                other = b if s is a else a
                other.sendall(data)
    except OSError:
        pass
    finally:
        try:
            a.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            b.shutdown(socket.SHUT_RDWR)
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
        head = req.split(b"\r\n", 1)[0]
        parts = head.split(b" ")
        if len(parts) < 2:
            client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            return
        method = parts[0].upper()
        target = parts[1]

        if method == b"CONNECT":
            host, _, port = target.partition(b":")
            port = int(port or 443)
            try:
                remote = socket.create_connection((host.decode("ascii"), port), timeout=30)
            except OSError:
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                return
            client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            tunnel(client, remote)
            remote.close()
            return

        if target.startswith(b"http://"):
            rest = target[len(b"http://"):]
            host, _, path = rest.partition(b"/")
            host, _, port = host.partition(b":")
            port = int(port or 80)
            path = b"/" + path
            try:
                remote = socket.create_connection((host.decode("ascii"), port), timeout=30)
            except OSError:
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                return
            req = req.replace(target, path)
            remote.sendall(req)
            tunnel(client, remote)
            remote.close()
            return

        client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
    except (OSError, ValueError):
        pass
    finally:
        try:
            client.close()
        except OSError:
            pass


def main() -> None:
    listen_host = "127.0.0.1"
    listen_port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((listen_host, listen_port))
    srv.listen(128)
    print(f"proxy listening on {listen_host}:{listen_port}", flush=True)
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