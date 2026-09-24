import SwiftUI
import StoreKit

/// Subscription paywall. Two cards (monthly + annual), all six 3.1.2(a)
/// disclosure sentences verbatim plus the Rule 3 forfeiture sentence
/// (required because the annual carries a trial), tappable Terms + Privacy
/// links, and a visible Restore Purchases button.
///
/// The annual card surfaces the 7-day free-trial label from the ASC intro
/// offer when StoreKit reports it; otherwise it falls back to the static
/// "7-day free trial" copy from PricingConfig.
struct PaywallView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var pendingProductId: String?
    @State private var purchaseAlertMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if appState.purchaseManager.isInIntroTrial {
                    trialBanner(daysLeft: appState.purchaseManager.introTrialDaysRemaining)
                }
                hero
                featureList
                installTrialInfo
                productCards
                if appState.purchaseManager.products.isEmpty {
                    pricingUnavailableNotice
                }
                actionButtons
                disclosuresSection
                footerLinks
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("PlateAware Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PortfolioAnalytics.shared.trackPaywallViewed(
                triggerSource: .settings,
                productsCount: appState.purchaseManager.products.count
            )
        }
        .onChange(of: appState.purchaseManager.lastError) { _, newValue in
            if let msg = newValue, !msg.isEmpty {
                purchaseAlertMessage = msg
            }
        }
        .alert(
            "Purchase problem",
            isPresented: Binding(
                get: { purchaseAlertMessage != nil },
                set: { if !$0 { purchaseAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                purchaseAlertMessage = nil
                appState.purchaseManager.clearLastError()
            }
        } message: {
            Text(purchaseAlertMessage ?? "")
        }
    }

    // MARK: - Sections

    private func trialBanner(daysLeft: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .foregroundStyle(.white)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your 7-day free Pro trial is active")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(daysLeft) \(daysLeft == 1 ? "day" : "days") left. Subscribe any time to keep Pro.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Text("PlateAware Pro")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Privacy-first roadway awareness, fully unlocked.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PricingConfig.benefits, id: \.self) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.primary)
                        .frame(width: 24)
                    Text(benefit)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(Theme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Install-time entitlement explainer. Kept OUT of the 3.1.2(a) block
    /// so the disclosure block stays the six Apple-required sentences plus
    /// the Rule 3 forfeiture sentence — nothing more.
    private var installTrialInfo: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "gift")
                .foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("New here? Your install includes 7 days of Pro.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(PricingConfig.Disclosures.freeTrial)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            ProductCard(
                productId: PricingConfig.monthlyProductId,
                title: "Monthly",
                period: "/ month",
                product: product(for: PricingConfig.monthlyProductId),
                trialLabel: nil,
                badge: nil,
                pendingProductId: $pendingProductId,
                onPurchase: purchase
            )
            ProductCard(
                productId: PricingConfig.yearlyProductId,
                title: "Annual",
                period: "/ year",
                product: product(for: PricingConfig.yearlyProductId),
                trialLabel: yearlyTrialLabel,
                badge: "7-DAY FREE TRIAL",
                pendingProductId: $pendingProductId,
                onPurchase: purchase
            )
        }
    }

    /// Surface the ASC intro offer on the annual card. Returns "7 days free,
    /// then $49.99/year" when StoreKit reports an introductoryOffer, or a
    /// static fallback when products haven't loaded yet. Mirrors the
    /// daysIn(_:) / yearlyFreeTrial helper pattern committed to the rest of
    /// the portfolio.
    private var yearlyTrialLabel: String? {
        guard let product = product(for: PricingConfig.yearlyProductId) else {
            return "7 days free, then \(PricingConfig.priceFallback[PricingConfig.yearlyProductId] ?? "$49.99") / year"
        }
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }
        let days = daysIn(offer.period)
        return "\(days) day\(days == 1 ? "" : "s") free, then \(product.displayPrice) / year"
    }

    private func daysIn(_ period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return period.value
        }
    }

    private var pricingUnavailableNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pricing unavailable — try again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Couldn't reach the App Store. Tap a plan to retry.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Retry") {
                Task { await appState.purchaseManager.loadProducts() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.primary)
        }
        .padding(14)
        .background(Theme.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    PortfolioAnalytics.shared.track(PortfolioEvent.restoreTapped, [:])
                    await appState.purchaseManager.restore()
                }
            } label: { Text("Restore Purchases") }
            .secondaryButtonStyle()

            if appState.purchaseManager.isPro {
                Button { showManageSubscriptions() } label: {
                    Text("Manage Subscription")
                }
                .secondaryButtonStyle()
            }
        }
    }

    /// 3.1.2(a) disclosures block. Renders ONLY the six Apple-required
    /// sentences (four standard + Rule 3 forfeiture since trial exists)
    /// plus Privacy / Terms / Restore. Install-trial copy is rendered
    /// separately by `installTrialInfo` above the cards so a reviewer never
    /// reads "no card required" three lines from the StoreKit confirmation
    /// sheet.
    private var disclosuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscription details")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 10) {
                Text(PricingConfig.Disclosures.payment)
                Text(PricingConfig.Disclosures.autoRenew)
                Text(PricingConfig.Disclosures.renewalCharge)
                Text(PricingConfig.Disclosures.manage)
                Text(PricingConfig.Disclosures.trialForfeit)
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var footerLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: PricingConfig.Links.terms)
            Text("·").foregroundStyle(Theme.textTertiary)
            Link("Privacy Policy", destination: PricingConfig.Links.privacy)
        }
        .font(.caption)
        .foregroundStyle(Theme.primary)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func product(for id: String) -> Product? {
        appState.purchaseManager.products.first(where: { $0.id == id })
    }

    private func purchase(_ productId: String) {
        let pm = appState.purchaseManager
        PortfolioAnalytics.shared.track(
            PortfolioEvent.paywallProductSelected,
            ["product_id": productId]
        )
        pendingProductId = productId
        Task {
            if pm.products.first(where: { $0.id == productId }) == nil {
                await pm.loadProducts()
            }
            guard let product = pm.products.first(where: { $0.id == productId }) else {
                pendingProductId = nil
                purchaseAlertMessage = "Couldn't reach the App Store right now. Check your connection and try again."
                PortfolioAnalytics.shared.trackPaywallFailure(
                    productId: productId,
                    reason: .productUnavailable
                )
                return
            }
            await pm.purchase(product)
            pendingProductId = nil
        }
    }

    private func showManageSubscriptions() {
        Task {
            #if canImport(UIKit)
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            try? await AppStore.showManageSubscriptions(in: scene)
            #endif
        }
    }
}

// MARK: - Card

private struct ProductCard: View {
    let productId: String
    let title: String
    let period: String
    let product: Product?
    let trialLabel: String?
    let badge: String?
    @Binding var pendingProductId: String?
    let onPurchase: (String) -> Void

    var body: some View {
        let isPending = (pendingProductId == productId)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.success.opacity(0.18))
                        .foregroundStyle(Theme.success)
                        .clipShape(Capsule())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(priceDisplay)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                    Text(period)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if let trialLabel {
                Text(trialLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.success)
            }

            Button {
                onPurchase(productId)
            } label: {
                HStack {
                    if isPending {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonLabel)
                    }
                }
            }
            .primaryButtonStyle()
            .disabled(isPending)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(badge != nil ? Theme.success : Theme.outline,
                        lineWidth: badge != nil ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var priceDisplay: String {
        if let p = product { return p.displayPrice }
        return PricingConfig.priceFallback[productId] ?? "—"
    }

    private var buttonLabel: String {
        if badge != nil { return "Start free trial" }
        return "Subscribe"
    }
}
