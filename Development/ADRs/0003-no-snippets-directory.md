---
adr: 0003
title: No Snippets/ directory — SwiftPM auto-discovery cannot scope snippet dependencies
status: Accepted
date: 2026-04-24
supersedes: []
superseded_by: null
---

# 0003 — No Snippets/ directory

## Context

SwiftPM auto-discovers a `Snippets/` directory (SE-0356) and links every library
product of the package into each snippet's executable. This package ships two
C-binding products, `libsecp256k1` and `libsecp256k1_zkp`, compiled from the
same upstream source tree — so any snippet fails at link time with duplicate C
symbols.

## Decision

Ship no `Snippets/` directory. Documentation examples live as fenced ` ```swift`
blocks inside the DocC catalog articles. The parked snippet sources from prior
DocC work are retained outside the repository for re-integration once SwiftPM
supports scoping snippet dependencies to specific products.

## Alternatives considered and rejected

- **Keep snippets**: produces a permanently red link step — the duplicate
  symbols are structural, not fixable in the package.
- **Scoped snippet dependencies**: the remedy SE-0356 names but SwiftPM has
  not shipped.
- **Exclude one C product from snippet linking**: no mechanism exists; every
  product links into every snippet.

## Consequences

Documentation examples are verified by review rather than by the snippet build
system. Re-evaluate when scoped snippet dependencies land in SwiftPM.
