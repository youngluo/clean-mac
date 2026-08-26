import XCTest
@testable import CleanMac

final class AppLanguageTests: XCTestCase {
    func testUnknownStoredLanguageFallsBackToSystem() {
        let suiteName = "CleanMacLanguageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("klingon", forKey: AppLanguage.userDefaultsKey)

        XCTAssertEqual(AppLanguage.load(from: defaults), .system)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLocalizationStorePersistsSelection() {
        let suiteName = "CleanMacLanguageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = LocalizationStore(defaults: defaults)

        XCTAssertEqual(store.selectedLanguage, .system)
        store.selectedLanguage = .english

        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
        XCTAssertEqual(store.locale.identifier, "en")
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testExplicitLanguageLocalesAreStable() {
        XCTAssertEqual(AppLanguage.simplifiedChinese.locale.identifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.english.locale.identifier, "en")
    }

    func testUnsupportedSystemLanguageFallsBackToSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.locale(for: "fr-FR").identifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.locale(for: "en-GB").identifier, "en")
    }

    func testMenuLanguageTitlesUseLocalizedSystemAndNativeLanguageNames() {
        XCTAssertEqual(AppLanguage.system.displayTitle(in: Locale(identifier: "en")), "System")
        XCTAssertEqual(AppLanguage.simplifiedChinese.displayTitle(in: Locale(identifier: "en")), "简体中文")
        XCTAssertEqual(AppLanguage.english.displayTitle(in: Locale(identifier: "en")), "English")
        XCTAssertEqual(AppLanguage.system.displayTitle(in: Locale(identifier: "zh-Hans")), "跟随系统")
        XCTAssertEqual(AppLanguage.simplifiedChinese.displayTitle(in: Locale(identifier: "zh-Hans")), "简体中文")
        XCTAssertEqual(AppLanguage.english.displayTitle(in: Locale(identifier: "zh-Hans")), "English")
    }

    func testEverySemanticKeyHasBothSupportedTranslations() {
        for key in L10nKey.allCases {
            XCTAssertNotEqual(L10n.resolve(key, locale: Locale(identifier: "zh-Hans")), key.rawValue, key.rawValue)
            XCTAssertNotEqual(L10n.resolve(key, locale: Locale(identifier: "en")), key.rawValue, key.rawValue)
        }
    }

    func testLocalizedMessageResolvesAtDisplayLocale() {
        let message = LocalizedMessage.failure(.key(.cleanupTrashPermissionRetry))
        let english = message.resolve(in: Locale(identifier: "en"))
        let chinese = message.resolve(in: Locale(identifier: "zh-Hans"))

        XCTAssertTrue(english.hasPrefix("Failed: "))
        XCTAssertTrue(chinese.hasPrefix("失败："))
        XCTAssertNotEqual(english, chinese)
    }

    func testLocalizedMessagePreservesRawExternalText() {
        let path = "/Users/young/Library/Caches/com.example"
        let message = LocalizedMessage.unreadableDirectory(path)

        XCTAssertTrue(message.resolve(in: Locale(identifier: "en")).contains(path))
        XCTAssertTrue(message.resolve(in: Locale(identifier: "zh-Hans")).contains(path))
    }

    func testLocalizedMessageDecodesLegacyStoredString() throws {
        let message = try JSONDecoder().decode(
            LocalizedMessage.self,
            from: Data("\"legacy cleanup message\"".utf8)
        )

        XCTAssertEqual(message, .raw("legacy cleanup message"))
    }
}
