import Foundation
import GrowlAds

/// Drives `start()` then `bid(_:)` against an adapter and surfaces
/// the result for assertion.
public struct AdNetworkAdapterRunner {
    public enum Outcome {
        case bid(AdBid)
        case noFill
        case adapterError(AdAdapterError)
    }

    public let adapter: any AdNetworkAdapter

    public init(adapter: any AdNetworkAdapter) {
        self.adapter = adapter
    }

    public func run(_ request: AdBidRequest) async -> Outcome {
        do {
            try await adapter.start()
        } catch let error as AdAdapterError {
            return .adapterError(error)
        } catch {
            return .adapterError(.underlying(String(describing: error)))
        }

        do {
            if let bid = try await adapter.bid(request) {
                return .bid(bid)
            }
            return .noFill
        } catch let error as AdAdapterError {
            return .adapterError(error)
        } catch {
            return .adapterError(.underlying(String(describing: error)))
        }
    }
}
