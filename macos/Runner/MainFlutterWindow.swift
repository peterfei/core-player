import Cocoa
import FlutterMacOS
import AVFoundation
import AVKit

// MARK: - Bookmark Manager
class BookmarkManager {
    static let shared = BookmarkManager()
    private var accessedURLs: [String: URL] = [:]
    private let maxCacheSize = 50

    private init() {}

    /// 创建文件的安全书签
    func createBookmark(for path: String) -> Data? {
        let url = URL(fileURLWithPath: path)
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            print("✅ 创建书签成功: \(path)")
            return bookmarkData
        } catch {
            print("❌ 创建书签失败: \(path) - \(error.localizedDescription)")
            return nil
        }
    }

    /// 恢复文件访问权限
    func startAccessing(bookmarkData: Data) -> (success: Bool, path: String?, isStale: Bool) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("⚠️ 书签已过期，需要重新创建")
                return (false, nil, true)
            }

            let success = url.startAccessingSecurityScopedResource()
            if success {
                accessedURLs[url.path] = url
                if accessedURLs.count > maxCacheSize {
                    let oldestKey = accessedURLs.keys.first!
                    stopAccessing(path: oldestKey)
                }
                print("✅ 恢复访问权限成功: \(url.path)")
                return (true, url.path, false)
            } else {
                print("❌ 恢复访问权限失败: \(url.path)")
                return (false, nil, false)
            }
        } catch {
            print("❌ 解析书签失败: \(error.localizedDescription)")
            return (false, nil, false)
        }
    }

    /// 停止访问特定路径
    func stopAccessing(path: String) {
        if let url = accessedURLs[path] {
            url.stopAccessingSecurityScopedResource()
            accessedURLs.removeValue(forKey: path)
            print("✅ 停止访问: \(path)")
        }
    }

    /// 停止所有访问
    func stopAllAccess() {
        for (path, url) in accessedURLs {
            url.stopAccessingSecurityScopedResource()
            print("✅ 停止访问: \(path)")
        }
        accessedURLs.removeAll()
        print("✅ 已停止所有文件访问权限")
    }

    /// 检查文件是否存在
    func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /// 获取文件大小
    func fileSize(at path: String) -> UInt64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? UInt64
        } catch {
            return nil
        }
    }

    /// 处理来自Flutter的方法调用
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔧 收到方法调用: \(call.method)")

        switch call.method {
        case "testConnection":
            result("BookmarkManager连接成功")
        case "createBookmark":
            createBookmarkMethod(call: call, result: result)
        case "startAccess":
            startAccessMethod(call: call, result: result)
        case "stopAccess":
            stopAccessMethod(call: call, result: result)
        case "stopAllAccess":
            stopAllAccessMethod(call: call, result: result)
        case "fileExists":
            fileExistsMethod(call: call, result: result)
        case "fileSize":
            fileSizeMethod(call: call, result: result)
        default:
            print("❌ 未知方法: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }

    private func createBookmarkMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing path parameter", details: nil))
            return
        }

        if let bookmarkData = createBookmark(for: path) {
            let base64String = bookmarkData.base64EncodedString()
            result(base64String)
        } else {
            result(nil)
        }
    }

    private func startAccessMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bookmarkStr = args["bookmark"] as? String,
              let bookmarkData = Data(base64Encoded: bookmarkStr) else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid bookmark data", details: nil))
            return
        }

        let (success, path, isStale) = startAccessing(bookmarkData: bookmarkData)
        if success && path != nil {
            result(path)
        } else if isStale {
            result(FlutterError(code: "STALE_BOOKMARK", message: "Bookmark is stale", details: nil))
        } else {
            result(nil)
        }
    }

    private func stopAccessMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            stopAllAccess()
            result(nil)
            return
        }

        stopAccessing(path: path)
        result(nil)
    }

    private func stopAllAccessMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        stopAllAccess()
        result(nil)
    }

    private func fileExistsMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing path parameter", details: nil))
            return
        }

        let exists = fileExists(at: path)
        result(exists)
    }

    private func fileSizeMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing path parameter", details: nil))
            return
        }

        let size = fileSize(at: path)
        result(size)
    }
}

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        // 设置Bookmark Channel
        setupBookmarkChannel(flutterViewController: flutterViewController)

        // 设置视频捕获 Channel
        setupVideoCaptureChannel(flutterViewController: flutterViewController)

        super.awakeFromNib()
    }

    private func setupBookmarkChannel(flutterViewController: FlutterViewController) {
        print("🔧 开始在MainFlutterWindow中设置Bookmark Channel")

        let bookmarkChannel = FlutterMethodChannel(
            name: "com.example.vidhub/bookmarks",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        bookmarkChannel.setMethodCallHandler { (call, result) in
            BookmarkManager.shared.handleMethodCall(call, result: result)
        }

        print("✅ Bookmark Channel 在MainFlutterWindow中设置成功")
    }

    private func setupVideoCaptureChannel(flutterViewController: FlutterViewController) {
        print("🔧 开始在MainFlutterWindow中设置Video Capture Channel")

        let videoCaptureChannel = FlutterMethodChannel(
            name: "com.example.vidhub/video_capture",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        videoCaptureChannel.setMethodCallHandler { (call, result) in
            VideoCaptureManager.shared.handleMethodCall(call, result: result)
        }

        print("✅ Video Capture Channel 在MainFlutterWindow中设置成功")
    }
}

// MARK: - Video Capture Manager
class VideoCaptureManager {
    static let shared = VideoCaptureManager()

    private init() {}

    /// 处理来自Flutter的方法调用
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔧 收到视频捕获方法调用: \(call.method)")

        switch call.method {
        case "captureFrame":
            captureFrameMethod(call: call, result: result)
        case "getVideoMetadata":
            getVideoMetadataMethod(call: call, result: result)
        default:
            print("❌ 未知视频捕获方法: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }

    /// 捕获视频帧
    private func captureFrameMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String,
              let timeInSeconds = args["timeInSeconds"] as? Double,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required parameters", details: nil))
            return
        }

        // 获取securityBookmark（如果提供）
        let securityBookmark = args["securityBookmark"] as? String

        // 如果需要，恢复访问权限
        if let bookmarkStr = securityBookmark, !bookmarkStr.isEmpty,
           let bookmarkData = Data(base64Encoded: bookmarkStr) {
            print("🔐 使用securityBookmark恢复文件访问权限")
            let (success, restoredPath, _) = BookmarkManager.shared.startAccessing(bookmarkData: bookmarkData)

            if success, let path = restoredPath {
                print("✅ 访问权限恢复成功: \(path)")
                // 使用恢复后的路径（如果有变化）
                let finalPath = restoredPath ?? videoPath

                captureVideoFrame(
                    videoPath: finalPath,
                    timeInSeconds: timeInSeconds,
                    width: width,
                    height: height
                ) { frameData in
                    // 停止访问
                    BookmarkManager.shared.stopAccessing(path: finalPath)

                    if let frameData = frameData {
                        result(frameData)
                    } else {
                        result(nil)
                    }
                }
            } else {
                print("⚠️  无法恢复访问权限，尝试直接使用原始路径")
                captureVideoFrameWithoutBookmark(videoPath, timeInSeconds, width, height, result)
            }
        } else {
            print("ℹ️  没有提供securityBookmark，尝试直接捕获")
            captureVideoFrameWithoutBookmark(videoPath, timeInSeconds, width, height, result)
        }
    }

    /// 不使用securityBookmark捕获视频帧（用于向后兼容）
    private func captureVideoFrameWithoutBookmark(_ videoPath: String, _ timeInSeconds: Double, _ width: Int, _ height: Int, _ result: @escaping FlutterResult) {
        captureVideoFrame(
            videoPath: videoPath,
            timeInSeconds: timeInSeconds,
            width: width,
            height: height
        ) { frameData in
            if let frameData = frameData {
                result(frameData)
            } else {
                result(nil)
            }
        }
    }

    /// 获取视频元数据
    private func getVideoMetadataMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing video path parameter", details: nil))
            return
        }

        // 获取securityBookmark（如果提供）
        let securityBookmark = args["securityBookmark"] as? String

        // 如果需要，恢复访问权限
        if let bookmarkStr = securityBookmark, !bookmarkStr.isEmpty,
           let bookmarkData = Data(base64Encoded: bookmarkStr) {
            print("🔐 使用securityBookmark恢复文件访问权限（获取元数据）")
            let (success, restoredPath, _) = BookmarkManager.shared.startAccessing(bookmarkData: bookmarkData)

            if success, let path = restoredPath {
                print("✅ 访问权限恢复成功: \(path)")
                let finalPath = restoredPath ?? videoPath

                getVideoMetadata(videoPath: finalPath) { metadata in
                    // 停止访问
                    BookmarkManager.shared.stopAccessing(path: finalPath)

                    if let metadata = metadata {
                        result(metadata)
                    } else {
                        result(nil)
                    }
                }
            } else {
                print("⚠️  无法恢复访问权限，尝试直接使用原始路径")
                getVideoMetadataWithoutBookmark(videoPath, result)
            }
        } else {
            print("ℹ️  没有提供securityBookmark，尝试直接获取元数据")
            getVideoMetadataWithoutBookmark(videoPath, result)
        }
    }

    /// 不使用securityBookmark获取视频元数据（向后兼容）
    private func getVideoMetadataWithoutBookmark(_ videoPath: String, _ result: @escaping FlutterResult) {
        getVideoMetadata(videoPath: videoPath) { metadata in
            if let metadata = metadata {
                result(metadata)
            } else {
                result(nil)
            }
        }
    }

    /// 捕获视频帧的实际实现
    private func captureVideoFrame(
        videoPath: String,
        timeInSeconds: Double,
        width: Int,
        height: Int,
        completion: @escaping (Data?) -> Void
    ) {
        print("🎬 开始捕获视频帧: \(videoPath)")

        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: videoPath) {
            print("❌ 视频文件不存在: \(videoPath)")
            completion(nil)
            return
        }

        // 检查文件是否可读
        if !FileManager.default.isReadableFile(atPath: videoPath) {
            print("❌ 视频文件不可读（权限不足）: \(videoPath)")
            completion(nil)
            return
        }

        let url = URL(fileURLWithPath: videoPath)

        // 检查URL是否可以访问
        do {
            let resources = try url.resourceValues(forKeys: [.isReadableKey])
            if resources.isReadable != true {
                print("⚠️  URL不可读，可能需要重新恢复访问权限")
            }
        } catch {
            print("⚠️  检查URL访问性时出错: \(error)")
        }

        let asset = AVAsset(url: url)

        // 使用传统的 completion handler 方式
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: width, height: height)

        // 异步加载视频时长
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            DispatchQueue.main.async {
                var error: NSError?

                guard asset.statusOfValue(forKey: "duration", error: &error) == .loaded else {
                    print("❌ 无法加载视频时长: \(error?.localizedDescription ?? "未知错误")")
                    completion(nil)
                    return
                }

                let duration = asset.duration
                print("视频时长: \(duration.seconds)秒")

                // 计算实际时间点
                let actualTime = CMTime(seconds: min(timeInSeconds, duration.seconds - 1), preferredTimescale: 600)
                print("捕获时间点: \(actualTime.seconds)秒")

                // 生成图像
                imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: actualTime)]) { _, cgImage, _, result, error in
                    DispatchQueue.main.async {
                        guard result == .succeeded, let cgImage = cgImage else {
                            print("❌ 视频帧捕获失败: \(error?.localizedDescription ?? "未知错误")")
                            completion(nil)
                            return
                        }

                        // 转换为PNG数据
                        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                        bitmapRep.size = NSSize(width: width, height: height)

                        // 创建PNG数据
                        let pngData = bitmapRep.representation(using: .png, properties: [:])

                        print("✅ 视频帧捕获成功，大小: \(pngData?.count ?? 0) bytes")
                        completion(pngData)
                    }
                }
            }
        }
    }

    /// 获取视频元数据
    private func getVideoMetadata(
        videoPath: String,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        print("📊 开始获取视频元数据: \(videoPath)")

        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: videoPath) {
            print("❌ 视频文件不存在: \(videoPath)")
            completion(nil)
            return
        }

        // 检查文件是否可读
        if !FileManager.default.isReadableFile(atPath: videoPath) {
            print("❌ 视频文件不可读（权限不足）: \(videoPath)")
            completion(nil)
            return
        }

        let url = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: url)

        // 异步加载所需的属性
        let keys = ["duration", "tracks"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            DispatchQueue.main.async {
                var error: NSError?

                // 检查所有属性是否加载成功
                for key in keys {
                    guard asset.statusOfValue(forKey: key, error: &error) == .loaded else {
                        print("❌ 无法加载\(key): \(error?.localizedDescription ?? "未知错误")")
                        completion(nil)
                        return
                    }
                }

                let duration = asset.duration
                let videoTrack = asset.tracks(withMediaType: .video).first
                var naturalSize = CGSize.zero
                if let videoTrack = videoTrack {
                    naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                }

                // 获取文件大小（同步操作）
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resourceValues.fileSize ?? 0

                    let metadata: [String: Any] = [
                        "duration": duration.seconds,
                        "width": Int(abs(naturalSize.width)),
                        "height": Int(abs(naturalSize.height)),
                        "fileSize": fileSize,
                        "fileSizeFormatted": self.formatFileSize(fileSize)
                    ]

                    print("✅ 视频元数据获取成功")
                    completion(metadata)

                } catch {
                    print("❌ 获取文件大小失败: \(error)")
                    completion(nil)
                }
            }
        }
    }

    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }
}
