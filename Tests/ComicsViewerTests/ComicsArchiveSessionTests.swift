import XCTest
@testable import ComicsViewer

final class ComicsArchiveSessionTests: XCTestCase {
    func testSessionsHaveDistinctRootsAndDisposeOnlyTheirOwnRoot() throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let firstRoot = parent.appendingPathComponent("first", isDirectory: true)
        let secondRoot = parent.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondRoot, withIntermediateDirectories: true)

        let first = ComicsArchiveSession(rootURL: firstRoot, comics: try decodeTestComics())
        let second = ComicsArchiveSession(rootURL: secondRoot, comics: try decodeTestComics())

        XCTAssertNotEqual(first.rootURL, second.rootURL)
        first.dispose()
        first.dispose()

        XCTAssertFalse(FileManager.default.fileExists(atPath: firstRoot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondRoot.path))
        withExtendedLifetime(second) {}
    }
}
