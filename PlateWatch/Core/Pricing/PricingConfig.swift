import Foundation

/// Product IDs + StoreKit config + 3.1.2(a) disclosure strings. Mirror
/// these in `Configuration.storekit` (local sandbox) and in App Store Connect
/// IAP records.
///
/// Pricing locked 2026-06-11:
///   - Monthly: $7.99, no trial.
///   - Annual:  $49.99, with 7-day FREE_TRIAL intro offer.
/// Install-time entitlement (7 days) is the canonical trial mechanism per
/// Subscriptions playbook Rule 4; the ASC `introductoryOffer` on the annual
/// product is the billing-side benefit users see at the StoreKit purchase
/// sheet.
enum PricingConfig {
    static let monthlyProductId = "com.plateaware.app.monthly"
    static let yearlyProductId  = "com.plateaware.app.yearly"

    static let allProductIds: [String] = [
        monthlyProductId,
        yearlyProductId,
    ]

    /// Fallback prices shown when StoreKit can't reach Apple (offline,
    /// simulator without Configuration.storekit). Always overridden by the
    /// real product price when StoreKit returns it.
    static let priceFallback: [String: String] = [
        monthlyProductId: "$7.99",
        yearlyProductId:  "$49.99",
    ]

    /// Headline benefits shown on the paywall. Lives here so tests and the
    /// settings status row can read the same source.
    ///
    /// "Privacy-preferring route" wording locked by the risk profile §0
    /// privacy-route subsection — copy MUST NOT use "avoid", "evade",
    /// "bypass", "around", "detect", "ticket", "police", "officer".
    static let benefits: [String] = [
        "Camera Ahead proximity alerts",
        "Pre-drive route scan with density score",
        "Privacy-preferring route — low-surveillance alternatives highlighted",
        "Saved routes synced across devices",
        "Offline state packs (download once, no roaming data)",
        "Faster sync + report history",
    ]

    /// Six 3.1.2(a) auto-renew disclosures + Rule 3 forfeiture sentence
    /// (mandatory because the annual product has a free trial). Apple forbids
    /// paraphrasing — keep verbatim on the paywall.
    enum Disclosures {
        static let payment        = "Payment will be charged to your Apple ID account at confirmation of purchase."
        static let autoRenew      = "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
        static let renewalCharge  = "Your account will be charged for renewal within 24 hours prior to the end of the current period."
        static let manage         = "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase."
        static let freeTrial      = "On first install, new users get full Pro access free for 7 days. Trial ends automatically; no card required during trial."
        static let trialForfeit   = "If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends."
    }

    /// Terms / Privacy URLs surfaced from the paywall + settings.
    enum Links {
        static let terms   = URL(string: "https://has-deploy.github.io/platewatch/terms.html")!
        static let privacy = URL(string: "https://has-deploy.github.io/platewatch/privacy.html")!
    }
}
