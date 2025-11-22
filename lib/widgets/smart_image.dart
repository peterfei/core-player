import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';

class SmartImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;

  const SmartImage({
    Key? key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return _buildPlaceholder();
    }

    if (path!.startsWith('http://') || path!.startsWith('https://')) {
      return Image.network(
        path!,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => _buildError(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    } else if (path!.startsWith('smb://')) {
      // SMB 图片暂不支持直接预览，显示占位符
      // TODO: 实现 SMB 图片加载器
      return _buildPlaceholder(icon: Icons.network_locked);
    } else {
      // 假设是本地文件
      return Image.file(
        File(path!),
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => _buildError(),
      );
    }
  }

  Widget _buildPlaceholder({IconData icon = Icons.image}) {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: AppColors.surfaceVariant,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textTertiary.withOpacity(0.5),
              size: 24,
            ),
          ),
        );
  }

  Widget _buildError() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: AppColors.surfaceVariant,
          child: Center(
            child: Icon(
              Icons.broken_image,
              color: AppColors.error.withOpacity(0.5),
              size: 24,
            ),
          ),
        );
  }
}
