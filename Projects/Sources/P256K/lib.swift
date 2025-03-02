//
//  lib.swift
//  libsecp256k1
//
//  Created by csjones on 1/26/25.
//

import libsecp256k1

public enum P256K {
    static func hello() {
        _ = secp256k1_context_create(UInt32(0))
    }
}
