import Foundation
import StoreKit

/// StoreKit 2 wrapper. Owns:
///   - Product fetch from ASC
///   - `purchase()` flow with verification
///   - `Transaction.updates` listener so refunds / out-of-band entitlement
///     changes propagate without restart
///   - Writing the resulting paid state to `UserEntitlement`
///
/// Read-only state is published via @MainActor @Published properties for
/// the paywall UI.
@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var lastError: String?

    private let entitlement: UserEntitlement
    private var updatesTask: Task<Void, Never>?

    init(entitlement: UserEntitlement = UserEntitlement()) {
        self.entitlement = entitlement
    }

    deinit {
        updatesTask?.cancel()
    }

    /// True iff the user can use Pro features now — paid sub active OR
    /// inside the install trial. THE read every gate uses. Never reads
    /// `entitlement.isPremium` in isolation.
    var isPro: Bool { entitlement.isEntitled() }

    var isInIntroTrial: Bool {
        !entitlement.isPremium && entitlement.installTrialActive()
    }

    var introTrialDaysRemaining: Int {
        entitlement.trialDaysRemaining()
    }

    /// Look up the StoreKit `Product.SubscriptionPeriod` for a product id.
    /// Used by the paywall to render the trial label on the annual card.
    func subscriptionPeriod(for productId: String) -> Product.SubscriptionPeriod? {
        products.first(where: { $0.id == productId })?.subscription?.subscriptionPeriod
    }

    /// Look up the introductory offer on a product. Used to surface the
    /// 7-day free trial copy on the annual card.
    func introductoryOffer(for productId: String) -> Product.SubscriptionOffer? {
        products.first(where: { $0.id == productId })?.subscription?.introductoryOffer
    }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handleVerifiedUpdate(update)
            }
        }
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: PricingConfig.allProductIds)
            self.products = PricingConfig.allProductIds.compactMap { id in
                fetched.first(where: { $0.id == id })
            }
        } catch {
            self.lastError = "Couldn't reach the App Store: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await applyTransaction(transaction)
                    await transaction.finish()
                    let isIntro: Bool = {
                        if #available(iOS 17.2, *) {
                            return transaction.offer?.type == .introductory
                        }
                        return false
                    }()
                    PortfolioAnalytics.shared.trackSubscriptionPurchase(
                        product: product,
                        transaction: transaction,
                        isPromotionalOffer: isIntro
                    )
                } else if case .unverified = verification {
                    lastError = "Purchase couldn't be verified. Please try again."
                    PortfolioAnalytics.shared.trackPaywallFailure(
                        productId: product.id,
                        reason: .verificationFailed
                    )
                }
            case .userCancelled:
                PortfolioAnalytics.shared.trackPaywallFailure(
                    productId: product.id,
                    reason: .userCanceled
                )
            case .pending:
                lastError = "Purchase is pending parental approval."
                PortfolioAnalytics.shared.trackPaywallFailure(
                    productId: product.id,
                    reason: .pending
                )
            @unknown default:
                lastError = "Unknown purchase result."
                PortfolioAnalytics.shared.trackPaywallFailure(
                    productId: product.id,
                    reason: .unknown
                )
            }
        } catch {
            lastError = error.localizedDescription
            PortfolioAnalytics.shared.trackPaywallFailure(
                productId: product.id,
                error: error
            )
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            PortfolioAnalytics.shared.track(PortfolioEvent.restoreCompleted, [:])
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
            PortfolioAnalytics.shared.track(PortfolioEvent.restoreFailed,
                                            ["reason": error.localizedDescription])
        }
    }

    func clearLastError() { lastError = nil }

    private func refreshEntitlements() async {
        var bestProductId: String?
        var bestExpiry: Date?
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               PricingConfig.allProductIds.contains(t.productID) {
                bestProductId = t.productID
                bestExpiry = t.expirationDate
            }
        }
        if let productId = bestProductId {
            entitlement.applyPaidEntitlement(productId: productId, expiresAt: bestExpiry)
        } else {
            entitlement.revokePaidEntitlement()
        }
        PortfolioAnalytics.shared.setEntitlement(
            isPremium: entitlement.isPremium,
            segment: entitlement.isPremium ? .premium :
                     (entitlement.installTrialActive() ? .trial : .free)
        )
        objectWillChange.send()
    }

    private func handleVerifiedUpdate(_ verification: VerificationResult<Transaction>) async {
        if case .verified(let t) = verification {
            await applyTransaction(t)
            await t.finish()
        }
    }

    private func applyTransaction(_ transaction: Transaction) async {
        guard PricingConfig.allProductIds.contains(transaction.productID) else { return }
        entitlement.applyPaidEntitlement(
            productId: transaction.productID,
            expiresAt: transaction.expirationDate
        )
        PortfolioAnalytics.shared.setEntitlement(
            isPremium: true,
            segment: .premium
        )
        objectWillChange.send()
    }
}
