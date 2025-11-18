import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'macos_bookmark_service.dart';

/// macOS原生视频帧捕获服务
/// 使用AVFoundation提取真实的视频帧
class NativeVideoCaptureService {
  static const MethodChannel _channel = MethodChannel('com.example.vidhub/video_capture');

  /// 检查是否支持
  static bool get isSupported => Platform.isMacOS;

  /// 提取视频帧
  static Future<Uint8List?> captureVideoFrame({
    required String videoPath,
    double timeInSeconds = 1.0,
    int width = 320,
    int height = 180,
    String? securityBookmark,
  }) async {
    if (!isSupported) return null;

    try {
      print('🎬 开始提取原生视频帧...');

      // 调用原生方法提取视频帧（传递securityBookmark）
      final result = await _channel.invokeMethod<Uint8List>('captureFrame', {
        'videoPath': videoPath,
        'timeInSeconds': timeInSeconds,
        'width': width,
        'height': height,
        'securityBookmark': securityBookmark,
      });

      if (result != null && result.isNotEmpty) {
        print('✅ 原生视频帧提取成功，大小: ${result.length} bytes');
        return result;
      } else {
        print('❌ 原生视频帧提取失败');
        return null;
      }
    } catch (e) {
      print('❌ 原生AVFoundation视频帧提取异常: $e');
      return null;
    }
  }

  /// 批量提取多帧
  static Future<List<Uint8List>> captureMultipleFrames({
    required String videoPath,
    List<double> timePoints = const [1.0, 10.0, 30.0],
    int width = 320,
    int height = 180,
    String? securityBookmark,
  }) async {
    final frames = <Uint8List>[];

    // 对于macOS，先恢复访问权限（一次性）
    String? restoredPath = videoPath;
    if (securityBookmark != null && isSupported) {
      restoredPath = await MacOSBookmarkService.tryRestoreAccess(videoPath);
      if (restoredPath == null) {
        print('❌ 批量提取时无法恢复文件访问权限');
        return frames;
      }
    }

    for (final timePoint in timePoints) {
      final frame = await captureVideoFrame(
        videoPath: restoredPath!,
        timeInSeconds: timePoint,
        width: width,
        height: height,
        securityBookmark: securityBookmark,
      );

      if (frame != null) {
        frames.add(frame);
      }

      // 在帧之间添加小延迟
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('✅ 批量提取完成，共${frames.length}帧');
    return frames;
  }

  /// 获取视频元数据
  static Future<Map<String, dynamic>?> getVideoMetadata(String videoPath, {String? securityBookmark}) async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<Map<String, dynamic>>('getVideoMetadata', {
        'videoPath': videoPath,
        'securityBookmark': securityBookmark,
      });

      if (result != null) {
        print('✅ 视频元数据获取成功');
        return result;
      } else {
        print('❌ 视频元数据获取失败');
        return null;
      }
    } catch (e) {
      print('❌ 获取视频元数据异常: $e');
      return null;
    }
  }
}