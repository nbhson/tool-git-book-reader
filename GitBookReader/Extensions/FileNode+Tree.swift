import Foundation

// MARK: - FileNode Tree Extensions

extension FileNode {
    /// Recursively filters a tree of nodes by a search text.
    /// Directories are kept if their name matches or if any descendant matches.
    static func filterTree(nodes: [FileNode], searchText: String) -> [FileNode] {
        guard !searchText.isEmpty else { return nodes }

        var result: [FileNode] = []
        let searchLower = searchText.lowercased()

        for node in nodes {
            if node.isDirectory {
                if let children = node.children {
                    let filteredChildren = filterTree(nodes: children, searchText: searchText)

                    if node.name.lowercased().contains(searchLower) || !filteredChildren.isEmpty {
                        let newNode = FileNode(
                            name: node.name,
                            path: node.path,
                            isDirectory: true,
                            downloadUrl: node.downloadUrl,
                            children: filteredChildren
                        )
                        result.append(newNode)
                    }
                }
            } else if node.name.lowercased().contains(searchLower) {
                result.append(node)
            }
        }

        return result
    }

    /// Returns the display name with the .md extension removed.
    var displayName: String {
        name.replacingOccurrences(of: ".md", with: "")
    }
}
