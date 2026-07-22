# ComicsViewer Swift Package

A Swift Package for rendering interactive comics and puzzles on iOS and macOS.

## Features

- **Comics Rendering**: Display tiled, animated comics with layer transformations
- **Sound Playback**: Integrated sound management with position-based triggers
- **Puzzle Support**: Handle puzzle pieces and their states
- **Cross-Platform**: Compatible with iOS 13.0+, macOS 10.15+
- **Standalone Library**: No app-specific dependencies

## Installation

### Swift Package Manager

Add the package to your Xcode project:

1. File → Add Package Dependencies
2. Select the local package at `libs/comics_viewer/comics-viewer-ios`
3. Link `ComicsViewer` to your target

## Package Structure

```
Sources/ComicsViewer/
├── Comics/
│   ├── Models/           # Comics, Layer, Image, Sound
│   │   └── Animations/   # Animation classes
│   ├── Views/            # TileImageView, ImageScrollView
│   └── Utils/            # ArchiveManager, SoundManager, Extensions
└── Puzzle/
    └── Models/           # Puzzle, Piece
```

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.9+
- AVFoundation framework

## License

Copyright © 2017 Iron Water Studio. All rights reserved.
