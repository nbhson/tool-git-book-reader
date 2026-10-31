import Foundation
import AVFoundation
import Combine

// MARK: - SpeechManager

@MainActor
class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // MARK: - Published Properties
    @Published private(set) var isSpeaking = false

    // MARK: - Private Properties
    private var synthesizer: AVSpeechSynthesizer?
    private var pendingUtterancesCount = 0

    // MARK: - Initialization
    override init() {
        super.init()
        setupSynthesizer()
    }

    // MARK: - Setup

    private func setupSynthesizer() {
        synthesizer = AVSpeechSynthesizer()
        synthesizer?.delegate = self
    }

    // MARK: - Public Methods

    /// Toggles speech playback: starts reading `text`, or stops if already speaking.
    func toggleSpeech(text: String) {
        guard synthesizer != nil else { return }

        if isSpeaking {
            stop()
        } else {
            startSpeaking(text: text)
        }
    }

    /// Stops current speech
    func stop() {
        synthesizer?.stopSpeaking(at: .immediate)
        isSpeaking = false
        pendingUtterancesCount = 0
    }

    // MARK: - Private Methods

    private func startSpeaking(text: String) {
        let cleanText = cleanMarkdownText(text)
        let paragraphs = extractParagraphs(from: cleanText)

        guard !paragraphs.isEmpty else { return }

        pendingUtterancesCount = paragraphs.count

        for paragraph in paragraphs {
            let utterance = AVSpeechUtterance(string: paragraph)
            configureUtterance(utterance)
            synthesizer?.speak(utterance)
        }

        isSpeaking = true
    }

    private func cleanMarkdownText(_ text: String) -> String {
        var cleanText = text

        // Remove code blocks
        if let codeBlockRegex = try? NSRegularExpression(pattern: "```[\\s\\S]*?```", options: []) {
            cleanText = codeBlockRegex.stringByReplacingMatches(
                in: cleanText,
                range: NSRange(cleanText.startIndex..., in: cleanText),
                withTemplate: ""
            )
        }

        // Remove images
        if let imageRegex = try? NSRegularExpression(pattern: "!\\[[^\\]]*\\]\\([^)]+\\)", options: []) {
            cleanText = imageRegex.stringByReplacingMatches(
                in: cleanText,
                range: NSRange(cleanText.startIndex..., in: cleanText),
                withTemplate: ""
            )
        }

        // Keep link text, remove URL
        if let linkRegex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", options: []) {
            cleanText = linkRegex.stringByReplacingMatches(
                in: cleanText,
                range: NSRange(cleanText.startIndex..., in: cleanText),
                withTemplate: "$1"
            )
        }

        // Remove HTML tags
        if let htmlRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            cleanText = htmlRegex.stringByReplacingMatches(
                in: cleanText,
                range: NSRange(cleanText.startIndex..., in: cleanText),
                withTemplate: ""
            )
        }

        // Remove markdown symbols
        return cleanText
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func extractParagraphs(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        // Prefer Vietnamese voice if available
        utterance.voice = AVSpeechSynthesisVoice(language: "vi-VN")
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0.1
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            pendingUtterancesCount -= 1
            if pendingUtterancesCount <= 0 {
                isSpeaking = false
                pendingUtterancesCount = 0
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            pendingUtterancesCount = 0
        }
    }
}
