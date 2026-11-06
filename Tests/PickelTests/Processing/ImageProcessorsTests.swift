//
//  ImageProcessorsTests.swift
//  Pickel
//

import CoreGraphics
import Foundation
import XCTest
@testable import Pickel

final class ImageProcessorsTests: XCTestCase {
    private func makeImage(width: Int, height: Int) throws -> CGImage {
        try ImageDecoder().decode(TestImages.png(width: width, height: height))
    }

    private func alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(
            image,
            in: CGRect(
                x: -x,
                y: -(image.height - 1 - y),
                width: image.width,
                height: image.height
            )
        )
        return pixel[3]
    }

    func testResizeAspectFill() throws {
        let output = ImageProcessors.Resize(size: CGSize(width: 50, height: 50))
            .process(try makeImage(width: 400, height: 200), scale: 2)

        XCTAssertEqual(output?.width, 200)
        XCTAssertEqual(output?.height, 100)
    }

    func testResizeAspectFillWithCrop() throws {
        let output = ImageProcessors.Resize(size: CGSize(width: 50, height: 50), crop: true)
            .process(try makeImage(width: 400, height: 200), scale: 2)

        XCTAssertEqual(output?.width, 100)
        XCTAssertEqual(output?.height, 100)
    }

    func testResizeAspectFit() throws {
        let output = ImageProcessors.Resize(size: CGSize(width: 50, height: 50), contentMode: .aspectFit)
            .process(try makeImage(width: 400, height: 200), scale: 1)

        XCTAssertEqual(output?.width, 50)
        XCTAssertEqual(output?.height, 25)
    }

    func testResizeDoesNotUpscaleByDefault() throws {
        let input = try makeImage(width: 10, height: 10)
        let output = ImageProcessors.Resize(size: CGSize(width: 100, height: 100))
            .process(input, scale: 1)

        XCTAssertEqual(output?.width, 10)
    }

    func testResizeUpscalesWhenAllowed() throws {
        let output = ImageProcessors.Resize(size: CGSize(width: 100, height: 100), upscale: true)
            .process(try makeImage(width: 10, height: 10), scale: 1)

        XCTAssertEqual(output?.width, 100)
    }

    func testCircleProducesSquareWithTransparentCorners() throws {
        let output = try XCTUnwrap(
            ImageProcessors.Circle().process(try makeImage(width: 100, height: 60), scale: 1)
        )

        XCTAssertEqual(output.width, 60)
        XCTAssertEqual(output.height, 60)
        XCTAssertEqual(alpha(of: output, x: 0, y: 0), 0)
        XCTAssertEqual(alpha(of: output, x: 30, y: 30), 255)
    }

    func testRoundedCornersMakeCornersTransparent() throws {
        let output = try XCTUnwrap(
            ImageProcessors.RoundedCorners(radius: 10)
                .process(try makeImage(width: 100, height: 100), scale: 1)
        )

        XCTAssertEqual(output.width, 100)
        XCTAssertEqual(alpha(of: output, x: 0, y: 0), 0)
        XCTAssertEqual(alpha(of: output, x: 50, y: 50), 255)
    }

    func testIdentifiersDifferByParameters() {
        XCTAssertNotEqual(
            ImageProcessors.Resize(size: CGSize(width: 1, height: 1)).identifier,
            ImageProcessors.Resize(size: CGSize(width: 2, height: 1)).identifier
        )
    }
}
