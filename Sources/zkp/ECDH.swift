//
//  ECDH.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

// MARK: - secp256k1 + KeyAgreement

public extension secp256k1 {
    enum KeyAgreement {
        public struct PublicKey /*: NISTECPublicKey */ {
            let baseKey: PublicKeyImplementation

            /// Creates a secp256k1 public key for key agreement from a collection of bytes.
            /// - Parameters:
            ///   - data: A raw representation of the public key as a collection of contiguous bytes.
            ///   - xonly: A raw representation of the xonly key as a collection of contiguous bytes.
            ///   - format: the format of the public key object
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PublicKeyImplementation(rawRepresentation: data, format: format)
            }

            /// Initializes a secp256k1 public key for key agreement.
            /// - Parameter baseKey: generated secp256k1 public key.
            init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// The associated x-only public key for verifying Schnorr signatures.
            ///
            /// - Returns: The associated x-only public key
            public var xonly: secp256k1.KeyAgreement.XonlyKey {
                XonlyKey(baseKey: baseKey.xonly)
            }

            /// A data representation of the public key
            public var rawRepresentation: Data { baseKey.rawRepresentation }

            /// Implementation public key object
            var bytes: [UInt8] { baseKey.bytes }
        }

        public struct XonlyKey {
            /// Generated secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// A data representation of the backing x-only public key
            public var rawRepresentation: Data { baseKey.rawRepresentation }

            /// A boolean that will be set to true if the point encoded by xonly is the
            /// negation of the pubkey and set to false otherwise.
            public var parity: Bool { baseKey.keyParity.boolValue }

            /// Initializes a secp256k1 x-only key for key agreement.
            /// - Parameter baseKey: generated secp256k1 public key.
            init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }
        }

        public struct PrivateKey {
            let baseKey: PrivateKeyImplementation

            /// Creates a random secp256k1 private key for key agreement.
            public init(format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for key agreement from a collection of bytes.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a private key for key agreement.
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(rawRepresentation: data, format: format)
            }

            /// Initializes a secp256k1 private key for key agreement.
            /// - Parameter baseKey: generated secp256k1 private key.
            init(baseKey: PrivateKeyImplementation) {
                self.baseKey = baseKey
            }

            /// The associated public key for verifying signatures done with this private key.
            public var publicKey: secp256k1.KeyAgreement.PublicKey {
                PublicKey(baseKey: baseKey.publicKey)
            }

            /// A data representation of the private key
            public var rawRepresentation: Data { baseKey.rawRepresentation }

            /// Implementation public key object
            var bytes: SecureBytes { baseKey.key }
        }
    }
}

// MARK: - secp256k1 + DH

extension secp256k1.KeyAgreement.PrivateKey: DiffieHellmanKeyAgreement {
    /// A pointer to a function that hashes an EC point to obtain an ECDH secret
    public typealias HashFunctionType = @convention(c) (
        UnsafeMutablePointer<UInt8>?,
        UnsafePointer<UInt8>?,
        UnsafePointer<UInt8>?,
        UnsafeMutableRawPointer?
    ) -> Int32

    /// Performs a key agreement with provided public key share.
    ///
    /// - Parameter publicKeyShare: The public key to perform the ECDH with.
    /// - Returns: Returns a shared secret
    /// - Throws: An error occurred while computing the shared secret
    func sharedSecretFromKeyAgreement(with publicKeyShare: secp256k1.KeyAgreement.PublicKey) throws -> SharedSecret {
        try sharedSecretFromKeyAgreement(with: publicKeyShare, handler: nil)
    }

    /// Performs a key agreement with provided public key share.
    /// - Parameters:
    ///   - publicKeyShare: The public key to perform the ECDH with.
    ///   - handler: Closure for customizing a hash function; Defaults to nil.
    /// - Returns: Returns a shared secret
    /// - Throws: An error occurred while computing the shared secret
    public func sharedSecretFromKeyAgreement(
        with publicKeyShare: secp256k1.KeyAgreement.PublicKey,
        handler: HashFunctionType? = nil,
        data: UnsafeMutableRawPointer? = nil
    ) throws -> SharedSecret {
        let context = secp256k1.Context.raw
        var publicKey = secp256k1_pubkey()
        var sharedSecret = [UInt8](repeating: 0, count: 32)

        guard secp256k1_ec_pubkey_parse(secp256k1.Context.raw, &publicKey, publicKeyShare.bytes, publicKeyShare.bytes.count).boolValue,
              secp256k1_ecdh(context, &sharedSecret, &publicKey, baseKey.key.bytes, handler, data).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return SharedSecret(ss: SecureBytes(bytes: sharedSecret))
    }
}
