#if canImport(UIKit)
import UIKit
import XCTest
@testable import ComicsViewer

@MainActor
final class PuzzleViewerControllerTests: XCTestCase {
    func testLoadsOneSessionPerPieceAndSelectsByIndex() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let puzzleURL = root.appendingPathComponent("puzzle.json")
        let pieces = [
            Piece(id: 1, x: 0, y: 0, width: 10, height: 10, file: "one.comics", version: 1, date: Date(), order: 0),
            Piece(id: 2, x: 10, y: 0, width: 10, height: 10, file: "two.comics", version: 1, date: Date(), order: 1),
        ]
        try JSONEncoder().encode(Puzzle(id: 1, name: "test", width: 20, height: 10, order: 0, pieces: pieces)).write(to: puzzleURL)
        let loader = StubArchiveLoader { _ in try makeSession() }
        let controller = PuzzleViewerController(
            archiveLoader: loader,
            loadQueue: DispatchQueue(label: "puzzle-test")
        )
        let loaded = expectation(description: "puzzle")

        controller.loadPuzzle(filePath: puzzleURL.path) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected error: \(error)")
            }
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 1)

        XCTAssertEqual(controller.totalPieces, 2)
        XCTAssertNotNil(controller.getCurrentScrollView())
        XCTAssertNotNil(controller.getScrollView(forPieceIndex: 1))
        controller.selectPiece(1)
        XCTAssertEqual(controller.currentPieceIndex, 1)
        XCTAssertTrue(controller.getCurrentScrollView() === controller.getScrollView(forPieceIndex: 1))
        controller.selectPiece(99)
        XCTAssertEqual(controller.currentPieceIndex, 1)
        controller.dispose()
        controller.dispose()
    }

    func testMissingPieceProducesTypedFailure() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let puzzleURL = root.appendingPathComponent("puzzle.json")
        let piece = Piece(id: 1, x: 0, y: 0, width: 10, height: 10, file: "missing.comics", version: 1, date: Date(), order: 0)
        try JSONEncoder().encode(Puzzle(id: 1, name: "test", width: 10, height: 10, order: 0, pieces: [piece])).write(to: puzzleURL)
        let loader = StubArchiveLoader { url in throw ComicsViewerError.fileNotFound(url) }
        let controller = PuzzleViewerController(
            archiveLoader: loader,
            loadQueue: DispatchQueue(label: "missing-piece-test")
        )
        let completed = expectation(description: "failure")

        controller.loadPuzzle(filePath: puzzleURL.path) { result in
            guard case .failure(let error) = result,
                  case ComicsViewerError.missingPuzzlePiece("missing.comics") = error else {
                XCTFail("Unexpected result: \(result)")
                completed.fulfill()
                return
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)
        controller.dispose()
    }
}
#endif
