#!/usr/bin/env python3
"""Relative path of a file inside a repo root, or loud failure.

Prints the path of <file> relative to <repo> — the value for
`git lfs pull --include=<rel>` in restore-db.bash. Exits 1 if the
file resolves outside the repo (the pointer cannot be materialized).
"""
import os
import sys


def relpath(file: str, repo: str) -> str:
    rel = os.path.relpath(file, repo)
    if rel == ".." or rel.startswith("../") or os.path.isabs(rel):
        raise ValueError(f"{file} is outside repo {repo}; cannot materialize LFS object")
    return rel


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: lfs-relpath.py <file> <repo>", file=sys.stderr)
        sys.exit(2)
    try:
        print(relpath(sys.argv[1], sys.argv[2]))
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
