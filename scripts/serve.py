#!/usr/bin/env python3
"""Local dev server with extensionless URL support, live reload, mirrors GitHub Pages."""

import argparse
import http.server
import os
import threading
import time
import urllib.parse
import webbrowser
from functools import partial
from pathlib import Path

_change_id = 0
_change_cond = threading.Condition()

RELOAD_SCRIPT = b'<script>new EventSource("/--reload").onmessage=()=>location.reload()</script>'


def watch_files(directory, interval=0.5, debounce=0.75):
    """Reload after file changes settle, ignoring Git metadata."""
    global _change_id
    mtimes = None
    changed_at = None
    while True:
        current = {}
        for root, dirs, files in os.walk(directory):
            dirs[:] = [name for name in dirs if not name.startswith(".") and name not in {"drafts", "__pycache__"}]
            for f in files:
                if f == ".git":
                    continue
                path = os.path.join(root, f)
                try:
                    stat = os.stat(path)
                    current[path] = (stat.st_mtime_ns, stat.st_size)
                except OSError:
                    pass
        if mtimes is not None and current != mtimes:
            changed_at = time.monotonic()
        if changed_at is not None and time.monotonic() - changed_at >= debounce:
            with _change_cond:
                _change_id += 1
                _change_cond.notify_all()
            changed_at = None
        mtimes = current
        time.sleep(interval)


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Dev server: never cache subresources, always force revalidation.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def translate_path(self, path):
        result = super().translate_path(path)
        if not os.path.exists(result) and os.path.exists(result + ".html"):
            return result + ".html"
        return result

    def _private_path(self):
        parts = Path(urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)).parts
        return any(part.startswith('.') or part in {'drafts', '__pycache__'} for part in parts)

    def list_directory(self, path):
        self.send_error(403, "Directory listings are disabled")
        return None

    def do_HEAD(self):
        if self._private_path():
            self.send_error(404)
            return
        super().do_HEAD()

    def do_GET(self):
        if self._private_path():
            self.send_error(404)
            return
        parsed = urllib.parse.urlsplit(self.path)
        request_path = parsed.path

        if request_path == "/--reload":
            return self._handle_sse()

        # Preserve browser URL semantics for directories:
        # "/dir" should redirect to "/dir/" so relative asset URLs resolve correctly.
        dir_check = self.translate_path(request_path)
        if os.path.isdir(dir_check) and not request_path.endswith("/"):
            location = urllib.parse.urlunsplit(("", "", request_path + "/", parsed.query, parsed.fragment))
            self.send_response(301)
            self.send_header("Location", location)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        path = self.translate_path(request_path)
        if os.path.isdir(path):
            path = os.path.join(path, "index.html")
        if path.endswith(".html") and os.path.isfile(path):
            with open(path, "rb") as f:
                content = f.read()
            content = content.replace(b"</body>", RELOAD_SCRIPT + b"\n</body>")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            return

        super().do_GET()

    def _handle_sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        last = _change_id
        try:
            while True:
                with _change_cond:
                    changed = _change_cond.wait_for(lambda: _change_id > last, timeout=15)
                    last = _change_id
                self.wfile.write(b"data: reload\n\n" if changed else b": heartbeat\n\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass

    def log_message(self, format, *args):
        if args and isinstance(args[0], str) and "--reload" in args[0]:
            return
        super().log_message(format, *args)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("port", nargs="?", type=int, default=8000)
    parser.add_argument("--directory", type=Path,
                        help="preview another output directory (relative to the repository root)")
    parser.add_argument("--no-open", action="store_true",
                        help="do not open the site in the default browser")
    parser.add_argument("--lan", action="store_true",
                        help="allow other devices on your network to access the preview")
    args = parser.parse_args()

    directory = args.directory or Path(".")
    if not directory.is_absolute():
        directory = Path(__file__).resolve().parents[1] / directory
    directory = directory.resolve()
    if not directory.is_dir():
        parser.error(f"site directory does not exist: {directory}")
    host = "0.0.0.0" if args.lan else "127.0.0.1"
    try:
        server = http.server.ThreadingHTTPServer(
            (host, args.port), partial(Handler, directory=str(directory)))
    except OSError as error:
        parser.exit(1, f"Cannot start preview: {error}\n")
    with server:
        threading.Thread(target=watch_files, args=(directory,), daemon=True).start()
        url = f"http://localhost:{server.server_port}"
        print(f"Preview directory: {directory}", flush=True)
        print(f"Serving on {url} (live reload enabled)", flush=True)
        if args.lan:
            print("LAN access enabled; use this Mac's IP address from other devices.", flush=True)
        if not args.no_open:
            threading.Timer(0.5, lambda: webbrowser.open(url)).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down.")


if __name__ == "__main__":
    main()
