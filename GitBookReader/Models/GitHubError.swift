import Foundation

// MARK: - GitHubService Errors

enum GitHubError: LocalizedError {
    case invalidURL
    case invalidRepository
    case networkError(underlying: Error)
    case rateLimitExceeded
    case decodingError
    case fileNotFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "error.invalidURL", comment: "Error when URL is malformed")
        case .invalidRepository:
            return String(localized: "error.invalidRepository", comment: "Error when repository is not found")
        case .networkError(let underlying):
            return String(localized: "error.networkError \(underlying.localizedDescription)", comment: "Network error")
        case .rateLimitExceeded:
            return String(localized: "error.rateLimitExceeded", comment: "API rate limit exceeded")
        case .decodingError:
            return String(localized: "error.decodingError", comment: "Failed to decode response")
        case .fileNotFound:
            return String(localized: "error.fileNotFound", comment: "File not found")
        case .unknown:
            return String(localized: "error.unknown", comment: "Unknown error occurred")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return String(localized: "error.invalidURL.suggestion", comment: "Check the URL format")
        case .invalidRepository:
            return String(localized: "error.invalidRepository.suggestion", comment: "Verify repo exists")
        case .networkError:
            return String(localized: "error.networkError.suggestion", comment: "Check internet connection")
        case .rateLimitExceeded:
            return String(localized: "error.rateLimitExceeded.suggestion", comment: "Wait and try again")
        case .decodingError:
            return String(localized: "error.decodingError.suggestion", comment: "Repository may be empty")
        case .fileNotFound:
            return String(localized: "error.fileNotFound.suggestion", comment: "File was removed")
        case .unknown:
            return String(localized: "error.unknown.suggestion", comment: "Try again later")
        }
    }
}
