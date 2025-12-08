# 修复"继续观看"和"最近添加"功能

## 问题描述

根据用户提供的截图,应用在播放"继续观看"中的视频时出现错误:
```
播放错误: Failed to open http://192.168.3.111:18888/video/v0.mp4
```

同时,"最近添加"功能也存在问题。

## 问题分析

### 1. "最近添加"功能问题

**原因**: 
- 代码使用的是播放历史记录 (`_histories`) 而不是媒体库视频 (`_scannedVideos`)
- 这导致"最近添加"显示的是最近播放的视频,而不是最近添加到媒体库的视频

### 2. "继续观看"功能问题

**原因**:
- 网络视频的 `streamUrl` 可能为空或无效
- 视频路径处理逻辑不够清晰
- 缺少错误处理和验证

## 修复方案

### 1. 修复"最近添加"功能

**文件**: `lib/screens/home_screen.dart`

**修改内容**:
1. 添加 `_scannedVideos` 字段保存原始扫描视频数据
2. 在 `_loadData()` 方法中保存原始数据
3. 修改 `_getRecentVideos()` 方法,使用原始数据按 `addedAt` 时间排序

```dart
// 添加字段
List<ScannedVideo> _scannedVideos = []; // 保存原始扫描视频数据用于排序

// 在 _loadData() 中保存原始数据
_scannedVideos = scanned; // 保存原始数据

// 修改 _getRecentVideos() 方法
List<VideoCardData> _getRecentVideos() {
  // 从媒体库中获取最近添加的视频
  if (_scannedVideos.isEmpty) {
    return [];
  }
  
  // 按添加时间降序排序(最新的在前)
  final sortedVideos = List<ScannedVideo>.from(_scannedVideos);
  sortedVideos.sort((a, b) {
    final aTime = a.addedAt ?? DateTime(1970);
    final bTime = b.addedAt ?? DateTime(1970);
    return bTime.compareTo(aTime);
  });
  
  // 返回最近添加的6个视频
  return sortedVideos.take(6).map(_mapScannedToVideoCard).toList();
}
```

### 2. 修复"继续观看"功能

**文件**: `lib/screens/home_screen.dart`

**修改内容**:
1. 改进 `_mapHistoryToVideoCard()` 方法,确保正确处理网络视频和本地视频的路径
2. 添加调试信息,帮助诊断问题
3. 改进 `_playVideo()` 方法,添加错误处理和验证

```dart
VideoCardData _mapHistoryToVideoCard(PlaybackHistory history) {
  // ... 前面的代码保持不变 ...
  
  // 关键修复:正确处理网络视频和本地视频的路径
  String? localPath;
  String? url;
  
  if (history.sourceType == 'network') {
    // 网络视频:使用 streamUrl 作为播放 URL
    url = history.streamUrl;
    localPath = null;
    
    // 调试信息
    if (url == null || url.isEmpty) {
      print('⚠️ 警告: 网络视频缺少 streamUrl: ${history.videoName}');
      print('   videoPath: ${history.videoPath}');
    }
  } else {
    // 本地视频:使用 videoPath 作为本地路径
    localPath = history.videoPath;
    url = null;
  }
  
  return VideoCardData(
    // ... 其他字段 ...
    localPath: localPath,
    url: url,
  );
}

void _playVideo(VideoCardData video) {
  // 验证视频数据
  if (video.localPath == null && video.url == null) {
    print('❌ 错误: 视频缺少播放路径');
    print('   标题: ${video.title}');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法播放视频: 缺少有效的播放路径'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return;
  }
  
  // ... 播放逻辑 ...
}
```

## 测试建议

1. **测试"最近添加"功能**:
   - 添加新视频到媒体库
   - 检查"最近添加"部分是否显示最新添加的视频
   - 验证排序是否正确(最新的在前)

2. **测试"继续观看"功能**:
   - 播放一个视频并中途停止
   - 检查"继续观看"部分是否显示该视频
   - 点击视频卡片,验证是否能正常播放
   - 检查控制台输出,查看是否有警告信息

3. **测试网络视频**:
   - 播放网络视频并中途停止
   - 检查历史记录中是否正确保存了 `streamUrl`
   - 从"继续观看"中重新播放,验证是否使用正确的 URL

## 潜在问题

如果网络视频仍然无法播放,可能的原因包括:

1. **URL 已失效**: 网络视频的 URL 可能已经过期或不可访问
2. **网络连接问题**: 检查网络连接是否正常
3. **历史记录数据问题**: 历史记录中的 `streamUrl` 字段可能为空

建议检查控制台输出,查看是否有 "⚠️ 警告: 网络视频缺少 streamUrl" 的消息。如果有,说明历史记录中没有保存正确的 URL。

## 后续改进建议

1. **添加 URL 验证**: 在保存历史记录时验证 URL 的有效性
2. **添加重试机制**: 如果 URL 失效,尝试从媒体服务器重新获取
3. **改进错误提示**: 提供更详细的错误信息,帮助用户理解问题
4. **添加 URL 刷新功能**: 允许用户手动刷新失效的 URL
