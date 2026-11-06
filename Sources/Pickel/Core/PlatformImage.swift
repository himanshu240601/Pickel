//
//  PlatformImage.swift
//  Pickel
//

import CoreGraphics

#if canImport(UIKit)
import UIKit

/// The native image type of the current platform (`UIImage` on iOS, tvOS
/// and visionOS, `NSImage` on macOS).
public typealias PlatformImage = UIImage

extension PlatformImage {
    static func make(cgImage: CGImage, scale: CGFloat) -> PlatformImage {
        UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

#elseif canImport(AppKit)
import AppKit

/// The native image type of the current platform (`UIImage` on iOS, tvOS
/// and visionOS, `NSImage` on macOS).
public typealias PlatformImage = NSImage

extension PlatformImage {
    static func make(cgImage: CGImage, scale: CGFloat) -> PlatformImage {
        let size = CGSize(
            width: CGFloat(cgImage.width) / scale,
            height: CGFloat(cgImage.height) / scale
        )
        return NSImage(cgImage: cgImage, size: size)
    }

    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif
