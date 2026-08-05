import Foundation
import ZIPFoundation
@testable import ComicsViewer

struct ArchiveFixtureEntry {
    let path: String
    let type: Entry.EntryType
    let data: Data

    init(path: String, type: Entry.EntryType = .file, data: Data = Data()) {
        self.path = path
        self.type = type
        self.data = data
    }
}

func makeComicsJSON(width: Int = 100, height: Int = 200) -> Data {
    Data("{\"width\":\(width),\"height\":\(height),\"layers\":[],\"sounds\":[]}".utf8)
}

func decodeTestComics() throws -> Comics {
    try JSONDecoder().decode(Comics.self, from: makeComicsJSON())
}

func makeSession(comics: Comics? = nil) throws -> ComicsArchiveSession {
    let root = try makeTemporaryDirectory()
    return ComicsArchiveSession(rootURL: root, comics: try comics ?? decodeTestComics())
}

final class StubArchiveLoader: ComicsArchiveLoading {
    var handler: (URL) throws -> ComicsArchiveSession

    init(handler: @escaping (URL) throws -> ComicsArchiveSession) {
        self.handler = handler
    }

    func loadArchive(at sourceURL: URL) throws -> ComicsArchiveSession {
        try handler(sourceURL)
    }
}

func makeArchive(at url: URL, entries: [ArchiveFixtureEntry]) throws {
    let archive = try Archive(url: url, accessMode: .create)
    for entry in entries {
        try archive.addEntry(
            with: entry.path,
            type: entry.type,
            uncompressedSize: Int64(entry.data.count)
        ) { position, size in
            let start = Int(position)
            let end = min(start + size, entry.data.count)
            guard start < end else { return Data() }
            return entry.data.subdata(in: start..<end)
        }
    }
}

func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("comics-viewer-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
