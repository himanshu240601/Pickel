//
//  PickelImage.swift
//  Pickel
//

import SwiftUI

/// A view that asynchronously loads and displays an image through an
/// ``ImagePipeline``.
///
/// Images already in the memory cache are shown immediately, without a
/// placeholder flash. Loading is cancelled when the view disappears or its
/// URL changes.
///
/// ```swift
/// PickelImage(url: user.avatarURL) { image in
///     image.resizable().scaledToFill()
/// } placeholder: {
///     ProgressView()
/// }
/// .frame(width: 64, height: 64)
/// ```
public struct PickelImage<Content: View>: View {
    private let makeRequest: (CGFloat) -> ImageRequest?
    private let transaction: Transaction
    private let content: (PickelImagePhase) -> Content

    @Environment(\.imagePipeline) private var pipeline
    @Environment(\.displayScale) private var displayScale

    @State private var loaded: LoadedPhase?

    private struct LoadedPhase {
        let key: String
        let phase: PickelImagePhase
    }

    /// Loads the image described by `request` and builds the view for each
    /// phase of the load.
    public init(
        request: ImageRequest?,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (PickelImagePhase) -> Content
    ) {
        self.makeRequest = { _ in request }
        self.transaction = transaction
        self.content = content
    }

    /// Loads the image at `url` and builds the view for each phase of the
    /// load.
    ///
    /// - Parameters:
    ///   - targetSize: Size in points the image is displayed at. When set,
    ///     the image is downsampled to that size (using the screen scale),
    ///     which greatly reduces memory use for large images.
    ///   - contentMode: How the image fits `targetSize` when downsampling.
    ///   - processors: Processors applied after decoding.
    public init(
        url: URL?,
        targetSize: CGSize? = nil,
        contentMode: ImageContentMode = .aspectFill,
        processors: [any ImageProcessing] = [],
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (PickelImagePhase) -> Content
    ) {
        self.makeRequest = { displayScale in
            url.map {
                ImageRequest(
                    url: $0,
                    targetSize: targetSize,
                    contentMode: contentMode,
                    scale: targetSize == nil ? 1 : displayScale,
                    processors: processors
                )
            }
        }
        self.transaction = transaction
        self.content = content
    }

    public var body: some View {
        let request = makeRequest(displayScale)

        content(phase(for: request))
            .task(id: request?.imageCacheKey) {
                await load(request)
            }
    }

    private func phase(for request: ImageRequest?) -> PickelImagePhase {
        guard let request else {
            return .empty
        }

        let key = request.imageCacheKey

        if let loaded, loaded.key == key {
            return loaded.phase
        }

        if !request.options.contains(.disableMemoryCacheReads),
           let cached = pipeline.cachedImage(for: request) {
            return .success(Image(platformImage: cached))
        }

        return .empty
    }

    private func load(_ request: ImageRequest?) async {
        guard let request else {
            return
        }

        let key = request.imageCacheKey

        if !request.options.contains(.disableMemoryCacheReads),
           let cached = pipeline.cachedImage(for: request) {
            loaded = LoadedPhase(key: key, phase: .success(Image(platformImage: cached)))
            return
        }

        let newPhase: PickelImagePhase
        do {
            newPhase = .success(
                try await loadSwiftUIImage(request, pipeline: pipeline)
            )
        } catch is CancellationError {
            return
        } catch {
            newPhase = .failure(error)
        }

        guard !Task.isCancelled else {
            return
        }

        withTransaction(transaction) {
            loaded = LoadedPhase(key: key, phase: newPhase)
        }
    }
}

extension PickelImage {
    /// Loads the image at `url`, showing `placeholder` until it is ready
    /// (and if loading fails).
    public init<I: View, P: View>(
        url: URL?,
        targetSize: CGSize? = nil,
        contentMode: ImageContentMode = .aspectFill,
        processors: [any ImageProcessing] = [],
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(
            url: url,
            targetSize: targetSize,
            contentMode: contentMode,
            processors: processors,
            transaction: transaction
        ) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }

    /// Loads the image described by `request`, showing `placeholder` until
    /// it is ready (and if loading fails).
    public init<I: View, P: View>(
        request: ImageRequest?,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(request: request, transaction: transaction) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }

    /// Loads the image at `url`, showing `placeholder` while loading and
    /// `failure` if loading fails.
    ///
    /// ```swift
    /// PickelImage(url: url) { image in
    ///     image.resizable()
    /// } placeholder: {
    ///     ProgressView()
    /// } failure: {
    ///     Image(systemName: "photo")
    /// }
    /// ```
    public init<I: View, P: View, F: View>(
        url: URL?,
        targetSize: CGSize? = nil,
        contentMode: ImageContentMode = .aspectFill,
        processors: [any ImageProcessing] = [],
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P,
        @ViewBuilder failure: @escaping () -> F
    ) where Content == _ConditionalContent<_ConditionalContent<I, F>, P> {
        self.init(
            url: url,
            targetSize: targetSize,
            contentMode: contentMode,
            processors: processors,
            transaction: transaction
        ) { phase in
            if let image = phase.image {
                content(image)
            } else if phase.error != nil {
                failure()
            } else {
                placeholder()
            }
        }
    }

    /// Loads the image at `url` and displays it as-is, with a grey
    /// placeholder while loading.
    public init(
        url: URL?,
        targetSize: CGSize? = nil,
        contentMode: ImageContentMode = .aspectFill,
        processors: [any ImageProcessing] = []
    ) where Content == _ConditionalContent<Image, Color> {
        self.init(
            url: url,
            targetSize: targetSize,
            contentMode: contentMode,
            processors: processors,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}

/// Loads and wraps the image off the main actor. `NSImage` is not
/// `Sendable` on every SDK, so only the `Sendable` SwiftUI `Image` is handed
/// back to the view.
private func loadSwiftUIImage(
    _ request: ImageRequest,
    pipeline: ImagePipeline
) async throws -> Image {
    Image(platformImage: try await pipeline.image(for: request))
}
