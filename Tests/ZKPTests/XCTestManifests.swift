import XCTest

#if !canImport(ObjectiveC) && canImport(P256K)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(P256K1Tests.allTests)
        ]
    }

#elseif !canImport(ObjectiveC) && canImport(ZKP)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(P256K1Tests.allTests),
            testCase(ZKPTests.allTests)
        ]
    }
#endif
