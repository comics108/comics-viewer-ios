//
//  ComicsViewerController.swift
//  ComicsViewer
//
//  Simplified controller for comics playback.
//  Provides a unified API matching Android/Flutter/React Native interfaces.
//

import Foundation

#if canImport(UIKit)
import UIKit

public class ComicsViewerController {
    // MARK: - Properties
    private let scrollView: ImageScrollView
    private var comics: Comics?
    private var playbackTimer: Timer?
    private var _isPlaying: Bool = false

    // Playback settings
    private static let playbackInterval: TimeInterval = 0.016 // ~60 FPS
    private static let scrollSpeed: CGFloat = 2.0 // pixels per frame

    // Callbacks
    public var onScrollChanged: ((CGFloat) -> Void)?

    // Read-only properties
    public var isPlaying: Bool {
        return _isPlaying
    }

    public var duration: CGFloat {
        return comics?.height ?? 0
    }

    public var currentPosition: CGFloat {
        return scrollView.contentOffset.y
    }

    // MARK: - Initialization

    public init(scrollView: ImageScrollView) {
        self.scrollView = scrollView
        setupScrollViewDelegate()
    }

    private func setupScrollViewDelegate() {
        scrollView.scrollDelegate = self
    }

    // MARK: - Load and Display

    /**
     * Load comics from file path.
     */
    public func loadComics(filePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
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

            guard let comics = ArchiveManager.loadComics(from: fileURL) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ComicsViewer", code: 500,
                                                userInfo: [NSLocalizedDescriptionKey: "Failed to load comics"])))
                }
                return
            }

            DispatchQueue.main.async {
                self.comics = comics
                self.scrollView.comics = comics
                completion(.success(()))
            }
        }
    }

    // MARK: - Playback Control

    /**
     * Start auto-scroll playback.
     */
    public func play() {
        guard !_isPlaying, comics != nil else { return }

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
        guard _isPlaying else { return }

        let currentScroll = scrollView.contentOffset.y
        let newScroll = currentScroll + Self.scrollSpeed

        if newScroll >= duration {
            // Reached end
            pause()
            return
        }

        setScrollPosition(newScroll)
        onScrollChanged?(newScroll)
    }

    // MARK: - Navigation

    /**
     * Set scroll position.
     */
    public func setScrollPosition(_ position: CGFloat) {
        let boundedPosition = max(0, min(position, duration))
        scrollView.setContentOffset(CGPoint(x: 0, y: boundedPosition), animated: false)

        // Process comics at this position
        comics?.process(at: Int(boundedPosition))
    }

    /**
     * Get current scroll position.
     */
    public func getScrollPosition() -> CGFloat {
        return scrollView.contentOffset.y
    }

    // MARK: - Preview & Sound

    /**
     * Toggle preview layers visibility.
     */
    public func togglePreview(_ show: Bool) {
        comics?.setPreview(show)
        scrollView.setNeedsDisplay()
    }

    /**
     * Toggle sound playback.
     */
    public func toggleSounds(_ enabled: Bool) {
        scrollView.soundEnabled = enabled
        comics?.setSoundEnabled(enabled)
    }

    // MARK: - Language & Cleanup

    /**
     * Set language index (0-based).
     */
    public func setLanguage(_ languageIndex: Int) {
        scrollView.languageIndex = languageIndex
    }

    /**
     * Release resources.
     */
    public func dispose() {
        pause()
        comics?.dispose()
        comics = nil
    }
}

// MARK: - ImageScrollViewDelegate

extension ComicsViewerController: ImageScrollViewDelegate {
    public func imageScrollViewDidScroll(_ view: ImageScrollView) {
        onScrollChanged?(view.contentOffset.y)
    }
}

#endif
