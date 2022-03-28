//
//  Zeroization.swift
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
// Copyright (c) 2019 Apple Inc. and the SwiftCrypto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of SwiftCrypto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#if !(os(macOS) || os(iOS) || os(watchOS) || os(tvOS))

    import secp256k1_bindings

    public typealias errno_t = CInt

    @discardableResult
    public func memset_s(_ s: UnsafeMutableRawPointer!, _ smax: Int, _ byte: CInt, _ n: Int) -> errno_t {
        assert(smax == n, "memset_s invariant not met")
        assert(byte == 0, "memset_s used to not zero anything")
        secp256k1_swift_memczero(s, smax, 1)
        return 0
    }
#endif
