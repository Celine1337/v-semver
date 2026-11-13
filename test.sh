#!/usr/bin/env bash
# Self-contained test suite for v-semver. Requires v (build) + coreutils.
set -uo pipefail
cd "$(dirname "$0")"
export TC="$HOME/.local/toolchains"
export PATH="$TC/v/v:$PATH"
./build.sh >/dev/null || { echo "FAIL: build failed"; exit 1; }
SV="./bin/v-semver"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); }
bad(){ fail=$((fail+1)); echo "FAIL: $1"; }
# assert exit code + stdout substring
check(){ # name expected_exit expected_substring actual_exit actual_out
  local name="$1" want_rc="$2" want="$3" rc="$4" out="$5"
  if [ "$rc" != "$want_rc" ]; then bad "$name (exit $rc, want $want_rc)"; return; fi
  if [ -n "$want" ] && ! printf '%s' "$out" | grep -qF -- "$want"; then
    bad "$name (output missing '$want')"; return
  fi
  ok
}
# assert exit code + exact stdout (single-line results)
check_eq(){ # name expected_exit expected actual_exit actual_out
  local name="$1" want_rc="$2" want="$3" rc="$4" out="$5"
  if [ "$rc" != "$want_rc" ]; then bad "$name (exit $rc, want $want_rc)"; return; fi
  if [ "$out" != "$want" ]; then bad "$name (got '$out', want '$want')"; return; fi
  ok
}
cmp3(){ # A B expected
  out=$($SV compare "$1" "$2"); rc=$?
  check_eq "compare $1 $2" 0 "$3" "$rc" "$out"
}

# --- numeric core precedence ---
cmp3 1.2.3 1.2.4 -1
cmp3 2.0.0 1.9.9 1
cmp3 1.2.3 1.2.3 0
cmp3 1.10.0 1.9.0 1
cmp3 1.0.10 1.0.9 1

# --- prerelease vs release ---
cmp3 1.0.0-alpha 1.0.0 -1
cmp3 1.0.0 1.0.0-alpha 1

# --- semver.org spec precedence chain ---
cmp3 1.0.0-alpha 1.0.0-alpha.1 -1
cmp3 1.0.0-alpha.1 1.0.0-alpha.beta -1
cmp3 1.0.0-alpha.beta 1.0.0-beta -1
cmp3 1.0.0-beta 1.0.0-beta.2 -1
cmp3 1.0.0-beta.2 1.0.0-beta.11 -1
cmp3 1.0.0-beta.11 1.0.0-rc.1 -1
cmp3 1.0.0-rc.1 1.0.0 -1

# --- identifier rules ---
cmp3 1.0.0-alpha.2 1.0.0-alpha.10 -1   # numeric, not lexical
cmp3 1.0.0-1 1.0.0-alpha -1            # numeric < alphanumeric
cmp3 1.0.0-alpha 1.0.0-alpha.1 -1      # fewer fields < more
cmp3 1.0.0-alpha.1 1.0.0-alpha.1 0

# --- build metadata ignored ---
cmp3 1.0.0+build1 1.0.0+build2 0
cmp3 1.0.0-alpha+001 1.0.0-alpha+002 0
cmp3 1.0.0+20260101 1.0.0 0

# --- big numbers (no overflow) ---
cmp3 99999999999999999999.0.0 100000000000000000000.0.0 -1

# --- bump ---
out=$($SV bump 1.2.3 major); rc=$?
check_eq "bump major" 0 "2.0.0" "$rc" "$out"
out=$($SV bump 1.2.3 minor); rc=$?
check_eq "bump minor" 0 "1.3.0" "$rc" "$out"
out=$($SV bump 1.2.3 patch); rc=$?
check_eq "bump patch" 0 "1.2.4" "$rc" "$out"
out=$($SV bump 1.2.3-alpha+build patch); rc=$?
check_eq "bump drops prerelease/build" 0 "1.2.4" "$rc" "$out"
out=$($SV bump 0.0.0 major); rc=$?
check_eq "bump from zero" 0 "1.0.0" "$rc" "$out"
out=$($SV bump 1.9.9 minor); rc=$?
check_eq "bump minor resets patch" 0 "1.10.0" "$rc" "$out"

# --- valid ---
for good in 0.0.0 1.2.3 10.20.30 1.2.3-alpha 1.2.3-alpha.1 1.2.3-0.3.7 1.2.3-x.7.z.92 \
            1.2.3-alpha01 1.2.3+build 1.2.3-alpha+build.5 1.2.3--a 1.0.0-alpha-beta; do
  out=$($SV valid "$good"); rc=$?
  check_eq "valid $good" 0 "valid" "$rc" "$out"
done
for badv in "" "1.2" "1.2.3.4" "01.2.3" "1.02.3" "1.2.03" "1.2.3-" "1.2.3+" "1.2.3-alpha..1" \
            "1.2.3-01" "1.2.3+build..x" "1.2.3+b uild" "a.b.c" "1.2.3 " "v1.2.3" "1.2.3-alpha_1"; do
  out=$($SV valid "$badv"); rc=$?
  check_eq "invalid '$badv'" 1 "invalid" "$rc" "$out"
done

# --- invalid input to compare/bump: exit 1 + stderr ---
out=$($SV compare 1.2.3 garbage 2>"$TMP/err.txt"); rc=$?
if [ "$rc" = 1 ] && [ -s "$TMP/err.txt" ]; then ok; else bad "compare invalid exits 1 with stderr (rc=$rc)"; fi
out=$($SV bump nope minor 2>"$TMP/err.txt"); rc=$?
if [ "$rc" = 1 ] && [ -s "$TMP/err.txt" ]; then ok; else bad "bump invalid exits 1 with stderr (rc=$rc)"; fi

# --- bad usage: exit 2 ---
out=$($SV 2>/dev/null); rc=$?
check "no args exits 2" 2 "" "$rc" "$out"
out=$($SV compare 1.2.3 2>/dev/null); rc=$?
check "compare missing arg exits 2" 2 "" "$rc" "$out"
out=$($SV bump 1.2.3 wrong 2>/dev/null); rc=$?
check "bump bad part exits 2" 2 "" "$rc" "$out"
out=$($SV frobnicate 2>/dev/null); rc=$?
check "unknown command exits 2" 2 "" "$rc" "$out"
out=$($SV valid 1.2.3 extra 2>/dev/null); rc=$?
check "valid extra arg exits 2" 2 "" "$rc" "$out"

echo "----------------------------------------"
echo "v-semver: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "ALL CHECKS PASSED" || exit 1