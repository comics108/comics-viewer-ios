//
//  PuzzleViewerController.swift
//  ComicsViewer
//
//  Simplified controller for puzzle interaction.
//  Provides a unified API matching Android/Flutter/React Native interfaces.
//

import Foundation

#if canImport(UIKit)
import UIKit

public class PuzzleViewerController {
    // MARK: - Properties
    private var puzzle: Puzzle?
    private var pieceComics: [Int: Comics] = [:] // Map piece ID to Comics
    private var pieceScrollViews: [Int: ImageScrollView] = [:] // Map piece ID to ScrollView
    private var _currentPieceIndex: Int = 0
    private var playbackTimer: Timer?
    private var _isPlaying: Bool = false

    // Playback settings
    private static let playbackInterval: TimeInterval = 0.016 // ~60 FPS
    private static let scrollSpeed: CGFloat = 2.0 // pixels per frame

    // Callbacks
    public var onPieceSelected: ((Int) -> Void)?

    // Read-only properties
    public var currentPieceIndex: Int {
        return _currentPieceIndex
    }

    public var totalPieces: Int {
        return puzzle?.pieces.count ?? 0
    }

    // MARK: - Initialization

    public init() {
        // Empty initializer
    }

    // MARK: - Load and Display

    /**
     * Load puzzle from file path.
     */
    public func loadPuzzle(filePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileURL = URL(fileURLWithPath: filePath)

            guard FileManager.default.fileExists(atPath: filePath) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ComicsViewer", code: 404,
                                                userInfo: [NSLocalizedDescriptionKey: "File not found: \(filePath)"])))
                }
                return
            }

            // Load puzzle metadata
            guard let puzzleData = try? Data(contentsOf: fileURL),
                  let puzzle = try? JSONDecoder().decode(Puzzle.self, from: puzzleData) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ComicsViewer", code: 500,
                                                userInfo: [NSLocalizedDescriptionKey: "Failed to parse puzzle data"])))
                }
                return
            }

            // Load comics for each piece
            let puzzleDir = fileURL.deletingLastPathComponent()
            var loadedComics: [Int: Comics] = [:]

            for piece in puzzle.pieces {
                let pieceFileURL = puzzleDir.appendingPathComponent(piece.file)
                if let comics = ArchiveManager.loadComics(from: pieceFileURL) {
                    loadedComics[piece.id] = comics
                }
            }

            DispatchQueue.main.async {
                self.puzzle = puzzle
                self.pieceComics = loadedComics

                // Create scroll views for each piece
                for piece in puzzle.pieces {
                    if let comics = loadedComics[piece.id] {
                        let scrollView = ImageScrollView()
                        scrollView.comics = comics
                        self.pieceScrollViews[piece.id] = scrollView
                    }
                }

                // Select first piece
                if !puzzle.pieces.isEmpty {
                    self._currentPieceIndex = 0
                }

                completion(.success(()))
            }
        }
    }

    // MARK: - Piece Navigation

    /**
     * Select piece by index.
     */
    public func selectPiece(_ index: Int) {
        guard let puzzle = puzzle, index >= 0, index < puzzle.pieces.count else {
            return
        }

        pause() // Stop playback when changing pieces

        _currentPieceIndex = index
        onPieceSelected?(index)
    }

    // MARK: - Playback Control

    /**
     * Start auto-scroll playback for current piece.
     */
    public func play() {
        guard !_isPlaying, let currentComics = getCurrentComics() else { return }

        _isPlaying = true
        playbackTimer = Timer.scheduledTimer(withTimeInterval: Self.playbackInterval, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    /**
     * Pause playback.
     */
    public func pause() {
        _isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlayback() {
        guard _isPlaying,
              let scrollView = getCurrentScrollView(),
              let comics = getCurrentComics() else {
            pause()
            return
        }

        let currentScroll = scrollView.contentOffset.y
        let newScroll = currentScroll + Self.scrollSpeed

        if newScroll >= CGFloat(comics.height) {
            // Reached end of current piece
            pause()
            return
        }

        scrollView.setContentOffset(CGPoint(x: 0, y: newScroll), animated: false)
        comics.process(at: Int(newScroll))
    }

    // MARK: - Preview & Sound

    /**
     * Toggle preview layers visibility for all pieces.
     */
    public func togglePreview(_ show: Bool) {
        for (_, comics) in pieceComics {
            comics.setPreview(show)
        }

        for (_, scrollView) in pieceScrollViews {
            scrollView.setNeedsDisplay()
        }
    }

    /**
     * Toggle sound playback for all pieces.
     */
    public func toggleSounds(_ enabled: Bool) {
        for (_, scrollView) in pieceScrollViews {
            scrollView.soundEnabled = enabled
        }

        for (_, comics) in pieceComics {
            comics.setSoundEnabled(enabled)
        }
    }

    // MARK: - Cleanup

    /**
     * Release resources.
     */
    public func dispose() {
        pause()

        for (_, comics) in pieceComics {
            comics.dispose()
        }

        pieceComics.removeAll()
        pieceScrollViews.removeAll()
        puzzle = nil
    }

    // MARK: - Helper Methods

    /**
     * Get current piece comics.
     */
    private func getCurrentComics() -> Comics? {
        guard let puzzle = puzzle, _currentPieceIndex < puzzle.pieces.count else {
            return nil
        }
        let pieceId = puzzle.pieces[_currentPieceIndex].id
        return pieceComics[pieceId]
    }

    /**
     * Get current piece scroll view.
     */
    private func getCurrentScrollView() -> ImageScrollView? {
        guard let puzzle = puzzle, _currentPieceIndex < puzzle.pieces.count else {
            return nil
        }
        let pieceId = puzzle.pieces[_currentPieceIndex].id
        return pieceScrollViews[pieceId]
    }

    /**
     * Get scroll view for piece index (for adding to layout).
     */
    public func getScrollView(forPieceIndex index: Int) -> ImageScrollView? {
        guard let puzzle = puzzle, index >= 0, index < puzzle.pieces.count else {
            return nil
        }
        let pieceId = puzzle.pieces[index].id
        return pieceScrollViews[pieceId]
    }

    /**
     * Get current scroll view (for adding to layout).
     */
    public func getCurrentScrollView() -> ImageScrollView? {
        return getScrollView(forPieceIndex: _currentPieceIndex)
    }

    /**
     * Get puzzle model.
     */
    public func getPuzzle() -> Puzzle? {
        return puzzle
    }
}

#endif
