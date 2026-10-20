import AppKit
import UniformTypeIdentifiers

@objc(Document)
final class Document: NSDocument {
    var text = ""
    var encoding = TextEncoding.utf8
    var lineEnding = LineEnding.lf
    var language: Language = .plain {
        didSet { if language !== oldValue { editor?.languageDidChange() } }
    }
    weak var editor: EditorWindowController?

    override class var autosavesInPlace: Bool { false }

    override func makeWindowControllers() {
        let wc = EditorWindowController(document: self)
        editor = wc
        addWindowController(wc)
    }

    /// The live text: from the editor when one is open.
    var currentText: String { editor?.textView.string ?? text }

    // MARK: - Reading / writing

    override func read(from data: Data, ofType typeName: String) throws {
        let (s, enc) = TextEncoding.detect(data)
        encoding = enc
        lineEnding = LineEnding.detect(s)
        text = LineEnding.normalize(s)
        language = Language.detect(url: fileURL, text: text)
        editor?.loadFromDocument()
    }

    override func data(ofType typeName: String) throws -> Data {
        text = currentText
        let out = lineEnding == .lf ? text : text.replacingOccurrences(of: "\n", with: lineEnding.sequence)
        guard let data = encoding.encode(out) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteInapplicableStringEncodingError,
                          userInfo: [NSStringEncodingErrorKey: encoding.encoding.rawValue])
        }
        return data
    }

    // MARK: - Administrator ("sudo") access

    /// Files we can't read (e.g. root-only) are read through an administrator prompt.
    override func read(from url: URL, ofType typeName: String) throws {
        do {
            try super.read(from: url, ofType: typeName)
        } catch where Privileged.isPermissionError(error) {
            let data = try Privileged.read(url)
            try read(from: data, ofType: typeName)
        }
    }

    /// Saving to a location we can't write (e.g. /etc/hosts) retries with administrator privileges.
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
                       completionHandler: @escaping (Error?) -> Void) {
        super.save(to: url, ofType: typeName, for: saveOperation) { [weak self] error in
            guard let self, let error, Privileged.isPermissionError(error),
                  saveOperation == .saveOperation || saveOperation == .saveAsOperation || saveOperation == .saveToOperation
            else { completionHandler(error); return }
            do {
                try Privileged.write(try self.data(ofType: typeName), to: url)
                if saveOperation != .saveToOperation {
                    self.fileURL = url
                    self.fileType = typeName
                    self.fileModificationDate =
                        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date ?? Date()
                    self.updateChangeCount(.changeCleared)
                }
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override var fileURL: URL? {
        didSet {
            if let url = fileURL, url != oldValue { language = Language.detect(url: url, text: currentText) }
        }
    }

    // Let the user save with any file name / extension.
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = []
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.canSelectHiddenExtension = false
        return true
    }

    override var fileTypeFromLastRunSavePanel: String? { "public.plain-text" }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] { ["public.plain-text"] }

    // MARK: - Printing

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let info = printInfo
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        tv.isRichText = false
        tv.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.string = currentText
        tv.isVerticallyResizable = true
        tv.sizeToFit()
        let op = NSPrintOperation(view: tv, printInfo: info)
        op.jobTitle = displayName
        return op
    }
}
