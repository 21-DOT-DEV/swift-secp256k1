import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(secp256k1Tests.allTests),
    ]
}
#endif
