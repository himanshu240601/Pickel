//
//  MemoryCache.swift
//  Pickel
//

import CoreGraphics
import Foundation

/// A thread-safe, cost-limited in-memory cache of decoded images.
///
/// Backed by `NSCache`, so entries are evicted automatically under memory
/// pressure. On iOS, tvOS and visionOS the cache is also emptied when the
/// app receives a memory warning.
public final class MemoryCache: @unchecked Sendable {
    private final class Entry {
        let image: PlatformImage

        init(image: PlatformImage) {
            self.image = image
        }
    }

    private let cache = NSCache<NSString, Entry>()
    private var memoryWarningObserver: (any NSObjectProtocol)?

    /// Maximum total cost (approximate bytes of decoded bitmaps).
    public var costLimit: Int {
        get { cache.totalCostLimit }
        set { cache.totalCostLimit = newValue }
    }

    /// Maximum number of images kept. `0` means no limit.
    public var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }

    /// Creates a memory cache.
    ///
    /// - Parameters:
    ///   - costLimit: Maximum total size in bytes of decoded bitmaps.
    ///     Defaults to 20% of physical memory, capped at 512 MB.
    ///   - countLimit: Maximum number of images. `0` means no limit.
    public init(
        costLimit: Int = MemoryCache.defaultCostLimit,
        countLimit: Int = 0
    ) {
        cache.totalCostLimit = costLimit
        cache.countLimit = countLimit

        #if canImport(UIKit)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(
                "UIApplicationDidReceiveMemoryWarningNotification"
            ),
            object: nil,
            queue: nil
        ) { [cache] _ in
            cache.removeAllObjects()
        }
        #endif
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    /// 20% of physical memory, capped at 512 MB.
    public static var defaultCostLimit: Int {
        let physical = ProcessInfo.processInfo.physicalMemory
        let limit = min(physical / 5, 512 * 1024 * 1024)
        return Int(limit)
    }

    /// Returns the image stored for `key`, if any.
    public func image(forKey key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)?.image
    }

    /// Stores `image` for `key`. Its cost is the size of the decoded bitmap.
    public func setImage(_ image: PlatformImage, forKey key: String) {
        cache.setObject(
            Entry(image: image),
            forKey: key as NSString,
            cost: Self.cost(of: image)
        )
    }

    /// Removes the image stored for `key`.
    public func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// Removes every image.
    public func removeAll() {
        cache.removeAllObjects()
    }

    static func cost(of image: PlatformImage) -> Int {
        guard let cgImage = image.cgImage else {
            return 1
        }

        return max(1, cgImage.bytesPerRow * cgImage.height)
    }
}
