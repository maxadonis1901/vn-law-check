"""Consumer-facing JSON/CLI checks; no LLM calls or external websites."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_fetch_site import site


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures"
BASH = shutil.which("bash")


class ScanJsonTests(unittest.TestCase):
    def run_scan(self, *args, cwd=ROOT, env=None):
        return subprocess.run(
            [BASH, str(ROOT / "scripts/scan.sh"), *map(str, args)],
            cwd=cwd, env=env, capture_output=True, text=True, timeout=30,
        )

    def scan(self, target, *, after=False):
        args = [target, "--json"] if after else ["--json", target]
        result = self.run_scan(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        try:
            data = json.loads(result.stdout)
        except ValueError:
            self.fail("stdout must contain only a JSON document: " + result.stdout)
        self.assertEqual(data["schema_version"], 1)
        self.assertEqual(data["target"], str(target))
        return data

    def test_summaries_match_existing_fixture_expectations(self):
        keys = {"LEVEL": "level", "AI": "ai", "FOREIGN_HOST": "foreign_host",
                "APP": "app", "TRACKING_CONSENT": "tracking_consent"}
        for fixture in sorted(FIXTURES.iterdir()):
            if not fixture.is_dir() or (fixture / "URL_ONLY").exists():
                continue
            with self.subTest(fixture=fixture.name):
                result = self.scan(fixture)
                for pair in (fixture / "EXPECTED").read_text().split():
                    key, value = pair.split("=", 1)
                    expected = int(value) if key == "LEVEL" else (
                        value == "yes" if value in ("yes", "no") else value
                    )
                    self.assertEqual(result["summary"][keys[key]], expected)
                self.assertEqual(result["scope"]["mode"], "directory")
                self.assertEqual(result["scope"]["root"], str(fixture))

    def test_evidence_preserves_unicode_quotes_colons_and_control_characters(self):
        with tempfile.TemporaryDirectory(prefix='scan "dữ liệu"\t') as tmp:
            name = 'form:7:"đăng ký".html'
            (Path(tmp) / name).write_text('<form title="Dữ liệu \\ mới">\n<input type="email">\n')
            result = self.scan(tmp)
            signal = result["signals"]["FORM"]
            self.assertIs(signal["detected"], True)
            self.assertEqual(signal["evidence"][0], {"file": name, "line": 1, "match": "<form "})
            self.assertEqual(signal["evidence"][1]["line"], 2)
            self.assertEqual(signal["evidence"][1]["match"], 'type="email"')

    def test_signal_applicability_is_distinct_from_absence(self):
        web = self.scan(FIXTURES / "static-blog")
        self.assertIs(web["signals"]["FORM"]["detected"], False)
        for name in ("PERMISSIONS", "SDK_TRACKING", "ADS_SDK", "ACCOUNT_DELETE"):
            self.assertIsNone(web["signals"][name]["detected"])
            self.assertEqual(web["signals"][name]["evidence"], [])
        app = self.scan(FIXTURES / "rn-app")
        self.assertIs(app["signals"]["MOBILE_APP"]["detected"], True)
        self.assertIn("React-Native", app["summary"]["platforms"])
        self.assertIs(app["signals"]["ACCOUNT_DELETE"]["detected"], False)

    def test_evidence_uses_full_filename_when_shorter_prefix_also_exists(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "form").write_text("unrelated prefix file")
            (Path(tmp) / "form:7:test.html").write_text("<p>Intro</p>\n<form>\n")
            result = self.scan(tmp)
            self.assertEqual(result["signals"]["FORM"]["evidence"], [
                {"file": "form:7:test.html", "line": 2, "match": "<form>"}
            ])

    def test_unicode_and_control_separators_in_filenames_remain_evidence(self):
        for separator in ("\u2028", "\u2029", "\u0085", "\v", "\f", "\r"):
            with self.subTest(separator=repr(separator)), tempfile.TemporaryDirectory() as tmp:
                name = "form" + separator + "data.html"
                (Path(tmp) / name).write_text("<form>\n")
                result = self.scan(tmp)
                self.assertEqual(result["signals"]["FORM"]["evidence"], [
                    {"file": name, "line": 1, "match": "<form>"}
                ])

    def test_config_filename_evidence_has_no_invented_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "vercel.json").write_text("{}")
            result = self.scan(tmp)
            self.assertEqual(result["signals"]["FOREIGN_HOST"]["evidence"], [
                {"file": "vercel.json", "line": None, "match": None}
            ])

    def test_large_tracking_evidence_is_not_limited_by_process_arguments(self):
        with tempfile.TemporaryDirectory() as tmp:
            tag = '<script src="https://www.googletagmanager.com/gtag/js?q=' + "x" * 3000000 + '\\test">'
            (Path(tmp) / "index.html").write_text(tag + "</script>")
            result = self.scan(tmp)
            self.assertEqual(result["signals"]["TRACKING_PRELOAD"]["evidence"][0]["match"], tag)

    def test_evidence_limits_and_consent_details(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "index.html").write_text("<form>\n" * 8)
            result = self.scan(tmp)
            self.assertEqual(len(result["signals"]["FORM"]["evidence"]), 3)
            self.assertEqual(result["signals"]["FORM"]["evidence_limit"], 3)
        result = self.scan(FIXTURES / "consent-multiline-active")
        self.assertIs(result["signals"]["TRACKING_PRELOAD"]["detected"], True)
        self.assertEqual(result["signals"]["TRACKING_PRELOAD"]["evidence"][0]["line"], 4)
        blocked = self.scan(FIXTURES / "consent-multiline-blocked")
        self.assertIs(blocked["signals"]["TRACKING_PRELOAD"]["detected"], False)
        self.assertIs(blocked["signals"]["CONSENT_GATE"]["detected"], True)

    def test_json_flag_after_target_and_default_target(self):
        self.assertEqual(self.scan(FIXTURES / "static-blog", after=True)["summary"]["level"], 0)
        result = self.run_scan("--json", cwd=FIXTURES / "static-blog")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["target"], ".")
        self.assertEqual(data["scope"]["root"], str(FIXTURES / "static-blog"))

    def test_url_json_contains_scope_and_downloaded_js_evidence(self):
        fixture = FIXTURES / "spa-url"
        pages = {"/" + str(p.relative_to(fixture)): p.read_text()
                 for p in fixture.rglob("*") if p.is_file()}
        pages["/"] = pages["/index.html"]
        with site(pages) as (origin, requests):
            result = self.scan(origin + "/")
            self.assertEqual(result["scope"]["mode"], "url")
            self.assertEqual(result["scope"]["max_linked_pages"], 15)
            self.assertEqual(result["scope"]["max_javascript_files"], 20)
            self.assertIn("/assets/index-a1b2c3.js", requests)
            self.assertEqual(result["summary"]["level"], 1)
            self.assertIn("server_side_not_inspected", result["limitations"])
            self.assertIn("no_browser_execution", result["limitations"])
            evidence = result["signals"]["FORM"]["evidence"][0]
            downloaded = Path(result["scope"]["root"])
            self.assertEqual(downloaded.parent.resolve(), Path(tempfile.gettempdir()).resolve())
            self.addCleanup(shutil.rmtree, downloaded)
            self.assertTrue((downloaded / evidence["file"]).is_file())
            self.assertIsInstance(evidence["line"], int)

    def test_cli_errors_have_nonzero_exit_and_empty_stdout(self):
        for args in (("--json", "/vn-law-check-missing-dir"), ("--json", "--unknown"),
                     ("--json", ".", ".")):
            with self.subTest(args=args):
                result = self.run_scan(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertTrue(result.stderr.strip())

    def test_failed_url_fetch_does_not_emit_a_success_document(self):
        with site({"/": "unused"}) as (origin, _requests):
            pass
        result = self.run_scan("--json", origin)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertTrue(result.stderr.strip())

    def test_python_is_only_required_in_json_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("grep", "awk", "find", "head", "sed", "cut", "dirname"):
                Path(tmp, name).symlink_to(shutil.which(name))
            env = dict(os.environ, PATH=tmp)
            text = self.run_scan(FIXTURES / "static-blog", env=env)
            self.assertEqual(text.returncode, 0, text.stderr)
            self.assertIn("LEVEL=0", text.stdout)
            result = self.run_scan("--json", FIXTURES / "static-blog", env=env)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertIn("Python 3", result.stderr)

    def test_ad_claims_and_health_supplement_warning(self):
        with tempfile.TemporaryDirectory() as tmp:
            page = Path(tmp, "index.html")
            page.write_text(
                "<p>Uy tín số 1 Việt Nam, giá rẻ nhất.</p>\n"
                "<p>Mang lại trải nghiệm tốt nhất.</p>\n"
                "<p>Số 1 Đại Cồ Việt</p>\n"
                "<p>Thực phẩm bảo vệ sức khỏe ABC</p>\n"
            )
            result = self.scan(tmp)
            claims = [hit["match"] for hit in result["signals"]["AD_CLAIM"]["evidence"]]
            self.assertEqual(claims, ["Uy tín số 1", "giá rẻ nhất"])
            self.assertTrue(result["signals"]["HEALTH_SUPPLEMENT"]["detected"])
            self.assertFalse(result["signals"]["HEALTH_WARNING"]["detected"])

            page.write_text(page.read_text() + "<p>Thực phẩm này không phải là thuốc.</p>\n")
            self.assertTrue(self.scan(tmp)["signals"]["HEALTH_WARNING"]["detected"])

        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "index.html").write_text("<p>Chính sách đổi trả</p>\n")
            result = self.scan(tmp)
            self.assertFalse(result["signals"]["AD_CLAIM"]["detected"])
            self.assertIsNone(result["signals"]["HEALTH_WARNING"]["detected"])


if __name__ == "__main__":
    unittest.main()
