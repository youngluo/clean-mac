import Foundation

enum CleanerError: Error {
    case userCancelled
    case invalidPath(String)
    case taskFailed(String)
    case unavailable(String)
    case unknown

}
