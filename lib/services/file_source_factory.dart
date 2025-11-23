import '../models/media_server_config.dart';
import '../core/plugin_system/plugin_loader.dart';
import 'file_source/file_source.dart';
import 'file_source/smb_file_source.dart';

/// 工厂类，用于从 MediaServerConfig 创建对应的 FileSource
class FileSourceFactory {
  /// 从服务器配置创建对应的 FileSource
  ///
  /// 目前支持的类型：
  /// - SMB: 创建 SMBFileSource (仅专业版)
  ///
  /// 返回 null 如果服务器类型不支持
  static FileSource? createFromConfig(MediaServerConfig config) {
    switch (config.type.toLowerCase()) {
      case 'smb':
        // 社区版不支持SMB功能
        if (EditionConfig.isCommunityEdition) {
          return null;
        }

        return SMBFileSource(
          id: config.id,
          name: config.name,
          host: config.url, // url 字段存储的是解析后的纯主机名
          port: config.port ?? 445,
          username: config.username.isEmpty ? null : config.username,
          password: config.token.isEmpty ? null : config.token,
          domain: config.domain,
        );

      // TODO: 添加更多服务器类型支持
      // case 'emby':
      // case 'jellyfin':
      // case 'plex':

      default:
        return null;
    }
  }
}
