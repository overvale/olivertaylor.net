"""Check in-place builds and root previews in disposable directories."""
import functools
import hashlib
import http.client
import http.server
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('site_preview', ROOT / 'scripts/serve.py')
preview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preview)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class BuildTests(unittest.TestCase):
    def test_deleted_source_cleans_only_owned_output_and_rebuild_is_stable(self):
        with tempfile.TemporaryDirectory() as directory:
            site = Path(directory) / 'site'
            shutil.copytree(ROOT, site, ignore=shutil.ignore_patterns(
                '.git', '.claude', '.DS_Store', '__pycache__', 'drafts'))
            (site / 'markdown/notes/perfection.md').unlink()
            nav = site / 'markdown/site-nav.tsv'
            nav.write_text(''.join(line for line in nav.read_text().splitlines(True)
                                   if '|/notes/perfection|' not in line))
            manual = site / 'notes/hand-maintained.html'
            manual.write_text('Keep this hand-maintained page.')
            assets = [site / 'links.html', site / 'style.css', manual]
            assets.extend((site / 'writing').glob('*.pdf'))
            assets.extend((site / 'notes/img').glob('*'))
            before = {p: digest(p) for p in assets}
            result = subprocess.run(['make', 'html'], cwd=site,
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((site / 'notes/perfection.html').exists())
            self.assertFalse((site / 'build').exists())
            self.assertNotIn('notes/perfection.html', (site / '.generated-files').read_text())
            self.assertEqual(before, {p: digest(p) for p in assets})
            owned = (site / '.generated-files').read_text().splitlines()
            snapshot = {name: digest(site / name) for name in owned}
            result = subprocess.run(['make', 'html'], cwd=site,
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(snapshot, {name: digest(site / name) for name in owned})


class PreviewTests(unittest.TestCase):
    def test_root_preview_routes_and_private_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('<body>Homepage</body>')
            (root / 'notes').mkdir()
            (root / 'notes/index.html').write_text('<body>Notes</body>')
            (root / 'notes/example.html').write_text('<body>Example</body>')
            for folder in ('.git', 'drafts'):
                (root / folder).mkdir()
                (root / folder / 'private').write_text('Do not serve')
            server = http.server.ThreadingHTTPServer(
                ('127.0.0.1', 0), functools.partial(preview.Handler, directory=directory))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                for method, path, expected in [
                    ('GET', '/', 200), ('GET', '/notes/example', 200),
                    ('GET', '/notes?x=1', 301), ('HEAD', '/notes/example', 200),
                    ('GET', '/.git/private', 404), ('HEAD', '/.git/private', 404),
                    ('GET', '/%2egit/private', 404), ('GET', '/drafts/private', 404),
                ]:
                    with self.subTest(method=method, path=path):
                        conn = http.client.HTTPConnection('127.0.0.1', server.server_port)
                        conn.request(method, path)
                        response = conn.getresponse()
                        body = response.read()
                        self.assertEqual(response.status, expected)
                        if path == '/':
                            self.assertIn(preview.RELOAD_SCRIPT, body)
                        if expected == 301:
                            self.assertEqual(response.getheader('Location'), '/notes/?x=1')
                        conn.close()
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == '__main__':
    unittest.main()
