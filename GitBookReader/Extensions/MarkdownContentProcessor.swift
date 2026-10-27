import Foundation

// MARK: - MarkdownContentProcessor

enum MarkdownContentProcessor {
    /// Processes raw markdown content for display.
    static func process(_ content: String) -> String {
        var result = content

        // Handle escaped newlines
        result = result
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")

        // Ensure headings have proper spacing
        result = ensureHeadingSpacing(result)

        // Ensure blockquotes have proper spacing
        result = ensureBlockquoteSpacing(result)

        return result
    }

    /// Adds blank line before headings if missing.
    private static func ensureHeadingSpacing(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "([^\n])\n(#{1,6}\\s)",
            options: []
        ) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "$1\n\n$2"
        )
    }

    /// Adds blank line before blockquotes if missing.
    private static func ensureBlockquoteSpacing(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "([^\n])\n(>\\s)",
            options: []
        ) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "$1\n\n$2"
        )
    }
}
