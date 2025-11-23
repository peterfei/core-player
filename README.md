# 酷影播放器 (CorePlayer)

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.38.1-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%7CAndroid%7CWeb%7CWindows%7CmacOS%7CLinux-orange.svg)](#特性)

**酷影播放器 CorePlayer** - 酷炫影音，畅享无限

*极致播放，智能管理，跨界体验*

[English](./README_EN.md) | 中文

</div>

## 🎯 品牌理念

**酷影**——酷炫的影音体验，让观影更加精彩。

- **酷**：酷炫、先进，代表我们的现代化设计和技术实力
- **影**：影音、视频，我们的核心服务

我们致力于打造最酷炫、最智能、最流畅的视频播放和管理平台，让每一次观影都成为享受。

## ✨ 核心特性

### 🎬 本地播放
- ✅ **跨平台支持** - 支持 iOS、Android、Web、Windows、macOS、Linux
- ✅ **超高清播放** - 完整支持 4K/8K 视频，硬件加速解码
- ✅ **多格式支持** - MP4、MKV、AVI、MOV、WebM 等主流格式
- ✅ **智能硬件加速** - 自动启用 VideoToolbox、DXVA2、VAAPI 等
- ✅ **HDR 视频支持** - HDR10、HLG 等高动态范围格式
- ✅ **完整播放控制** - 播放/暂停、进度调节、音量控制、全屏模式

### 🌐 网络功能
- ✅ **网络视频播放** - 支持 HTTP/HTTPS 直链播放
- ✅ **HLS 流媒体** - 支持 m3u8 自适应流播放
- ✅ **智能缓存系统** - 边播边缓存，节省流量
- ✅ **缓存优先加载** - 已缓存视频秒开，无需等待
- ✅ **断点续传** - 网络中断自动恢复播放
- ✅ **URL 历史管理** - 快捷访问常用视频源

### 🏠 媒体服务器集成
- ✅ **SMB/NAS 支持** - 直接访问网络共享文件夹
- ✅ **Emby 集成** - 完整的 Emby 媒体服务器支持
- ✅ **Jellyfin 集成** - Jellyfin 媒体库无缝访问
- ✅ **Plex 集成** - Plex 服务器内容播放
- ✅ **服务器管理** - 添加、编辑、删除多个媒体服务器
- ✅ **远程缩略图** - 自动获取和缓存视频封面

### 📝 字幕功能
- ✅ **多格式字幕** - 支持 SRT、ASS、SSA、VTT 等格式
- ✅ **外部字幕加载** - 自动匹配同名字幕文件
- ✅ **字幕样式自定义** - 字体大小、颜色、位置调节
- ✅ **多语言切换** - 支持多字幕轨道切换
- ✅ **字幕同步** - 精确调节字幕延迟
- ✅ **编码自动检测** - 智能识别 UTF-8、GBK 等编码

### 🎨 现代化界面
- ✅ **深色主题设计** - 护眼的深色界面风格
- ✅ **侧边栏导航** - 清晰的导航结构
- ✅ **响应式布局** - 自适应各种屏幕尺寸
- ✅ **流畅动画** - 精致的悬停和切换动画
- ✅ **卡片式设计** - 现代化的视频卡片展示

### 📊 播放历史
- ✅ **智能记录** - 自动记录观看进度
- ✅ **断点续播** - 从上次位置继续观看
- ✅ **搜索过滤** - 按名称、状态、时间筛选
- ✅ **批量管理** - 多选删除历史记录
- ✅ **缩略图预览** - 视频封面快速识别
- ✅ **播放统计** - 详细的观看数据

### ⚡ 性能监控
- ✅ **实时性能面板** - CPU、GPU、内存占用监控
- ✅ **帧率监控** - 实时显示播放帧率
- ✅ **视频信息查看** - 编解码器、分辨率、码率等参数
- ✅ **性能指示器** - 颜色编码的性能状态显示
- ✅ **播放质量切换** - 自动/高质量/低功耗/兼容模式

## 🚀 快速开始

### 环境要求
```
Flutter 3.38.1 或更高版本
Dart 3.10.0 或更高版本
```

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
# 运行到Chrome浏览器
flutter run -d chrome

# 运行到指定平台
flutter run -d android    # Android设备
flutter run -d ios       # iOS设备
flutter run -d macos     # macOS桌面
flutter run -d windows   # Windows桌面
flutter run -d linux     # Linux桌面
```

### 构建发布版本
```bash
# Web版本
flutter build web

# 桌面版本
flutter build windows
flutter build macos
flutter build linux

# 移动版本
flutter build apk
flutter build ios
```

## 🏗️ 项目架构

```
lib/
├── main.dart                           # 应用入口
├── screens/
│   ├── home_screen.dart                # 主界面（侧边栏导航）
│   ├── player_screen.dart              # 播放器界面
│   ├── playback_history_screen.dart    # 播放历史
│   ├── media_library_screen.dart       # 媒体库
│   ├── media_server_list_page.dart     # 媒体服务器列表
│   └── settings_screen.dart            # 设置界面
├── services/
│   ├── network_stream_service.dart     # 网络流服务
│   ├── video_cache_service.dart        # 视频缓存服务
│   ├── local_proxy_server.dart         # 本地代理服务器
│   ├── subtitle_service.dart           # 字幕服务
│   ├── media_server_service.dart       # 媒体服务器管理
│   ├── emby_api_service.dart           # Emby API
│   ├── jellyfin_api_service.dart       # Jellyfin API
│   ├── plex_api_service.dart           # Plex API
│   ├── history_service.dart            # 历史记录服务
│   └── file_source/
│       └── smb_file_source.dart        # SMB 文件源
├── widgets/
│   ├── modern_video_card.dart          # 现代化视频卡片
│   ├── modern_sidebar.dart             # 侧边栏导航
│   ├── responsive_grid.dart            # 响应式网格
│   ├── buffering_indicator.dart        # 缓冲指示器
│   └── subtitle_selector.dart          # 字幕选择器
└── models/
    ├── playback_history.dart           # 播放历史模型
    ├── stream_info.dart                # 流信息模型
    ├── subtitle_config.dart            # 字幕配置
    └── media_server.dart               # 媒体服务器模型
```

### 技术栈
- **框架**: Flutter 3.38.1
- **视频引擎**: media_kit + media_kit_video (基于 MPV)
- **网络请求**: http, dio
- **本地代理**: shelf (HTTP 服务器)
- **文件选择**: file_picker
- **缓存管理**: hive, sqflite
- **状态管理**: Provider + StatefulWidget
- **UI框架**: Material Design 3
- **字幕处理**: charset_converter
- **SMB协议**: dart_smb
- **插件系统**: 自定义插件架构（三层仓库结构）

## 🎯 使用说明

### 本地视频播放
1. **添加视频**: 点击主界面右下角的 `+` 按钮
2. **播放控制**: 点击播放器中央的大播放/暂停按钮
3. **进度调节**: 拖拽底部的进度条
4. **音量控制**: 点击右上角的音量图标
5. **全屏播放**: 点击右上角的全屏图标

### 网络视频播放
1. **输入URL**: 点击主界面"网络视频"按钮
2. **粘贴链接**: 输入HTTP/HTTPS或HLS(m3u8)链接
3. **自动缓存**: 播放时自动缓存，再次观看秒开
4. **URL历史**: 快速访问最近播放的网络视频

### 媒体服务器
1. **添加服务器**: 进入"影视服务器"→"添加服务器"
2. **选择类型**: SMB共享、Emby、Jellyfin或Plex
3. **输入信息**: 填写服务器地址、用户名、密码等
4. **浏览媒体**: 扫描完成后浏览和播放服务器视频

### 字幕功能
1. **自动加载**: 播放视频时自动匹配同名字幕文件
2. **手动选择**: 点击字幕按钮→"加载外部字幕"
3. **切换字幕**: 点击字幕按钮选择字幕轨道
4. **调节延迟**: 使用同步控制按钮(±100ms/±500ms)
5. **自定义样式**: 在设置中调节字幕字体、颜色、位置

### 播放历史
1. **查看历史**: 点击侧边栏"播放历史"
2. **继续观看**: 点击历史记录项从上次位置继续
3. **搜索视频**: 在搜索框中输入关键词快速查找
4. **智能过滤**: 按观看状态、时间范围筛选
5. **批量管理**: 长按进入多选模式，批量删除

### 性能监控
1. **视频信息**: 右键点击视频 → "视频信息"
2. **性能监控**: 右键点击视频 → "查看性能信息"
3. **性能覆盖层**: 右键点击视频 → "切换性能覆盖层"
4. **质量设置**: 在设置中选择播放质量模式

## 🛣️ 产品路线

### ✅ 已完成功能 (v0.8)
- ✅ **基础播放功能** - 本地视频播放、全屏、进度控制
- ✅ **播放历史系统** - 智能记录、断点续播、搜索过滤
- ✅ **超高清支持** - 4K/8K、硬件加速、性能监控
- ✅ **网络流媒体** - HTTP/HLS 播放、智能缓存
- ✅ **字幕系统** - 多格式、自定义样式、同步调节
- ✅ **媒体服务器集成** - SMB/Emby/Jellyfin/Plex
- ✅ **现代化UI** - 深色主题、侧边栏、响应式布局

### ✅ 已完成功能 (v0.9 - 插件系统)
- ✅ **插件架构** - 实现新版插件系统初始架构
- ✅ **三层仓库结构** - 内置、商业、第三方插件仓库
- ✅ **插件生命周期管理** - 完整的插件安装、更新、卸载流程
- ✅ **插件注册和管理系统** - 强大的插件注册和管理功能
- ✅ **插件中心** - 插件浏览、安装、管理界面（修复tabs切换）
- ✅ **SMB支持优化** - 修复添加服务器页面SMB类型显示问题

### 🔄 进行中 (v0.10)
- 🔄 **网络缓冲优化** - 自适应缓冲、带宽监控
- 🔄 **macOS 沙盒优化** - Security-Scoped Bookmarks

### 🎯 近期计划 (v1.0 - 正式发布)
- [ ] **播放列表管理** - 创建、编辑、导入/导出播放列表
- [ ] **播放速度调节** - 0.25x - 4.0x 变速播放
- [ ] **画面调节** - 比例、裁剪、旋转、翻转
- [ ] **截图和录制** - 高质量截图、片段录制

### 🚀 中期目标 (v1.5)
- [ ] **在线字幕下载** - 自动搜索和下载字幕
- [ ] **视频转码** - 格式转换、压缩优化
- [ ] **DLNA/Chromecast** - 投屏到电视
- [ ] **WebDAV 支持** - WebDAV 服务器集成

### 🌟 长期愿景 (v2.0)
- [ ] **AI 功能** - 智能推荐、场景识别
- [ ] **云端同步** - 多设备播放进度同步
- [ ] **社交功能** - 观影记录分享
- [ ] **直播支持** - RTMP/RTSP 直播流

## 📹 支持格式

### 容器格式
- ✅ **MP4** - 完全支持，硬件加速
- ✅ **MKV** - 完全支持，多音轨字幕
- ✅ **AVI** - 完全支持
- ✅ **MOV** - 完全支持，硬件加速
- ✅ **WebM** - 完全支持
- ✅ **FLV** - 基本支持
- ✅ **WMV** - 基本支持

### 视频编解码器
- ✅ **H.264/AVC** - 完全支持，硬件加速
- ✅ **HEVC/H.265** - 完全支持，硬件加速
- ✅ **VP9** - 完全支持，硬件加速
- ✅ **AV1** - 支持，部分硬件加速
- ✅ **MPEG-2** - 支持
- ✅ **MPEG-4** - 支持
- ✅ **WMV2/3** - 支持
- ✅ **DivX/XviD** - 支持

### 音频编解码器
- ✅ **AAC** - 完全支持
- ✅ **MP3** - 完全支持
- ✅ **AC3/Dolby Digital** - 支持
- ✅ **DTS** - 支持
- ✅ **FLAC** - 支持
- ✅ **Opus** - 支持
- ✅ **Vorbis** - 支持

### 字幕格式
- ✅ **SRT** - 完全支持
- ✅ **ASS/SSA** - 完全支持，高级样式
- ✅ **VTT** - 支持
- ✅ **内嵌字幕** - 支持 MKV 内嵌字幕

### 流媒体协议
- ✅ **HTTP/HTTPS** - 直链播放
- ✅ **HLS (m3u8)** - 自适应流
- ✅ **SMB** - 网络共享文件夹（通过本地代理）

### 分辨率支持
- ✅ **720p (HD)** - 完全支持
- ✅ **1080p (Full HD)** - 完全支持，硬件加速
- ✅ **1440p (2K)** - 支持，硬件加速
- ✅ **2160p (4K UHD)** - 支持，硬件加速
- ✅ **4320p (8K UHD)** - 支持，高性能设备硬件加速

### HDR支持
- ✅ **HDR10** - 支持
- ✅ **HLG** - 支持
- ⚠️ **Dolby Vision** - 部分支持

### 平台硬件加速
- ✅ **macOS**: VideoToolbox
- ✅ **Windows**: DXVA2/D3D11VA
- ✅ **Linux**: VAAPI/VDPAU
- ✅ **Android**: MediaCodec
- ✅ **iOS**: VideoToolbox
- ⚠️ **Web**: 依赖浏览器支持

## 🤝 贡献指南

我们欢迎所有开发者参与贡献！无论是bug修复、功能建议还是代码优化，我们都非常感激。

### 如何贡献
1. Fork 本仓库
2. 创建您的功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

### 代码规范
- 遵循 Flutter 官方代码规范
- 保持代码简洁、可读性强
- 添加必要的注释说明
- 确保跨平台兼容性
- 编写单元测试和集成测试

## 📝 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 优秀的跨平台开发框架
- [media_kit](https://github.com/media-kit/media-kit) - 强大的视频播放引擎
- [MPV](https://mpv.io/) - 高性能多媒体播放器内核
- [file_picker](https://github.com/miguelpruivo/flutter_file_picker) - 便捷的文件选择插件
- [shelf](https://pub.dev/packages/shelf) - 轻量级 HTTP 服务器

## 📞 联系我们

**作者**: peterfei

如果您有任何问题、建议或合作意向，欢迎通过以下方式联系我们：

- 📧 邮箱: [peterfeispace@gmail.com](mailto:peterfeispace@gmail.com)
- 🐙 GitHub: [https://github.com/peterfei/core-player](https://github.com/peterfei/core-player)
- 🐛 Issues: [项目Issues页面](https://github.com/peterfei/core-player/issues)

---

<div align="center">

**酷影播放器 CorePlayer** - 酷炫影音，畅享无限

*极致播放，智能管理，跨界体验*

Made with ❤️ by peterfei

</div>