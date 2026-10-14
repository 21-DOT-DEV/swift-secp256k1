#!/usr/bin/env bash
# vendir-check.sh [check ...] — the vendored-tree gate behind
# .github/workflows/vendir-check.yml (lands T020). No arguments runs every
# check that exists, so the gate reproduces outside CI; a workflow step names
# one check per invocation. bash-3.2-safe (macOS /bin/bash): no declare -A,
# no mapfile.
#
# Checks (a bare run uses registry order; final order once T022–T024 land:
#   allowlist resolve sync locksha ignorepaths — insert, never reorder.
#   Explicit args run in the order given and may repeat — args are NOT
#   re-sorted to registry order, so it is the workflow's step order, not
#   $CHECKS, that keeps allowlist first in CI):
#   resolve every committed `ref:` resolves upstream to the SHA the
#           committed lock pins — a ref edit without a re-sync, or a moved
#           tag, fails named. The config↔lock parity check `npm ci` and
#           `cargo --locked` bake into the locked install and vendir skips.
#   sync    `vendir sync --locked` reproduces the committed tree: porcelain
#           over every config-declared destination plus vendir.lock.yml, run
#           in a throwaway worktree of HEAD so vendir's wipe can never touch —
#           or be fooled by — an unclean working tree.
#
# Env:
#   VENDIR_CHECK_ROOT   repo (or T025 fixture dir) under test — checks read
#                       $ROOT/vendir.yml + $ROOT/vendir.lock.yml and run git
#                       against $ROOT. Default: this script's repository.
#   VENDIR              vendir binary — a path or a PATH name (default:
#                       vendir). CI passes its pinned download; a developer
#                       can pin a matching release (a newer vendir may write
#                       a lock CI can't read — AGENTS.md, "Extraction flow").
#                       Resolved only by checks that need it.
#   VENDIR_CHECK_ALLOW_PROTOCOLS
#                       Overrides the GIT_ALLOW_PROTOCOL allowlist below
#                       (default https). T025's file://-remote fixtures widen
#                       it; nothing else should.
#
# Exit — the diff(1) contract: 0 every requested check passed, 1 any check
# reported drift (the tree/config/lock disagree — findings dominate: a
# proven mismatch outranks another check's couldn't-run), 2 no check found
# anything but at least one could not run (usage, missing tool, environment
# trouble). T025's assertions and CI reporting hang off the 1-vs-2 split.
# shellcheck disable=SC2329  # checks are invoked dynamically as "check_$c";
# the helpers are this file's shared library (some are for T022–T024).
set -euo pipefail

# A git-hook environment exports GIT_* vars that silently retarget nested git
# calls at the outer repo (GIT_DIR/GIT_WORK_TREE win over -C). Every repo
# access below must see only $ROOT.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX \
    GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
# Pin everything else a developer's config could skew, for every git call
# below *and* vendir's internal ones: literal pathspecs (a `*`/`:` in a
# managed path can never turn into magic), no opportunistic index writes
# (a read-only status on the live tree mustn't take index.lock mid-edit),
# real file modes, and no hooks — a global core.hooksPath (lefthook) would
# otherwise fire post-checkout inside the scratch worktree.
export GIT_LITERAL_PATHSPECS=1 GIT_OPTIONAL_LOCKS=0
# Never prompt for credentials — a renamed or deleted remote would
# otherwise hang ls-remote on a TTY — and abort a transfer that stalls
# below 1 KB/s for 30 s (BuildBuddy's documented CI defaults) instead of
# hanging until the job's own timeout.
export GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1024 GIT_HTTP_LOW_SPEED_TIME=30
# Transport allowlist: https only, for every git call *and* vendir's own
# fetches — a committed url: could otherwise name file:/ssh:/ext: (ext::
# literally runs its payload as a command). Dedicated override var rather
# than honoring ambient GIT_ALLOW_PROTOCOL, which we treat as hostile env.
export GIT_ALLOW_PROTOCOL="${VENDIR_CHECK_ALLOW_PROTOCOLS:-https}"
export GIT_CONFIG_COUNT=5 \
    GIT_CONFIG_KEY_0=core.fileMode GIT_CONFIG_VALUE_0=true \
    GIT_CONFIG_KEY_1=core.hooksPath GIT_CONFIG_VALUE_1=/dev/null \
    GIT_CONFIG_KEY_2=core.autocrlf GIT_CONFIG_VALUE_2=false \
    GIT_CONFIG_KEY_3=core.fsmonitor GIT_CONFIG_VALUE_3=false \
    GIT_CONFIG_KEY_4=core.untrackedCache GIT_CONFIG_VALUE_4=false

