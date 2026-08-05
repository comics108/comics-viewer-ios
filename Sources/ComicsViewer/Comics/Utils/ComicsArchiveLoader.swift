import Foundation
import ZIPFoundation

protocol ComicsArchiveLoading: AnyObject {
    func loadArchive(at sourceURL: URL) throws -> ComicsArchiveSession
}

final class ComicsArchiveLoader: ComicsArchiveLoading {
    struct Limits {
        let maximumEntryCount: Int
        let maximumEntrySize: UInt64
        let maximumTotalSize: UInt64

        static let `default` = Limits(
            maximumEntryCount: 10_000,
            maximumEntrySize: 256 * 1_024 * 1_024,
            maximumTotalSize: 1_024 * 1_024 * 1_024
        )
    }

    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private let limits: Limits

    init(
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        limits: Limits = .default
    ) {
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
        self.limits = limits
    }

    func loadArchive(at sourceURL: URL) throws -> ComicsArchiveSession {
        let sourceURL = sourceURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw ComicsViewerError.fileNotFound(sourceURL)
        }
        guard !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: sourceURL.path),
              (try? sourceURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw ComicsViewerError.unreadableFile(sourceURL)
        }

        let rootURL = temporaryDirectory
            .appendingPathComponent("comics-viewer-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL

        do {
            let archive: Archive
            do {
                archive = try Archive(url: sourceURL, accessMode: .read)
            } catch {
                throw ComicsViewerError.invalidArchive
            }

            let entries = Array(archive)
            guard entries.count <= limits.maximumEntryCount else {
                throw ComicsViewerError.archiveLimitExceeded
            }

            var destinations = Set<String>()
            var declaredTotal: UInt64 = 0
            var hasDataJSON = false

            for entry in entries {
                let destination = try validatedDestination(for: entry, rootURL: rootURL)
                guard destinations.insert(destination.path).inserted else {
                    throw ComicsViewerError.unsafeArchiveEntry(entry.path)
                }
                guard entry.uncompressedSize <= limits.maximumEntrySize else {
                    throw ComicsViewerError.archiveLimitExceeded
                }
                let (newTotal, overflow) = declaredTotal.addingReportingOverflow(entry.uncompressedSize)
                guard !overflow, newTotal <= limits.maximumTotalSize else {
                    throw ComicsViewerError.archiveLimitExceeded
                }
                declaredTotal = newTotal
                if entry.path == "data.json", entry.type == .file {
                    hasDataJSON = true
                }
            }

            guard hasDataJSON else { throw ComicsViewerError.missingDataJSON }
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

            var writtenTotal: UInt64 = 0
            for entry in entries {
                let destination = try validatedDestination(for: entry, rootURL: rootURL)
                switch entry.type {
                case .directory:
                    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                case .symlink:
                    throw ComicsViewerError.unsafeArchiveEntry(entry.path)
                case .file:
                    try extract(
                        entry,
                        from: archive,
                        to: destination,
                        writtenTotal: &writtenTotal
                    )
                }
            }

            let dataURL = rootURL.appendingPathComponent("data.json")
            let data = try Data(contentsOf: dataURL)
            let comics: Comics
            do {
                comics = try JSONDecoder().decode(Comics.self, from: data)
            } catch {
                throw ComicsViewerError.invalidComicsData(error)
            }
            return ComicsArchiveSession(rootURL: rootURL, comics: comics, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: rootURL)
            if let viewerError = error as? ComicsViewerError {
                throw viewerError
            }
            throw ComicsViewerError.invalidArchive
        }
    }

    private func validatedDestination(for entry: Entry, rootURL: URL) throws -> URL {
        let path = entry.path
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty,
              !path.contains("\\"),
              !(path as NSString).isAbsolutePath,
              !path.hasPrefix("/"),
              !path.hasPrefix("~"),
              !(path.count >= 2 && path[path.index(after: path.startIndex)] == ":"),
              !components.contains(".."),
              entry.type != .symlink else {
            throw ComicsViewerError.unsafeArchiveEntry(path)
        }

        let destination = rootURL.appendingPathComponent(path).standardizedFileURL
        let rootPath = rootURL.standardizedFileURL.path
        guard destination.path != rootPath,
              destination.path.hasPrefix(rootPath + "/") else {
            throw ComicsViewerError.unsafeArchiveEntry(path)
        }
        return destination
    }

    private func extract(
        _ entry: Entry,
        from archive: Archive,
        to destination: URL,
        writtenTotal: inout UInt64
    ) throws {
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            throw ComicsViewerError.invalidArchive
        }
        let handle = try FileHandle(forWritingTo: destination)
        defer { handle.closeFile() }

        var writtenEntry: UInt64 = 0
        _ = try archive.extract(entry) { [limits] data in
            let chunkSize = UInt64(data.count)
            let (newEntrySize, entryOverflow) = writtenEntry.addingReportingOverflow(chunkSize)
            let (newTotalSize, totalOverflow) = writtenTotal.addingReportingOverflow(chunkSize)
            guard !entryOverflow,
                  !totalOverflow,
                  newEntrySize <= limits.maximumEntrySize,
                  newTotalSize <= limits.maximumTotalSize else {
                throw ComicsViewerError.archiveLimitExceeded
            }
            writtenEntry = newEntrySize
            writtenTotal = newTotalSize
            handle.write(data)
        }
    }
}
