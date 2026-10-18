#!/usr/bin/env bash
# vendir-check.sh [check ...] — the vendored-tree gate behind
# .github/workflows/vendir-check.yml. No arguments runs every
# check that exists, so the gate reproduces outside CI; a workflow step names
# one check per invocation. bash-3.2-safe (macOS /bin/bash): no declare -A,
# no mapfile.
#
# Checks (a bare run uses registry order — allowlist resolve sync locksha
#   ignorepaths — insert, never reorder. Explicit args run in the order
#   given and may repeat — args are NOT re-sorted to registry order, so it
#   is the workflow's step order, not $CHECKS, that keeps allowlist first
#   in CI):
#   allowlist committed vendir.yml confined to the used key set at every
#           mapping level (read un-exploded so `<<:` merge keys surface —
#           and repeated keys fail too, since parsers disagree on which
#           duplicate wins), `url:`/`directories[].path` pinned to the
#           declared sets, one git: contents per directory. vendir drops
#           unknown keys silently, so a typo'd excludePath: would sync
#           green with nothing downstream able to tell.
#   resolve every committed `ref:` resolves upstream to the SHA the
#           committed lock pins — a ref edit without a re-sync, or a moved
#           tag, fails named. The config↔lock parity check `npm ci` and
#           `cargo --locked` bake into the locked install and vendir skips.
#   sync    `vendir sync --locked` reproduces the committed tree: porcelain
#           over every config-declared destination plus vendir.lock.yml, run
#           in a throwaway worktree of HEAD so vendir's wipe can never touch —
#           or be fooled by — an unclean working tree.
#   locksha entries sharing a git.url keep equal lock SHAs — a literal
#           typed in place of a shared-ref alias (like &secp256k1-ref)
#           survives a ref bump as a split pin, so the finding names
#           every member of the group with its SHA and the likely cause.
#   ignorepaths
#           every declared ignorePaths entry stays absent upstream at the
#           locked SHA — a future upstream file there would be silently
#           shadowed by the preserved local copy (CopyExistingFiles writes
#           destination bytes over fetched ones — after newRootPath
#           re-roots, so entries probe at <newRootPath>/<entry>). Probes
#           hit raw.githubusercontent.com: an exact 404 passes, a 2xx is
#           a finding, anything else after curl's retried backoff is
#           couldn't-verify — never a pass. Before entries, one "anchor"
#           probe on a committed, non-ignored file proves the SHA/repo/
#           URL-mapping answers at all — a dead pin 404s identically to
#           an absent file, and today's correct answer IS all-404s, so
#           only the anchor keeps that green honest. A local ls-tree
#           pass (no network) runs first: an entry naming a committed
#           directory is a named finding — vendir's copyFile errors the
#           next sync on it. The flakiest check by design (live HTTP to
#           upstream), so it trails the registry — one revert never
#           touches the core.
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
# the helpers are this file's shared library.
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
# enumeration stays un-exploded so `<<:` merge keys surface (the allowlist
# check relies on it). Optional second arg reads a different copy — the live
# files are the default; a check asserting committed state passes the
# worktree's file explicitly.
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
        allowlist) printf '%s\n' git yq ;;
        resolve) printf '%s\n' git yq ;;
        sync) printf '%s\n' git yq "$VENDIR" ;;
        locksha) printf '%s\n' git yq ;;
        ignorepaths) printf '%s\n' git yq curl ;;
        *) die "internal: no tool list for check '$1'" ;;
    esac
}

tool_hint() {
    case "$1" in
        *vendir*) echo "brew install carvel-dev/carvel/vendir (or point VENDIR at a binary)" ;;
        yq) echo "brew install yq" ;;
        git) echo "xcode-select --install" ;;
        curl) echo "preinstalled on macOS and the CI image — brew install curl if missing" ;;
        *) echo "" ;;
    esac
}

# — checks —————————————————————————————————————————————————————————————
# Contract for check_* functions: the dispatcher runs each as a
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

