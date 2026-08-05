#if canImport(UIKit)
import UIKit
import XCTest
@testable import ComicsViewer

@MainActor
final class ComicsViewerControllerTests: XCTestCase {
    func testLoadInstallsSessionAndCompletesOnMain() throws {
        let session = try makeSession()
        let loader = StubArchiveLoader { _ in session }
        let view = ImageScrollView()
        let controller = ComicsViewerController(
            scrollView: view,
            archiveLoader: loader,
            loadQueue: DispatchQueue(label: "controller-test")
        )
        let completed = expectation(description: "load")

        controller.loadComics(filePath: "/tmp/test.comics") { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure(let error) = result {
                XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(controller.duration, 200)
            XCTAssertTrue(view.comics === session.comics)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)
        controller.dispose()
    }

    func testLatestLoadWinsAndStaleCompletionIsCancelled() throws {
        let firstSession = try makeSession()
        let secondSession = try makeSession()
        let firstMayFinish = DispatchSemaphore(value: 0)
        let loader = StubArchiveLoader { url in
            if url.lastPathComponent == "first.comics" {
                _ = firstMayFinish.wait(timeout: .now() + 1)
                return firstSession
            }
            return secondSession
        }
        let controller = ComicsViewerController(
            scrollView: ImageScrollView(),
            archiveLoader: loader,
            loadQueue: DispatchQueue(label: "controller-generation-test", attributes: .concurrent)
        )
        let first = expectation(description: "first")
        let second = expectation(description: "second")

        controller.loadComics(filePath: "/tmp/first.comics") { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected cancellation")
                first.fulfill()
                return
            }
            XCTAssertTrue(error is CancellationError)
            first.fulfill()
        }
        controller.loadComics(filePath: "/tmp/second.comics") { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected error: \(error)")
            }
            second.fulfill()
        }
        firstMayFinish.signal()

        wait(for: [first, second], timeout: 2)
        XCTAssertEqual(controller.duration, 200)
        controller.dispose()
    }

    func testControlsAreSafeBeforeLoadAndDisposeIsIdempotent() {
        let loader = StubArchiveLoader { _ in throw ComicsViewerError.invalidArchive }
        let controller = ComicsViewerController(
            scrollView: ImageScrollView(),
            archiveLoader: loader,
            loadQueue: DispatchQueue(label: "controller-empty-test")
        )

        controller.play()
        controller.pause()
        controller.setScrollPosition(100)
        controller.togglePreview(false)
        controller.toggleSounds(false)
        controller.setLanguage(-1)
        controller.dispose()
        controller.dispose()

        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.duration, 0)
    }
}
#endif
