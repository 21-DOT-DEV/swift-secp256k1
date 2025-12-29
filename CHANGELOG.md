# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Updated vendored swift-crypto from 3.11.1 to 4.2.0
- Added `@available` attributes to resolve availability requirements from swift-crypto 4.2.0
- Added `Sendable` conformance to key types (`P256K`, `PrivateKey`, `PublicKey`, `XonlyKey`, `SharedSecret`)
- Updated imports to use `FoundationEssentials` conditional pattern matching upstream swift-crypto
- Synced ASN1 files (`ObjectIdentifier.swift`, `SEC1PrivateKey.swift`, `SubjectPublicKeyInfo.swift`) with upstream structure
- Synced utility files (`SafeCompare.swift`, `Zeroization.swift`, `DH.swift`) with upstream patterns
