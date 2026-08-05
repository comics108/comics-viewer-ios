//
//  PuzzleViewerController.swift
//  ComicsViewer
//
//  Puzzle facade sharing the same archive/session renderer as comics.
//

import Foundation

#if canImport(UIKit)
import UIKit

public class PuzzleViewerController {
    private struct LoadedPiece {
        let session: ComicsArchiveSession
        let scrollView: ImageScrollView
    }

    private let archiveLoader: ComicsArchiveLoading
    private let loadQueue: DispatchQueue
    private var puzzle: Puzzle?
    private var loadedPieces: [Int: LoadedPiece] = [:]
    private var _currentPieceIndex = 0
    private var playbackTimer: Timer?
    private var _isPlaying = false
    private var loadGeneration: UInt64 = 0
    private var disposed = false
    private var storedPreview = true
    private var storedSounds = true

    private static let playbackInterval: TimeInterval = 0.016
    private static let scrollSpeed: CGFloat = 2

    public var onPieceSelected: ((Int) -> Void)?
    public var currentPieceIndex: Int { _currentPieceIndex }
    public var totalPieces: Int { puzzle?.pieces.count ?? 0 }

    public init() {
        self.archiveLoader = ComicsArchiveLoader()
        self.loadQueue = DispatchQueue(label: "net.nativemind.comics.viewer.puzzle-load", qos: .userInitiated)
    }

    init(archiveLoader: ComicsArchiveLoading, loadQueue: DispatchQueue) {
        self.archiveLoader = archiveLoader
        self.loadQueue = loadQueue
    }

    public func loadPuzzle(
        filePath: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        onMain { [weak self] in
            guard let self, !self.disposed else {
                completion(.failure(ComicsViewerError.disposed))
                return
            }
            self.loadGeneration &+= 1
            let generation = self.loadGeneration
            let sourceURL = URL(fileURLWithPath: filePath).standardizedFileURL
            let loader = self.archiveLoader

            self.loadQueue.async { [weak self] in
                let result = Result { try Self.loadPuzzle(sourceURL: sourceURL, loader: loader) }
                DispatchQueue.main.async {
                    guard let self else {
                        if case .success((_, let sessions)) = result {
                            sessions.values.forEach { $0.dispose() }
                        }
                        completion(.failure(ComicsViewerError.disposed))
                        return
                    }
                    self.finishLoad(result, generation: generation, completion: completion)
                }
            }
        }
    }

