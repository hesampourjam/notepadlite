import AppKit

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSMenuItemValidation {
    let textView: EditorTextView
    let scrollView = NSScrollView()
    let statusBar = StatusBarView()
    let lineIndex = LineIndex()
    private(set) var ruler: LineNumberRulerView!
    private weak var editorDocument: Document?
    private static let frameName = "NotepadLiteEditorWindow"

    init(document: Document) {
        editorDocument = document

        // TextKit 1 stack (needed for the line-number ruler and temporary-attribute highlighting).
        let storage = NSTextStorage()
        let lm = NSLayoutManager()
        lm.allowsNonContiguousLayout = true
        storage.addLayoutManager(lm)
        let tc = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        tc.widthTracksTextView = true
        lm.addTextContainer(tc)
        textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 900, height: 600), textContainer: tc)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 420, height: 240)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "NotepadLiteEditor"
        super.init(window: window)

        lineIndex.source = { [unowned self] in self.textView.string as NSString }
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) { window.center() }
        shouldCascadeWindows = true

        buildLayout(in: window)
        configureTextView()
        applyPrefs()
        loadFromDocument()

        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged),
                                               name: Prefs.didChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup

    private func buildLayout(in window: NSWindow) {
        let content = NSView()
        window.contentView = content

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)
        content.addSubview(statusBar)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),
        ])

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        ruler = LineNumberRulerView(scrollView: scrollView, textView: textView, lineIndex: lineIndex)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(didScroll),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

        statusBar.setTarget(self, language: #selector(setLanguage(_:)),
                            eol: #selector(setLineEnding(_:)), encoding: #selector(convertEncoding(_:)))
    }

    private func configureTextView() {
        let tv = textView
        tv.delegate = self
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.usesFontPanel = false
        tv.usesRuler = false
        tv.allowsDocumentBackgroundColorChange = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.smartInsertDeleteEnabled = false
        if #available(macOS 14.0, *) { tv.inlinePredictionType = .no }
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.insertionPointColor = .textColor
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
    }

    // MARK: - Preferences

    @objc private func prefsChanged() { applyPrefs() }

    func applyPrefs() {
        let p = Prefs.shared
        textView.tabWidth = p.tabWidth
        textView.indentWithSpaces = p.indentWithSpaces
        textView.autoIndent = p.autoIndent
        textView.highlightCurrentLine = p.highlightCurrentLine
        applyTextAttributes()
        ruler.labelFont = .monospacedDigitSystemFont(ofSize: max(9, p.fontSize - 2), weight: .regular)
        scrollView.rulersVisible = p.showLineNumbers
        applyWrap(p.wordWrap)
        ruler.updateThickness()
        ruler.needsDisplay = true
        textView.needsDisplay = true
    }

    private func applyTextAttributes() {
        let font = Prefs.shared.font
        let para = NSMutableParagraphStyle()
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        para.tabStops = []
        para.defaultTabInterval = spaceWidth * CGFloat(Prefs.shared.tabWidth)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para, .foregroundColor: NSColor.textColor]
        textView.font = font
        textView.defaultParagraphStyle = para
        textView.typingAttributes = attrs
        if let ts = textView.textStorage, ts.length > 0 {
            ts.beginEditing()
            ts.setAttributes(attrs, range: NSRange(location: 0, length: ts.length))
            ts.endEditing()
        }
    }

    private func applyWrap(_ wrap: Bool) {
        guard let tc = textView.textContainer else { return }
        let contentSize = scrollView.contentSize
        if wrap {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            tc.widthTracksTextView = true
            textView.setFrameSize(NSSize(width: contentSize.width, height: textView.frame.height))
            tc.size = NSSize(width: max(0, contentSize.width - 2 * textView.textContainerInset.width),
                             height: CGFloat.greatestFiniteMagnitude)
        } else {
            scrollView.hasHorizontalScroller = true
            tc.widthTracksTextView = false
            tc.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width, .height]
        }
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.sizeToFit()
    }

    // MARK: - Document sync

    func loadFromDocument() {
        guard let doc = editorDocument else { return }
        textView.string = doc.text
        applyTextAttributes()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        doc.undoManager?.removeAllActions()
        languageDidChange()
        textChanged()
    }

    func languageDidChange() {
        guard let lang = editorDocument?.language else { return }
        textView.lineComment = lang.lineComment
        textView.blockComment = lang.blockComment
        textView.indentAfterColon = lang.indentAfterColon
        runHighlight()
        refreshStatus()
    }

    // MARK: - Highlighting

    private func scheduleHighlight() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runHighlight), object: nil)
        perform(#selector(runHighlight), with: nil, afterDelay: 0.08)
    }

    @objc private func runHighlight() {
        guard let lang = editorDocument?.language, let lm = textView.layoutManager, let tc = textView.textContainer else { return }
        let text = textView.string
        let ns = text as NSString
        var range = NSRange(location: 0, length: ns.length)
        if ns.length > 200_000 {
            // Large files: highlight only around the visible area.
            let glyphs = lm.glyphRange(forBoundingRect: textView.visibleRect, in: tc)
            let vis = lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            let start = max(0, vis.location - 20_000)
            let end = min(ns.length, NSMaxRange(vis) + 20_000)
            range = ns.lineRange(for: NSRange(location: start, length: end - start))
        }
        Highlighter.apply(lang, to: lm, text: text, range: range)
    }

    @objc private func didScroll() {
        ruler.needsDisplay = true
        if (textView.string as NSString).length > 200_000 { scheduleHighlight() }
    }

    // MARK: - NSTextViewDelegate

    func undoManager(for view: NSTextView) -> UndoManager? { editorDocument?.undoManager }

    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
        // Keep "\n" as the only line break internally (pasted CRLF/CR text is normalized).
        guard let text, text.utf16.contains(13) else { return true }
        textView.insertText(LineEnding.normalize(text), replacementRange: range)
        return false
    }

    func textDidChange(_ notification: Notification) { textChanged() }

    private func textChanged() {
        lineIndex.invalidate()
        ruler.updateThickness()
        ruler.needsDisplay = true
        refreshStatus()
        scheduleHighlight()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        refreshStatus()
        ruler.needsDisplay = true
        if textView.highlightCurrentLine { textView.setNeedsDisplay(textView.visibleRect, avoidAdditionalLayout: true) }
    }

    // MARK: - Status bar

    func refreshStatus() {
        guard let doc = editorDocument else { return }
        let sel = textView.selectedRange()
        let line = lineIndex.line(at: sel.location)
        let col = sel.location - lineIndex.starts[line] + 1
        var pos = "Ln \(line + 1), Col \(col)"
        if sel.length > 0 {
            let lines = lineIndex.line(at: NSMaxRange(sel)) - line + 1
            pos += "   Sel \(sel.length.formatted())" + (lines > 1 ? " | \(lines) lines" : "")
        }
        statusBar.positionLabel.stringValue = pos
        statusBar.infoLabel.stringValue =
            "Length \((textView.string as NSString).length.formatted())   Lines \(lineIndex.lineCount.formatted())"
        if let i = Language.all.firstIndex(where: { $0 === doc.language }) { statusBar.languagePopup.selectItem(withTag: i) }
        statusBar.eolPopup.selectItem(withTag: doc.lineEnding.rawValue)
        if let i = TextEncoding.all.firstIndex(of: doc.encoding) {
            statusBar.encodingPopup.selectItem(withTag: i)
        } else {
            if statusBar.encodingPopup.item(withTitle: doc.encoding.title) == nil {
                statusBar.encodingPopup.addItem(withTitle: doc.encoding.title)
                statusBar.encodingPopup.lastItem?.tag = -1
                statusBar.encodingPopup.lastItem?.isEnabled = false
            }
            statusBar.encodingPopup.selectItem(withTitle: doc.encoding.title)
        }
    }

    // MARK: - Actions

    private func tag(_ sender: Any?) -> Int {
        if let p = sender as? NSPopUpButton { return p.selectedTag() }
        return (sender as? NSMenuItem)?.tag ?? -1
    }

    @objc func setLanguage(_ sender: Any?) {
        let i = tag(sender)
        guard Language.all.indices.contains(i) else { return }
        editorDocument?.language = Language.all[i]
        refreshStatus()
    }

    @objc func setLineEnding(_ sender: Any?) {
        guard let doc = editorDocument, let e = LineEnding(rawValue: tag(sender)), e != doc.lineEnding else { return }
        doc.lineEnding = e
        doc.updateChangeCount(.changeDone)
        refreshStatus()
    }

    @objc func convertEncoding(_ sender: Any?) {
        let i = tag(sender)
        guard let doc = editorDocument, TextEncoding.all.indices.contains(i) else { return }
        let enc = TextEncoding.all[i]
        guard enc != doc.encoding else { return }
        guard enc.canEncode(textView.string) else {
            refreshStatus()
            let alert = NSAlert()
            alert.messageText = "Can't convert to \(enc.title)"
            alert.informativeText = "The document contains characters that can't be represented in this encoding."
            alert.beginSheetModal(for: window!)
            return
        }
        doc.encoding = enc
        doc.updateChangeCount(.changeDone)
        refreshStatus()
    }

    @objc func reopenWithEncoding(_ sender: Any?) {
        let i = tag(sender)
        guard let doc = editorDocument, let url = doc.fileURL, TextEncoding.all.indices.contains(i) else { return }
        let enc = TextEncoding.all[i]
        let reopen = { [weak self] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: url), let s = enc.decode(data) else {
                let alert = NSAlert()
                alert.messageText = "The file can't be read as \(enc.title)."
                alert.beginSheetModal(for: self.window!)
                return
            }
            doc.encoding = enc
            doc.lineEnding = LineEnding.detect(s)
            doc.text = LineEnding.normalize(s)
            self.loadFromDocument()
            doc.updateChangeCount(.changeCleared)
        }
        if doc.isDocumentEdited {
            let alert = NSAlert()
            alert.messageText = "Reopen “\(doc.displayName ?? "")” with \(enc.title)?"
            alert.informativeText = "Your unsaved changes will be lost."
            alert.addButton(withTitle: "Reopen")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: window!) { if $0 == .alertFirstButtonReturn { reopen() } }
        } else {
            reopen()
        }
    }

    @objc func goToLine(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Line number (1–\(lineIndex.lineCount.formatted())):"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "line[:column]"
        alert.accessoryView = field
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let parts = field.stringValue.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard let line = parts.first ?? nil else { return }
            self.jump(toLine: line, column: parts.count > 1 ? (parts[1] ?? 1) : 1)
        }
    }

    func jump(toLine line: Int, column: Int = 1) {
        let i = max(1, min(line, lineIndex.lineCount)) - 1
        let start = lineIndex.starts[i]
        let end = i + 1 < lineIndex.starts.count ? lineIndex.starts[i + 1] - 1 : (textView.string as NSString).length
        let loc = min(start + max(0, column - 1), end)
        window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: loc, length: 0))
        textView.centerSelectionInVisibleArea(nil)
    }

    @objc func revealInFinder(_ sender: Any?) {
        guard let url = editorDocument?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func copyFilePath(_ sender: Any?) {
        guard let url = editorDocument?.fileURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    // New-tab "+" button in the tab bar.
    @objc override func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let doc = editorDocument else { return false }
        switch item.action {
        case #selector(setLanguage(_:)):
            item.state = Language.all.indices.contains(item.tag) && Language.all[item.tag] === doc.language ? .on : .off
        case #selector(setLineEnding(_:)):
            item.state = item.tag == doc.lineEnding.rawValue ? .on : .off
        case #selector(convertEncoding(_:)):
            item.state = TextEncoding.all.indices.contains(item.tag) && TextEncoding.all[item.tag] == doc.encoding ? .on : .off
        case #selector(reopenWithEncoding(_:)), #selector(revealInFinder(_:)), #selector(copyFilePath(_:)):
            return doc.fileURL != nil
        default:
            break
        }
        return true
    }

    // MARK: - NSWindowDelegate

    func windowDidEndLiveResize(_ notification: Notification) { window?.saveFrame(usingName: Self.frameName) }
    func windowDidMove(_ notification: Notification) { window?.saveFrame(usingName: Self.frameName) }
    func windowDidResize(_ notification: Notification) { ruler.needsDisplay = true }
}
