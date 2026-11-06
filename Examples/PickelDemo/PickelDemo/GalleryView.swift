//
//  GalleryView.swift
//  PickelDemo
//
//  SwiftUI: a grid of thumbnails with placeholder and failure views.
//

import Pickel
import SwiftUI

struct GalleryView: View {
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(SamplePhotos.landscapes) { photo in
                        NavigationLink(value: photo) {
                            thumbnail(for: photo)
                        }
                    }
                }
                Text("Photos from Unsplash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .navigationTitle("Gallery")
            .navigationDestination(for: Photo.self) { photo in
                PhotoDetailView(photo: photo)
            }
        }
    }

    private func thumbnail(for photo: Photo) -> some View {
        // `targetSize` makes Pickel shrink the 1600px image to the cell size
        // while decoding, which keeps memory use low in long grids.
        PickelImage(url: photo.url, targetSize: CGSize(width: 120, height: 120)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
        } failure: {
            Rectangle()
                .fill(.quaternary)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 120)
        .clipped()
        .contentShape(Rectangle())
    }
}

struct PhotoDetailView: View {
    let photo: Photo

    var body: some View {
        // The phase-based initializer gives full control over each state.
        PickelImage(url: photo.url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            case .failure(let error):
                ContentUnavailableView(
                    "Couldn't load image",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(photo.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
