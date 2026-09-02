#!/usr/bin/env python3
"""Structural manifest lint for Omarchy plugins.

Runs where the `omarchy` CLI does not exist (e.g. GitHub CI) and mirrors the
structural checks of `omarchy plugin validate` / shell PluginRegistry.qml:

  - manifest.json exists and is valid JSON
  - schemaVersion is exactly the JSON number 1 (string "1" is rejected)
  - required fields: id, name, version, kinds, entryPoints
  - id, read with jq -r '.id // ""' coercion semantics (JSON scalars are
    stringified: 3 -> "3" passes the regex; only null/false become empty),
    matches ^[A-Za-z0-9][A-Za-z0-9._-]*$, contains no "..",
    and does not use the reserved omarchy.* namespace
  - kinds is a non-empty array (unknown kinds are NOT rejected — parity
    with the platform, which deliberately leaves unknown kinds alone; they
    earn a stderr warning, our stricter lint, but the exit code stays 0)
  - entryPoints is an object of safe relative paths that exist in the repo
  - every KNOWN kind has the entry point the shell loads it through
    (exactly the platform's kind↔entryPoint table — unknown kinds are
    skipped there too, so they are skipped here)
  - barWidget.defaultSection (when present) is left|center|right
  - no symlinks anywhere (git checkouts on CI never have them, but a local
    run of this script catches them the same way the real validator does)

This script's exit code must always PREDICT the real validator's verdict on
the same folder — a mirror that fails where reality passes (or vice versa)
teaches authors to ignore it. The one deliberate extra is the unknown-kinds
warning, which never changes the exit code.

SYNC DUTY: when the platform grows kind #7 or `omarchy plugin validate`
changes, hand-sync this file against
/usr/share/omarchy/bin/omarchy-plugin-validate (and shell
PluginRegistry.qml) before the next plugin is scaffolded.

The REAL gate remains `omarchy plugin validate <dir>` run locally before
every push/tag — this mirror cannot know the shell's runtime behavior.

Usage: validate_manifest.py [plugin-root]   (default: repo root, i.e. ".")
"""

import json
import os
import re
import sys

# The shell loads each kind through a fixed entryPoints key. This table is
# copied verbatim from omarchy-plugin-validate — SYNC DUTY: keep it in sync
# when the platform grows a new kind.
KIND_ENTRY_POINTS = {
    "bar": "bar",
    "bar-widget": "barWidget",
    "menu": "menu",
    "overlay": "overlay",
    "panel": "panel",
    "service": "service",
}

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def fail(msg):
    print(f"validate-manifest: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    manifest_path = os.path.join(root, "manifest.json")

    if not os.path.isfile(manifest_path):
        fail(f"missing manifest.json in {root}")
    try:
        with open(manifest_path, encoding="utf-8") as fh:
            manifest = json.load(fh)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        fail(f"manifest.json is not valid JSON: {exc}")
    if not isinstance(manifest, dict):
        fail("manifest.json must contain a JSON object")

    # schemaVersion must be exactly the number 1. The bool exclusion matters:
    # in Python, True == 1. JSON has no such ambiguity, so reject bools here
    # to stay as strict as the platform's type-aware check.
    version = manifest.get("schemaVersion")
    if isinstance(version, bool) or version != 1:
        fail("unsupported or missing schemaVersion (expected the number 1)")

    for field in ("id", "name", "version", "kinds", "entryPoints"):
        if field not in manifest:
            fail(f"manifest missing required field '{field}'")

    # The real validator reads the id as `jq -r '.id // ""'`: JSON scalars
    # are STRINGIFIED (the number 3 becomes "3" and passes the regex) and
    # only null/false map to "" (jq's only falsy values; 0 stays 0). A
    # mirror must predict reality, not improve on it — so coerce exactly
    # like jq instead of type-checking.
    raw_id = manifest["id"]
    plugin_id = "" if raw_id is None or raw_id is False else str(raw_id)
    if not plugin_id or not ID_RE.match(plugin_id):
        fail(f"invalid plugin id {plugin_id!r}")
    if ".." in plugin_id:
        fail(f"invalid plugin id {plugin_id!r} (contains '..')")
    if plugin_id.startswith("omarchy."):
        fail(f"plugin id {plugin_id!r} uses the reserved omarchy.* namespace")

    kinds = manifest["kinds"]
    if not isinstance(kinds, list) or not kinds:
        fail("'kinds' must be a non-empty array")
    # PLATFORM PARITY: the real validator deliberately leaves unknown kinds
    # alone — its source says "a kind not listed is left alone rather than
    # guessed at" — so `kinds: ["bogus"]` passes `omarchy plugin validate`.
    # The enum below is OUR stricter lint: it warns (stderr) so a typo is
    # visible in CI logs, but MUST NOT change the exit code, or this mirror
    # stops predicting the platform's verdict.
    unknown = [k for k in kinds if k not in KIND_ENTRY_POINTS]
    if unknown:
        print(
            f"warning: unknown kinds {unknown} (accepted by the platform "
            f"validator; known kinds: {sorted(KIND_ENTRY_POINTS)})",
            file=sys.stderr,
        )

    entry_points = manifest["entryPoints"]
    if not isinstance(entry_points, dict):
        fail("'entryPoints' must be an object")
    for key, value in entry_points.items():
        if not isinstance(value, str) or not value:
            fail(f"entry point '{key}' must be a non-empty string")
        if "\n" in value:
            fail(f"entry point '{key}' may not contain a newline")
        if value.startswith("/"):
            fail(f"entry point '{key}' must be a relative path: {value!r}")
        if ".." in value:
            fail(f"entry point '{key}' may not contain '..': {value!r}")
        if not os.path.isfile(os.path.join(root, value)):
            fail(f"entry point file not found: '{value}'")

    # A kind is a promise to supply something to load; claiming a kind
    # without its entry point installs fine and then silently does nothing.
    # (Platform parity: the real validator walks ITS table only, so unknown
    # kinds are skipped here exactly as they are skipped there.)
    for kind in kinds:
        key = KIND_ENTRY_POINTS.get(kind)
        if key is None:
            continue
        if key not in entry_points:
            fail(f"kind '{kind}' requires an 'entryPoints.{key}' to load")

    bar_widget = manifest.get("barWidget")
    if isinstance(bar_widget, dict) and "defaultSection" in bar_widget:
        section = bar_widget["defaultSection"]
        if section not in ("left", "center", "right"):
            fail(f"'barWidget.defaultSection' must be left, center, or right (got {section!r})")

    # Symlinks could point a copied plugin back at arbitrary files after it
    # lands in the trusted plugins directory. .git is skipped: installed
    # plugins are git checkouts and git internals are never loaded.
    for dirpath, dirnames, filenames in os.walk(root):
        if ".git" in dirnames:
            dirnames.remove(".git")
        for name in dirnames + filenames:
            if os.path.islink(os.path.join(dirpath, name)):
                fail(f"symlinks are not allowed inside a plugin folder: {name}")

    print(f"manifest OK: {plugin_id} ({', '.join(kinds)})")


if __name__ == "__main__":
    main()
