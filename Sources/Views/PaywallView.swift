import SwiftUI

// Measures the natural height of the sheet content so presentationDetents
// can fit exactly — no guessing, no empty space.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 300
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Purchase sheet — compact modal with close button top-right.
///
/// macOS: per-split ($0.99) + forever ($2.99)
/// iOS:   watch ad + per-split ($0.99) + forever ($2.99)
struct PaywallView: View {

    @ObservedObject var splitVM: SplitViewModel
    @StateObject private var vm = PaywallViewModel()

    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var adManager: AdManager
    @Environment(\.dismiss) private var dismiss

    @State private var contentHeight: CGFloat = 300

    var body: some View {
        Color(white: 0.06)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                content
                    // Measure the natural height of the content
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ContentHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )
            }
            .onPreferenceChange(ContentHeightKey.self) { h in
                contentHeight = h
            }
            .presentationDetents([.height(contentHeight)])
            .presentationDragIndicator(.hidden)
            .onAppear {
                vm.onAuthorized = { [weak splitVM] in
                    splitVM?.authorizeAndSplit()
                }
            }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ───────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "scissors")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Unlock this split")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Choose how to continue")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.4))
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // ── Divider ──────────────────────────────────────────────────────
            Divider().background(Color.white.opacity(0.08))

            // ── Error banner ─────────────────────────────────────────────────
            if let error = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.7))
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // ── Option cards ─────────────────────────────────────────────────
            VStack(spacing: 10) {
#if !targetEnvironment(macCatalyst)
                adCard
#endif
                perSplitCard
                premiumCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // ── Restore link ─────────────────────────────────────────────────
            Button {
                Task { await vm.restore(storeManager: storeManager) }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.28))
                    .underline()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .disabled(vm.isLoadingPurchase)
        }
    }

    // MARK: - Card builder

    private func card(
        icon: String,
        iconBg: Color, iconFg: Color,
        title: String,
        badge: String?,
        badgeBg: Color, badgeFg: Color,
        subtitle: String,
        cardBg: Color, cardBorder: Color,
        titleColor: Color, subtitleColor: Color,
        isLoading: Bool, chevronColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconBg).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(iconFg)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(titleColor)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(badgeFg)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(badgeBg)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(subtitleColor)
            }
            Spacer()
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: chevronColor))
                    .scaleEffect(0.85)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(chevronColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Watch Ad (iOS only)

    private var adCard: some View {
        Button { vm.watchAd(adManager: adManager) } label: {
            card(
                icon: vm.isLoadingAd ? "hourglass" : "play.rectangle.fill",
                iconBg: Color.white.opacity(0.08), iconFg: .white,
                title: "Watch a Short Ad",
                badge: "Free",
                badgeBg: Color.white.opacity(0.12), badgeFg: Color.white.opacity(0.7),
                subtitle: adManager.isAdReady ? "~15–30 seconds" : "Loading ad…",
                cardBg: Color.white.opacity(0.05), cardBorder: Color.white.opacity(0.1),
                titleColor: .white, subtitleColor: Color.white.opacity(0.4),
                isLoading: vm.isLoadingAd, chevronColor: Color.white.opacity(0.3)
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isLoadingAd || vm.isLoadingPurchase || !adManager.isAdReady)
        .opacity((adManager.isAdReady && !vm.isLoadingPurchase) ? 1 : 0.45)
    }

    // MARK: - Per-Split ($0.99)

    private var perSplitCard: some View {
        Button { Task { await vm.purchasePerSplit(storeManager: storeManager) } } label: {
            card(
                icon: vm.isLoadingPurchase ? "hourglass" : "scissors",
                iconBg: Color.white.opacity(0.08), iconFg: .white,
                title: "This Split Only",
                badge: perSplitPriceLabel,
                badgeBg: Color.white.opacity(0.1), badgeFg: Color.white.opacity(0.65),
                subtitle: "Pay once, use now",
                cardBg: Color.white.opacity(0.05), cardBorder: Color.white.opacity(0.1),
                titleColor: .white, subtitleColor: Color.white.opacity(0.4),
                isLoading: vm.isLoadingPurchase, chevronColor: Color.white.opacity(0.3)
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isLoadingPurchase || vm.isLoadingAd)
    }

    // MARK: - Premium forever ($2.99)

    private var premiumCard: some View {
        Button { Task { await vm.purchase(storeManager: storeManager) } } label: {
            card(
                icon: vm.isLoadingPurchase ? "hourglass" : "crown.fill",
                iconBg: .white, iconFg: .black,
                title: "Unlock Forever",
                badge: premiumPriceLabel,
                badgeBg: Color.black.opacity(0.1), badgeFg: Color.black.opacity(0.6),
                subtitle: "Unlimited splits, no ads",
                cardBg: .white, cardBorder: .clear,
                titleColor: .black, subtitleColor: Color.black.opacity(0.45),
                isLoading: vm.isLoadingPurchase, chevronColor: Color.black.opacity(0.35)
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isLoadingPurchase || vm.isLoadingAd)
        .opacity(vm.isLoadingAd ? 0.55 : 1)
    }

    // MARK: - Helpers

    private var perSplitPriceLabel: String { storeManager.perSplitProduct?.displayPrice ?? "$0.99" }
    private var premiumPriceLabel: String  { storeManager.premiumProduct?.displayPrice  ?? "$2.99" }
}
