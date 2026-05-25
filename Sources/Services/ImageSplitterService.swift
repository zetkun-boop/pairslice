import UIKit

/// Splits a UIImage into left and right halves using a pixel-accurate crop.
enum ImageSplitterService {

    // MARK: - Public API

    /// Splits `image` exactly at its vertical midpoint.
    /// - Returns: A `SplitResult` with left (0…w/2) and right (w/2…w) UIImages,
    ///            both at the original scale and in `.up` orientation.
    /// - Throws: `AppError.cgImageUnavailable` if the image cannot be processed.
    static func split(image: UIImage) throws -> SplitResult {
        // 1. Normalize EXIF orientation so CGImage coordinates are always top-left.
        //    Without this, landscape iPhone photos would split along the wrong axis.
        let normalized = normalize(image)

        guard let cgImage = normalized.cgImage else {
            throw AppError.cgImageUnavailable
        }

        // 2. Work in pixel space (not point space) to preserve full resolution on
        //    Retina / ProMotion displays where scale > 1.
        let w = cgImage.width   // pixel width
        let h = cgImage.height  // pixel height
        let scale = normalized.scale

        // 3. Integer divide — the right half absorbs any odd pixel.
        let leftRect  = CGRect(x: 0,     y: 0, width: w / 2,     height: h)
        let rightRect = CGRect(x: w / 2, y: 0, width: w - w / 2, height: h)

        guard
            let leftCG  = cgImage.cropping(to: leftRect),
            let rightCG = cgImage.cropping(to: rightRect)
        else {
            throw AppError.cgImageUnavailable
        }

        let leftImage  = UIImage(cgImage: leftCG,  scale: scale, orientation: .up)
        let rightImage = UIImage(cgImage: rightCG, scale: scale, orientation: .up)

        return SplitResult(left: leftImage, right: rightImage)
    }

    // MARK: - Private helpers

    /// Re-draws the image into a new bitmap so that `imageOrientation == .up`.
    /// This resolves EXIF rotation flags that `CGImage` ignores.
    private static func normalize(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }
}
