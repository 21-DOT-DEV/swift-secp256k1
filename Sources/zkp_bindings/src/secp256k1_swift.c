//
//  secp256k1_swift.c
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#include "../include/secp256k1_swift.h"
#include "../src/hash_impl.h"

/// Exposes secp256k1 memczero implementation to the bindings target
/// @param s    pointer to an array to be zero'd by the function
/// @param len  the length of the data to be zero'd
/// @param flag zero memory if flag == 1. Flag must be 0 or 1. Constant time.
void secp256k1_swift_memczero(void *s, size_t len, int flag) {
    secp256k1_memczero(s, len, flag);
}

/// Exposes secp256k1 SHA256 implementation to the bindings target
/// @param output pointer to an array to be filled by the function
/// @param input  a pointer to the data to be hashed
/// @param len    the length of the data to be hashed
void secp256k1_swift_sha256(unsigned char *output, const unsigned char *input, size_t len) {
    secp256k1_sha256 hasher;
    secp256k1_sha256_initialize(&hasher);
    secp256k1_sha256_write(&hasher, input, len);
    secp256k1_sha256_finalize(&hasher, output);
}

/// Parse a surjection proof
/// @param data  Borromean signature: e0, scalars
/// @param proof data structure that holds a parsed surjection proof
void secp256k1_swift_surjection_proof_parse(const unsigned char *data, secp256k1_surjectionproof proof) {
    data = proof.data;
}

/// Serialize a surjection proof
/// @param proof data structure that holds a parsed surjection proof
/// @param data  Borromean signature: e0, scalars
void secp256k1_swift_surjection_proof_serialize(secp256k1_surjectionproof proof, const unsigned char *data) {
    memcpy(proof.data, &data, sizeof data);
}
