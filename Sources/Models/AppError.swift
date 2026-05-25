import Foundation

enum AppError: LocalizedError, Equatable {
    case cgImageUnavailable
    case invalidImageData
    case httpError(statusCode: Int)
    case urlInvalid
    case photoPermissionDenied
    case saveFailed(String)
    case adNotReady
    case purchaseFailed(String)
    case purchaseCancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .cgImageUnavailable:
            return "Could not process image. Please try a different photo."
        case .invalidImageData:
            return "The image data is invalid or corrupted."
        case .httpError(let code):
            return "Network error (HTTP \(code)). Check the URL and try again."
        case .urlInvalid:
            return "Invalid URL. Please enter a direct image link."
        case .photoPermissionDenied:
            return "Photo library access denied. Enable it in Settings → PairSlice."
        case .saveFailed(let msg):
            return "Save failed: \(msg)"
        case .adNotReady:
            return "Ad isn't ready yet. Please wait a moment and try again."
        case .purchaseFailed(let msg):
            return "Purchase failed: \(msg)"
        case .purchaseCancelled:
            return "Purchase cancelled."
        case .unknown(let msg):
            return msg
        }
    }
}
