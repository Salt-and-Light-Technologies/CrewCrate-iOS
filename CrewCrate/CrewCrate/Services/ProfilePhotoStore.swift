import Foundation
import UIKit

@MainActor
final class ProfilePhotoStore {
    private func url(for userID: UUID) throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ProfilePhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(userID.uuidString + ".jpg")
    }
    func load(for userID: UUID) throws -> Data? {
        let file = try url(for: userID)
        return FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
    }
    func save(_ data: Data, for userID: UUID) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw AuthenticationFailure(message: "This photo could not be opened. Choose another image.")
        }
        let scale = min(1, 512 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            throw AuthenticationFailure(message: "This photo could not be saved.")
        }
        try jpeg.write(to: url(for: userID), options: [.atomic, .completeFileProtection])
        return jpeg
    }
}
