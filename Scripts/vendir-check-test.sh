#!/usr/bin/env bash
# vendir-check-test.sh — self-test for Scripts/vendir-check.sh. Each case
# builds a doctored fixture repo under mktemp (the checks assert committed
# state via `git show HEAD:` and `worktree add HEAD`, so every fixture is a
# real `git init` + commit), runs the gate against it through
# VENDIR_CHECK_ROOT, and asserts the exit code plus named output where a
# finding names a path. A final leg asserts the gate passes on the real
# tree. .github/workflows/vendir-check-test.yml (T026) calls a bare run of
# this suite in CI.
#
# Fixture remotes are file:// URLs widened through
# VENDIR_CHECK_ALLOW_PROTOCOLS=file:https (per-invocation only — a suite-wide
# widening would make the insteadOf-rewrite fixture legal). `ignorepaths`
# cases prepend a stub `curl` on PATH — a spy that logs every probed URL and
# answers fixture-chosen status codes, so every verdict branch (anchor 2xx,
# entry 2xx finding, 404 pass, couldn't-verify) runs hermetically; live HTTP
# stays with the real-tree leg and the weekly CI gate.
#
# Environment is hermetic by construction: GIT_CONFIG_NOSYSTEM=1 and a
# test-owned GIT_CONFIG_GLOBAL are exported for the whole suite (per-case
# overrides carry the insteadOf fixtures), so a developer's ~/.gitconfig —
# url rewrites, gpgsign, hooks — can neither flake a run nor leak into an
# assertion. Fixture commits carry their own local identity for the same
# reason.
#
# usage: vendir-check-test.sh [substring] — no args runs every case; an arg
# runs only cases whose name contains it (a filtered run exits 0 when its
# selection passes).
#
# Env: VENDIR  vendir binary (default: vendir on PATH) — sync fixtures and
#              the default real-tree leg need it; without it those cases
#              report SKIPPED rather than fail.
#      VENDIR_CHECK_TEST_OFFLINE=1
#              real-tree leg runs `allowlist locksha` only (no network) —
#              for dev runs without connectivity.
#
# Exit — mirrors the gate's diff(1) contract: 0 every selected case passed,
# 1 any case failed, 2 nothing failed but a case was skipped (missing vendir)
# or the suite itself couldn't run.
set -euo pipefail

