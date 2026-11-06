//
//  ImageProcessors.swift
//  Pickel
//

import CoreGraphics

/// Namespace for the built-in processors.
public enum ImageProcessors {
    /// Resizes an image to a size in points.
    public struct Resize: ImageProcessing, Hashable {
        public let size: CGSize
        public let contentMode: ImageContentMode
        /// When `true` and `contentMode` is `.aspectFill`, the result is
        /// cropped to exactly `size`.
        public let crop: Bool
        /// Whether images smaller than `size` are enlarged.
        public let upscale: Bool

        public init(
            size: CGSize,
            contentMode: ImageContentMode = .aspectFill,
            crop: Bool = false,
            upscale: Bool = false
        ) {
            self.size = size
            self.contentMode = contentMode
            self.crop = crop
            self.upscale = upscale
        }

        public var identifier: String {
            "pickel.resize(\(size.width)x\(size.height),\(contentMode.rawValue),crop=\(crop),upscale=\(upscale))"
        }

        public func process(_ image: CGImage, scale: CGFloat) -> CGImage? {
            let source = CGSize(width: image.width, height: image.height)
            let target = CGSize(width: size.width * scale, height: size.height * scale)

            guard target.width >= 1, target.height >= 1 else {
                return nil
            }

            let horizontal = target.width / source.width
            let vertical = target.height / source.height

            var factor: CGFloat = switch contentMode {
            case .aspectFit: min(horizontal, vertical)
            case .aspectFill: max(horizontal, vertical)
            }

            if !upscale {
                factor = min(factor, 1)
            }

            let scaled = CGSize(
                width: (source.width * factor).rounded(),
                height: (source.height * factor).rounded()
            )

            let canvas: CGSize
            if crop, contentMode == .aspectFill {
                canvas = CGSize(
                    width: min(scaled.width, target.width.rounded()),
                    height: min(scaled.height, target.height.rounded())
                )
            } else {
                canvas = scaled
            }

            if canvas.width == source.width,
               canvas.height == source.height {
                return image
            }

            let drawRect = CGRect(
                x: (canvas.width - scaled.width) / 2,
                y: (canvas.height - scaled.height) / 2,
                width: scaled.width,
                height: scaled.height
            )

            return Graphics.draw(size: canvas, opaque: image.isOpaque) { context in
                context.interpolationQuality = .high
                context.draw(image, in: drawRect)
            }
        }
    }

    /// Rounds the corners of an image.
    public struct RoundedCorners: ImageProcessing, Hashable {
        /// Corner radius in points.
        public let radius: CGFloat

        public init(radius: CGFloat) {
            self.radius = radius
        }

        public var identifier: String {
            "pickel.roundedCorners(\(radius))"
        }

        public func process(_ image: CGImage, scale: CGFloat) -> CGImage? {
            let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            let pixelRadius = min(radius * scale, min(rect.width, rect.height) / 2)

            return Graphics.draw(size: rect.size, opaque: false) { context in
                context.addPath(
                    CGPath(
                        roundedRect: rect,
                        cornerWidth: pixelRadius,
                        cornerHeight: pixelRadius,
                        transform: nil
                    )
                )
                context.clip()
                context.draw(image, in: rect)
            }
        }
    }

    /// Crops an image to a centred circle.
    public struct Circle: ImageProcessing, Hashable {
        public init() {}

        public var identifier: String {
            "pickel.circle"
        }

        public func process(_ image: CGImage, scale: CGFloat) -> CGImage? {
            let side = CGFloat(min(image.width, image.height))
            let canvas = CGRect(x: 0, y: 0, width: side, height: side)
            let drawRect = CGRect(
                x: (side - CGFloat(image.width)) / 2,
                y: (side - CGFloat(image.height)) / 2,
                width: CGFloat(image.width),
                height: CGFloat(image.height)
            )

            return Graphics.draw(size: canvas.size, opaque: false) { context in
                context.addEllipse(in: canvas)
                context.clip()
                context.draw(image, in: drawRect)
            }
        }
    }
}

extension ImageProcessing where Self == ImageProcessors.Resize {
    /// Resizes the image to `size` points.
    public static func resize(
        size: CGSize,
        contentMode: ImageContentMode = .aspectFill,
        crop: Bool = false,
        upscale: Bool = false
    ) -> ImageProcessors.Resize {
        ImageProcessors.Resize(
            size: size,
            contentMode: contentMode,
            crop: crop,
            upscale: upscale
        )
    }
}

extension ImageProcessing where Self == ImageProcessors.RoundedCorners {
    /// Rounds the corners with a radius in points.
    public static func roundedCorners(radius: CGFloat) -> ImageProcessors.RoundedCorners {
        ImageProcessors.RoundedCorners(radius: radius)
    }
}

extension ImageProcessing where Self == ImageProcessors.Circle {
    /// Crops the image to a circle.
    public static var circle: ImageProcessors.Circle {
        ImageProcessors.Circle()
    }
}

// MARK: - Drawing

enum Graphics {
    static func draw(
        size: CGSize,
        opaque: Bool,
        _ drawing: (CGContext) -> Void
    ) -> CGImage? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())

        guard width > 0, height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: opaque
                      ? CGImageAlphaInfo.noneSkipLast.rawValue
                      : CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }

        drawing(context)
        return context.makeImage()
    }
}

extension CGImage {
    var isOpaque: Bool {
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            true
        default:
            false
        }
    }
}
