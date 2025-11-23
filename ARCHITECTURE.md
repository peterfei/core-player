# 酷影播放器 (CorePlayer) 项目架构文档

## 目录
- [1. 总体架构](#1-总体架构)
- [2. 版本架构](#2-版本架构)
- [3. 插件系统架构](#3-插件系统架构)
- [4. 核心模块](#4-核心模块)
- [5. 数据流](#5-数据流)
- [6. 技术栈](#6-技术栈)

---

## 1. 总体架构

CorePlayer 采用分层架构设计，主要分为以下几层：

```
┌─────────────────────────────────────────────────────────────┐
│                        展示层 (Presentation)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ 主界面    │  │ 播放器    │  │ 媒体库    │  │ 设置      │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                              ↓↑
┌─────────────────────────────────────────────────────────────┐
│                      业务逻辑层 (Business Logic)              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ 播放管理  │  │ 媒体服务器 │  │ 缓存管理  │  │ 字幕处理  │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                              ↓↑
┌─────────────────────────────────────────────────────────────┐
│                       插件系统层 (Plugin System)              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │ 内置插件  │  │ 商业插件  │  │ 第三方插件 │                   │
│  │(Community)│  │(Pro Only) │  │(Optional) │                   │
│  └──────────┘  └──────────┘  └──────────┘                   │
└─────────────────────────────────────────────────────────────┘
                              ↓↑
┌─────────────────────────────────────────────────────────────┐
│                      数据访问层 (Data Access)                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ 本地存储  │  │ 网络请求  │  │ 文件系统  │  │ 数据库    │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 版本架构

CorePlayer 采用**双版本策略**，通过编译时宏定义实现版本差异化：

### 2.1 版本划分

```dart
// lib/core/plugin_system/plugin_loader.dart
class EditionConfig {
  static const String community = 'community';
  static const String pro = 'pro';
  
  static String get currentEdition {
    return const String.fromEnvironment('EDITION', defaultValue: community);
  }
  
  static bool get isCommunityEdition => currentEdition == community;
  static bool get isProEdition => currentEdition == pro;
}
```

### 2.2 编译方式

```bash
# 社区版（默认）
flutter build macos

# 专业版
flutter build macos --dart-define=EDITION=pro
```

### 2.3 功能差异对照表

| 功能模块 | 社区版 | 专业版 |
|---------|-------|--------|
| 本地视频播放 | ✅ | ✅ |
| 网络视频播放 | ✅ | ✅ |
| 播放历史 | ✅ | ✅ |
| 字幕功能 | ✅ | ✅ |
| 媒体库管理 | ✅ | ✅ |
| SMB/CIFS | ❌ (显示升级提示) | ✅ |
| Emby 集成 | ❌ | ✅ |
| Jellyfin 集成 | ❌ | ✅ |
| Plex 集成 | ❌ | ✅ |
| HEVC 解码器 | ❌ | ✅ |
| AI 智能字幕 | ❌ | ✅ |

### 2.4 版本限制实现

#### 2.4.1 服务层限制

```dart
// lib/services/file_source_factory.dart
class FileSourceFactory {
  static FileSource? createFromConfig(MediaServerConfig config) {
    switch (config.type.toLowerCase()) {
      case 'smb':
        // 社区版不支持SMB功能
        if (EditionConfig.isCommunityEdition) {
          return null;  // 返回null触发错误处理
        }
        return SMBFileSource(...);
      // 其他类型...
    }
  }
}
```

#### 2.4.2 UI层友好提示

```dart
// lib/screens/series_detail_page.dart
void _playEpisode(Episode episode) async {
  // 检查是否为 SMB 且为社区版
  if (serverConfig.type.toLowerCase() == 'smb' && 
      EditionConfig.isCommunityEdition) {
    showDialog(
      context: context,
      builder: (context) => const UpgradeDialog(),  // 显示升级对话框
    );
    return;
  }
  // 继续播放逻辑...
}
```

#### 2.4.3 统一升级对话框组件

```dart
// lib/widgets/upgrade_dialog.dart
class UpgradeDialog extends StatelessWidget {
  // 显示专业版功能列表
  // - SMB/CIFS 网络共享访问
  // - FTP/SFTP 安全文件传输
  // - NFS 网络文件系统支持
  // - WebDAV 协议支持
  // - HEVC/H.265 专业解码器
  // - AI 智能字幕
  // - 多设备同步
}
```

---

## 3. 插件系统架构

### 3.1 三层插件仓库结构

```
lib/core/plugin_system/
└── plugins/
    ├── builtin/              # 内置插件（社区版 + 专业版）
    │   ├── subtitle/         # 字幕插件
    │   ├── audio_effects/    # 音频效果
    │   └── video_processing/ # 视频处理
    │
    ├── commercial/           # 商业插件（仅专业版）
    │   └── media_server/
    │       ├── smb/          # SMB 插件
    │       ├── emby/         # Emby 插件
    │       └── jellyfin/     # Jellyfin 插件
    │
    └── third_party/          # 第三方插件（可选）
        └── examples/
            ├── youtube_plugin/
            └── bilibili_plugin/
```

### 3.2 插件生命周期

```
┌─────────────┐
│   未加载     │
└──────┬──────┘
       │ load()
       ↓
┌─────────────┐
│   已注册     │ ←──────────────┐
└──────┬──────┘                 │
       │ initialize()           │
       ↓                        │
┌─────────────┐                 │
│   已初始化   │                 │
└──────┬──────┘                 │
       │ activate()             │
       ↓                        │
┌─────────────┐                 │
│   已激活     │ ────────────────┘
└──────┬──────┘   deactivate()
       │
       │ dispose()
       ↓
┌─────────────┐
│   已销毁     │
└─────────────┘
```

### 3.3 插件加载器

```dart
// lib/core/plugin_system/plugin_loader.dart
class PluginLoader {
  Future<void> initialize() async {
    await _loadBuiltInPlugins();
    if (_config.autoActivate) {
      await _autoActivatePlugins();
    }
  }
  
  List<CorePlugin> _getBuiltInPlugins() {
    if (EditionConfig.isCommunityEdition) {
      return _getCommunityEditionPlugins();  // 仅内置插件
    } else {
      return _getProEditionPlugins();        // 内置 + 商业插件
    }
  }
}
```

### 3.4 插件注册表

```dart
// lib/core/plugin_system/plugin_registry.dart
class PluginRegistry {
  final Map<String, CorePlugin> _plugins = {};
  final Map<String, List<String>> _dependencies = {};
  
  Future<void> register(CorePlugin plugin);
  Future<void> activateWithDependencies(String pluginId);
  Future<void> deactivateWithDependents(String pluginId);
}
```

---

## 4. 核心模块

### 4.1 目录结构

```
lib/
├── main.dart                              # 应用入口
├── core/                                  # 核心系统
│   ├── plugin_system/                     # 插件系统
│   │   ├── plugin_loader.dart             # 插件加载器
│   │   ├── plugin_registry.dart           # 插件注册表
│   │   ├── plugin_interface.dart          # 插件接口
│   │   ├── core_plugin.dart               # 核心插件基类
│   │   └── plugins/                       # 插件实现
│   │       ├── builtin/                   # 内置插件
│   │       ├── commercial/                # 商业插件
│   │       └── third_party/               # 第三方插件
│   └── edition/                           # 版本控制
│       └── edition_config.dart            # 版本配置
│
├── screens/                               # 界面层
│   ├── home_screen.dart                   # 主界面
│   ├── player_screen.dart                 # 播放器
│   ├── series_detail_page.dart            # 剧集详情
│   ├── media_library_screen.dart          # 媒体库
│   ├── plugin_manager_screen.dart         # 插件管理
│   └── settings_screen.dart               # 设置
│
├── services/                              # 业务逻辑层
│   ├── local_proxy_server.dart            # 本地代理服务器
│   ├── file_source_factory.dart           # 文件源工厂
│   ├── media_server_service.dart          # 媒体服务器管理
│   ├── network_stream_service.dart        # 网络流服务
│   ├── video_cache_service.dart           # 视频缓存
│   ├── subtitle_service.dart              # 字幕服务
│   └── file_source/                       # 文件源实现
│       ├── smb_file_source.dart           # SMB 文件源
│       └── smb_connection_pool.dart       # SMB 连接池
│
├── widgets/                               # UI组件
│   ├── upgrade_dialog.dart                # 升级对话框（统一组件）
│   ├── modern_video_card.dart             # 视频卡片
│   ├── modern_sidebar.dart                # 侧边栏
│   └── episode_card.dart                  # 剧集卡片
│
└── models/                                # 数据模型
    ├── media_server_config.dart           # 媒体服务器配置
    ├── episode.dart                       # 剧集模型
    ├── series.dart                        # 系列模型
    └── playback_history.dart              # 播放历史
```

### 4.2 媒体服务器访问流程

```
用户点击播放
    ↓
SeriesDetailPage._playEpisode()
    ↓
检查版本和服务器类型
    ↓
┌──────────────────────────────────┐
│ 社区版 + SMB?                     │
│ ✓ → 显示 UpgradeDialog → 返回     │
│ ✗ → 继续                          │
└──────────────────────────────────┘
    ↓
启动 LocalProxyServer
    ↓
生成代理 URL
    ↓
打开 PlayerScreen
    ↓
LocalProxyServer 处理请求
    ↓
FileSourceFactory.createFromConfig()
    ↓
┌──────────────────────────────────┐
│ 社区版?                           │
│ ✓ → 返回 null → HTTP 500          │
│ ✗ → 创建 SMBFileSource             │
└──────────────────────────────────┘
    ↓
SMBConnectionPool 管理连接
    ↓
读取文件数据 → 流式传输到播放器
```

---

## 5. 数据流

### 5.1 本地视频播放流程

```
文件选择器
    ↓
File 对象
    ↓
PlayerScreen
    ↓
MPV 播放引擎
    ↓
硬件解码
    ↓
视频渲染
```

### 5.2 SMB 视频播放流程（专业版）

```
媒体服务器配置
    ↓
Episode 对象（含 sourceId）
    ↓
SeriesDetailPage
    ↓
版本检查
    ↓
LocalProxyServer.getProxyUrl()
    ↓
http://192.168.x.x:xxxxx/video/xxx
    ↓
PlayerScreen（播放代理 URL）
    ↓
LocalProxyServer 接收请求
    ↓
FileSourceFactory（根据 sourceId 查找配置）
    ↓
SMBFileSource.openRead()
    ↓
SMBConnectionPool（连接管理）
    ↓
dart_smb 库（底层协议）
    ↓
NAS 设备
    ↓
数据流 → LocalProxyServer → MPV
```

### 5.3 网络视频缓存流程

```
网络 URL
    ↓
NetworkStreamService
    ↓
CacheDownloadService
    ↓
VideoCacheService
    ↓
本地缓存文件
    ↓
播放器优先加载缓存
```

---

## 6. 技术栈

### 6.1 核心框架
- **Flutter**: 3.38.1（跨平台 UI 框架）
- **Dart**: 3.10.0（编程语言）

### 6.2 视频播放
- **media_kit**: 视频播放引擎（基于 MPV）
- **media_kit_video**: 视频渲染组件
- **media_kit_libs_macos_video**: macOS 平台库

### 6.3 网络和文件访问
- **http**: HTTP 请求
- **dio**: 高级网络库
- **shelf**: 本地 HTTP 服务器（代理服务器）
- **dart_smb**: SMB 协议支持（专业版）

### 6.4 数据存储
- **hive**: 轻量级 NoSQL 数据库
- **sqflite**: SQLite 数据库
- **shared_preferences**: 键值对存储

### 6.5 UI 组件
- **Material Design 3**: 现代化设计语言
- **file_picker**: 文件选择器
- **cached_network_image**: 网络图片缓存

### 6.6 字幕处理
- **charset_converter**: 字符编码转换
- **subtitle_wrapper_package**: 字幕渲染

### 6.7 开发工具
- **flutter_lints**: 代码规范检查
- **test**: 单元测试框架

---

## 7. 版本控制与发布

### 7.1 版本号规范

遵循语义化版本控制（Semantic Versioning）：`MAJOR.MINOR.PATCH`

- **MAJOR**: 重大架构变更或不兼容的 API 修改
- **MINOR**: 新功能添加，向后兼容
- **PATCH**: 错误修复和小改进

### 7.2 发布流程

```
开发 → 测试 → 构建社区版 → 构建专业版 → 发布
         ↓
    单元测试
    集成测试
    UI 测试
```

### 7.3 构建命令

```bash
# 社区版
flutter build macos --release

# 专业版
flutter build macos --release --dart-define=EDITION=pro
```

---

## 8. 安全性设计

### 8.1 版本验证
- 编译时通过 `--dart-define` 注入版本标识
- 运行时通过 `EditionConfig` 检查版本

### 8.2 商业功能保护
- 商业插件代码仅在专业版构建中包含
- 运行时双重检查：插件加载器 + 服务层

### 8.3 数据安全
- 敏感配置（服务器密码）使用 Hive 加密存储
- 网络传输支持 HTTPS

---

## 9. 性能优化

### 9.1 懒加载
- 插件系统支持懒加载
- 媒体库缩略图按需加载

### 9.2 缓存策略
- 网络图片缓存
- 视频缓存（边播边缓存）
- 元数据缓存

### 9.3 连接池管理
- SMB 连接池（专业版）
- HTTP 连接复用

---

## 10. 未来架构演进

### 10.1 微服务化（v2.0）
- 将代理服务器独立为独立进程
- 支持分布式缓存

### 10.2 插件市场（v1.5）
- 在线插件商店
- 一键安装和更新

### 10.3 跨设备同步（v2.0）
- 播放进度云同步
- 配置跨设备同步

---

**文档版本**: 1.0  
**最后更新**: 2025-01-24  
**维护者**: peterfei
