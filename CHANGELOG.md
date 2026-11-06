# Changelog

All notable changes to this project are documented here. Pickel follows [Semantic Versioning](https://semver.org): breaking API changes only happen in a new major version.

## 1.0.0

First stable release. The public API is now stable.

- Everything from 0.1.0 and 0.2.0, with no API changes
- Tested on macOS and the iOS Simulator, and builds for iPhone hardware

## 0.2.0

- SwiftUI: `PickelImage(url:content:placeholder:failure:)` shows a separate view when loading fails
- Sample app in `Examples/PickelDemo` showing SwiftUI, UIKit, processors, prefetching and caching

## 0.1.0

First public release.

- `ImagePipeline` with memory cache, disk cache, coalesced downloads, downsampling and processing
- `ImageRequest` with target size, scale, processors, cache options and `URLRequest` support
- `MemoryCache` (NSCache based, cost limited) and `DiskCache` (LRU plus expiration)
- Processors: resize, rounded corners, circle
- `ImagePrefetcher`
- SwiftUI `PickelImage` view and `imagePipeline` environment value
- UIKit `UIImageView.pickel.setImage(with:)`
- Security: only `http`/`https`/`file` URLs are loaded, responses over 50 MB are rejected, and images are capped at 24 megapixels when decoded
