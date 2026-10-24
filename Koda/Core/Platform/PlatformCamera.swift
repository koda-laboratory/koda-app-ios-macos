import SwiftUI

#if os(iOS)
    import UIKit
#endif

/// "Hacer foto": the system camera on iPhone. The Mac has no camera flow (it adds photos from the library, a file or
/// drag and drop instead).
enum PlatformCamera {
    static var isAvailable: Bool {
        #if os(iOS)
            UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
            false
        #endif
    }
}

/// The system camera; reports the photo as JPEG data, or `nil` when cancelled.
struct CameraCaptureView: View {
    let onFinish: (Data?) -> Void

    var body: some View {
        #if os(iOS)
            CameraPickerRepresentable(onFinish: onFinish)
                .ignoresSafeArea()
        #else
            Color.clear.onAppear { onFinish(nil) }
        #endif
    }
}

#if os(iOS)
    private struct CameraPickerRepresentable: UIViewControllerRepresentable {
        let onFinish: (Data?) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(onFinish: onFinish)
        }

        final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let onFinish: (Data?) -> Void

            init(onFinish: @escaping (Data?) -> Void) {
                self.onFinish = onFinish
            }

            func imagePickerController(
                _ picker: UIImagePickerController,
                didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
            ) {
                let image = info[.originalImage] as? UIImage
                onFinish(image?.jpegData(compressionQuality: 0.9))
            }

            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                onFinish(nil)
            }
        }
    }
#endif

extension View {
    /// Full-screen presentation on iPhone (the photo viewer, the camera); a large attached sheet on the Mac.
    func platformFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
            fullScreenCover(item: item, content: content)
        #else
            sheet(item: item) { value in
                content(value).frame(minWidth: 720, idealWidth: 900, minHeight: 560, idealHeight: 720)
            }
        #endif
    }
}
