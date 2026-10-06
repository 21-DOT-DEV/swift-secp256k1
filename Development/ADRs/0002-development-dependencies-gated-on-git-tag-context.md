---
adr: 0002
title: Development dependencies are gated on git-tag context in Package.swift
status: Accepted
date: 2026-04-16
supersedes: []
superseded_by: null
---

# 0002 — Development dependencies are gated on git-tag context in Package.swift

## Context

The root manifest needs heavyweight development tooling — SwiftFormat,
SwiftLint, Tuist, SourceKitten, the subtree and DocC plugins, and friends — for
contributor workflows. Declared unconditionally, every one of those packages
resolves transitively for downstream consumers of a library whose headline
property is zero runtime dependencies.

## Decision

`Package.swift` branches on `Context.gitInformation?.currentTag`: at tagged
releases the development dependencies are excluded, so consumers resolve none
of the dev tree; in a non-tagged development checkout they are present, so
format, lint, Tuist, and plugin commands work as documented.

## Alternatives considered and rejected

- **Unconditional dev dependencies**: every consumer transitively resolves the
  tooling — the failure mode this exists to prevent.
- **A separate tools package for contributor workflows**: correct for CI-only
  tools (see `Development/Tools`), wrong for workflows like the lefthook
  format/lint plugins that must run against this package's sources.
- **Dropping the dev tooling**: loses the format/lint/subtree/DocC gates the
  project depends on.

## Consequences

Consumers get zero transitive development dependencies. The cost is that
format, lint, Tuist, and plugin commands only work in a non-tagged checkout —
a deliberate trade, documented in `AGENTS.md`.
