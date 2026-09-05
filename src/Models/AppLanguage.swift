import Combine
import Foundation

enum L10nKey: String, CaseIterable, Codable, Hashable, Sendable {
    case menuTheme = "menu.theme"
    case menuFollowSystem = "menu.followSystem"
    case menuLight = "menu.light"
    case menuDark = "menu.dark"
    case menuLanguage = "menu.language"
    case menuLanguageSystemName = "menu.language.systemName"
    case menuLanguageSimplifiedChineseName = "menu.language.simplifiedChineseName"
    case menuLanguageEnglishName = "menu.language.englishName"
    case menuSimplifiedChinese = "menu.simplifiedChinese"
    case menuEnglish = "menu.english"
    case menuQuit = "menu.quit"
    case appStartupDisk = "app.startupDisk"
    case appAvailableSpace = "app.availableSpace"
    case appZeroKilobytes = "app.zeroKilobytes"
    case appUnknownValue = "app.unknownValue"
    case idleCleanNow = "idle.cleanNow"
    case idleSafeScanHelp = "idle.safeScanHelp"
    case idleSafeScanDescription = "idle.safeScanDescription"
    case idleFullDiskAccessRequired = "idle.fullDiskAccessRequired"
    case idleMoreCompleteScanResults = "idle.moreCompleteScanResults"
    case idleOpenSettings = "idle.openSettings"
    case idleCheckDiskAccessAgain = "idle.checkDiskAccessAgain"
    case viewScanning = "view.scanning"
    case viewScanComplete = "view.scanComplete"
    case viewCleaning = "view.cleaning"
    case viewCleanupComplete = "view.cleanupComplete"
    case viewCleanupPartiallyComplete = "view.cleanupPartiallyComplete"
    case viewProcessing = "view.processing"
    case viewScannedComplete = "view.scannedComplete"
    case viewScanProgress = "view.scanProgress"
    case viewPreparingUnifiedScan = "view.preparingUnifiedScan"
    case viewNoCleanupItems = "view.noCleanupItems"
    case viewCancel = "view.cancel"
    case viewScanned = "view.scanned"
    case viewItems = "view.items"
    case viewUnknownSize = "view.unknownSize"
    case viewCleanupItems = "view.cleanupItems"
    case viewSelected = "view.selected"
    case viewMoveToTrash = "view.moveToTrash"
    case viewDone = "view.done"
    case viewAddToExclusions = "view.addToExclusions"
    case viewFailurePrefix = "view.failurePrefix"
    case viewBeforeCleanup = "view.beforeCleanup"
    case viewAfterCleanup = "view.afterCleanup"
    case viewCleaned = "view.cleaned"
    case viewFailed = "view.failed"
    case viewNoCleanupResults = "view.noCleanupResults"
    case categoryRoutineTitle = "category.routineTitle"
    case categoryAnalysisTitle = "category.analysisTitle"
    case categoryDeveloperTitle = "category.developerTitle"
    case categoryRoutineDetail = "category.routineDetail"
    case categoryAnalysisDetail = "category.analysisDetail"
    case categoryDeveloperDetail = "category.developerDetail"
    case providerDeepCleanupTitle = "provider.deepCleanupTitle"
    case providerApplicationsTitle = "provider.applicationsTitle"
    case providerProjectArtifactsTitle = "provider.projectArtifactsTitle"
    case providerSpaceAnalysisTitle = "provider.spaceAnalysisTitle"
    case providerDeepCleanupDetail = "provider.deepCleanupDetail"
    case providerApplicationsDetail = "provider.applicationsDetail"
    case providerProjectArtifactsDetail = "provider.projectArtifactsDetail"
    case providerSpaceAnalysisDetail = "provider.spaceAnalysisDetail"
    case providerPending = "provider.pending"
    case providerRunning = "provider.running"
    case providerCompleted = "provider.completed"
    case providerPartial = "provider.partial"
    case providerSkipped = "provider.skipped"
    case providerFailed = "provider.failed"
    case diskFullTitle = "disk.fullTitle"
    case diskLimitedTitle = "disk.limitedTitle"
    case diskFullDetail = "disk.fullDetail"
    case diskLimitedDetail = "disk.limitedDetail"
    case riskSafe = "risk.safe"
    case riskReview = "risk.review"
    case riskAdvanced = "risk.advanced"
    case riskProtected = "risk.protected"
    case removalTrash = "removal.trash"
    case removalPrivilegedTrash = "removal.privilegedTrash"
    case removalTimeMachine = "removal.timeMachine"
    case outcomeMovedToTrash = "outcome.movedToTrash"
    case outcomeRemoved = "outcome.removed"
    case outcomeSkipped = "outcome.skipped"
    case outcomeFailed = "outcome.failed"
    case outcomeCancelled = "outcome.cancelled"
    case volumeMeasured = "volume.measured"
    case volumeEstimated = "volume.estimated"
    case volumeProtected = "volume.protected"
    case volumeUnavailable = "volume.unavailable"
    case diagnosticSkippedInUse = "diagnostic.skippedInUse"
    case diagnosticUnreadable = "diagnostic.unreadable"
    case errorAuthorizationCancelled = "error.authorizationCancelled"
    case errorSafetyCheck = "error.safetyCheck"
    case errorTaskFailed = "error.taskFailed"
    case errorFeatureUnavailable = "error.featureUnavailable"
    case scanCancelledBeforeStart = "scan.cancelledBeforeStart"
    case scanCompleteReviewTrashItems = "scan.completeReviewTrashItems"
    case scanPhaseCacheCleanup = "scan.phaseCacheCleanup"
    case scanPhaseProjectArtifacts = "scan.phaseProjectArtifacts"
    case scanPhaseAppRemnants = "scan.phaseAppRemnants"
    case scanPhaseLargeFiles = "scan.phaseLargeFiles"
    case scanFindingInstalledApps = "scan.findingInstalledApps"
    case scanFindingAppRemnants = "scan.findingAppRemnants"
    case scanCalculatingAppRemnantSizes = "scan.calculatingAppRemnantSizes"
    case scanNoAppRemnants = "scan.noAppRemnants"
    case scanFindingInstallers = "scan.findingInstallers"
    case scanNoConfirmedInstallers = "scan.noConfirmedInstallers"
    case scanLookingForInstallers = "scan.lookingForInstallers"
    case scanAnalyzingStartupDiskAndTimeMachine = "scan.analyzingStartupDiskAndTimeMachine"
    case scanFindingCachesAndOldLogs = "scan.findingCachesAndOldLogs"
    case scanCachesScanned = "scan.cachesScanned"
    case scanNoSafeCleanupItems = "scan.noSafeCleanupItems"
    case scanInvalidStartupDisk = "scan.invalidStartupDisk"
    case scanReadingStartupDisk = "scan.readingStartupDisk"
    case scanWalkingStartupDisk = "scan.walkingStartupDisk"
    case scanCancelledPreserved = "scan.cancelledPreserved"
    case scanStartupDiskTimeout = "scan.startupDiskTimeout"
    case scanUnreadableDirectory = "scan.unreadableDirectory"
    case scanProtectedPathOverview = "scan.protectedPathOverview"
    case scanStartupDiskLargeFile = "scan.startupDiskLargeFile"
    case scanStartupDiskLargeDirectory = "scan.startupDiskLargeDirectory"
    case scanNoMeasurableUserFiles = "scan.noMeasurableUserFiles"
    case scanPartiallyComplete = "scan.partiallyComplete"
    case scanFindingProjectArtifacts = "scan.findingProjectArtifacts"
    case scanCalculatingProjectArtifactSizes = "scan.calculatingProjectArtifactSizes"
    case scanNoOldProjectArtifacts = "scan.noOldProjectArtifacts"
    case scanTmutilUnavailable = "scan.tmutilUnavailable"
    case scanTimeMachineStatusTimeout = "scan.timeMachineStatusTimeout"
    case scanTimeMachineStatusUnreadable = "scan.timeMachineStatusUnreadable"
    case scanTimeMachineRunningSkipped = "scan.timeMachineRunningSkipped"
    case scanLocalSnapshotsTimeout = "scan.localSnapshotsTimeout"
    case scanLocalSnapshotsUnreadable = "scan.localSnapshotsUnreadable"
    case scanNoLocalSnapshots = "scan.noLocalSnapshots"
    case timeMachineLocalSnapshot = "timeMachine.localSnapshot"
    case sourceLargeFileTimeMachine = "source.largeFileTimeMachine"
    case sourceSafariCache = "source.safariCache"
    case sourceXcodeCache = "source.xcodeCache"
    case sourcePipCache = "source.pipCache"
    case sourceNpmCache = "source.npmCache"
    case sourcePnpmStore = "source.pnpmStore"
    case sourceHomebrewCache = "source.homebrewCache"
    case sourceXcodeDerivedData = "source.xcodeDerivedData"
    case sourceCocoaPodsCache = "source.cocoaPodsCache"
    case sourceSwiftPMCache = "source.swiftPMCache"
    case sourceYarnCache = "source.yarnCache"
    case sourceYarnBerryCache = "source.yarnBerryCache"
    case sourceBunCache = "source.bunCache"
    case sourceCargoRegistryCache = "source.cargoRegistryCache"
    case sourceCargoGitCache = "source.cargoGitCache"
    case sourceGradleCache = "source.gradleCache"
    case sourceGoBuildCache = "source.goBuildCache"
    case sourceGoModuleDownloadCache = "source.goModuleDownloadCache"
    case sourceUserOldLogs = "source.userOldLogs"
    case sourceSystemSafariCache = "source.systemSafariCache"
    case sourceSystemXcodeCache = "source.systemXcodeCache"
    case sourceSystemOldLogs = "source.systemOldLogs"
    case sourceAppRemnants = "source.appRemnants"
    case sourceInstallers = "source.installers"
    case sourceProjectBuildArtifacts = "source.projectBuildArtifacts"
    case sourceAddedToExclusions = "source.addedToExclusions"
    case cleanupNoTrashPermission = "cleanup.noTrashPermission"
    case cleanupRecheckingItems = "cleanup.recheckingItems"
    case cleanupNothingSelected = "cleanup.nothingSelected"
    case cleanupMissingFilePath = "cleanup.missingFilePath"
    case cleanupAdministratorPermissionRequired = "cleanup.administratorPermissionRequired"
    case cleanupTrashPermissionRetry = "cleanup.trashPermissionRetry"
    case cleanupCandidateChanged = "cleanup.candidateChanged"
    case cleanupCandidateMissing = "cleanup.candidateMissing"
    case cleanupAdministratorPathValidationFailed = "cleanup.administratorPathValidationFailed"
    case cleanupAdministratorOperationFailed = "cleanup.administratorOperationFailed"
    case cleanupAdministratorOperationComplete = "cleanup.administratorOperationComplete"
    case cleanupCancelled = "cleanup.cancelled"
    case cleanupUnknownError = "cleanup.unknownError"
    case viewItemCount = "view.itemCount"
    case viewScannedItems = "view.scannedItems"
    case viewSelectedSummary = "view.selectedSummary"
    case viewFailureMessage = "view.failureMessage"
    case viewRescan = "view.rescan"
    case appStartupDiskHeader = "app.startupDiskHeader"
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese
    case english

