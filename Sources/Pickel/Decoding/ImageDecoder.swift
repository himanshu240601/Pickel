//
//  ImageDecoder.swift
//  Pickel
//

import CoreGraphics
import Foundation
import ImageIO

/// How an image should be fitted into a target size when downsampling.
public enum ImageContentMode: String, Hashable, Sendable {
    /// The whole image fits inside the target size.
    case aspectFit
    /// The image covers the whole target size (one side may overflow).
    case aspectFill
}

/// Decodes image data using ImageIO, optionally downsampling it so that the
/// full-size bitmap is never held in memory.
///
/// Decoding always happens eagerly (`kCGImageSourceShouldCacheImmediately`),
/// so the returned image is ready to draw without blocking the main thread.
/// EXIF orientation is applied to the pixels.
///
/// To protect against "decompression bombs" (tiny files that expand to
/// enormous bitmaps), images are never decoded larger than
/// ``maximumPixelCount`` pixels; bigger images are downsampled instead.
struct ImageDecoder: Sendable {
    /// Default cap: 24 megapixels (about 96 MB of bitmap memory).
    static let defaultMaximumPixelCount = 24_000_000

    var maximumPixelCount = ImageDecoder.defaultMaximumPixelCount

    /// Decodes `data` into a `CGImage`.
    ///
    /// - Parameters:
    ///   - targetSize: Size in points the image will be displayed at. When
    ///     `nil`, the image is decoded at its original pixel size.
    ///   - scale: Display scale used to convert `targetSize` to pixels.
    ///   - contentMode: How the image is fitted into `targetSize`.
    func decode(
        _ data: Data,
        targetSize: CGSize? = nil,
        scale: CGFloat = 1,
        contentMode: ImageContentMode = .aspectFill
    ) throws -> CGImage {
        guard !data.isEmpty else {
            throw ImageDecodingError.invalidData
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary

        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            sourceOptions
        ), CGImageSourceGetCount(source) > 0 else {
            throw ImageDecodingError.invalidData
        }

        guard let pixelSize = Self.orientedPixelSize(of: source) else {
            throw ImageDecodingError.invalidData
        }

        let maxPixelSize = min(
            Self.maxPixelSize(
                source: pixelSize,
                target: targetSize,
                scale: scale,
                contentMode: contentMode
            ),
            Self.longestSide(source: pixelSize, maximumPixelCount: maximumPixelCount)
        )

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as [CFString: Any] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options
        ) else {
            throw ImageDecodingError.decodingFailed
        }

        return image
    }

    /// Pixel size of the first frame after applying EXIF orientation.
    static func orientedPixelSize(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0
        else {
            return nil
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1

        // Orientations 5...8 rotate the image by 90 degrees.
        if (5...8).contains(orientation) {
            return CGSize(width: height, height: width)
        }

        return CGSize(width: width, height: height)
    }

    /// Longest side allowed so the image has at most `maximumPixelCount`
    /// pixels.
    static func longestSide(source: CGSize, maximumPixelCount: Int) -> Int {
        let pixels = source.width * source.height
        let longest = max(source.width, source.height)

        guard maximumPixelCount > 0, pixels > CGFloat(maximumPixelCount) else {
            return Int(longest.rounded())
        }

        let factor = (CGFloat(maximumPixelCount) / pixels).squareRoot()
        return max(1, Int((longest * factor).rounded(.down)))
    }

    /// The longest side, in pixels, the decoded image should have.
    /// Never upscales beyond the source size.
    static func maxPixelSize(
        source: CGSize,
        target: CGSize?,
        scale: CGFloat,
        contentMode: ImageContentMode
    ) -> Int {
        let sourceLongestSide = max(source.width, source.height)

        guard let target,
              target.width > 0, target.height > 0,
              scale > 0
        else {
            return Int(sourceLongestSide.rounded())
        }

        let horizontal = target.width * scale / source.width
        let vertical = target.height * scale / source.height

        let factor: CGFloat = switch contentMode {
        case .aspectFit: min(horizontal, vertical)
        case .aspectFill: max(horizontal, vertical)
        }

        let clamped = min(factor, 1)
        return max(1, Int((sourceLongestSide * clamped).rounded(.up)))
    }
}
