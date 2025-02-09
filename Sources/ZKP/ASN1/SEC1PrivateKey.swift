//
//  SEC1PrivateKey.swift
//  GigaBitcoin/secp256k1.swift
//
//  Modifications Copyright (c) 2023 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
//
//  NOTICE: THIS FILE HAS BEEN MODIFIED BY GigaBitcoin LLC
//  UNDER COMPLIANCE WITH THE APACHE 2.0 LICENSE FROM THE
//  ORIGINAL WORK OF THE COMPANY Apple Inc.
//
//  THE FOLLOWING IS THE COPYRIGHT OF THE ORIGINAL DOCUMENT:
//
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftCrypto open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the SwiftCrypto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of SwiftCrypto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#if CRYPTO_IN_SWIFTPM && !CRYPTO_IN_SWIFTPM_FORCE_BUILD_API
    @_exported import CryptoKit
#else
    import Foundation

    extension ASN1 {
        // For private keys, SEC 1 uses:
        //
        // ECPrivateKey ::= SEQUENCE {
        //   version INTEGER { ecPrivkeyVer1(1) } (ecPrivkeyVer1),
        //   privateKey OCTET STRING,
        //   parameters [0] EXPLICIT ECDomainParameters OPTIONAL,
        //   publicKey [1] EXPLICIT BIT STRING OPTIONAL
        // }
        struct SEC1PrivateKey: ASN1ImplicitlyTaggable {
            static var defaultIdentifier: ASN1.ASN1Identifier {
                .sequence
            }

            var algorithm: ASN1.RFC5480AlgorithmIdentifier?

            var privateKey: ASN1.ASN1OctetString

            var publicKey: ASN1.ASN1BitString?

            init(asn1Encoded rootNode: ASN1.ASN1Node, withIdentifier identifier: ASN1.ASN1Identifier) throws {
                self = try ASN1.sequence(rootNode, identifier: identifier) { nodes in
                    let version = try Int(asn1Encoded: &nodes)
                    guard version == 1 else {
                        throw CryptoKitASN1Error.invalidASN1Object
                    }

                    let privateKey = try ASN1OctetString(asn1Encoded: &nodes)
                    let parameters = try ASN1.optionalExplicitlyTagged(&nodes, tagNumber: 0, tagClass: .contextSpecific) { node in
                        try ASN1.ASN1ObjectIdentifier(asn1Encoded: node)
                    }
                    let publicKey = try ASN1.optionalExplicitlyTagged(&nodes, tagNumber: 1, tagClass: .contextSpecific) { node in
                        try ASN1.ASN1BitString(asn1Encoded: node)
                    }

                    return try .init(privateKey: privateKey, algorithm: parameters, publicKey: publicKey)
                }
            }

            private init(privateKey: ASN1.ASN1OctetString, algorithm: ASN1.ASN1ObjectIdentifier?, publicKey: ASN1.ASN1BitString?) throws {
                self.privateKey = privateKey
                self.publicKey = publicKey
                self.algorithm = try algorithm.map { algorithmOID in
                    switch algorithmOID {
                    case ASN1ObjectIdentifier.NamedCurves.secp256k1:
                        return .ecdsaP256K1

                    default:
                        throw CryptoKitASN1Error.invalidASN1Object
                    }
                }
            }

            init(privateKey: [UInt8], algorithm: RFC5480AlgorithmIdentifier?, publicKey: [UInt8]) {
                self.privateKey = ASN1OctetString(contentBytes: privateKey[...])
                self.algorithm = algorithm
                self.publicKey = ASN1BitString(bytes: publicKey[...])
            }

            func serialize(into coder: inout ASN1.Serializer, withIdentifier identifier: ASN1.ASN1Identifier) throws {
                try coder.appendConstructedNode(identifier: identifier) { coder in
                    try coder.serialize(1) // version
                    try coder.serialize(self.privateKey)

                    if let algorithm = self.algorithm {
                        let oid: ASN1.ASN1ObjectIdentifier
                        switch algorithm {
                        case .ecdsaP256K1:
                            oid = ASN1ObjectIdentifier.NamedCurves.secp256k1

                        default:
                            throw CryptoKitASN1Error.invalidASN1Object
                        }

                        try coder.serialize(oid, explicitlyTaggedWithTagNumber: 0, tagClass: .contextSpecific)
                    }

                    if let publicKey = self.publicKey {
                        try coder.serialize(publicKey, explicitlyTaggedWithTagNumber: 1, tagClass: .contextSpecific)
                    }
                }
            }
        }
    }

#endif // Linux or !SwiftPM
