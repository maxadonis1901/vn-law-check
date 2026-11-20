"""Exercise the real fetcher and curl against isolated local HTTP sites."""

from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import subprocess
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def site(pages):
    requests = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.path)
            body = pages.get(self.path)
            if isinstance(body, tuple):
                self.send_response(302)
                self.send_header("Location", body[0])
                self.end_headers()
                return
            self.send_response(200 if body is not None else 404)
            self.end_headers()
            self.wfile.write((body or "Not found").encode())

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}", requests
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


class FetchSiteTests(unittest.TestCase):
    def fetch(self, url, destination, curl_home=None):
        env = os.environ.copy()
        if curl_home is not None:
            env["CURL_HOME"] = str(curl_home)
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/fetch-site.sh"), url, str(destination)],
            capture_output=True, text=True, timeout=30, env=env,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_hostname_suffix_for_pages_and_scripts(self):
        with site({"/privacy": "external page", "/track.js": "external JS"}) as (external, external_requests):
            pages = {
                "/": '<a href="http://shop.example.other.test/privacy">External</a>'
                     '<script src="http://shop.example.other.test/track.js"></script>'
                     '<a href="/privacy">Local</a>',
                "/privacy": "local policy",
            }
            with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
                curl_home = Path(tmp) / "curl"
                curl_home.mkdir()
                # Real curl/HTTP, but route both test hostnames exclusively to localhost.
                (curl_home / ".curlrc").write_text(
                    'noproxy = "*"\n'
                    f'connect-to = "shop.example:80:{origin.split("://", 1)[1]}"\n'
                    f'connect-to = "shop.example.other.test:80:{external.split("://", 1)[1]}"\n'
                )
                self.fetch("http://shop.example/", Path(tmp) / "download", curl_home)
                self.assertIn("/privacy", requests)
                self.assertEqual(external_requests, [])

    def test_rejects_origin_prefix_with_different_authority(self):
        with site({"/privacy": "external page", "/track.js": "external JS"}) as (external, external_requests):
            pages = {"/privacy": "local policy"}
            with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
                # Looks like the origin as text, but the part before @ is userinfo.
                bypass = origin + "@" + external.removeprefix("http://")
                pages["/"] = (
                    f'<a href="{bypass}/privacy">External</a>'
                    f'<script src="{bypass}/track.js"></script>'
                    '<a href="/privacy">Local</a>'
                )
                self.fetch(origin + "/", Path(tmp))
                self.assertIn("/privacy", requests)
                self.assertEqual(external_requests, [], "Fetcher contacted a different authority")

    def test_resolves_pages_relative_to_entry_page(self):
        pages = {
            "/shop/index.html": '<a href="privacy.html">Policy</a><a href="../contact.html">Contact</a>',
            "/shop/privacy.html": "shop policy marker",
            "/contact.html": "contact marker",
        }
        with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
            self.fetch(origin + "/shop/index.html", Path(tmp))
            contents = "\n".join(p.read_text() for p in (Path(tmp) / "pages").glob("*.html"))
            self.assertIn("/shop/privacy.html", requests)
            self.assertIn("/contact.html", requests)
            self.assertIn("shop policy marker", contents)
            self.assertIn("contact marker", contents)

    def test_resolves_scripts_relative_to_each_containing_page(self):
        pages = {
            "/shop/": '<a href="policies/privacy.html">Policy</a><script src="assets/home.js"></script>',
            "/shop/policies/privacy.html": '<script src="assets/policy.js"></script>',
            "/shop/assets/home.js": "home script marker",
            "/shop/policies/assets/policy.js": "policy script marker",
        }
        with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
            self.fetch(origin + "/shop/", Path(tmp))
            contents = "\n".join(p.read_text() for p in (Path(tmp) / "js").glob("*.js"))
            self.assertIn("/shop/assets/home.js", requests)
            self.assertIn("/shop/policies/assets/policy.js", requests)
            self.assertIn("home script marker", contents)
            self.assertIn("policy script marker", contents)

    def test_preserves_root_query_and_protocol_relative_links(self):
        pages = {"/": "", "/privacy?lang=vi": "query policy", "/terms": "terms marker"}
        with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
            pages["/"] = (
                '<a href="/privacy?lang=vi#details">Privacy</a>'
                f'<a href="//{origin.removeprefix("http://")}/terms">Terms</a>'
            )
            self.fetch(origin, Path(tmp))
            self.assertEqual(set(requests), {"/", "/privacy?lang=vi", "/terms"})

    def test_resolves_query_only_link_against_current_page(self):
        pages = {
            "/shop/index.html?lang=en": '<a href="?privacy=vi#details">Policy</a>',
            "/shop/index.html?privacy=vi": "policy marker",
        }
        with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
            self.fetch(origin + "/shop/index.html?lang=en", Path(tmp))
            self.assertIn("/shop/index.html?privacy=vi", requests)

    def test_resolves_links_against_redirected_page_urls(self):
        pages = {
            "/": ("/shop/",),
            "/shop/": '<a href="privacy.html">Policy</a>',
            "/shop/privacy.html": ("/legal/privacy.html",),
            "/legal/privacy.html": '<script src="assets/policy.js"></script>',
            "/legal/assets/policy.js": "redirected script marker",
        }
        with site(pages) as (origin, requests), tempfile.TemporaryDirectory() as tmp:
            self.fetch(origin + "/", Path(tmp))
            self.assertIn("/legal/assets/policy.js", requests)
            contents = "\n".join(p.read_text() for p in (Path(tmp) / "js").glob("*.js"))
            self.assertIn("redirected script marker", contents)

    def test_uses_canonical_origin_after_entry_redirect(self):
        canonical_pages = {
            "/shop/": '<a href="privacy.html">Policy</a><script src="assets/home.js"></script>',
            "/shop/privacy.html": "canonical policy marker",
            "/shop/assets/home.js": "canonical script marker",
        }
        with site(canonical_pages) as (canonical, canonical_requests):
            # A second local origin models a canonical host/scheme redirect without TLS.
            with site({"/": (canonical + "/shop/",)}) as (origin, _requests):
                with tempfile.TemporaryDirectory() as tmp:
                    self.fetch(origin + "/", Path(tmp))
                    self.assertIn("/shop/privacy.html", canonical_requests)
                    self.assertIn("/shop/assets/home.js", canonical_requests)


if __name__ == "__main__":
    unittest.main()
