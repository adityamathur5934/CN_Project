#!/usr/bin/env python3
"""
Backend B — CN Project (Mac 4)
Listens on 0.0.0.0:3002, serves GET / and GET /api/status.
No third-party dependencies — stdlib only.
"""

import json
import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

PORT = 3002
HOST = "0.0.0.0"

# Fixed ETag for /api/status (body is constant)
STATUS_BODY = json.dumps({"backend": "B", "status": "ok"}).encode("utf-8")
STATUS_ETAG = '"backend-b-v1"'


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class BackendBHandler(BaseHTTPRequestHandler):
    server_version = "BackendB/1.0"

    # ------------------------------------------------------------------ #
    #  Custom clean log format                                           #
    # ------------------------------------------------------------------ #
    def log_message(self, fmt, *args):  # noqa: N802
        print(f"[Backend B] {self.address_string()} - {fmt % args}", flush=True)

    # ------------------------------------------------------------------ #
    #  Shared helper: send standard headers on every response.           #
    # ------------------------------------------------------------------ #
    def _send_common_headers(self, status: int):
        self.send_response(status)
        self.send_header("X-Backend", "B")
        self.send_header("Cache-Control", "max-age=60")

    # ------------------------------------------------------------------ #
    #  GET /                                                             #
    # ------------------------------------------------------------------ #
    def _handle_root(self):
        body = b"Backend B is running\n"
        self._send_common_headers(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # ------------------------------------------------------------------ #
    #  GET /api/status                                                   #
    # ------------------------------------------------------------------ #
    def _handle_status(self):
        # Conditional request support (ETag / If-None-Match)
        if_none_match = self.headers.get("If-None-Match", "")
        if if_none_match and if_none_match == STATUS_ETAG:
            self._send_common_headers(304)
            self.send_header("ETag", STATUS_ETAG)
            self.end_headers()
            return

        self._send_common_headers(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(STATUS_BODY)))
        self.send_header("ETag", STATUS_ETAG)
        self.end_headers()
        self.wfile.write(STATUS_BODY)

    # ------------------------------------------------------------------ #
    #  Router                                                            #
    # ------------------------------------------------------------------ #
    def do_GET(self):  # noqa: N802
        if self.path == "/":
            self._handle_root()
        elif self.path == "/api/status":
            self._handle_status()
        else:
            body = json.dumps({"error": "Not Found", "backend": "B"}).encode("utf-8")
            self._send_common_headers(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)


def get_lan_ip() -> str:
    """Return the primary non-loopback IPv4 address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.7.0.1", 80))  # doesn't actually send traffic
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "10.7.2.96"


def main():
    lan_ip = get_lan_ip()
    try:
        server = ThreadedHTTPServer((HOST, PORT), BackendBHandler)
    except OSError as exc:
        print(
            f"[Backend B] ERROR: Cannot bind to port {PORT} — {exc}\n"
            f"            Is another process already using port {PORT}?\n"
            f"            Run:  lsof -ti :{PORT} | xargs kill -9",
            file=sys.stderr,
        )
        sys.exit(1)

    print("=================================================", flush=True)
    print(f"[Backend B] Listening on {HOST}:{PORT} (LAN IP: {lan_ip}:{PORT})", flush=True)
    print(f"[Backend B] Endpoints:  GET /   GET /api/status", flush=True)
    print(f"[Backend B] Headers:    X-Backend: B, Cache-Control: max-age=60, ETag: {STATUS_ETAG}", flush=True)
    print(f"[Backend B] Press Ctrl-C to stop.", flush=True)
    print("=================================================", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Backend B] Shutting down.", flush=True)
        server.server_close()
        sys.exit(0)


if __name__ == "__main__":
    main()
