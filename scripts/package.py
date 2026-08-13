#!/usr/bin/env python3
"""Create a normalized gzip-compressed tar archive."""

from __future__ import annotations

import argparse
import gzip
import os
import tarfile
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--mtime", required=True, type=int)
    args = parser.parse_args()

    source = args.source.resolve(strict=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    paths = [source, *sorted(source.rglob("*"), key=lambda p: p.as_posix())]
    with args.output.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=args.mtime) as gz:
            with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as archive:
                for path in paths:
                    relative = Path("wineforge-engine")
                    if path != source:
                        relative /= path.relative_to(source)
                    info = archive.gettarinfo(str(path), arcname=relative.as_posix())
                    info.uid = 0
                    info.gid = 0
                    info.uname = "root"
                    info.gname = "root"
                    info.mtime = args.mtime
                    if path.is_file():
                        with path.open("rb") as handle:
                            archive.addfile(info, handle)
                    else:
                        archive.addfile(info)


if __name__ == "__main__":
    main()
