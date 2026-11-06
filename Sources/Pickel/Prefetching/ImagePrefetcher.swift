//
//  ImagePrefetcher.swift
//  Pickel
//

import Foundation

/// Loads images ahead of time so they are already cached when displayed.
///
/// Designed for `UICollectionViewDataSourcePrefetching` /
/// `UITableViewDataSourcePrefetching` and SwiftUI `onAppear` hooks: all
/// methods are synchronous and safe to call from any thread.
///
/// ```swift
/// let prefetcher = ImagePrefetcher()
/// prefetcher.startPrefetching(with: upcomingURLs)
/// prefetcher.stopPrefetching(with: offscreenURLs)
/// ```
public final class ImagePrefetcher: @unchecked Sendable {
    private let pipeline: ImagePipeline
    private let maxConcurrentRequests: Int
    private let priority: TaskPriority

    private let lock = NSLock()
    private var pending: [(key: String, request: ImageRequest)] = []
    private var running: [String: Task<Void, Never>] = [:]

    /// Creates a prefetcher.
    ///
    /// - Parameters:
    ///   - pipeline: Pipeline used to load images.
    ///   - maxConcurrentRequests: Maximum number of simultaneous loads.
    ///   - priority: Priority of prefetch tasks.
    public init(
        pipeline: ImagePipeline = .shared,
        maxConcurrentRequests: Int = 2,
        priority: TaskPriority = .utility
    ) {
        self.pipeline = pipeline
        self.maxConcurrentRequests = max(1, maxConcurrentRequests)
        self.priority = priority
    }

    deinit {
        for task in running.values {
            task.cancel()
        }
    }

    /// Starts loading the given URLs.
    public func startPrefetching(with urls: [URL]) {
        startPrefetching(with: urls.map { ImageRequest(url: $0) })
    }

    /// Starts loading the given requests. Requests already pending or
    /// running are ignored.
    public func startPrefetching(with requests: [ImageRequest]) {
        lock.lock()
        for request in requests {
            let key = request.imageCacheKey

            guard pipeline.cachedImage(for: request) == nil,
                  running[key] == nil,
                  !pending.contains(where: { $0.key == key })
            else {
                continue
            }

            pending.append((key, request))
        }
        startNextIfPossible()
        lock.unlock()
    }

    /// Cancels loading of the given URLs.
    public func stopPrefetching(with urls: [URL]) {
        stopPrefetching(with: urls.map { ImageRequest(url: $0) })
    }

    /// Cancels loading of the given requests.
    public func stopPrefetching(with requests: [ImageRequest]) {
        let keys = Set(requests.map(\.imageCacheKey))

        lock.lock()
        pending.removeAll { keys.contains($0.key) }
        for key in keys {
            running.removeValue(forKey: key)?.cancel()
        }
        startNextIfPossible()
        lock.unlock()
    }

    /// Cancels all pending and running prefetches.
    public func stopPrefetching() {
        lock.lock()
        pending.removeAll()
        let tasks = running.values
        running.removeAll()
        lock.unlock()

        for task in tasks {
            task.cancel()
        }
    }

    /// Number of prefetches waiting to start or currently running.
    public var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pending.count + running.count
    }

    // MARK: - Private

    /// Must be called with `lock` held.
    private func startNextIfPossible() {
        while running.count < maxConcurrentRequests, !pending.isEmpty {
            let (key, request) = pending.removeFirst()
            let pipeline = self.pipeline

            running[key] = Task(priority: priority) { [weak self] in
                _ = try? await pipeline.image(for: request)
                self?.didFinish(key: key)
            }
        }
    }

    private func didFinish(key: String) {
        lock.lock()
        running.removeValue(forKey: key)
        startNextIfPossible()
        lock.unlock()
    }
}
