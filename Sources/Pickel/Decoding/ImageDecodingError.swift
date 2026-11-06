//
//  ImageDecodingError.swift
//  Pickel
//

import Foundation

/// Errors thrown while turning downloaded bytes into an image.
public enum ImageDecodingError: Error, Equatable, Sendable {
    /// The data is empty or is not in an image format supported by ImageIO.
    case invalidData
    /// ImageIO recognised the data but failed to produce a bitmap.
    case decodingFailed
}
