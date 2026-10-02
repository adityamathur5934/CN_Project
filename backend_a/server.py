#!/usr/bin/env python3
"""
Backend A — CN Project (Mac 3)
Listens on 0.0.0.0:3001, serves GET / and GET /api/status.
No third-party dependencies — stdlib only.
"""

import hashlib
import json
import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 3001
HOST = "0.0.0.0"

# STATUS_BODY never changes — ETag is a hash of the body so it is:
#   1. Identical across Backend A and Backend B (same content → same ETag)
#   2. Self-updating if the body ever changes (no manual constant to forget)
STATUS_BODY = json.dumps({"backend": "A", "status": "ok"}).encode()
STATUS_ETAG = '"' + hashlib.md5(STATUS_BODY).hexdigest()[:16] + '"'


class BackendAHandler(BaseHTTPRequestHandler):

    # ------------------------------------------------------------------ #
    #  Silence the default access log line — we print our own below.      #
    # ------------------------------------------------------------------ #
    def log_message(self, fmt, *args):  # noqa: N802
        print(f"[Backend A] {self.address_string()} - {fmt % args}",
              flush=True)

    # ------------------------------------------------------------------ #
    #  Shared helper: send standard headers on every response.            #
    # ------------------------------------------------------------------ #
    def _send_common_headers(self, status: int):
        self.send_response(status)
        self.send_header("X-Backend", "A")
        # Only cache successful responses — errors (4xx/5xx) must not be
        # cached, otherwise clients won't see new routes or fixed errors.
        if status < 400:
            self.send_header("Cache-Control", "max-age=60")
        else:
            self.send_header("Cache-Control", "no-store")

    # ------------------------------------------------------------------ #
    #  GET / HEAD /                                                        #
    # ------------------------------------------------------------------ #
    def _handle_root(self, send_body: bool = True):
        body = b"Backend A is running\n"
        self._send_common_headers(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if send_body:
            self.wfile.write(body)

    # ------------------------------------------------------------------ #
    #  GET / HEAD /api/status                                              #
    # ------------------------------------------------------------------ #
    def _handle_status(self, send_body: bool = True):
        # Conditional request support (ETag / If-None-Match)
        if_none_match = self.headers.get("If-None-Match", "")
        if if_none_match and if_none_match == STATUS_ETAG:
            self._send_common_headers(304)
            self.send_header("ETag", STATUS_ETAG)
            self.end_headers()
            return

        self._send_common_headers(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(STATUS_BODY)))
        self.send_header("ETag", STATUS_ETAG)
        self.end_headers()
        if send_body:
            self.wfile.write(STATUS_BODY)

    # ------------------------------------------------------------------ #
    #  Router                                                              #
    # ------------------------------------------------------------------ #
    def _dispatch(self, send_body: bool):
        if self.path == "/":
            self._handle_root(send_body)
        elif self.path == "/api/status":
            self._handle_status(send_body)
        else:
            body = b"Not Found\n"
            self._send_common_headers(404)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if send_body:
                self.wfile.write(body)

    def do_GET(self):   # noqa: N802
        self._dispatch(send_body=True)

    def do_HEAD(self):  # noqa: N802
        """HEAD — same headers as GET, no body (required by RFC 7231)."""
        self._dispatch(send_body=False)


def get_lan_ip() -> str:
    """Return the primary non-loopback IPv4 address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.7.0.1", 80))   # doesn't actually send traffic
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return HOST


def main():
    lan_ip = get_lan_ip()
    try:
        server = HTTPServer((HOST, PORT), BackendAHandler)
    except OSError as exc:
        print(
            f"[Backend A] ERROR: Cannot bind to port {PORT} — {exc}\n"
            f"            Is another process already using port {PORT}?\n"
            f"            Run:  lsof -i :{PORT}",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"[Backend A] Listening on {HOST}:{PORT}  (LAN IP: {lan_ip}:{PORT})",
          flush=True)
    print(f"[Backend A] Endpoints:  GET /   GET /api/status", flush=True)
    print(f"[Backend A] Press Ctrl-C to stop.", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Backend A] Shutting down.", flush=True)
        server.server_close()
        sys.exit(0)


if __name__ == "__main__":
    main()
