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

/// An elliptic curve that enables secp256k1 signatures and key agreement.
public extension secp256k1 {
    /// A namespace for key agreement functionality using the secp256k1 elliptic curve.
    enum KeyAgreement {
        /// A public key for performing key agreement using the secp256k1 elliptic curve.
        public struct PublicKey /*: NISTECPublicKey */ {
            /// The underlying implementation of the secp256k1 public key.
            let baseKey: PublicKeyImplementation

            /// Creates a secp256k1 public key for key agreement from a collection of bytes.
            ///
            /// - Parameters:
            ///   - data: A data representation of the public key as a collection of contiguous bytes.
            ///   - format: The format of the public key object.
            /// - Throws: An error if the raw representation does not create a public key.
            public init<D: ContiguousBytes>(dataRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PublicKeyImplementation(dataRepresentation: data, format: format)
            }

            /// Initializes a secp256k1 public key for key agreement.
            ///
            /// - Parameter baseKey: Generated secp256k1 public key.
            init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// The associated x-only public key for verifying Schnorr signatures.
            ///
            /// - Returns: The associated x-only public key.
            public var xonly: secp256k1.KeyAgreement.XonlyKey {
                XonlyKey(baseKey: baseKey.xonly)
            }

            /// A data representation of the public key.
            public var dataRepresentation: Data { baseKey.dataRepresentation }

            /// A raw representation of the public key.
            public var rawRepresentation: secp256k1_pubkey { baseKey.rawRepresentation }

            /// Implementation public key object.
            var bytes: [UInt8] { baseKey.bytes }
        }

        /// A secp256k1 x-only public key for key agreement.
        public struct XonlyKey {
            /// The underlying implementation of the secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// A data representation of the backing x-only public key.
            public var dataRepresentation: Data { baseKey.dataRepresentation }

            /// A raw representation of the backing x-only public key.
            public var rawRepresentation: secp256k1_xonly_pubkey { baseKey.rawRepresentation }

            /// A boolean that will be set to true if the point encoded by xonly is the
            /// negation of the pubkey and set to false otherwise.
            public var parity: Bool { baseKey.keyParity.boolValue }

            /// Initializes a secp256k1 x-only key for key agreement.
            ///
            /// - Parameter baseKey: Generated secp256k1 x-only public key.
            init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }
        }

        /// A secp256k1 private key for key agreement.
        public struct PrivateKey {
            /// The underlying implementation of the secp256k1 private key.
            let baseKey: PrivateKeyImplementation

            /// Creates a random secp256k1 private key for key agreement.
            ///
            /// - Parameter format: The format of the secp256k1 key (default is .compressed).
            /// - Throws: An error is thrown when the key generation fails.
            public init(format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for key agreement from a collection of bytes.
            ///
            /// - Parameters:
            ///   - data: A raw representation of the key.
            ///   - format: The format of the secp256k1 key (default is .compressed).
            /// - Throws: An error is thrown when the raw representation does not create a private key for key agreement.
            public init<D: ContiguousBytes>(dataRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(dataRepresentation: data, format: format)
            }

            /// Initializes a secp256k1 private key for key agreement.
            ///
            /// - Parameter baseKey: Generated secp256k1 private key.
            init(baseKey: PrivateKeyImplementation) {
                self.baseKey = baseKey
            }

            /// The associated public key for verifying signatures done with this private key.
            public var publicKey: secp256k1.KeyAgreement.PublicKey {
                PublicKey(baseKey: baseKey.publicKey)
            }

            /// A data representation of the private key.
            public var rawRepresentation: Data { baseKey.dataRepresentation }

            /// A secure bytes representation of the private key.
            var bytes: SecureBytes { baseKey.key }
        }
    }
}

// MARK: - secp256k1 + DH

/// An extension to the `secp256k1.KeyAgreement.PrivateKey` conforming to the `DiffieHellmanKeyAgreement` protocol.
extension secp256k1.KeyAgreement.PrivateKey: DiffieHellmanKeyAgreement {
    /// A pointer to a function that hashes an EC point to obtain an ECDH secret.
    public typealias HashFunctionType = @convention(c) (
        UnsafeMutablePointer<UInt8>?,
        UnsafePointer<UInt8>?,
        UnsafePointer<UInt8>?,
        UnsafeMutableRawPointer?
    ) -> Int32

    /// Performs a key agreement with the provided public key share.
    ///
    /// - Parameter publicKeyShare: The public key to perform the ECDH with.
    /// - Returns: Returns a shared secret.
    /// - Throws: An error occurred while computing the shared secret.
    func sharedSecretFromKeyAgreement(with publicKeyShare: secp256k1.KeyAgreement.PublicKey) throws -> SharedSecret {
        try sharedSecretFromKeyAgreement(with: publicKeyShare, format: .compressed)
    }

    /// Performs a key agreement with the provided public key share.
    ///
    /// - Parameters:
    ///   - publicKeyShare: The public key to perform the ECDH with.
    ///   - format: An enum that represents the format of the shared secret.
    /// - Returns: Returns a shared secret.
    /// - Throws: An error occurred while computing the shared secret.
    public func sharedSecretFromKeyAgreement(
        with publicKeyShare: secp256k1.KeyAgreement.PublicKey,
        format: secp256k1.Format = .compressed
    ) throws -> SharedSecret {
        let context = secp256k1.Context.rawRepresentation
        var publicKey = publicKeyShare.rawRepresentation
        var sharedSecret = [UInt8](repeating: 0, count: format.length)
        var data = [UInt8](repeating: format == .compressed ? 1 : 0, count: 1)

        guard secp256k1_ecdh(context, &sharedSecret, &publicKey, baseKey.key.bytes, hashClosure(), &data).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return SharedSecret(ss: SecureBytes(bytes: sharedSecret), format: format)
    }

    /// Creates a closure which handles creating either a compressed or uncompressed shared secret
    ///
    /// - Returns: Closure to override the libsecp256k1 hashing function
    func hashClosure() -> HashFunctionType {
        { output, x32, y32, data in
            guard let output, let x32, let y32, let compressed = data?.load(as: Bool.self) else { return 0 }

            let lastByte = y32.advanced(by: secp256k1.ByteLength.dimension - 1).pointee
            let version: UInt8 = compressed ? (lastByte & 0x01) | 0x02 : 0x04

            output.update(repeating: version, count: 1)
            output.advanced(by: 1).update(from: x32, count: secp256k1.ByteLength.dimension)

            if compressed == false {
                output.advanced(by: secp256k1.ByteLength.dimension + 1)
                    .update(from: y32, count: secp256k1.ByteLength.dimension)
            }

            return 1
        }
    }
}
