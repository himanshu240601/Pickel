//
//  DiskCacheTests.swift
//  Pickel
//

import Foundation
import XCTest
@testable import Pickel

final class DiskCacheTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PickelDiskCacheTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeSUT(
        sizeLimit: Int = 10 * 1024 * 1024,
        expiration: TimeInterval? = nil
    ) -> DiskCache {
        DiskCache(
            directory: directory,
            sizeLimit: sizeLimit,
            expiration: expiration
        )
    }

    func testStoresAndReadsData() async {
        let sut = makeSUT()
        let data = Data("hello".utf8)

        await sut.store(data, forKey: "https://example.com/a.png")

        let stored = await sut.data(forKey: "https://example.com/a.png")
        let contains = await sut.containsData(forKey: "https://example.com/a.png")
        XCTAssertEqual(stored, data)
        XCTAssertTrue(contains)
    }

    func testReturnsNilForMissingKey() async {
        let sut = makeSUT()

        let stored = await sut.data(forKey: "missing")
        XCTAssertNil(stored)
    }

    func testRemovesData() async {
        let sut = makeSUT()
        await sut.store(Data("x".utf8), forKey: "a")

        await sut.removeData(forKey: "a")

        let stored = await sut.data(forKey: "a")
        XCTAssertNil(stored)
    }

    func testRemoveAll() async {
        let sut = makeSUT()
        await sut.store(Data("x".utf8), forKey: "a")
        await sut.store(Data("y".utf8), forKey: "b")

        await sut.removeAll()

        let a = await sut.data(forKey: "a")
        let b = await sut.data(forKey: "b")
        let size = await sut.totalSize()
        XCTAssertNil(a)
        XCTAssertNil(b)
        XCTAssertEqual(size, 0)
    }

    func testExpiredEntriesAreNotReturned() async throws {
        let sut = makeSUT(expiration: 60)
        await sut.store(Data("x".utf8), forKey: "a")

        let url = sut.fileURL(forKey: "a")
        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-120)],
            ofItemAtPath: url.path
        )

        let stored = await sut.data(forKey: "a")
        XCTAssertNil(stored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSweepRemovesLeastRecentlyUsedEntriesOverLimit() async throws {
        let entrySize = 64 * 1024
        let sut = makeSUT(sizeLimit: entrySize * 3)
        let payload = Data(repeating: 1, count: entrySize)

        for key in ["old", "middle", "new"] {
            await sut.store(payload, forKey: key)
        }

        let now = Date()
        for (offset, key) in ["old", "middle", "new"].enumerated() {
            try FileManager.default.setAttributes(
                [.modificationDate: now.addingTimeInterval(Double(offset - 10))],
                ofItemAtPath: sut.fileURL(forKey: key).path
            )
        }

        await sut.store(payload, forKey: "newest")
        await sut.sweep()

        let old = await sut.containsData(forKey: "old")
        let newest = await sut.containsData(forKey: "newest")
        let size = await sut.totalSize()
        XCTAssertFalse(old)
        XCTAssertTrue(newest)
        XCTAssertLessThanOrEqual(size, entrySize * 3)
    }

    func testFileNameIsStableHash() {
        XCTAssertEqual(
            DiskCache.fileName(forKey: "abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}
