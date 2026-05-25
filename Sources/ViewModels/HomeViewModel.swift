import SwiftUI
import PhotosUI

/// Manages all four image-loading paths and exposes the loaded UIImage to the UI.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published var loadedImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // URL sheet state
    @Published var showURLInput = false
    @Published var urlText = ""

    // Document picker sheet state
    @Published var showDocumentPicker = false

    // Computed convenience
    var hasImage: Bool { loadedImage != nil }

    // MARK: - Image Loading Paths

    /// Load from PhotosPicker selection (gallery / iCloud Photos)
    func loadFromPhotosItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        await run {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw AppError.invalidImageData
            }
            self.loadedImage = image
        }
    }

    /// Load by downloading an image from a URL string
    func loadFromURL() async {
        guard !urlText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await run {
            self.loadedImage = try await ImageLoaderService.download(from: self.urlText)
            self.showURLInput = false
            self.urlText = ""
        }
    }

    /// Load from a drag-and-drop URL (may be security-scoped on Mac / Files app)
    func loadFromDroppedURL(_ url: URL) {
        Task {
            await run {
                let hasScope = url.startAccessingSecurityScopedResource()
                defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard let image = UIImage(data: data) else {
                    throw AppError.invalidImageData
                }
                self.loadedImage = image
            }
        }
    }

    /// Load from document picker selection (same security-scoped pattern)
    func loadFromDocumentURL(_ url: URL) {
        loadFromDroppedURL(url)
    }

    // MARK: - Reset

    func reset() {
        loadedImage = nil
        errorMessage = nil
        urlText = ""
        showURLInput = false
        showDocumentPicker = false
    }

    // MARK: - Private

    /// Runs an async throwing block, updating `isLoading` and `errorMessage`.
    private func run(_ block: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await block()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
