//
//  ImageProcessing.swift
//  Pickel
//

import CoreGraphics

/// Transforms a decoded image. Processors run off the main thread after
/// decoding, and their output is stored in the memory cache.
public protocol ImageProcessing: Sendable {
    /// Uniquely identifies the processor and its parameters. Used as part of
    /// the memory cache key, so two processors with the same identifier must
    /// produce the same output.
    var identifier: String { get }

    /// Returns the processed image, or `nil` if processing failed.
    ///
    /// - Parameter scale: Display scale of the image, used to convert point
    ///   values (such as sizes or corner radii) into pixels.
    func process(_ image: CGImage, scale: CGFloat) -> CGImage?
}

/// Errors thrown while processing an image.
public enum ImageProcessingError: Error, Equatable, Sendable {
    /// The processor with the given identifier returned `nil`.
    case processingFailed(identifier: String)
}
