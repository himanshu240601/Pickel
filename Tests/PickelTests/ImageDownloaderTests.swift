//
//  ImageDownloaderTests.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation
import XCTest
@testable import Pickel

final class StubURLProtocol: URLProtocol {
    private var requestStarted: XCTestExpectation!
    
    fileprivate static let slowRequestObserver = SlowRequestObserver()
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }
    
    override func startLoading() {
        guard let url = request.url else {
            return
        }
        
        switch url.path {
        case "/success":
            let data = Data("image-data".utf8)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            
        case "/server-error":
            let response = HTTPURLResponse(
                url: url,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocolDidFinishLoading(self)
            
        case "/invalid-response":
            let response = URLResponse(
                url: url,
                mimeType: nil,
                expectedContentLength: 0,
                textEncodingName: nil
            )
            
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocolDidFinishLoading(self)
            
        case "/transport-error":
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.notConnectedToInternet)
            )
            
        case "/slow":
            Self.slowRequestObserver.notify()
            return
            
        default:
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
        }
    }
    
    override func stopLoading() {}
}

final class ImageDownloaderTests: XCTestCase {
    
    private func makeSUT() -> ImageDownloader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        
        let session = URLSession(configuration: configuration)
        
        return ImageDownloader(session: session)
    }
    
    func testDownloadReturnsDataForSuccessfulResponse() async throws {
        let sut = makeSUT()
        let url = URL(string: "https://example.com/success")!
        
        let data = try await sut.download(from: url)
        
        XCTAssertEqual(data, Data("image-data".utf8))
    }
    
    func testDownloadThrowsForUnsuccessfulHTTPStatus() async {
        let sut = makeSUT()
        let url = URL(string: "https://example.com/server-error")!

        do {
            _ = try await sut.download(from: url)
            XCTFail("Expected an HTTP status error")
        } catch let error as ImageDownloaderError {
            XCTAssertEqual(error, .unacceptableStatusCode(503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDownloadThrowsForInvalidResponse() async {
        let sut = makeSUT()
        let url = URL(string: "https://example.com/invalid-response")!

        do {
            _ = try await sut.download(from: url)
            XCTFail("Expected an invalid response error")
        } catch let error as ImageDownloaderError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDownloadPropagatesTransportError() async {
        let sut = makeSUT()
        let url = URL(string: "https://example.com/transport-error")!

        do {
            _ = try await sut.download(from: url)
            XCTFail("Expected a transport error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDownloadCanBeCancelled() async {
        let sut = makeSUT()
        let url = URL(string: "https://example.com/slow")!

        let requestStarted = expectation(
            description: "Slow request started"
        )

        StubURLProtocol.slowRequestObserver.setCallback {
            requestStarted.fulfill()
        }

        defer {
            StubURLProtocol.slowRequestObserver.setCallback(nil)
        }

        let task = Task {
            try await sut.download(from: url)
        }

        await fulfillment(
            of: [requestStarted],
            timeout: 2
        )

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected the request to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class SlowRequestObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: (@Sendable () -> Void)?

    func setCallback(_ callback: (@Sendable () -> Void)?) {
        lock.lock()
        defer { lock.unlock() }

        self.callback = callback
    }

    func notify() {
        lock.lock()
        let callback = self.callback
        lock.unlock()

        callback?()
    }
}
