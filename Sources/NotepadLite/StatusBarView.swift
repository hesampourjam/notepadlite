import AppKit

final class StatusBarView: NSView {
    let positionLabel = NSTextField(labelWithString: "")
    let infoLabel = NSTextField(labelWithString: "")
    let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let eolPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let encodingPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    override init(frame: NSRect) {
        super.init(frame: frame)
        let small = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        for label in [positionLabel, infoLabel] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
        }
        positionLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        infoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for popup in [languagePopup, eolPopup, encodingPopup] {
            popup.isBordered = false
            popup.controlSize = .small
            popup.font = small
            popup.setContentHuggingPriority(.required, for: .horizontal)
        }
        for (i, lang) in Language.all.enumerated() {
            languagePopup.addItem(withTitle: lang.name)
            languagePopup.lastItem?.tag = i
        }
        for e in LineEnding.allCases {
            eolPopup.addItem(withTitle: e.short)
            eolPopup.lastItem?.tag = e.rawValue
            eolPopup.lastItem?.toolTip = e.title
        }
        for (i, enc) in TextEncoding.all.enumerated() {
            encodingPopup.addItem(withTitle: enc.title)
            encodingPopup.lastItem?.tag = i
        }
        languagePopup.toolTip = "Language"
        eolPopup.toolTip = "Line endings"
        encodingPopup.toolTip = "Convert to encoding"

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 6)
        stack.addView(positionLabel, in: .leading)
        stack.addView(infoLabel, in: .leading)
        stack.addView(languagePopup, in: .trailing)
        stack.addView(eolPopup, in: .trailing)
        stack.addView(encodingPopup, in: .trailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func setTarget(_ target: AnyObject, language: Selector, eol: Selector, encoding: Selector) {
        languagePopup.target = target; languagePopup.action = language
        eolPopup.target = target; eolPopup.action = eol
        encodingPopup.target = target; encodingPopup.action = encoding
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }
}
