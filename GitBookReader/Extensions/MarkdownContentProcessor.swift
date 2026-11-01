import Foundation

// MARK: - MarkdownContentProcessor

enum MarkdownContentProcessor {
    /// Processes raw markdown content for display.
    ///
    /// Escaped-newline handling and spacing fixes are applied **only outside
    /// fenced code blocks**, so literal `\n` / `\t` sequences that belong to
    /// code samples (e.g. `printf("\n")`) are preserved verbatim.
    static func process(_ content: String) -> String {
        var result = ""
        var cursor = content.startIndex

        // Matches a fenced code block: an opening ``` up to the next closing
        // ``` — or, for an unterminated fence, up to the end of the content.
        let fenceRegex = try? NSRegularExpression(pattern: "```[\\s\\S]*?(?:```|\\Z)")

        if let fenceRegex {
            let nsContent = content as NSString
            fenceRegex.enumerateMatches(
                in: content,
                range: NSRange(location: 0, length: nsContent.length)
            ) { match, _, _ in
                guard let match, let range = Range(match.range, in: content) else { return }

                // Text before the code block is transformed; the code block
                // itself is kept verbatim.
                result += transformNonCode(String(content[cursor..<range.lowerBound]))
                result += String(content[range])
                cursor = range.upperBound
            }
        }

        // Tail after the last code block (or the whole content when no fences).
        result += transformNonCode(String(content[cursor...]))

        return result
    }

    /// Applies escaped-newline handling and spacing fixes to non-code text.
    private static func transformNonCode(_ text: String) -> String {
        var result = text

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
