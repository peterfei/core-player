# 插件更新系统

## 📋 概述

插件更新系统支持检测、下载和安装插件更新。目前支持两种模式:

1. **开发模式 (Mock)** - 使用本地Mock数据,无需后端服务器
2. **生产模式 (Real API)** - 连接真实的更新API服务器

## 🔧 开发模式配置

### 启用/禁用Mock模式

在 `lib/services/update/mock_update_api.dart` 中:

```dart
// 启用Mock模式(默认)
MockUpdateApi.enabled = true;

// 禁用Mock模式(使用真实API)
MockUpdateApi.enabled = false;
```

### Mock数据配置

Mock数据库默认包含以下插件的更新信息:

| 插件ID | 当前版本 | 最新版本 | 特性 |
|--------|----------|----------|------|
| `com.coreplayer.smb` | 1.0.0 | 1.1.0 | 普通更新 |
| `com.coreplayer.emby` | 1.0.0 | 1.2.0 | 安全更新 ⚠️ |
| `third_party.youtube` | 2.0.0 | 2.1.0 | 普通更新 |

### 添加自定义Mock数据

```dart
import 'package:yinghe_player/services/update/mock_update_api.dart';

// 添加新的Mock插件
MockUpdateApi.addMockPlugin(
  MockPluginVersionInfo(
    pluginId: 'com.example.plugin',
    currentVersion: '1.0.0',
    latestVersion: '1.5.0',
    changelog: ['新功能', '修复Bug'],
    downloadUrl: 'https://example.com/plugin.zip',
    downloadSize: 2097152, // 2MB
    isSecurityUpdate: false,
    isMandatory: false,
    isBreakingChange: false,
    minAppVersion: '2.0.0',
    releaseDate: DateTime.now(),
    priority: 5,
  ),
);
```

## 🌐 生产模式配置

### API端点配置

在 `lib/config/plugin_update_api_config.dart` 中:

```dart
// 开发环境
static String _baseUrl = 'http://localhost:8080/v1/plugins';

// 生产环境
static String _baseUrl = 'https://api.coreplayer.app/v1/plugins';
```

### API接口规范

#### 检查更新
```
GET /v1/plugins/{pluginId}/updates
Headers:
  X-Current-Version: 1.0.0
  User-Agent: CorePlayer/1.0.0

Response 200:
{
  "pluginId": "com.coreplayer.smb",
  "currentVersion": "1.0.0",
  "latestVersion": "1.1.0",
  "hasUpdate": true,
  "changelog": ["新功能", "Bug修复"],
  "downloadUrl": "https://cdn.example.com/plugin.zip",
  "downloadSize": 5242880,
  "isSecurityUpdate": false,
  "isMandatory": false,
  "isBreakingChange": false,
  "minAppVersion": "2.0.0",
  "releaseDate": "2024-01-15T00:00:00Z",
  "priority": 5
}

Response 404:
插件不存在
```

## 🧪 测试

### 测试更新检测

```dart
import 'package:yinghe_player/services/update/update_detector.dart';

final detector = UpdateDetector();
await detector.initialize();

// 检查单个插件
final updateInfo = await detector.checkForUpdate(
  pluginId: 'com.coreplayer.smb',
  currentVersion: '1.0.0',
);

if (updateInfo != null && updateInfo.hasUpdate) {
  print('发现新版本: ${updateInfo.latestVersion}');
}

// 检查所有插件
final updates = await detector.checkAllUpdates(
  plugins: {
    'com.coreplayer.smb': '1.0.0',
    'com.coreplayer.emby': '1.0.0',
  },
);

print('发现 ${updates.length} 个可用更新');
```

### 测试场景

1. **有可用更新**
   ```dart
   // SMB插件: 1.0.0 → 1.1.0
   // 预期: 返回UpdateInfo, hasUpdate=true
   ```

2. **已是最新版本**
   ```dart
   // SMB插件: 1.1.0 → 1.1.0
   // 预期: 返回UpdateInfo, hasUpdate=false
   ```

3. **插件不存在**
   ```dart
   // 未知插件
   // 预期: 返回null
   ```

4. **安全更新优先级**
   ```dart
   // Emby插件有安全更新
   // 预期: isSecurityUpdate=true, 在列表中排序靠前
   ```

## 📊 日志输出

### 正常流程
```
🔍 批量检查更新: 1个插件
🔍 检查插件更新: com.coreplayer.smb (当前版本: 1.0.0)
🔧 使用Mock数据检查更新
🆕 发现新版本: 1.1.0
✅ 发现 1 个可用更新
```

### 无更新
```
🔍 检查插件更新: com.coreplayer.smb (当前版本: 1.1.0)
🔧 使用Mock数据检查更新
✅ 已是最新版本
✅ 发现 0 个可用更新
```

### Mock数据不存在
```
🔍 检查插件更新: unknown.plugin (当前版本: 1.0.0)
🔧 使用Mock数据检查更新
⚠️ Mock数据库中无此插件: unknown.plugin
✅ 发现 0 个可用更新
```

## 🔄 切换到生产模式

当准备部署时:

1. **禁用Mock模式**
   ```dart
   MockUpdateApi.enabled = false;
   ```

2. **配置生产API**
   ```dart
   PluginUpdateApiConfig.setBaseUrl('https://api.coreplayer.app/v1/plugins');
   ```

3. **部署后端API服务器**
   - 实现 `/v1/plugins/{pluginId}/updates` 端点
   - 返回符合规范的JSON响应
   - 配置HTTPS和CDN

## 🐛 故障排查

### 问题: "插件不存在"
```
⚠️ 插件不存在: com.coreplayer.smb
```

**解决方案**:
1. 检查插件ID是否正确
2. 如果使用Mock模式,确保插件在Mock数据库中
3. 如果使用真实API,检查后端是否有该插件的数据

### 问题: "网络请求失败"
```
❌ 网络请求失败: SocketException
```

**解决方案**:
1. 检查网络连接
2. 检查API URL是否正确
3. 检查防火墙设置
4. 考虑切换到Mock模式进行开发

## 📚 相关文件

- `update_detector.dart` - 更新检测器
- `update_downloader.dart` - 更新下载器
- `hot_installer.dart` - 热更新安装器
- `mock_update_api.dart` - Mock API数据提供者
- `../config/plugin_update_api_config.dart` - API配置
- `../../models/update/update_models.dart` - 数据模型

## 🎯 下一步

- [ ] 实现下载功能
- [ ] 实现热更新安装
- [ ] 实现版本回滚
- [ ] 添加更新通知
- [ ] 实现自动更新配置
- [ ] 部署生产环境API服务器
