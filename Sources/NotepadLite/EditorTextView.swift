import AppKit

/// NSTextView with code-editor behaviour: auto-indent, block indent,
/// line operations, comment toggling, current-line highlight, file drops.
final class EditorTextView: NSTextView {
    var lineComment: String?
    var blockComment: (String, String)?
    var indentAfterColon = false
    var autoIndent = true
    var tabWidth = 4
    var indentWithSpaces = false
    var highlightCurrentLine = true { didSet { needsDisplay = true } }

    var indentUnit: String { indentWithSpaces ? String(repeating: " ", count: tabWidth) : "\t" }

    private var ns: NSString { string as NSString }

    // MARK: - Drawing

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard highlightCurrentLine, selectedRange().length == 0,
              let lm = layoutManager, let tc = textContainer else { return }
        let loc = selectedRange().location
        var r: NSRect
        if loc >= ns.length, lm.extraLineFragmentTextContainer != nil {
            r = lm.extraLineFragmentRect
        } else {
            let para = ns.lineRange(for: NSRange(location: min(loc, ns.length), length: 0))
            let glyphs = lm.glyphRange(forCharacterRange: para, actualCharacterRange: nil)
            r = lm.boundingRect(forGlyphRange: glyphs, in: tc)
        }
        r.origin.x = 0
        r.size.width = bounds.width
        r.origin.y += textContainerOrigin.y
        if r.intersects(rect) {
            Theme.currentLine.setFill()
            r.fill(using: .sourceOver)
        }
    }

    // MARK: - Editing helpers

    /// Undoable replacement that keeps the scroll position stable.
    func replace(_ range: NSRange, with text: String, select: NSRange?, action: String? = nil) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        let origin = enclosingScrollView?.contentView.bounds.origin
        textStorage?.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: typingAttributes))
        didChangeText()
        if let action { undoManager?.setActionName(action) }
        if let origin { enclosingScrollView?.contentView.scroll(to: origin) }
        if let sel = select {
            let clamped = NSRange(location: min(sel.location, ns.length),
                                  length: max(0, min(sel.length, ns.length - min(sel.location, ns.length))))
            setSelectedRange(clamped)
            scrollRangeToVisible(clamped)
        }
    }

    /// Full lines covered by the selection (a selection ending at the start of a line excludes that line).
    func selectedLinesRange() -> NSRange {
        var sel = selectedRange()
        if sel.length > 0, NSMaxRange(sel) > 0, ns.character(at: NSMaxRange(sel) - 1) == 10 { sel.length -= 1 }
        return ns.lineRange(for: sel)
    }

    private static func leadingWhitespace(_ s: String) -> String {
        String(s.prefix(while: { $0 == " " || $0 == "\t" }))
    }

    // MARK: - Typing

    override func insertNewline(_ sender: Any?) {
        guard autoIndent else { super.insertNewline(sender); return }
        let sel = selectedRange()
        let lineStart = ns.lineRange(for: NSRange(location: sel.location, length: 0)).location
        var i = lineStart
        while i < sel.location {
            let c = ns.character(at: i)
            if c == 32 || c == 9 { i += 1 } else { break }
        }
        var indent = ns.substring(with: NSRange(location: lineStart, length: i - lineStart))
        // Extra indent after an opening bracket (or ':' for Python-like languages).
        var j = sel.location - 1
        while j >= lineStart, ns.character(at: j) == 32 || ns.character(at: j) == 9 { j -= 1 }
        if j >= lineStart {
            let c = ns.character(at: j)
            if c == 123 || c == 91 || c == 40 || (indentAfterColon && c == 58) { indent += indentUnit }
        }
        insertText("\n" + indent, replacementRange: sel)
    }

    override func insertTab(_ sender: Any?) {
        let sel = selectedRange()
        if sel.length > 0, ns.substring(with: sel).contains("\n") {
            indentSelection(sender)
        } else {
            insertText(indentUnit, replacementRange: sel)
        }
    }

    override func insertBacktab(_ sender: Any?) { outdentSelection(sender) }

    // MARK: - Line operations

    @objc func indentSelection(_ sender: Any?) {
        let r = selectedLinesRange()
        let unit = indentUnit
        mapLines(in: r, action: "Indent") { $0.isEmpty ? $0 : unit + $0 }
    }

    @objc func outdentSelection(_ sender: Any?) {
        let r = selectedLinesRange()
        let width = tabWidth
        mapLines(in: r, action: "Outdent") { line in
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            let spaces = line.prefix(while: { $0 == " " }).count
            return String(line.dropFirst(min(spaces, width)))
        }
    }

    /// Applies `f` to each line in `r` and selects the result.
    private func mapLines(in r: NSRange, action: String, _ f: (String) -> String) {
        var block = ns.substring(with: r)
        let trailingNL = block.hasSuffix("\n")
        if trailingNL { block.removeLast() }
        var out = block.components(separatedBy: "\n").map(f).joined(separator: "\n")
        if out == block { return }
        let len = (out as NSString).length
        if trailingNL { out += "\n" }
        replace(r, with: out, select: NSRange(location: r.location, length: len), action: action)
    }

    @objc func duplicateLines(_ sender: Any?) {
        let sel = selectedRange()
        let r = selectedLinesRange()
        let block = ns.substring(with: r)
        let insertion = block.hasSuffix("\n") ? block : "\n" + block
        replace(NSRange(location: NSMaxRange(r), length: 0), with: insertion,
                select: NSRange(location: sel.location + (insertion as NSString).length, length: sel.length),
                action: "Duplicate Line")
    }

    @objc func deleteLines(_ sender: Any?) {
        var r = selectedLinesRange()
        if NSMaxRange(r) == ns.length, r.location > 0, !ns.substring(with: r).hasSuffix("\n") {
            r.location -= 1
            r.length += 1
        }
        guard r.length > 0 else { NSSound.beep(); return }
        replace(r, with: "", select: NSRange(location: r.location, length: 0), action: "Delete Line")
    }

    @objc func moveLinesUp(_ sender: Any?) {
        let sel = selectedRange()
        let r = selectedLinesRange()
        guard r.location > 0 else { NSSound.beep(); return }
        let prev = ns.lineRange(for: NSRange(location: r.location - 1, length: 0))
        var block = ns.substring(with: r)
        var prevText = ns.substring(with: prev)
        if !block.hasSuffix("\n") { block += "\n"; prevText = String(prevText.dropLast()) }
        replace(NSRange(location: prev.location, length: prev.length + r.length), with: block + prevText,
                select: NSRange(location: sel.location - prev.length, length: sel.length), action: "Move Line Up")
    }

    @objc func moveLinesDown(_ sender: Any?) {
        let sel = selectedRange()
        let r = selectedLinesRange()
        guard NSMaxRange(r) < ns.length else { NSSound.beep(); return }
        let next = ns.lineRange(for: NSRange(location: NSMaxRange(r), length: 0))
        var block = ns.substring(with: r)
        var nextText = ns.substring(with: next)
        if !nextText.hasSuffix("\n") { nextText += "\n"; block = String(block.dropLast()) }
        let shift = (nextText as NSString).length
        replace(NSRange(location: r.location, length: r.length + next.length), with: nextText + block,
                select: NSRange(location: sel.location + shift, length: sel.length), action: "Move Line Down")
    }

    @objc func toggleLineComment(_ sender: Any?) {
        let sel = selectedRange()
        let r = selectedLinesRange()
        var block = ns.substring(with: r)
        let trailingNL = block.hasSuffix("\n")
        if trailingNL { block.removeLast() }
        var out: String

        if let tok = lineComment {
            var lines = block.components(separatedBy: "\n")
            let isBlank: (String) -> Bool = { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            let content = lines.filter { !isBlank($0) }
            let uncomment = !content.isEmpty && content.allSatisfy {
                $0.drop(while: { $0 == " " || $0 == "\t" }).hasPrefix(tok)
            }
            for i in lines.indices {
                let line = lines[i]
                if isBlank(line) && !content.isEmpty { continue }
                let ws = Self.leadingWhitespace(line)
                var rest = String(line.dropFirst(ws.count))
                if uncomment {
                    rest = String(rest.dropFirst(tok.count))
                    if rest.hasPrefix(" ") { rest.removeFirst() }
                } else {
                    rest = tok + " " + rest
                }
                lines[i] = ws + rest
            }
            out = lines.joined(separator: "\n")
        } else if let (open, close) = blockComment {
            let ws = Self.leadingWhitespace(block)
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(open), trimmed.hasSuffix(close), trimmed.count >= open.count + close.count {
                var inner = String(trimmed.dropFirst(open.count).dropLast(close.count))
                if inner.hasPrefix(" ") { inner.removeFirst() }
                if inner.hasSuffix(" ") { inner.removeLast() }
                out = ws + inner
            } else {
                out = ws + open + " " + String(block.dropFirst(ws.count)) + " " + close
            }
        } else {
            NSSound.beep()
            return
        }

        let newLen = (out as NSString).length
        let delta = newLen - (block as NSString).length
        if trailingNL { out += "\n" }
        let select = sel.length == 0
            ? NSRange(location: max(r.location, min(sel.location + delta, r.location + newLen)), length: 0)
            : NSRange(location: r.location, length: newLen)
        replace(r, with: out, select: select, action: "Toggle Comment")
    }

    private func changeCase(_ action: String, _ f: (String) -> String) {
        var sel = selectedRange()
        if sel.length == 0 { sel = selectionRange(forProposedRange: sel, granularity: .selectByWord) }
        guard sel.length > 0 else { NSSound.beep(); return }
        let t = f(ns.substring(with: sel))
        replace(sel, with: t, select: NSRange(location: sel.location, length: (t as NSString).length), action: action)
    }

    @objc func convertToUppercase(_ sender: Any?) { changeCase("Uppercase") { $0.uppercased() } }
    @objc func convertToLowercase(_ sender: Any?) { changeCase("Lowercase") { $0.lowercased() } }
    @objc func convertToTitleCase(_ sender: Any?) { changeCase("Title Case") { $0.capitalized } }

    /// Transforms the selected lines, or the whole document when nothing is selected.
    private func transformLines(_ action: String, _ f: ([String]) -> [String]) {
        let sel = selectedRange()
        let whole = sel.length == 0
        let r = whole ? NSRange(location: 0, length: ns.length) : selectedLinesRange()
        var block = ns.substring(with: r)
        let trailingNL = block.hasSuffix("\n")
        if trailingNL { block.removeLast() }
        var out = f(block.components(separatedBy: "\n")).joined(separator: "\n")
        guard out != block else { return }
        let len = (out as NSString).length
        if trailingNL { out += "\n" }
        replace(r, with: out,
                select: whole ? NSRange(location: min(sel.location, len), length: 0) : NSRange(location: r.location, length: len),
                action: action)
    }

    @objc func sortLinesAscending(_ sender: Any?) {
        transformLines("Sort Lines") { $0.sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    }

    @objc func sortLinesDescending(_ sender: Any?) {
        transformLines("Sort Lines") { $0.sorted { $0.localizedStandardCompare($1) == .orderedDescending } }
    }

    @objc func removeDuplicateLines(_ sender: Any?) {
        transformLines("Remove Duplicate Lines") { lines in
            var seen = Set<String>()
            return lines.filter { seen.insert($0).inserted }
        }
    }

    @objc func removeEmptyLines(_ sender: Any?) {
        transformLines("Remove Empty Lines") { $0.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    @objc func trimTrailingWhitespace(_ sender: Any?) {
        transformLines("Trim Trailing Whitespace") { lines in
            lines.map { line in
                var l = Substring(line)
                while let c = l.last, c == " " || c == "\t" { l.removeLast() }
                return String(l)
            }
        }
    }

    @objc func joinSelectedLines(_ sender: Any?) {
        transformLines("Join Lines") { lines in
            guard let first = lines.first else { return lines }
            let rest = lines.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return [([first] + rest).joined(separator: " ")]
        }
    }

    @objc func tabsToSpaces(_ sender: Any?) {
        let spaces = String(repeating: " ", count: tabWidth)
        transformLines("Tabs to Spaces") { $0.map { $0.replacingOccurrences(of: "\t", with: spaces) } }
    }

    @objc func leadingSpacesToTabs(_ sender: Any?) {
        let width = tabWidth
        transformLines("Spaces to Tabs") { lines in
            lines.map { line in
                let n = line.prefix(while: { $0 == " " }).count
                return String(repeating: "\t", count: n / width) + String(line.dropFirst(n - n % width))
            }
        }
    }

    // MARK: - Dropping files opens them

    private func fileURLs(_ info: NSDraggingInfo) -> [URL] {
        (info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        var t = super.acceptableDragTypes
        if !t.contains(.fileURL) { t.append(.fileURL) }
        return t
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(sender)
        guard !urls.isEmpty else { return super.performDragOperation(sender) }
        for url in urls {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
        return true
    }
}
