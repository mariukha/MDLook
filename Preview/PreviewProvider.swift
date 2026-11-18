import Cocoa
import Quartz
import JavaScriptCore
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    private static let bundle = Bundle(for: PreviewProvider.self)

    private static let markedSource: String = {
        guard let url = bundle.url(forResource: "marked", withExtension: "js"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s
    }()

    private static let css: String = {
        guard let url = bundle.url(forResource: "style", withExtension: "css"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s
    }()

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let markdown = Self.readText(fileURL)
        let html = Self.renderPage(markdown: markdown, title: fileURL.lastPathComponent)

        return QLPreviewReply(dataOfContentType: .html,
                              contentSize: CGSize(width: 860, height: 1000)) { reply in
            reply.stringEncoding = .utf8
            reply.title = fileURL.lastPathComponent
            return Data(html.utf8)
        }
    }

    private static func readText(_ url: URL) -> String {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        if let d = try? Data(contentsOf: url) {
            return String(decoding: d, as: UTF8.self)
        }
        return ""
    }
    private static func stripFrontMatter(_ text: String) -> String {
        guard text.hasPrefix("---\n") || text.hasPrefix("---\r\n") else { return text }
        let lines = text.components(separatedBy: .newlines)
        for i in 1..<lines.count where lines[i] == "---" || lines[i] == "..." {
            return lines[(i + 1)...].joined(separator: "\n")
        }
        return text
    }

    private static func markdownToHTML(_ md: String) -> String {
        guard let ctx = JSContext() else { return escape(md) }
        ctx.evaluateScript(markedSource)
        guard let parse = ctx.objectForKeyedSubscript("marked")?
                .objectForKeyedSubscript("parse"),
              !parse.isUndefined,
              let out = parse.call(withArguments: [md, ["gfm": true, "breaks": false]]),
              out.isString,
              let html = out.toString()
        else {
            return "<pre>\(escape(md))</pre>"
        }
        return html
    }

    private static func renderPage(markdown: String, title: String) -> String {
        let body = markdownToHTML(stripFrontMatter(markdown))
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <title>\(escape(title))</title>
        <style>\(css)</style>
        </head>
        <body><article>\(body)</article></body>
        </html>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
