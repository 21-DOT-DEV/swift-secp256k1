import XCTest
@_exported import zkp

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(zkpTests.allTests)
        ]
    }
#endif
