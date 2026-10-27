import Foundation

// MARK: - API Response Models

struct RepoResponse: Codable {
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case defaultBranch = "default_branch"
    }
}

struct GitTreeResponse: Codable {
    let sha: String
    let url: String
    let tree: [GitTreeItem]
    let truncated: Bool
}

struct GitTreeItem: Codable {
    let path: String
    let mode: String
    let type: String
    let sha: String
    let size: Int?
    let url: String
}

// MARK: - FileNode (App State Model)

class FileNode: Identifiable, Hashable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let downloadUrl: URL?
    var children: [FileNode]?
    weak var parent: FileNode?

    init(
        name: String,
        path: String,
        isDirectory: Bool,
        downloadUrl: URL? = nil,
        children: [FileNode]? = nil,
        parent: FileNode? = nil
    ) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.downloadUrl = downloadUrl
        self.children = children
        self.parent = parent
    }

    var breadcrumbPath: [FileNode] {
        var path: [FileNode] = []
        var current: FileNode? = self
        while let node = current {
            path.insert(node, at: 0)
            current = node.parent
        }
        return path
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
