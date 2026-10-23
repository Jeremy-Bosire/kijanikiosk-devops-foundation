#!/usr/bin/env python3
"""KijaniKiosk placeholder service (stdlib only).

Stands in for the real api / payments / logs applications so the systemd
hardening can be proven against a process that actually runs. At runtime it:
  * reads its own config file (proves the service user can read it under
    ProtectSystem=strict - Integration Challenge D),
  * appends to <service>.log in /opt/kijanikiosk/shared/logs (proves the
    ReadWritePaths exception works; rotated by logrotate),
  * serves GET /health as JSON.
"""
import json
import logging
import os
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SERVICE = os.environ.get("KK_SERVICE", "kk-unknown")
BIND = os.environ.get("KK_BIND", "127.0.0.1")
PORT = int(os.environ.get("KK_PORT", "8080"))
CONFIG_FILE = os.environ.get("KK_CONFIG_FILE", "")
LOG_DIR = os.environ.get("KK_LOG_DIR", "")


def config_readable() -> bool:
    try:
        with open(CONFIG_FILE, encoding="utf-8") as fh:
            fh.read()
        return True
    except OSError as exc:
        logging.error("cannot read config %s: %s", CONFIG_FILE, exc)
        return False


def log_writable() -> bool:
    try:
        path = os.path.join(LOG_DIR, f"{SERVICE}.log")
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(f"{datetime.now(timezone.utc).isoformat()} health-check\n")
        return True
    except OSError as exc:
        logging.error("cannot write log dir %s: %s", LOG_DIR, exc)
        return False


access_log = logging.getLogger("access")


class Handler(BaseHTTPRequestHandler):
    server_version = "kijanikiosk/1.0"

    def do_GET(self):  # noqa: N802 (stdlib naming)
        if self.path != "/health":
            self.send_error(404)
            return
        body = json.dumps({
            "service": SERVICE,
            "status": "ok",
            "environment": os.environ.get("KK_ENVIRONMENT", ""),
            "config_readable": config_readable(),
            "log_writable": log_writable(),
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        access_log.info("%s %s", self.client_address[0], fmt % args)


def main() -> int:
    logging.basicConfig(stream=sys.stderr, level=logging.INFO,
                        format=f"{SERVICE} %(levelname)s %(message)s")
    if LOG_DIR:
        fh = logging.FileHandler(os.path.join(LOG_DIR, f"{SERVICE}.log"))
        fh.setFormatter(logging.Formatter("%(asctime)s %(message)s"))
        access_log.addHandler(fh)
    if not config_readable():
        return 1
    log_writable()
    logging.info("listening on %s:%d", BIND, PORT)
    ThreadingHTTPServer((BIND, PORT), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
