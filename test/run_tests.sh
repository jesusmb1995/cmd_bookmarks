#!/usr/bin/env zsh
set -u

REPO="${0:A:h}/.."
SB=$(mktemp -d)
export SB
FAILED=0

pass() { echo "PASS: $1" }
fail() { echo "FAIL: $1"; FAILED=1 }

# Sandbox: fake home + deployed copy of the repo (no .git)
HOME="$SB/home"
export HOME
mkdir -p "$HOME/.local/share"
cp -r "$REPO" "$HOME/.local/share/cmd_bookmarks"
rm -rf "$HOME/.local/share/cmd_bookmarks/.git"

# Non-interactive shells have no completion system
if ! command -v compdef >/dev/null 2>&1; then
    compdef() { : }
fi
if ! command -v _describe >/dev/null 2>&1; then
    _describe() { : }
fi

mkdir -p "$SB/proj dir" "$SB/proj2" "$SB/proj3"

echo "== CENTRAL mode =="
source "$HOME/.local/share/cmd_bookmarks/savecmd.zsh"

cd "$SB/proj dir"
print -s 'echo hello-world'
cmdsave testcmd >/dev/null

central_store="$HOME/.local/share/cmd_bookmarks/${PWD//\//_}"
if [[ -f "$central_store/.local_cmd_bookmarks" ]]; then
    pass "central bookmarks file created at $central_store/.local_cmd_bookmarks"
else
    fail "central bookmarks file missing at $central_store/.local_cmd_bookmarks"
fi
if grep -Eq '^testcmd\|echo hello-world$' "$central_store/.local_cmd_bookmarks"; then
    pass "central bookmarks file contains 'testcmd|echo hello-world'"
else
    fail "central bookmarks file does not contain 'testcmd|echo hello-world'"
fi
if cmdlist | grep -q 'testcmd'; then
    pass "cmdlist shows testcmd"
else
    fail "cmdlist does not show testcmd"
fi
if cmdrun testcmd >/dev/null 2>&1; then
    pass "cmdrun testcmd exits 0"
else
    fail "cmdrun testcmd did not exit 0"
fi
if [[ ! -e "$SB/proj dir/.local_cmd_bookmarks" ]]; then
    pass "no .local_cmd_bookmarks created in proj dir"
else
    fail "unexpected .local_cmd_bookmarks created in proj dir"
fi

echo "== auto-import =="
echo 'old|echo old' > "$SB/proj2/.local_cmd_bookmarks"
echo "old|1000" > "$SB/proj2/.local_cmd_bookmarks_stats"
cd "$SB/proj2"
cmdlist >/dev/null
central_store2="$HOME/.local/share/cmd_bookmarks/${PWD//\//_}"
if grep -q 'old|echo old' "$central_store2/.local_cmd_bookmarks" 2>/dev/null; then
    pass "auto-import copied legacy bookmarks into central store"
else
    fail "auto-import did not copy legacy bookmarks into $central_store2"
fi
if grep -q '^old|1000$' "$central_store2/.local_cmd_bookmarks_stats" 2>/dev/null; then
    pass "auto-import copied legacy stats into central store"
else
    fail "auto-import did not copy legacy stats into $central_store2"
fi

echo "== LEGACY mode =="
mkdir -p "$SB/other" "$SB/home2"
cp "$REPO/savecmd.zsh" "$SB/other/savecmd.zsh"
cat > "$SB/legacy_inner.zsh" <<'EOF'
set -u
if ! command -v compdef >/dev/null 2>&1; then
    compdef() { : }
fi
if ! command -v _describe >/dev/null 2>&1; then
    _describe() { : }
fi
source "$SB/other/savecmd.zsh"
mkdir -p "$SB/proj3"
cd "$SB/proj3"
print -s 'echo legacy-run'
cmdsave legacycmd >/dev/null
[[ -f "$SB/proj3/.local_cmd_bookmarks" ]] || { echo "FAIL: legacy bookmarks file missing"; exit 1 }
grep -Eq '^legacycmd\|echo legacy-run$' "$SB/proj3/.local_cmd_bookmarks" || { echo "FAIL: legacy bookmarks content wrong"; exit 1 }
echo "PASS: legacy mode writes .local_cmd_bookmarks in cwd"
EOF
if HOME="$SB/home2" zsh -f "$SB/legacy_inner.zsh"; then
    : 
else
    fail "legacy mode test failed"
fi

if (( FAILED == 0 )); then
    echo "ALL TESTS PASSED"
    rm -rf "$SB"
else
    echo "TESTS FAILED (sandbox kept at $SB for debugging)"
fi
exit "$FAILED"
