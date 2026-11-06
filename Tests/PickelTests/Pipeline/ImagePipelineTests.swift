//
//  ImagePipelineTests.swift
//  Pickel
//

import CoreGraphics
import Foundation
import XCTest
@testable import Pickel

final class ImagePipelineTests: XCTestCase {
    private let url = URL(string: "https://example.com/image.png")!
    private var directory: URL!
    private var downloader: StubDownloader!
    private var memoryCache: MemoryCache!
    private var diskCache: DiskCache!
    private var sut: ImagePipeline!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PickelPipelineTests-\(UUID().uuidString)")
        downloader = StubDownloader()
        memoryCache = MemoryCache()
        diskCache = DiskCache(directory: directory)
        sut = ImagePipeline(
            configuration: .init(
                downloader: downloader,
                memoryCache: memoryCache,
                diskCache: diskCache
            )
        )
        await downloader.setResponse(
            .success(TestImages.png(width: 200, height: 100)),
            for: url
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    private func waitForDiskEntry(_ key: String) async throws {
        for _ in 0..<200 {
            if await diskCache.containsData(forKey: key) {
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Disk cache entry was never written")
    }

    func testLoadsAndDecodesImage() async throws {
        let image = try await sut.image(for: url)

        XCTAssertEqual(image.cgImage?.width, 200)
        XCTAssertEqual(image.cgImage?.height, 100)
    }

    func testSecondLoadIsServedFromMemory() async throws {
        let first = try await sut.image(for: url)
        let second = try await sut.image(for: url)

        XCTAssertTrue(first === second)
        let calls = await downloader.callCount
        XCTAssertEqual(calls, 1)
        XCTAssertNotNil(sut.cachedImage(for: url))
    }

    func testLoadIsServedFromDiskWhenMemoryIsEmpty() async throws {
        _ = try await sut.image(for: url)
        try await waitForDiskEntry(url.absoluteString)
        memoryCache.removeAll()

        _ = try await sut.image(for: url)

        let calls = await downloader.callCount
        XCTAssertEqual(calls, 1)
    }

    func testReloadIgnoringCachedDataHitsNetwork() async throws {
        _ = try await sut.image(for: url)

        _ = try await sut.image(
            for: ImageRequest(url: url, options: .reloadIgnoringCachedData)
        )

        let calls = await downloader.callCount
        XCTAssertEqual(calls, 2)
    }

    func testReturnCacheDataDontLoadThrowsOnMiss() async {
        do {
            _ = try await sut.image(
                for: ImageRequest(url: url, options: .returnCacheDataDontLoad)
            )
            XCTFail("Expected a cache miss")
        } catch {
            XCTAssertEqual(error as? ImagePipelineError, .cacheMiss)
        }

        let calls = await downloader.callCount
        XCTAssertEqual(calls, 0)
    }

    func testDisableCachingStoresNothing() async throws {
        _ = try await sut.image(
            for: ImageRequest(url: url, options: .disableCaching)
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(sut.cachedImage(for: url))
        let onDisk = await diskCache.containsData(forKey: url.absoluteString)
        XCTAssertFalse(onDisk)
    }

    func testDownsamplesAndProcesses() async throws {
        let request = ImageRequest(
            url: url,
            targetSize: CGSize(width: 50, height: 50),
            scale: 2,
            processors: [.circle]
        )

        let image = try await sut.image(for: request)

        XCTAssertEqual(image.cgImage?.width, 100)
        XCTAssertEqual(image.cgImage?.height, 100)
        XCTAssertNotNil(sut.cachedImage(for: request))
        XCTAssertNil(sut.cachedImage(for: url))
    }

    func testDifferentSizesShareOneDownloadViaDiskCache() async throws {
        _ = try await sut.image(for: ImageRequest(url: url, targetSize: CGSize(width: 10, height: 10)))
        try await waitForDiskEntry(url.absoluteString)

        _ = try await sut.image(for: ImageRequest(url: url, targetSize: CGSize(width: 20, height: 20)))

        let calls = await downloader.callCount
        XCTAssertEqual(calls, 1)
    }

    func testInvalidDataIsNotCached() async throws {
        await downloader.setResponse(.success(Data("<html>".utf8)), for: url)

        do {
            _ = try await sut.image(for: url)
            XCTFail("Expected a decoding error")
        } catch {
            XCTAssertEqual(error as? ImageDecodingError, .invalidData)
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        let onDisk = await diskCache.containsData(forKey: url.absoluteString)
        XCTAssertFalse(onDisk)
    }

    func testPropagatesDownloadErrors() async {
        await downloader.setResponse(
            .failure(ImageDownloaderError.unacceptableStatusCode(404)),
            for: url
        )

        do {
            _ = try await sut.image(for: url)
            XCTFail("Expected a download error")
        } catch {
            XCTAssertEqual(
                error as? ImageDownloaderError,
                .unacceptableStatusCode(404)
            )
        }
    }

    func testPassesURLRequestHeadersToDownloader() async throws {
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")

        _ = try await sut.image(for: ImageRequest(urlRequest: urlRequest))

        let requests = await downloader.requests
        XCTAssertEqual(
            requests.first?.value(forHTTPHeaderField: "Authorization"),
            "Bearer token"
        )
    }

    func testRemoveCachedImage() async throws {
        _ = try await sut.image(for: url)
        try await waitForDiskEntry(url.absoluteString)

        await sut.removeCachedImage(for: ImageRequest(url: url))

        XCTAssertNil(sut.cachedImage(for: url))
        let onDisk = await diskCache.containsData(forKey: url.absoluteString)
        XCTAssertFalse(onDisk)
    }

    func testLoadsFileURLsWithDefaultDownloader() async throws {
        let fileURL = directory.appendingPathComponent("local.png")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try TestImages.png(width: 8, height: 8).write(to: fileURL)

        let pipeline = ImagePipeline(
            configuration: .init(memoryCache: nil, diskCache: nil)
        )
        let image = try await pipeline.image(for: fileURL)

        XCTAssertEqual(image.cgImage?.width, 8)
    }

    #if canImport(UIKit)
    // UIImage is Sendable, so results can be used directly on the main actor.
    @MainActor
    func testCanBeCalledFromMainActor() async throws {
        let image = try await sut.image(for: url)

        XCTAssertNotNil(image.cgImage)
    }
    #endif
}
