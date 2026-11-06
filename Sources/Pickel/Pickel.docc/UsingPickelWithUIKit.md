# Using Pickel with UIKit

Load remote images into any `UIImageView`.

## Show an image

Call `setImage(with:)` on the image view's `pickel` property:

```swift
import Pickel
import UIKit

imageView.pickel.setImage(with: url)
```

Pickel downloads the image in the background, caches it, and fades it in when it's ready. If the image view has already been laid out, the image is shrunk to the image view's size to save memory.

## Placeholder and failure images

```swift
imageView.pickel.setImage(
    with: url,
    placeholder: UIImage(named: "placeholder"),   // shown while loading
    failureImage: UIImage(named: "broken")        // shown if loading fails
)
```

- The placeholder appears right away, then fades into the real image.
- If the image is already cached, it shows instantly and the placeholder is skipped.
- If loading fails and you didn't pass a `failureImage`, the placeholder stays.
- With no placeholder, the image view is cleared while loading.

The placeholder uses the image view's `contentMode`, so pick one that suits both, for example `.scaleAspectFill` for photos.

## Use it in table and collection view cells

Starting a new load on an image view cancels the previous one, so a reused cell never shows the wrong image. You can also cancel as soon as the cell is reused:

```swift
final class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()

    func configure(with url: URL) {
        imageView.pickel.setImage(with: url, placeholder: UIImage(named: "placeholder"))
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.pickel.cancel()
    }
}
```

## Load images before they appear

Use ``ImagePrefetcher`` with your collection view's prefetching data source so images are ready before cells scroll into view:

```swift
let prefetcher = ImagePrefetcher()

func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    prefetcher.startPrefetching(with: indexPaths.map { items[$0.item].imageURL })
}

func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    prefetcher.stopPrefetching(with: indexPaths.map { items[$0.item].imageURL })
}
```

## Round corners and other effects

```swift
imageView.pickel.setImage(with: url, processors: [.roundedCorners(radius: 12)])
```

## Know when loading finishes

```swift
imageView.pickel.setImage(with: url) { result in
    switch result {
    case .success(let image):
        print("Loaded \(image.size)")
    case .failure(let error):
        print("Failed: \(error)")
    }
}
```

## See also

- <doc:UsingPickelWithSwiftUI>
- ``PickelImageViewLoader``
- ``ImagePrefetcher``
