import Photos
import UIKit

/// Saves an array of UIImages to the user's Camera Roll.
enum PhotoLibraryService {

    /// Requests `.addOnly` authorization if needed, then saves all `images`
    /// in a single atomic `performChanges` block (either all succeed or none).
    /// - Throws: `AppError.photoPermissionDenied` or `AppError.saveFailed`.
    static func save(images: [UIImage]) async throws {
        // 1. Check / request authorization (addOnly is less intrusive than full access)
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                throw AppError.photoPermissionDenied
            }
        case .denied, .restricted:
            throw AppError.photoPermissionDenied
        case .authorized, .limited:
            break // already have access
        @unknown default:
            throw AppError.photoPermissionDenied
        }

        // 2. Save all images atomically
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                for image in images {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    let msg = error?.localizedDescription ?? "Unknown error"
                    continuation.resume(throwing: AppError.saveFailed(msg))
                }
            }
        }
    }
}
