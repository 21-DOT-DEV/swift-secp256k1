//
//  BindingsTests.swift
//  swift-secp256k1
//
//  Created by csjones on 2/9/25.
//

#if canImport(libsecp256k1_zkp)
    @testable import libsecp256k1_zkp
    @testable import ZKP
#else
    @testable import libsecp256k1
    @testable import P256K
#endif

import Testing

struct BindingsTestSuite {
    /// Uncompressed Key pair test
    @Test("Uncompressed Key pair creation bindings")
    func uncompressedKeypairCreationBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubkeyLen = 65
        var cPubkey = secp256k1_pubkey()
        var publicKey = [UInt8](repeating: 0, count: pubkeyLen)

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        // Verify the context and keys are setup correctly
        #expect(secp256k1_context_randomize(context, privateKey) == 1, "Context randomization failed.")
        #expect(secp256k1_ec_pubkey_create(context, &cPubkey, privateKey) == 1, "Public key creation failed.")
        #expect(secp256k1_ec_pubkey_serialize(context, &publicKey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)) == 1, "Public key serialization failed.")

        let hexString = """
        04734B3511150A60FC8CAC329CD5FF804555728740F2F2E98BC4242135EF5D5E4E6C4918116B0866F50C46614F3015D8667FBFB058471D662A642B8EA2C9C78E8A
        """

        // Define the expected public key
        let expectedPublicKey = try! hexString.bytes

