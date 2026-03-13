# Contributing to swift-secp256k1

Thank you for your interest in contributing to swift-secp256k1! This document provides guidelines and information for contributors.

## Scope

swift-secp256k1 is a Swift cryptography package for elliptic curve operations on the secp256k1 curve. It is not a general-purpose cryptography library.

The package primarily provides Swift APIs for [libsecp256k1](https://github.com/bitcoin-core/secp256k1), serving the needs of the Bitcoin ecosystem on Apple platforms and Linux.

Contributions of new functionality are welcome, provided they are within the project's scope. When proposing significant additions, please open an issue first to discuss the design and ensure alignment with project goals.

## Code of Conduct

This project has adopted the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the community leaders listed in the Code of Conduct.

## How to Report a Bug

Please [open an issue](https://github.com/21-DOT-DEV/swift-secp256k1/issues/new) and include the following:

- swift-secp256k1 version or commit hash
- Swift version (output of `swift --version`)
- OS version and the output of `uname -a`
- Contextual information (what you were trying to achieve)
- Simplest possible steps to reproduce
  - A pull request with a failing test case is preferred, but pasting the test case into the issue description is fine.

## Security Vulnerabilities

If you believe you have found a security vulnerability, **do not open a public issue**. Please report it through [GitHub Security Advisories](https://github.com/21-DOT-DEV/swift-secp256k1/security/advisories). See [SECURITY.md](SECURITY.md) for full details.

## Writing a Patch

A good swift-secp256k1 patch is:

1. **Concise** — contains as few changes as needed to achieve the end result.
2. **Tested** — any tests provided must fail before the patch and pass after it.
3. **Documented** — adds or updates API documentation as needed to cover new or changed functionality.
4. **Well-described** — accompanied by a clear commit message explaining *what* changed and *why*.

## Code Style

Code is automatically formatted and linted using the project's configuration files:

- **[SwiftFormat](https://github.com/nicklockwood/SwiftFormat)** — enforced via `.swiftformat` (4-space indentation, LF line breaks, alphabetized imports)
- **[SwiftLint](https://github.com/realm/SwiftLint)** — enforced via `.swiftlint.yml` (140-char line length, extensive opt-in rules)

Both tools run automatically as pre-commit hooks via [Lefthook](https://github.com/evilmartians/lefthook). After cloning, run:

```
lefthook install
```

## Branching

All development happens on `main`. Create feature branches from `main` and open pull requests back to `main`.

## Testing

Run the full test suite with:

```
swift test
```

Pre-push hooks automatically run `swift test` and `swift build --target ZKP` via Lefthook. New features should include corresponding tests, and bug fixes should include a regression test.

## How to Contribute

1. Fork the repository and create your branch from `main`.
2. Make your changes following the guidelines above.
3. Ensure all tests pass (`swift test`).
4. Open a pull request at https://github.com/21-DOT-DEV/swift-secp256k1.
5. Wait for CI to pass and code review.

## Legal

By submitting a pull request, you represent that you have the right to license your contribution to the project and the community, and agree by submitting the patch that your contributions are licensed under the [MIT License](LICENSE).
