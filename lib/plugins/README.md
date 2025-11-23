# CorePlayer 插件系统

CorePlayer 插件系统是一个强大的、可扩展的架构，允许开发者创建和集成各种功能模块，为用户提供丰富的媒体播放体验。

## 系统架构

### 核心组件

1. **插件核心 (CorePlugin)**: 所有插件的基础抽象类
2. **插件管理器 (PluginManager)**: 负责插件的生命周期管理
3. **插件仓库 (PluginRepository)**: 管理不同类型的插件源
4. **插件注册表 (PluginRegistry)**: 插件注册和发现服务

### 插件分类

#### 内置插件 (Builtin Plugins)
- **字幕插件**: 多格式字幕支持和显示
- **音频效果插件**: 10频段均衡器和音频增强
- **视频增强插件**: 画面增强和优化处理
- **主题管理插件**: UI主题和个性化定制
- **元数据增强插件**: 媒体信息获取和管理
- **媒体服务器插件**: 网络媒体服务器连接

#### 商业插件 (Commercial Plugins)
- **SMB网络存储插件**: SMB/CIFS协议支持
- **高级解码器插件**: 专业级视频解码
- **云同步插件**: 多设备数据同步

#### 第三方插件 (Third-party Plugins)
- **YouTube插件**: YouTube视频播放集成
- **Bilibili插件**: B站视频播放和弹幕支持
- **VLC插件**: VLC播放器集成

## 目录结构

```
lib/plugins/
├── README.md                           # 插件系统文档
├── plugin_registry.dart                # 插件注册表
├── core/                              # 核心插件系统
│   └── plugin_system/                 # 插件系统核心
│       ├── core_plugin.dart           # 插件基类
│       ├── plugin_interface.dart      # 插件接口定义
│       ├── plugin_manager.dart        # 插件管理器
│       └── plugin_repository.dart     # 插件仓库
├── builtin/                           # 内置插件
│   ├── base/                         # 基础插件
│   │   └── media_server_plugin.dart
│   ├── subtitle/                     # 字幕插件
│   │   └── subtitle_plugin.dart
│   ├── audio_effects/                # 音频效果插件
│   │   └── audio_effects_plugin.dart
│   ├── video_processing/             # 视频处理插件
│   │   └── video_enhancement_plugin.dart
│   ├── ui_themes/                    # UI主题插件
│   │   └── theme_plugin.dart
│   └── metadata/                     # 元数据插件
│       └── metadata_enhancer_plugin.dart
├── commercial/                        # 商业插件
│   └── media_server/                 # 媒体服务器插件
│       ├── smb/                      # SMB插件
│       └── ftp/                      # FTP插件
└── third_party/                       # 第三方插件
    ├── README.md
    └── examples/                     # 示例插件
        ├── youtube_plugin/           # YouTube插件
        ├── bilibili_plugin/          # Bilibili插件
        └── vlc_plugin/               # VLC插件
```

## 插件开发指南

### 1. 创建插件类

所有插件必须继承自 `CorePlugin` 基类：

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
    print('MyCustomPlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    // 插件激活逻辑
    print('MyCustomPlugin activated');
  }

  @override
  Future<void> onDeactivate() async {
    // 插件停用逻辑
    print('MyCustomPlugin deactivated');
  }

  @override
  void onDispose() {
    // 清理资源
    print('MyCustomPlugin disposed');
  }

  @override
  Future<bool> healthCheck() async {
    // 健康检查
    return true;
  }
}
```

### 2. 插件生命周期

1. **初始化 (onInitialize)**: 插件创建时的初始化工作
2. **激活 (onActivate)**: 插件被激活时的准备工作
3. **运行时**: 插件提供功能服务的阶段
4. **停用 (onDeactivate)**: 插件被停用时的清理工作
5. **销毁 (onDispose)**: 插件被销毁时的资源释放

### 3. 插件功能

#### 插件元数据
```dart
static final _metadata = PluginMetadata(
  id: 'plugin.unique.id',           // 唯一标识符
  name: '插件名称',                  // 显示名称
  version: '1.0.0',                // 版本号
  description: '插件描述',          // 功能描述
  author: '作者名称',               // 作者信息
  icon: Icons.extension,            // 插件图标
  capabilities: ['feature1', 'feature2'], // 功能能力
  license: PluginLicense.mit,       // 许可证类型
);
```

#### 版本控制
插件支持语义化版本控制 (SemVer)，确保向后兼容性。

#### 依赖管理
插件可以声明对其他插件的依赖关系：
```dart
PluginRepositoryInfo(
  // ... 其他字段
  dependencies: ['builtin.base_plugin', 'builtin.audio_plugin'],
)
```

### 4. 插件通信

#### 事件系统
插件可以通过事件系统进行通信：
```dart
// 发送事件
eventController.add(MyPluginEvent(
  type: MyEventType.customEvent,
  data: {'key': 'value'},
  timestamp: DateTime.now(),
));