        // Verify the generated public key matches the expected public key
        #expect(expectedPublicKey == publicKey, "Generated public key does not match expected public key.")
        #expect(hexString.lowercased() == String(bytes: publicKey), "Generated public key string representation is incorrect.")
    }

    /// Compressed Key pair creation bindings
    @Test("Compressed Key pair creation bindings")
    func compressedKeypairCreationBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubkeyLen = 33
        var cPubkey = secp256k1_pubkey()
        var publicKey = [UInt8](repeating: 0, count: pubkeyLen)
        let privateKey = try! "B035FCFC6ABF660856C5F3A6F9AC51FCA897BB4E76AD9ACA3EFD40DA6B9C864B".bytes

        // Verify the context and keys are setup correctly
        #expect(secp256k1_context_randomize(context, privateKey) == 1, "Context randomization failed.")
        #expect(secp256k1_ec_pubkey_create(context, &cPubkey, privateKey) == 1, "Public key creation failed.")
        #expect(secp256k1_ec_pubkey_serialize(context, &publicKey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_COMPRESSED)) == 1, "Public key serialization failed.")

        // Define the expected public key
        let expectedPublicKey = try! "02EA724B70B48B61FB87E4310871A48C65BF38BF3FDFEFE73C2B90F8F32F9C1794".bytes

        // Verify the generated public key matches the expected public key
        #expect(expectedPublicKey == publicKey, "Generated public key does not match expected public key.")
    }

    /// ECDH Test
    @Test("ECDH Binding Test")
    func ecdhBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var point = secp256k1_pubkey()
        var res = [UInt8](repeating: 0, count: 32)
        var s_one = [UInt8](repeating: 0, count: 32)

        s_one[31] = 1

        #expect(secp256k1_ec_pubkey_create(context, &point, s_one) == 1, "Public key creation failed.")
        #expect(secp256k1_ecdh(context, &res, &point, s_one, nil, nil) == 1, "ECDH computation failed.")
    }

    /// Extra Keys Bindings Test
    @Test("Extra Keys Bindings Test")
    func extraKeysBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var pubKey = secp256k1_pubkey()
        var xOnlyPubKey = secp256k1_xonly_pubkey()
        var pk_parity = Int32()

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        #expect(secp256k1_ec_pubkey_create(context, &pubKey, privateKey) == 1, "Failed to create public key from private key.")
        #expect(secp256k1_xonly_pubkey_from_pubkey(context, &xOnlyPubKey, &pk_parity, &pubKey) == 1, "Failed to convert public key to xonly format.")
    }

    /// Recovery Bindings Test
    @Test("Recovery Bindings Test")
    func recoveryBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var pubKey = secp256k1_pubkey()
        var recsig = secp256k1_ecdsa_recoverable_signature()
        var message = [UInt8](repeating: 0, count: 32)

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        #expect(secp256k1_ec_seckey_verify(context, privateKey) == 1, "Failed to verify private key.")
        #expect(secp256k1_ec_pubkey_create(context, &pubKey, privateKey) == 1, "Failed to create public key from private key.")
        #expect(secp256k1_ecdsa_sign_recoverable(context, &recsig, &message, privateKey, nil, nil) == 1, "Failed to sign message with private key.")
    }

    /// Schnorr Bindings Test
    @Test("Schnorr Bindings Test")
    func schnorrBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var keypair = secp256k1_keypair()
        var xpubKey = secp256k1_xonly_pubkey()
        var xpubKeyBytes = [UInt8](repeating: 0, count: 32)

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        #expect(secp256k1_keypair_create(context, &keypair, privateKey) == 1, "Failed to create keypair from private key.")
        #expect(secp256k1_keypair_xonly_pub(context, &xpubKey, nil, &keypair) == 1, "Failed to get xonly public key from keypair.")
        #expect(secp256k1_xonly_pubkey_serialize(context, &xpubKeyBytes, &xpubKey) == 1, "Failed to serialize xonly public key.")

        let expectedXPubKey = "734b3511150a60fc8cac329cd5ff804555728740f2f2e98bc4242135ef5d5e4e"

        #expect(String(bytes: xpubKeyBytes) == expectedXPubKey, "Generated xonly public key does not match expected xonly public key.")
    }

    /// Key Agreement Hash Function Test
    @Test("Key Agreement Hash Function Test")
    func keyAgreementHashFunction() {
        let context = P256K.Context.rawRepresentation
        let privateKey1 = try! P256K.KeyAgreement.PrivateKey()
        let privateKey2 = try! P256K.KeyAgreement.PrivateKey()

        var pub = secp256k1_pubkey()
        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        var sharedSecret2 = [UInt8](repeating: 0, count: 32)

        #expect(secp256k1_ec_pubkey_parse(context, &pub, privateKey1.publicKey.bytes, privateKey1.publicKey.bytes.count) == 1, "Failed to parse public key.")
        #expect(secp256k1_ecdh(context, &sharedSecret2, &pub, privateKey2.baseKey.key.bytes, nil, nil) == 1, "Failed to compute ECDH shared secret.")

        let symmerticKey = SHA256.hash(data: sharedSecret1.bytes)

        #expect(symmerticKey.bytes == sharedSecret2, "Shared secrets do not match.")
    }

    /// Pubkey Combine Bindings Test
    @Test("Pubkey Combine Bindings Test")
    func pubkeyCombineBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubKeyLen = 33
        var cPubKey1 = secp256k1_pubkey()
        var cPubKey2 = secp256k1_pubkey()

        let publicKeyBytes1 = try! "021b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014".bytes
        let publicKeyBytes2 = try! "0260303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752".bytes

        // Verify the context and keys are setup correctly
        #expect(secp256k1_ec_pubkey_parse(context, &cPubKey1, publicKeyBytes1, pubKeyLen) == 1, "Failed to parse the first public key.")
        #expect(secp256k1_ec_pubkey_parse(context, &cPubKey2, publicKeyBytes2, pubKeyLen) == 1, "Failed to parse the second public key.")

        let pubKeys: [UnsafePointer<secp256k1_pubkey>?] = [UnsafePointer(&cPubKey1), UnsafePointer(&cPubKey2)]
        var combinedKey = secp256k1_pubkey()
        var combinedKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        // Combine the two public keys
        #expect(secp256k1_ec_pubkey_combine(context, &combinedKey, pubKeys, 2) == 1, "Failed to combine public keys.")
        #expect(secp256k1_ec_pubkey_serialize(context, &combinedKeyBytes, &pubKeyLen, &combinedKey, P256K.Format.compressed.rawValue) == 1, "Failed to serialize the combined public key.")

        // Define the expected combined key
        let expectedCombinedKey = try! "03d6a3a9d62c7650fcac18f9ee68c7a004ebad71b7581b683062213ad9f37ddb28".bytes

        #expect(combinedKeyBytes == expectedCombinedKey, "Combined public key does not match the expected value.")
    }
}