# Probe one node's shape, then enumerate its mapping keys against the
# level's allowed set — accumulating into the caller's found/errored
# locals via bash dynamic scope (the caller must declare them), and
# leaving the node's type tag in the caller's _KT so it can decide
# whether to descend. Shape semantics (spec 002 §3, check 1, as
# amended): absent (null) is skipped — the missing-field findings are
# resolve's territory; a present non-map node is a finding, not an
# error — the check ran and proved a violation. Keys are enumerated
# UN-exploded on purpose: explode(.) resolves `<<:` merge keys into
# their source's fields and hides them, while the literal `<<` is itself
# a foreign key. Repeated keys fail too — YAML 1.2 makes mapping keys a
# unique set, and parsers disagree on which duplicate wins (yamllint's
# key-duplicates rule), so the gate rejects rather than picks a side —
# the winner yq picks here is not necessarily the winner vendir's own
# parser picks. Keys are read by index and matched with `=` equality —
# a substring match would let a crafted key like `ref depth` borrow the
# boundary between two allowed names, and a line-oriented read would
# silently drop an empty-string key. Reads $cfg_yml through dynamic
# scope — the caller's local holds the committed bytes. Never exits;
# always returns 0.
keyscan() {
    local q=$1 label=$2 allowed=$3 nkeys i j k a ok
    local klist=()
    _KT=$(printf '%s' "$cfg_yml" | yq "$q | type" - 2>/dev/null) || _KT=
    case "$_KT" in
        '!!map') ;;
        '!!null') return 0 ;;
        '') cerr "$label — type probe failed (node skipped)"; errored=1; return 0 ;;
        *) fail "$label is a $_KT, not a mapping"; found=1; return 0 ;;
    esac
    nkeys=$(printf '%s' "$cfg_yml" | yq "$q | keys | length" -) \
        || { cerr "$label — key enumeration failed (node skipped)"; errored=1; return 0; }
    for ((i = 0; i < nkeys; i++)); do
        # Append in both paths — klist stays index-aligned for the dup
        # loop below even when a read fails (a failed read is cerr, not a
        # foreign-key finding: we couldn't see the key).
        if k=$(printf '%s' "$cfg_yml" | yq "$q | keys | .[$i]" -); then
            ok=0
            for a in $allowed; do  # word-split — the list is literals
                [ "$k" = "$a" ] && { ok=1; break; }
            done
            [ "$ok" = 1 ] \
                || { fail "$label — key '$k' is outside the allowed set ($allowed)"; found=1; }
        else
            cerr "$label — key read failed at index $i"; errored=1; k=''
        fi
        klist+=("$k")
    done
    # Repeated keys — pairwise because a key containing a newline would
    # garble a line-oriented uniq; n per level is tiny. An empty klist[i]
    # marks a failed read above — skipped, not a dup candidate (a real
    # empty-string key is already flagged foreign by the membership pass).
    for ((i = 0; i < nkeys; i++)); do
        [ -n "${klist[$i]}" ] || continue
        for ((j = 0; j < i; j++)); do
            if [ "${klist[$i]}" = "${klist[$j]}" ]; then
                fail "$label — key '${klist[$i]}' is repeated (duplicate keys are spec-invalid; which wins is parser-defined)"
                found=1
                break
            fi
        done
    done
    return 0
}

