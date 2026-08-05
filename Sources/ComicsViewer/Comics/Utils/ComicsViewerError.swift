import Foundation

public enum ComicsViewerError: LocalizedError {
    case fileNotFound(URL)
    case unreadableFile(URL)
    case invalidArchive
    case unsafeArchiveEntry(String)
    case archiveLimitExceeded
    case missingDataJSON
    case invalidComicsData(Error)
    case invalidPuzzleData(Error)
    case missingPuzzlePiece(String)
    case disposed

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .unreadableFile(let url):
            return "File is not readable: \(url.path)"
        case .invalidArchive:
            return "The file is not a valid .comics archive."
        case .unsafeArchiveEntry(let path):
            return "The archive contains an unsafe entry: \(path)"
        case .archiveLimitExceeded:
            return "The archive exceeds the allowed extraction limits."
        case .missingDataJSON:
            return "The archive does not contain a root data.json file."
        case .invalidComicsData(let error):
            return "The archive contains invalid comics data: \(error.localizedDescription)"
        case .invalidPuzzleData(let error):
            return "The puzzle contains invalid data: \(error.localizedDescription)"
        case .missingPuzzlePiece(let file):
            return "The puzzle piece is missing: \(file)"
        case .disposed:
            return "The viewer has been disposed."
        }
    }
}
