import SwiftUI

/// Shows both image halves and lets the user save them to Camera Roll.
struct ResultView: View {

    let result: SplitResult
    @ObservedObject var splitVM: SplitViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(spacing: 28) {
                        successBanner
                        halfImages
                        uploadGuide
                        saveButton
                        splitAnotherButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Sub-views

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16))
                }
                .foregroundColor(Color.white.opacity(0.7))
            }
            Spacer()
            Text("Ready to Post")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
            Text("Image split at exact midpoint")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.7))
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.14, blue: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        )
        .padding(.top, 12)
    }

    private var halfImages: some View {
        HStack(spacing: 12) {
            ImageThumbnailView(image: result.left,  label: "Post 1st", index: 1)
            ImageThumbnailView(image: result.right, label: "Post 2nd", index: 2)
        }
    }

    private var uploadGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to use in Threads")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))

            guideStep(num: "1", text: "Save both images to your Camera Roll below")
            guideStep(num: "2", text: "In Threads, create a new post and add both photos in order")
            guideStep(num: "3", text: "Viewers can pinch-swipe the carousel — images connect seamlessly ✨")
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func guideStep(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.7))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var saveButton: some View {
        Button {
            Task { await splitVM.saveBothHalves() }
        } label: {
            HStack(spacing: 10) {
                saveButtonContent
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(saveButtonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(saveButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(splitVM.saveState == .saving || splitVM.saveState == .saved)
        .animation(.easeInOut(duration: 0.2), value: splitVM.saveState)
    }

    @ViewBuilder
    private var saveButtonContent: some View {
        switch splitVM.saveState {
        case .idle:
            Image(systemName: "square.and.arrow.down")
            Text("Save Both to Camera Roll")
        case .saving:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .black))
            Text("Saving…")
        case .saved:
            Image(systemName: "checkmark")
            Text("Saved to Camera Roll")
        case .failed(let msg):
            Image(systemName: "exclamationmark.triangle")
            Text(msg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var saveButtonForeground: Color {
        switch splitVM.saveState {
        case .saved: return .black
        case .failed: return .black
        default: return .black
        }
    }

    private var saveButtonBackground: Color {
        switch splitVM.saveState {
        case .saved: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .failed: return Color(red: 0.9, green: 0.3, blue: 0.3)
        default: return .white
        }
    }

    private var splitAnotherButton: some View {
        Button {
            // Pop back two levels (ResultView + PreviewView) to HomeView
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                dismiss()
            }
        } label: {
            Text("Split Another Image")
                .font(.system(size: 16))
                .foregroundColor(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