    static let userDefaultsKey = "CleanMac.appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
            return Self.locale(for: preferredLanguage)
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    static func locale(for preferredLanguage: String) -> Locale {
        if preferredLanguage.hasPrefix("zh") {
            return Locale(identifier: "zh-Hans")
        }
        if preferredLanguage.hasPrefix("en") {
            return Locale(identifier: "en")
        }
        return Locale(identifier: "zh-Hans")
    }

    func displayTitle(in locale: Locale) -> String {
        switch self {
        case .system:
            return L10n.resolve(.menuLanguageSystemName, locale: locale)
        case .simplifiedChinese:
            return L10n.resolve(.menuLanguageSimplifiedChineseName, locale: Locale(identifier: "zh-Hans"))
        case .english:
            return L10n.resolve(.menuLanguageEnglishName, locale: Locale(identifier: "en"))
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: userDefaultsKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return .system
        }
        return language
    }
}

final class LocalizationStore: ObservableObject {
    @Published var selectedLanguage: AppLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: AppLanguage.userDefaultsKey)
        }
    }

    private let defaults: UserDefaults
    private var systemLocaleObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedLanguage = AppLanguage.load(from: defaults)
        self.systemLocaleObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.selectedLanguage == .system else { return }
            self.objectWillChange.send()
        }
    }

    deinit {
        if let systemLocaleObserver {
            NotificationCenter.default.removeObserver(systemLocaleObserver)
        }
    }

    var locale: Locale {
        selectedLanguage.locale
    }
}

