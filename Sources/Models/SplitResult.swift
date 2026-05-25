import UIKit

/// Holds the two vertical halves produced by ImageSplitterService.
struct SplitResult: Equatable {
    /// Left half of the original image (x: 0 … width/2)
    let left: UIImage
    /// Right half of the original image (x: width/2 … width)
    let right: UIImage
    /// Timestamp used for Equatable / as stable identity
    let createdAt: Date

    init(left: UIImage, right: UIImage) {
        self.left = left
        self.right = right
        self.createdAt = Date()
    }

    static func == (lhs: SplitResult, rhs: SplitResult) -> Bool {
        lhs.createdAt == rhs.createdAt
    }
}
