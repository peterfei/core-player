import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/playback_history.dart';
import '../services/history_service.dart';

class PlayerScreen extends StatefulWidget {
  final File videoFile;
  final String? webVideoUrl;
  final String? webVideoName;
  final int? seekTo;
  final bool fromHistory;

  const PlayerScreen({
    super.key,
    required this.videoFile,
    this.webVideoUrl,
    this.webVideoName,
    this.seekTo,
    this.fromHistory = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Create a [Player] instance from `media_kit`.
  late final Player player = Player();
  // Create a [VideoController] instance from `media_kit_video`.
  late final VideoController controller = VideoController(player);

  // 播放状态
  bool _isPlaying = true;
  bool _isControlsVisible = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  bool _isFullscreen = false;

  // 控制界面自动隐藏的定时器
  Timer? _controlsTimer;

  // 播放历史记录相关
  Timer? _historyTimer;
  String? _videoPath;
  String? _videoName;

  @override
  void initState() {
    super.initState();
    // 监听播放状态变化
    player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // 监听播放位置变化
    player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // 监听总时长变化
    player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
        // 获取总时长后开始记录播放历史
        _initializeHistory();

        // 如果是从历史记录播放且有指定跳转位置，则跳转
        if (widget.fromHistory && widget.seekTo != null && widget.seekTo! > 0) {
          // 延迟跳转，确保视频已经开始播放
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              player.seek(Duration(seconds: widget.seekTo!));
            }
          });
        }
      }
    });

    // 监听音量变化
    player.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });

    // 设置视频路径和名称
    _videoPath = widget.webVideoUrl ?? widget.videoFile.path;
    _videoName = widget.webVideoName ?? HistoryService.extractVideoName(_videoPath!);

    // Open the video file and start playing.
    if (widget.webVideoUrl != null) {
      // Web 平台：使用 URL
      player.open(Media(widget.webVideoUrl!), play: true);
    } else {
      // 非 Web 平台：使用文件路径
      player.open(Media(widget.videoFile.path), play: true);
    }

    // 3秒后自动隐藏控制界面
    _startControlsTimer();
  }

  // 控制界面自动隐藏
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  // 切换播放/暂停
  void _togglePlayPause() {
    setState(() {
      _isPlaying ? player.pause() : player.play();
    });
    _startControlsTimer();
  }

  // 跳转到指定位置
  void _seekTo(Duration position) {
    player.seek(position);
    _startControlsTimer();
  }

  // 设置音量
  void _setVolume(double volume) {
    player.setVolume(volume);
    _startControlsTimer();
  }

  // 切换控制界面显示
  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    if (_isControlsVisible) {
      _startControlsTimer();
    }
  }

  // 初始化播放历史记录
  void _initializeHistory() async {
    if (_videoPath == null || _videoName == null || _totalDuration.inSeconds <= 0) {
      return;
    }

    // 查找是否有历史记录
    final existingHistory = await HistoryService.getHistoryByPath(_videoPath!);

    if (existingHistory != null) {
      // 如果是从历史记录播放，更新最后播放时间但不询问
      if (widget.fromHistory) {
        final updatedHistory = existingHistory.copyWith(
          lastPlayedAt: DateTime.now(),
          currentPosition: widget.seekTo ?? 0,
          totalDuration: _totalDuration.inSeconds,
        );
        await HistoryService.saveHistory(updatedHistory);
      } else if (!existingHistory.isCompleted) {
        // 如果有未看完的记录，询问用户是否从上次位置继续
        _showResumeDialog(existingHistory);
        _startHistoryTimer();
        return;
      } else {
        // 已看完的视频，重置到开头
        final resetHistory = existingHistory.copyWith(
          lastPlayedAt: DateTime.now(),
          currentPosition: 0,
          totalDuration: _totalDuration.inSeconds,
        );
        await HistoryService.saveHistory(resetHistory);
      }
    } else {
      // 创建新的历史记录（异步版本以支持缩略图生成）
      final newHistory = await HistoryService.createHistoryAsync(
        videoPath: _videoPath!,
        videoName: _videoName!,
        currentPosition: widget.seekTo ?? 0,
        totalDuration: _totalDuration.inSeconds,
      );
      await HistoryService.saveHistory(newHistory);
    }

    
    // 开始定期保存播放进度
    _startHistoryTimer();

    // 后台生成缩略图
    if (_videoPath != null) {
      HistoryService.generateThumbnailInBackground(_videoPath!);
    }
  }

  // 显示继续播放对话框
  void _showResumeDialog(PlaybackHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('继续播放'),
        content: Text(
          '检测到您上次观看此视频到 ${history.formattedProgress}，\n'
          '是否从上次位置继续观看？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _seekTo(Duration(seconds: history.currentPosition));
            },
            child: const Text('继续'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
  }

  // 开始定时保存播放进度
  void _startHistoryTimer() {
    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  // 保存播放进度
  void _saveProgress() async {
    if (_videoPath == null || _videoName == null || _currentPosition.inSeconds <= 0) {
      return;
    }

    await HistoryService.updateProgress(
      videoPath: _videoPath!,
      currentPosition: _currentPosition.inSeconds,
      totalDuration: _totalDuration.inSeconds,
    );
  }

  // 切换全屏模式
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      // 进入全屏模式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // 退出全屏模式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _startControlsTimer();
  }

  // 格式化时间显示
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _historyTimer?.cancel();

    // 保存最终播放进度
    _saveProgress();

    // 恢复正常的系统UI模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Make sure to dispose the player and controller.
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 视频播放区域
            Center(
              child: Video(
                controller: controller,
              ),
            ),
            // 播放控制界面
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 顶部工具栏
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 返回按钮
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          // 标题
                          Expanded(
                            child: Text(
                              widget.webVideoName ?? widget.videoFile.path.split('/').last,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // 全屏按钮
                          IconButton(
                            icon: Icon(
                              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: _toggleFullscreen,
                          ),
                          // 音量按钮
                          IconButton(
                            icon: Icon(
                              _volume > 0 ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _setVolume(_volume > 0 ? 0.0 : 1.0);
                            },
                          ),
                        ],
                      ),
                    ),
                    // 中间播放按钮
                    Expanded(
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 80,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                    ),
                    // 底部进度条和控制
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 进度条
                          Slider(
                            value: _totalDuration.inSeconds > 0
                                ? _currentPosition.inSeconds / _totalDuration.inSeconds
                                : 0.0,
                            onChanged: (value) {
                              final position = Duration(
                                seconds: (value * _totalDuration.inSeconds).round(),
                              );
                              _seekTo(position);
                            },
                            activeColor: Colors.blue,
                            inactiveColor: Colors.grey,
                          ),
                          // 时间和控制按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 当前时间
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(color: Colors.white),
                              ),
                              // 总时长
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
