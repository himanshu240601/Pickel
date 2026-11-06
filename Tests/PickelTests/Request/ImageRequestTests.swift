//
//  ImageRequestTests.swift
//  Pickel
//

import CoreGraphics
import Foundation
import XCTest
@testable import Pickel

final class ImageRequestTests: XCTestCase {
    private let url = URL(string: "https://example.com/a.png")!

    func testPlainRequestKeysAreTheURL() {
        let request = ImageRequest(url: url)

        XCTAssertEqual(request.dataCacheKey, url.absoluteString)
        XCTAssertEqual(request.imageCacheKey, url.absoluteString)
    }

    func testImageKeyIncludesTargetSizeScaleAndProcessors() {
        let request = ImageRequest(
            url: url,
            targetSize: CGSize(width: 100, height: 50.5),
            contentMode: .aspectFit,
            scale: 3,
            processors: [.circle]
        )

        XCTAssertEqual(request.dataCacheKey, url.absoluteString)
        XCTAssertEqual(
            request.imageCacheKey,
            "https://example.com/a.png|size=100x50.5,mode=aspectFit|scale=3|processors=pickel.circle"
        )
    }

    func testDifferentProcessorsProduceDifferentKeys() {
        let a = ImageRequest(url: url, processors: [.roundedCorners(radius: 4)])
        let b = ImageRequest(url: url, processors: [.roundedCorners(radius: 8)])

        XCTAssertNotEqual(a.imageCacheKey, b.imageCacheKey)
        XCTAssertEqual(a.dataCacheKey, b.dataCacheKey)
    }

    func testStringLiteral() {
        let request: ImageRequest = "https://example.com/a.png"

        XCTAssertEqual(request.url, url)
    }

    func testOptionPresets() {
        XCTAssertTrue(ImageRequest.Options.reloadIgnoringCachedData.contains(.disableDiskCacheReads))
        XCTAssertFalse(ImageRequest.Options.reloadIgnoringCachedData.contains(.disableDiskCacheWrites))
        XCTAssertTrue(ImageRequest.Options.disableCaching.contains(.disableMemoryCacheWrites))
    }
}
