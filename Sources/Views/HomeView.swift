import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Root screen — loads an image via gallery, URL, drag-and-drop, or Files app,
/// then navigates to PreviewView.
struct HomeView: View {

    @StateObject private var vm = HomeViewModel()
    @StateObject private var splitVM = SplitViewModel()

    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var adManager: AdManager

    // PhotosPicker item binding (iOS only — on Mac we go direct to document picker)
    @State private var photosItem: PhotosPickerItem?
    // Drag-and-drop targeting
    @State private var isDropTargeted = false
    // Navigate to preview when image is ready
    @State private var navigateToPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    dropZone
                    Spacer(minLength: 20)
                    actionButtons
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)

                // Error toast
                if let error = vm.errorMessage {
                    errorToast(error)
                }
            }
            // Navigate to Preview when an image is loaded
            .navigationDestination(isPresented: $navigateToPreview) {
                if let image = vm.loadedImage {
                    PreviewView(image: image, splitVM: splitVM)
                        .environmentObject(storeManager)
                        .environmentObject(adManager)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .onChange(of: vm.hasImage) { hasImage in
                if hasImage { navigateToPreview = true }
            }
            .onChange(of: navigateToPreview) { presented in
                // When user pops back from PreviewView, reset everything
                if !presented {
                    vm.reset()
                    splitVM.reset()
                }
            }
            // URL input sheet
            .sheet(isPresented: $vm.showURLInput) {
                URLInputSheet(urlText: $vm.urlText) {
                    Task { await vm.loadFromURL() }
                }
            }
            // Document picker sheet (Files app / Finder on Mac)
            .sheet(isPresented: $vm.showDocumentPicker) {
                DocumentPickerView { url in
                    vm.loadFromDocumentURL(url)
                }
                .ignoresSafeArea()
            }
            // PhotosPicker (iOS gallery)
            .onChange(of: photosItem) { newItem in
                Task { await vm.loadFromPhotosItem(newItem) }
            }
            // Drag & Drop (URL-based: from Finder on Mac / Files on iPad)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                vm.loadFromDroppedURL(url)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
            // Drag & Drop (Data-based: direct image data on some platforms)
            .dropDestination(for: Data.self) { items, _ in
                guard let data = items.first,
                      let image = UIImage(data: data) else { return false }
                vm.loadedImage = image
                return true
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Drop Zone

    /// On macOS: plain Button → document picker (Finder) — instant response.
    /// On iOS:   PhotosPicker → system gallery sheet.
    @ViewBuilder
    private var dropZone: some View {
#if targetEnvironment(macCatalyst)
        Button {
            vm.showDocumentPicker = true
        } label: {
            DropZoneView(isTargeted: isDropTargeted, isLoading: vm.isLoading)
                .frame(height: 260)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
#else
        PhotosPicker(selection: $photosItem, matching: .images) {
            DropZoneView(isTargeted: isDropTargeted, isLoading: vm.isLoading)
                .frame(height: 260)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
#endif
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Text("PairSlice")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.white)
                Spacer()
                premiumBadge
            }
            .padding(.top, 56)

            HStack {
                Text("Split any image perfectly in half for Threads")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 36)
    }

    @ViewBuilder
    private var premiumBadge: some View {
        if storeManager.purchaseState == .premium {
            Label("Premium", systemImage: "crown.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white)
                .clipShape(Capsule())
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Gallery button
            // Mac: opens document picker (same as tap zone — Finder is native here)
            // iOS: PhotosPicker
#if targetEnvironment(macCatalyst)
            Button {
                vm.showDocumentPicker = true
            } label: {
                iconButton(icon: "photo.on.rectangle", label: "Files")
            }
#else
            PhotosPicker(selection: $photosItem, matching: .images) {
                iconButton(icon: "photo.on.rectangle", label: "Gallery")
            }
            .buttonStyle(.plain)
#endif

            // URL
            Button {
                vm.showURLInput = true
            } label: {
                iconButton(icon: "link", label: "URL")
            }

            // Files (only on iOS — on Mac the main button already opens Finder)
#if !targetEnvironment(macCatalyst)
            Button {
                vm.showDocumentPicker = true
            } label: {
                iconButton(icon: "folder", label: "Files")
            }
#endif
        }
    }

    private func iconButton(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
            Text(label)
                .font(.system(size: 12))
        }
        .foregroundColor(Color.white.opacity(0.6))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                    .multilineTextAlignment(.leading)
                Spacer()
                Button {
                    vm.errorMessage = nil
                } label: {
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
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.35), value: vm.errorMessage)
    }
}

// MARK: - URL Input Sheet

private struct URLInputSheet: View {
    @Binding var urlText: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text("Paste Image URL")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                TextField("https://example.com/image.jpg", text: $urlText)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                Button {
                    dismiss()
                    onSubmit()
                } label: {
                    Text("Load Image")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(urlText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)

                Spacer()
            }
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .jpeg, .png, UTType("public.heic") ?? .image, .tiff, .webP]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(StoreManager())
        .environmentObject(AdManager())
}
