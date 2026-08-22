import Foundation

final class CleanupHistoryStore {
    private let historyURL: URL
    private let fileManager: FileManager
    private let limit: Int

    init(
        homeDirectory: URL,
        fileManager: FileManager,
        limit: Int = 50
    ) {
        self.historyURL = homeDirectory
            .appendingPathComponent("Library/Application Support/CleanMac", isDirectory: true)
            .appendingPathComponent("operations.json")
        self.fileManager = fileManager
        self.limit = limit
    }

    func load() -> [CleanupHistoryEntry] {
        guard let data = try? Data(contentsOf: historyURL),
              let entries = try? JSONDecoder().decode([CleanupHistoryEntry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.finishedAt > $1.finishedAt }
    }

    func save(_ summary: CleanupSummary, categories: [CleanupCategory]) {
        var entries = load()
        entries.insert(
            CleanupHistoryEntry(
                id: UUID(),
                finishedAt: summary.finishedAt,
                categories: categories,
                summary: summary
            ),
            at: 0
        )
        entries = Array(entries.prefix(limit))
        guard let data = try? JSONEncoder().encode(entries) else { return }

        do {
            try fileManager.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // 历史记录是辅助信息，不应让清理失败。
        }
    }
}
