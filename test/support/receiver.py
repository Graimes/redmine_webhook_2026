from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock


events: list[dict[str, object]] = []
events_lock = Lock()


class Handler(BaseHTTPRequestHandler):
    def send_empty(self, status: int) -> None:
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
            return
        if self.path == "/events":
            with events_lock:
                snapshot = list(events)
            self.send_json(200, snapshot)
            return
        self.send_json(404, {"error": "not found"})

    def do_DELETE(self) -> None:  # noqa: N802
        if self.path != "/events":
            self.send_json(404, {"error": "not found"})
            return
        with events_lock:
            events.clear()
        self.send_empty(204)

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length)
        try:
            body: object = json.loads(raw_body)
        except json.JSONDecodeError:
            body = raw_body.decode(errors="replace")
        event = {
            "path": self.path,
            "headers": dict(self.headers.items()),
            "body": body,
        }
        with events_lock:
            events.append(event)
        self.send_empty(204)

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
