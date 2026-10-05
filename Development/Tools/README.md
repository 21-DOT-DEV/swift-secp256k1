# Tools

A Swift package of its own, separate from the one at the repository root.

It holds `plans`, which reads the `key: value` block at the top of every
`../Specs/*/plan.md` and `../ADRs/*.md`, checks it, and regenerates the index
tables in `../Specs/README.md` and `../ADRs/README.md`. That is what keeps a
feature's status in exactly one place.

```sh
swift run  --package-path Development/Tools plans           # rewrite the index tables
swift run  --package-path Development/Tools plans --check   # fail if stale or invalid
swift test --package-path Development/Tools                 # unit tests
```

**Why a second manifest.** SwiftPM has no way to mark a target as
development-only, so declaring this in the root manifest would pull the project's
development dependencies — SourceKitten, Tuist, SwiftLint, swift-syntax and the
rest, the ones the root manifest already hides behind its tagged-release check —
into every run of a documentation check. This package takes two small
dependencies instead and resolves, builds and tests in about twenty seconds
from cold.

**Why swift-yaml rather than parsing by hand.** An earlier version read the
`key: value` block itself. It worked, but it accepted a misspelled field silently:
`adr:` where `adrs:` was meant simply never arrived, and nothing reported it.
`Schema.swift` now declares the shape as Swift types and refuses any field it does
not know, which is stricter than either the hand-written version or a plain
decode. Two behaviours were checked rather than assumed: `feature: 002` keeps its
leading zeros, and `updated: 2026-08-31` stays text instead of becoming a date, so
neither needs quoting in the files.

**Why swift-argument-parser for one flag.** The command line used to test whether
the string `--check` was present and ignore everything else, so `--chekc` ran in
rewrite mode and printed the same success line. A typo in automation would have
turned this check into a step that verified nothing and still reported green. The
parser refuses what it does not recognise, and `Command.swift` lives in the
library rather than the executable so that behaviour is covered by tests instead
of only by running the binary.

swift-yaml is pinned to a commit because it publishes no tagged release;
swift-argument-parser is pinned by version. swift-yaml needs C++ interoperability
mode, which every target here therefore uses; that spreads no further, because
this package is not a dependency of the root one.
