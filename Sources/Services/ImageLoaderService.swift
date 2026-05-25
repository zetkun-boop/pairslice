import UIKit

/// Downloads a UIImage from a remote URL.
enum ImageLoaderService {

    /// Downloads image data from `urlString` and decodes it as `UIImage`.
    /// - Throws: `AppError.urlInvalid`, `.httpError`, or `.invalidImageData`.
    static func download(from urlString: String) async throws -> UIImage {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            throw AppError.urlInvalid
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw AppError.httpError(statusCode: http.statusCode)
        }

        guard let image = UIImage(data: data) else {
            throw AppError.invalidImageData
        }

        return image
    }
}
