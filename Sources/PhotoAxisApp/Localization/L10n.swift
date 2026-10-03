import Foundation

final class L10n {
    let language: String
    private let selected: Bundle
    private let fallback: Bundle

    init(choice: InterfaceLanguage, preferredLanguages: [String] = Locale.preferredLanguages, bundle: Bundle = .main) {
        language = choice.resolved(preferredLanguages: preferredLanguages)
        fallback = bundle.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        selected = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? fallback
    }

    func text(_ key: String) -> String {
        let english = fallback.localizedString(forKey: key, value: key, table: "Localizable")
        return selected.localizedString(forKey: key, value: english, table: "Localizable")
    }
}