T=$(mktemp -d "${TMPDIR:-/tmp}/vendir-check-test.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SCRIPT=$HERE/vendir-check.sh
REPO=$(cd "$HERE/.." && pwd -P)
[ -f "$SCRIPT" ] || { echo "error: gate script not found at $SCRIPT" >&2; exit 2; }

# Run from the scratch dir (paths above are already absolute): a
# relative-path slip — or a `git -C ""`, which git documents as CWD —
# lands in temp space, never in the caller's repo.
cd "$T"

VENDIR=${VENDIR:-vendir}
ONLY=${1:-}

command -v git >/dev/null 2>&1 || { echo "error: git required" >&2; exit 2; }
command -v yq  >/dev/null 2>&1 || { echo "error: yq required — brew install yq" >&2; exit 2; }

# Same env hygiene the gate applies to itself (vendir-check.sh): repo- and
# index-redirect vars plus config-injection vars from the caller's env must
# not steer the fixture gits this suite runs directly.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX \
    GIT_CONFIG_COUNT GIT_ALLOW_PROTOCOL

# Suite-wide hermetic git config — see header.
export GIT_CONFIG_NOSYSTEM=1
GCFG_EMPTY=$T/gitconfig.empty
: > "$GCFG_EMPTY"
export GIT_CONFIG_GLOBAL=$GCFG_EMPTY

pass=0 fail=0 skip=0
ok()    { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad()   { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
skipit(){ skip=$((skip + 1)); printf 'SKIP %s — %s\n' "$1" "$2"; }

# harness_die — a fixture-CONSTRUCTION failure, not a case verdict: reported
# with a distinct prefix and exit 2 (couldn't-run) so a broken fixture can't
# be mistaken for a red test or die silently under set -e.
harness_die() { printf 'HARNESS-FAIL %s\n' "$*" >&2; exit 2; }

# sel <name> — the ONLY filter: an empty word matches every case; otherwise
# the case name must contain it. Runner and skip path consult the same
# predicate so a filtered run never scores unselected cases either way.
sel() { case "$1" in *"$ONLY"*) return 0 ;; *) return 1 ;; esac; }
# selskip <name> <reason> — count a couldn't-run only when its case was
# selected (otherwise a filtered run would exit 2 on skips it never asked
# about). Always returns 0 — safe under set -e in a loop.
selskip() { sel "$1" || return 0; skipit "$1" "$2"; }

# it <name> <expected-rc> [check args...]
# A case first sets: CUR (fixture repo root), optionally GCFG (global
# gitconfig override) and EXTRA (extra env assignments array). A filtered-out
# case clears CUR_NAME (assertion helpers below no-op on it) AND resets the
# env slots — without the reset, a skipped case's EXTRA would leak into the
# next selected case's run.
it() {
    local name=$1 want=$2
    shift 2
    sel "$name" || { EXTRA=(); GCFG=$GCFG_EMPTY; CUR_NAME=; return 0; }
    local rc=0
    env VENDIR_CHECK_ROOT="$CUR" GIT_CONFIG_GLOBAL="${GCFG:-$GCFG_EMPTY}" \
        VENDIR="$VENDIR" ${EXTRA[@]+"${EXTRA[@]}"} \
        "$SCRIPT" "$@" >"$T/last.out" 2>&1 || rc=$?
    CUR_NAME=$name
    if [ "$rc" = "$want" ]; then
        ok "$name"
    else
        bad "$name — expected exit $want, got $rc"
        sed 's/^/    | /' "$T/last.out" | head -12
    fi
    EXTRA=()
    GCFG=$GCFG_EMPTY
}
# has/hasnt assert on the merged output of the last `it` run. Both no-op
# after a filtered-out case — otherwise assertions would grep a stale or
# missing last.out and report FAILs under the previous case's name.
has() {
    [ -n "$CUR_NAME" ] || return 0
    grep -qF "$1" "$T/last.out" || bad "$CUR_NAME — expected output: $1"
}
hasnt() {
    [ -n "$CUR_NAME" ] || return 0
    ! grep -qF "$1" "$T/last.out" || bad "$CUR_NAME — unexpected output: $1"
}
# log_has <regex> <what-went-wrong> / log_silent — the same guard for the
# stub curl's URL log (log_silent asserts the stub was never invoked).
log_has() {
    [ -n "$CUR_NAME" ] || return 0
    { [ -s "$CURLLOG" ] && grep -q "$1" "$CURLLOG"; } \
        || bad "$CUR_NAME — $2: $(cat "$CURLLOG" 2>/dev/null || echo '<no stub log>')"
}
log_silent() {
    [ -n "$CUR_NAME" ] || return 0
    [ ! -s "$CURLLOG" ] || bad "$CUR_NAME — stub curl was invoked for a local finding"
}

EXTRA=()
GCFG=$GCFG_EMPTY
CUR=$REPO
CUR_NAME=

# — fixture builders ———————————————————————————————————————————————————

mkrepo() {
    local d=$1
    mkdir -p "$d" \
        && git -C "$d" init -q -b main \
        && git -C "$d" config user.email test@invalid \
        && git -C "$d" config user.name vendir-check-test \
        || harness_die "mkrepo: repo setup failed for '$d'"
    printf '%s' "$d"
}
# The .git probe is deliberate, not just a non-empty check: `git -C ""` is
# documented as a no-op (falls back to CWD), so an empty arg would otherwise
# `add -A` whatever repo the suite happens to sit in.
commit_all() {
    [ -n "${1:-}" ] && [ -d "$1/.git" ] \
        || harness_die "commit_all: '${1:-}' is not a fixture repo"
    git -C "$1" add -A \
        || harness_die "commit_all: git add failed in $1"
    git -C "$1" commit -qm "${2:-fixture}" >/dev/null \
        || harness_die "commit_all: git commit failed in $1 — nothing to commit? (an empty fixture voids the committed-state premise)"
}

yml_head() {
    cat <<'EOF'
apiVersion: vendir.k14s.io/v1alpha1
kind: Config
minimumRequiredVersion: 0.46.2
directories:
EOF
}
# dir_entry <dest-path> <url> <ref>
dir_entry() {
    cat <<EOF
- path: $1
  contents:
  - path: .
    git:
      url: $2
      ref: $3
      depth: 0
      skipInitSubmodules: true
    legalPaths: []
EOF
}
lock_head() {
    cat <<'EOF'
apiVersion: vendir.k14s.io/v1alpha1
kind: LockConfig
directories:
EOF
}
# lock_entry <dest-path> <sha>
lock_entry() {
    cat <<EOF
- path: $1
  contents:
  - path: .
    git:
      sha: $2
EOF
}
# edit <file> <sed args...> — portable in-place edit (BSD/GNU sed differ on -i).
edit() {
    local f=$1
    shift
    sed "$@" "$f" > "$f.tmp" && mv "$f.tmp" "$f" \
        || harness_die "edit: sed failed on $f"
}

# — shared upstream — one local repo every file:// fixture resolves against.
UP=$T/upstream
mkrepo "$UP" >/dev/null
printf 'upstream bytes v1\n' > "$UP/file.txt"
mkdir -p "$UP/sub"
printf 'nested\n' > "$UP/sub/nested.txt"
commit_all "$UP" v1
SHA_A=$(git -C "$UP" rev-parse HEAD)
git -C "$UP" tag -a -m release v9.9.9
printf 'upstream bytes v2\n' > "$UP/file.txt"
commit_all "$UP" v2
SHA_B=$(git -C "$UP" rev-parse HEAD)
git -C "$UP" tag light
URL=file://$UP

# — allowlist — the committed (HEAD) vendir.yml, one mutation per case, so
# the only finding is the mutation under test. The baseline comes from
# `git show` — a dirty working-tree edit mustn't leak into the fixture and
# make these cases pass or fail for the wrong reason. ——————————————————————

# A foreign top-level key — vendir drops unknown keys silently, so the
# allowlist is the only place a typo'd key can surface.
CUR=$(mkrepo "$T/fx-al-foreign")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
printf 'bogusKey: true\n' >> "$CUR/vendir.yml"
commit_all "$CUR"
it allowlist-foreign-key 1 allowlist
has 'bogusKey'

# A url outside the three pinned upstreams.
CUR=$(mkrepo "$T/fx-al-url")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
edit "$CUR/vendir.yml" 's|apple/swift-crypto|evil/repo|'
commit_all "$CUR"
it allowlist-foreign-url 1 allowlist
has 'evil/repo'

# A destination outside the five declared paths.
CUR=$(mkrepo "$T/fx-al-path")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
edit "$CUR/vendir.yml" 's|path: Sources/Shared/swift-crypto|path: Sources/evil|'
commit_all "$CUR"
it allowlist-bad-path 1 allowlist
has 'Sources/evil'

# The version floor is required present (its value is CI's pin, not this
# check's).
CUR=$(mkrepo "$T/fx-al-floor")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
edit "$CUR/vendir.yml" '/^minimumRequiredVersion/d'
commit_all "$CUR"
it allowlist-missing-floor 1 allowlist
has 'minimumRequiredVersion'

# Repeated mapping keys are spec-invalid — the gate rejects rather than pick
# which duplicate wins.
CUR=$(mkrepo "$T/fx-al-dup")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
printf 'kind: Config\n' >> "$CUR/vendir.yml"
commit_all "$CUR"
it allowlist-duplicate-key 1 allowlist
has 'repeated'

# A `<<:` merge key — invisible to explode(.) (it resolves into the merged
# fields), which is exactly why keys are scanned un-exploded.
CUR=$(mkrepo "$T/fx-al-merge")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
printf '<<: {merged: 1}\n' >> "$CUR/vendir.yml"
commit_all "$CUR"
it allowlist-merge-key 1 allowlist
has '<<'

# Malformed committed YAML is couldn't-run, not a finding.
CUR=$(mkrepo "$T/fx-al-malformed")
printf 'x: [1,2\n' > "$CUR/vendir.yml"
commit_all "$CUR"
it allowlist-malformed 2 allowlist
has 'malformed YAML'

# A config with no directories: at all — nothing to scan, couldn't-run.
CUR=$(mkrepo "$T/fx-al-nodirs")
printf 'apiVersion: vendir.k14s.io/v1alpha1\nkind: Config\nminimumRequiredVersion: 0.46.2\n' \
    > "$CUR/vendir.yml"
commit_all "$CUR"
it allowlist-no-directories 2 allowlist
has 'directories'

# — resolve — fixtures point at the file:// upstream; the lock's sha decides
# green vs finding. FILEPROTO widens the transport allowlist per case (the
# suite must never widen it process-wide — the insteadOf-rewrite fixture
# relies on file:// urls still being audit-visible).
FILEPROTO=VENDIR_CHECK_ALLOW_PROTOCOLS=file:https

# Green: annotated tag v9.9.9 peels to commit $SHA_A = lock.
CUR=$(mkrepo "$T/fx-res-green")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-green 0 resolve
has 'resolve: ok'

# Moved-tag shape: ref still resolves, but the lock pins the other commit.
CUR=$(mkrepo "$T/fx-res-moved")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_B"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-moved-tag 1 resolve
has 'resolves to'

# A branch name queries nothing under refs/tags/ — an unsynced ref edit
# fails named.
CUR=$(mkrepo "$T/fx-res-branch")
{ yml_head; dir_entry dest/one "$URL" main; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-branch-ref 1 resolve
has 'resolves to nothing'

# An unreachable remote is couldn't-verify (exit 2), never drift.
CUR=$(mkrepo "$T/fx-res-dead")
{ yml_head; dir_entry dest/one file://$T/nonexistent v9.9.9; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-unreachable 2 resolve
has 'ls-remote failed'

# Two directories sharing (url, ref) cache to one probe — but a bad shared
# ref must still fail BOTH by name, not one.
CUR=$(mkrepo "$T/fx-res-shared")
{ yml_head; dir_entry dest/aaa "$URL" bogus-tag; dir_entry dest/bbb "$URL" bogus-tag; } \
    > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/aaa "$SHA_A"; lock_entry dest/bbb "$SHA_A"; } \
    > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-shared-ref-names-all 1 resolve
has 'dest/aaa'
has 'dest/bbb'

# Findings dominate INSIDE a check: one drifted entry plus one unreachable
# entry still exits 1, not 2.
CUR=$(mkrepo "$T/fx-res-dom")
{ yml_head; dir_entry dest/drift "$URL" v9.9.9; dir_entry dest/dead file://$T/nonexistent v9.9.9; } \
    > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/drift "$SHA_B"; lock_entry dest/dead "$SHA_A"; } \
    > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-domination 1 resolve
has 'dest/drift'
has 'dest/dead'

# A 40-hex ref resolves to itself — green only when the lock agrees.
CUR=$(mkrepo "$T/fx-res-hex-green")
{ yml_head; dir_entry dest/one "$URL" "$SHA_A"; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-hex-ref-green 0 resolve
has 'resolve: ok'

CUR=$(mkrepo "$T/fx-res-hex-red")
{ yml_head; dir_entry dest/one "$URL" "$SHA_A"; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_B"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=($FILEPROTO)
it resolve-hex-ref-red 1 resolve

# Missing inputs are couldn't-run: no lock, and no config, each exit 2.
CUR=$(mkrepo "$T/fx-res-nolock")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; } > "$CUR/vendir.yml"
commit_all "$CUR"
it resolve-missing-lock 2 resolve
has 'no vendir.lock.yml'

CUR=$(mkrepo "$T/fx-res-noyml")
{ lock_head; lock_entry dest/one "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
it resolve-missing-yml 2 resolve
has 'no vendir.yml'

# — sync — real vendir against the file:// upstream (vendir is already a
# prerequisite of gate work; T026's workflow installs the pinned binary).
# The fixture is built by an actual `vendir sync`, so red cases are real
# drift shapes, not fabricated porcelain. —————————————————————————————————

if command -v "$VENDIR" >/dev/null 2>&1; then
    CUR=$(mkrepo "$T/fx-sync")
    printf '.vendir-tmp*\n' > "$CUR/.gitignore"
    cat > "$CUR/vendir.yml" <<EOF
apiVersion: vendir.k14s.io/v1alpha1
kind: Config
minimumRequiredVersion: 0.46.2
directories:
- path: vendored/thing
  contents:
  - path: .
    git:
      url: $URL
      ref: v9.9.9
      depth: 1
      skipInitSubmodules: true
    # A bare '**' includePaths would carry the upstream clone's own .git
    # into the destination (an embedded repo — git add records a gitlink
    # and doctor edits vanish from the outer tree). Name real files.
    includePaths:
    - '**/*.txt'
    legalPaths: []
EOF
    # A build failure here is the suite itself not running (a stale vendir,
    # say), not a test verdict — the dependent cases skip instead of the
    # whole suite dying under set -e with vendir's exit code.
    if GIT_ALLOW_PROTOCOL=file "$VENDIR" sync --chdir "$CUR" >"$T/syncbuild.out" 2>&1; then
        commit_all "$CUR" synced

        EXTRA=(VENDIR_CHECK_ALLOW_PROTOCOLS=file:https)
        it sync-green 0 sync
        has 'sync: ok'

        # A synced file modified after the lock — the porcelain read catches it.
        EXTRA=(VENDIR_CHECK_ALLOW_PROTOCOLS=file:https)
        printf 'doctored\n' > "$CUR/vendored/thing/file.txt"
        commit_all "$CUR" doctor
        it sync-red-modified 1 sync
        has 'vendored/thing/file.txt'

        # A committed file inside the managed path that upstream never shipped —
        # the wipe deletes it and porcelain reads the deletion.
        EXTRA=(VENDIR_CHECK_ALLOW_PROTOCOLS=file:https)
        git -C "$CUR" checkout -q HEAD~1 -- vendored/thing/file.txt \
            || harness_die "sync fixture: checkout of synced file failed"
        printf 'not upstream\n' > "$CUR/vendored/thing/extra.txt"
        commit_all "$CUR" extra
        it sync-red-untracked-file 1 sync
        has 'vendored/thing/extra.txt'
    else
        for c in sync-green sync-red-modified sync-red-untracked-file; do
            selskip "$c" "sync fixture build failed — vendir: $(tail -1 "$T/syncbuild.out")"
        done
    fi

    # No committed lock — vendir itself can't proceed: couldn't-run. The
    # fixture needs no synced tree, so it runs even when the build failed.
    CUR=$(mkrepo "$T/fx-sync-nolock")
    { yml_head; dir_entry vendored/thing "$URL" v9.9.9; } > "$CUR/vendir.yml"
    commit_all "$CUR"
    it sync-missing-lock 2 sync
    has 'sync --locked failed'
else
    for c in sync-green sync-red-modified sync-red-untracked-file sync-missing-lock; do
        selskip "$c" "no vendir binary (VENDIR=$VENDIR)"
    done
fi

# — locksha — entries sharing a git.url must share a lock SHA. ———————————————

CUR=$(mkrepo "$T/fx-ls-red")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; dir_entry dest/two "$URL" v9.9.9; } \
    > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; lock_entry dest/two "$SHA_B"; } \
    > "$CUR/vendir.lock.yml"
commit_all "$CUR"
it locksha-split-pin 1 locksha
has 'dest/one'
has 'dest/two'

CUR=$(mkrepo "$T/fx-ls-green")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; dir_entry dest/two "$URL" v9.9.9; } \
    > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; lock_entry dest/two "$SHA_A"; } \
    > "$CUR/vendir.lock.yml"
