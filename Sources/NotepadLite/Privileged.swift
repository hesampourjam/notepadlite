import Foundation

/// Reads/writes files as root via the standard macOS administrator password prompt
/// (`do shell script … with administrator privileges`), like `sudo`.
/// macOS caches the authorization for a few minutes, so repeated saves don't re-prompt.
enum Privileged {
    static func isPermissionError(_ error: Error) -> Bool {
        let e = error as NSError
        if e.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError, NSFileWriteVolumeReadOnlyError].contains(e.code) {
            return true
        }
        if e.domain == NSPOSIXErrorDomain, e.code == Int(EACCES) || e.code == Int(EPERM) { return true }
        if let underlying = e.userInfo[NSUnderlyingErrorKey] as? Error { return isPermissionError(underlying) }
        return false
    }

    static func read(_ url: URL) throws -> Data {
        let out = try run("/usr/bin/base64 -i \(quoted(url.path))",
                          prompt: "Notepad Lite needs administrator access to open “\(url.lastPathComponent)”.")
        guard let data = Data(base64Encoded: out, options: .ignoreUnknownCharacters) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
        }
        return data
    }

    static func write(_ data: Data, to url: URL) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("notepadlite-\(UUID().uuidString)")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // `cat >` keeps the destination's owner and permissions.
        _ = try run("/bin/cat \(quoted(tmp.path)) > \(quoted(url.path))",
                    prompt: "Notepad Lite needs administrator access to save “\(url.lastPathComponent)”.")
    }

    /// Single-quotes a path for the shell.
    private static func quoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes a Swift string as an AppleScript string literal.
    private static func appleScriptLiteral(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func run(_ command: String, prompt: String) throws -> String {
        let source = "do shell script \(appleScriptLiteral(command)) with prompt \(appleScriptLiteral(prompt)) with administrator privileges"
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -128 { throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError) }
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Administrator operation failed."
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        return result.stringValue ?? ""
    }
}
