import Foundation
import Combine

// MARK: - GitHubService

@MainActor
class GitHubService: ObservableObject {
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

    /// Loads a GitHub repository from URL
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

    /// Refreshes the current repository
    func refreshRepository(urlString: String) {
        loadRepository(urlString: urlString)
    }

    /// Fetches raw content from download URL with caching
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
            throw GitHubError.networkError(underlying: URLError(.badServerResponse))
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw GitHubError.decodingError
        }

        rawFileCache.setObject(NSString(string: content), forKey: cacheKey)
        return content
    }

    /// Clears all cached data
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

    private func loadRecentRepos() {
        if let savedRepos = UserDefaults.standard.array(forKey: Keys.recentRepos) as? [String] {
            recentRepos = savedRepos
        }
    }

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
        try validateResponse(response)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            throw GitHubError.rateLimitExceeded
        }

        do {
            let treeResponse = try JSONDecoder().decode(GitTreeResponse.self, from: data)
            return treeResponse.tree
        } catch {
            throw GitHubError.decodingError
        }
    }

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

    private func extractOwnerAndRepo(from url: String) -> (String, String)? {
        let cleanedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = cleanedUrl.components(separatedBy: "/")

        guard let gitIndex = components.firstIndex(of: "github.com"),
              gitIndex + 2 < components.count else {
            return nil
        }

        let owner = components[gitIndex + 1]
        let repo = components[gitIndex + 2].replacingOccurrences(of: ".git", with: "")

        guard !owner.isEmpty, !repo.isEmpty else { return nil }

        return (owner, repo)
    }

    // MARK: - Tree Building

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

    private func sortNodes(_ nodes: inout [FileNode]) {
        nodes.sort { a, b in
            if a.isDirectory && !b.isDirectory { return true }
            if !a.isDirectory && b.isDirectory { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func pruneEmptyDirectories(nodes: [FileNode], parent: FileNode? = nil) -> [FileNode] {
        var result: [FileNode] = []

        for node in nodes {
            if node.isDirectory {
                if let children = node.children, !children.isEmpty {
                    let prunedChildren = pruneEmptyDirectories(nodes: children, parent: nil)
                    if !prunedChildren.isEmpty {
                        let newNode = FileNode(
                            name: node.name,
                            path: node.path,
                            isDirectory: true,
                            downloadUrl: node.downloadUrl,
                            children: prunedChildren,
                            parent: parent
                        )
                        for child in prunedChildren { child.parent = newNode }

                        var sortedArray = result + [newNode]
                        sortNodes(&sortedArray)
                        result = sortedArray
                    }
                }
            } else {
                node.parent = parent
                result.append(node)
                sortNodes(&result)
            }
        }

        return result
    }
}
