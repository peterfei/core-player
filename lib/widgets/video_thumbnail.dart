import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VideoThumbnail extends StatelessWidget {
  final String? thumbnailPath;
  final double width;
  final double height;
  final Widget placeholder;
  final BorderRadius? borderRadius;

  const VideoThumbnail({
    super.key,
    this.thumbnailPath,
    this.width = 120,
    this.height = 90,
    required this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailPath == null) {
      return placeholder;
    }

    // Web平台处理Base64缩略图
    if (kIsWeb && thumbnailPath!.startsWith('data:image/')) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: _buildBase64Image(thumbnailPath!),
      );
    }

    // 桌面/移动平台处理文件路径
    if (!kIsWeb) {
      final file = File(thumbnailPath!);
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return placeholder;
          },
        ),
      );
    }

    return placeholder;
  }

  Widget _buildBase64Image(String base64String) {
    try {
      // 提取Base64数据
      final UriData? data = Uri.parse(base64String).data;
      if (data != null) {
        final Uint8List bytes = data.contentAsBytes();
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return placeholder;
          },
        );
      }
    } catch (e) {
      // Base64解析失败，返回占位符
    }

    return placeholder;
  }
}