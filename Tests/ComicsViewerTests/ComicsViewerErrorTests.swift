import XCTest
@testable import ComicsViewer

final class ComicsViewerErrorTests: XCTestCase {
    func testStableLocalizedDescriptions() {
        let url = URL(fileURLWithPath: "/tmp/missing.comics")

        XCTAssertEqual(
            ComicsViewerError.fileNotFound(url).localizedDescription,
            "File not found: /tmp/missing.comics"
        )
        XCTAssertEqual(
            ComicsViewerError.unsafeArchiveEntry("../escape").localizedDescription,
            "The archive contains an unsafe entry: ../escape"
        )
        XCTAssertEqual(
            ComicsViewerError.archiveLimitExceeded.localizedDescription,
            "The archive exceeds the allowed extraction limits."
        )
        XCTAssertEqual(
            ComicsViewerError.disposed.localizedDescription,
            "The viewer has been disposed."
        )
    }
}
