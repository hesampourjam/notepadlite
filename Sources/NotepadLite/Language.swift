import AppKit

/// A syntax definition: ordered regex rules, then a single combined pass for
/// strings/comments (leftmost match wins, so "//" inside a string stays a string).
final class Language {
    let name: String
    let extensions: [String]
    let fileNames: [String]
    let lineComment: String?
    let blockComment: (String, String)?
    let indentAfterColon: Bool
    let rules: [(NSRegularExpression, TokenKind)]
    let tokens: NSRegularExpression?
    let tokenKinds: [TokenKind]

    var hasRules: Bool { !rules.isEmpty || tokens != nil }

    init(name: String, ext: [String] = [], files: [String] = [],
         line: String? = nil, block: (String, String)? = nil,
         keywords: String = "", types: String = "", caseInsensitive: Bool = false,
         numbers: Bool = true, capsAsTypes: Bool = false, indentAfterColon: Bool = false,
         extra: [(String, TokenKind)] = [], tokens: [(String, TokenKind)] = []) {
        self.name = name
        self.extensions = ext
        self.fileNames = files
        self.lineComment = line
        self.blockComment = block
        self.indentAfterColon = indentAfterColon

        var rules: [(NSRegularExpression, TokenKind)] = []
        let kwOpts: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive, .anchorsMatchLines] : [.anchorsMatchLines]
        func add(_ pattern: String, _ kind: TokenKind, _ opts: NSRegularExpression.Options = [.anchorsMatchLines]) {
            if let re = Language.regex(pattern, opts) { rules.append((re, kind)) }
        }
        func words(_ list: String) -> String? {
            let w = list.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
            return w.isEmpty ? nil : #"\b(?:"# + w.joined(separator: "|") + #")\b"#
        }
        if numbers {
            add(#"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)[uUlLfFnN]*\b"#, .number)
        }
        if capsAsTypes { add(#"\b[A-Z][A-Za-z0-9_]*\b"#, .type) }
        if let t = words(types) { add(t, .type, kwOpts) }
        if let k = words(keywords) { add(k, .keyword, kwOpts) }
        for (p, k) in extra { add(p, k, caseInsensitive ? [.caseInsensitive, .anchorsMatchLines] : [.anchorsMatchLines]) }
        self.rules = rules

        if tokens.isEmpty {
            self.tokens = nil
            self.tokenKinds = []
        } else {
            let combined = tokens.map { "(" + $0.0 + ")" }.joined(separator: "|")
            self.tokens = Language.regex(combined, [.anchorsMatchLines])
            self.tokenKinds = tokens.map { $0.1 }
        }
    }

    private static func regex(_ p: String, _ o: NSRegularExpression.Options) -> NSRegularExpression? {
        do { return try NSRegularExpression(pattern: p, options: o) } catch {
            NSLog("NotepadLite: bad pattern %@: %@", p, error.localizedDescription)
            return nil
        }
    }

    // MARK: - Shared token patterns

    private static let lineSlash = (#"//.*"#, TokenKind.comment)
    private static let blockSlash = (#"/\*[\s\S]*?(?:\*/|\z)"#, TokenKind.comment)
    private static let hashComment = (#"#.*"#, TokenKind.comment)
    private static let dq = (#""(?:\\.|[^"\\\n])*""#, TokenKind.string)
    private static let sq = (#"'(?:\\.|[^'\\\n])*'"#, TokenKind.string)
    private static let backtick = (#"`(?:\\.|[^`\\])*`"#, TokenKind.string)
    private static let cTokens = [lineSlash, blockSlash, dq, sq]

    // MARK: - Definitions

    static let plain = Language(name: "Plain Text", numbers: false)

    static let all: [Language] = [plain] + [
        Language(name: "Batch", ext: ["bat", "cmd"], line: "REM",
                 keywords: "echo set if else goto call exit for in do not exist errorlevel defined setlocal endlocal shift pause cd copy del move start choice equ neq lss leq gtr geq",
                 caseInsensitive: true, numbers: false,
                 extra: [(#"%[\w~:]+%?|![\w]+!"#, .attribute), (#"^\s*:[\w]+"#, .meta)],
                 tokens: [(#"(?i)^\s*(?:rem\b|::).*"#, .comment), dq]),
        Language(name: "C", ext: ["c", "h"], line: "//", block: ("/*", "*/"),
                 keywords: cKeywords,
                 types: "int char float double long short unsigned signed void size_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t FILE",
                 extra: [(#"^\s*#\s*\w+"#, .meta)], tokens: cTokens),
        Language(name: "C++", ext: ["cpp", "cc", "cxx", "hpp", "hh", "hxx", "ino"], line: "//", block: ("/*", "*/"),
                 keywords: cKeywords + " class namespace template typename public private protected virtual override final new delete this throw try catch using operator friend explicit constexpr noexcept static_cast dynamic_cast reinterpret_cast const_cast decltype mutable concept requires co_await co_return co_yield",
                 types: "int char float double long short unsigned signed void bool size_t string vector map set unique_ptr shared_ptr std auto",
                 extra: [(#"^\s*#\s*\w+"#, .meta)], tokens: cTokens),
        Language(name: "C#", ext: ["cs"], line: "//", block: ("/*", "*/"),
                 keywords: "abstract as base break case catch checked class const continue default delegate do else enum event explicit extern false finally fixed for foreach goto if implicit in interface internal is lock namespace new null operator out override params private protected public readonly ref return sealed sizeof stackalloc static struct switch this throw true try typeof unchecked unsafe using virtual void volatile while var async await get set value yield record init",
                 types: "bool byte char decimal double float int long object sbyte short string uint ulong ushort dynamic",
                 capsAsTypes: true, extra: [(#"^\s*#\s*\w+"#, .meta)], tokens: [lineSlash, blockSlash, (#"@"(?:""|[^"])*""#, .string), dq, sq]),
        Language(name: "CSS", ext: ["css", "scss", "sass", "less"], line: nil, block: ("/*", "*/"),
                 numbers: false,
                 extra: [(#"(?<![\w-])[a-zA-Z-]+(?=\s*:(?!:))"#, .attribute),
                         (#"\.[A-Za-z_][\w-]*"#, .tag),
                         (#"#[0-9a-fA-F]{3,8}\b"#, .number),
                         (#"-?\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|vmin|vmax|s|ms|deg|fr|pt|ch)?\b"#, .number),
                         (#"@[\w-]+|!important"#, .keyword),
                         (#"\$[\w-]+"#, .meta)],
                 tokens: [blockSlash, lineSlash, dq, sq]),
        Language(name: "Diff", ext: ["diff", "patch"], numbers: false,
                 extra: [(#"^\+.*"#, .comment), (#"^-.*"#, .string), (#"^@@.*?@@"#, .keyword),
                         (#"^(?:\+\+\+|---|diff|index) .*"#, .meta)]),
        Language(name: "Go", ext: ["go"], line: "//", block: ("/*", "*/"),
                 keywords: "break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil iota",
                 types: "bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr any",
                 tokens: [lineSlash, blockSlash, dq, sq, backtick]),
        Language(name: "HTML / XML", ext: ["html", "htm", "xhtml", "xml", "svg", "plist", "xsd", "xsl", "vue", "storyboard", "xib", "csproj", "config"],
                 block: ("<!--", "-->"), numbers: false,
                 extra: [(#"</?[A-Za-z][\w:.-]*|/?>"#, .tag),
                         (#"\b[\w:.-]+(?=\s*=\s*["'])"#, .attribute),
                         (#"&#?\w+;"#, .number),
                         (#"<![A-Za-z][^>]*>|<\?[\s\S]*?\?>"#, .meta)],
                 tokens: [(#"<!--[\s\S]*?(?:-->|\z)"#, .comment),
                          (#"<!\[CDATA\[[\s\S]*?\]\]>"#, .string),
                          (#"(?<==\s{0,3})"[^"]*""#, .string),
                          (#"(?<==\s{0,3})'[^']*'"#, .string)]),
        Language(name: "INI / TOML", ext: ["ini", "toml", "cfg", "conf", "properties", "env", "editorconfig", "gitconfig"],
                 files: [".env", ".gitconfig", ".editorconfig"], line: "#",
                 keywords: "true false on off yes no",
                 extra: [(#"^\s*[\w.\-]+(?=\s*[=:])"#, .attribute), (#"^\s*\[[^\]\n]*\]"#, .keyword)],
                 tokens: [(#"^\s*[;#].*"#, .comment), dq, sq]),
        Language(name: "Java", ext: ["java"], line: "//", block: ("/*", "*/"),
                 keywords: "abstract assert break case catch class const continue default do else enum extends final finally for goto if implements import instanceof interface native new package private protected public return static strictfp super switch synchronized this throw throws transient try volatile while true false null var record sealed permits yield",
                 types: "boolean byte char double float int long short void",
                 capsAsTypes: true, extra: [(#"@\w+"#, .meta)], tokens: [(#"\"\"\"[\s\S]*?(?:\"\"\"|\z)"#, .string)] + cTokens),
        Language(name: "JavaScript", ext: ["js", "mjs", "cjs", "jsx"], line: "//", block: ("/*", "*/"),
                 keywords: jsKeywords,
                 types: "Array Object String Number Boolean Promise Map Set Date RegExp Error JSON Math console window document",
                 tokens: [lineSlash, blockSlash, dq, sq, backtick]),
        Language(name: "JSON", ext: ["json", "jsonc", "json5", "geojson", "babelrc", "eslintrc"], line: "//", block: ("/*", "*/"),
                 keywords: "true false null",
                 extra: [(#"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .number)],
                 tokens: [(#""(?:\\.|[^"\\\n])*"(?=\s*:)"#, .attribute), dq, lineSlash, blockSlash]),
        Language(name: "Kotlin", ext: ["kt", "kts"], line: "//", block: ("/*", "*/"),
                 keywords: "as break class continue do else false for fun if in interface is null object package return super this throw true try typealias val var when while by catch constructor finally get import init set where abstract annotation companion const crossinline data enum external final infix inline inner internal lateinit noinline open operator out override private protected public reified sealed suspend tailrec vararg",
                 capsAsTypes: true, extra: [(#"@\w+"#, .meta)],
                 tokens: [(#"\"\"\"[\s\S]*?(?:\"\"\"|\z)"#, .string)] + cTokens),
        Language(name: "Lua", ext: ["lua"], line: "--", block: ("--[[", "]]"),
                 keywords: "and break do else elseif end false for function goto if in local nil not or repeat return then true until while self",
                 tokens: [(#"--\[\[[\s\S]*?(?:\]\]|\z)"#, .comment), (#"--.*"#, .comment), (#"\[\[[\s\S]*?\]\]"#, .string), dq, sq]),
        Language(name: "Markdown", ext: ["md", "markdown", "mdown", "mkd"], block: ("<!--", "-->"), numbers: false,
                 extra: [(#"^\s*(?:[-*+]|\d+\.)\s"#, .keyword),
                         (#"\*\*[^*\n]+\*\*|__[^_\n]+__"#, .type),
                         (#"(?<![*\w])\*[^*\n]+\*(?!\*)|(?<![_\w])_[^_\n]+_(?!_)"#, .attribute),
                         (#"!?\[[^\]\n]*\]\([^)\n]*\)"#, .attribute),
                         (#"^>.*"#, .comment),
                         (#"^#{1,6}\s.*"#, .keyword),
                         (#"^(?:---+|\*\*\*+|___+)\s*$"#, .meta)],
                 tokens: [(#"```[\s\S]*?(?:```|\z)"#, .string), (#"`[^`\n]+`"#, .string), (#"<!--[\s\S]*?(?:-->|\z)"#, .comment)]),
        Language(name: "PHP", ext: ["php", "phtml", "php3", "php4", "php5"], line: "//", block: ("/*", "*/"),
                 keywords: "abstract and array as break callable case catch class clone const continue declare default do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile extends final finally fn for foreach function global goto if implements include include_once instanceof insteadof interface isset list match namespace new or print private protected public readonly require require_once return static switch throw trait try unset use var while xor yield true false null",
                 caseInsensitive: true,
                 extra: [(#"\$\w+"#, .attribute), (#"<\?php|<\?=|\?>"#, .meta)],
                 tokens: [lineSlash, blockSlash, hashComment, dq, sq]),
        Language(name: "Python", ext: ["py", "pyw", "pyi"], files: ["SConstruct", "SConscript"], line: "#",
                 keywords: "False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case self cls",
                 types: "int float str bool list dict set tuple bytes object type len print range enumerate zip map filter open super isinstance Exception ValueError TypeError KeyError",
                 indentAfterColon: true,
                 extra: [(#"^\s*@[\w.]+"#, .meta)],
                 tokens: [(#"[rRbBfFuU]{0,2}\"\"\"[\s\S]*?(?:\"\"\"|\z)"#, .string),
                          (#"[rRbBfFuU]{0,2}'''[\s\S]*?(?:'''|\z)"#, .string),
                          hashComment,
                          (#"[rRbBfFuU]{0,2}"(?:\\.|[^"\\\n])*""#, .string),
                          (#"[rRbBfFuU]{0,2}'(?:\\.|[^'\\\n])*'"#, .string)]),
        Language(name: "Ruby", ext: ["rb", "rake", "gemspec", "ru"], files: ["Gemfile", "Rakefile", "Podfile", "Fastfile"], line: "#",
                 keywords: "BEGIN END alias and begin break case class def do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield require require_relative attr_accessor attr_reader attr_writer puts private protected public lambda proc",
                 capsAsTypes: true,
                 extra: [(#"(?<![:\w]):\w+"#, .number), (#"@{1,2}\w+"#, .attribute)],
                 tokens: [(#"^=begin[\s\S]*?(?:^=end|\z)"#, .comment), hashComment, dq, sq]),
        Language(name: "Rust", ext: ["rs"], line: "//", block: ("/*", "*/"),
                 keywords: "as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while",
                 types: "i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str",
                 capsAsTypes: true,
                 extra: [(#"\b\w+!"#, .meta), (#"#!?\[[^\]\n]*\]"#, .meta)],
                 tokens: [lineSlash, blockSlash, dq, (#"'(?:\\.|[^'\\\n])'"#, .string)]),
        Language(name: "Shell", ext: ["sh", "bash", "zsh", "fish", "command", "ksh"],
                 files: ["Makefile", "makefile", "GNUmakefile", "Dockerfile", ".bashrc", ".zshrc", ".bash_profile", ".profile", ".zprofile", ".zshenv"],
                 line: "#",
                 keywords: "if then else elif fi case esac for while until do done in function return break continue local export readonly declare unset shift exit source alias echo printf read cd test true false eval exec set trap FROM RUN CMD COPY ADD ENV WORKDIR EXPOSE ENTRYPOINT ARG LABEL USER VOLUME",
                 numbers: false,
                 extra: [(#"\$\{[^}\n]*\}|\$[\w@#?*!$-]+"#, .attribute)],
                 tokens: [(#"(?<![\w$])#.*"#, .comment), dq, (#"'[^']*'"#, .string), backtick]),
        Language(name: "SQL", ext: ["sql", "psql", "mysql"], line: "--", block: ("/*", "*/"),
                 keywords: "select from where insert into values update set delete create table drop alter add column index view as and or not null is in like ilike between join inner left right outer full cross on group by order having limit offset union all distinct case when then else end primary key foreign references default unique check exists asc desc begin commit rollback transaction if replace with returning database schema grant revoke truncate procedure function trigger declare return",
                 types: "int integer bigint smallint serial varchar char text date time timestamp timestamptz boolean bool float real double decimal numeric json jsonb uuid blob count sum avg min max coalesce",
                 caseInsensitive: true,
                 tokens: [(#"--.*"#, .comment), blockSlash, (#"'(?:''|[^'])*'"#, .string), (#""[^"\n]*""#, .attribute), (#"`[^`\n]*`"#, .attribute)]),
        Language(name: "Swift", ext: ["swift"], line: "//", block: ("/*", "*/"),
                 keywords: "associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private protocol public rethrows static struct subscript typealias var break case continue default defer do else fallthrough for guard if in repeat return switch where while as catch false is nil super self Self throw throws true try async await actor some any weak unowned lazy override final mutating nonmutating convenience required get set willSet didSet",
                 capsAsTypes: true,
                 extra: [(#"[@#]\w+"#, .meta)],
                 tokens: [lineSlash, blockSlash, (#"\"\"\"[\s\S]*?(?:\"\"\"|\z)"#, .string), dq]),
        Language(name: "TypeScript", ext: ["ts", "tsx", "mts", "cts"], line: "//", block: ("/*", "*/"),
                 keywords: jsKeywords + " interface type enum implements namespace declare abstract private public protected readonly as is keyof infer satisfies",
                 types: "any unknown never number string boolean object symbol bigint void Array Object String Number Boolean Promise Map Set Date RegExp Error Record Partial Readonly",
                 capsAsTypes: true,
                 extra: [(#"@\w+"#, .meta)],
                 tokens: [lineSlash, blockSlash, dq, sq, backtick]),
        Language(name: "YAML", ext: ["yml", "yaml"], line: "#",
                 keywords: "true false null yes no on off True False Null",
                 extra: [(#"^\s*-?\s*[\w.\-/]+(?=\s*:(?:\s|$))"#, .attribute),
                         (#"^(?:---|\.\.\.)\s*$"#, .meta),
                         (#"(?<!\w)[&*][\w-]+"#, .meta)],
                 tokens: [(#"(?<!\S)#.*"#, .comment), dq, (#"'(?:''|[^'\n])*'"#, .string)]),
    ]

    private static let cKeywords = "auto break case const continue default do else enum extern for goto if inline register restrict return sizeof static struct switch typedef union volatile while true false NULL nullptr"
    private static let jsKeywords = "break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof let new return super switch this throw try typeof var void while with yield async await of static get set from true false null undefined NaN Infinity"

    // MARK: - Detection

    static func detect(url: URL?, text: String) -> Language {
        if let url {
            let fileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            if let l = all.first(where: { $0.fileNames.contains(fileName) }) { return l }
            if !ext.isEmpty, let l = all.first(where: { $0.extensions.contains(ext) }) { return l }
        }
        // Shebang
        if text.hasPrefix("#!") {
            let firstLine = text.prefix(while: { $0 != "\n" }).lowercased()
            let map: [(String, String)] = [("python", "Python"), ("node", "JavaScript"), ("ruby", "Ruby"),
                                           ("php", "PHP"), ("lua", "Lua"), ("sh", "Shell")]
            for (needle, name) in map where firstLine.contains(needle) {
                if let l = all.first(where: { $0.name == name }) { return l }
            }
        }
        if text.hasPrefix("<?xml") || text.lowercased().hasPrefix("<!doctype html") {
            return all.first(where: { $0.name == "HTML / XML" }) ?? plain
        }
        return plain
    }
}

enum Highlighter {
    /// Colors `range` of the text using layout-manager temporary attributes
    /// (display only — never saved, never touches undo).
    static func apply(_ lang: Language, to lm: NSLayoutManager, text: String, range: NSRange) {
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        guard lang.hasRules, range.length > 0 else { return }
        for (re, kind) in lang.rules {
            let color = kind.color
            re.enumerateMatches(in: text, options: [], range: range) { m, _, _ in
                if let r = m?.range, r.length > 0 {
                    lm.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: r)
                }
            }
        }
        if let tok = lang.tokens {
            let kinds = lang.tokenKinds
            tok.enumerateMatches(in: text, options: [], range: range) { m, _, _ in
                guard let m, m.range.length > 0 else { return }
                for g in 1..<m.numberOfRanges where m.range(at: g).location != NSNotFound {
                    lm.addTemporaryAttribute(.foregroundColor, value: kinds[g - 1].color, forCharacterRange: m.range(at: g))
                    break
                }
            }
        }
    }
}
