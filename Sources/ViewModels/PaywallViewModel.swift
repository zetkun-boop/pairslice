import Foundation

/// Coordinates unlock paths and reports success back to the caller via `onAuthorized`.
///
/// Available paths:
/// - **Watch Ad** (iOS only) — free, rewarded via AdManager
/// - **Buy Per-Split** ($0.99 consumable) — one split on any platform
/// - **Buy Premium** ($2.99 non-consumable) — unlimited splits forever
@MainActor
final class PaywallViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isLoadingPurchase = false
    @Published var isLoadingAd = false
    @Published var errorMessage: String?

    /// Called when any unlock path succeeds.
    /// The presenter (SplitViewModel) uses this to dismiss the paywall and perform the split.
    var onAuthorized: (() -> Void)?

    // MARK: - Premium Purchase ($2.99)

    /// Initiates the StoreKit 2 non-consumable purchase flow.
    func purchase(storeManager: StoreManager) async {
        isLoadingPurchase = true
        errorMessage = nil
        defer { isLoadingPurchase = false }

        do {
            try await storeManager.purchase()
            onAuthorized?()
        } catch AppError.purchaseCancelled {
            // User tapped Cancel — no error shown, stay on paywall.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Per-Split Purchase ($0.99)

    /// Initiates the StoreKit 2 consumable purchase for a single split.
    func purchasePerSplit(storeManager: StoreManager) async {
        isLoadingPurchase = true
        errorMessage = nil
        defer { isLoadingPurchase = false }

        do {
            try await storeManager.purchasePerSplit()
            onAuthorized?()
        } catch AppError.purchaseCancelled {
            // Silent
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore Purchases

    func restore(storeManager: StoreManager) async {
        isLoadingPurchase = true
        errorMessage = nil
        defer { isLoadingPurchase = false }

        await storeManager.restorePurchases()

        if storeManager.purchaseState == .premium {
            onAuthorized?()
        } else {
            errorMessage = "No previous purchase found for this Apple ID."
        }
    }

    // MARK: - Ad Path (iOS only)

    /// Presents a rewarded ad. On successful reward, calls `onAuthorized`.
    func watchAd(adManager: AdManager) {
        guard !isLoadingAd else { return }
        isLoadingAd = true
        errorMessage = nil

        adManager.presentRewardedAd {
            self.isLoadingAd = false
            self.onAuthorized?()
        } onFailed: { error in
            self.isLoadingAd = false
            self.errorMessage = error.localizedDescription
        }
    }
}
