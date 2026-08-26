import Foundation

struct AppLocalization: Sendable {
    let locale: Locale

    func resolve(_ key: L10nKey) -> String {
        L10n.resolve(key, locale: locale)
    }

    func resolve(_ message: LocalizedMessage) -> String {
        L10n.resolve(message, locale: locale)
    }
}