    private static func loadPuzzle(
        sourceURL: URL,
        loader: ComicsArchiveLoading
    ) throws -> (Puzzle, [Int: ComicsArchiveSession]) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw ComicsViewerError.fileNotFound(sourceURL)
        }
        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw ComicsViewerError.unreadableFile(sourceURL)
        }

        let puzzle: Puzzle
        do {
            puzzle = try JSONDecoder().decode(Puzzle.self, from: Data(contentsOf: sourceURL))
        } catch {
            throw ComicsViewerError.invalidPuzzleData(error)
        }

        let baseURL = sourceURL.deletingLastPathComponent().standardizedFileURL
        var sessions: [Int: ComicsArchiveSession] = [:]
        do {
            for piece in puzzle.pieces {
                let pieceURL = baseURL.appendingPathComponent(piece.file).standardizedFileURL
                guard !piece.file.isEmpty,
                      !piece.file.contains("\\"),
                      !(piece.file as NSString).isAbsolutePath,
                      !piece.file.split(separator: "/").contains(".."),
                      pieceURL.path.hasPrefix(baseURL.path + "/"),
                      sessions[piece.id] == nil else {
                    throw ComicsViewerError.missingPuzzlePiece(piece.file)
                }
                do {
                    sessions[piece.id] = try loader.loadArchive(at: pieceURL)
                } catch ComicsViewerError.fileNotFound(_) {
                    throw ComicsViewerError.missingPuzzlePiece(piece.file)
                }
            }
            return (puzzle, sessions)
        } catch {
            sessions.values.forEach { $0.dispose() }
            throw error
        }
    }

    private func finishLoad(
        _ result: Result<(Puzzle, [Int: ComicsArchiveSession]), Error>,
        generation: UInt64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        precondition(Thread.isMainThread)
        guard !disposed, generation == loadGeneration else {
            if case .success((_, let sessions)) = result {
                sessions.values.forEach { $0.dispose() }
            }
            completion(.failure(disposed ? ComicsViewerError.disposed : CancellationError()))
            return
        }

        switch result {
        case .failure(let error):
            completion(.failure(error))
        case .success((let newPuzzle, let sessions)):
            disposeLoadedPieces()
            puzzle = newPuzzle
            _currentPieceIndex = 0
            for piece in newPuzzle.pieces {
                guard let session = sessions[piece.id] else { continue }
                let view = ImageScrollView()
                view.showPreview = storedPreview
                view.soundEnabled = storedSounds
                view.install(comics: session.comics, resources: session.resources)
                loadedPieces[piece.id] = LoadedPiece(session: session, scrollView: view)
            }
            completion(.success(()))
        }
    }

    public func selectPiece(_ index: Int) {
        onMain { [weak self] in
            guard let self,
                  !self.disposed,
                  let puzzle = self.puzzle,
                  index >= 0,
                  index < puzzle.pieces.count else { return }
            self.pauseNow()
            self._currentPieceIndex = index
            self.onPieceSelected?(index)
        }
    }

    public func play() {
        onMain { [weak self] in self?.playNow() }
    }

    private func playNow() {
        guard !disposed, !_isPlaying, currentLoadedPiece() != nil else { return }
        _isPlaying = true
        playbackTimer = Timer.scheduledTimer(withTimeInterval: Self.playbackInterval, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    public func pause() {
        onMain { [weak self] in self?.pauseNow() }
    }

    private func pauseNow() {
        _isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlayback() {
        guard _isPlaying, let loaded = currentLoadedPiece() else {
            pauseNow()
            return
        }
        let newPosition = loaded.scrollView.contentOffset.y + Self.scrollSpeed
        guard newPosition < CGFloat(loaded.session.comics.height) else {
            pauseNow()
            return
        }
        loaded.scrollView.setContentOffset(CGPoint(x: 0, y: newPosition), animated: false)
        loaded.scrollView.loadComics(scrollView: loaded.scrollView, sound: true)
    }

    public func togglePreview(_ show: Bool) {
        onMain { [weak self] in
            guard let self, !self.disposed else { return }
            self.storedPreview = show
            self.loadedPieces.values.forEach { $0.scrollView.showPreview = show }
        }
    }

    public func toggleSounds(_ enabled: Bool) {
        onMain { [weak self] in
            guard let self, !self.disposed else { return }
            self.storedSounds = enabled
            self.loadedPieces.values.forEach { $0.scrollView.soundEnabled = enabled }
        }
    }

    public func dispose() {
        onMain { [weak self] in self?.disposeNow() }
    }

    private func disposeNow() {
        guard !disposed else { return }
        disposed = true
        loadGeneration &+= 1
        pauseNow()
        disposeLoadedPieces()
        puzzle = nil
        onPieceSelected = nil
    }

    private func disposeLoadedPieces() {
        pauseNow()
        for loaded in loadedPieces.values {
            loaded.scrollView.dispose()
            loaded.session.dispose()
        }
        loadedPieces.removeAll()
    }

    private func currentLoadedPiece() -> LoadedPiece? {
        guard let puzzle, _currentPieceIndex >= 0, _currentPieceIndex < puzzle.pieces.count else {
            return nil
        }
        return loadedPieces[puzzle.pieces[_currentPieceIndex].id]
    }

    public func getScrollView(forPieceIndex index: Int) -> ImageScrollView? {
        guard let puzzle, index >= 0, index < puzzle.pieces.count else { return nil }
        return loadedPieces[puzzle.pieces[index].id]?.scrollView
    }

    public func getCurrentScrollView() -> ImageScrollView? {
        currentLoadedPiece()?.scrollView
    }

    public func getPuzzle() -> Puzzle? {
        puzzle
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

#endif
