"""Serialize raw scanner results. Python stdlib only, used by --json."""

import json
import os
from pathlib import Path
import re
import sys


def evidence(raw, root):
    """Keep real grep locations; filename/header-only evidence has no line."""
    result = []
    # grep separates records with LF, not Unicode/control line separators.
    for hit in raw.split("\n"):
        if hit.startswith("response-headers: "):
            result.append({"file": "response-headers.txt", "line": None,
                           "match": hit[len("response-headers: "):]})
            continue
        # A filename can itself contain colons and numbers. Accept a location
        # delimiter after the longest real file path, not an existing shorter
        # filename prefix (e.g. both "form" and "form:7:test.html").
        for location in reversed(list(re.finditer(r":([0-9]+):", hit))):
            filename = hit[:location.start()]
            if Path(filename).is_file():
                result.append({"file": os.path.relpath(filename, root),
                               "line": int(location.group(1)),
                               "match": hit[location.end():]})
                break
        else:
            if Path(hit).is_file():
                result.append({"file": os.path.relpath(hit, root),
                               "line": None, "match": None})
    return result


def main(args):
    target, directory, url_mode, level, ai, host, app, consent, platforms = args[:9]
    root = os.path.abspath(directory)
    signals = {}
    results = args[9:]
    for offset in range(0, len(results), 3):
        name, detected, hits = results[offset:offset + 3]
        signals[name] = {
            "detected": None if detected == "null" else detected == "true",
            "evidence": evidence(hits, root),
            "evidence_limit": 10 if name == "PERMISSIONS" else (2 if name == "ACCOUNT_DELETE" else 3),
        }
    scope = {"mode": "url" if url_mode == "1" else "directory", "root": root}
    limitations = ["heuristic_matches_require_review", "evidence_is_bounded", "no_browser_execution"]
    if url_mode == "1":
        scope.update(max_linked_pages=15, max_javascript_files=20)
        limitations.extend(["public_pages_only", "server_side_not_inspected"])
    else:
        limitations.append("supported_source_files_only")
    json.dump({
        "schema_version": 1,
        "target": target,
        "scope": scope,
        "summary": {"level": int(level), "ai": ai == "yes", "foreign_host": host == "yes",
                    "app": app == "yes", "tracking_consent": consent,
                    "platforms": platforms.split()},
        "signals": signals,
        "limitations": limitations,
    }, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main(sys.stdin.buffer.read().decode("utf-8", errors="surrogateescape").split("\0")[:-1])
