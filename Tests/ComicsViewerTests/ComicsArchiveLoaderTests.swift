import XCTest
@testable import ComicsViewer

final class ComicsArchiveLoaderTests: XCTestCase {
    private var testRoot: URL!

    override func setUpWithError() throws {
        testRoot = try makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        if let testRoot {
            try? FileManager.default.removeItem(at: testRoot)
        }
    }

    func testLoadsArchiveAndOwnsExtractedResources() throws {
        let source = testRoot.appendingPathComponent("valid.comics")
        try makeArchive(at: source, entries: [
            .init(path: "data.json", data: makeComicsJSON(width: 320, height: 640)),
            .init(path: "layers/" , type: .directory),
            .init(path: "layers/tile.png", data: Data([1, 2, 3])),
            .init(path: "sounds/" , type: .directory),
            .init(path: "sounds/test.mp3", data: Data([4, 5, 6])),
        ])

        let session = try ComicsArchiveLoader(temporaryDirectory: testRoot).loadArchive(at: source)

        XCTAssertEqual(session.comics.width, 320)
        XCTAssertEqual(session.comics.height, 640)
        XCTAssertTrue(FileManager.default.fileExists(atPath: session.rootURL.appendingPathComponent("layers/tile.png").path))
        XCTAssertEqual(session.resources.currentArchiveURL, session.rootURL)
    }

    func testMapsMissingAndInvalidInputsToTypedErrors() throws {
        let loader = ComicsArchiveLoader(temporaryDirectory: testRoot)
        XCTAssertThrowsError(try loader.loadArchive(at: testRoot.appendingPathComponent("missing.comics"))) {
            guard case ComicsViewerError.fileNotFound = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }

        let invalid = testRoot.appendingPathComponent("invalid.comics")
        try Data("not a zip".utf8).write(to: invalid)
        XCTAssertThrowsError(try loader.loadArchive(at: invalid)) {
            guard case ComicsViewerError.invalidArchive = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testRejectsMissingAndMalformedDataJSON() throws {
        let missing = testRoot.appendingPathComponent("missing-data.comics")
        try makeArchive(at: missing, entries: [.init(path: "layers/a", data: Data([1]))])
        XCTAssertThrowsError(try ComicsArchiveLoader(temporaryDirectory: testRoot).loadArchive(at: missing)) {
            guard case ComicsViewerError.missingDataJSON = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }

        let malformed = testRoot.appendingPathComponent("malformed.comics")
        try makeArchive(at: malformed, entries: [.init(path: "data.json", data: Data("{}".utf8))])
        XCTAssertThrowsError(try ComicsArchiveLoader(temporaryDirectory: testRoot).loadArchive(at: malformed)) {
            guard case ComicsViewerError.invalidComicsData = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testRejectsTraversalAndSymlinkEntries() throws {
        let traversal = testRoot.appendingPathComponent("traversal.comics")
        try makeArchive(at: traversal, entries: [
            .init(path: "data.json", data: makeComicsJSON()),
            .init(path: "../escape", data: Data([1])),
        ])
        XCTAssertThrowsError(try ComicsArchiveLoader(temporaryDirectory: testRoot).loadArchive(at: traversal)) {
            guard case ComicsViewerError.unsafeArchiveEntry("../escape") = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }

        let symlink = testRoot.appendingPathComponent("symlink.comics")
        try makeArchive(at: symlink, entries: [
            .init(path: "data.json", data: makeComicsJSON()),
            .init(path: "link", type: .symlink, data: Data("../escape".utf8)),
        ])
        XCTAssertThrowsError(try ComicsArchiveLoader(temporaryDirectory: testRoot).loadArchive(at: symlink)) {
            guard case ComicsViewerError.unsafeArchiveEntry("link") = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testEnforcesEntryCountEntrySizeAndTotalSizeLimits() throws {
        let archive = testRoot.appendingPathComponent("limits.comics")
        try makeArchive(at: archive, entries: [
            .init(path: "data.json", data: makeComicsJSON()),
            .init(path: "layers/a", data: Data(repeating: 1, count: 16)),
        ])

        let countLoader = ComicsArchiveLoader(
            temporaryDirectory: testRoot,
            limits: .init(maximumEntryCount: 1, maximumEntrySize: 1_024, maximumTotalSize: 2_048)
        )
        assertLimitError(from: countLoader, archive: archive)

        let entryLoader = ComicsArchiveLoader(
            temporaryDirectory: testRoot,
            limits: .init(maximumEntryCount: 10, maximumEntrySize: 15, maximumTotalSize: 2_048)
        )
        assertLimitError(from: entryLoader, archive: archive)

        let totalLoader = ComicsArchiveLoader(
            temporaryDirectory: testRoot,
            limits: .init(maximumEntryCount: 10, maximumEntrySize: 1_024, maximumTotalSize: 20)
        )
        assertLimitError(from: totalLoader, archive: archive)
    }

    func testFailureRemovesPartialSessionDirectory() throws {
        let source = testRoot.appendingPathComponent("malformed.comics")
        try makeArchive(at: source, entries: [
            .init(path: "data.json", data: Data("{}".utf8)),
            .init(path: "layers/a", data: Data([1, 2, 3])),
        ])
        let before = try Set(FileManager.default.contentsOfDirectory(atPath: testRoot.path))

        XCTAssertThrowsError(try ComicsArchiveLoader(temporaryDirectory: testRoot).loadArchive(at: source))

        let after = try Set(FileManager.default.contentsOfDirectory(atPath: testRoot.path))
        XCTAssertEqual(after, before)
    }

    private func assertLimitError(from loader: ComicsArchiveLoader, archive: URL) {
        XCTAssertThrowsError(try loader.loadArchive(at: archive)) {
            guard case ComicsViewerError.archiveLimitExceeded = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }
}
