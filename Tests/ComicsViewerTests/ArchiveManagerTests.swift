import XCTest
@testable import ComicsViewer

final class ArchiveManagerTests: XCTestCase {
    func testRootBoundManagersResolveCollidingSoundNamesIndependently() throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let firstRoot = parent.appendingPathComponent("first", isDirectory: true)
        let secondRoot = parent.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstRoot.appendingPathComponent("sounds"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondRoot.appendingPathComponent("sounds"), withIntermediateDirectories: true)
        try Data([1]).write(to: firstRoot.appendingPathComponent("sounds/shared.mp3"))
        try Data([2]).write(to: secondRoot.appendingPathComponent("sounds/shared.mp3"))

        var firstURL: URL?
        var secondURL: URL?
        ArchiveManager(rootURL: firstRoot).sound(name: "shared.mp3") { firstURL = $0 }
        ArchiveManager(rootURL: secondRoot).sound(name: "shared.mp3") { secondURL = $0 }

        XCTAssertEqual(try firstURL.map { try Data(contentsOf: $0) }, Data([1]))
        XCTAssertEqual(try secondURL.map { try Data(contentsOf: $0) }, Data([2]))
    }

    func testRejectsResourceTraversal() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let callback = expectation(description: "unsafe callback")
        callback.isInverted = true

        ArchiveManager(rootURL: root).sound(name: "../outside.mp3") { _ in callback.fulfill() }

        wait(for: [callback], timeout: 0.05)
    }
}
