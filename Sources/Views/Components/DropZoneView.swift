import SwiftUI

/// Animated dashed-border drop zone — purely visual, no interactive elements inside.
/// Tapping is handled by the parent view to avoid nested-button gesture conflicts.
struct DropZoneView: View {

    let isTargeted: Bool
    let isLoading: Bool

    @State private var dashPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Background fill (subtle, brightens when targeted)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Color.white.opacity(0.06) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            // Dashed border
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [7, 5],
                        dashPhase: dashPhase
                    )
                )
                .foregroundColor(isTargeted ? .white : Color.white.opacity(0.3))
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            // Content
            VStack(spacing: 14) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                } else {
                    Image(systemName: isTargeted ? "arrow.down.to.line" : "photo.badge.plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(isTargeted ? .white : Color.white.opacity(0.5))
                        .animation(.easeInOut(duration: 0.15), value: isTargeted)

                    Text(isTargeted ? "Release to load" : "Drop image here")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isTargeted ? .white : Color.white.opacity(0.45))

                    Text("or tap to choose")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.25))
                }
            }
            .padding(32)
        }
        // Allow the parent's tap gesture to pass through unobstructed
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                dashPhase = -24
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DropZoneView(isTargeted: false, isLoading: false)
            .frame(height: 260)
            .padding(24)
    }
}
