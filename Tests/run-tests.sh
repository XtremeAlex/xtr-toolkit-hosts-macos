#!/bin/sh
# Test della logica di lettura/scrittura del file hosts, senza Xcode ne' privilegi:
# compila modelli, parser e HostsDocument insieme ai test e li esegue. Adatto anche a CI.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/xtr-toolkit-hosts-macos"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

xcrun swiftc -O -o "$OUT/hosts-tests" \
  "$SRC/Models/Host.swift" \
  "$SRC/Models/HostApp.swift" \
  "$SRC/Utilities/HostsDocument.swift" \
  "$SRC/Utilities/IOHostParser.swift" \
  "$ROOT/Tests/HostsDocumentTests/main.swift"

"$OUT/hosts-tests"
