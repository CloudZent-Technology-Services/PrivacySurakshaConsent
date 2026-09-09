import Foundation
@testable import PrivacySurakshaConsent

/// A scripted stand-in for URLSession. Airplane mode in the conformance suite
/// is this returning a failure, not a device toggle — which makes items 7 and
/// 8 of the suite runnable in CI (design 6.2).
final class StubHTTP: HTTPPerforming, @unchecked Sendable {

    enum Outcome {
        /// `headers` defaults to empty so every existing call site — none of
        /// which cares about response headers — is unaffected. DownloadBridge
        /// is the first consumer to pass a real Content-Disposition value.
        case success(status: Int, body: Data, headers: [String: String] = [:])
        case failure(Error)
        /// Never answers. This is how the suite proves that a code path does
        /// NOT wait on the network: a request that would be awaited hangs the
        /// test, a request that is genuinely fired-and-forgotten does not.
        case never
    }

    enum StubError: Error { case offline }

    /// Requests this stub was asked to perform, in order. Assertions read this.
    private(set) var requests: [URLRequest] = []
    private var outcomes: [Outcome]
    private let lock = NSLock()

    /// Outcomes are consumed in order; the last one repeats once exhausted, so
    /// a test that only cares about "always offline" passes a single failure.
    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    convenience init(alwaysOffline: Bool = true) {
        self.init([.failure(StubError.offline)])
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        requests.append(request)
        let outcome = outcomes.count > 1 ? outcomes.removeFirst() : (outcomes.first ?? .failure(StubError.offline))
        lock.unlock()

        switch outcome {
        case let .success(status, body, headers):
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers
            )!
            return (body, response)
        case let .failure(error):
            throw error
        case .never:
            // An hour is "forever" relative to any test timeout. Not
            // `Task.sleep(nanoseconds: .max)`, which overflows internally.
            try await Task.sleep(nanoseconds: 3_600 * NSEC_PER_SEC)
            throw StubError.offline
        }
    }
}
