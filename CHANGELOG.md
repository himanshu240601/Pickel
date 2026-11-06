# Changelog

## 0.1.0

First public release.

- `ImagePipeline` with memory cache, disk cache, coalesced downloads, downsampling and processing
- `ImageRequest` with target size, scale, processors, cache options and `URLRequest` support
- `MemoryCache` (NSCache based, cost limited) and `DiskCache` (LRU plus expiration)
- Processors: resize, rounded corners, circle
- `ImagePrefetcher`
- SwiftUI `PickelImage` view and `imagePipeline` environment value
- UIKit `UIImageView.pickel.setImage(with:)`
