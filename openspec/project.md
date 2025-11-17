# 项目上下文

## 项目目标
影核播放器 (CorePlayer) 是一个基于 Flutter 的跨平台视频播放器,支持 iOS、Android、Web、Windows、macOS 和 Linux 平台。项目致力于提供最核心、最强劲、最流畅的视频播放体验,让每一帧画面都完美呈现。

## 技术栈
- **框架**: Flutter 3.38.1 + Dart 3.10.0+
- **视频引擎**: media_kit + media_kit_video,统一视频播放后端
- **文件选择**: file_picker,支持跨平台文件选择
- **状态管理**: StatefulWidget (当前采用的方式)
- **UI 框架**: Material Design 3
- **平台支持**: iOS、Android、Web、Windows、macOS、Linux
- **构建工具**: Flutter CLI、Xcode、Android Studio

## 项目规范

### 代码风格
- 遵循 Flutter/Dart 官方代码规范
- 使用有意义的英文变量和函数名
- 尽可能使用 const 构造函数
- 对于有状态管理的界面使用 StatefulWidget
- 保持 Widget 小巧且可组合

### 架构模式
- **基于屏幕的导航**: 主界面代码位于 lib/screens/ 目录
- **平台适配方**: 根据平台自动选择文件选择方式(Web 与桌面/移动端不同)
- **控制抽象**: 跨平台统一的视频播放控制
- **响应式 UI**: 遵循 Material Design 3 原则,提供一致的体验

### 测试策略
目前尚未实现正式测试策略 - MVP 阶段采用跨平台手动测试。
**未来规划**: 需要为视频控制、文件选择逻辑和平台适配器添加单元测试。

### Git 工作流
- **主分支**: `main`
- **功能分支**: `feature/[功能名称]` (例如 `feature/AmazingFeature`)
- **提交格式**: `[类型]描述` (例如 `[Feature]`、`[Fixed]`、`[Update]`)
- **代码提交流程**: Fork + 功能分支 → 提交 Pull Request 到 main
- **修复模式**: `[Fixed]修复[平台][问题]` (例如 `[Fixed]修复macos不能播放`)

## 领域上下文

### 视频播放领域
- **media_kit 集成**: 统一的视频播放引擎,处理平台特定的视频渲染
- **平台考虑**: 不同的文件选择方式(Web 浏览器与桌面/移动端的文件系统访问权限不同)
- **用户体验**: 3 秒后自动隐藏控制栏、点击切换控制界面显示、全屏切换
- **格式支持**: 通过 media_kit 编解码器支持多种视频格式
- **原生依赖**: 平台特定的视频库(例如 macOS 使用 media_kit_libs_macos_video)

### 跨平台挑战
- **文件访问**: Web 浏览器与桌面/移动端有不同的文件权限模型
- **视频渲染**: 每个平台需要不同的原生视频后端
- **性能优化**: 需要在低端设备上实现流畅播放
- **UI 一致性**: Material Design 3 提供跨平台统一外观

## 重要约束

### 技术约束
- **Flutter SDK**: 必须保持 Flutter 3.38.1+ 兼容性
- **视频引擎**: media_kit 有平台特定的依赖和要求
- **Web 限制**: 浏览器安全策略限制直接文件系统访问(file_picker 处理此问题)
- **桌面平台**: 需要适当的原生视频库依赖

### 业务约束
- **MIT 许可证**: 使用宽松许可证的开源项目
- **性能**: 作为"核心"功能必须提供流畅的播放体验
- **即插即用**: 应该在各个平台上以最少配置工作

## 外部依赖

### 核心依赖
- **media_kit**: ^1.2.2 - 主要视频播放引擎
- **media_kit_video**: ^2.0.0 - 视频组件和 UI 控件
- **file_picker**: ^8.3.2 - 跨平台文件选择
- **cupertino_icons**: ^1.0.6 - iOS 风格图标

### 平台特定依赖
- **media_kit_libs_macos_video**: ^1.0.4 - macOS 视频库
- Windows/Linux 可能需要额外平台库(请查阅文档)

### 开发依赖
- **flutter_lints**: ^3.0.0 - 代码质量和风格检查
- **flutter_test**: SDK 依赖 - 测试框架(当前未使用)
