#!/usr/bin/env python3
"""Deterministic sort key from a dump filename's embedded timestamp.

Parses DD-MM-YYYY-HH-MM and DD-mon-YYYY-HH-MM patterns (e.g.
app-production-28-march-2026-00-24-ist.sql). Untimestamped names
sort last (key 00000000000000). Prints the key on stdout.
"""
import re
import sys

MONTHS = {m: i + 1 for i, m in enumerate(
    ["jan", "feb", "mar", "apr", "may", "jun",
     "jul", "aug", "sep", "oct", "nov", "dec"])}


def ts_key(name: str) -> str:
    m = re.search(r"(\d{1,2})-([A-Za-z]{3,}|\d{2})-(\d{4})-(\d{2})-(\d{2})", name.lower())
    if not m:
        return "00000000000000"
    dd, mon, yyyy, hh, mi = m.groups()
    mm = MONTHS[mon[:3]] if mon[:3] in MONTHS else int(mon)
    return f"{int(yyyy):04d}{int(mm):02d}{int(dd):02d}{hh}{mi}"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: ts_key.py <dump-filename-or-dirname>", file=sys.stderr)
        sys.exit(2)
    print(ts_key(sys.argv[1]))
