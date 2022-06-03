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
import secp256k1_bindings

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
            public init<D: ContiguousBytes>(rawRepresentation data: D, xonly: D, keyParity: Int32, format: secp256k1.Format) {
                self.baseKey = PublicKeyImplementation(rawRepresentation: data, xonly: xonly, keyParity: keyParity, format: format)
            }

            /// Initializes a secp256k1 public key for key agreement.
            /// - Parameter baseKey: generated secp256k1 public key.
            init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// A data representation of the public key
            public var rawRepresentation: Data { baseKey.rawRepresentation }

            /// Implementation public key object
            var bytes: [UInt8] { baseKey.bytes }
        }

        public struct PrivateKey /*: NISTECPrivateKey */ {
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
    /// Performs a key agreement with provided public key share.
    ///
    /// - Parameter publicKeyShare: The public key to perform the ECDH with.
    /// - Returns: Returns a shared secret
    /// - Throws: An error occurred while computing the shared secret
    public func sharedSecretFromKeyAgreement(with publicKeyShare: secp256k1.KeyAgreement.PublicKey) throws -> SharedSecret {
        var publicKey = secp256k1_pubkey()
        var sharedSecret = [UInt8](repeating: 0, count: 32)

        guard secp256k1_ec_pubkey_parse(secp256k1.Context.raw, &publicKey, publicKeyShare.bytes, publicKeyShare.bytes.count).boolValue,
              secp256k1_ecdh(secp256k1.Context.raw, &sharedSecret, &publicKey, baseKey.key.bytes, nil, nil).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return SharedSecret(ss: SecureBytes(bytes: sharedSecret))
    }
}
