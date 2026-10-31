import Foundation
import Combine

// MARK: - GitHubService

/// The main app service: loads GitHub repository file trees, caches raw
/// Markdown content in memory, and tracks recently opened repositories.
///
/// All mutable state is confined to the main actor for SwiftUI safety.
@MainActor
final class GitHubService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var rootNodes: [FileNode] = []

    /// Recent repositories for quick access
    @Published var recentRepos: [String] = [] {
        didSet {
            UserDefaults.standard.set(recentRepos, forKey: Keys.recentRepos)
        }
    }

    // MARK: - Private Properties
    private let rawFileCache = NSCache<NSString, NSString>()
    private let maxRecentRepos = 20
    private let maxRetryAttempts = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    // MARK: - Keys
    private enum Keys {
        static let recentRepos = "recentRepos"
    }

    // MARK: - Initialization
    init() {
        loadRecentRepos()
    }

    // MARK: - Public Methods

    /// Loads a GitHub repository from a URL string (e.g. `https://github.com/owner/repo`).
    ///
    /// Resets the current state, validates and parses the URL, records the
    /// repository in the recent list, then fetches the file tree asynchronously.
    func loadRepository(urlString: String) {
        let cleanedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil
        rootNodes = []

        guard let (owner, repo) = extractOwnerAndRepo(from: cleanedUrl) else {
            errorMessage = GitHubError.invalidURL.errorDescription
            isLoading = false
            return
        }

        addToRecentRepos(cleanedUrl)
        Task {
            await fetchRepository(owner: owner, repo: repo)
        }
    }

    /// Refreshes the current repository (equivalent to `loadRepository`).
    func refreshRepository(urlString: String) {
        loadRepository(urlString: urlString)
    }

    /// Fetches raw file content from a download URL, using a memory cache first.
    ///
    /// - Throws: `GitHubError.fileNotFound` on 404, `GitHubError.decodingError`
    ///   for non-UTF-8 content, or a network error otherwise.
    func fetchRawContent(downloadUrl: URL) async throws -> String {
        let cacheKey = NSString(string: downloadUrl.absoluteString)

        if let cachedContent = rawFileCache.object(forKey: cacheKey) {
            return String(cachedContent)
        }

        let (data, response) = try await URLSession.shared.data(from: downloadUrl)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.unknown
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw GitHubError.fileNotFound
            }
            if httpResponse.statusCode == 403 {
                throw GitHubError.rateLimitExceeded
            }
            throw GitHubError.networkError(underlying: URLError(.badServerResponse))
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw GitHubError.decodingError
        }

        rawFileCache.setObject(NSString(string: content), forKey: cacheKey)
        return content
    }

    /// Clears all cached Markdown content.
    func clearCache() {
        rawFileCache.removeAllObjects()
    }

    /// Removes a specific repository from history
    func removeFromHistory(_ repoUrl: String) {
        recentRepos.removeAll { $0 == repoUrl }
    }

    /// Clears all repository history
    func clearHistory() {
        recentRepos.removeAll()
    }

    // MARK: - Private Methods

    /// Loads the persisted recent-repository list from `UserDefaults`.
    private func loadRecentRepos() {
        if let savedRepos = UserDefaults.standard.array(forKey: Keys.recentRepos) as? [String] {
            recentRepos = savedRepos
        }
    }

    /// Moves a repository to the top of the recent list, evicting the oldest
    /// entry when the list exceeds `maxRecentRepos`.
    private func addToRecentRepos(_ url: String) {
        guard !recentRepos.contains(url) else {
            recentRepos.removeAll { $0 == url }
            recentRepos.insert(url, at: 0)
            return
        }

        recentRepos.insert(url, at: 0)
        if recentRepos.count > maxRecentRepos {
            recentRepos.removeLast()
        }
    }

    /// Fetches the default branch, then the full git tree, and builds the sidebar tree.
    private func fetchRepository(owner: String, repo: String) async {
        do {
            let defaultBranch = try await fetchDefaultBranch(owner: owner, repo: repo)
            let treeItems = try await fetchTreeWithRetry(owner: owner, repo: repo, branch: defaultBranch)
            let nodes = buildTree(from: treeItems, owner: owner, repo: repo, branch: defaultBranch)

            rootNodes = nodes
            isLoading = false
        } catch {
            handleError(error)
        }
    }

    /// Fetches repository metadata to determine the default branch.
    private func fetchDefaultBranch(owner: String, repo: String) async throws -> String {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)"
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validateResponse(response)

        do {
            let repoResponse = try JSONDecoder().decode(RepoResponse.self, from: data)
            return repoResponse.defaultBranch
        } catch {
            throw GitHubError.decodingError
        }
    }

    /// Fetches the recursive git tree, retrying transient network errors with a backoff delay.
    private func fetchTreeWithRetry(owner: String, repo: String, branch: String, attempt: Int = 1) async throws -> [GitTreeItem] {
        do {
            return try await fetchTree(owner: owner, repo: repo, branch: branch)
        } catch GitHubError.networkError where attempt < maxRetryAttempts {
            try await Task.sleep(nanoseconds: retryDelay * UInt64(attempt))
            return try await fetchTreeWithRetry(owner: owner, repo: repo, branch: branch, attempt: attempt + 1)
        }
    }

    private func fetchTree(owner: String, repo: String, branch: String) async throws -> [GitTreeItem] {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(branch)?recursive=1"
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("GitBookReader-App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        // Throws `.rateLimitExceeded` on 403 and `.invalidRepository` on 404.
        try validateResponse(response)

        do {
            let treeResponse = try JSONDecoder().decode(GitTreeResponse.self, from: data)
            return treeResponse.tree
        } catch {
            throw GitHubError.decodingError
        }
    }

    /// Validates the HTTP status code of a response, mapping it to a `GitHubError`.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 403:
            throw GitHubError.rateLimitExceeded
        case 404:
            throw GitHubError.invalidRepository
        default:
            throw GitHubError.networkError(underlying: URLError(.badServerResponse))
        }
    }

    private func handleError(_ error: Error) {
        if let githubError = error as? GitHubError {
            errorMessage = githubError.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - URL Parsing

    /// Extracts the repository owner and name from a GitHub URL.
    ///
    /// Accepts `https://github.com/owner/repo`, `www.github.com/owner/repo`,
    /// bare `github.com/owner/repo`, an optional `.git` suffix, and trailing
    /// slashes. Returns `nil` when the string is not a valid GitHub repo URL.
    private func extractOwnerAndRepo(from url: String) -> (String, String)? {
        let cleanedUrl = url
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var components = cleanedUrl.components(separatedBy: "/")
        // Drop an empty first element so bare "github.com/..." aligns with "https://github.com/..."
        if components.first?.isEmpty == true { components.removeFirst() }

        // Find the "github.com" host, also matching "www.github.com"
        guard let gitIndex = components.lastIndex(where: { $0 == "github.com" || $0 == "www.github.com" }),
              components.count >= gitIndex + 3 else {
            return nil
        }

        let owner = components[gitIndex + 1]
        var repo = components[gitIndex + 2]
        if repo.hasSuffix(".git") { repo.removeLast(4) }

        guard !owner.isEmpty, !repo.isEmpty else { return nil }

        return (owner, repo)
    }

    // MARK: - Tree Building

    /// Builds the sidebar tree from recursive git-tree items, keeping only
    /// directories and Markdown files, sorted folders-first, and prunes
    /// directories that contain no Markdown files.
    private func buildTree(from items: [GitTreeItem], owner: String, repo: String, branch: String) -> [FileNode] {
        var nodesMap: [String: FileNode] = [:]

        // Filter and create nodes
        for item in items {
            if item.type != "tree" && !item.path.lowercased().hasSuffix(".md") { continue }

            let isDir = item.type == "tree"
            let components = item.path.components(separatedBy: "/")
            let name = components.last ?? item.path

            var downloadUrl: URL? = nil
            if !isDir {
                let encodedPath = components
                    .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
                    .joined(separator: "/")
                let urlString = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(encodedPath)"
                downloadUrl = URL(string: urlString)
            }

            let node = FileNode(
                name: name,
                path: item.path,
                isDirectory: isDir,
                downloadUrl: downloadUrl,
                children: isDir ? [] : nil
            )
            nodesMap[item.path] = node
        }

        // Build parent-child relationships
        var rootLevel: [FileNode] = []
        for (_, node) in nodesMap {
            let components = node.path.components(separatedBy: "/")

            if components.count == 1 {
                rootLevel.append(node)
            } else {
                var parentPath = components
                parentPath.removeLast()
                let parentKey = parentPath.joined(separator: "/")

                if let parentNode = nodesMap[parentKey] {
                    if parentNode.children == nil { parentNode.children = [] }
                    parentNode.children?.append(node)
                }
            }
        }

        var finalNodes = rootLevel
        sortNodes(&finalNodes)
        return pruneEmptyDirectories(nodes: finalNodes)
    }

    /// Sorts nodes in place: directories first, then files, both alphabetically.
    private func sortNodes(_ nodes: inout [FileNode]) {
        nodes.sort { a, b in
            if a.isDirectory && !b.isDirectory { return true }
            if !a.isDirectory && b.isDirectory { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Recursively removes directories that contain no Markdown files.
    ///
    /// Directory nodes are re-created with the pruned children, and every
    /// surviving node gets its `parent` set so breadcrumbs work at any depth.
    private func pruneEmptyDirectories(nodes: [FileNode], parent: FileNode? = nil) -> [FileNode] {
        var result: [FileNode] = []

        for node in nodes {
            if node.isDirectory {
                guard let children = node.children, !children.isEmpty else { continue }

                let newNode = FileNode(
                    name: node.name,
                    path: node.path,
                    isDirectory: true,
                    downloadUrl: node.downloadUrl,
                    children: [],
                    parent: parent
                )
                let prunedChildren = pruneEmptyDirectories(nodes: children, parent: newNode)

                guard !prunedChildren.isEmpty else { continue }

                newNode.children = prunedChildren
                result.append(newNode)
            } else {
                node.parent = parent
                result.append(node)
            }
        }

        sortNodes(&result)
        return result
    }
}
