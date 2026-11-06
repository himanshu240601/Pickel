//
//  ImageDataLoader.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

private final class WaiterCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

/// Fetches image data and coalesces concurrent requests for the same key
/// into a single download. The download is cancelled only when every caller
/// waiting on it has been cancelled.
actor ImageDataLoader {
    private struct InflightRequest {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [
            UUID: CheckedContinuation<Data, any Error>
        ]
    }
    
    private let downloader: any ImageDownloading
    
    private var inFlightRequests: [String: InflightRequest] = [:]

    
    init(downloader: any ImageDownloading = ImageDownloader()) {
        self.downloader = downloader
    }
    
    func hasInFlightRequest(for url: URL) -> Bool {
        inFlightRequests[url.absoluteString] != nil
    }
    
    func waiterCount(for url: URL) -> Int {
        inFlightRequests[url.absoluteString]?.waiters.count ?? 0
    }

    func data(for url: URL) async throws -> Data {
        try await data(for: URLRequest(url: url), key: url.absoluteString)
    }
    
    func data(for request: URLRequest, key url: String) async throws -> Data {
        let waiterID = UUID()
        let cancellationState = WaiterCancellationState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                register(
                    request: request,
                    url: url,
                    waiterID: waiterID,
                    cancellationState: cancellationState,
                    continuation: continuation
                )
            }
        } onCancel: {
            cancellationState.cancel()

            Task {
                await self.cancelWaiter(
                    waiterID,
                    for: url
                )
            }
        }
    }
    
    private func register(
        request urlRequest: URLRequest,
        url: String,
        waiterID: UUID,
        cancellationState: WaiterCancellationState,
        continuation: CheckedContinuation<Data, any Error>
    ) {
        guard !cancellationState.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
        }
        
        if var request = inFlightRequests[url] {
            request.waiters[waiterID] = continuation
            inFlightRequests[url] = request

            if cancellationState.isCancelled {
                cancelWaiter(waiterID, for: url)
            }

            return
        }
        
        let requestID = UUID()
        
        let task = Task {
            let result: Result<Data, any Error>
            
            do {
                result = .success(
                    try await downloader.download(urlRequest)
                )
            } catch {
                result = .failure(error)
            }
            
            finishRequest(
                for: url,
                requestID: requestID,
                result: result
            )
        }
        
        inFlightRequests[url] = InflightRequest(
            id: requestID,
            task: task,
            waiters: [waiterID: continuation]
        )

        if cancellationState.isCancelled {
            cancelWaiter(waiterID, for: url)
        }
    }
    
    
    private func cancelWaiter(
        _ waiterID: UUID,
        for url: String
    ) {
        guard var request = inFlightRequests[url],
              let continuation = request.waiters.removeValue(
                  forKey: waiterID
              )
        else {
            return
        }

        continuation.resume(throwing: CancellationError())

        if request.waiters.isEmpty {
            inFlightRequests[url] = nil
            request.task.cancel()
        } else {
            inFlightRequests[url] = request
        }
    }

    private func finishRequest(
        for url: String,
        requestID: UUID,
        result: Result<Data, any Error>
    ) {
        guard let request = inFlightRequests[url],
              request.id == requestID
        else {
            return
        }

        inFlightRequests[url] = nil

        for continuation in request.waiters.values {
            switch result {
            case .success(let data):
                continuation.resume(returning: data)

            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
