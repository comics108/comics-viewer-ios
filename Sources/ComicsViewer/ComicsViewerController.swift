//
//  ComicsViewerController.swift
//  ComicsViewer
//
//  Unified controller used by native, Flutter, and React Native consumers.
//

import Foundation

#if canImport(UIKit)
import UIKit

public class ComicsViewerController {
    private let scrollView: ImageScrollView
    private let archiveLoader: ComicsArchiveLoading
    private let loadQueue: DispatchQueue

    private var session: ComicsArchiveSession?
    private var playbackTimer: Timer?
    private var loadGeneration: UInt64 = 0
    private var disposed = false
    private var storedPreview = true
    private var storedSounds = true
    private var storedLanguage = 0
    private var _isPlaying = false

    private static let playbackInterval: TimeInterval = 0.016
    private static let scrollSpeed: CGFloat = 2

    public var onScrollChanged: ((CGFloat) -> Void)?

    public var isPlaying: Bool { _isPlaying }
    public var duration: CGFloat { CGFloat(session?.comics.height ?? 0) }
    public var currentPosition: CGFloat { scrollView.contentOffset.y }

    public init(scrollView: ImageScrollView) {
        self.scrollView = scrollView
        self.archiveLoader = ComicsArchiveLoader()
        self.loadQueue = DispatchQueue(label: "net.nativemind.comics.viewer.load", qos: .userInitiated)
        self.scrollView.scrollDelegate = self
    }

    init(
        scrollView: ImageScrollView,
        archiveLoader: ComicsArchiveLoading,
        loadQueue: DispatchQueue
    ) {
        self.scrollView = scrollView
        self.archiveLoader = archiveLoader
        self.loadQueue = loadQueue
        self.scrollView.scrollDelegate = self
    }

    public func loadComics(
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
            let sourceURL = URL(fileURLWithPath: filePath)
            let loader = self.archiveLoader

            self.loadQueue.async { [weak self] in
                let result = Result { try loader.loadArchive(at: sourceURL) }
                DispatchQueue.main.async {
                    guard let self else {
                        if case .success(let abandonedSession) = result {
                            abandonedSession.dispose()
                        }
                        completion(.failure(ComicsViewerError.disposed))
                        return
                    }
                    self.finishLoad(result, generation: generation, completion: completion)
                }
            }
        }
    }

    private func finishLoad(
        _ result: Result<ComicsArchiveSession, Error>,
        generation: UInt64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        precondition(Thread.isMainThread)
        guard !disposed, generation == loadGeneration else {
            if case .success(let staleSession) = result {
                staleSession.dispose()
            }
            completion(.failure(disposed ? ComicsViewerError.disposed : CancellationError()))
            return
        }

        switch result {
        case .failure(let error):
            completion(.failure(error))
        case .success(let newSession):
            pauseNow()
            scrollView.dispose()
            session?.dispose()
            session = newSession
            scrollView.scrollDelegate = self
            scrollView.showPreview = storedPreview
            scrollView.soundEnabled = storedSounds
            scrollView.languageIndex = storedLanguage
            scrollView.install(comics: newSession.comics, resources: newSession.resources)
            completion(.success(()))
        }
    }

    public func play() {
        onMain { [weak self] in self?.playNow() }
    }

    private func playNow() {
        guard !disposed, !_isPlaying, session != nil else { return }
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
        guard _isPlaying else { return }
        let newPosition = scrollView.contentOffset.y + Self.scrollSpeed
        guard newPosition < duration else {
            pauseNow()
            return
        }
        setScrollPositionNow(newPosition)
    }

    public func setScrollPosition(_ position: CGFloat) {
        onMain { [weak self] in self?.setScrollPositionNow(position) }
    }

    private func setScrollPositionNow(_ position: CGFloat) {
        guard !disposed, session != nil else { return }
        let boundedPosition = max(0, min(position, duration))
        scrollView.setContentOffset(CGPoint(x: 0, y: boundedPosition), animated: false)
        scrollView.loadComics(scrollView: scrollView, sound: true)
    }

    public func getScrollPosition() -> CGFloat {
        currentPosition
    }

    public func togglePreview(_ show: Bool) {
        onMain { [weak self] in
            guard let self, !self.disposed else { return }
            self.storedPreview = show
            self.scrollView.showPreview = show
        }
    }

    public func toggleSounds(_ enabled: Bool) {
        onMain { [weak self] in
            guard let self, !self.disposed else { return }
            self.storedSounds = enabled
            self.scrollView.soundEnabled = enabled
        }
    }

    public func setLanguage(_ languageIndex: Int) {
        onMain { [weak self] in
            guard let self, !self.disposed else { return }
            self.storedLanguage = max(0, languageIndex)
            self.scrollView.languageIndex = self.storedLanguage
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
        scrollView.dispose()
        session?.dispose()
        session = nil
        onScrollChanged = nil
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

extension ComicsViewerController: ImageScrollViewDelegate {
    public func imageScrollViewDidScroll(_ view: ImageScrollView) {
        guard !disposed else { return }
        onScrollChanged?(view.contentOffset.y)
    }
}

#endif
