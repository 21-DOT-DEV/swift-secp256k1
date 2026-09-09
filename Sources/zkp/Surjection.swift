//
//  Surjection.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2023 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import zkp_bindings

// MARK: - secp256k1 + SurjectionProof

public extension secp256k1 {
    enum Surjection {
        struct Proof {
            let length = Int(32 * (1 + SECP256K1_SURJECTIONPROOF_MAX_USED_INPUTS))
            /// Total number of input asset tags
            public let nInputs: Int
            /// Bitmap of which input tags are used in the surjection proof
            public let usedInputs: Data
            /// Borromean signature: e0, scalars
            public let rawRepresentation: Data
            /// The index of the actual input that is secretly mapped to the output
            public let inputIndex: Int
            /// The ephemeral asset tag of the output
            public let ephemeralOutputTag: Data
            /// the blinding key of the output
            public let blindingKey: [UInt8]

            /// Surjection proof initialization and generation functions
            @usableFromInline init(
                fixedInputTags: [secp256k1_fixed_asset_tag],
                ephemeralInputTags: [secp256k1_generator],
                inputBlindingKey: [UInt8]
            ) throws {
                var outSurjectionProof = secp256k1_surjectionproof()
                var ephemeralOutputTag = secp256k1_generator()
                var outputBlindingKey = [UInt8](repeating: 0, count: 64)
                var outInputIndex = 0
                var fixedOutputTag = secp256k1_fixed_asset_tag()
                var randomSeed: Int8 = 3
                var proofData = [UInt8](repeating: 0, count: length)

                guard secp256k1_surjectionproof_initialize(
                    secp256k1.Context.raw,
                    &outSurjectionProof,
                    &outInputIndex,
                    fixedInputTags,
                    fixedInputTags.count,
                    fixedInputTags.count,
                    &fixedOutputTag,
                    100,
                    &randomSeed
                ).boolValue,
                    secp256k1_surjectionproof_generate(
                        secp256k1.Context.raw,
                        &outSurjectionProof,
                        ephemeralInputTags,
                        ephemeralInputTags.count,
                        &ephemeralOutputTag,
                        outInputIndex,
                        inputBlindingKey,
                        &outputBlindingKey
                    ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                secp256k1_swift_surjection_proof_parse(&proofData, outSurjectionProof)

                self.blindingKey = outputBlindingKey
                self.nInputs = outSurjectionProof.n_inputs
                self.inputIndex = outInputIndex
                self.usedInputs = Data(outSurjectionProof.used_inputs)
                self.rawRepresentation = Data(proofData)
                self.ephemeralOutputTag = Data(ephemeralOutputTag.data)
            }

            static func verify(
                proof: inout secp256k1_surjectionproof,
                ephemeralInputTags: [secp256k1_generator],
                ephemeralOutputTag: inout secp256k1_generator
            ) -> Bool {
                secp256k1_surjectionproof_verify(
                    secp256k1.Context.raw,
                    &proof,
                    ephemeralInputTags,
                    ephemeralInputTags.count,
                    &ephemeralOutputTag
                ).boolValue
            }
        }
    }
}

internal extension Data {
    init(_ usedInputs: UsedInputsType) {
        self = Data(Swift.withUnsafeBytes(of: usedInputs) { [UInt8]($0) })
    }

    init(_ ephemeralTag: EphemeralTagType) {
        self = Data(Swift.withUnsafeBytes(of: ephemeralTag) { [UInt8]($0) })
    }
}

typealias UsedInputsType = (
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8
)

typealias EphemeralTagType = (
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8,
    UInt8
)
