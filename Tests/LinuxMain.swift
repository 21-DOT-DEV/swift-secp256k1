import XCTest

import secp256k1Tests

var tests = [XCTestCaseEntry]()
tests += secp256k1Tests.allTests()
XCTMain(tests)
