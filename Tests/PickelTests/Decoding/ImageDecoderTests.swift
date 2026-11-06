//
//  ImageDecoderTests.swift
//  Pickel
//

import CoreGraphics
import Foundation
import XCTest
@testable import Pickel

final class ImageDecoderTests: XCTestCase {
    private let sut = ImageDecoder()

    func testDecodesAtOriginalSizeWithoutTarget() throws {
        let image = try sut.decode(TestImages.png(width: 120, height: 80))

        XCTAssertEqual(image.width, 120)
        XCTAssertEqual(image.height, 80)
    }

    func testDownsamplesAspectFillToCoverTarget() throws {
        let data = TestImages.png(width: 400, height: 200)

        let image = try sut.decode(
            data,
            targetSize: CGSize(width: 50, height: 50),
            scale: 2,
            contentMode: .aspectFill
        )

        // Shorter side must cover 100px -> 200x100.
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 100)
    }

    func testDownsamplesAspectFitInsideTarget() throws {
        let data = TestImages.png(width: 400, height: 200)

        let image = try sut.decode(
            data,
            targetSize: CGSize(width: 50, height: 50),
            scale: 2,
            contentMode: .aspectFit
        )

        // Longer side must fit 100px -> 100x50.
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 50)
    }

    func testNeverUpscales() throws {
        let image = try sut.decode(
            TestImages.png(width: 40, height: 20),
            targetSize: CGSize(width: 500, height: 500),
            scale: 3
        )

        XCTAssertEqual(image.width, 40)
        XCTAssertEqual(image.height, 20)
    }

    func testAppliesEXIFOrientation() throws {
        // Orientation 6 = rotated 90° clockwise.
        let image = try sut.decode(
            TestImages.png(width: 120, height: 80, orientation: 6)
        )

        XCTAssertEqual(image.width, 80)
        XCTAssertEqual(image.height, 120)
    }

    func testThrowsForEmptyData() {
        XCTAssertThrowsError(try sut.decode(Data())) { error in
            XCTAssertEqual(error as? ImageDecodingError, .invalidData)
        }
    }

    func testThrowsForNonImageData() {
        XCTAssertThrowsError(try sut.decode(Data("not an image".utf8))) { error in
            XCTAssertEqual(error as? ImageDecodingError, .invalidData)
        }
    }
}