// 监听事件
otherPlugin.eventStream.listen((event) {
  // 处理事件
});
```

#### 服务注册
插件可以注册服务供其他插件使用：
```dart
// 注册服务
ServiceRegistry.instance.registerService('myService', myService);

// 获取服务
final service = ServiceRegistry.instance.getService('myService');
```

## 插件管理

### 插件注册
```dart
// 在 plugin_registry.dart 中注册
PluginRepositoryInfo(
  id: 'third_party.my_plugin',
  name: '我的插件',
  version: '1.0.0',
  description: '插件描述',
  path: 'third_party/my_plugin',
  pluginClass: 'MyCustomPlugin',
  repositoryType: PluginRepositoryType.thirdParty,
  isCommunityEdition: true,
  author: '开发者',
  category: 'media',
  tags: ['custom', 'media'],
  dependencies: [],
  minCoreVersion: '1.0.0',
  lastUpdated: DateTime.now(),
)
```

### 插件加载和激活
```dart
// 创建插件实例
final plugin = await PluginRegistry.instance.createPlugin('third_party.my_plugin');

// 激活插件
await PluginRegistry.instance.activatePlugin('third_party.my_plugin');

// 停用插件
await PluginRegistry.instance.deactivatePlugin('third_party.my_plugin');

// 卸载插件
await PluginRegistry.instance.unloadPlugin('third_party.my_plugin');
```

## 插件市场

### 功能特性
- **浏览插件**: 按类别、标签、评分浏览
- **搜索插件**: 关键词搜索和过滤
- **插件评价**: 用户评分和评论
- **一键安装**: 自动下载和安装
- **版本管理**: 插件更新和回滚
- **安全检查**: 插件安全扫描

### 插件分类
- **媒体播放**: 视频解码、音频处理
- **网络服务**: 流媒体、网络存储
- **用户界面**: 主题、界面增强
- **工具类**: 字幕、元数据、转换器
- **游戏娱乐**: 游戏模式、互动功能

## 性能优化

### 懒加载
插件采用懒加载策略，只有在需要时才会被加载和初始化。

### 内存管理
- 插件内存使用监控
- 自动垃圾回收
- 内存泄漏检测

### 并发控制
- 插件并发访问控制
- 线程安全保证
- 性能监控和统计

## 安全机制

### 权限控制
- 插件权限声明
- 运行时权限检查
- 用户授权管理

### 代码审查
- 静态代码分析
- 安全漏洞扫描
- 恶意代码检测

### 沙箱隔离
- 插件运行环境隔离
- 资源访问限制
- 系统调用监控

## 调试和测试

### 调试工具
- 插件日志系统
- 性能分析工具
- 调试断点支持

### 单元测试
```dart
void main() {
  group('MyCustomPlugin', () {
    test('initialization', () async {
      final plugin = MyCustomPlugin();
      await plugin.onInitialize();
      expect(plugin.state, PluginState.initialized);
    });

    test('functionality', () async {
      final plugin = MyCustomPlugin();
      // 测试插件功能
    });
  });
}
```

### 集成测试
- 插件间交互测试
- 性能基准测试
- 兼容性测试

## 最佳实践

### 1. 插件设计
- 保持插件功能单一和专注
- 提供清晰的API接口
- 实现优雅的错误处理

### 2. 资源管理
- 及时释放不需要的资源
- 避免内存泄漏
- 合理使用缓存

### 3. 用户体验
- 提供友好的错误信息
- 支持用户配置选项
- 保持界面响应性

### 4. 版本兼容
- 遵循语义化版本控制
- 提供升级路径
- 保持向后兼容性

## 社区支持

### 开发文档
- [API参考文档](./docs/api.md)
- [插件开发教程](./docs/tutorial.md)
- [示例代码库](./examples/)

### 社区资源
- [插件开发论坛](https://forum.coreplayer.dev)
- [开发者交流群组](https://discord.gg/coreplayer)
- [GitHub仓库](https://github.com/coreplayer/plugins)

### 技术支持
- 插件开发问题咨询
- 技术文档和教程
- 代码审查和建议

## 更新日志

### v2.0.0 (2024-01-15)
- 重构插件系统架构
- 添加插件市场功能
- 改进性能和内存管理

### v1.5.0 (2023-12-01)
- 添加第三方插件支持
- 改进插件通信机制
- 增强安全控制

### v1.0.0 (2023-10-01)
- 初始版本发布
- 基础插件系统实现
- 内置插件集合

---

通过这个插件系统，CorePlayer 能够提供高度可扩展和定制化的媒体播放体验。无论是个人开发者还是企业用户，都可以根据需要开发和使用各种插件来增强播放器功能。