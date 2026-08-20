import Foundation

enum CleanerError: LocalizedError {
    case userCancelled
    case invalidPath(String)
    case taskFailed(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "用户取消了授权"
        case .invalidPath(let path):
            return "路径未通过安全检查: \(path)"
        case .taskFailed(let msg):
            return "任务失败: \(msg)"
        case .unavailable(let message):
            return "功能不可用: \(message)"
        }
    }
}
