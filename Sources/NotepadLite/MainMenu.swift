import AppKit

enum MainMenu {
    private static func key(_ functionKey: Int) -> String {
        String(Character(UnicodeScalar(UInt32(functionKey))!))
    }

    @discardableResult
    private static func add(_ menu: NSMenu, _ title: String, _ action: Selector?, _ key: String = "",
                            _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.tag = tag
        menu.addItem(item)
        return item
    }

    private static func submenu(_ parent: NSMenu, _ title: String) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        item.submenu = menu
        parent.addItem(item)
        return menu
    }

    static func build() -> NSMenu {
        let main = NSMenu()
        let appName = "Notepad Lite"

        // App
        let appMenu = submenu(main, appName)
        add(appMenu, "About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), "")
        appMenu.addItem(.separator())
        let services = submenu(appMenu, "Services")
        NSApp.servicesMenu = services
        appMenu.addItem(.separator())
        add(appMenu, "Hide \(appName)", #selector(NSApplication.hide(_:)), "h")
        add(appMenu, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        add(appMenu, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
        appMenu.addItem(.separator())
        add(appMenu, "Quit \(appName)", #selector(NSApplication.terminate(_:)), "q")

        // File
        let file = submenu(main, "File")
        add(file, "New", #selector(NSDocumentController.newDocument(_:)), "n")
        add(file, "New Tab", #selector(NSResponder.newWindowForTab(_:)), "t")
        add(file, "Open…", #selector(NSDocumentController.openDocument(_:)), "o")
        let recent = submenu(file, "Open Recent")
        add(recent, "Clear Menu", #selector(NSDocumentController.clearRecentDocuments(_:)))
        file.addItem(.separator())
        add(file, "Close Tab", #selector(NSWindow.performClose(_:)), "w")
        add(file, "Save", #selector(NSDocument.save(_:)), "s")
        add(file, "Save As…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift])
        add(file, "Save All", #selector(AppDelegate.saveAllDocuments(_:)), "s", [.command, .option])
        add(file, "Revert to Saved", #selector(NSDocument.revertToSaved(_:)))
        file.addItem(.separator())
        add(file, "Reveal in Finder", #selector(EditorWindowController.revealInFinder(_:)), "r", [.command, .shift])
        add(file, "Copy File Path", #selector(EditorWindowController.copyFilePath(_:)), "c", [.command, .control])
        file.addItem(.separator())
        add(file, "Page Setup…", #selector(NSDocument.runPageLayout(_:)), "p", [.command, .shift])
        add(file, "Print…", #selector(NSDocument.printDocument(_:)), "p")

        // Edit
        let edit = submenu(main, "Edit")
        add(edit, "Undo", Selector(("undo:")), "z")
        add(edit, "Redo", Selector(("redo:")), "z", [.command, .shift])
        edit.addItem(.separator())
        add(edit, "Cut", #selector(NSText.cut(_:)), "x")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Delete", #selector(NSText.delete(_:)))
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())

        let find = submenu(edit, "Find")
        add(find, "Find…", #selector(NSTextView.performTextFinderAction(_:)), "f",
            tag: NSTextFinder.Action.showFindInterface.rawValue)
        add(find, "Find and Replace…", #selector(NSTextView.performTextFinderAction(_:)), "f", [.command, .option],
            tag: NSTextFinder.Action.showReplaceInterface.rawValue)
        add(find, "Find & Replace (Regex)…", #selector(AppDelegate.showRegexFind(_:)), "f", [.command, .shift])
        add(find, "Find Next", #selector(NSTextView.performTextFinderAction(_:)), "g",
            tag: NSTextFinder.Action.nextMatch.rawValue)
        add(find, "Find Previous", #selector(NSTextView.performTextFinderAction(_:)), "g", [.command, .shift],
            tag: NSTextFinder.Action.previousMatch.rawValue)
        add(find, "Use Selection for Find", #selector(NSTextView.performTextFinderAction(_:)), "e",
            tag: NSTextFinder.Action.setSearchString.rawValue)
        add(find, "Jump to Selection", #selector(NSTextView.centerSelectionInVisibleArea(_:)), "j")
        add(edit, "Go to Line…", #selector(EditorWindowController.goToLine(_:)), "l")
        edit.addItem(.separator())

        let lines = submenu(edit, "Line Operations")
        add(lines, "Duplicate Line", #selector(EditorTextView.duplicateLines(_:)), "d")
        add(lines, "Delete Line", #selector(EditorTextView.deleteLines(_:)), "k", [.command, .shift])
        add(lines, "Move Line Up", #selector(EditorTextView.moveLinesUp(_:)), key(NSUpArrowFunctionKey), .option)
        add(lines, "Move Line Down", #selector(EditorTextView.moveLinesDown(_:)), key(NSDownArrowFunctionKey), .option)
        add(lines, "Join Lines", #selector(EditorTextView.joinSelectedLines(_:)), "j", [.command, .control])
        lines.addItem(.separator())
        add(lines, "Sort Lines Ascending", #selector(EditorTextView.sortLinesAscending(_:)))
        add(lines, "Sort Lines Descending", #selector(EditorTextView.sortLinesDescending(_:)))
        add(lines, "Remove Duplicate Lines", #selector(EditorTextView.removeDuplicateLines(_:)))
        add(lines, "Remove Empty Lines", #selector(EditorTextView.removeEmptyLines(_:)))
        add(lines, "Trim Trailing Whitespace", #selector(EditorTextView.trimTrailingWhitespace(_:)))

        let indent = submenu(edit, "Indentation")
        add(indent, "Indent", #selector(EditorTextView.indentSelection(_:)), "]")
        add(indent, "Outdent", #selector(EditorTextView.outdentSelection(_:)), "[")
        indent.addItem(.separator())
        add(indent, "Tabs to Spaces", #selector(EditorTextView.tabsToSpaces(_:)))
        add(indent, "Leading Spaces to Tabs", #selector(EditorTextView.leadingSpacesToTabs(_:)))

        let caseMenu = submenu(edit, "Convert Case")
        add(caseMenu, "UPPERCASE", #selector(EditorTextView.convertToUppercase(_:)), "u", [.command, .shift])
        add(caseMenu, "lowercase", #selector(EditorTextView.convertToLowercase(_:)), "u")
        add(caseMenu, "Title Case", #selector(EditorTextView.convertToTitleCase(_:)))

        add(edit, "Toggle Comment", #selector(EditorTextView.toggleLineComment(_:)), "/")
        edit.addItem(.separator())
        let dir = submenu(edit, "Writing Direction")
        add(dir, "Natural", #selector(NSResponder.makeBaseWritingDirectionNatural(_:)))
        add(dir, "Left to Right", #selector(NSResponder.makeBaseWritingDirectionLeftToRight(_:)))
        add(dir, "Right to Left", #selector(NSResponder.makeBaseWritingDirectionRightToLeft(_:)))

        // View
        let view = submenu(main, "View")
        add(view, "Word Wrap", #selector(AppDelegate.toggleWordWrap(_:)), "w", [.command, .option])
        add(view, "Line Numbers", #selector(AppDelegate.toggleLineNumbers(_:)))
        add(view, "Highlight Current Line", #selector(AppDelegate.toggleCurrentLine(_:)))
        view.addItem(.separator())
        add(view, "Zoom In", #selector(AppDelegate.increaseFontSize(_:)), "=")
        add(view, "Zoom Out", #selector(AppDelegate.decreaseFontSize(_:)), "-")
        add(view, "Actual Size", #selector(AppDelegate.resetFontSize(_:)), "0")
        view.addItem(.separator())
        let tabs = submenu(view, "Tabs & Indent")
        add(tabs, "Indent Using Spaces", #selector(AppDelegate.toggleIndentWithSpaces(_:)))
        add(tabs, "Auto-Indent", #selector(AppDelegate.toggleAutoIndent(_:)))
        tabs.addItem(.separator())
        for w in [2, 4, 8] { add(tabs, "Tab Width: \(w)", #selector(AppDelegate.setTabWidth(_:)), tag: w) }
        view.addItem(.separator())

        // Language
        let language = submenu(main, "Language")
        for (i, lang) in Language.all.enumerated() {
            add(language, lang.name, #selector(EditorWindowController.setLanguage(_:)), tag: i)
            if i == 0 { language.addItem(.separator()) }
        }

        // Encoding
        let encoding = submenu(main, "Encoding")
        let convert = submenu(encoding, "Convert To")
        let reopen = submenu(encoding, "Reopen With")
        for (i, enc) in TextEncoding.all.enumerated() {
            add(convert, enc.title, #selector(EditorWindowController.convertEncoding(_:)), tag: i)
            add(reopen, enc.title, #selector(EditorWindowController.reopenWithEncoding(_:)), tag: i)
        }
        encoding.addItem(.separator())
        let eolHeader = NSMenuItem(title: "Line Endings", action: nil, keyEquivalent: "")
        eolHeader.isEnabled = false
        encoding.addItem(eolHeader)
        for e in LineEnding.allCases {
            add(encoding, e.title, #selector(EditorWindowController.setLineEnding(_:)), tag: e.rawValue).indentationLevel = 1
        }

        // Window
        let window = submenu(main, "Window")
        add(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(window, "Zoom", #selector(NSWindow.performZoom(_:)))
        window.addItem(.separator())
        add(window, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        NSApp.windowsMenu = window

        // Help
        let help = submenu(main, "Help")
        NSApp.helpMenu = help

        return main
    }
}
