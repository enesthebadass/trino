#!/usr/bin/env bash
set -euo pipefail

failures=0

check() {
  name="$1"
  command="$2"

  if bash -lc "$command" >/dev/null 2>&1; then
    printf '[OK] %s\n' "$name"
  else
    printf '[FAIL] %s\n' "$name"
    failures=$((failures + 1))
  fi
}

check "x86_64 architecture" '[ "$(uname -m)" = "x86_64" ]'
check "Linux kernel 5.x or newer" 'test "$(uname -r | cut -d. -f1)" -ge 5'
check "glibc 2.28 or newer" "ldd --version | head -n1 | grep -Eq '2\\.([2-9][8-9]|[3-9][0-9])|[3-9]\\.'"
check "Java 24 available" "java -version 2>&1 | grep -q 'version \"24'"
check "Python 3.9 or newer" "python3 - <<'PY2'
import sys
raise SystemExit(0 if sys.version_info >= (3, 9) else 1)
PY2"
check "ulimit -n >= 131072" 'test "$(ulimit -n)" -ge 131072'
check "ulimit -u >= 128000" 'test "$(ulimit -u)" -ge 128000'
check "swap disabled" 'test "$(awk '\''/^SwapTotal:/ {print $2}'\'' /proc/meminfo)" = "0"'
check "THP disabled" "grep -q '\\[never\\]' /sys/kernel/mm/transparent_hugepage/enabled"

if [ "$failures" -gt 0 ]; then
  printf '\n%d preflight check(s) failed. Sunucu ayarlari production oncesi duzeltilmeli.\n' "$failures"
  exit 1
fi

printf '\nAll preflight checks passed.\n'
