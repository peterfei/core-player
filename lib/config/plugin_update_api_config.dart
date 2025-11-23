/// 插件更新API配置
/// 
/// 配置插件更新的API端点和相关设置
class PluginUpdateApiConfig {
  /// API基础URL
  static String _baseUrl = 'https://api.coreplayer.app/v1/plugins';
  static String get baseUrl => _baseUrl;
  
  /// 设置API基础URL (用于测试)
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }
  
  /// 更新检查端点
  static String updateCheckUrl(String pluginId) => '$baseUrl/$pluginId/updates';
  
  /// 批量更新检查端点
  static String get batchUpdateCheckUrl => '$baseUrl/updates/batch';
  
  /// 下载端点
  static String downloadUrl(String pluginId, String version) => 
      '$baseUrl/$pluginId/download/$version';
  
  /// API密钥 (如果需要)
  static const String? apiKey = null; // 设置为实际的API密钥
  
  /// 请求超时时间
  static const Duration timeout = Duration(seconds: 30);
  
  /// 是否启用HTTPS
  static const bool useHttps = true;
  
  /// 是否验证SSL证书
  static const bool verifySsl = true;
  
  /// 获取请求头
  static Map<String, String> getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'CorePlayer/1.0.0',
    };
    
    if (apiKey != null) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    
    return headers;
  }
}

/// 开发环境API配置
class PluginUpdateApiConfigDev extends PluginUpdateApiConfig {
  static const String baseUrl = 'http://localhost:3000/api/v1/plugins';
  static const bool useHttps = false;
  static const bool verifySsl = false;
}

/// 测试环境API配置
class PluginUpdateApiConfigStaging extends PluginUpdateApiConfig {
  static const String baseUrl = 'https://staging-api.coreplayer.app/v1/plugins';
}