commit_all "$CUR"
it locksha-green 0 locksha
has 'locksha: ok'

# — ignorepaths — the stub curl below logs every requested URL to
# $CURL_STUB_LOG and prints the first status whose substring in
# $CURL_STUB_MAP matches the URL (default 404). The check resolves curl via
# PATH like any binary, so a prepended stub dir intercepts every probe —
# and the log doubles as the URL-assembly assertion (owner/repo/sha/prefix).
STUBBIN=$T/stubbin
mkdir -p "$STUBBIN"
cat > "$STUBBIN/curl" <<'STUB'
#!/usr/bin/env bash
for last; do :; done
printf '%s\n' "$last" >> "${CURL_STUB_LOG:-/dev/null}"
code=404
if [ -f "${CURL_STUB_MAP:-/dev/null}" ]; then
    while read -r c sub; do
        case "$last" in *"$sub"*) code=$c; break ;; esac
    done < "$CURL_STUB_MAP"
fi
printf '%s' "$code"
STUB
chmod +x "$STUBBIN/curl"

GH=https://github.com/owner/repo
CURLMAP=$T/curl.map
CURLLOG=$T/curl.log
STUBENV=(PATH="$STUBBIN:$PATH" CURL_STUB_MAP="$CURLMAP" CURL_STUB_LOG="$CURLLOG")

