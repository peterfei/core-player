import 'dart:io';
import 'package:yinghe_player/models/codec_info.dart';

/// 系统编解码器检测服务
///
/// 🔥 插件基础设施服务 - 供插件使用
///
/// 检测系统支持的编解码器。由于 media_kit 没有提供直接查询所有可用解码器的 API，
/// 此服务返回底层引擎 (mpv/ffmpeg) 在不同平台上通常支持的编解码器列表。
///
/// 这是一个基础设施服务，供插件（如 HEVC 高级解码器插件包）使用来了解系统编解码器能力。
///
/// 检测的编解码器：
/// - 视频: H.264, HEVC/H.265, VP9, AV1, MPEG4
/// - 音频: AAC, MP3, FLAC, Opus, Vorbis, AC3
/// - 硬件加速: 根据平台自动检测支持情况
///
/// 插件使用示例：
/// ```dart
/// final detector = SystemCodecDetectorService();
/// final codecs = await detector.detectSupportedCodecs();
///
/// final hevcCodecs = codecs.where((c) =>
///   c.type == CodecType.video && c.codec == 'hevc');
///
/// if (hevcCodecs.isNotEmpty && hevcCodecs.first.isHardwareAccelerated) {
///   // 系统支持 HEVC 硬件解码
/// }
/// ```
class SystemCodecDetectorService {
  /// Detects the list of supported video and audio codecs based on the platform.
  Future<List<CodecInfo>> detectSupportedCodecs() async {
    print("Detecting supported codecs for ${Platform.operatingSystem}...");

    // Common base codecs supported by media_kit's backend
    List<CodecInfo> codecs = [
      // Video Codecs
      const CodecInfo(codec: 'h264', profile: 'High', level: '5.2', bitDepth: 8, type: CodecType.video),
      const CodecInfo(codec: 'hevc', profile: 'Main 10', level: '6.1', bitDepth: 10, type: CodecType.video),
      const CodecInfo(codec: 'vp9', profile: 'Profile 2', level: '6.1', bitDepth: 10, type: CodecType.video),
      const CodecInfo(codec: 'av1', profile: 'Main', level: '6.0', bitDepth: 10, type: CodecType.video),
      const CodecInfo(codec: 'mpeg4', profile: 'Advanced Simple', level: '5', bitDepth: 8, type: CodecType.video),

      // Audio Codecs
      const CodecInfo(codec: 'aac', profile: 'LC', level: 'N/A', bitDepth: 0, type: CodecType.audio),
      const CodecInfo(codec: 'mp3', profile: 'N/A', level: 'N/A', bitDepth: 0, type: CodecType.audio),
      const CodecInfo(codec: 'flac', profile: 'N/A', level: 'N/A', bitDepth: 0, type: CodecType.audio),
      const CodecInfo(codec: 'opus', profile: 'N/A', level: 'N/A', bitDepth: 0, type: CodecType.audio),
      const CodecInfo(codec: 'vorbis', profile: 'N/A', level: 'N/A', bitDepth: 0, type: CodecType.audio),
      const CodecInfo(codec: 'ac3', profile: 'N/A', level: 'N/A', bitDepth: 0, type: CodecType.audio),
    ];

    // Platform-specific hardware acceleration adjustments
    if (Platform.isMacOS || Platform.isIOS) {
      _applyHardwareAcceleration(codecs, ['h264', 'hevc'], 'VideoToolbox');
    } else if (Platform.isAndroid) {
      _applyHardwareAcceleration(codecs, ['h264', 'hevc', 'vp9', 'av1'], 'MediaCodec');
    } else if (Platform.isWindows) {
      _applyHardwareAcceleration(codecs, ['h264', 'hevc', 'vp9', 'av1'], 'D3D11VA');
    } else if (Platform.isLinux) {
      _applyHardwareAcceleration(codecs, ['h264', 'hevc', 'vp9'], 'VAAPI');
    }

    print("Codec detection complete. Found ${codecs.length} common codecs.");
    return codecs;
  }

  void _applyHardwareAcceleration(List<CodecInfo> codecs, List<String> hwCodecs, String hwType) {
    for (int i = 0; i < codecs.length; i++) {
      if (hwCodecs.contains(codecs[i].codec)) {
        codecs[i] = codecs[i].copyWith(
          isHardwareAccelerated: true,
          hardwareAccelerationType: hwType,
        );
      }
    }
  }
}