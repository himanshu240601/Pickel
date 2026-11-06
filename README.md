# Pickel

**Images, without the pickle.**

Pickel is a lightweight image loading library for iOS, built entirely on Swift concurrency. It loads remote images into SwiftUI and UIKit with memory and disk caching, request coalescing, downsampling and image processing. It has no dependencies.

## Features

- **SwiftUI**: `PickelImage`, an `AsyncImage`-style view backed by a real cache.
- **UIKit**: `imageView.pickel.setImage(with:)`, safe to use in reused cells.
- **Two-level cache**: an in-memory cache of decoded images (limited by cost, cleared on memory warnings) and an on-disk cache of original data (LRU trimming plus expiration).
- **Request coalescing**: concurrent requests for the same URL share one download. The download is cancelled only after every caller has cancelled.
- **Downsampling**: decodes straight to the display size with ImageIO, so a full-size bitmap never sits in memory.
- **Background decoding**: images are decoded eagerly off the main thread and EXIF orientation is applied.
- **Processors**: resize, rounded corners, circle, or your own.
- **Prefetching**: warms the caches before images scroll into view.
- **Swift 6**: compiles in strict concurrency mode, and the public types are `Sendable`.

## Requirements

- iOS 17+, macOS 14+, tvOS 17+, visionOS 1+
- Swift 6.0+ (Xcode 16+)

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies…** and enter:

```
https://github.com/himanshu240601/Pickel.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/himanshu240601/Pickel.git", from: "0.1.0")
],
targets: [
    .target(name: "MyApp", dependencies: ["Pickel"])
]
```

## Usage

### SwiftUI

```swift
import Pickel
import SwiftUI

struct Avatar: View {
    let url: URL?

    var body: some View {
        PickelImage(
            url: url,
            targetSize: CGSize(width: 64, height: 64), // downsample to display size
            processors: [.circle]
        ) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ProgressView()
        }
        .frame(width: 64, height: 64)
    }
}
```

To handle every phase yourself:

```swift
PickelImage(url: url, transaction: Transaction(animation: .easeIn)) { phase in
    switch phase {
    case .empty:
        Color.gray.opacity(0.2)
    case .success(let image):
        image.resizable().scaledToFit()
    case .failure:
        Image(systemName: "photo")
    }
}
```

Images already in memory appear immediately with no placeholder flash. Loading is cancelled when the view disappears or the URL changes.

To use a custom pipeline for a whole view hierarchy:

```swift
ContentView()
    .imagePipeline(myPipeline)
```

### UIKit

```swift
import Pickel

imageView.pickel.setImage(
    with: url,
    placeholder: UIImage(named: "placeholder"),
    failureImage: UIImage(named: "broken"),
    processors: [.roundedCorners(radius: 8)],
    transition: .fade(0.25)
)

// In prepareForReuse():
imageView.pickel.cancel()
```

When the image view has been laid out, the image is downsampled to its bounds and `contentMode`. Starting a new load on the same image view cancels the previous one automatically.

### Loading images directly

```swift
let image = try await ImagePipeline.shared.image(for: url)

let request = ImageRequest(
    url: url,
    targetSize: CGSize(width: 300, height: 200),
    contentMode: .aspectFit,
    scale: 3,
    processors: [.resize(size: CGSize(width: 300, height: 200), crop: true)]
)
let thumbnail = try await ImagePipeline.shared.image(for: request)
```

To set custom headers (for example for authentication), pass a `URLRequest`:

```swift
var urlRequest = URLRequest(url: url)
urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
let image = try await ImagePipeline.shared.image(for: ImageRequest(urlRequest: urlRequest))
```

### Cache options

```swift
ImageRequest(url: url, options: .reloadIgnoringCachedData) // skip cache reads, store fresh result
ImageRequest(url: url, options: .returnCacheDataDontLoad)  // cache only, never hit the network
ImageRequest(url: url, options: .disableCaching)           // no cache reads or writes
```

Managing caches:

```swift
let cached = ImagePipeline.shared.cachedImage(for: url)       // synchronous memory lookup
await ImagePipeline.shared.removeCachedImage(for: ImageRequest(url: url))
await ImagePipeline.shared.removeAllCachedImages()
```

### Configuration

```swift
let pipeline = ImagePipeline(configuration: .init(
    downloader: ImageDownloader(session: mySession),
    memoryCache: MemoryCache(costLimit: 100 * 1024 * 1024),
    diskCache: DiskCache(name: "avatars", sizeLimit: 50 * 1024 * 1024, expiration: 3 * 24 * 60 * 60)
))
```

Pass `nil` for `memoryCache` or `diskCache` to turn that cache off. To use a different networking stack, conform to `ImageDownloading`:

```swift
struct MyDownloader: ImageDownloading {
    func download(_ request: URLRequest) async throws -> Data { ... }
}
```

### Processors

Built-in processors are `.resize(size:contentMode:crop:upscale:)`, `.roundedCorners(radius:)` and `.circle`. Sizes and radii are given in points. To write your own:

```swift
struct Grayscale: ImageProcessing {
    var identifier: String { "com.myapp.grayscale" }

    func process(_ image: CGImage, scale: CGFloat) -> CGImage? {
        // return a transformed CGImage
    }
}
```

The `identifier` is part of the memory cache key, so it must be unique for each processor and each set of parameters.

### Prefetching

```swift
let prefetcher = ImagePrefetcher(maxConcurrentRequests: 2)

// UICollectionViewDataSourcePrefetching
func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    prefetcher.startPrefetching(with: indexPaths.map { items[$0.item].imageURL })
}

func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    prefetcher.stopPrefetching(with: indexPaths.map { items[$0.item].imageURL })
}
```

Prefetch the same request your view will display, with the same `targetSize` and processors, so the memory cache entry matches.

## How it works

```
request ─► memory cache ─hit─► image
              │ miss
              ▼
           disk cache ──hit──┐
              │ miss         │
              ▼              ▼
        coalesced download ─► decode + downsample ─► processors ─► memory cache ─► image
              └────────────── store original data in disk cache ◄─┘
```

The disk cache stores **original** data under the URL key. Different sizes or processor variants of one image therefore share a single download. The memory cache stores the **final** image under a key built from the URL, size, scale and processors.

## Limitations

- Animated GIF, APNG and WebP images decode to their first frame only.
- The disk cache ignores HTTP cache headers and uses its own expiration.

## License

Pickel is available under the MIT License. See [LICENSE](LICENSE).
