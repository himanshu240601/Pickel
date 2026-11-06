//
//  DiskCache.swift
//  Pickel
//

import CryptoKit
import Foundation

/// A size- and age-limited cache of raw image data on disk.
///
/// Each entry is stored in its own file named after the SHA-256 hash of its
/// key. Least recently used entries are removed when the cache grows beyond
/// ``sizeLimit``, and entries older than ``expiration`` are discarded.
public actor DiskCache {
    /// Directory holding the cached files.
    public nonisolated let directory: URL

    /// Maximum total size of the cache in bytes.
    public let sizeLimit: Int

    /// Maximum age of an entry. `nil` means entries never expire.
    public let expiration: TimeInterval?

    private let fileManager = FileManager.default
    private var writesSinceLastSweep = 0
    private var hasSweptOnce = false

    /// Number of writes between automatic sweeps.
    private let sweepInterval = 20

    /// Creates a disk cache.
    ///
    /// - Parameters:
    ///   - name: Name of the sub-directory inside the user caches directory.
    ///   - directory: Explicit location for the cache. Overrides `name`.
    ///   - sizeLimit: Maximum total size in bytes. Defaults to 150 MB.
    ///   - expiration: Maximum entry age. Defaults to 7 days.
    public init(
        name: String = "com.pickel.images",
        directory: URL? = nil,
        sizeLimit: Int = 150 * 1024 * 1024,
        expiration: TimeInterval? = 7 * 24 * 60 * 60
    ) {
        let resolved = directory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)

        self.directory = resolved
        self.sizeLimit = sizeLimit
        self.expiration = expiration

        try? FileManager.default.createDirectory(
            at: resolved,
            withIntermediateDirectories: true
        )
    }

    /// Returns the data stored for `key`, or `nil` if missing or expired.
    public func data(forKey key: String) -> Data? {
        let url = fileURL(forKey: key)

        guard let attributes = try? fileManager.attributesOfItem(
            atPath: url.path
        ) else {
            return nil
        }

        if isExpired(attributes) {
            try? fileManager.removeItem(at: url)
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        // Mark as recently used for LRU trimming.
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )

        return data
    }

    /// Whether an unexpired entry exists for `key`.
    public func containsData(forKey key: String) -> Bool {
        let url = fileURL(forKey: key)

        guard let attributes = try? fileManager.attributesOfItem(
            atPath: url.path
        ) else {
            return false
        }

        return !isExpired(attributes)
    }

    /// Stores `data` for `key`.
    public func store(_ data: Data, forKey key: String) {
        let url = fileURL(forKey: key)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }

        writesSinceLastSweep += 1

        if !hasSweptOnce || writesSinceLastSweep >= sweepInterval {
            sweep()
        }
    }

    /// Removes the entry for `key`.
    public func removeData(forKey key: String) {
        try? fileManager.removeItem(at: fileURL(forKey: key))
    }

    /// Removes every entry.
    public func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    /// Total size in bytes of all cached files.
    public func totalSize() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    /// Removes expired entries, then least recently used entries until the
    /// cache is below 80% of ``sizeLimit``.
    public func sweep() {
        writesSinceLastSweep = 0
        hasSweptOnce = true

        var entries = entries()

        if let expiration {
            let cutoff = Date().addingTimeInterval(-expiration)

            entries.removeAll { entry in
                guard entry.created < cutoff else {
                    return false
                }

                try? fileManager.removeItem(at: entry.url)
                return true
            }
        }

        var totalSize = entries.reduce(0) { $0 + $1.size }

        guard totalSize > sizeLimit else {
            return
        }

        let target = Int(Double(sizeLimit) * 0.8)

        for entry in entries.sorted(by: { $0.lastUsed < $1.lastUsed }) {
            guard totalSize > target else {
                break
            }

            if (try? fileManager.removeItem(at: entry.url)) != nil {
                totalSize -= entry.size
            }
        }
    }

    // MARK: - Private

    private struct FileEntry {
        let url: URL
        let size: Int
        let created: Date
        let lastUsed: Date
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
        .creationDateKey,
        .contentModificationDateKey
    ]

    private func entries() -> [FileEntry] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Self.resourceKeys,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(
                forKeys: Set(Self.resourceKeys)
            ), values.isRegularFile == true else {
                return nil
            }

            let lastUsed = values.contentModificationDate ?? .distantPast

            return FileEntry(
                url: url,
                size: values.totalFileAllocatedSize ?? values.fileSize ?? 0,
                created: values.creationDate ?? lastUsed,
                lastUsed: lastUsed
            )
        }
    }

    private func isExpired(_ attributes: [FileAttributeKey: Any]) -> Bool {
        guard let expiration,
              let created = attributes[.creationDate] as? Date
        else {
            return false
        }

        return Date().timeIntervalSince(created) > expiration
    }

    nonisolated func fileURL(forKey key: String) -> URL {
        directory.appendingPathComponent(Self.fileName(forKey: key))
    }

    nonisolated static func fileName(forKey key: String) -> String {
        SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
