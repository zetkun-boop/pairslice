import SwiftUI

/// Shows the loaded image with an overlay vertical split-line,
/// then lets the user initiate the split (gated by the paywall).
struct PreviewView: View {

    let image: UIImage
    @ObservedObject var splitVM: SplitViewModel

    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var adManager: AdManager

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar area
                navBar

                Spacer(minLength: 0)

                // Image preview with split-line overlay
                imagePreview
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                // Info label
                splitInfoLabel
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Spacer(minLength: 28)

                // Split button
                splitButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }

            // Error toast
            if let error = splitVM.errorMessage {
                errorToast(error)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $splitVM.showPaywall) {
            PaywallView(splitVM: splitVM)
                .environmentObject(storeManager)
                .environmentObject(adManager)
        }
        // Navigate to ResultView once split is done
        .navigationDestination(isPresented: Binding(
            get: { splitVM.splitResult != nil },
            set: { if !$0 { splitVM.splitResult = nil } }
        )) {
            if let result = splitVM.splitResult {
                ResultView(result: result, splitVM: splitVM)
            }
        }
    }

    // MARK: - Sub-views

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16))
                }
                .foregroundColor(Color.white.opacity(0.7))
            }
            Spacer()
            Text("Preview")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            // Invisible balance
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var imagePreview: some View {
        GeometryReader { geo in
            ZStack {
                // Image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Vertical split-line indicator
                GeometryReader { inner in
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .position(x: inner.size.width / 2, y: inner.size.height / 2)

                    // Top arrow hint
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .position(x: inner.size.width / 2, y: 18)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(CGFloat(image.size.width) / max(CGFloat(image.size.height), 1),
                     contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var splitInfoLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "scissors")
                .font(.system(size: 13))
            Text("Splits exactly at the vertical midpoint")
                .font(.system(size: 13))
        }
        .foregroundColor(Color.white.opacity(0.35))
    }

    private var splitButton: some View {
        Button {
            splitVM.requestSplit(image: image, storeManager: storeManager)
        } label: {
            ZStack {
                if splitVM.isSplitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "scissors")
                            .font(.system(size: 16, weight: .semibold))
                        Text(storeManager.purchaseState == .premium ? "Split Image" : "Split Image")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(splitVM.isSplitting)
    }

    private func errorToast(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Button { splitVM.errorMessage = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .animation(.spring(response: 0.35), value: splitVM.errorMessage)
    }
}
