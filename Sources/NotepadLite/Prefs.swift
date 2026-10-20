import AppKit

/// Global editor preferences, persisted in UserDefaults.
final class Prefs {
    static let shared = Prefs()
    static let didChange = Notification.Name("NotepadLitePrefsDidChange")

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "fontSize": 13.0,
            "wordWrap": false,
            "showLineNumbers": true,
            "highlightCurrentLine": true,
            "indentWithSpaces": false,
            "tabWidth": 4,
            "autoIndent": true,
        ])
    }

    var fontSize: CGFloat {
        get { CGFloat(defaults.double(forKey: "fontSize")) }
        set { defaults.set(Double(min(max(newValue, 8), 48)), forKey: "fontSize"); changed() }
    }
    var wordWrap: Bool {
        get { defaults.bool(forKey: "wordWrap") }
        set { defaults.set(newValue, forKey: "wordWrap"); changed() }
    }
    var showLineNumbers: Bool {
        get { defaults.bool(forKey: "showLineNumbers") }
        set { defaults.set(newValue, forKey: "showLineNumbers"); changed() }
    }
    var highlightCurrentLine: Bool {
        get { defaults.bool(forKey: "highlightCurrentLine") }
        set { defaults.set(newValue, forKey: "highlightCurrentLine"); changed() }
    }
    var indentWithSpaces: Bool {
        get { defaults.bool(forKey: "indentWithSpaces") }
        set { defaults.set(newValue, forKey: "indentWithSpaces"); changed() }
    }
    var tabWidth: Int {
        get { max(1, defaults.integer(forKey: "tabWidth")) }
        set { defaults.set(newValue, forKey: "tabWidth"); changed() }
    }
    var autoIndent: Bool {
        get { defaults.bool(forKey: "autoIndent") }
        set { defaults.set(newValue, forKey: "autoIndent"); changed() }
    }

    var font: NSFont { NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular) }

    private func changed() {
        NotificationCenter.default.post(name: Prefs.didChange, object: nil)
    }
}
