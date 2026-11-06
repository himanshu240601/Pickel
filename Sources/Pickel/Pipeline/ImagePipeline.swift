//
//  ImagePipeline.swift
//  Pickel
//

import CoreGraphics
import Foundation

/// Loads images: memory cache → disk cache → network, then decodes,
/// downsamples and processes them off the main thread.
///
/// Concurrent requests for the same URL share a single download, and the
/// download is cancelled only when every caller waiting on it is cancelled.
///
/// ```swift
/// let image = try await ImagePipeline.shared.image(for: url)
/// ```
public final class ImagePipeline: Sendable {
    /// Pipeline dependencies.
    public struct Configuration: Sendable {
        /// Fetches data from the network.
        public var downloader: any ImageDownloading
        /// Cache for decoded images. `nil` disables memory caching.
        public var memoryCache: MemoryCache?
        /// Cache for original image data. `nil` disables disk caching.
        public var diskCache: DiskCache?

        public init(
            downloader: any ImageDownloading = ImageDownloader(),
            memoryCache: MemoryCache? = MemoryCache(),
            diskCache: DiskCache? = DiskCache()
        ) {
            self.downloader = downloader
            self.memoryCache = memoryCache
            self.diskCache = diskCache
        }
    }

    /// The default pipeline used by Pickel's SwiftUI and UIKit APIs.
    public static let shared = ImagePipeline()

    public let configuration: Configuration

    private let dataLoader: ImageDataLoader
    private let decoder = ImageDecoder()

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.dataLoader = ImageDataLoader(downloader: configuration.downloader)
    }

    // MARK: - Loading

    /// Loads the image at `url`.
    public func image(for url: URL) async throws -> PlatformImage {
        try await image(for: ImageRequest(url: url))
    }

    /// Loads the image described by `request`.
    ///
    /// - Throws: `CancellationError` if the task is cancelled,
    ///   ``ImagePipelineError``, ``ImageDownloaderError``, `URLError`,
    ///   ``ImageDecodingError`` or ``ImageProcessingError``.
    public func image(for request: ImageRequest) async throws -> PlatformImage {
        let options = request.options

        if !options.contains(.disableMemoryCacheReads),
           let cached = cachedImage(for: request) {
            return cached
        }

        guard let url = request.url else {
            throw ImagePipelineError.missingURL
        }

        let dataKey = request.dataCacheKey
        let diskCache = url.isFileURL ? nil : configuration.diskCache

        var data: Data?
        if let diskCache, !options.contains(.disableDiskCacheReads) {
            data = await diskCache.data(forKey: dataKey)
        }

        let isFromNetwork = data == nil

        if isFromNetwork {
            if options.contains(.returnCacheDataDontLoad) {
                throw ImagePipelineError.cacheMiss
            }

            data = try await dataLoader.data(
                for: request.urlRequest,
                key: dataKey
            )
        }

        try Task.checkCancellation()

        let image: PlatformImage
        do {
            image = try makeImage(from: data ?? Data(), request: request)
        } catch let error as ImageDecodingError {
            // Don't keep undecodable data around.
            if !isFromNetwork, let diskCache {
                await diskCache.removeData(forKey: dataKey)
            }
            throw error
        }

        if isFromNetwork,
           let diskCache,
           let data,
           !options.contains(.disableDiskCacheWrites) {
            Task.detached(priority: .utility) {
                await diskCache.store(data, forKey: dataKey)
            }
        }

        if !options.contains(.disableMemoryCacheWrites) {
            configuration.memoryCache?.setImage(
                image,
                forKey: request.imageCacheKey
            )
        }

        return image
    }

    /// Decodes and processes `data` according to `request`.
    func makeImage(
        from data: Data,
        request: ImageRequest
    ) throws -> PlatformImage {
        var cgImage = try decoder.decode(
            data,
            targetSize: request.targetSize,
            scale: request.scale,
            contentMode: request.contentMode
        )

        for processor in request.processors {
            try Task.checkCancellation()

            guard let processed = processor.process(
                cgImage,
                scale: request.scale
            ) else {
                throw ImageProcessingError.processingFailed(
                    identifier: processor.identifier
                )
            }

            cgImage = processed
        }

        return PlatformImage.make(cgImage: cgImage, scale: request.scale)
    }

    // MARK: - Cache access

    /// Returns the image for `request` from the memory cache, synchronously.
    public func cachedImage(for request: ImageRequest) -> PlatformImage? {
        configuration.memoryCache?.image(forKey: request.imageCacheKey)
    }

    /// Returns the image for `url` from the memory cache, synchronously.
    public func cachedImage(for url: URL) -> PlatformImage? {
        cachedImage(for: ImageRequest(url: url))
    }

    /// Removes the cached image for `request` from memory, and its original
    /// data from disk.
    public func removeCachedImage(for request: ImageRequest) async {
        configuration.memoryCache?.removeImage(forKey: request.imageCacheKey)
        await configuration.diskCache?.removeData(forKey: request.dataCacheKey)
    }

    /// Removes every image from the memory and disk caches.
    public func removeAllCachedImages() async {
        configuration.memoryCache?.removeAll()
        await configuration.diskCache?.removeAll()
    }
}
