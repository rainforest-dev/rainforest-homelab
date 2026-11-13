import functools
import http.server
import os
import sys

ROOT = os.path.realpath(os.path.expanduser("~/.hermes/workspace/od-pages"))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
ALLOWED = {".html", ".css", ".js", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".ico", ".woff2"}


class Handler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        path = os.path.realpath(self.translate_path(self.path))
        rel = os.path.relpath(path, ROOT)
        if (rel.startswith("..") or any(part.startswith(".") for part in rel.split(os.sep))
                or os.path.isdir(path) or os.path.splitext(path)[1].lower() not in ALLOWED):
            self.send_error(404)
            return None
        return super().send_head()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Robots-Tag", "noindex")
        super().end_headers()


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), functools.partial(Handler, directory=ROOT)).serve_forever()
