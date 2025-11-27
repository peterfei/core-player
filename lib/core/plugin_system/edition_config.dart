/// 应用版本配置
class EditionConfig {
  static const String community = 'community';
  static const String pro = 'pro';

  static String get currentEdition {
    const edition = String.fromEnvironment('EDITION', defaultValue: community);
    return edition;
  }

  static bool get isCommunityEdition => currentEdition == community;
  static bool get isProEdition => currentEdition == pro || currentEdition == 'prod';

  /// 检查特定版本是否可用
  static bool isEditionAvailable(String edition) {
    return currentEdition == edition;
  }
}