check_allowlist() {
    # Committed state, like resolve and sync — the gate asserts HEAD, not
    # the working tree.
    local cfg_yml found=0 errored=0 _KT
    cfg_yml=$(git -C "$ROOT" show HEAD:vendir.yml 2>/dev/null) \
        || die "HEAD has no vendir.yml (no commits yet?)"

    # Advisory, like resolve — the verdict reads HEAD.
    local live_dirty
    live_dirty=$(git -C "$ROOT" status --porcelain --untracked-files=all -- vendir.yml || true)
    if [ -n "$live_dirty" ]; then
        note "note: uncommitted changes (allowlist checks HEAD, not the working tree):"
        printf '%s\n' "$live_dirty"
    fi

    # Unparseable committed YAML is couldn't-run — nothing exists to
    # enumerate (the same split resolve makes); parseable-but-wrong-shaped
    # nodes are findings below, since the check ran and proved a violation.
    printf '%s' "$cfg_yml" | yq '.' - >/dev/null 2>&1 \
        || die "committed vendir.yml is malformed YAML"
    local t
    t=$(printf '%s' "$cfg_yml" | yq '. | type' -) \
        || die "type probe failed on committed vendir.yml's document root"
    [ "$t" = '!!map' ] \
        || { fail "vendir.yml's document root is a $t, not a mapping"; return 1; }
    keyscan '.' 'top level' 'apiVersion kind minimumRequiredVersion directories'

    # — pinned values that don't depend on directories: —
    # apiVersion/kind are the schema's identity, not data — a changed pair
    # silently redefines what every key below means.
    t=$(printf '%s' "$cfg_yml" | yq 'explode(.) | .apiVersion + " " + .kind' - 2>/dev/null || true)
    [ "$t" = 'vendir.k14s.io/v1alpha1 Config' ] \
        || { fail "apiVersion/kind is '$t' — expected 'vendir.k14s.io/v1alpha1 Config'"; found=1; }
    # The version floor must exist — without it vendir never refuses an
    # older binary. Its value is not pinned here: the workflow pins the
    # binary, and a floor bump stays a two-file change.
    t=$(printf '%s' "$cfg_yml" | yq 'explode(.) | .minimumRequiredVersion' - 2>/dev/null || true)
    case "$t" in
        '' | null) fail "minimumRequiredVersion is missing or empty — vendir's own version floor needs it"; found=1 ;;
    esac

    # Absent subject = couldn't-run (resolve reads it identically): a
    # missing, null, or empty directories: leaves nothing to enumerate, and
    # the per-directory pins below would just restate the same absence as
    # misleading per-path findings — so they're skipped too. A present
    # non-list directories: is a finding: definitively wrong, and the
    # shape probe proved it.
    local ndirs=0 dirs_ok=0
    t=$(printf '%s' "$cfg_yml" | yq '.directories | type' - 2>/dev/null) || t=
    case "$t" in
        '!!seq')
            if ndirs=$(printf '%s' "$cfg_yml" | yq '.directories | length' -); then
                if [ "$ndirs" -gt 0 ] 2>/dev/null; then
                    dirs_ok=1
                elif [ "$ndirs" = 0 ]; then
                    cerr "committed vendir.yml declares zero directories — nothing to scan"
                    errored=1
                else
                    cerr "committed vendir.yml — 'directories' length probe returned '$ndirs'"
                    errored=1
                fi
            else
                cerr "committed vendir.yml — 'directories' length probe failed"
                errored=1
            fi
            ;;
        '!!null') cerr "committed vendir.yml declares no 'directories' list — nothing to scan"; errored=1 ;;
        '') cerr "committed vendir.yml — 'directories' type probe failed"; errored=1 ;;
        *) fail "committed vendir.yml's directories is a $t, not a list"; found=1 ;;
    esac
    [ "$dirs_ok" = 1 ] || {
        ((found)) && return 1
        return 2
    }

    # Per-node scans. Structure queries (type/length/keys) stay un-exploded
    # — the raw document is what key-conflicts hide in; value reads
    # (path/url) go through explode(.) per the file's convention.
    local all_dir='path contents'
    local all_contents='path git includePaths excludePaths legalPaths ignorePaths newRootPath'
    local all_git='url ref depth skipInitSubmodules'
    local allowed_urls='https://github.com/apple/swift-crypto https://github.com/bitcoin-core/secp256k1'
    local dirpaths=() i j ncontents ctype dpath dlabel cpath url ok u
    for ((i = 0; i < ndirs; i++)); do
        dlabel="directories[$i]"
        keyscan ".directories[$i]" "$dlabel" "$all_dir"
        [ "$_KT" = '!!map' ] || continue
        dpath=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].path" -) \
            || { cerr "$dlabel — path read failed (entry skipped)"; errored=1; continue; }
        case "$dpath" in
            '' | null) fail "$dlabel has no usable path value"; found=1 ;;
            *) dirpaths+=("$dpath"); dlabel="'$dpath'" ;;
        esac

        ctype=$(printf '%s' "$cfg_yml" | yq ".directories[$i].contents | type" - 2>/dev/null) || ctype=
        ncontents=0
        case "$ctype" in
            '!!seq')
                ncontents=$(printf '%s' "$cfg_yml" | yq ".directories[$i].contents | length" -) \
                    || { cerr "$dlabel — contents length probe failed (entry skipped)"; errored=1; continue; }
                ;;
            '!!null') ;;  # absent — the count below reports it
            '') cerr "$dlabel — contents type probe failed (entry skipped)"; errored=1; continue ;;
            *) fail "$dlabel contents is a $ctype, not a list"; found=1; continue ;;
        esac
        [ "$ncontents" = 1 ] \
            || { fail "$dlabel — $ncontents contents entries; exactly one git: contents per directory"; found=1; }
        for ((j = 0; j < ncontents; j++)); do
            keyscan ".directories[$i].contents[$j]" "$dlabel contents[$j]" "$all_contents"
            [ "$_KT" = '!!map' ] || continue
            cpath=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[$j].path" -) \
                || { cerr "$dlabel contents[$j] — path read failed"; errored=1; continue; }
            [ "$cpath" = '.' ] \
                || { fail "$dlabel contents[$j].path is '$cpath', not '.' — a contents entry must own its destination root"; found=1; }
            keyscan ".directories[$i].contents[$j].git" "$dlabel contents[$j].git" "$all_git"
            [ "$_KT" = '!!map' ] || continue  # absent git: — resolve names the missing url:
            url=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[$j].git.url" -) \
                || { cerr "$dlabel contents[$j].git — url read failed"; errored=1; continue; }
            case "$url" in
                '' | null) ;;  # absent url: — resolve names the missing field
                *)
                    # `=` equality, not a substring match — a url joining
                    # two allowed names with a space can't borrow their
                    # boundary.
                    ok=0
                    for u in $allowed_urls; do
                        [ "$url" = "$u" ] && { ok=1; break; }
                    done
                    [ "$ok" = 1 ] \
                        || { fail "$dlabel — git.url '$url' is outside the two declared upstreams"; found=1; }
                    ;;
            esac
        done
    done

    # Destination set — `=` equality in both directions. Counting
    # occurrences also catches a duplicated destination, which a
    # sort|comm diff would only show as an unexplained surplus.
    local expected_paths='Projects/Resources/WycheproofTests/secp256k1 Projects/Sources/libsecp256k1Tests Sources/P256K/swift-crypto Sources/libsecp256k1'
    local ep seen
    for t in ${dirpaths[@]+"${dirpaths[@]}"}; do
        ok=0
        for ep in $expected_paths; do
            [ "$t" = "$ep" ] && { ok=1; break; }
        done
        [ "$ok" = 1 ] \
            || { fail "unexpected directories[].path '$t' — outside the four declared destinations"; found=1; }
    done
    for ep in $expected_paths; do
        seen=0
        for t in ${dirpaths[@]+"${dirpaths[@]}"}; do
            [ "$t" = "$ep" ] && seen=$((seen + 1))
        done
        case "$seen" in
            1) ;;
            0) fail "declared destination '$ep' has no directories[] entry"; found=1 ;;
            *) fail "declared destination '$ep' appears in $seen directories[] entries"; found=1 ;;
        esac
    done
    ((found)) && return 1
    ((errored)) && return 2
    return 0
}

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
        # something this check can't fully see (allowlist asserts exactly
        # one per directory); failing named beats a silent skip.
        case "${counts[$i]}" in
            1) ;;
            *) fail "$path — ${counts[$i]} contents entries; resolve covers exactly one per directory (allowlist asserts the same)"; found=1; continue ;;
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
            resolved=$(resolve_ref "$url" "$ref") || rc=$?  # || keeps set -e off it
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
    # Extraction flow — CI pins exactly the floor).
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

