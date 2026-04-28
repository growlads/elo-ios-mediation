import Foundation
import GrowlAds

/// Builder for `AdBidRequest` fixtures. Use named arguments to
/// override only the fields a test cares about.
///
/// Note: `AdBidRequest.messages` is `[ChatMessage]` and `context` is
/// `[ContextObject]` — the GrowlAds SDK types, not plain `[String]`.
public enum MockAdBidRequest {
    public static func make(
        adUnitId: String = "test-ad-unit",
        messages: [ChatMessage] = [],
        context: [ContextObject] = [],
        consent: AdConsent = MockAdConsent.allConsented,
        timeout: TimeInterval = 1.0
    ) -> AdBidRequest {
        AdBidRequest(
            messages: messages,
            context: context,
            adUnitId: adUnitId,
            consent: consent,
            timeout: timeout
        )
    }
}