# Same contract as die(), defined first — early-env failures still exit 2.
die0() { echo "error: $*" >&2; exit 2; }

command -v git >/dev/null 2>&1 \
    || die0 "required tool missing: git (xcode-select --install)"

if [ -n "${VENDIR_CHECK_ROOT:-}" ]; then
    ROOT=$(cd "$VENDIR_CHECK_ROOT" 2>/dev/null && pwd -P) \
        || die0 "VENDIR_CHECK_ROOT '$VENDIR_CHECK_ROOT' is not a directory"
else
    ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
fi
# The root must be the repo top level: a subdirectory would make worktree
# add check out the whole *outer* repo, and the check would read the outer
# vendir.yml — verifying the wrong tree without saying so.
# rev-parse first, on its own line: when it fails its empty output would
# make `cd ""` a no-op and the guard could pass by accident.
top=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null) \
    && [ -n "$top" ] \
    || die0 "'$ROOT' is not inside a git repository"
top=$(cd "$top" 2>/dev/null && pwd -P) \
    || die0 "cannot resolve repository top level under '$ROOT'"
[ "$top" = "$ROOT" ] \
    || die0 "VENDIR_CHECK_ROOT must be the repository top level ('$ROOT' is inside '$top')"
VENDIR_YML=$ROOT/vendir.yml
VENDIR_LOCK=$ROOT/vendir.lock.yml
VENDIR=${VENDIR:-vendir}

# Environment/usage/internal trouble — exits 2 so a check that could not run
# never reads as "the tree is wrong" (exit 1 is findings only).
die() {
    echo "error: $*" >&2
    exit 2
}

# Emit an error line: a ::error:: annotation in CI, a plain line locally.
# Workflow-command data escapes % first, then CR/LF — the toolkit's
# escapeData order; `ref:`/`url:` text is PR-controlled, so never emit raw.
_err() {
    local msg=$*
    if [ "${GITHUB_ACTIONS:-}" = true ]; then
        msg=${msg//'%'/'%25'}
        msg=${msg//$'\r'/'%0D'}
        msg=${msg//$'\n'/'%0A'}
        printf '::error::%s\n' "$msg"
    else
        printf 'error: %s\n' "$msg" >&2
    fi
}
# A finding — the tree/config/lock disagree. Never exits: a check lists
# every mismatch it found before returning 1.
fail() { _err "$@"; }
# A check-execution problem inside a check (one entry's transport failed):
# reported the same way, but only drags the check to ERRORED (rc 2) when no
# entry reported drift — findings dominate within a check too.
cerr() { _err "$@"; }

# Status lines are advisory — after SIGHUP closes the terminal a stdout
# write fails, and a bare `note` under set -e would exit 1 (reads as
# drift). Status output can never be allowed to fail the gate.
note() {
    printf '%s\n' "$*" 2>/dev/null || :
}

# Every *value* read from the vendir files goes through explode(.) — a bare
# read prints the `*secp256k1-ref` alias literally (spec 002 §3). Key
# enumeration stays un-exploded so `<<:` merge keys surface (T022). Optional
# second arg reads a different copy — the live files are the default; a
# check asserting committed state passes the worktree's file explicitly.
cfg() {
    yq "explode(.) | $1" "${2:-$VENDIR_YML}"
}
lock() {
    yq "explode(.) | $1" "${2:-$VENDIR_LOCK}"
}

# Each check's tool requirements — the dispatcher preflights the union of the
# requested set so a missing binary is one named error, not a cascade of
# command-not-found exits halfway through a 60s sync. One tool per line — a
# VENDIR path may contain spaces.
check_tools() {
    case "$1" in
        resolve) printf '%s\n' git yq ;;
        sync) printf '%s\n' git yq "$VENDIR" ;;
        *) die "internal: no tool list for check '$1'" ;;
    esac
}

