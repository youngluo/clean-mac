import Foundation

enum AppState: Equatable {
    case idle
    case scanning(CleanupCategory)
    case review
    case applying
    case completed
    case partial
    case cancelled
}
