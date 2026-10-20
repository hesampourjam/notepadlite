import Foundation

struct TextEncoding: Equatable {
    let encoding: String.Encoding
    let bom: Bool

    init(_ encoding: String.Encoding, bom: Bool = false) {
        self.encoding = encoding
        self.bom = bom
    }

    static func cf(_ e: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(e.rawValue)))
    }

    static let utf8 = TextEncoding(.utf8)
    static let utf8BOM = TextEncoding(.utf8, bom: true)
    static let utf16LE = TextEncoding(.utf16LittleEndian, bom: true)
    static let utf16BE = TextEncoding(.utf16BigEndian, bom: true)

    /// Encodings offered in menus.
    static let all: [TextEncoding] = [
        .utf8, .utf8BOM, .utf16LE, .utf16BE,
        TextEncoding(.windowsCP1252),
        TextEncoding(.isoLatin1),
        TextEncoding(.macOSRoman),
        TextEncoding(cf(.windowsArabic)),
        TextEncoding(.windowsCP1251),
        TextEncoding(.shiftJIS),
        TextEncoding(cf(.GB_18030_2000)),
    ]

    var title: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf8BOM: return "UTF-8 with BOM"
        case .utf16LE: return "UTF-16 LE"
        case .utf16BE: return "UTF-16 BE"
        default:
            if encoding == .windowsCP1252 { return "Windows-1252 (Western)" }
            if encoding == .isoLatin1 { return "ISO-8859-1 (Latin 1)" }
            if encoding == .macOSRoman { return "Mac Roman" }
            if encoding == TextEncoding.cf(.windowsArabic) { return "Windows-1256 (Arabic/Persian)" }
            if encoding == .windowsCP1251 { return "Windows-1251 (Cyrillic)" }
            if encoding == .shiftJIS { return "Shift JIS (Japanese)" }
            if encoding == TextEncoding.cf(.GB_18030_2000) { return "GB 18030 (Chinese)" }
            return String.localizedName(of: encoding)
        }
    }

    var bomBytes: [UInt8] {
        guard bom else { return [] }
        switch encoding {
        case .utf8: return [0xEF, 0xBB, 0xBF]
        case .utf16LittleEndian: return [0xFF, 0xFE]
        case .utf16BigEndian: return [0xFE, 0xFF]
        default: return []
        }
    }

    func encode(_ s: String) -> Data? {
        guard let d = s.data(using: encoding, allowLossyConversion: false) else { return nil }
        return Data(bomBytes) + d
    }

    func canEncode(_ s: String) -> Bool { s.data(using: encoding, allowLossyConversion: false) != nil }

    func decode(_ data: Data) -> String? {
        var d = data
        let marks: [[UInt8]]
        switch encoding {
        case .utf8: marks = [[0xEF, 0xBB, 0xBF]]
        case .utf16LittleEndian: marks = [[0xFF, 0xFE]]
        case .utf16BigEndian: marks = [[0xFE, 0xFF]]
        default: marks = []
        }
        for m in marks where d.starts(with: m) { d = d.dropFirst(m.count) }
        return String(data: Data(d), encoding: encoding)
    }

    /// Guess the encoding of raw file data.
    static func detect(_ data: Data) -> (String, TextEncoding) {
        if data.starts(with: [0xEF, 0xBB, 0xBF]), let s = utf8BOM.decode(data) { return (s, .utf8BOM) }
        if data.starts(with: [0xFF, 0xFE]), let s = utf16LE.decode(data) { return (s, .utf16LE) }
        if data.starts(with: [0xFE, 0xFF]), let s = utf16BE.decode(data) { return (s, .utf16BE) }
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }

        var converted: NSString?
        var lossy: ObjCBool = false
        let raw = NSString.stringEncoding(
            for: data,
            encodingOptions: [
                .suggestedEncodingsKey: [String.Encoding.windowsCP1252.rawValue, cf(.windowsArabic).rawValue],
                .allowLossyKey: false,
            ],
            convertedString: &converted,
            usedLossyConversion: &lossy)
        if raw != 0, let c = converted {
            return (c as String, TextEncoding(String.Encoding(rawValue: raw)))
        }
        return (String(data: data, encoding: .isoLatin1) ?? "", TextEncoding(.isoLatin1))
    }
}

enum LineEnding: Int, CaseIterable {
    case lf, crlf, cr

    var sequence: String { ["\n", "\r\n", "\r"][rawValue] }
    var title: String { ["Unix (LF)", "Windows (CRLF)", "Classic Mac (CR)"][rawValue] }
    var short: String { ["LF", "CRLF", "CR"][rawValue] }

    static func detect(_ s: String) -> LineEnding {
        let ns = s as NSString
        if ns.range(of: "\r\n", options: .literal).location != NSNotFound { return .crlf }
        if ns.range(of: "\r", options: .literal).location != NSNotFound { return .cr }
        return .lf
    }

    /// Convert any line breaks to "\n" (the editor's internal form).
    static func normalize(_ s: String) -> String {
        let ns = s as NSString
        guard ns.range(of: "\r", options: .literal).location != NSNotFound else { return s }
        let a = ns.replacingOccurrences(of: "\r\n", with: "\n", options: .literal, range: NSRange(location: 0, length: ns.length)) as NSString
        return a.replacingOccurrences(of: "\r", with: "\n", options: .literal, range: NSRange(location: 0, length: a.length))
    }
}
