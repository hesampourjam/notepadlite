import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = Prefs.shared
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private var frontEditor: EditorWindowController? {
        NSApp.mainWindow?.windowController as? EditorWindowController
    }

    // MARK: - File

    @objc func saveAllDocuments(_ sender: Any?) {
        for doc in NSDocumentController.shared.documents where doc.isDocumentEdited { doc.save(sender) }
    }

    @objc func showRegexFind(_ sender: Any?) {
        var seed: String?
        if let tv = frontEditor?.textView, tv.selectedRange().length > 0 {
            seed = (tv.string as NSString).substring(with: tv.selectedRange())
        }
        FindPanelController.shared.show(seed: seed)
    }

    // MARK: - View preferences

    @objc func toggleWordWrap(_ sender: Any?) { Prefs.shared.wordWrap.toggle() }
    @objc func toggleLineNumbers(_ sender: Any?) { Prefs.shared.showLineNumbers.toggle() }
    @objc func toggleCurrentLine(_ sender: Any?) { Prefs.shared.highlightCurrentLine.toggle() }
    @objc func toggleIndentWithSpaces(_ sender: Any?) { Prefs.shared.indentWithSpaces.toggle() }
    @objc func toggleAutoIndent(_ sender: Any?) { Prefs.shared.autoIndent.toggle() }
    @objc func increaseFontSize(_ sender: Any?) { Prefs.shared.fontSize += 1 }
    @objc func decreaseFontSize(_ sender: Any?) { Prefs.shared.fontSize -= 1 }
    @objc func resetFontSize(_ sender: Any?) { Prefs.shared.fontSize = 13 }
    @objc func setTabWidth(_ sender: Any?) {
        if let tag = (sender as? NSMenuItem)?.tag, tag > 0 { Prefs.shared.tabWidth = tag }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        let p = Prefs.shared
        switch item.action {
        case #selector(toggleWordWrap(_:)): item.state = p.wordWrap ? .on : .off
        case #selector(toggleLineNumbers(_:)): item.state = p.showLineNumbers ? .on : .off
        case #selector(toggleCurrentLine(_:)): item.state = p.highlightCurrentLine ? .on : .off
        case #selector(toggleIndentWithSpaces(_:)): item.state = p.indentWithSpaces ? .on : .off
        case #selector(toggleAutoIndent(_:)): item.state = p.autoIndent ? .on : .off
        case #selector(setTabWidth(_:)): item.state = item.tag == p.tabWidth ? .on : .off
        case #selector(showRegexFind(_:)): return frontEditor != nil
        default: break
        }
        return true
    }
}
