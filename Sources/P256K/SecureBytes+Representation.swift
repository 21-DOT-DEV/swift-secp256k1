//
//  SecureBytes+Representation.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if !hasFeature(Embedded)
    /// Redacted render channels for `SecureBytes`, the zeroizing storage every
    /// copyable secret-bearing type delegates to.
    ///
    /// Without these conformances the render is safe only incidentally:
    /// `String(describing:)` prints `SecureBytes(backing: <class>)` because the
    /// secret bytes are tail-allocated `ManagedBuffer` elements no `Mirror` can
    /// reach — nothing pins the shape. Pinning all three channels by
    /// construction keeps the storage redacted even if a future upstream sync
    /// restructures `Backing` into inline storage: `description` and
    /// `debugDescription` report only the byte count (the ``SharedSecret``
    /// convention), and `customMirror` shows no stored properties, sealing the
    /// `Mirror`/`dump(_:)` channel a redacted `description` cannot cover.
    ///
    /// Lives in a project-owned file because `SecureBytes` is vendored under
    /// `Sources/P256K/swift-crypto/` (`vendir.yml`). If upstream ever ships its
    /// own conformance this extension collides at sync time — resolve by
    /// deleting it.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension SecureBytes: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        /// A redacted form reporting only the stored byte count.
        ///
        /// The secret bytes are never rendered — printing, interpolating, or
        /// logging a `SecureBytes` cannot disclose its contents; byte access
        /// stays explicit through `withUnsafeBytes(_:)`.
        var description: String {
            "\(Self.self) representation contains \(count) bytes."
        }

        var debugDescription: String {
            description
        }

        /// Reflects no stored properties to `Mirror` consumers — `dump(_:)` and
        /// Mirror-walking loggers see no children to descend into, so the
        /// secret bytes stay unreachable through the channel a redacted
        /// `description` cannot cover.
        var customMirror: Mirror {
            Mirror(self, unlabeledChildren: EmptyCollection<Void>())
        }
    }
#endif
