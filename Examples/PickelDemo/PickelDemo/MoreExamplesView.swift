//
//  MoreExamplesView.swift
//  PickelDemo
//
//  Processors, error handling, async/await and cache controls.
//

import Pickel
import SwiftUI

struct MoreExamplesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Processors") {
                    ProcessorsRow()
                }

                Section {
                    FailureExample()
                } header: {
                    Text("Error handling")
                } footer: {
                    Text("This URL doesn't exist, so the failure view is shown.")
                }

                Section("async/await") {
                    AsyncAwaitExample()
                }

                Section("Cache") {
                    CacheControls()
                }
            }
            .navigationTitle("More")
        }
    }
}

// MARK: - Processors

private struct ProcessorsRow: View {
    private let url = SamplePhotos.landscapes[2].url
    private let size = CGSize(width: 80, height: 80)

    var body: some View {
        HStack(spacing: 16) {
            // Processors run in order: crop to a square first, then shape it.
            example("Square", processors: [.resize(size: size, crop: true)])
            example("Rounded", processors: [.resize(size: size, crop: true), .roundedCorners(radius: 16)])
            example("Circle", processors: [.circle])
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func example(_ title: String, processors: [any ImageProcessing]) -> some View {
        VStack {
            PickelImage(url: url, targetSize: size, processors: processors) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: size.width, height: size.height)
            .clipped()

            Text(title).font(.caption)
        }
    }
}

// MARK: - Failure

private struct FailureExample: View {
    @State private var attempt = 0

    var body: some View {
        HStack(spacing: 16) {
            PickelImage(url: SamplePhotos.brokenURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 80, height: 80)
            // Changing the id recreates the view, which retries the load.
            .id(attempt)

            Button("Retry") { attempt += 1 }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - async/await

private struct AsyncAwaitExample: View {
    @State private var image: UIImage?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(isLoading ? "Loading…" : "Load with ImagePipeline") {
                Task { await load() }
            }
            .disabled(isLoading)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Use the pipeline directly when you need a UIImage yourself.
            image = try await ImagePipeline.shared.image(for: SamplePhotos.landscapes[12].url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Cache

private struct CacheControls: View {
    @State private var diskSize: Int?

    var body: some View {
        LabeledContent("Disk cache") {
            Text(diskSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "…")
        }
        .task { await refresh() }

        Button("Refresh size") {
            Task { await refresh() }
        }

        Button("Clear all caches", role: .destructive) {
            Task {
                await ImagePipeline.shared.removeAllCachedImages()
                await refresh()
            }
        }
    }

    private func refresh() async {
        diskSize = await ImagePipeline.shared.configuration.diskCache?.totalSize() ?? 0
    }
}