tool_hint() {
    case "$1" in
        *vendir*) echo "brew install carvel-dev/carvel/vendir (or point VENDIR at a binary)" ;;
        yq) echo "brew install yq" ;;
        git) echo "xcode-select --install" ;;
        *) echo "" ;;
    esac
}

# — checks —————————————————————————————————————————————————————————————
# Contract for check_* functions (T022–T024): the dispatcher runs each as a
# foreground subshell in *tested* context (`( check_$c ) || rc=$?`), so
# `set -e` is OFF inside — every step that must abort the check needs its
# own `|| die` or `|| { fail …; return 1; }`. Report findings via fail(),
# per-entry couldn't-verify problems via cerr(), `return 1` on findings,
# `return 2` when only errors occurred. die() mid-check still works (the
# subshell's exit 2 reads the same), and rc 0/1/2 are the whole contract —
# 3–127 means the check broke it (ERRORED, code printed), ≥128 is a signal
# and aborts the run. Signals: the parent records INT/TERM/HUP and exits
# with that code once the check returns; a terminal Ctrl-C reaches the
# whole group, and the subshell's own EXIT trap still cleans its worktree.

# Resolve a vendir git ref to its upstream commit SHA. A 40-hex ref resolves
# to itself — ls-remote lists refs, not raw SHAs. Otherwise query
# refs/tags/<ref> plus its ^{} peel: the peeled line wins, because an
# annotated tag's bare ref line is the tag-*object* SHA and would false-fail
# the lock comparison (spec 002 §3, check 2). Branch names and `origin/…`
# refs match nothing under refs/tags/ — empty output fails the check.
# Prints the SHA; returns 2 on transport failure, 3 when nothing resolved.
resolve_ref() {
    local url=$1 ref=$2 out sha refname tag="" peel=""
    # grep, not [[ =~ ]] — bash 3.2's regex engine mishandles {N} intervals.
    # Uppercase hex is a valid commit-ish; normalize so it compares equal to
    # the lock's lowercase sha.
    if printf '%s' "$ref" | grep -qiE '^[0-9a-f]{40}$'; then
        printf '%s' "$ref" | tr '[:upper:]' '[:lower:]'
        return 0
    fi
    # `--` is load-bearing: a url: starting with '-' would otherwise be
    # parsed as an option (--upload-pack runs a command — CVE-2017-1000117
    # class). GIT_ALLOW_PROTOCOL is the second layer, in the env block.
    # `-C /` pins the probe to the same config layer preflight's rewrite
    # audit and vendir's temp-repo fetches see (system+global+env) — never
    # the caller's cwd repo, whose local rules nobody else consults.
    out=$(git -C / ls-remote -- "$url" "refs/tags/$ref" "refs/tags/$ref^{}") \
        || return 2
    while read -r sha refname; do
        case "$refname" in
            "refs/tags/$ref") tag=$sha ;;
            "refs/tags/$ref^{}") peel=$sha ;;
        esac
    done <<EOF
$out
EOF
    [ -n "${peel:-$tag}" ] || return 3
    printf '%s' "${peel:-$tag}"
}

