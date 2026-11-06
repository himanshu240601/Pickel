//
//  ImagePrefetcherTests.swift
//  Pickel
//

import Foundation
import XCTest
@testable import Pickel

final class ImagePrefetcherTests: XCTestCase {
    private func makePipeline(urls: [URL]) async -> (ImagePipeline, StubDownloader) {
        let downloader = StubDownloader()
        for url in urls {
            await downloader.setResponse(.success(TestImages.png(width: 4, height: 4)), for: url)
        }
        let pipeline = ImagePipeline(
            configuration: .init(
                downloader: downloader,
                memoryCache: MemoryCache(),
                diskCache: nil
            )
        )
        return (pipeline, downloader)
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Condition was never met")
    }

    func testPrefetchingPopulatesMemoryCache() async throws {
        let urls = (0..<5).map { URL(string: "https://example.com/\($0).png")! }
        let (pipeline, downloader) = await makePipeline(urls: urls)
        let sut = ImagePrefetcher(pipeline: pipeline, maxConcurrentRequests: 2)

        sut.startPrefetching(with: urls)

        try await waitUntil { sut.activeCount == 0 }
        for url in urls {
            XCTAssertNotNil(pipeline.cachedImage(for: url))
        }
        let calls = await downloader.callCount
        XCTAssertEqual(calls, 5)
    }

    func testDuplicateRequestsAreIgnored() async throws {
        let url = URL(string: "https://example.com/a.png")!
        let (pipeline, downloader) = await makePipeline(urls: [url])
        let sut = ImagePrefetcher(pipeline: pipeline, maxConcurrentRequests: 1)

        sut.startPrefetching(with: [url, url, url])

        try await waitUntil { sut.activeCount == 0 }
        let calls = await downloader.callCount
        XCTAssertEqual(calls, 1)
    }

    func testAlreadyCachedImagesAreSkipped() async throws {
        let url = URL(string: "https://example.com/a.png")!
        let (pipeline, downloader) = await makePipeline(urls: [url])
        _ = try await pipeline.image(for: url)
        let sut = ImagePrefetcher(pipeline: pipeline)

        sut.startPrefetching(with: [url])

        XCTAssertEqual(sut.activeCount, 0)
        let calls = await downloader.callCount
        XCTAssertEqual(calls, 1)
    }

    func testStopPrefetchingClearsQueue() async {
        let urls = (0..<10).map { URL(string: "https://example.com/\($0).png")! }
        let (pipeline, _) = await makePipeline(urls: urls)
        let sut = ImagePrefetcher(pipeline: pipeline, maxConcurrentRequests: 1)

        sut.startPrefetching(with: urls)
        sut.stopPrefetching()

        XCTAssertEqual(sut.activeCount, 0)
    }
}
