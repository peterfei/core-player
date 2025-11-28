import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../models/cover_gradient.dart';
import '../services/cover_fallback_service.dart';

class DefaultCoverGenerator {
  static const double _width = 300;
  static const double _height = 450;

  /// 生成默认封面
  /// [title] 剧集标题
  /// [outputId] 输出ID（通常是剧集ID或路径哈希）
  /// [subtitle] 副标题（可选，如"第1季"）
  static Future<File?> generateCover(String title, String outputId, {String? subtitle}) async {
    try {
      if (kIsWeb) return null;

      // 1. 检查缓存
      final cacheFile = await _getCacheFile(outputId);
      if (await cacheFile.exists()) {
        return cacheFile;
      }

      // 2. 准备绘制
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(_width, _height);

      // 3. 绘制背景
      final gradient = CoverGradient.fromString(title);
      final paint = Paint()
        ..shader = gradient.toLinearGradient().createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // 4. 绘制装饰纹理（可选，增加质感）
      _drawPattern(canvas, size);

      // 5. 绘制文字
      final cleanedTitle = _cleanTitle(title);
      _drawText(canvas, size, cleanedTitle, subtitle);

      // 6. 导出图片
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return null;

      // 7. 保存文件
      final buffer = byteData.buffer.asUint8List();
      await cacheFile.writeAsBytes(buffer);

      return cacheFile;
    } catch (e) {
      debugPrint('生成默认封面失败: $e');
      return null;
    }
  }

  static Future<File> _getCacheFile(String outputId) async {
    // 假设 CoverFallbackService 已经初始化并公开了目录，或者我们重新获取
    // 为了简单，我们这里重新获取路径，或者最好在 CoverFallbackService 中提供获取路径的方法
    // 这里我们暂时使用 getApplicationDocumentsDirectory
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(path.join(appDir.path, 'metadata', 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    // 使用 _v2 后缀强制刷新缓存，解决旧版生成器产生的标题问题
    return File(path.join(coversDir.path, '${outputId}_v2.jpg'));
  }

  static void _drawPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 100, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), 80, paint);
  }

  static void _drawText(Canvas canvas, Size size, String title, String? subtitle) {
    // 绘制标题
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          offset: Offset(0, 2),
          blurRadius: 4,
          color: Colors.black.withOpacity(0.3),
        ),
      ],
    );

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: '...',
    );

    titlePainter.layout(maxWidth: size.width - 40);
    
    // 计算垂直居中位置
    double totalHeight = titlePainter.height;
    if (subtitle != null && subtitle.isNotEmpty) {
      totalHeight += 30; // 间距 + 副标题高度估计
    }
    
    double startY = (size.height - totalHeight) / 2;

    titlePainter.paint(canvas, Offset((size.width - titlePainter.width) / 2, startY));

    // 绘制副标题
    if (subtitle != null && subtitle.isNotEmpty) {
      final subStyle = TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.2),
          ),
        ],
      );

      final subPainter = TextPainter(
        text: TextSpan(text: subtitle, style: subStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      subPainter.layout(maxWidth: size.width - 40);
      subPainter.paint(canvas, Offset((size.width - subPainter.width) / 2, startY + titlePainter.height + 10));
    }
  }

  static String _cleanTitle(String title) {
    var cleaned = title;

    // 1. 移除所有方括号内容 (如 [高清电影天堂...] 或 【首发...】)
    // 移除 ^ 锚点，匹配所有位置
    cleaned = cleaned.replaceAll(RegExp(r'(\[.*?\]|【.*?】)'), '');

    // 2. 移除网址 (加强版，匹配更多格式)
    cleaned = cleaned.replaceAll(RegExp(r'([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}'), '');

    // 3. 移除常见的发布信息标签 (不区分大小写)
    // 增加更多关键词，优化匹配逻辑
    final techSpecs = RegExp(
      r'(S\d+|1080p|2160p|4k|60fps|WEBRip|BluRay|HDTV|x264|x265|HEVC|AAC|DTS|HDR|Remux|H\.264|H\.265)', 
      caseSensitive: false,
    );
    
    // 如果包含技术参数，截断之前的内容
    if (techSpecs.hasMatch(cleaned)) {
      final match = techSpecs.firstMatch(cleaned);
      if (match != null && match.start > 0) {
        cleaned = cleaned.substring(0, match.start);
      }
    }

    // 4. 替换点号、下划线为空格
    cleaned = cleaned.replaceAll(RegExp(r'[._]'), ' ');

    // 5. 移除多余空格
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }
}
