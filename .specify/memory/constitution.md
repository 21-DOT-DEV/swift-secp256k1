<!--
Sync Impact Report:
- Version: N/A → 1.0.0 (Initial constitution)
- Change Type: Initial creation
- Scope: swift-secp256k1 monorepo (/Users/csjones/Developer/swift-secp256k1)
- Structure: Two-tier (7 core principles + implementation practices in nested format)
- Core Principles:
  I. Scope & Bitcoin Standards Alignment
  II. Cryptographic Correctness
  III. Key & Secret Handling
  IV. API Design & Safety
  V. Spec-First & Test-Driven Development
  VI. Cross-Platform CI & Quality Gates
  VII. Open Source Excellence
- Enforcement: Three-tier model (MUST/SHOULD/MAY) with explicit MUST NOT
- Governance: BDFL model with security-relevant change protocols
- Compliance: Continuous CI + event-driven strategic review
- Templates Status:
  ⚠ spec-template.md - Requires alignment review
  ⚠ plan-template.md - Requires alignment review
  ⚠ tasks-template.md - Requires alignment review
  ⚠ checklist-template.md - Requires alignment review
- Follow-up TODOs:
  • Create CONTRIBUTING.md with Projects folder workflow details
  • Create SECURITY.md with vulnerability disclosure process
-->

# Constitution for swift-secp256k1

## Preamble

This constitution governs the **swift-secp256k1** package, a Swift wrapper around libsecp256k1 providing elliptic curve cryptography for Bitcoin.

**Scope**: This repository only. Covers both `P256K` (primary) and `ZKP` (experimental extension) product lines, plus their underlying C bindings (`libsecp256k1`, `libsecp256k1_zkp`).

**Philosophy**: Principles are technology-agnostic where possible. This is a zero-dependency cryptographic library—security, correctness, and simplicity take precedence over features.

---

## Core Principles

### I. Scope & Bitcoin Standards Alignment

**Statement**: The package MUST focus exclusively on elliptic-curve cryptography for Bitcoin: secp256k1 ECDSA, Schnorr, ECDH, and related primitives, with libsecp256k1 as the sole cryptographic primitive source.

**Rationale**: Keeping scope tight reduces complexity and attack surface. Aligning with Bitcoin consensus and wallet standards (BIPs) avoids fragmentation and misuse.

**Practices**:
- **MUST** limit scope to secp256k1 ECDSA, Schnorr signatures, ECDH, MuSig2, and related Bitcoin primitives
- **MUST** align high-level APIs with relevant Bitcoin standards (BIP-340 Schnorr, BIP-327 MuSig2, Taproot usage)
- **MUST** use libsecp256k1 as the sole source of cryptographic primitives
- **MUST** maintain zero runtime dependencies beyond libsecp256k1 bindings
- **MUST NOT** add dependencies without constitutional review and explicit justification
- **MUST NOT** implement novel, unreviewed cryptographic constructions beyond core secp256k1 scope
- **SHOULD** treat `ZKP` product as an experimental extension tier (adaptor signatures, range proofs, etc.)
- **MAY** expose raw bindings for advanced users requiring full control

**Compliance**: PRs adding new primitives or dependencies MUST include justification and constitutional review. CI blocks unapproved additions.

---

### II. Cryptographic Correctness

**Statement**: All primitives MUST be mathematically correct, using vetted algorithms and parameters from libsecp256k1 and recognized cryptographic standards. Implementation safety (constant-time behavior) MUST be preserved.

**Rationale**: Cryptographic correctness is non-negotiable. Leveraging libsecp256k1's battle-tested core reduces the risk of subtle bugs. Timing attacks are practical and have broken production systems.

**Practices**:
- **MUST** preserve constant-time behavior for all operations on secret data (keys, nonces, scalars) wherever libsecp256k1 guarantees it
- **MUST** avoid data-dependent branches and memory access patterns on secrets
- **MUST** validate against published test vectors (BIP-340, libsecp256k1 test vectors, related standards)
- **MUST** validate inputs rigorously and reject invalid curve points, invalid scalars, and malformed encodings
- **MUST** verify correctness of ECC operations against published test vectors
- **MUST NOT** implement custom cryptographic constructions ("don't roll your own crypto")
- **SHOULD** run fuzzing on cryptographic functions via scheduled CI (not every PR)
- **SHOULD** incorporate third-party security reviews for significant changes
- **MAY** add property-based tests for edge cases (covered by test vector validation)

