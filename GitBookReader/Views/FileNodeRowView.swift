import SwiftUI

// MARK: - FileNodeRowView (Recursive Tree Row)

struct FileNodeRowView: View {
    let node: FileNode
    @Binding var selectedFile: FileNode?

    @State private var isExpanded = false

    // MARK: - Body

    var body: some View {
        if node.isDirectory {
            folderRow
        } else {
            fileRow
        }
    }

    // MARK: - Subviews

    private var folderName: some View {
        HStack {
            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text(node.name)
                .fontWeight(selectedFile == node ? .bold : .semibold)
                .foregroundColor(selectedFile == node ? .accentColor : .primary)

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var folderRow: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let children = node.children {
                ForEach(children) { child in
                    FileNodeRowView(node: child, selectedFile: $selectedFile)
                }
            }
        } label: {
            Button(action: { selectedFile = node }) {
                folderName
            }
            .buttonStyle(.plain)
        }
        .accessibilityLabel(node.name)
        .accessibilityHint(String(localized: "accessibility.folderHint"))
    }

    private var fileRow: some View {
        NavigationLink(value: node) {
            HStack {
                Image(systemName: "doc.plaintext.fill")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                Text(node.name.replacingOccurrences(of: ".md", with: ""))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel(node.name.replacingOccurrences(of: ".md", with: ""))
    }
}

// MARK: - Preview

