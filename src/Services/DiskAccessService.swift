import AppKit
import Foundation

final class DiskAccessService {
    private let startupVolumeURL: URL
    private let fileManager: FileManager
    private let fullDiskAccessProbeURL: URL

    init(
        startupVolumeURL: URL,
        fileManager: FileManager,
        fullDiskAccessProbeURL: URL
    ) {
        self.startupVolumeURL = startupVolumeURL.standardizedFileURL
        self.fileManager = fileManager
        self.fullDiskAccessProbeURL = fullDiskAccessProbeURL.standardizedFileURL
    }

    var availableBytes: Int64? {
        guard let values = try? startupVolumeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]) else {
            return nil
        }
        return values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map { Int64($0) }
    }

    var accessStatus: DiskAccessStatus {
        guard fileManager.fileExists(atPath: fullDiskAccessProbeURL.path) else { return .limited }
        do {
            _ = try Data(contentsOf: fullDiskAccessProbeURL, options: [.mappedIfSafe])
            return .full
        } catch {
            return .limited
        }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
