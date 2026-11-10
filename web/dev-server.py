#!/usr/bin/env python3
"""Local dev-preview server for web/.

Plain `python3 -m http.server` sends no cache-control headers, so browsers
fall back to heuristic caching and can keep serving a stale style.css/app.js
after an edit — confusing during active iteration. This is dev-only: the
real screensaver/app shells load these files straight off disk (or from an
app bundle), never over HTTP, so production is unaffected either way.
"""
import http.server
import os

PORT = 8755


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        super().end_headers()


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    http.server.test(HandlerClass=NoCacheHandler, port=PORT)