**Compliance**: Test vector validation runs on every PR. Fuzzing runs on schedule. PRs modifying cryptographic code require explicit review.

---

### III. Key & Secret Handling

**Statement**: Private keys, nonces, and other secrets MUST be generated securely, protected during use, zeroed when no longer needed, and never exposed through public APIs except as opaque types.

**Rationale**: Minimizing lifetime and exposure of secrets is fundamental to cryptographic security. Predictable nonces or leaked secrets lead to catastrophic private key recovery.

**Practices**:
- **MUST** generate keys and nonces using cryptographically secure pseudo-random number generators (CSPRNGs)
- **MUST** zero private keys, nonces, and intermediate secrets when no longer needed
- **MUST** hold sensitive data only in memory during processing
- **MUST** expose secrets only as opaque types or secure representations
- **MUST NOT** log private keys, nonces, or intermediate secrets
- **MUST NOT** use predictable or hardcoded nonces
- **MUST NOT** expose secrets in error messages, debug descriptions, or crash reports
- **MUST NOT** store secrets in plaintext at rest
- **SHOULD** encrypt any persisted sensitive data using industry-standard algorithms
- **MAY** provide unsafe escape hatches for expert users, clearly documented as such

**Compliance**: Code review MUST verify secret handling. CI scans for obvious violations (logging patterns, hardcoded values).

---

### IV. API Design & Safety

**Statement**: Public APIs MUST follow a Swift-native, Swift Crypto-inspired design with safe defaults. Advanced operations MUST live behind clearly named, documented unsafe APIs.

**Rationale**: Familiar API design lowers learning curve and reduces misuse. Safe defaults protect typical users while still supporting advanced protocols for experts.

**Practices**:
- **MUST** follow Swift Crypto-inspired naming conventions (e.g., `P256K.Signing.PrivateKey`, `isValidSignature`)
- **MUST** provide safe high-level APIs that generate nonces internally by default
- **MUST** use strongly-typed errors (e.g., invalid encoding, invalid scalar, failed verification)
- **MUST** ensure errors do not leak secret material in descriptions
- **MUST** ensure binary/text representations interoperate cleanly with common ecosystems (Bitcoin Core, BIP key formats, DER, PEM)
- **MUST NOT** expose implementation details that could be misused
- **SHOULD** separate safe high-level APIs from lower-level bindings
- **SHOULD** gate manual nonce control, raw scalars, and unsafe conversions behind explicit "unsafe" naming
- **SHOULD** document all public types and functions
- **MAY** provide convenience methods for common Bitcoin wallet use cases

**Compliance**: Code review enforces API naming conventions and documentation requirements.

---

### V. Spec-First & Test-Driven Development

**Statement**: Every feature MUST start with a specification. All code MUST follow test-driven development: tests written first, verified to fail, then implementation proceeds.

**Rationale**: Specifications ensure alignment with user needs and provide measurable success criteria. TDD prevents regressions, enables confident refactoring, and documents expected behavior.

**Practices - Specification Requirements**:
- **MUST** create `spec.md` for every feature before development
- **MUST** represent a single feature or small subfeature (not multiple unrelated features)
- **MUST** be independently testable (no dependencies on incomplete specs)
- **MUST** define user scenarios, acceptance criteria, and success metrics
- **MUST NOT** combine multiple unrelated features in one spec
- **MUST NOT** describe implementation details instead of user-facing behavior

