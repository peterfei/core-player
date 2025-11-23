# 第三方插件目录

此目录用于存放社区开发的第三方插件。

## 目录结构

```
third_party/
├── README.md
├── examples/           # 示例插件
│   ├── youtube_plugin/
│   ├── bilibili_plugin/
│   └── vlc_plugin/
└── external/          # 外部插件源
```

## 插件开发指南

### 1. 创建新插件
```dart
import 'package:flutter/material.dart';
import '../../../core/plugin_system/core_plugin.dart';

class MyCustomPlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'third_party.my_custom_plugin',
    name: '我的自定义插件',
    version: '1.0.0',
    description: '插件功能描述',
    author: '作者名称',
    icon: Icons.extension,
    capabilities: ['custom_capability'],
    license: PluginLicense.mit,
  );

  @override
  PluginMetadata get metadata => _metadata;

  @override
  Future<void> onInitialize() async {
    // 插件初始化逻辑
  }

  @override
  Future<void> onActivate() async {
    // 插件激活逻辑
  }

  @override
  Future<void> onDeactivate() async {
    // 插件停用逻辑
  }

  @override
  void onDispose() {
    // 清理资源
  }
}
```

### 2. 插件注册
在 `lib/plugins/plugin_registry.dart` 中注册你的插件：

```dart
// 第三方插件
PluginRepositoryInfo(
  id: 'third_party.my_custom_plugin',
  name: '我的自定义插件',
  version: '1.0.0',
  description: '插件功能描述',
  path: 'third_party/my_custom_plugin',
  pluginClass: 'MyCustomPlugin',
  repositoryType: PluginRepositoryType.thirdParty,
  isCommunityEdition: true,
  author: '作者名称',
  category: 'media',
  tags: ['custom', 'media'],
  downloadUrl: 'https://github.com/username/plugin-repo',
  dependencies: [],
  minCoreVersion: '1.0.0',
  lastUpdated: DateTime.now(),
),
```

### 3. 提交插件
- Fork 项目仓库
- 在 `third_party` 目录下创建插件文件夹
- 提交 Pull Request
- 通过审核后包含在插件市场中

## 插件示例

### YouTube 插件
- 支持YouTube视频播放
- 播放列表管理
- 字幕下载

### Bilibili 插件
- 支持Bilibili视频播放
- 弹幕显示
- 分P播放支持

### VLC 插件
- VLC播放器集成
- 多格式支持
- 流媒体播放

## 插件分发

### 插件市场
通过内置插件市场，用户可以：
- 浏览可用插件
- 搜索特定功能插件
- 一键安装和卸载
- 查看插件评价和使用统计

### 版本管理
- 支持插件版本更新
- 自动检查兼容性
- 安全更新推送

## 质量标准

### 代码质量
- 遵循 Dart 代码规范
- 包含完整的文档注释
- 通过所有静态分析检查

### 性能要求
- 插件初始化时间 < 2秒
- 内存占用 < 50MB
- 不影响主应用性能

### 安全检查
- 代码安全扫描
- 恶意行为检测
- 权限使用审核

## 社区支持

- 插件开发文档
- 示例代码库
- 社区论坛支持
- 开发者交流群组