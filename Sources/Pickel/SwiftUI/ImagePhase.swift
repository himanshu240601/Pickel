//
//  ImagePhase.swift
//  Pickel
//

import SwiftUI

/// The current state of a ``PickelImage`` load.
public enum PickelImagePhase {
    /// No image is loaded yet (or the URL is `nil`).
    case empty
    /// The image loaded successfully.
    case success(Image)
    /// The image failed to load.
    case failure(any Error)

    /// The loaded image, if any.
    public var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }

    /// The error, if loading failed.
    public var error: (any Error)? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

extension Image {
    /// Creates a SwiftUI image from a `UIImage` / `NSImage`.
    public init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