indirect enum LocalizedMessage: Codable, Hashable, Sendable {
    case key(L10nKey)
    case skippedInUse(String)
    case unreadableDirectory(String)
    case failure(LocalizedMessage)
    case invalidPath(String)
    case candidateChanged(String)
    case candidateMissing(String)
    case taskFailed(String)
    case unavailable(String)
    case raw(String)

    private enum CodingKeys: String, CodingKey {
        case key
        case skippedInUse
        case unreadableDirectory
        case failure
        case invalidPath
        case candidateChanged
        case candidateMissing
        case taskFailed
        case unavailable
        case raw
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let legacyValue = try? singleValue.decode(String.self) {
            self = .raw(legacyValue)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let key = try container.decodeIfPresent(L10nKey.self, forKey: .key) {
            self = .key(key)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .skippedInUse) {
            self = .skippedInUse(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .unreadableDirectory) {
            self = .unreadableDirectory(value)
        } else if let value = try container.decodeIfPresent(LocalizedMessage.self, forKey: .failure) {
            self = .failure(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .invalidPath) {
            self = .invalidPath(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .candidateChanged) {
            self = .candidateChanged(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .candidateMissing) {
            self = .candidateMissing(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .taskFailed) {
            self = .taskFailed(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .unavailable) {
            self = .unavailable(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .raw) {
            self = .raw(value)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported localized message"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .key(let key): try container.encode(key, forKey: .key)
        case .skippedInUse(let value): try container.encode(value, forKey: .skippedInUse)
        case .unreadableDirectory(let value): try container.encode(value, forKey: .unreadableDirectory)
        case .failure(let value): try container.encode(value, forKey: .failure)
        case .invalidPath(let value): try container.encode(value, forKey: .invalidPath)
        case .candidateChanged(let value): try container.encode(value, forKey: .candidateChanged)
        case .candidateMissing(let value): try container.encode(value, forKey: .candidateMissing)
        case .taskFailed(let value): try container.encode(value, forKey: .taskFailed)
        case .unavailable(let value): try container.encode(value, forKey: .unavailable)
        case .raw(let value): try container.encode(value, forKey: .raw)
        }
    }

    func resolve(in locale: Locale) -> String {
        switch self {
        case .key(let key):
            return L10n.resolve(key, locale: locale)
        case .skippedInUse(let name):
            return "\(L10n.resolve(.diagnosticSkippedInUse, locale: locale)) \(name)"
        case .unreadableDirectory(let path):
            return "\(L10n.resolve(.diagnosticUnreadable, locale: locale)) \(path)"
        case .failure(let reason):
            return L10n.format(.viewFailureMessage, locale: locale, reason.resolve(in: locale))
        case .invalidPath(let path):
            return "\(L10n.resolve(.errorSafetyCheck, locale: locale)): \(path)"
        case .candidateChanged(let path):
            return "\(L10n.resolve(.cleanupCandidateChanged, locale: locale)): \(path)"
        case .candidateMissing(let path):
            return "\(L10n.resolve(.cleanupCandidateMissing, locale: locale)): \(path)"
        case .taskFailed(let message):
            return "\(L10n.resolve(.errorTaskFailed, locale: locale)): \(message)"
        case .unavailable(let message):
            return "\(L10n.resolve(.errorFeatureUnavailable, locale: locale)): \(message)"
        case .raw(let value):
            return value
        }
    }

    var requiresRescan: Bool {
        switch self {
        case .candidateChanged, .candidateMissing:
            return true
        case .failure(let reason):
            return reason.requiresRescan
        default:
            return false
        }
    }
}

enum L10n {
    static func resolve(_ key: L10nKey, locale: Locale) -> String {
        let bundle = Bundle.main
        let localeIdentifiers = [locale.identifier, locale.language.languageCode?.identifier].compactMap { $0 }
        for identifier in localeIdentifiers {
            guard let resourcePath = bundle.path(forResource: identifier, ofType: "lproj"),
                  let localizedBundle = Bundle(path: resourcePath) else { continue }
            return localizedBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: "Localizable")
        }
        return key.rawValue
    }

    static func message(_ key: L10nKey) -> LocalizedMessage {
        .key(key)
    }

    static func resolve(_ message: LocalizedMessage, locale: Locale) -> String {
        message.resolve(in: locale)
    }

    static func itemCount(_ count: Int, locale: Locale) -> String {
        format(.viewItemCount, locale: locale, Int64(count))
    }

    static func scannedItems(_ count: Int, locale: Locale) -> String {
        format(.viewScannedItems, locale: locale, Int64(count))
    }

    static func selectedSummary(selectedCount: Int, totalCount: Int, size: String, locale: Locale) -> String {
        format(.viewSelectedSummary, locale: locale, Int64(selectedCount), Int64(totalCount), size)
    }

    static func startupDiskHeader(availableSpace: String, locale: Locale) -> String {
        format(.appStartupDiskHeader, locale: locale, availableSpace)
    }

    static func format(_ key: L10nKey, locale: Locale, _ arguments: CVarArg...) -> String {
        String(format: resolve(key, locale: locale), locale: locale, arguments: arguments)
    }
}
