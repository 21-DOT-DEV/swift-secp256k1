# Security Policy

## Reporting a Vulnerability

To report a security vulnerability in swift-secp256k1, please use [GitHub Security Advisories](https://github.com/21-DOT-DEV/swift-secp256k1/security/advisories).

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
| 0.22.x  | :white_check_mark: |
| < 0.22  | :x:                |

## Upstream Dependencies

This package wraps [libsecp256k1](https://github.com/bitcoin-core/secp256k1) and [libsecp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp) via Swift's C interoperability.

Vulnerabilities in the underlying C libraries should be reported directly to their respective projects:

- **libsecp256k1**: See [bitcoin-core/secp256k1 SECURITY.md](https://github.com/bitcoin-core/secp256k1/blob/master/SECURITY.md)
- **libsecp256k1-zkp**: See [BlockstreamResearch/secp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp)
