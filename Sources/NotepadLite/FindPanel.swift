import AppKit

private final class FindPanelWindow: NSPanel {
    override func cancelOperation(_ sender: Any?) { close() }
}

/// Notepad++-style Find & Replace with regular expressions, acting on the front editor.
final class FindPanelController: NSWindowController {
    static let shared = FindPanelController()

    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let caseBox = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
    private let wordBox = NSButton(checkboxWithTitle: "Whole word", target: nil, action: nil)
    private let regexBox = NSButton(checkboxWithTitle: "Regular expression", target: nil, action: nil)
    private let wrapBox = NSButton(checkboxWithTitle: "Wrap around", target: nil, action: nil)
    private let selectionBox = NSButton(checkboxWithTitle: "In selection", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")

    private init() {
        let panel = FindPanelWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 200),
                                    styleMask: [.titled, .closable, .utilityWindow],
                                    backing: .buffered, defer: true)
        panel.title = "Find & Replace"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        super.init(window: panel)
        buildUI(in: panel)
        panel.center()
        panel.setFrameAutosaveName("NotepadLiteFindPanel")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func buildUI(in panel: NSPanel) {
        wrapBox.state = .on
        for f in [findField, replaceField] {
            f.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            f.usesSingleLineMode = true
            f.cell?.isScrollable = true
            f.cell?.wraps = false
            f.translatesAutoresizingMaskIntoConstraints = false
            f.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        }
        findField.placeholderString = "Find"
        replaceField.placeholderString = "Replace with ($1, \\n, \\t in regex mode)"

        let options = NSStackView(views: [caseBox, wordBox, regexBox])
        options.spacing = 12
        let options2 = NSStackView(views: [wrapBox, selectionBox])
        options2.spacing = 12
        let optionsColumn = NSStackView(views: [options, options2])
        optionsColumn.orientation = .vertical
        optionsColumn.alignment = .leading
        optionsColumn.spacing = 6

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Find:"), findField],
            [NSTextField(labelWithString: "Replace:"), replaceField],
            [NSGridCell.emptyContentView, optionsColumn],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline

        func button(_ title: String, _ action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 120).isActive = true
            return b
        }
        let next = button("Find Next", #selector(findNext(_:)))
        next.keyEquivalent = "\r"
        let buttons = NSStackView(views: [
            next,
            button("Find Previous", #selector(findPrevious(_:))),
            button("Replace", #selector(replaceOne(_:))),
            button("Replace All", #selector(replaceAll(_:))),
            button("Count", #selector(count(_:))),
        ])
        buttons.orientation = .vertical
        buttons.spacing = 6

        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let top = NSStackView(views: [grid, buttons])
        top.alignment = .top
        top.spacing = 16
        let root = NSStackView(views: [top, status])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
    }

    func show(seed: String?) {
        if let seed, !seed.isEmpty, !seed.contains("\n") { findField.stringValue = seed }
        status.stringValue = ""
        showWindow(nil)
        window?.makeFirstResponder(findField)
        findField.selectText(nil)
    }

    private var editor: EditorTextView? {
        (NSApp.mainWindow?.windowController as? EditorWindowController)?.textView
    }

    private func makeRegex() -> NSRegularExpression? {
        var pattern = findField.stringValue
        guard !pattern.isEmpty else { return nil }
        if regexBox.state != .on { pattern = NSRegularExpression.escapedPattern(for: pattern) }
        if wordBox.state == .on { pattern = #"\b(?:"# + pattern + #")\b"# }
        var opts: NSRegularExpression.Options = [.anchorsMatchLines]
        if caseBox.state != .on { opts.insert(.caseInsensitive) }
        do {
            return try NSRegularExpression(pattern: pattern, options: opts)
        } catch {
            status.stringValue = "Invalid regular expression."
            return nil
        }
    }

    /// Replacement template; regex mode supports $1 and \n \t \r escapes.
    private var template: String {
        let raw = replaceField.stringValue
        guard regexBox.state == .on else { return NSRegularExpression.escapedTemplate(for: raw) }
        var out = ""
        var it = raw.makeIterator()
        while let c = it.next() {
            guard c == "\\", let n = it.next() else { out.append(c); continue }
            switch n {
            case "n": out.append("\n")
            case "t": out.append("\t")
            case "r": out.append("\n")
            default: out.append("\\"); out.append(n)
            }
        }
        return out
    }

    private func searchRange(_ tv: NSTextView) -> NSRange {
        let sel = tv.selectedRange()
        if selectionBox.state == .on, sel.length > 0 { return sel }
        return NSRange(location: 0, length: (tv.string as NSString).length)
    }

    @discardableResult
    private func find(forward: Bool) -> Bool {
        guard let tv = editor, let re = makeRegex() else { NSSound.beep(); return false }
        let text = tv.string
        let len = (text as NSString).length
        let sel = tv.selectedRange()
        var match: NSRange?
        var wrapped = false
        if forward {
            var start = NSMaxRange(sel)
            if sel.length == 0, let m = re.firstMatch(in: text, range: NSRange(location: start, length: len - start)),
               m.range.length == 0, m.range.location == start {
                start = min(len, start + 1)
            }
            match = re.firstMatch(in: text, range: NSRange(location: start, length: len - start))?.range
            if match == nil, wrapBox.state == .on {
                match = re.firstMatch(in: text, range: NSRange(location: 0, length: len))?.range
                wrapped = true
            }
        } else {
            match = re.matches(in: text, range: NSRange(location: 0, length: sel.location)).last?.range
            if match == nil, wrapBox.state == .on {
                match = re.matches(in: text, range: NSRange(location: 0, length: len)).last?.range
                wrapped = true
            }
        }
        guard let m = match else {
            status.stringValue = "“\(findField.stringValue)” not found."
            NSSound.beep()
            return false
        }
        tv.setSelectedRange(m)
        tv.scrollRangeToVisible(m)
        tv.showFindIndicator(for: m)
        status.stringValue = wrapped ? "Wrapped around." : ""
        return true
    }

    @objc func findNext(_ sender: Any?) { find(forward: true) }
    @objc func findPrevious(_ sender: Any?) { find(forward: false) }

    @objc func replaceOne(_ sender: Any?) {
        guard let tv = editor, let re = makeRegex() else { NSSound.beep(); return }
        let text = tv.string
        let sel = tv.selectedRange()
        if let m = re.firstMatch(in: text, options: [.anchored, .withTransparentBounds, .withoutAnchoringBounds], range: sel),
           m.range == sel {
            let rep = re.replacementString(for: m, in: text, offset: 0, template: template)
            tv.replace(sel, with: rep, select: NSRange(location: sel.location + (rep as NSString).length, length: 0),
                       action: "Replace")
        }
        find(forward: true)
    }

    @objc func replaceAll(_ sender: Any?) {
        guard let tv = editor, let re = makeRegex() else { NSSound.beep(); return }
        let text = tv.string
        let target = searchRange(tv)
        let matches = re.matches(in: text, range: target)
        guard !matches.isEmpty else {
            status.stringValue = "No occurrences found."
            NSSound.beep()
            return
        }
        let t = template
        let result = NSMutableString(string: (text as NSString).substring(with: target))
        for m in matches.reversed() {
            let rep = re.replacementString(for: m, in: text, offset: 0, template: t)
            result.replaceCharacters(in: NSRange(location: m.range.location - target.location, length: m.range.length), with: rep)
        }
        let caret = tv.selectedRange().location
        tv.replace(target, with: result as String,
                   select: selectionBox.state == .on ? NSRange(location: target.location, length: result.length)
                                                    : NSRange(location: caret, length: 0),
                   action: "Replace All")
        status.stringValue = "\(matches.count.formatted()) occurrence\(matches.count == 1 ? "" : "s") replaced."
    }

    @objc func count(_ sender: Any?) {
        guard let tv = editor, let re = makeRegex() else { NSSound.beep(); return }
        let n = re.numberOfMatches(in: tv.string, range: searchRange(tv))
        status.stringValue = "\(n.formatted()) match\(n == 1 ? "" : "es")."
    }
}
