import StoreKit
import Foundation

/// Manages the StoreKit 2 lifecycle: product loading, purchasing, and entitlement verification.
@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Configuration

    /// Non-consumable: unlimited splits forever
    static let productID = "com.pairslice.premium"
    /// Consumable: one split at a time
    static let perSplitProductID = "com.pairslice.split"

    // MARK: - Published State

    @Published private(set) var purchaseState: PurchaseState = .unknown
    /// All loaded products (premium + per-split)
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false

    // Convenient access by type
    var premiumProduct: Product? { products.first(where: { $0.id == Self.productID }) }
    var perSplitProduct: Product? { products.first(where: { $0.id == Self.perSplitProductID }) }

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?

    // MARK: - Init / Deinit

    init() {
        // Start listening for transactions (renewals, family sharing, restoration)
        // before any UI appears, as required by StoreKit 2.
        transactionListener = Task.detached(priority: .utility) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(result)
                    // Only non-consumable purchases update the permanent premium state
                    if transaction.productID == StoreManager.productID {
                        await MainActor.run { self.purchaseState = .premium }
                    }
                    await transaction.finish()
                } catch {
                    print("[StoreManager] Unverified transaction: \(error)")
                }
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public Methods

    /// Fetches products from the store (or local .storekit config in Xcode).
    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.productID, Self.perSplitProductID])
        } catch {
            print("[StoreManager] Failed to load products: \(error)")
        }
    }

    /// Initiates the purchase flow for the $2.99 premium (non-consumable) product.
    /// - Throws: `AppError.purchaseCancelled` or `AppError.purchaseFailed`.
    func purchase() async throws {
        guard let product = premiumProduct else {
            throw AppError.purchaseFailed("Product not available. Check your connection.")
        }

        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            purchaseState = .premium

        case .userCancelled:
            throw AppError.purchaseCancelled

        case .pending:
            // Awaiting parental approval; transaction listener will handle completion.
            break

        @unknown default:
            throw AppError.purchaseFailed("Unexpected purchase result.")
        }
    }

    /// Initiates the purchase flow for one consumable split ($0.99).
    /// On success the caller may perform one split; state is NOT permanently changed.
    /// - Throws: `AppError.purchaseCancelled` or `AppError.purchaseFailed`.
    func purchasePerSplit() async throws {
        guard let product = perSplitProduct else {
            throw AppError.purchaseFailed("Per-split product not available. Check your connection.")
        }

        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            // Consumable — no permanent entitlement; caller handles the reward.

        case .userCancelled:
            throw AppError.purchaseCancelled

        case .pending:
            break

        @unknown default:
            throw AppError.purchaseFailed("Unexpected purchase result.")
        }
    }

    /// Re-syncs with the App Store and refreshes entitlement.
    /// Call this from "Restore Purchases".
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            print("[StoreManager] AppStore.sync failed: \(error)")
        }
        await refreshEntitlement()
    }

    // MARK: - Private Helpers

    /// Checks the current entitlement from StoreKit 2.
    func refreshEntitlement() async {
        if let entitlement = await Transaction.currentEntitlement(for: Self.productID) {
            do {
                _ = try verified(entitlement)
                purchaseState = .premium
                return
            } catch {
                print("[StoreManager] Entitlement verification failed: \(error)")
            }
        }
        if purchaseState == .unknown {
            purchaseState = .free
        }
    }

    /// Verifies a `VerificationResult`, throwing if it is `.unverified`.
    private nonisolated func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
