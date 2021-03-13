//
//  SHA256.h
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#include "../secp256k1/src/hash.h"
#include "../secp256k1/include/secp256k1.h"

/// Exposes secp256k1 SHA256 implementation to the bindings target
/// @param output  pointer to an array to be filled by the function
/// @param input a pointer to the data to be hashed
/// @param len the length of the data to be hashed
void secp256k1_swift_sha256(unsigned char *output, const unsigned char *input, size_t len);
