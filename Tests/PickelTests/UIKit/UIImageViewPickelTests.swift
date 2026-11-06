//
//  UIImageViewPickelTests.swift
//  Pickel
//

#if canImport(UIKit)
import UIKit
import XCTest
@testable import Pickel

@MainActor
final class UIImageViewPickelTests: XCTestCase {
    private let url = URL(string: "https://example.com/a.png")!

    private func makePipeline() async -> (ImagePipeline, StubDownloader) {
        let downloader = StubDownloader()
        await downloader.setResponse(.success(TestImages.png(width: 300, height: 300)), for: url)
        let pipeline = ImagePipeline(
            configuration: .init(downloader: downloader, memoryCache: MemoryCache(), diskCache: nil)
        )
        return (pipeline, downloader)
    }

    func testLoadsImageIntoImageView() async throws {
        let (pipeline, _) = await makePipeline()
        let imageView = UIImageView()

        let task = imageView.pickel.setImage(with: url, transition: .none, pipeline: pipeline)
        await task?.value

        XCTAssertEqual(imageView.image?.cgImage?.width, 300)
    }

    func testDownsamplesToBounds() async throws {
        let (pipeline, _) = await makePipeline()
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))

        let task = imageView.pickel.setImage(with: url, transition: .none, pipeline: pipeline)
        await task?.value

        let scale = imageView.traitCollection.displayScale
        XCTAssertEqual(imageView.image?.cgImage?.width, Int(50 * scale))
    }

    func testShowsPlaceholderWhileLoading() async {
        let (pipeline, _) = await makePipeline()
        let imageView = UIImageView()
        let placeholder = UIImage()

        let task = imageView.pickel.setImage(with: url, placeholder: placeholder, pipeline: pipeline)

        XCTAssertTrue(imageView.image === placeholder)
        task?.cancel()
    }

    func testMemoryCacheHitIsSynchronous() async throws {
        let (pipeline, _) = await makePipeline()
        _ = try await pipeline.image(for: url)
        let imageView = UIImageView()

        let task = imageView.pickel.setImage(with: url, pipeline: pipeline)

        XCTAssertNil(task)
        XCTAssertNotNil(imageView.image)
    }

    func testNewLoadCancelsPreviousOne() async throws {
        let (pipeline, downloader) = await makePipeline()
        let other = URL(string: "https://example.com/b.png")!
        await downloader.setResponse(.success(TestImages.png(width: 10, height: 10)), for: other)
        let imageView = UIImageView()

        let first = imageView.pickel.setImage(with: url, transition: .none, pipeline: pipeline)
        let second = imageView.pickel.setImage(with: other, transition: .none, pipeline: pipeline)
        await first?.value
        await second?.value

        XCTAssertEqual(imageView.image?.cgImage?.width, 10)
    }

    func testFailureImageIsShownOnError() async {
        let (pipeline, downloader) = await makePipeline()
        await downloader.setResponse(.failure(URLError(.badServerResponse)), for: url)
        let imageView = UIImageView()
        let failure = UIImage()
        var receivedError: (any Error)?

        let task = imageView.pickel.setImage(
            with: url,
            failureImage: failure,
            pipeline: pipeline
        ) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
        }
        await task?.value

        XCTAssertTrue(imageView.image === failure)
        XCTAssertNotNil(receivedError)
    }
}
#endif
