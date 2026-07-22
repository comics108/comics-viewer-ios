# ComicsViewer Swift Package

A standalone Swift Package for rendering interactive comics and puzzles on iOS and macOS.

## Features

- **Comics Rendering**: Display animated comics with automatic scroll and sound synchronization
- **Puzzle Support**: Render interactive puzzle grids with piece navigation
- **Sound Playback**: Position-synchronized audio playback with fade effects
- **Tiled Images**: Efficient memory usage with CATiledLayer (512x512 tiles)
- **Animations**: Alpha, translate, scale, rotate, and sound animations with cubic easing
- **Cross-Platform**: Compatible with iOS 13.0+, macOS 10.15+
- **Local Files Only**: Works with local .comics files (ZIP archives), no network dependencies
- **Simple API**: Just 5 main methods for comics playback control

## Installation

### Swift Package Manager

**1. Add to Xcode project:**

- File → Add Package Dependencies
- Add Local → select `libs/comics_viewer/comics-viewer-ios`
- Link `ComicsViewer` to your target

**2. Or add to Package.swift:**

```swift
dependencies: [
    .package(path: "../path/to/comics-viewer-ios")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ComicsViewer"]
    )
]
```

## Quick Start

```swift
import UIKit
import ComicsViewer

class ComicsViewController: UIViewController {
    private let scrollView = ImageScrollView()
    private var controller: ComicsViewerController!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        scrollView.frame = view.bounds

        controller = ComicsViewerController(scrollView: scrollView)

        controller.loadComics(filePath: "/path/to/episode.comics") { result in
            switch result {
            case .success:
                self.controller.play()
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.dispose()
    }
}
```

## Public API

### ComicsViewerController

Main controller for comics playback (simplified API matching Android/Flutter/React Native).

#### Methods

**1. Load and Display**

```swift
controller.loadComics(filePath: String, completion: @escaping (Result<Void, Error>) -> Void)

// Example
controller.loadComics(filePath: comicsPath) { result in
    switch result {
    case .success:
        print("Comics loaded!")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

**2. Playback Control**

```swift
// Start auto-scroll playback
controller.play()

// Pause playback
controller.pause()
```

**3. Navigation**

```swift
// Set scroll position (0.0 to duration)
controller.setScrollPosition(500.0)

// Get current scroll position
let position = controller.getScrollPosition()
```

**4. Preview & Sound**

```swift
// Toggle preview layers visibility
controller.togglePreview(true)   // Show preview
controller.togglePreview(false)  // Hide preview

// Toggle sound playback
controller.toggleSounds(true)    // Enable sounds
controller.toggleSounds(false)   // Disable sounds
```

**5. Language & Cleanup**

```swift
// Set language (0-based index)
controller.setLanguage(0)

// Release resources (call in viewWillDisappear)
controller.dispose()
```

#### Properties (Read-Only)

```swift
// Check if currently playing
let playing = controller.isPlaying

// Get total scrollable height
let totalHeight = controller.duration

// Get current position
let currentPos = controller.currentPosition
```

#### Callbacks

```swift
// Listen to scroll changes
controller.onScrollChanged = { position in
    // Update progress bar
    print("Position: \(position)")
}
```

## Puzzle API

### PuzzleViewerController

Controller for puzzle interaction.

```swift
let puzzleController = PuzzleViewerController()

// Load puzzle file
puzzleController.loadPuzzle(filePath: "/path/to/puzzle.puzzle") { result in
    switch result {
    case .success:
        puzzleController.selectPiece(0)
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Navigate to piece by index
puzzleController.selectPiece(5)

// Get current piece
let currentPiece = puzzleController.currentPieceIndex

// Get total pieces count
let totalPieces = puzzleController.totalPieces

// Control playback for current piece
puzzleController.play()
puzzleController.pause()

// Toggle preview/sounds for all pieces
puzzleController.togglePreview(true)
puzzleController.toggleSounds(false)

// Cleanup
puzzleController.dispose()
```

### Puzzle Callbacks

```swift
puzzleController.onPieceSelected = { index in
    print("Selected piece: \(index)")
}
```

## File Format

### .comics File

A .comics file is a ZIP archive containing:

- `data.json` - Comics structure and metadata
- `layers/` - Layer images (PNG)
- `sounds/` - Audio files (MP3)

**Example usage:**

```swift
// From app bundle
let comicsPath = Bundle.main.path(forResource: "episode", ofType: "comics")!

// From documents directory
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let comicsPath = documentsPath.appendingPathComponent("episode.comics").path
```

## Complete Example

```swift
import UIKit
import ComicsViewer

class ComicsPlayerViewController: UIViewController {
    private let scrollView = ImageScrollView()
    private var controller: ComicsViewerController!
    private let playPauseButton = UIButton(type: .system)
    private var isPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Setup play/pause button
        view.addSubview(playPauseButton)
        playPauseButton.frame = CGRect(x: 0, y: 0, width: 100, height: 44)
        playPauseButton.center = CGPoint(x: view.bounds.midX, y: view.bounds.maxY - 50)
        playPauseButton.setTitle("Pause", for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)

        // Initialize controller
        controller = ComicsViewerController(scrollView: scrollView)

        // Setup scroll listener
        controller.onScrollChanged = { [weak self] position in
            self?.updateProgressBar(position: position)
        }

        // Load comics
        let comicsPath = "/path/to/episode.comics"
        controller.loadComics(filePath: comicsPath) { [weak self] result in
            switch result {
            case .success:
                self?.controller.play()
                self?.isPlaying = true
                self?.playPauseButton.setTitle("Pause", for: .normal)
            case .failure(let error):
                self?.showError(error: error)
            }
        }
    }

    @objc private func togglePlayback() {
        if isPlaying {
            controller.pause()
            playPauseButton.setTitle("Play", for: .normal)
        } else {
            controller.play()
            playPauseButton.setTitle("Pause", for: .normal)
        }
        isPlaying.toggle()
    }

    private func updateProgressBar(position: CGFloat) {
        // Update UI
    }

    private func showError(error: Error) {
        // Show error alert
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.dispose()
    }
}
```

## Requirements

- **iOS**: 13.0+
- **macOS**: 10.15+
- **Swift**: 5.9+
- **Frameworks**: Foundation, UIKit/AppKit, AVFoundation

## Bundle ID

```
net.nativemind.comics.viewer
```

## Advanced Usage

### Direct Access to Internal Components

For advanced use cases, you can still access internal components:

```swift
import ComicsViewer

// Low-level API
let comicsURL = URL(fileURLWithPath: "/path/to/file.comics")
if let comics = ArchiveManager.loadComics(from: comicsURL) {
    scrollView.setComics(comics, from: comicsURL)
    scrollView.languageIndex = 0
    scrollView.soundEnabled = true
}
```

**Note:** Using `ComicsViewerController` is recommended for most use cases.

## License

Copyright © 2017-2026 Iron Water Studio, NativeMind. All rights reserved.
