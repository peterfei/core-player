import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class VideoThumbnailExtractor {
  /// 提取视频截图
  /// [videoPath] 视频文件路径
  /// [outputId] 输出ID
  /// [position] 截图位置（0.0 - 1.0），默认 0.1 (10%)
  static Future<File?> extractThumbnail(String videoPath, String outputId, {double position = 0.1}) async {
    try {
      if (kIsWeb) return null;

      // 注：视频帧提取功能对所有用户开放

      // 2. 准备输出路径
      final cacheFile = await _getCacheFile(outputId);
      if (await cacheFile.exists()) {
        return cacheFile;
      }

      // 3. 提取截图
      bool success = false;
      if (Platform.isMacOS || Platform.isLinux) {
        success = await _extractWithFFmpeg(videoPath, cacheFile.path, position);
      }

      if (success && await cacheFile.exists()) {
        return cacheFile;
      }
      
      return null;
    } catch (e) {
      debugPrint('提取视频截图失败: $e');
      return null;
    }
  }

  static Future<File> _getCacheFile(String outputId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory(path.join(appDir.path, 'metadata', 'thumbnails'));
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }
    return File(path.join(thumbnailsDir.path, '$outputId.jpg'));
  }

  static Future<bool> _extractWithFFmpeg(String videoPath, String outputPath, double position) async {
    try {
      // 1. 先获取视频时长
      final durationCommand = 'ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$videoPath" 2>/dev/null';
      final durationResult = await Process.run('bash', ['-c', durationCommand]);
      
      double videoDuration = 0;
      if (durationResult.exitCode == 0) {
        final durationStr = durationResult.stdout.toString().trim();
        videoDuration = double.tryParse(durationStr) ?? 0;
        debugPrint('📹 视频时长: ${videoDuration.toStringAsFixed(1)}秒');
      }
      
      // 2. 计算截图时间点
      String time;
      if (videoDuration > 0) {
        // 如果成功获取时长，使用百分比位置
        // 默认截取 10% 位置，避免片头黑屏
        final seconds = (videoDuration * position).clamp(5.0, videoDuration - 5.0);
        final hours = (seconds / 3600).floor();
        final minutes = ((seconds % 3600) / 60).floor();
        final secs = (seconds % 60).floor();
        time = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        debugPrint('📸 截图时间点: $time (${(position * 100).toStringAsFixed(0)}%)');
      } else {
        // 如果无法获取时长，使用固定时间点
        time = '00:00:10';
        debugPrint('⚠️ 无法获取视频时长，使用固定时间点: $time');
      }

      // 3. 执行截图
      final command = 'ffmpeg -y -ss $time -i "$videoPath" -vframes 1 -q:v 2 -vf "scale=300:-1" "$outputPath" 2>/dev/null';
      
      final result = await Process.run('bash', ['-c', command]);
      
      if (result.exitCode == 0 && await File(outputPath).exists()) {
        final fileSize = await File(outputPath).length();
        debugPrint('✅ FFmpeg 截图成功 ($fileSize bytes)');
        return true;
      } else {
        debugPrint('❌ FFmpeg 截图失败，退出码: ${result.exitCode}');
        return false;
      }
    } catch (e) {
      debugPrint('FFmpeg 截图异常: $e');
      return false;
    }
  }
}
