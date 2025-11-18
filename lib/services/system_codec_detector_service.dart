import 'dart:io';
import 'package:yinghe_player/models/codec_info.dart';

/// A service to detect system-supported codecs.
///
/// Since media_kit does not provide a direct API to query all available decoders,
/// this service returns a curated list of codecs commonly supported by the
/// underlying engine (mpv/ffmpeg) on different platforms.
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