import functools
import http.server
import os
import sys

ROOT = os.path.expanduser("~/.hermes/workspace/od-pages")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787


class Handler(http.server.SimpleHTTPRequestHandler):
    def list_directory(self, path):
        self.send_error(404)
        return None

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Robots-Tag", "noindex")
        super().end_headers()


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), functools.partial(Handler, directory=ROOT)).serve_forever()
