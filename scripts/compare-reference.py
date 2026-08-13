#!/usr/bin/env python3
"""Compare local and CI engine reference records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("local", type=Path)
    parser.add_argument("reference", type=Path)
    parser.add_argument("--require-exact", action="store_true")
    args = parser.parse_args()
    local = json.loads(args.local.read_text())
    reference = json.loads(args.reference.read_text())
    for record in (local, reference):
        if record.get("schema_version") != 1 or record.get("kind") != "wineforge-engine-build-reference":
            raise SystemExit("unsupported reference record")
    if local["id"] != reference["id"]:
        raise SystemExit(f'engine mismatch: {local["id"]} != {reference["id"]}')
    inputs_match = local["inputs_sha256"] == reference["inputs_sha256"]
    content_match = local["content_manifest_sha256"] == reference["content_manifest_sha256"]
    artifact_match = local["artifact_sha256"] == reference["artifact_sha256"]
    print(f'inputs\t{"match" if inputs_match else "DIFFER"}')
    print(f'normalized-content\t{"match" if content_match else "DIFFER"}')
    print(f'archive\t{"match" if artifact_match else "DIFFER"}')
    if not inputs_match:
        raise SystemExit(2)
    if args.require_exact and not (content_match and artifact_match):
        raise SystemExit(3)


if __name__ == "__main__":
    main()