# ip_fixture <dir> <yml-tail> — the shared boilerplate: github url, lock sha,
# a committed non-ignored anchor file at dest/.
ip_fixture() {
    local d
    d=$(mkrepo "$1")
    mkdir -p "$d/dest"
    printf 'committed content\n' > "$d/dest/anchor.txt"
    cat > "$d/vendir.yml" <<EOF
apiVersion: vendir.k14s.io/v1alpha1
kind: Config
minimumRequiredVersion: 0.46.2
directories:
- path: dest
  contents:
  - path: .
    git:
      url: $GH
      ref: v9.9.9
      depth: 0
      skipInitSubmodules: true
$2
    legalPaths: []
EOF
    { lock_head; lock_entry dest "$SHA_A"; } > "$d/vendir.lock.yml"
    commit_all "$d"
    printf '%s' "$d"
}

# Green: anchor answers 2xx, the shim entry 404s — and the stub's log proves
# the exact URL assembly (owner/repo, lock SHA, path).
CUR=$(ip_fixture "$T/fx-ip-green" '    ignorePaths:
    - shim.txt')
printf '200 anchor.txt\n' > "$CURLMAP"
: > "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-green 0 ignorepaths
has 'anchor'
log_has "owner/repo/$SHA_A/anchor.txt" 'anchor probe URL wrong'
log_has "owner/repo/$SHA_A/shim.txt" 'entry probe URL wrong'

# The core finding: a file exists upstream at a shim path — the preserved
# local copy would silently shadow it on the next sync.
CUR=$(ip_fixture "$T/fx-ip-shadow" '    ignorePaths:
    - shim.txt')
printf '200 anchor.txt\n200 shim.txt\n' > "$CURLMAP"
: > "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-shadow 1 ignorepaths
has 'silently shadow'

# A dead anchor means the lock SHA/repo can't be verified — every 404 after
# it is meaningless, so entries report couldn't-verify.
CUR=$(ip_fixture "$T/fx-ip-anchor-dead" '    ignorePaths:
    - shim.txt')
printf '404 anchor.txt\n' > "$CURLMAP"
: > "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-anchor-dead 2 ignorepaths
has "can't verify"

# Retry-exhausted status (a persistent 429/5xx after curl's backoff) is
# couldn't-verify — never a pass and never mislabeled drift.
CUR=$(ip_fixture "$T/fx-ip-throttled" '    ignorePaths:
    - shim.txt')
printf '200 anchor.txt\n429 shim.txt\n' > "$CURLMAP"
: > "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-throttled 2 ignorepaths
has "couldn't verify"

# An entry naming a committed directory is a LOCAL finding — vendir
# preserves files only, so the copy would error the next sync. The empty
# stub log proves no network was touched.
CUR=$(mkrepo "$T/fx-ip-dir")
mkdir -p "$CUR/dest/adir"
printf 'x\n' > "$CUR/dest/adir/file.txt"
printf 'committed content\n' > "$CUR/dest/anchor.txt"
cat > "$CUR/vendir.yml" <<EOF
apiVersion: vendir.k14s.io/v1alpha1
kind: Config
minimumRequiredVersion: 0.46.2
directories:
- path: dest
  contents:
  - path: .
    git:
      url: $GH
      ref: v9.9.9
      depth: 0
      skipInitSubmodules: true
    ignorePaths:
    - adir
    legalPaths: []
EOF
{ lock_head; lock_entry dest "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
rm -f "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-committed-dir 1 ignorepaths
has 'names a directory'
log_silent

# A non-GitHub url can't map to a raw. URL — couldn't-verify, not a skip.
CUR=$(mkrepo "$T/fx-ip-nongh")
mkdir -p "$CUR/dest"
printf 'committed content\n' > "$CUR/dest/anchor.txt"
cat > "$CUR/vendir.yml" <<EOF
apiVersion: vendir.k14s.io/v1alpha1
kind: Config
minimumRequiredVersion: 0.46.2
directories:
- path: dest
  contents:
  - path: .
    git:
      url: $URL
      ref: v9.9.9
      depth: 0
      skipInitSubmodules: true
    ignorePaths:
    - shim.txt
    legalPaths: []
EOF
{ lock_head; lock_entry dest "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
EXTRA=("${STUBENV[@]}")
it ignorepaths-non-github 2 ignorepaths
has "isn't a github.com remote"

# A glob-shaped entry can't form a literal probe URL — couldn't-verify.
CUR=$(ip_fixture "$T/fx-ip-glob" '    ignorePaths:
    - "**/shim.txt"')
: > "$CURLMAP"
rm -f "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-glob-entry 2 ignorepaths
has 'literal paths only'

# newRootPath re-roots the fetched tree BEFORE ignorePaths match — entries
# probe at <newRootPath>/<entry>; the stub log asserts the prefix.
CUR=$(ip_fixture "$T/fx-ip-nrp" '    newRootPath: sub
    ignorePaths:
    - shim.txt')
printf '200 anchor.txt\n' > "$CURLMAP"
: > "$CURLLOG"
EXTRA=("${STUBENV[@]}")
it ignorepaths-newrootpath 0 ignorepaths
log_has "owner/repo/$SHA_A/sub/shim.txt" 'probe URL lacks newRootPath prefix'

# — preflight's insteadOf audit — the GIT_CONFIG_GLOBAL fixture carries the
# rewrite; per-case GCFG overrides the suite's empty file. ———————————————————

# A rewrite retargeting the fixture remote's scheme to a blocked transport
# is flagged before any check runs.
CUR=$(mkrepo "$T/fx-io-flagged")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; } > "$CUR/vendir.yml"
{ lock_head; lock_entry dest/one "$SHA_A"; } > "$CUR/vendir.lock.yml"
commit_all "$CUR"
GCFG=$T/gitconfig.rewrite
printf '[url "ssh://git@evil.example/"]\n\tinsteadOf = %s\n' "$URL" > "$GCFG"
EXTRA=(VENDIR_CHECK_ALLOW_PROTOCOLS=file:https)
it insteadof-rewrite-flagged 2 resolve
has 'rewrites'

# A rewrite for an unrelated host doesn't gate.
GCFG=$T/gitconfig.unrelated
printf '[url "ssh://git@evil.example/"]\n\tinsteadOf = file:///somewhere-else\n' > "$GCFG"
EXTRA=($FILEPROTO)
it insteadof-unrelated-ignored 0 resolve
has 'resolve: ok'
GCFG=$GCFG_EMPTY

# — exit-contract cases ————————————————————————————————————————————————

# Findings dominate ACROSS checks: allowlist finds drift while resolve
# can't even run (no lock) — the run still exits 1.
CUR=$(mkrepo "$T/fx-dom-across")
git -C "$REPO" show HEAD:vendir.yml > "$CUR/vendir.yml" \
    || harness_die "git show HEAD:vendir.yml failed"
printf 'bogusKey: true\n' >> "$CUR/vendir.yml"
commit_all "$CUR"
it findings-dominate-across 1 allowlist resolve
has 'bogusKey'

# Nothing found but checks couldn't run — exit 2.
CUR=$(mkrepo "$T/fx-err2")
{ yml_head; dir_entry dest/one "$URL" v9.9.9; } > "$CUR/vendir.yml"
commit_all "$CUR"
it errors-only-exit-2 2 resolve locksha
has 'could not run'

# An unknown check name is usage trouble — exit 2.
it unknown-check 2 bogus-check-name
has 'unknown check'

# VENDIR_CHECK_ROOT must be the repo top level — a subdirectory dies.
CUR=$(mkrepo "$T/fx-subdir")
mkdir -p "$CUR/dest"
printf 'x\n' > "$CUR/dest/marker.txt"
commit_all "$CUR"
CUR=$CUR/dest
it subdir-root-rejected 2 allowlist
has 'top level'

# And a non-repo dies the same way.
CUR=$(mktemp -d "$T/nonrepo.XXXXXX")
it nonrepo-root-rejected 2 allowlist
has 'not inside a git repository'

# — real tree — the committed state of this repository passes. Default is
# the full bare run (same as CI); VENDIR_CHECK_TEST_OFFLINE=1 shrinks the
# leg to the networkless checks for dev runs without connectivity. ————————

CUR=$REPO
if [ "${VENDIR_CHECK_TEST_OFFLINE:-}" = 1 ]; then
    it real-tree-offline 0 allowlist locksha
    has 'allowlist: ok'
    has 'locksha: ok'
elif command -v "$VENDIR" >/dev/null 2>&1; then
    it real-tree 0
    has 'resolve: ok'
    has 'ignorepaths: ok'
else
    selskip real-tree "no vendir binary (VENDIR=$VENDIR) — or set VENDIR_CHECK_TEST_OFFLINE=1"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1
[ "$skip" -eq 0 ] || exit 2
exit 0
