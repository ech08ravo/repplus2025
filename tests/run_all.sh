#!/bin/bash
# Every automated check, in one go. Run from the project root before a release:
#
#     ./tests/run_all.sh
#
# Exits non-zero if any suite fails, so it can gate a deploy.
set -uo pipefail
cd "$(dirname "$0")/.."

status=0
for t in tests/test_grid_integrity.R tests/test_release_check.R; do
  echo
  echo "=============================================================="
  echo " $t"
  echo "=============================================================="
  if ! Rscript "$t"; then status=1; fi
done

echo
if [ "$status" -eq 0 ]; then
  echo "ALL SUITES PASSED - safe to release"
else
  echo "SUITE(S) FAILED - do not release"
fi
exit "$status"