check_locksha() {
    # Committed state, like its siblings — both files out of HEAD.
    local cfg_yml lock_yml
    cfg_yml=$(git -C "$ROOT" show HEAD:vendir.yml 2>/dev/null) \
        || die "HEAD has no vendir.yml (no commits yet?)"
    lock_yml=$(git -C "$ROOT" show HEAD:vendir.lock.yml 2>/dev/null) \
        || die "HEAD has no vendir.lock.yml"

    # Malformed or list-less committed files are couldn't-run — resolve's
    # split: findings are for proven violations, not unreadable inputs.
    printf '%s' "$cfg_yml" | yq 'explode(.) | has("directories") == true' - | grep -qx true \
        || die "committed vendir.yml is malformed YAML or lacks a 'directories' list"
    printf '%s' "$lock_yml" | yq 'explode(.) | has("directories") == true' - | grep -qx true \
        || die "committed vendir.lock.yml is malformed YAML or lacks a 'directories' list"

    # Advisory — the verdict reads HEAD, so surface an unsynced local
    # edit rather than let it read as the checked state.
    local live_dirty
    live_dirty=$(git -C "$ROOT" status --porcelain --untracked-files=all -- vendir.yml vendir.lock.yml || true)
    if [ -n "$live_dirty" ]; then
        note "note: uncommitted changes (locksha checks HEAD, not the working tree):"
        printf '%s\n' "$live_dirty"
    fi

    local dirs=() urls=() counts=() lockpaths=() lockshas=()
    local line rest path url ncontents sha i j
    # Manual field splits — `IFS=tab read` would collapse an empty middle
    # field into a misaligned row (resolve's idiom). The length read comes
    # BEFORE the [0] index — yq materializes a null element for a missing
    # index, so an absent or empty `contents` would read as length 1 and
    # slip past the count guard into a misleading "no url" finding.
    while IFS= read -r line; do
        path=${line%%$'\t'*}; rest=${line#*$'\t'}
        ncontents=${rest%%$'\t'*}; url=${rest##*$'\t'}
        dirs+=("$path"); urls+=("$url"); counts+=("$ncontents")
    done < <(printf '%s' "$cfg_yml" | yq 'explode(.) | .directories[] | [.path, (.contents | length), .contents[0].git.url] | @tsv' -)
    while IFS= read -r line; do
        lockpaths+=("${line%%$'\t'*}"); lockshas+=("${line##*$'\t'}")
    done < <(printf '%s' "$lock_yml" | yq 'explode(.) | .directories[] | [.path, .contents[0].git.sha] | @tsv' -)
    ((${#dirs[@]})) || die "committed vendir.yml declares no directories"

    # Entries that fail their own shape guards are findings and stay out
    # of the groups below — a broken entry mustn't seed a fake second
    # divergence in its url group.
    local vpaths=() vurls=() vshas=() found=0
    for i in "${!dirs[@]}"; do
        path=${dirs[$i]}; url=${urls[$i]}
        case "${counts[$i]}" in
            1) ;;
            *) fail "$path — ${counts[$i]} contents entries; locksha covers exactly one per directory (allowlist asserts the same)"; found=1; continue ;;
        esac
        case "$url" in
            "" | null) fail "$path — no contents[0].git.url in the config (non-git contents?)"; found=1; continue ;;
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
        vpaths+=("$path"); vurls+=("$url"); vshas+=("$sha")
    done

    # One report per shared upstream, led by the url's first-seen entry so
    # a group isn't listed once per member. The finding names every member
    # with its SHA — the reader sees which entry split — plus the cause
    # that most often produces this: a YAML alias (like &secp256k1-ref)
    # typed out as a literal and left behind by a ref bump. n is four;
    # O(n²) scans keep the bash-3.2 parallel arrays readable.
    local leader mismatched base detail
    if ((${#vpaths[@]})); then
        for i in "${!vpaths[@]}"; do
            url=${vurls[$i]}
            leader=1
            for ((j = 0; j < i; j++)); do
                [ "${vurls[$j]}" = "$url" ] && { leader=0; break; }
            done
            ((leader)) || continue
            detail=""; base=${vshas[$i]}; mismatched=0
            for j in "${!vpaths[@]}"; do
                [ "${vurls[$j]}" = "$url" ] || continue
                detail="${detail:+$detail }${vpaths[$j]}=${vshas[$j]}"
                [ "${vshas[$j]}" = "$base" ] || mismatched=1
            done
            if ((mismatched)); then
                fail "entries sharing url $url lock different commits ($detail) — an entry that should share the group's ref was likely typed as a literal where a YAML alias (like &secp256k1-ref) belongs and left behind on a ref bump; restore the shared ref and re-sync"
                found=1
            fi
        done
    fi
    ((found)) && return 1
    return 0
}

# GET a raw.githubusercontent.com URL, print the final response code
# (000 when curl never got one), and let the caller's case decide. Retries
# are curl's own: --retry gives the spec's 429/5xx exponential backoff and
# honors a Retry-After header if one ever arrives — raw. throttles
# anonymous runner IPs with a header-less 429, so bounded backoff is the
# whole answer — while --retry-all-errors widens the retryable set to
# every transport error (timeout, refused, TLS). Each attempt caps at
# --max-time, the retry window at --retry-max-time.
# The `--` is belt-and-suspenders, same as resolve's ls-remote: every
# argument curl sees must parse as positional even if a future caller
# hands this a `-`-leading URL.
probe_code() {
    local url=$1 code
    # `|| :` — a failed curl still writes its code (000 on no response);
    # the printed code, not curl's exit status, is the evidence.
    code=$(curl -sSL -o /dev/null -w '%{http_code}' \
        --connect-timeout 10 --max-time 30 \
        --retry 4 --retry-all-errors --retry-max-time 60 \
        -- "$url" 2>/dev/null) || :
    printf '%s' "${code:-000}"
}

# Can $1 be probed as a literal path under owner/repo/sha? Two failure
# tiers so the caller keeps distinct causes:
#   1  a doublestar glob char or URL-unsafe byte — vendir treats
#      ignorePaths entries as patterns (isPathIgnored, staging_dir.go),
#      so a glob reaches upstream paths no single URL does; a ? # space
#      or % would corrupt, truncate, or double-decode the request into a
#      false 404; " < > | ^ ` ] } and tab are bytes a raw URL can't carry
#      honestly either.
#   2  not a clean relative path — curl strips . and .. segments unless
#      --path-as-is (a src/./x entry probes as src/x while vendir would
#      never match it), and a leading/trailing slash or empty segment
#      collapses the same way.
# Empty/null lands in tier 2: callers that name the case check it first.
probeable_path() {
    case "$1" in "" | null) return 2 ;; esac
    if printf '%s' "$1" | grep -qF -e '*' -e '?' -e '[' -e '{' -e "\\" \
        || printf '%s' "$1" | grep -qF -e '#' -e ' ' -e '%' -e '"' \
            -e '<' -e '>' -e '|' -e '^' -e '`' -e ']' -e '}' \
            -e "$(printf '\t')"; then
        return 1
    fi
    case "$1" in
        /* | */ | */../* | ../* | */.. | .. | ./* | . | */./* | */. | *//*) return 2 ;;
    esac
    return 0
}

check_ignorepaths() {
    # Committed state, like its siblings — both files out of HEAD.
    local cfg_yml lock_yml
    cfg_yml=$(git -C "$ROOT" show HEAD:vendir.yml 2>/dev/null) \
        || die "HEAD has no vendir.yml (no commits yet?)"
    lock_yml=$(git -C "$ROOT" show HEAD:vendir.lock.yml 2>/dev/null) \
        || die "HEAD has no vendir.lock.yml"

    # Malformed or list-less committed files are couldn't-run (resolve's
    # split): findings are for proven violations, not unreadable inputs.
    printf '%s' "$cfg_yml" | yq 'explode(.) | has("directories") == true' - | grep -qx true \
        || die "committed vendir.yml is malformed YAML or lacks a 'directories' list"
    printf '%s' "$lock_yml" | yq 'explode(.) | has("directories") == true' - | grep -qx true \
        || die "committed vendir.lock.yml is malformed YAML or lacks a 'directories' list"

    # Advisory — the verdict reads HEAD, so surface an unsynced local
    # edit rather than let it read as the checked state.
    local live_dirty
    live_dirty=$(git -C "$ROOT" status --porcelain --untracked-files=all -- vendir.yml vendir.lock.yml || true)
    if [ -n "$live_dirty" ]; then
        note "note: uncommitted changes (ignorepaths checks HEAD, not the working tree):"
        printf '%s\n' "$live_dirty"
    fi

    local dirs=() urls=() counts=() lockpaths=() lockshas=()
    local line rest path url ncontents sha i j
    # locksha's TSV idiom: the length read comes BEFORE the [0] index so an
    # absent or empty `contents` can't read as length 1 and slip the guard.
    while IFS= read -r line; do
        path=${line%%$'\t'*}; rest=${line#*$'\t'}
        ncontents=${rest%%$'\t'*}; url=${rest##*$'\t'}
        dirs+=("$path"); urls+=("$url"); counts+=("$ncontents")
    done < <(printf '%s' "$cfg_yml" | yq 'explode(.) | .directories[] | [.path, (.contents | length), .contents[0].git.url] | @tsv' -)
    while IFS= read -r line; do
        lockpaths+=("${line%%$'\t'*}"); lockshas+=("${line##*$'\t'}")
    done < <(printf '%s' "$lock_yml" | yq 'explode(.) | .directories[] | [.path, .contents[0].git.sha] | @tsv' -)
    ((${#dirs[@]})) || die "committed vendir.yml declares no directories"

    # Every declared ignorePaths entry gets probed — no dedup: a shared
    # (url, sha, entry) still names each of its directories in turn, the
    # same "name every affected path" contract resolve's cache keeps.
    local found=0 errored=0 itype ip status rc
    local cpath nrp ntype prefix lt ltype cand anchor
    local entries=() toprobe=()
    for i in "${!dirs[@]}"; do
        path=${dirs[$i]}; url=${urls[$i]}
        case "${counts[$i]}" in
            1) ;;
            *) fail "$path — ${counts[$i]} contents entries; ignorepaths covers exactly one per directory (allowlist asserts the same)"; found=1; continue ;;
        esac
        case "$url" in
            "" | null) fail "$path — no contents[0].git.url in the config (non-git contents?)"; found=1; continue ;;
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
        # The probe is GitHub-only. A url: outside github.com can't form a
        # raw.githubusercontent.com URL — couldn't-verify that entry, never
        # a silent pass (allowlist pins the two github.com upstreams).
        # The https, git@, and ssh:// spellings all reduce to owner/repo —
        # `?*/?*` requires non-empty segments (a bare `*` would swallow an
        # empty one) — and a trailing `.git`, the standard git spelling, is
        # stripped for the probe. Subpaths, a trailing slash, spaces, or a
        # `%` would assemble a wrong URL that 404s into a false pass.
        local rel
        case "$url" in
            https://github.com/?*/?*)     rel=${url#https://github.com/} ;;
            http://github.com/?*/?*)      rel=${url#http://github.com/} ;;
            git@github.com:?*/?*)         rel=${url#git@github.com:} ;;
            ssh://git@github.com/?*/?*)   rel=${url#ssh://git@github.com/} ;;
            *) cerr "$path — git.url '$url' isn't a github.com remote this check can map to a raw URL"; errored=1; continue ;;
        esac
        rel=${rel%.git}
        case "$rel" in
            */*/* | */ | *' '* | *%*)
                cerr "$path — git.url '$url' isn't a clean owner/repo; can't form a raw.githubusercontent.com URL"
                errored=1; continue ;;
        esac

        # contents[].path positions the fetched tree inside the
        # destination, and entries are patterns against THAT subtree —
        # CopyExistingFiles walks <dir>/<contents.path> (staging_dir.go).
        # '.' is the only value whose upstream coordinate is
        # newRootPath/<entry>; anything else is a dir-level
        # couldn't-verify (allowlist fails it too, but this check runs
        # standalone). A missing path is a shape violation like the rest.
        cpath=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[0].path" - 2>/dev/null) || cpath=
        case "$cpath" in
            .) ;;
            "" | null) fail "$path — no contents[0].path in the config"; found=1; continue ;;
            *) cerr "$path — contents[0].path is '$cpath', not '.' — entries under a contents subdir can't be mapped to an upstream path"; errored=1; continue ;;
        esac
        # newRootPath re-roots the fetched tree BEFORE ignorePaths match —
        # NewSubPath().Extract runs ahead of CopyExistingFiles
        # (directory.go, staging_dir.go; vendir.yml's own note records the
        # opposite ordering for includePaths), so the upstream coordinate
        # is <newRootPath>/<entry>. It feeds the URL like an entry: same
        # guards, and a bad one is a dir-level couldn't-verify — never a
        # silent repo-root probe that 404s into a false pass.
        ntype=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[0].newRootPath | type" - 2>/dev/null) || ntype=
        nrp=""
        case "$ntype" in
            '!!null') ;;
            '!!str') nrp=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[0].newRootPath" - 2>/dev/null) || nrp= ;;
            '') cerr "$path — newRootPath type probe failed (entry skipped)"; errored=1; continue ;;
            *) fail "$path — contents[0].newRootPath is a $ntype, not a string"; found=1; continue ;;
        esac
        if [ -n "$nrp" ]; then
            rc=0; probeable_path "$nrp" || rc=$?  # || keeps set -e off it
            case "$rc" in
                0) ;;
                1) cerr "$path — newRootPath '$nrp' is a pattern or URL-hostile; can't form a probe URL"; errored=1; continue ;;
                *) cerr "$path — newRootPath '$nrp' isn't a clean relative path"; errored=1; continue ;;
            esac
        fi
        prefix=${nrp:+$nrp/}

        # Shape guard before enumerating — a present non-list ignorePaths
        # is a proven violation, a finding like allowlist's shape checks;
        # absent (null) is the common case and skips cleanly.
        itype=$(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[0].ignorePaths | type" - 2>/dev/null) || itype=
        case "$itype" in
            '!!null') continue ;;
            '!!seq') ;;
            '') cerr "$path — ignorePaths type probe failed (entry skipped)"; errored=1; continue ;;
            *) fail "$path — contents[0].ignorePaths is a $itype, not a list"; found=1; continue ;;
        esac

        # Local pass first — it needs no network, so a proven finding
        # surfaces even when raw. is unreachable. vendir's Walk visits
        # directories and copyFile errors on one (staging_dir.go), so an
        # entry naming a committed dir — or a gitlink, an empty dir in the
        # worktree — breaks the next sync. That's a finding, not
        # couldn't-verify: the check DID verify. The lookup path is
        # <dir>/<entry> — destination-relative, never newRootPath-
        # prefixed: ignorePaths match the re-rooted tree, and the
        # re-rooted tree IS the destination; only the upstream URL takes
        # the prefix. No committed file is a note, not a red — vendir
        # tolerates a dead entry ("reserved for a shim to come"), but the
        # upstream check still matters: it guards the future shadow.
        entries=(); toprobe=()
        while IFS= read -r ip; do entries+=("$ip"); done \
            < <(printf '%s' "$cfg_yml" | yq "explode(.) | .directories[$i].contents[0].ignorePaths[]" -)
        ((${#entries[@]})) || continue
        for ip in "${entries[@]}"; do
            case "$ip" in
                "" | null) cerr "$path — empty ignorePaths entry; nothing to probe"; errored=1; continue ;;
            esac
            rc=0; probeable_path "$ip" || rc=$?  # || keeps set -e off it
            case "$rc" in
                0) ;;
                1) cerr "$path — ignorePaths entry '$ip' is a pattern or URL-hostile; the check probes literal paths only"
                   errored=1; continue ;;
                *) cerr "$path — ignorePaths entry '$ip' isn't a clean relative path"
                   errored=1; continue ;;
            esac
            lt=$(git -C "$ROOT" ls-tree HEAD -- "$path/$ip" 2>/dev/null || true)
            lt=${lt%%$'\n'*}; ltype=${lt#* }; ltype=${ltype%% *}
            case "$ltype" in
                tree)   fail "$path — ignorePaths entry '$ip' names a directory in the committed tree — vendir preserves files only; copying it would error the next sync"; found=1; continue ;;
                commit) fail "$path — ignorePaths entry '$ip' names a gitlink (a submodule — an empty dir in the worktree) — vendir preserves files only"; found=1; continue ;;
                blob) ;;
                "")     note "    $path — '$ip': nothing committed there (dead entry — reserved or stale); probed anyway" ;;
            esac
            toprobe+=("$ip")
        done
        ((${#toprobe[@]})) || continue

        # Anchor — a string of 404s only means "absent" if the same URL
        # builder returns 2xx for a file that exists. Pick a committed
        # file outside the ignore list (a committed non-ignored file is
        # upstream-sourced by definition) through the SAME prefix: a dead
        # pin, a moved repo, or a wrong mapping all 404 into
        # couldn't-verify instead of a false green. Caveat: GitHub serves
        # any commit in a repo's fork network at this URL, so a passing
        # anchor proves reachability through owner/repo — not that the
        # commit ever sat on that repo's own branches. No usable anchor
        # means the dir's SHA can't be anchored — couldn't-verify.
        anchor=""
        while IFS= read -r line; do
            ltype=${line#* }; ltype=${ltype%% *}
            [ "$ltype" = blob ] || continue
            cand=${line#*$'\t'}
            cand=${cand#"$path"/}  # repo-root-relative → contents-relative
            for ip in "${entries[@]}"; do [ "$cand" = "$ip" ] && continue 2; done
            probeable_path "$cand" || continue
            anchor=$cand; break
        done < <(git -C "$ROOT" ls-tree -r HEAD -- "$path" 2>/dev/null)
        case "$anchor" in
            "") cerr "$path — no committed file outside the ignore list to anchor on; couldn't verify $rel@$sha exists upstream (entry probes skipped)"; errored=1; continue ;;
        esac
        status=$(probe_code "https://raw.githubusercontent.com/$rel/$sha/$prefix$anchor")
        case "$status" in
            2??) note "    $path — anchor $prefix$anchor verified at ${sha:0:12}… (HTTP $status)" ;;
            *) cerr "$path — anchor '$anchor' at $rel@$sha returned HTTP $status — can't verify the lock SHA exists upstream; entry probes skipped"; errored=1; continue ;;
        esac

        for ip in "${toprobe[@]}"; do
            status=$(probe_code "https://raw.githubusercontent.com/$rel/$sha/$prefix$ip")
            case "$status" in
                404) note "    $path — $ip: absent upstream at ${sha:0:12}… (404)" ;;
                2??) fail "$path — '$ip' exists upstream at $rel@$sha${prefix:+ as \"$prefix$ip\"} (HTTP $status) — the preserved local copy would silently shadow it on the next sync"; found=1 ;;
                *) cerr "$path — probe of '$ip' at $rel@$sha returned HTTP $status after retries — couldn't verify absence"; errored=1 ;;
            esac
        done
    done
    # Findings dominate within a check: a proven shadow outranks another
    # entry's probe failure.
    ((found)) && return 1
    ((errored)) && return 2
    return 0
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
CHECKS="allowlist resolve sync locksha ignorepaths"

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
    # Run it only when a requested check fetches over git — today resolve
    # and sync (ignorepaths probes raw.githubusercontent.com over HTTPS via
    # curl, which git's url-rewrites never reach) — so an https→ssh rule
    # can't gate the offline checks.
    local fetch=0
    for c in "$@"; do
        case "$c" in resolve | sync) fetch=1 ;; esac
    done
    ((fetch)) || return "$bad"
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

    local c rc sig failed="" errored="" known ok
    # shellcheck disable=SC2086 # $CHECKS is a literal word list — splitting is the point.
    if [ $# -eq 0 ]; then set -- $CHECKS; fi
    for c; do
        ok=0
        for known in $CHECKS; do
            [ "$c" = "$known" ] && { ok=1; break; }
        done
        [ "$ok" = 1 ] || die "unknown check '$c' (available: $CHECKS)"
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
