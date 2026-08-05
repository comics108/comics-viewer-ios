import Foundation

final class ComicsArchiveSession {
    let rootURL: URL
    let comics: Comics
    let resources: ArchiveManager

    private let fileManager: FileManager
    private let lock = NSLock()
    private var isDisposed = false

    init(rootURL: URL, comics: Comics, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.comics = comics
        self.resources = ArchiveManager(rootURL: rootURL)
        self.fileManager = fileManager
    }

    func dispose() {
        lock.lock()
        guard !isDisposed else {
            lock.unlock()
            return
        }
        isDisposed = true
        lock.unlock()

        try? fileManager.removeItem(at: rootURL)
    }

    deinit {
        dispose()
    }
}
