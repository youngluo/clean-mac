import Foundation

final class CleanupExclusionStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults, key: String = "CleanMac.excludedCleanupPaths") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func add(_ url: URL) {
        var paths = Set(userDefaults.stringArray(forKey: key) ?? [])
        paths.insert(url.standardizedFileURL.path)
        userDefaults.set(Array(paths).sorted(), forKey: key)
    }

    func remove(_ url: URL) {
        var paths = Set(userDefaults.stringArray(forKey: key) ?? [])
        paths.remove(url.standardizedFileURL.path)
        userDefaults.set(Array(paths).sorted(), forKey: key)
    }

    func contains(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return (userDefaults.stringArray(forKey: key) ?? []).contains { excludedPath in
            path == excludedPath || path.hasPrefix(excludedPath + "/")
        }
    }
}
