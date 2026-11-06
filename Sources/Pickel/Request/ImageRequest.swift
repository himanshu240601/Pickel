//
//  ImageRequest.swift
//  Pickel
//

import CoreGraphics
import Foundation

/// Describes an image to load: where it comes from, how it should be
/// decoded and processed, and how caches are used.
public struct ImageRequest: Sendable {
    /// Controls how a request interacts with caches and the network.
    public struct Options: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let disableMemoryCacheReads = Options(rawValue: 1 << 0)
        public static let disableMemoryCacheWrites = Options(rawValue: 1 << 1)
        public static let disableDiskCacheReads = Options(rawValue: 1 << 2)
        public static let disableDiskCacheWrites = Options(rawValue: 1 << 3)
        /// Only return a cached image; never hit the network.
        public static let returnCacheDataDontLoad = Options(rawValue: 1 << 4)

        /// Skip cache reads but still store the fresh result.
        public static let reloadIgnoringCachedData: Options = [
            .disableMemoryCacheReads,
            .disableDiskCacheReads
        ]

        /// Don't read from or write to any cache.
        public static let disableCaching: Options = [
            .disableMemoryCacheReads,
            .disableMemoryCacheWrites,
            .disableDiskCacheReads,
            .disableDiskCacheWrites
        ]
    }

    /// The underlying URL request.
    public var urlRequest: URLRequest

    /// Size in points the image will be displayed at. When set, the image
    /// is downsampled while decoding, which saves a lot of memory.
    public var targetSize: CGSize?

    /// How the image is fitted into ``targetSize``.
    public var contentMode: ImageContentMode

    /// Display scale used to convert ``targetSize`` to pixels and as the
    /// resulting image's `scale`.
    public var scale: CGFloat

    /// Processors applied in order after decoding.
    public var processors: [any ImageProcessing]

    /// Cache and network options.
    public var options: Options

    /// The URL of the image.
    public var url: URL? {
        urlRequest.url
    }

    public init(
        urlRequest: URLRequest,
        targetSize: CGSize? = nil,
        contentMode: ImageContentMode = .aspectFill,
        scale: CGFloat = 1,
        processors: [any ImageProcessing] = [],
        options: Options = []
    ) {
        self.urlRequest = urlRequest
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.scale = scale
        self.processors = processors
        self.options = options
    }

    public init(
        url: URL,
        targetSize: CGSize? = nil,
        contentMode: ImageContentMode = .aspectFill,
        scale: CGFloat = 1,
        processors: [any ImageProcessing] = [],
        options: Options = []
    ) {
        self.init(
            urlRequest: URLRequest(url: url),
            targetSize: targetSize,
            contentMode: contentMode,
            scale: scale,
            processors: processors,
            options: options
        )
    }

    /// Key identifying the original data (used by the disk cache and for
    /// coalescing network requests).
    public var dataCacheKey: String {
        url?.absoluteString ?? ""
    }

    /// Key identifying the final decoded and processed image (used by the
    /// memory cache).
    public var imageCacheKey: String {
        var key = dataCacheKey

        if let targetSize {
            key += "|size=\(Self.format(targetSize.width))x\(Self.format(targetSize.height))"
            key += ",mode=\(contentMode.rawValue)"
        }

        if scale != 1 || targetSize != nil {
            key += "|scale=\(Self.format(scale))"
        }

        if !processors.isEmpty {
            key += "|processors=" + processors.map(\.identifier).joined(separator: ",")
        }

        return key
    }

    private static func format(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(Double(rounded))
    }
}

extension ImageRequest: ExpressibleByStringLiteral {
    /// Creates a request from a URL string literal. Invalid literals produce
    /// a request that fails when loaded.
    public init(stringLiteral value: String) {
        self.init(
            urlRequest: URLRequest(
                url: URL(string: value) ?? URL(fileURLWithPath: "/dev/null")
            )
        )
    }
}
