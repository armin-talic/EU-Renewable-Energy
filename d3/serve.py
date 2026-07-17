# Small threaded static file server for local preview.
# (python -m http.server is single-threaded and drops parallel requests)
# Usage: python serve.py  ->  http://localhost:8641
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

class Handler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

if __name__ == "__main__":
    print("Serving dashboard at http://localhost:8641")
    ThreadingHTTPServer(("127.0.0.1", 8641), Handler).serve_forever()
