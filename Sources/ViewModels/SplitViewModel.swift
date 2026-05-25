import SwiftUI

/// Orchestrates the split flow: paywall gate → ImageSplitterService → save.
@MainActor
final class SplitViewModel: ObservableObject {

    // MARK: - Published State

    @Published var splitResult: SplitResult?
    @Published var showPaywall = false
    @Published var isSplitting = false
    @Published var saveState: SaveState = .idle
    @Published var errorMessage: String?

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    // The image waiting to be split (held here so split can be deferred past paywall)
    private(set) var pendingImage: UIImage?

    // MARK: - macOS Free Split Tracking

    /// UserDefaults key for tracking whether the one-time macOS free split has been used.
    private static let macFreeSplitKey = "ps_mac_free_split_used"

    /// Whether the macOS user has already consumed their one free split.
    var hasUsedMacFreeSplit: Bool {
        UserDefaults.standard.bool(forKey: Self.macFreeSplitKey)
    }

    // MARK: - Split Request

    /// Entry point called when the user taps "Split Image" on PreviewView.
    ///
    /// **macOS flow:**
    ///   1. Premium → split immediately
    ///   2. Free split not yet used → split immediately, mark as used
    ///   3. Otherwise → show paywall (Buy $0.99 / Buy $2.99)
    ///
    /// **iOS flow:**
    ///   1. Premium → split immediately
    ///   2. Otherwise → show paywall (Watch Ad / Buy $0.99 / Buy $2.99)
    func requestSplit(image: UIImage, storeManager: StoreManager) {
        pendingImage = image
        errorMessage = nil

        // Premium always bypasses the paywall
        if storeManager.purchaseState == .premium {
            performSplit()
            return
        }

#if targetEnvironment(macCatalyst)
        // macOS: one free split, then paid options only
        if !hasUsedMacFreeSplit {
            UserDefaults.standard.set(true, forKey: Self.macFreeSplitKey)
            performSplit()
        } else {
            showPaywall = true
        }
#else
        // iOS: no free split — watch ad or purchase
        showPaywall = true
#endif
    }

    /// Called by PaywallViewModel (via callback) once the user has earned the right
    /// to split — either by completing an ad, a per-split purchase, or a premium purchase.
    func authorizeAndSplit() {
        showPaywall = false
        performSplit()
    }

    // MARK: - Save

    /// Saves both halves to the Camera Roll.
    func saveBothHalves() async {
        guard let result = splitResult else { return }
        saveState = .saving
        do {
            try await PhotoLibraryService.save(images: [result.left, result.right])
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Reset

    func reset() {
        splitResult = nil
        pendingImage = nil
        errorMessage = nil
        saveState = .idle
        showPaywall = false
    }

    // MARK: - Private

    private func performSplit() {
        guard let image = pendingImage else { return }
        isSplitting = true
        Task {
            defer { isSplitting = false }
            do {
                splitResult = try ImageSplitterService.split(image: image)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
