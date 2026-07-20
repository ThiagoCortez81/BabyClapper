#!/usr/bin/env bash
# Generates a unit/widget test coverage report for BabyClapper.
#
# Usage:
#   bash tool/coverage.sh           # run tests, build filtered report + summary
#   bash tool/coverage.sh --open    # also open the HTML report in a browser
#
# Excludes generated + non-instrumentable files so the percentage is honest:
#   *.g.dart and main.dart.
set -uo pipefail
cd "$(dirname "$0")/.."

RAW=coverage/lcov.info
FILTERED=coverage/lcov.filtered.info

echo "==> Running tests with coverage..."
fvm flutter test --coverage || { echo "tests failed — aborting report"; exit 1; }

echo "==> Filtering generated / non-instrumentable files..."
lcov --remove "$RAW" \
  '*.g.dart' \
  'lib/main.dart' \
  --ignore-errors unused,inconsistent,empty,corrupt \
  -o "$FILTERED"

echo "==> Generating HTML report..."
genhtml "$FILTERED" -o coverage/html --quiet \
  --ignore-errors inconsistent,corrupt,category 2>/dev/null \
  || genhtml "$FILTERED" -o coverage/html --quiet

echo ""
echo "==> Overall + per-package line coverage:"
awk '
/^SF:/ { f=substr($0,4); sub(/^lib\//,"",f); n=split(f,p,"/"); pkg=(n>=2)?p[1]"/"p[2]:p[1] }
/^LF:/ { lf=substr($0,4) }
/^LH:/ { lh=substr($0,4); LF[pkg]+=lf; LH[pkg]+=lh; TLF+=lf; TLH+=lh }
END {
  for (k in LF) printf "%6.1f%%  %5d/%-5d  %s\n", (LF[k]?100*LH[k]/LF[k]:100), LH[k], LF[k], k
  printf "\n==== OVERALL: %.2f%%  (%d/%d) ====\n", (TLF?100*TLH/TLF:0), TLH, TLF
}' "$FILTERED" | sort -n

echo ""
echo "Report: coverage/html/index.html"
if [[ "${1:-}" == "--open" ]]; then open coverage/html/index.html; fi
