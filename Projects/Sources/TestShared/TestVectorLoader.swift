//
//  TestVectorLoader.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// Errors that can occur during test vector loading
public enum TestVectorError: Error, CustomStringConvertible {
    /// JSON file not found in bundle
    case fileNotFound(filename: String)

    /// JSON file exists but could not be decoded
    case decodingFailed(filename: String, underlyingError: Error)

    /// Vector contains unsupported data
    case unsupportedVector(tcId: Int, reason: String)

    public var description: String {
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

/// Result of filtering test vectors
public struct FilteredVectors<T> {
    /// Vectors that should be executed
    public let included: [T]

    /// Vectors that were skipped with reasons
    public let skipped: [(vector: T, reason: String)]

    public init(included: [T], skipped: [(vector: T, reason: String)]) {
        self.included = included
        self.skipped = skipped
    }
}

/// Generic test vector loader for JSON bundle resources
public struct TestVectorLoader<VectorType: Decodable> {
    /// The bundle containing the test vector resources
    private let bundle: Bundle

    /// JSON decoder configured for test vectors
    private let decoder: JSONDecoder

    /// Creates a new loader for the specified bundle
    /// - Parameter bundle: Bundle containing test vector JSON files (default: Bundle.module)
    public init(bundle: Bundle) {
        self.bundle = bundle
        self.decoder = JSONDecoder()
    }

    /// Loads and decodes test vectors from a JSON file in the bundle
    /// - Parameter filename: Name of the JSON file (without extension)
    /// - Returns: Decoded test vector container
    /// - Throws: TestVectorError if file is missing or malformed
    public func load(from filename: String) throws -> VectorType {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw TestVectorError.fileNotFound(filename: filename)
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(VectorType.self, from: data)
        } catch let error as DecodingError {
            throw TestVectorError.decodingFailed(filename: filename, underlyingError: error)
        } catch {
            throw TestVectorError.decodingFailed(filename: filename, underlyingError: error)
        }
    }
}

/// Wycheproof test file container structure
public struct WycheproofTestFile<TestGroup: Decodable>: Decodable {
    public let algorithm: String
    public let numberOfTests: Int
    public let testGroups: [TestGroup]

    public init(algorithm: String, numberOfTests: Int, testGroups: [TestGroup]) {
        self.algorithm = algorithm
        self.numberOfTests = numberOfTests
        self.testGroups = testGroups
    }
}

/// Protocol for handling Wycheproof result types
public protocol WycheproofResultHandler {
    /// List of flags that indicate unsupported features (vectors will be skipped)
    var unsupportedFlags: Set<String> { get }

    /// Determines if a test vector should pass based on result and flags
    /// - Parameters:
    ///   - result: Wycheproof result string ("valid", "invalid", "acceptable")
    ///   - flags: Array of flags for the test vector
    /// - Returns: Tuple of (shouldPass: Bool, skipReason: String?)
    func shouldPass(result: String, flags: [String]) -> (shouldPass: Bool, skipReason: String?)
}

/// Default Wycheproof result handler implementation
public struct DefaultWycheproofHandler: WycheproofResultHandler {
    public let unsupportedFlags: Set<String>

    public init(unsupportedFlags: Set<String> = []) {
        self.unsupportedFlags = unsupportedFlags
    }

    public func shouldPass(result: String, flags: [String]) -> (shouldPass: Bool, skipReason: String?) {
        // Check for unsupported flags
        let unsupported = flags.filter { unsupportedFlags.contains($0) }
        if !unsupported.isEmpty {
            return (false, "Unsupported flags: \(unsupported.joined(separator: ", "))")
        }

        // Determine expected result based on Wycheproof convention
        switch result.lowercased() {
        case "valid":
            return (true, nil)
        case "invalid":
            return (false, nil)
        case "acceptable":
            // Acceptable means the implementation may accept or reject
            // We treat as valid but note it's acceptable
            return (true, nil)
        default:
            return (false, "Unknown result type: \(result)")
        }
    }
}

/// Filters test vectors based on supported flags
public struct TestVectorFilter<T> {
    private let handler: WycheproofResultHandler
    private let getFlags: (T) -> [String]
    private let getResult: (T) -> String

    public init(
        handler: WycheproofResultHandler,
        getFlags: @escaping (T) -> [String],
        getResult: @escaping (T) -> String
    ) {
        self.handler = handler
        self.getFlags = getFlags
        self.getResult = getResult
    }

    /// Filters vectors based on supported flags
    /// - Parameter vectors: Array of test vectors to filter
    /// - Returns: Filtered vectors with skip reasons for excluded items
    public func filter(_ vectors: [T]) -> FilteredVectors<T> {
        var included: [T] = []
        var skipped: [(vector: T, reason: String)] = []

        for vector in vectors {
            let flags = getFlags(vector)
            let result = getResult(vector)
            let (_, skipReason) = handler.shouldPass(result: result, flags: flags)

            if let reason = skipReason, handler.unsupportedFlags.intersection(Set(flags)).isEmpty == false {
                skipped.append((vector, reason))
            } else {
                included.append(vector)
            }
        }

        return FilteredVectors(included: included, skipped: skipped)
    }
}
