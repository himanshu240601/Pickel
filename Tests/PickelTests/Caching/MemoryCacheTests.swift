//
//  MemoryCacheTests.swift
//  Pickel
//

import Foundation
import XCTest
@testable import Pickel

final class MemoryCacheTests: XCTestCase {
    private func makeImage(width: Int = 10, height: Int = 10) throws -> PlatformImage {
        let cgImage = try ImageDecoder().decode(
            TestImages.png(width: width, height: height)
        )
        return PlatformImage.make(cgImage: cgImage, scale: 1)
    }

    func testStoresAndReturnsImage() throws {
        let sut = MemoryCache()
        let image = try makeImage()

        sut.setImage(image, forKey: "a")

        XCTAssertTrue(sut.image(forKey: "a") === image)
        XCTAssertNil(sut.image(forKey: "b"))
    }

    func testRemovesImage() throws {
        let sut = MemoryCache()
        sut.setImage(try makeImage(), forKey: "a")

        sut.removeImage(forKey: "a")

        XCTAssertNil(sut.image(forKey: "a"))
    }

    func testRemoveAll() throws {
        let sut = MemoryCache()
        sut.setImage(try makeImage(), forKey: "a")
        sut.setImage(try makeImage(), forKey: "b")

        sut.removeAll()

        XCTAssertNil(sut.image(forKey: "a"))
        XCTAssertNil(sut.image(forKey: "b"))
    }

    func testCostIsDecodedBitmapSize() throws {
        let image = try makeImage(width: 20, height: 10)

        XCTAssertGreaterThanOrEqual(MemoryCache.cost(of: image), 20 * 10 * 4)
    }

    func testCountLimitEvictsEntries() throws {
        let sut = MemoryCache(countLimit: 1)

        sut.setImage(try makeImage(), forKey: "a")
        sut.setImage(try makeImage(), forKey: "b")

        XCTAssertNotNil(sut.image(forKey: "b"))
        XCTAssertNil(sut.image(forKey: "a"))
    }
}
