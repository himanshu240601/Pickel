//
//  ImagePipelineTests.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation
import XCTest
@testable import Pickel


private actor DownloadSpy: ImageDownloading {
    private(set) var callCount = 0

    private var pending: [
        CheckedContinuation<Data, any Error>
    ] = []

    private var callCountWaiters: [
        (expected: Int, continuation: CheckedContinuation<Void, Never>)
    ] = []

    private var wasCancelled = false

    func waitForCancellation() async {
        while !wasCancelled {
            await Task.yield()
        }
    }

    func isDownloadCancelled() -> Bool {
        wasCancelled
    }
    
    func download(from url: URL) async throws -> Data {
        callCount += 1
        resumeCallCountWaiters()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.append(continuation)
            }
        } onCancel: {
            Task {
                await self.recordCancellation()
            }
        }
    }
    
    private func recordCancellation() {
        wasCancelled = true
    }

    func waitForCallCount(_ expected: Int) async {
        if callCount >= expected {
            return
        }

        await withCheckedContinuation { continuation in
            callCountWaiters.append((expected, continuation))
        }
    }

    func succeed(with data: Data) {
        let continuations = pending
        self.pending.removeAll()
        
        for continuation in continuations {
            continuation.resume(returning: data)
        }
    }

    private func resumeCallCountWaiters() {
        let ready = callCountWaiters.filter {
            callCount >= $0.expected
        }

        callCountWaiters.removeAll {
            callCount >= $0.expected
        }

        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}

final class ImagePipelineTests: XCTestCase {
    func testConcurrentRequestsForSameURLShareDownload() async throws {
        let downloader = DownloadSpy()
        let sut = ImagePipeline(downloader: downloader)
        let url = URL(string: "https://example.com/image.png")!
        let expectedData = Data("image-data".utf8)

        let first = Task {
            try await sut.data(for: url)
        }

        await downloader.waitForCallCount(1)

        let second = Task {
            try await sut.data(for: url)
        }

        var registeredWaiters = 0

        for _ in 0..<100 {
            registeredWaiters = await sut.waiterCount(for: url)

            if registeredWaiters >= 2 {
                break
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(
            registeredWaiters,
            2,
            "Both callers should join the same in-flight request"
        )

        await downloader.succeed(with: expectedData)

        let firstResult = try await first.value
        let secondResult = try await second.value

        XCTAssertEqual(firstResult, expectedData)
        XCTAssertEqual(secondResult, expectedData)
        let calls = await downloader.callCount
        XCTAssertEqual(calls, 1)
    }
    
    
    func testCancellingOneCallerDoesNotCancelOtherCallers() async throws {
        let downloader = DownloadSpy()
        let sut = ImagePipeline(downloader: downloader)
        let url = URL(string: "https://example.com/shared.png")!
        let expectedData = Data("image-data".utf8)

        let first = Task {
            try await sut.data(for: url)
        }

        await downloader.waitForCallCount(1)

        let second = Task {
            try await sut.data(for: url)
        }

        var registeredWaiters = 0

        for _ in 0..<100 {
            registeredWaiters = await sut.waiterCount(for: url)

            if registeredWaiters == 2 {
                break
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(registeredWaiters, 2)

        first.cancel()

        do {
            _ = try await first.value
            XCTFail("Expected the first caller to be cancelled")
        } catch is CancellationError {
            // Expected.
        }

        let remainingWaiters = await sut.waiterCount(for: url)
        XCTAssertEqual(remainingWaiters, 1)

        await downloader.succeed(with: expectedData)

        let secondResult = try await second.value
        XCTAssertEqual(secondResult, expectedData)

        let callCount = await downloader.callCount
        XCTAssertEqual(callCount, 1)
    }
    
    func testCancellingAllCallersCancelsUnderlyingRequest() async throws {
        let downloader = DownloadSpy()
        let sut = ImagePipeline(downloader: downloader)
        let url = URL(string: "https://example.com/cancel.png")!

        let first = Task {
            try await sut.data(for: url)
        }

        await downloader.waitForCallCount(1)

        let second = Task {
            try await sut.data(for: url)
        }

        var registeredWaiters = 0

        for _ in 0..<100 {
            registeredWaiters = await sut.waiterCount(for: url)

            if registeredWaiters == 2 {
                break
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(registeredWaiters, 2)

        first.cancel()
        second.cancel()

        do {
            _ = try await first.value
            XCTFail("Expected the first caller to be cancelled")
        } catch is CancellationError {
            // Expected.
        }

        do {
            _ = try await second.value
            XCTFail("Expected the second caller to be cancelled")
        } catch is CancellationError {
            // Expected.
        }

        let remainingWaiters = await sut.waiterCount(for: url)
        XCTAssertEqual(remainingWaiters, 0)
        
        await downloader.waitForCancellation()

        let wasCancelled = await downloader.isDownloadCancelled()
        XCTAssertTrue(wasCancelled)
    }
}
