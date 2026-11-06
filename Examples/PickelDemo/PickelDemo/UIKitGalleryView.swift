//
//  UIKitGalleryView.swift
//  PickelDemo
//
//  UIKit: a collection view using `imageView.pickel.setImage(with:)` and
//  `ImagePrefetcher`.
//

import Pickel
import SwiftUI
import UIKit

/// Embeds the UIKit screen in the SwiftUI tab view.
struct UIKitGalleryView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: PhotoCollectionViewController())
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

final class PhotoCollectionViewController: UICollectionViewController, UICollectionViewDataSourcePrefetching {
    // Repeat the photos so there is something to scroll through.
    private let photos = Array(repeating: SamplePhotos.landscapes, count: 4).flatMap { $0 }
    private let prefetcher = ImagePrefetcher()

    init() {
        super.init(collectionViewLayout: Self.makeLayout())
    }

    /// Three square columns. Cells get their final size before they are
    /// configured, so Pickel downsamples images to the right size.
    private static func makeLayout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1 / 3), heightDimension: .fractionalHeight(1))
        )
        item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1 / 3)),
            subitems: [item]
        )

        return UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: group))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit"
        navigationController?.navigationBar.prefersLargeTitles = true
        collectionView.backgroundColor = .systemBackground
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        collectionView.prefetchDataSource = self
    }

    // MARK: Data source

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as! PhotoCell
        cell.configure(with: photos[indexPath.item])
        return cell
    }

    // MARK: Prefetching

    // Starts downloading images just before they scroll into view. The data
    // lands in the disk cache, so the cell's own request is fast.
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        prefetcher.startPrefetching(with: indexPaths.map { photos[$0.item].url })
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        prefetcher.stopPrefetching(with: indexPaths.map { photos[$0.item].url })
    }
}

final class PhotoCell: UICollectionViewCell {
    static let reuseIdentifier = "PhotoCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with photo: Photo) {
        // Shows the placeholder, loads the image (downsampled to the image
        // view's size) and fades it in. Any previous load is cancelled.
        imageView.pickel.setImage(
            with: photo.url,
            placeholder: Self.placeholder,
            failureImage: Self.failureImage
        )
    }

    // Placeholders are drawn as full tiles (an icon centred on a grey
    // background) so they look right with `.scaleAspectFill`.
    private static let placeholder = makeTile(symbol: "photo")
    private static let failureImage = makeTile(symbol: "exclamationmark.triangle")

    private static func makeTile(symbol: String) -> UIImage {
        let size = CGSize(width: 120, height: 120)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.secondarySystemBackground.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let configuration = UIImage.SymbolConfiguration(pointSize: 28)
            if let icon = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(
                    x: (size.width - icon.size.width) / 2,
                    y: (size.height - icon.size.height) / 2
                ))
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.pickel.cancel()
    }
}
