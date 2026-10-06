---
adr: 0001
title: Shared sources are copied into both targets by a build plugin, not symlinked
status: Accepted
date: 2025-12-08
supersedes: []
superseded_by: null
---

# 0001 — Shared sources are copied into both targets by a build plugin, not symlinked

## Context

`P256K` and `ZKP` share roughly forty files under `Sources/Shared/` — including
the extracted swift-crypto sources — and that set needed one source of truth.
The first mechanism was directory symlinks inside each target's source tree:
it worked on macOS, broke on Linux and in Docker images, and forced `Projects/`
(Tuist) to maintain twenty-plus file-level symlinks.

## Decision

An SPM build-tool plugin (`Plugins/SharedSourcesPlugin`, a `prebuildCommand`)
copies every `.swift` file from `Sources/Shared/` — flattened, because plugin
output directories do not recursively include subdirectories — into each of the
two targets' build directories before compilation. The plugin uses POSIX
`find` + `cp` rather than `rsync`, which Linux container images do not ship.
`Projects/` keeps consolidated *directory* symlinks, which are macOS-only and
therefore acceptable there.

## Alternatives considered and rejected

- **Directory symlinks**: the status quo — platform-fragile and unmaintainable
  at file granularity under Tuist.
- **Manual duplication**: guaranteed drift between the two product lines.
- **A plugin executable built from this package**: SPM does not allow prebuild
  commands to run executables built from the same package; discovered
  mid-implementation, this killed the first design.
- **`rsync`**: not present in the Docker/Linux build images.

## Consequences

`Sources/Shared/` is the single source of truth; editing it affects both
products, which is the intended ZKP-first workflow (prototype in `ZKP`, promote
to `P256K`). Copying over symlinking was confirmed again on 2026-04-27 for an
unrelated reason: `swift-symbolgraph-extract` records the symlink path, not its
target, so plugin-output symlinks would leave every `Shared/` source link in
the released DocC archives broken — the repair lives downstream in
`Scripts/rewrite-docc-shared-paths.swift`, run by `docc-release.yml`. Windows
support remains deferred. The plugin is scoped to this repository and is not a
published product.
