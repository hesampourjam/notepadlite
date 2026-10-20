import AppKit

/// Cached start offsets (UTF-16) of every line. Rebuilt lazily after edits.
final class LineIndex {
    var source: () -> NSString = { "" }
    private(set) var starts: [Int] = [0]
    private var valid = false

    func invalidate() { valid = false }

    func ensure() {
        guard !valid else { return }
        let s = source()
        let len = s.length
        var result = [0]
        result.reserveCapacity(len / 32 + 1)
        let chunk = 65_536
        var buf = [unichar](repeating: 0, count: chunk)
        var pos = 0
        while pos < len {
            let n = min(chunk, len - pos)
            buf.withUnsafeMutableBufferPointer { p in
                s.getCharacters(p.baseAddress!, range: NSRange(location: pos, length: n))
            }
            for i in 0..<n where buf[i] == 10 { result.append(pos + i + 1) }
            pos += n
        }
        starts = result
        valid = true
    }

    var lineCount: Int { ensure(); return starts.count }

    /// 0-based line containing the UTF-16 offset `loc`.
    func line(at loc: Int) -> Int {
        ensure()
        var lo = 0, hi = starts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= loc { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let lineIndex: LineIndex
    var labelFont: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { updateThickness(); needsDisplay = true }
    }

    init(scrollView: NSScrollView, textView: NSTextView, lineIndex: LineIndex) {
        self.textView = textView
        self.lineIndex = lineIndex
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    required init(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    func updateThickness() {
        let digits = max(3, String(lineIndex.lineCount).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: labelFont]).width
        let w = ceil(digitWidth * CGFloat(digits) + 18)
        if abs(ruleThickness - w) > 0.5 { ruleThickness = w }
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.gutterBackground.setFill()
        dirtyRect.fill()
        Theme.gutterSeparator.setFill()
        NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        let len = (tv.string as NSString).length
        let origin = tv.textContainerOrigin
        var visible = tv.visibleRect
        visible.origin.x -= origin.x
        visible.origin.y -= origin.y
        let glyphs = lm.glyphRange(forBoundingRect: visible, in: tc)
        let chars = lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)

        lineIndex.ensure()
        let starts = lineIndex.starts
        let current = lineIndex.line(at: tv.selectedRange().location)
        let normal: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: Theme.gutterText]
        let bold: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: labelFont.pointSize, weight: .semibold),
            .foregroundColor: Theme.gutterCurrentText,
        ]

        var line = lineIndex.line(at: chars.location)
        while line < starts.count {
            let start = starts[line]
            if start > NSMaxRange(chars) { break }
            let frag: NSRect
            if start >= len {
                guard lm.extraLineFragmentTextContainer != nil else { break }
                frag = lm.extraLineFragmentRect
            } else {
                frag = lm.lineFragmentRect(forGlyphAt: lm.glyphIndexForCharacter(at: start), effectiveRange: nil)
            }
            let y = convert(NSPoint(x: 0, y: frag.minY + origin.y), from: tv).y
            if y > rect.maxY { break }
            let label = String(line + 1) as NSString
            let attrs = line == current ? bold : normal
            let size = label.size(withAttributes: attrs)
            // Center on the first line of the fragment (wrapped lines keep the number at the top).
            let textLineHeight = min(frag.height, lm.defaultLineHeight(for: tv.font ?? labelFont))
            label.draw(at: NSPoint(x: ruleThickness - 8 - size.width, y: y + (textLineHeight - size.height) / 2),
                       withAttributes: attrs)
            line += 1
        }
    }

    /// Clicking a line number selects that line.
    override func mouseDown(with event: NSEvent) {
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        let p = tv.convert(event.locationInWindow, from: nil)
        let glyph = lm.glyphIndex(for: NSPoint(x: 1, y: p.y - tv.textContainerOrigin.y), in: tc)
        let ch = lm.characterIndexForGlyph(at: glyph)
        let ns = tv.string as NSString
        let r = ns.lineRange(for: NSRange(location: min(ch, ns.length), length: 0))
        tv.window?.makeFirstResponder(tv)
        tv.setSelectedRange(r)
    }
}
