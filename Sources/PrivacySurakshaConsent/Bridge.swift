import Foundation
import WebKit

/// Receives page->host messages and decodes them.
///
/// The handler name is "compliant", matching EMBEDDED.md section 5's Swift row
/// and `postToHost`'s third branch
/// (window.webkit.messageHandlers.compliant). The page's send function tries
/// window.CompliantAndroid, then window.ReactNativeWebView, then this — so an
/// iOS shell must leave the first two undefined, which it does by simply not
/// installing them.
final class Bridge: NSObject, WKScriptMessageHandler {

    static let handlerName = "compliant"

    private let onEvent: (PageEvent) -> Void

    init(onEvent: @escaping (PageEvent) -> Void) {
        self.onEvent = onEvent
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Outbound page messages always arrive as a JSON STRING — postToHost
        // stringifies before handing the payload to any transport.
        // A non-string body is structurally not a page message at all — the
        // page never posts one — so there is no decode failure to report.
        guard let raw = message.body as? String else { return }

        let event: PageEvent
        do {
            event = try PageEvent.decode(raw)
        } catch ProtocolError.unknownEventType {
            // Deliberately silent, and the ONLY silent decode outcome. The
            // page is free to post message types a newer bundle introduced;
            // an unrecognised-but-valid forward extension is not an error.
            return
        } catch ProtocolError.missingField(let field) {
            // A RECOGNISED type missing a field it requires means the
            // hand-maintained decoder here has drifted from protocol.ts, or
            // the page sent something broken. Either way it is a contract
            // violation with no other diagnostic anywhere, and swallowing it
            // silently is how a whole event stream goes missing unexplained.
            onEvent(.error(message:
                "page->host message rejected: required field '\(field)' is missing — the shell's "
                + "PageEvent decoder and the page's protocol may have drifted apart"))
            return
        } catch ProtocolError.malformedJSON {
            onEvent(.error(message:
                "page->host message rejected: malformed message — not JSON, or carrying no "
                + "recognisable `type`"))
            return
        } catch {
            onEvent(.error(message:
                "page->host message rejected: \(error.localizedDescription)"))
            return
        }
        onEvent(event)
    }
}
