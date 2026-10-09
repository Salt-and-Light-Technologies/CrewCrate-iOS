import SwiftUI
import UIKit

enum CapturedMediaType: String, Equatable { case photo, video }
struct CapturedMedia: Equatable { let type: CapturedMediaType; let data: Data }
enum CaptureSource: Identifiable, Equatable { case camera, library; var id: Self { self } }

struct CameraCapturePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let source: CaptureSource
    var allowsVideo = true
    @Binding var media: CapturedMedia?
    func makeUIViewController(context: Context) -> UIImagePickerController { let picker = UIImagePickerController(); picker.sourceType = source == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary; picker.mediaTypes = allowsVideo ? ["public.image", "public.movie"] : ["public.image"]; picker.videoQuality = .typeMedium; picker.delegate = context.coordinator; return picker }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate { let parent: CameraCapturePicker; init(parent: CameraCapturePicker) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) { parent.media = CapturedMedia(type: .photo, data: data) } else if let url = info[.mediaURL] as? URL, let data = try? Data(contentsOf: url) { parent.media = CapturedMedia(type: .video, data: data) }; parent.dismiss() }
    }
}
