import SwiftUI

// MARK: - FolderGridView

struct FolderGridView: View {
    let nodes: [FileNode]
    @Binding var selectedFile: FileNode?

    // MARK: - Grid Configuration
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 20)
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(sortedNodes) { node in
                    FolderGridItemView(
                        node: node,
                        isSelected: selectedFile == node,
                        onTap: { selectedFile = node }
                    )
                }
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground)
    }

    // MARK: - Computed Properties

    private var sortedNodes: [FileNode] {
        nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}

// MARK: - FolderGridItemView

private struct FolderGridItemView: View {
    let node: FileNode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.text.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 54, height: 54)
                    .foregroundColor(node.isDirectory ? .orange : .secondary)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                    .accessibilityHidden(true)

                Text(node.displayName)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(node.name)
        .accessibilityHint(node.isDirectory
            ? String(localized: "accessibility.openFolder")
            : String(localized: "accessibility.openFile"))
    }
}
