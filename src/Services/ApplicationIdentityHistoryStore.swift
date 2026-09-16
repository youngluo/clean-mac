import Foundation

struct ApplicationIdentityHistoryEntry: Codable, Hashable {
    var owners: Set<String>
    var lastSeenAt: Date
}

final class ApplicationIdentityHistoryStore {
    private let historyURL: URL
    private let fileManager: FileManager
    private let limit: Int

    init(
        homeDirectory: URL,
        fileManager: FileManager,
        limit: Int = 2_000
    ) {
        self.historyURL = homeDirectory
            .appendingPathComponent("Library/Application Support/Spotless", isDirectory: true)
            .appendingPathComponent("application-identity-history.json")
        self.fileManager = fileManager
        self.limit = limit
    }

    func load() -> [String: ApplicationIdentityHistoryEntry] {
        guard let data = try? Data(contentsOf: historyURL),
              let entries = try? JSONDecoder().decode([String: ApplicationIdentityHistoryEntry].self, from: data) else {
            return [:]
        }
        return entries
    }

    func record(
        namespace: String,
        owners: Set<String>,
        in history: inout [String: ApplicationIdentityHistoryEntry],
        observedAt: Date = Date()
    ) {
        let normalizedOwners = Set(owners.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            .filter { !$0.isEmpty }
        guard !namespace.isEmpty, !normalizedOwners.isEmpty else { return }

        if var entry = history[namespace] {
            entry.owners.formUnion(normalizedOwners)
            entry.lastSeenAt = observedAt
            history[namespace] = entry
        } else {
            history[namespace] = ApplicationIdentityHistoryEntry(
                owners: normalizedOwners,
                lastSeenAt: observedAt
            )
        }

        guard history.count > limit else { return }
        let keysToRemove = history
            .sorted { $0.value.lastSeenAt < $1.value.lastSeenAt }
            .prefix(history.count - limit)
            .map(\.key)
        for key in keysToRemove {
            history.removeValue(forKey: key)
        }
    }

    func save(_ history: [String: ApplicationIdentityHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(history) else { return }

        do {
            try fileManager.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // 归属历史是安全增强信息，不应让扫描失败。
        }
    }
}
