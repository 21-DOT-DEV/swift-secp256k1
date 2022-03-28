import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(secp256k1Tests.allTests)
        ]
    }
#endif
