// MARK: - Test Vector Protocols

// These protocol definitions serve as contracts for the test infrastructure.
// Implementation will be in Projects/Sources/TestShared/

import Foundation

// MARK: - Test Vector Loading

/// Protocol for loading test vectors from bundle resources
protocol TestVectorLoader {
    associatedtype VectorType: Decodable

    /// Loads and decodes test vectors from a JSON file in the bundle
    /// - Parameter filename: Name of the JSON file (without extension)
    /// - Returns: Decoded test vector container
    /// - Throws: TestVectorError if file is missing or malformed
    func load(from filename: String) throws -> VectorType
}

/// Protocol for filtering test vectors based on flags
protocol TestVectorFilter {
    associatedtype VectorType

    /// Filters vectors based on supported flags
    /// - Parameter vectors: Array of test vectors to filter
    /// - Returns: Filtered vectors with skip reasons for excluded items
    func filter(_ vectors: [VectorType]) -> FilteredVectors<VectorType>
}

/// Result of filtering test vectors
struct FilteredVectors<T> {
    /// Vectors that should be executed
    let included: [T]

    /// Vectors that were skipped with reasons
    let skipped: [(vector: T, reason: String)]
}

// MARK: - Test Vector Errors

/// Errors that can occur during test vector loading
enum TestVectorError: Error, CustomStringConvertible {
    /// JSON file not found in bundle
    case fileNotFound(filename: String)

    /// JSON file exists but could not be decoded
    case decodingFailed(filename: String, underlyingError: Error)

    /// Vector contains unsupported data
    case unsupportedVector(tcId: Int, reason: String)

    var description: String {
        switch self {
        case let .fileNotFound(filename):
            return "Test vector file not found: \(filename).json"
        case let .decodingFailed(filename, error):
            return "Failed to decode \(filename).json: \(error)"
        case let .unsupportedVector(tcId, reason):
            return "Unsupported vector tcId=\(tcId): \(reason)"
        }
    }
}

// MARK: - Test Vector Assertions

/// Protocol for cryptographic test assertions with verbose diagnostics
protocol TestVectorAssertion {
    /// Asserts that two byte arrays are equal with verbose hex dump on failure
    /// - Parameters:
    ///   - expected: Expected byte array
    ///   - actual: Actual byte array
    ///   - context: Description of what is being compared (e.g., "signature r-component")
    ///   - vectorId: Test vector identifier for error reporting
    ///   - file: Source file (auto-filled)
    ///   - line: Source line (auto-filled)
    func assertEqual(
        expected: [UInt8],
        actual: [UInt8],
        context: String,
        vectorId: String,
        file: StaticString,
        line: UInt
    )

    /// Asserts that a signature verification result matches expected
    /// - Parameters:
    ///   - expected: Expected verification result (true = valid)
    ///   - actual: Actual verification result
    ///   - vectorId: Test vector identifier
    ///   - publicKey: Public key used (hex) for diagnostics
    ///   - message: Message signed (hex) for diagnostics
    ///   - signature: Signature verified (hex) for diagnostics
    ///   - file: Source file (auto-filled)
    ///   - line: Source line (auto-filled)
    func assertVerification(
        expected: Bool,
        actual: Bool,
        vectorId: String,
        publicKey: String,
        message: String,
        signature: String,
        file: StaticString,
        line: UInt
    )

    /// Asserts that an ECDH shared secret matches expected
    /// - Parameters:
    ///   - expected: Expected shared secret (hex)
    ///   - actual: Actual shared secret (hex)
    ///   - vectorId: Test vector identifier
    ///   - publicKey: Public key used (hex) for diagnostics
    ///   - file: Source file (auto-filled)
    ///   - line: Source line (auto-filled)
    func assertSharedSecret(
        expected: String,
        actual: String,
        vectorId: String,
        publicKey: String,
        file: StaticString,
        line: UInt
    )
}

// MARK: - Hex Utilities

// NOTE: HexConvertible protocol NOT NEEDED — reuse existing utilities:
//   - Sources/Shared/swift-crypto/Sources/Crypto/Util/PrettyBytes.swift
//     → DataProtocol.hexString, Data(hexString:), Array<UInt8>(hexString:)
//   - Sources/Shared/Utility.swift
//     → String(bytes:), String.bytes

// MARK: - Wycheproof Result Handling

/// Protocol for handling Wycheproof result types
protocol WycheproofResultHandler {
    /// Determines if a test vector should pass based on result and flags
    /// - Parameters:
    ///   - result: Wycheproof result string ("valid", "invalid", "acceptable")
    ///   - flags: Array of flags for the test vector
    /// - Returns: Tuple of (shouldPass: Bool, skipReason: String?)
    func shouldPass(result: String, flags: [String]) -> (shouldPass: Bool, skipReason: String?)

    /// List of flags that indicate unsupported features (vectors will be skipped)
    var unsupportedFlags: Set<String> { get }
}

// MARK: - Native Test Runner

/// Protocol for running native C test binaries
protocol NativeTestRunner {
    /// Runs the native secp256k1 test binary
    /// - Returns: Test result with pass/fail status and output
    /// - Throws: If binary cannot be executed
    func runNativeTests() throws -> NativeTestResult
}

/// Result of running native tests
struct NativeTestResult {
    /// Whether all tests passed
    let passed: Bool

    /// Number of tests run
    let testsRun: Int

    /// Number of tests failed
    let testsFailed: Int

    /// Standard output from test binary
    let output: String

    /// Standard error from test binary
    let errorOutput: String

    /// Execution time in seconds
    let executionTime: TimeInterval
}
