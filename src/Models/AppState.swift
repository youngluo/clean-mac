import Foundation

enum AppState: Equatable {
    case idle
    case scanning
    case awaitingConfirmation
    case applying
    case completed
    case partial
}