check_resolve() {
    # Committed state, like the sync — both files come out of HEAD so an
    # uncommitted edit can't move the goalposts.
    local cfg_yml lock_yml
    cfg_yml=$(git -C "$ROOT" show HEAD:vendir.yml 2>/dev/null) \
        || die "HEAD has no vendir.yml (no commits yet?)"
    lock_yml=$(git -C "$ROOT" show HEAD:vendir.lock.yml 2>/dev/null) \
        || die "HEAD has no vendir.lock.yml"

    # Shape check before parsing: a malformed file yields an empty
    # directory list downstream, which the guards there would misreport
    # as "declares no directories".
    printf '%s' "$cfg_yml" | yq 'explode(.) | has("directories") == true' - | grep -qx true \
        || die "committed vendir.yml is malformed YAML or lacks a 'directories' list"
    printf '%s' "$lock_yml" | yq 'explode(.) | has("directories") == true' - | grep -qx true \
        || die "committed vendir.lock.yml is malformed YAML or lacks a 'directories' list"

    # Advisory: the check asserts committed bytes — without this a local
    # "did my ref: bump take?" run silently passes against the old HEAD.
    local live_dirty
    live_dirty=$(git -C "$ROOT" status --porcelain --untracked-files=all -- vendir.yml vendir.lock.yml || true)
    if [ -n "$live_dirty" ]; then
        note "note: uncommitted changes (resolve checks HEAD, not the working tree):"
        printf '%s\n' "$live_dirty"
    fi

    local dirs=() urls=() refs=() counts=() lockpaths=() lockshas=()
    local line rest path url ref ncontents sha i j resolved rc
    # Manual field splits — `IFS=tab read` would collapse an empty middle
    # field into a misaligned row.
    while IFS= read -r line; do
        path=${line%%$'\t'*}; rest=${line#*$'\t'}
        url=${rest%%$'\t'*}; rest=${rest#*$'\t'}
        ref=${rest%%$'\t'*}; ncontents=${rest##*$'\t'}
        dirs+=("$path"); urls+=("$url"); refs+=("$ref"); counts+=("$ncontents")
    done < <(printf '%s' "$cfg_yml" | yq 'explode(.) | .directories[] | [.path, .contents[0].git.url, .contents[0].git.ref, (.contents | length)] | @tsv' -)
    while IFS= read -r line; do
        lockpaths+=("${line%%$'\t'*}"); lockshas+=("${line##*$'\t'}")
    done < <(printf '%s' "$lock_yml" | yq 'explode(.) | .directories[] | [.path, .contents[0].git.sha] | @tsv' -)
    ((${#dirs[@]})) || die "committed vendir.yml declares no directories"

    # Resolved-(url,ref) cache — the three secp256k1 entries share one
    # anchor ref, so probing per entry would triple the network calls and
    # a dead remote would report three identical transport errors. Parallel
    # arrays (no assoc arrays on bash 3.2); the key is length-prefixed so
    # PR-controlled values can't collide by sharing a delimiter. The cache
    # lives here, not in resolve_ref — that function runs inside $( ) and
    # anything it stored would die with the subshell.
    local cache_keys=() cache_rcs=() cache_vals=() cache_paths=() cached key k hit_path
    local found=0 errored=0
    for i in "${!dirs[@]}"; do
        path=${dirs[$i]}; url=${urls[$i]}; ref=${refs[$i]}
        # Shape guard first — a directory with !=1 contents entries is
        # something this check can't fully see (multi-entry policy is
        # T022's allowlist scope); failing named beats a silent skip.
        case "${counts[$i]}" in
            1) ;;
            *) fail "$path — ${counts[$i]} contents entries; resolve covers exactly one per directory (multi-entry is T022 allowlist scope)"; found=1; continue ;;
        esac
        sha=""
        if ((${#lockpaths[@]})); then
            for j in "${!lockpaths[@]}"; do
                if [ "${lockpaths[$j]}" = "$path" ]; then sha=${lockshas[$j]}; break; fi
            done
        fi
        case "$sha" in
            "" | null) fail "$path — no contents[0].git.sha in the lock"; found=1; continue ;;
        esac
        case "$url" in
            "" | null) fail "$path — no contents[0].git.url in the config (non-git contents?)"; found=1; continue ;;
        esac
        key="${#url},${#ref}:$url$ref"; cached=0; resolved=""; rc=0
        if ((${#cache_keys[@]})); then
            for k in "${!cache_keys[@]}"; do
                if [ "${cache_keys[$k]}" = "$key" ]; then
                    rc=${cache_rcs[$k]}; resolved=${cache_vals[$k]}
                    hit_path=${cache_paths[$k]}; cached=1; break
                fi
            done
        fi
        if ((!cached)); then
            resolved=$(resolve_ref "$url" "$ref"); rc=$?
            cache_keys+=("$key"); cache_rcs+=("$rc")
            cache_vals+=("$resolved"); cache_paths+=("$path")
        fi
        case $rc in
            0) ;;
            2) if ((!cached)); then
                   cerr "$path — git ls-remote failed for $url (network or auth trouble) — entry not verified"
               else
                   cerr "$path — same failed lookup as $hit_path (shared url+ref) — not verified"
               fi
               errored=1; continue ;;
            *) if ((!cached)); then
                   fail "$path — ref '$ref' resolves to nothing at $url (tags only; a branch name queries nothing under refs/tags/)"
               else
                   fail "$path — same unresolved ref as $hit_path (shared url+ref '$ref')"
               fi
               found=1; continue ;;
        esac
        printf '%s' "$resolved" | grep -qE '^[0-9a-f]{40}$' \
            || { fail "$path — resolved value '$resolved' is not a full SHA"; found=1; continue; }
        [ "$resolved" = "$sha" ] \
            || { fail "$path — ref '$ref' resolves to $resolved upstream; lock holds $sha — a ref edit without re-sync, or a moved tag"; found=1; }
    done
    # Findings dominate *within* a check too: proven drift outranks another
    # entry's transport failure.
    ((found)) && return 1
    ((errored)) && return 2
    return 0
}

check_sync() {
    local paths=() live_paths=() p wt dirty live vver floor

    # A detached worktree of HEAD: the sync exercises exactly the committed
    # bytes the gate asserts on, and vendir's wipe reaches only the scratch
    # checkout — uncommitted work in the live tree is untouchable.
    wt=$(mktemp -d "${TMPDIR:-/tmp}/vendir-check.XXXXXX") \
        || die "mktemp failed"
    # `worktree remove --force` (the synced tree is dirty, so --force is
    # required) — never `prune --expire now`, which would also reap OTHER
    # worktrees' stale records (a checkout on an unplugged drive dies with
    # it). It deletes only $wt/tree, so the `;` then rm -rf's the mktemp
    # parent — `||` would skip that on success and leak a directory every
    # run. If remove fails, rm -rf still clears the files; the stale admin
    # entry left behind is git's own slow-prune business. The paths are
    # baked into the trap now — `wt` is local and out of scope by the time
    # the EXIT trap fires in the dispatcher's subshell.
    # shellcheck disable=SC2064
    trap "git -C $(printf '%q' "$ROOT") worktree remove --force $(printf '%q' "$wt/tree") 2>/dev/null; rm -rf $(printf '%q' "$wt")" EXIT
    git -C "$ROOT" worktree add --detach --quiet "$wt/tree" HEAD \
        || die "cannot create scratch worktree — is $ROOT a git repository?"

    # Shape check first — a missing or malformed committed config would
    # otherwise fall through to the empty-list message and misreport why.
    cfg 'has("directories") == true' "$wt/tree/vendir.yml" | grep -qx true \
        || die "committed vendir.yml is missing, malformed, or has no 'directories' list"
    # Scope = the destinations the sync actually consumed — read from the
    # worktree's vendir.yml (the committed copy vendir read), never the live
    # file: an uncommitted edit would silently shift the check's coverage.
    while IFS= read -r p; do paths+=("$p"); done \
        < <(cfg '.directories[].path' "$wt/tree/vendir.yml" || true)
    ((${#paths[@]})) \
        || die "committed vendir.yml declares no directories — not a vendir repo?"

    vver=$("$VENDIR" version) \
        || die "'$VENDIR version' failed — point VENDIR at a vendir binary"
    printf '%s\n' "$vver"
    vver=${vver##* }
    # A vendir newer than the declared floor can rewrite the lock's format —
    # flag it now so a red sync isn't misread as upstream drift (AGENTS.md,
    # Extraction flow pins exactly the floor until CI does).
    floor=$(cfg '.minimumRequiredVersion' "$wt/tree/vendir.yml" || true)
    if [ -n "$floor" ] && [ "$floor" != null ] && [ "$vver" != "$floor" ]; then
        note "note: vendir $vver differs from vendir.yml's minimumRequiredVersion $floor"
    fi
    # vendir dumps the whole exploded config to stdout — ~150 lines that
    # bury the check markers. Log it under $wt (freed by the trap) and
    # surface it only when the sync itself fails.
    if ! "$VENDIR" sync --locked --chdir "$wt/tree" >"$wt/vendir.log" 2>&1; then
        cat "$wt/vendir.log" 2>/dev/null
        die "vendir sync --locked failed (output above)"
    fi

    # The tree must match the committed lock deterministically.
    # --untracked-files=all pins the mode — a developer's
    # status.showUntrackedFiles=no would make --ignored=matching a fatal
    # combination, and the flag overrides that config outright. --ignored=
    # matching catches a synced file that matches a .gitignore pattern (a
    # plain porcelain read is blind to it); vendir.lock.yml is in scope
    # because --locked still rewrites its `tags:` field (carvel-dev/
    # vendir#403) — red there with no config change means upstream retagged.
    dirty=$(git -C "$wt/tree" status --porcelain --untracked-files=all --ignored=matching -- "${paths[@]}" vendir.lock.yml) \
        || die "git status failed in the scratch worktree"
    if [ -n "$dirty" ]; then
        fail "sync --locked changed the committed state:"
        printf '%s\n' "$dirty"
        return 1
    fi

    # Advisory only: uncommitted edits in the live tree are not part of this
    # check — the gate asserts committed state — but surface them anyway so a
    # local run still shows the drift it deliberately skipped. Live paths
    # come from the live config; vendir.yml/vendir.lock.yml are in scope so
    # an uncommitted config edit (say, a `ref:` bump not yet synced) shows
    # too. Divergence from the synced set means vendir.yml itself is edited
    # and the committed set was what ran.
    while IFS= read -r p; do live_paths+=("$p"); done < <(cfg '.directories[].path' || true)
    if ((${#live_paths[@]})); then
        live=$(git -C "$ROOT" status --porcelain --untracked-files=all -- "${live_paths[@]}" vendir.yml vendir.lock.yml || true)
        if [ -n "$live" ]; then
            note "note: uncommitted changes in vendored paths (not checked — sync ran on HEAD):"
            printf '%s\n' "$live"
        fi
        [ "${paths[*]}" = "${live_paths[*]}" ] \
            || note "note: vendir.yml's directory list differs from HEAD's — the committed set was checked"
    fi
}

# — dispatch ———————————————————————————————————————————————————————————

usage() {
    cat <<EOF
usage: vendir-check.sh [check ...]

With no arguments, runs every check that exists — the same gate
.github/workflows/vendir-check.yml runs per named step.
Checks (current): $CHECKS

Env: VENDIR_CHECK_ROOT  repo/fixture under test (default: this repo)
     VENDIR             vendir binary (default: vendir on PATH)
     VENDIR_CHECK_ALLOW_PROTOCOLS  git transport allowlist (default: https)
EOF
}

# Checks that exist, in run order.
CHECKS="resolve sync"

# Map an insteadOf replacement base to its transport protocol — fail-closed
# (unclassifiable → non-zero): scheme:// → scheme, transport:: → transport,
# scp-style [user@]host:path → ssh, a path → file. Composite transports
# like git+ssh normalize to their inner protocol.
classify_url_base() {
    local rep=$1 scheme
    case "$rep" in
        *://*) scheme=${rep%%://*} ;;
        *::*)  scheme=${rep%%::*} ;;
        *:*)   scheme=ssh ;;  # scp-style [user@]host:path
        *)     scheme= ;;
    esac
    if [ -z "$scheme" ]; then
        if [ "${rep#*/}" != "$rep" ] || [ "${rep#~}" != "$rep" ]; then
            scheme="file"  # contains / or leads with ~ — a path
        else
            return 1
        fi
    fi
    case "$scheme" in git+ssh|ssh+git) scheme=ssh ;; esac
    printf '%s' "$scheme"
}

preflight() {
    local tools=() uniq=() missing=() c t hint bad=0
    for c in "$@"; do
        while IFS= read -r t; do tools+=("$t"); done < <(check_tools "$c")
    done
    ((${#tools[@]})) || return 0
    while IFS= read -r t; do uniq+=("$t"); done < <(printf '%s\n' "${tools[@]}" | sort -u)
    for t in "${uniq[@]}"; do
        if ! command -v "$t" >/dev/null 2>&1; then
            missing+=("$t")
        elif [ "$t" = yq ]; then
            # Identity *and* a v4 floor: apt's python-yq parses explode(.)
            # as a different query language, and a future yq v5 could move
            # explode/@tsv semantics — either would silently mislead a
            # config read rather than fail.
            case "$(yq --version 2>&1)" in
                *"version v4."*) ;;
                *mikefarah*) fail "yq is mikefarah/yq but not v4.x — CI's image ships v4"; bad=1 ;;
                *) fail "yq on PATH is not mikefarah/yq — install: brew install yq"; bad=1 ;;
            esac
        fi
    done
    if ((${#missing[@]})); then
        while IFS= read -r t; do
            hint=$(tool_hint "$t")
            fail "required tool missing: $t${hint:+ — install: $hint}"
        done < <(printf '%s\n' "${missing[@]}" | sort -u)
        bad=1
    fi
    # url.<base>.insteadOf rewrites (a common ~/.gitconfig maps
    # https://github.com/ to ssh) redirect every probe to a protocol the
    # allowlist blocks — failing 'transport not allowed' in a way that
    # reads as a network outage on every run. Audit the layer the calls
    # actually see: vendir fetches from its own temp repo and ls-remote
    # runs with -C /, so both see only system+global(+env) — never $ROOT's
    # or the caller's repo-local rules. Flag only a rule whose matched
    # prefix hits a committed url: — an unrelated rewrite mustn't gate.
    # --get-regexp -z: one NUL record per rule, key\nvalue — the
    # replacement base lives in the KEY (url.<base>.insteadof).
    local committed_urls rule repkey rep orig scheme u
    committed_urls=$(git -C "$ROOT" show HEAD:vendir.yml 2>/dev/null \
        | yq 'explode(.) | .directories[].contents[].git.url' - 2>/dev/null || true)
    while IFS= read -r -d '' rule; do
        repkey=${rule%%$'\n'*}; rep=${repkey#url.}; rep=${rep%.insteadof}
        orig=${rule#*$'\n'}
        # Fail closed on anything unclassifiable — a guess is worse than
        # a flag, and the scheme feeds a protocol-allowlist decision.
        scheme=$(classify_url_base "$rep") \
            || { fail "git config rule '$repkey' rewrites to '$rep' — can't classify its protocol; refusing to guess"; bad=1; continue; }
        # RFC scheme chars only — the classification feeds a glob pattern in
        # the membership test, so a metachar base like '*://x' would pattern-
        # match its way to allowed; it isn't a protocol git speaks anyway.
        printf '%s' "$scheme" | grep -qiE '^[a-z][a-z0-9+.-]*$' \
            || { fail "git config rule '$repkey' rewrites to '$rep' — '$scheme' is not a usable protocol name; refusing to guess"; bad=1; continue; }
        case ":$GIT_ALLOW_PROTOCOL:" in *":$scheme:"*) continue ;; esac
        [ -n "$orig" ] || continue  # an empty insteadOf value matches nothing
        while IFS= read -r u; do
            if [ "${u:0:${#orig}}" = "$orig" ]; then
                fail "git config '$repkey' rewrites committed url '$u' to '$scheme' — blocked by GIT_ALLOW_PROTOCOL ($GIT_ALLOW_PROTOCOL); widen VENDIR_CHECK_ALLOW_PROTOCOLS or remove the rule"
                bad=1; break
            fi
        done <<< "$committed_urls"
    done < <(git -C / config --get-regexp -z '^url\..*\.insteadof$' 2>/dev/null || true)
    return "$bad"
}

main() {
    case "${1:-}" in -h | --help) usage; exit 0 ;; esac

    local c rc sig failed="" errored=""
    # shellcheck disable=SC2086 # $CHECKS is a literal word list — splitting is the point.
    if [ $# -eq 0 ]; then set -- $CHECKS; fi
    for c; do
        case " $CHECKS " in
            *" $c "*) ;;
            *) die "unknown check '$c' (available: $CHECKS)" ;;
        esac
    done
    preflight "$@" || exit 2
    # Foreground checks + record-the-signal traps. A terminal Ctrl-C hits
    # the whole process group — the check subshell dies on its own default
    # disposition and bash runs its EXIT trap, so the scratch worktree is
    # still cleaned — while the parent's traps only record the code so the
    # run exits with it once the check returns. The residual delay: a
    # signal sent to the parent PID alone (kill, or a CI cancel's SIGINT)
    # waits until the current check returns — bounded; CI escalates to
    # SIGKILL anyway. Do NOT background the checks under job control: a
    # background pgrp that touches the terminal (a stdin read, or
    # `stty tostop`) stops dead and `wait` hangs forever.
    sig=""
    trap 'sig=129' HUP
    trap 'sig=130' INT
    trap 'sig=143' TERM
    for c; do
        [ -z "$sig" ] || exit "$sig"
        note "==> $c"
        rc=0
        ( "check_$c" ) || rc=$?
        [ -z "$sig" ] || { note "    $c: interrupted" 2>/dev/null || true; exit "$sig"; }
        case "$rc" in
            0) note "    $c: ok" ;;
            1) failed="${failed:+$failed }$c"; note "    $c: FAILED" ;;
            2) errored="${errored:+$errored }$c"; note "    $c: ERRORED" ;;
            *) if [ "$rc" -ge 128 ]; then
                   note "    $c: killed (signal $((rc - 128))) — aborting run"
                   exit "$rc"
               fi
               errored="${errored:+$errored }$c"
               note "    $c: ERRORED (exited $rc — outside the 0/1/2 check contract)" ;;
        esac
    done
    # Findings dominate trouble: a check that proved drift says something
    # certain about the tree — a check that merely couldn't run does not.
    # Print both lists; exit 2 only when nothing produced a finding.
    if [ -n "$failed" ] || [ -n "$errored" ]; then
        local msg=${failed:+failed check(s): $failed}
        [ -z "$errored" ] || msg="${msg:+$msg; }could not run: $errored"
        echo "error: $msg" >&2
        [ -z "$failed" ] || exit 1
        exit 2
    fi
    exit 0
}

main "$@"