**Practices - Test-Driven Development**:
- **MUST** write tests before implementation (red → green → refactor)
- **MUST** verify tests fail initially
- **MUST** validate against published test vectors (BIP-340, libsecp256k1, related standards)
- **MUST** maintain separate unit and integration tests
- **SHOULD** run fuzzing via scheduled CI for cryptographic functions
- **SHOULD** develop outside-in (user's perspective first)

**Compliance**: PRs MUST include tests written first. CI blocks merges if tests missing or immediately passing. Specs combining multiple features MUST be rejected in review.

---

### VI. Cross-Platform CI & Quality Gates

**Statement**: The package MUST maintain support for all advertised platforms with CI coverage ensuring features compile and tests pass on each. Behavior MUST be deterministic across environments.

**Rationale**: Cross-platform reliability is a core value proposition. Determinism is critical for testability, reproducibility, and debugging Bitcoin protocol-level issues.

**Practices**:
- **MUST** test across all supported Swift versions and platforms (iOS, macOS, tvOS, watchOS, visionOS, Linux)
- **MUST** test on both Intel and ARM architectures
- **MUST** ensure deterministic behavior: given same inputs, operations produce same outputs across all platforms
- **MUST** pass all unit and integration tests before merge
- **MUST** pass linting checks (SwiftLint, SwiftFormat) before merge
- **MUST NOT** merge code that breaks any supported platform
- **SHOULD** run fuzzing on schedule for cryptographic functions
- **SHOULD** integrate property-based tests for edge cases
- **MAY** provide platform-specific optimizations where beneficial

**Compliance**: CI pipeline enforces all MUST-level gates. Platform failures block merge.

---

### VII. Open Source Excellence

**Statement**: All development MUST follow open source best practices: comprehensive documentation, welcoming contributions, clear licensing, and simplicity over cleverness.

**Rationale**: Good documentation reduces friction. Clear decisions preserve knowledge. Simplicity encourages contributions and reduces maintenance burden.

**Practices**:
- **MUST** document architecture decisions
- **MUST** maintain clear README with setup instructions and usage examples
- **MUST** provide contribution guidelines (CONTRIBUTING.md)
- **MUST** include LICENSE file (MIT)
- **MUST** write clear, human-readable code (readability over cleverness)
- **MUST** apply KISS and DRY principles
- **MUST** document all public APIs with inline comments
- **MUST** include minimal, complete examples for ECDSA, Schnorr, MuSig2, and typical Bitcoin wallet use cases
- **SHOULD** maintain security disclosure process (SECURITY.md)
- **SHOULD** provide issue and PR templates
- **SHOULD** respond to community contributions promptly and respectfully

**Compliance**: PRs MUST include documentation updates for new features or API changes. Code reviews enforce readability.

---

## Implementation Guidance

### Security Disclosure Process

**Statement**: A clear process for reporting vulnerabilities MUST be documented.

**Requirements**:
- **MUST** provide SECURITY.md with reporting instructions
- **MUST** include preferred contact method (email, encrypted if possible)
- **MUST** define expected response timeline (e.g., acknowledgment within 48 hours)
- **MUST** commit to coordinated disclosure timeline
- **SHOULD** provide PGP key for encrypted reports
- **SHOULD** acknowledge reporters in release notes (with permission)

**Security-Relevant Changes**:
- Maintainer MUST document security implications in PR description
- 48-72 hour merge delay for community review opportunity
- Explicit "security-reviewed" label required before merge

---

### Projects Folder Usage

**Purpose**: The `Projects/` folder serves as the integration testing and distribution workspace.

**Designated Uses**:
- Integration testing for new APIs before promotion to `Sources/`
- Running test vector targets
- Fuzzing infrastructure
- XCFramework distribution builds
- CocoaPods support and validation

**Workflow**:
- New APIs may be prototyped and tested in `Projects/` before integration
- `ZKP` serves as the experimental tier; stable APIs promote to `P256K`
- Detailed workflow documented in CONTRIBUTING.md

---

## Technology Stack (Current Implementation)

**Note**: Constitution defines technology-agnostic principles. This section documents current choices, which may change without constitutional amendments.

### Supported Platforms

- **iOS** (arm64)
- **macOS** (arm64, x86_64)
- **tvOS** (arm64)
- **watchOS** (arm64)
- **visionOS** (arm64)
- **Linux** (x86_64, arm64)

### Current Stack (2025-12-02)

**Language**: Swift 6.0+
**C Standard**: C89
**Build**: Swift Package Manager (SPM)
**Testing**: swift-testing, XCTest
**Linting**: SwiftLint, SwiftFormat
**CI**: Bitrise, GitHub Actions

### Products

| Product | Type | Description |
|---------|------|-------------|
| `P256K` | Swift wrapper | Primary high-level API (stable focus) |
| `ZKP` | Swift wrapper | Experimental extension (zkp primitives) |
| `libsecp256k1` | C bindings | Raw bindings to libsecp256k1 |
| `libsecp256k1_zkp` | C bindings | Raw bindings to libsecp256k1-zkp |

### Dependencies

**Runtime**: Zero dependencies beyond libsecp256k1 bindings
**Development only**: lefthook-plugin, swift-plugin-tuist, SwiftFormat, SwiftLint, swift-plugin-subtree

---

## Governance

### Authority

This constitution supersedes all other development practices. Deviations MUST be explicitly justified and approved.

**Model**: Project owner (BDFL) can amend constitution directly. Community proposes changes via GitHub issues.

### Security-Relevant Changes

Changes affecting cryptographic behavior require additional scrutiny:

| Requirement | Purpose |
|-------------|---------|
| Document security implications in PR description | Creates audit trail |
| 48-72 hour merge delay | Allows community review |
| Explicit "security-reviewed" label | Signals intentional consideration |

**Security-relevant changes include**:
- New cryptographic primitives
- Changes to key/secret handling APIs
- New key formats or protocol support

### Amendment Process

1. Project owner proposes amendment with rationale and impact analysis
2. Version updated (semantic versioning):
   - **MAJOR**: Backward-incompatible changes or principle removals
   - **MINOR**: New principle or materially expanded guidance
   - **PATCH**: Clarifications, wording fixes
3. Update dependent templates in `.specify/templates/`
4. Document changes in Sync Impact Report
5. Commit with descriptive message

### Compliance Review Triggers

| Trigger | Action |
|---------|--------|
| Adding new cryptographic primitives | Full constitutional alignment check |
| libsecp256k1 upstream updates | Verify behavior consistency |
| Changes to key/secret handling APIs | Security review required |
| Breaking API changes (semver major) | Stability signaling review |

### Versioning & Stability

**Pre-1.0** (current):
- No stability guarantees
- Immediate breaking changes acceptable
- Users advised to pin exact versions

**Post-1.0** (future):
- Semantic versioning strictly enforced
- Deprecation period (one minor version) before removal
- Breaking changes require major version bump

### Enforcement

- PR reviewers verify constitutional alignment
- CI pipeline enforces MUST-level (blocking), SHOULD-level (warnings)
- Three-tier enforcement:
  - **MUST**: Blocks merge
  - **SHOULD**: Warning, requires override justification
  - **MAY**: Informational only

---

## Version History

**Version**: 1.0.0
**Ratified**: 2025-12-02
**Last Amended**: 2025-12-02

**Changelog**:
- **1.0.0** (2025-12-02): Initial constitution with 7 core principles, three-tier enforcement, BDFL governance, security-relevant change protocols.

---

## Appendix: Principle Mapping

This constitution consolidates principles from the provided sources:

**From Core Principles (4.1)**:
- Spec-First & Outside-In → Principle V
- Test-Driven Development → Principle V
- Small, Independent Specs → Principle V
- CI & Quality Gates → Principle VI
- Simplicity & Readability → Principle VII
- Open Source Excellence → Principle VII
- Governance & Amendments → Governance

**From Swift-SECP256k1 Principles (4.2)**:
- Security-First Cryptographic Development → Principles II, III
- Mathematically Verified Implementations → Principle II
- Secure Random Number Generation → Principle III
- Key & Data Protection → Principle III
- Error Handling → Principle IV
- Cross-Platform CI → Principle VI
- Open-Source Documentation & Community → Principle VII

**From Principle Table**:
- Project Scope → Principle I
- Standards Alignment → Principle I
- Cryptographic Correctness → Principle II
- Implementation Safety (Constant-Time) → Principle II
- Key & Secret Handling → Principle III
- API Design & Ergonomics → Principle IV
- Safe Defaults, Explicit Power → Principle IV
- Deterministic Behavior → Principle VI
- Cross-Platform Guarantees → Principle VI
- Test Vectors & Property Tests → Principle V
- Fuzzing & Negative Testing → Principles II, V
- Versioning & Stability Signaling → Governance
- Documentation & Examples → Principle VII
- Dependency Hygiene → Principle I
- Security Review & Disclosure → Implementation Guidance
- No "Roll Your Own Crypto" → Principle II
- Data Portability & Interop → Principle IV
- Graceful Failure & Error Types → Principle IV
- Swift Compatibility Discovery → Principle V (use swift-tools-version as authoritative source, avoid build-testing)
