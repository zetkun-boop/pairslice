import SwiftUI
import AppTrackingTransparency

// ─────────────────────────────────────────────────────────────────────────────
// SETUP CHECKLIST (do this before first run):
//
//  □  1. In Xcode: New Project → iOS App → "PairSlice"
//         Bundle ID: com.pairslice.app
//         Interface: SwiftUI  |  Lifecycle: SwiftUI App  |  No CoreData
//
//  □  2. Enable Mac Catalyst in the target's General settings.
//
//  □  3. Add SPM package via File → Add Package Dependencies:
//         https://github.com/googleads/swift-package-manager-google-mobile-ads
//         Version: Up to Next Major → 11.0.0
//         Link GoogleMobileAds to PairSlice target only.
//
//  □  4. In the target's Signing & Capabilities, add "In-App Purchase".
//
//  □  5. Add PairSlice.storekit to the Xcode scheme (Edit Scheme → Run →
//         Options → StoreKit Configuration) for local sandbox testing.
//
//  □  6. Fill in your real AdMob App ID in Info.plist (GADApplicationIdentifier).
//         Until then, comment out GADMobileAds.sharedInstance().start() below.
//
//  □  7. Set Deployment Target: iOS 16.0 / macOS 13.0
//
//  □  8. Delete the auto-generated ContentView.swift that Xcode creates.
//
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct PairSliceApp: App {

    @StateObject private var storeManager = StoreManager()
    @StateObject private var adManager   = AdManager()

    init() {
        // Configure app-wide appearance (ensure pure-black nav bars etc.)
        configureAppearance()

        // Initialize Google Mobile Ads SDK.
        // ⚠️ COMMENT THIS OUT until you have added your real GADApplicationIdentifier
        //    to Info.plist — otherwise the app will crash on launch.
        #if canImport(GoogleMobileAds) && !targetEnvironment(macCatalyst)
        // GADMobileAds.sharedInstance().start(completionHandler: nil)  // ← Uncomment after adding AdMob App ID
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(storeManager)
                .environmentObject(adManager)
                .preferredColorScheme(.dark)
                .task {
                    // Request App Tracking Transparency permission.
                    // Must be called before showing any ads.
                    // Omitted on Mac Catalyst (not needed there).
                    #if !targetEnvironment(macCatalyst)
                    await requestTrackingPermission()
                    #endif
                }
        }
    }

    // MARK: - Tracking Permission

    @MainActor
    private func requestTrackingPermission() async {
        // Small delay so the app's own UI has appeared first (Apple guideline).
        try? await Task.sleep(nanoseconds: 500_000_000)

        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }

        _ = await ATTrackingManager.requestTrackingAuthorization()

        // After ATT resolves, initialize AdMob (delayed start).
        #if canImport(GoogleMobileAds)
        // GADMobileAds.sharedInstance().start(completionHandler: nil)  // ← Uncomment after adding AdMob App ID
        #endif
    }

    // MARK: - Appearance

    private func configureAppearance() {
        // Pure-black navigation bar on Mac Catalyst / iPad
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance  = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance   = navAppearance

        // Pure-black tab bar (if ever added)
        UITabBar.appearance().barTintColor = .black

        // Ensure the window background is black (critical for Mac Catalyst)
        UIWindow.appearance().backgroundColor = .black
    }
}
