//
//  MockURLProtocol.swift
//  anyappTests
//

import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static let lock = NSLock()

    static func withRequestHandler<R>(
        _ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
        perform work: () async throws -> R
    ) async rethrows -> R {
        Self.lock.lock()
        Self.requestHandler = handler
        Self.lock.unlock()

        defer {
            Self.lock.lock()
            Self.requestHandler = nil
            Self.lock.unlock()
        }

        return try await work()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.requestHandler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
