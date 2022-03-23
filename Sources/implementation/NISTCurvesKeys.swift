//
//  NISTCurvesKeys.swift
//  GigaBitcoin/secp256k1.swift
//
//  Modifications Copyright (c) 2021 GigaBitcoin LLC
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
import Foundation

protocol ECPublicKey {
    init <Bytes: ContiguousBytes>(rawRepresentation: Bytes) throws
    var rawRepresentation: Data { get }
}

protocol ECPrivateKey {
    associatedtype PublicKey
    var publicKey: PublicKey { get }
}

protocol NISTECPublicKey: ECPublicKey {
    init<Bytes: ContiguousBytes>(compactRepresentation: Bytes) throws
    init<Bytes: ContiguousBytes>(x963Representation: Bytes) throws

    var compactRepresentation: Data? { get }
    var x963Representation: Data { get }
}

protocol NISTECPrivateKey: ECPrivateKey where PublicKey: NISTECPublicKey {
    init <Bytes: ContiguousBytes>(rawRepresentation: Bytes) throws
    var rawRepresentation: Data { get }
}
