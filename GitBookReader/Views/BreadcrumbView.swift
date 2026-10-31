import SwiftUI

// MARK: - BreadcrumbView

struct BreadcrumbView: View {
    @Binding var selectedFile: FileNode?
    let rootName: String

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 8) {
                    rootButton

                    if let file = selectedFile {
                        ForEach(file.breadcrumbPath) { crumb in
                            chevron

                            crumbButton(for: crumb, isSelected: crumb == file)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: selectedFile) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue?.id ?? UUID(), anchor: .trailing)
                    }
                }
            }
        }
        .background(Color.adaptiveWindowBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "accessibility.breadcrumb"))
    }

    // MARK: - Subviews

    private var rootButton: some View {
        Button(action: { selectedFile = nil }) {
            HStack {
                Image(systemName: "house.fill")
                    .accessibilityHidden(true)

                Text(rootName)
            }
            .foregroundColor(selectedFile == nil ? .primary : .accentColor)
            .fontWeight(selectedFile == nil ? .bold : .regular)
        }
        .buttonStyle(.plain)
        .id("root")
        .accessibilityLabel(String(localized: "accessibility.goHome"))
    }

    private func crumbButton(for crumb: FileNode, isSelected: Bool) -> some View {
        Button(action: { selectedFile = crumb }) {
            Text(crumb.name)
                .foregroundColor(isSelected ? .primary : .accentColor)
                .fontWeight(isSelected ? .bold : .regular)
        }
        .buttonStyle(.plain)
        .id(crumb.id)
        .accessibilityLabel(crumb.name)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(.secondary)
            .accessibilityHidden(true)
    }
}
