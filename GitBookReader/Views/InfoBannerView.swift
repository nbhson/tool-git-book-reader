import SwiftUI

// MARK: - InfoBannerView

/// A compact notice banner used for non-blocking warnings such as a
/// truncated repository tree or offline (cached) data.
struct InfoBannerView: View {
    let icon: String
    let title: String
    let message: String?
    var tint: Color = .orange

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let message = message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, message ?? ""].filter { !$0.isEmpty }.joined(separator: ". "))
    }
}
