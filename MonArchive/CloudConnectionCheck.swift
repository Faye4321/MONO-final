import Foundation
import FirebaseAuth
import Supabase
import UIKit

/// Temporary integration check. Run only after Firebase sign-in.
enum CloudConnectionCheck {
    @MainActor
    static func run() async {
        guard let user = FirebaseAuth.Auth.auth().currentUser else {
            print("云端测试未开始：请先登录，然后重新运行 App。")
            return
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        guard let data = image.pngData() else { return }
        let path = "\(user.uid)/connection-test-\(UUID().uuidString).png"
        let bucket = CloudStorage.client.storage.from(CloudStorage.bucket)
        var uploaded = false
        do {
            _ = try await bucket.upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/png", upsert: false)
            )
            uploaded = true
            print("云端测试：上传成功")
            let downloaded = try await bucket.download(path: path)
            guard downloaded == data else {
                throw NSError(domain: "CloudConnectionCheck", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "下载内容与上传内容不一致"])
            }
            print("云端测试：读取成功")
            _ = try await bucket.remove(paths: [path])
            uploaded = false
            print("云端测试通过：上传、读取、删除均成功")
        } catch {
            print("云端测试失败：\(error.localizedDescription)")
            if uploaded {
                do {
                    _ = try await bucket.remove(paths: [path])
                } catch {
                    print("测试图片清理失败，可在 Storage 中删除：\(path)")
                }
            }
        }
    }
}
