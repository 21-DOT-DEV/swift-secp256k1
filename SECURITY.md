# Security Policy

## Reporting a Vulnerability

To report a security vulnerability in swift-secp256k1, either:
- send an email to `security@21.dev`, or
- use [GitHub Security Advisories](https://github.com/21-DOT-DEV/swift-secp256k1/security/advisories).

**Do not file a public issue.**

When reporting, please include:

- A description of the vulnerability
- Steps to reproduce or a proof of concept
- Potential impact assessment

We will acknowledge receipt within 7 days and provide an initial assessment as soon as possible.

## Supported Versions

This package is pre-1.0 ([SemVer major version zero](https://semver.org/#spec-item-4)). Only the latest minor release receives security fixes.

| Version | Supported          |
|---------|--------------------|
| 0.25.x  | :white_check_mark: |
| < 0.25  | :x:                |

`0.23.x` — including `0.23.2`, the last release with the zkp modules — receives no security fixes; pin it only until a dedicated zkp package ships.

## Upstream Dependencies

This package wraps [libsecp256k1](https://github.com/bitcoin-core/secp256k1) via Swift's C interoperability.

Vulnerabilities in the underlying C library should be reported directly to its project:

- **libsecp256k1**: See [bitcoin-core/secp256k1 SECURITY.md](https://github.com/bitcoin-core/secp256k1/blob/master/SECURITY.md)

Releases `0.20.0` through `0.23.2` also embedded [libsecp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp); vulnerabilities in that library should be reported to the BlockstreamResearch project.

## Published Security Advisories

Published advisories follow a fixed format so readers always find the same
information in the same place:

- **Summary** — what breaks, on which versions, at what severity.
- **Details** — the root cause, with the vulnerable code excerpt.
- **PoC** — a minimal reproduction.
- **Impact** — what an attacker (or a legitimate caller) can and cannot achieve.
- **Patches** — the first fixed release.
- **Workarounds** — how to stay safe without upgrading, or an explicit "none".

Affected versions use GitHub Advisory Database range syntax (`= 0.25.0`, `>= 0.24.0, < 0.25.0`), never bare version numbers.

Every advisory cross-links its fix end to end: the advisory's references point
to the fix pull request, the merge commit, and the patched release tag; the
fix's pull request and the changelog entry name the advisory's
`GHSA-xxxx-xxxx-xxxx` identifier. Publication waits for the merge commit and
release tag to exist so every link is live on day one.

Maintainers request a CVE through the draft advisory's **Request CVE** button
before publishing. Reporters are credited by name in the advisory body and in
GitHub's credits field.
