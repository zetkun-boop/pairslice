/// Represents the user's monetisation status.
enum PurchaseState: Equatable {
    /// Initial state while StoreKit is verifying entitlements
    case unknown
    /// User has purchased the one-time premium unlock ($2.99)
    case premium
    /// No active purchase — must watch an ad per split
    case free
}
