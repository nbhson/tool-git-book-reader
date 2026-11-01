import Foundation

// MARK: - CachedTree

/// Payload persisted for a repository's git tree so it can be rebuilt
/// offline (the branch is needed to re-create raw-file download URLs).
struct CachedTree: Codable {
    let items: [GitTreeItem]
    let branch: String
    let truncated: Bool
}

// MARK: - OfflineCacheStore

/// Persists repository trees and raw Markdown files under Application
/// Support so previously opened repositories remain readable offline.
///
/// Layout:
/// ```
/// <Application Support>/GitBookReader/OfflineCache/
/// ├── <owner>-<repo>/tree.json          — CachedTree payload
/// └── files/<encoded download URL>.md   — raw Markdown content
/// ```
final class OfflineCacheStore {
    // MARK: - Private Properties

    private let rootDirectory: URL
    private let fileManager = FileManager.default

    // MARK: - Initialization

    /// - Parameter rootDirectory: Overrides the cache location (used by tests).
    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.rootDirectory = base
                .appendingPathComponent("GitBookReader", isDirectory: true)
                .appendingPathComponent("OfflineCache", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Tree Cache

    /// Saves the git tree of a repository for offline use.
    func saveTree(owner: String, repo: String, branch: String, items: [GitTreeItem], truncated: Bool) {
        let payload = CachedTree(items: items, branch: branch, truncated: truncated)
        guard let data = try? JSONEncoder().encode(payload) else { return }

        let fileUrl = repositoryDirectory(owner: owner, repo: repo)
            .appendingPathComponent("tree.json")
        try? data.write(to: fileUrl, options: .atomic)
    }

    /// Loads the cached git tree of a repository, if any.
    func loadTree(owner: String, repo: String) -> CachedTree? {
        let fileUrl = repositoryDirectory(owner: owner, repo: repo)
            .appendingPathComponent("tree.json")
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        return try? JSONDecoder().decode(CachedTree.self, from: data)
    }

    // MARK: - Raw File Cache

    /// Saves raw Markdown content keyed by its download URL.
    func saveFile(downloadUrl: URL, content: String) {
        let fileUrl = cacheFileUrl(for: downloadUrl)
        try? fileManager.createDirectory(
            at: fileUrl.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data(content.utf8).write(to: fileUrl, options: .atomic)
    }

    /// Loads cached raw Markdown content for a download URL, if any.
    func loadFile(downloadUrl: URL) -> String? {
        guard let data = try? Data(contentsOf: cacheFileUrl(for: downloadUrl)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes every cached tree and file.
    func clearAll() {
        try? fileManager.removeItem(at: rootDirectory)
    }

    // MARK: - Helpers

    private func repositoryDirectory(owner: String, repo: String) -> URL {
        let directory = rootDirectory
            .appendingPathComponent("\(sanitized(owner))-\(sanitized(repo))", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Percent-encodes the whole URL string so it is a valid, stable file name.
    private func cacheFileUrl(for downloadUrl: URL) -> URL {
        let encoded = sanitized(downloadUrl.absoluteString)
        return rootDirectory
            .appendingPathComponent("files", isDirectory: true)
            .appendingPathComponent("\(encoded).md")
    }

    /// Percent-encodes everything except alphanumerics so the mapping
    /// URL → file name is injective (no two different URLs can collide),
    /// and the result is a valid file name on all platforms.
    private func sanitized(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }
}
