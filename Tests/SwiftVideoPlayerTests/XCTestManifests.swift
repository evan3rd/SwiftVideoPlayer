import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftVideoPlayerTests.allTests),
    ]
}
#endif
