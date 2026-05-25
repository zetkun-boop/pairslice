import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// AdMob Integration
// ─────────────────────────────────────────────────────────────────────────────
// SETUP REQUIRED:
//   1. Add GoogleMobileAdsSPM via SPM:
//      https://github.com/googleads/swift-package-manager-google-mobile-ads
//      Version: 11.x.x  |  Target: PairSlice only
//
//   2. In Info.plist add:
//      Key:   GADApplicationIdentifier
//      Value: <your real AdMob App ID>   e.g. "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"
//
//   3. In Info.plist add:
//      Key:   NSUserTrackingUsageDescription
//      Value: "We use your advertising ID to show relevant ads."
//
//   4. Replace adUnitID below with your real Rewarded Ad Unit ID.
//
//   5. In PairSliceApp.swift, uncomment the GADMobileAds.start() call.
//
// NOTE: AdMob rewarded ads are NOT available on Mac Catalyst.
//       The "Watch Ad" option is automatically hidden on Mac.
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdManager: ObservableObject {

    // MARK: - Configuration

    // TODO: Replace with your real AdMob Rewarded Ad Unit ID from AdMob console.
    // Current value is Google's public test ID (safe for development).
    static let adUnitID = "ca-app-pub-3940256099942544/1712485313"

    // MARK: - Published State

    @Published private(set) var isAdReady = false
    @Published private(set) var isLoading = false

    /// True when running on Mac Catalyst — ads not supported there.
    let isMacCatalyst: Bool = {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }()

    // MARK: - Private

#if canImport(GoogleMobileAds)
    private var rewardedAd: GADRewardedAd?
#endif

    // MARK: - Init

    init() {
        guard !isMacCatalyst else { return }
        Task { await loadAd() }
    }

    // MARK: - Public Methods

    /// Pre-loads a rewarded ad so it is ready to present immediately.
    func loadAd() async {
#if canImport(GoogleMobileAds) && !targetEnvironment(macCatalyst)
        isLoading = true
        isAdReady = false
        defer { isLoading = false }

        do {
            rewardedAd = try await GADRewardedAd.load(
                withAdUnitID: Self.adUnitID,
                request: GADRequest()
            )
            isAdReady = true
        } catch {
            print("[AdManager] Failed to load rewarded ad: \(error)")
            isAdReady = false
        }
#endif
    }

    /// Presents the rewarded ad from the top-most view controller.
    /// Calls `onRewarded` when the user earns the reward (completed viewing).
    /// Calls `onFailed` if the ad is not ready or presentation fails.
    func presentRewardedAd(
        onRewarded: @escaping @MainActor () -> Void,
        onFailed: @escaping @MainActor (Error) -> Void
    ) {
#if canImport(GoogleMobileAds) && !targetEnvironment(macCatalyst)
        guard let ad = rewardedAd, isAdReady else {
            Task { @MainActor in onFailed(AppError.adNotReady) }
            return
        }

        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                      ?? scene.windows.first?.rootViewController
        else {
            Task { @MainActor in onFailed(AppError.adNotReady) }
            return
        }

        isAdReady = false

        ad.present(fromRootViewController: rootVC) {
            // This closure is called on the main thread when the user earns the reward.
            Task { @MainActor in
                onRewarded()
                // Pre-load the next ad while the user is in the result screen.
                await self.loadAd()
            }
        }
#else
        Task { @MainActor in onFailed(AppError.adNotReady) }
#endif
    }
}
