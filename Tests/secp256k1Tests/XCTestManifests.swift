import XCTest

#if !canImport(ObjectiveC) && canImport(secp256k1)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(secp256k1Tests.allTests)
        ]
    }

#elseif !canImport(ObjectiveC) && canImport(zkp)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(secp256k1Tests.allTests),
            testCase(zkpTests.allTests)
        ]
    }
#endif
