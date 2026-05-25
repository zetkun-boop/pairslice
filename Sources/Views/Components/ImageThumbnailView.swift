import SwiftUI

/// Rounded image thumbnail with a label underneath.
struct ImageThumbnailView: View {

    let image: UIImage
    let label: String
    let index: Int          // 1 or 2  — used for ordering badge

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Order badge
                Text("\(index)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(Color.white)
                    .clipShape(Circle())
                    .padding(8)
            }

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.5))
        }
    }
}
