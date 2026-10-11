//
//  ImagePipeline.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

actor ImagePipeline {
    private struct InflightRequest {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [
            UUID: CheckedContinuation<Data, any Error>
        ]
    }
    
    private let downloader: any ImageDownloading
    
    private var inFlightRequests: [URL: InflightRequest] = [:]
    
    init(downloader: any ImageDownloading = ImageDownloader()) {
        self.downloader = downloader
    }
    
    func data(for url: URL) async throws -> Data {
        let waiterID = UUID()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                register(
                    url: url,
                    waiterID: waiterID,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(
                    waiterID,
                    for: url
                )
            }
        }
    }
    
    private func register(
        url: URL,
        waiterID: UUID,
        continuation: CheckedContinuation<Data, any Error>
    ) {
        if var request = inFlightRequests[url] {
            request.waiters[waiterID] = continuation
            inFlightRequests[url] = request
            return
        }
        
        let requestID = UUID()
        
        let task = Task {
            let result: Result<Data, any Error>
            
            do {
                result = .success(
                    try await downloader.download(from: url)
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
            id: requestID, task: task, waiters: [waiterID: continuation]
        )
    }
    
    private func cancelWaiter(
        _ waiterID: UUID,
        for url: URL
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
        for url: URL,
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
