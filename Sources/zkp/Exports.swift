//
//  Exports.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(secp256k1_zkp_bindings)
    @_exported import secp256k1_zkp_bindings
#else
    @_exported import secp256k1_bindings
#endif
