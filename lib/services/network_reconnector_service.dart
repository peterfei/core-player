import 'dart:async';
import 'dart:math';
import 'package:media_kit/media_kit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/network_stats.dart';
import 'bandwidth_monitor_service.dart';

/// 网络重连服务
class NetworkReconnectorService {
  static final NetworkReconnectorService _instance =
      NetworkReconnectorService._internal();
  factory NetworkReconnectorService() => _instance;
  NetworkReconnectorService._internal();

  final BandwidthMonitorService _bandwidthMonitor = BandwidthMonitorService();

  // 重连配置
  int _maxRetries = 5;
  int _currentRetry = 0;
  Duration _connectionTimeout = const Duration(seconds: 10);
  bool _autoReconnect = true;

  // 状态管理
  ConnectionStatus _connectionStatus = ConnectionStatus(
    state: ConnectionState.connected,
    message: '已连接',
    timestamp: DateTime.now(),
  );

  // 播放器相关
  Player? _player;
  String? _currentUrl;
  Duration? _checkpointPosition; // 断点位置
  bool _wasPlaying = false; // 断开时是否在播放

  // 定时器
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;

  // 事件回调
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  /// 获取连接状态流
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// 获取当前连接状态
  ConnectionStatus get currentStatus => _connectionStatus;

  /// 设置最大重试次数
  void setMaxRetries(int retries) {
    _maxRetries = max(1, retries);
  }

  /// 设置连接超时
  void setConnectionTimeout(Duration timeout) {
    _connectionTimeout = timeout;
  }

  /// 启用/禁用自动重连
  void setAutoReconnect(bool enabled) {
    _autoReconnect = enabled;
    if (!enabled) {
      stopReconnection();
    }
  }

  /// 绑定播放器
  void bindPlayer(Player player, String url) {
    if (_player != null) {
      unbindPlayer();
    }

    _player = player;
    _currentUrl = url;
    _currentRetry = 0;

    // 开始健康检查
    _startHealthCheck();

    print('NetworkReconnector bound to player: $url');
  }

  /// 解绑播放器
  void unbindPlayer() {
    _stopHealthCheck();
    stopReconnection();

    _player = null;
    _currentUrl = null;
    _checkpointPosition = null;
    _wasPlaying = false;
    _currentRetry = 0;

    print('NetworkReconnector unbound from player');
  }

  /// 保存断点
  void saveCheckpoint(Duration position, bool isPlaying) {
    _checkpointPosition = position;
    _wasPlaying = isPlaying;
  }

  /// 处理网络断开
  void handleNetworkDisconnection({String reason = '网络连接断开'}) {
    if (!_autoReconnect) return;

    _updateStatus(
      ConnectionState.offline,
      reason,
    );

    // 保存当前播放状态
    if (_player != null) {
      _player!.state.playing.then((isPlaying) {
        _wasPlaying = isPlaying;
      });

      _player!.state.position.then((position) {
        _checkpointPosition = position;
      });
    }

    // 开始重连
    startReconnection();
  }

  /// 开始重连
  void startReconnection() {
    if (!_autoReconnect || _currentRetry >= _maxRetries) {
      _updateStatus(
        ConnectionState.failed,
        '重连失败，已达到最大重试次数',
      );
      return;
    }

    _currentRetry++;
    _updateStatus(
      ConnectionState.reconnecting,
      '正在重连... ($_currentRetry/$_maxRetries)',
      retryCount: _currentRetry,
    );

    // 指数退避策略
    final delay = _getRetryDelay(_currentRetry);

    _reconnectTimer = Timer(delay, () {
      _performReconnection();
    });
  }

  /// 停止重连
  void stopReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _currentRetry = 0;
  }

  /// 获取重连延迟（指数退避）
  Duration _getRetryDelay(int attempt) {
    // 基础延迟：2秒，最大延迟：30秒
    final baseDelay = min(30, pow(2, attempt - 1).toDouble()).toInt();

    // 添加随机抖动，避免多个连接同时重连
    final jitter = (Random().nextDouble() * 0.5 + 0.5); // 0.5-1.0 倍
    final finalDelay = (baseDelay * jitter).round();

    return Duration(seconds: finalDelay);
  }

  /// 执行重连
  Future<void> _performReconnection() async {
    try {
      // 检查网络连接
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print('No internet connection, retrying...');
        startReconnection();
        return;
      }

      // 检查带宽
      final bandwidthStats = _bandwidthMonitor.currentStats;
      if (bandwidthStats.currentBandwidth <= 0) {
        print('No bandwidth, retrying...');
        startReconnection();
        return;
      }

      // 重新打开视频
      if (_player != null && _currentUrl != null) {
        await _player!.open(Media(_currentUrl!));

        // 如果有断点，恢复播放位置
        if (_checkpointPosition != null) {
          // 等待视频加载完成后跳转
          await Future.delayed(const Duration(milliseconds: 500));
          await _player!.seek(_checkpointPosition!);
        }

        // 如果之前在播放，恢复播放
        if (_wasPlaying) {
          await Future.delayed(const Duration(milliseconds: 200));
          await _player!.play();
        }

        // 重连成功
        _updateStatus(
          ConnectionState.connected,
          '连接已恢复',
        );

        // 重置重试计数
        _currentRetry = 0;
        _checkpointPosition = null;

        print('Reconnection successful');
      }
    } catch (e) {
      print('Reconnection failed: $e');

      // 重连失败，继续重试
      startReconnection();
    }
  }

  /// 开始健康检查
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _performHealthCheck();
    });
  }

  /// 停止健康检查
  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// 执行健康检查
  void _performHealthCheck() async {
    try {
      // 检查网络连接
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        handleNetworkDisconnection(reason: '网络连接断开');
        return;
      }

      // 检查播放器状态
      if (_player == null || _currentUrl == null) return;

      final isPlaying = await _player!.state.playing;
      final position = await _player!.state.position;

      // 检查是否长时间卡顿
      if (_connectionStatus.state == ConnectionState.connected) {
        final timeSinceLastUpdate =
            DateTime.now().difference(_connectionStatus.timestamp);

        // 如果超过15秒没有更新且播放器在播放，可能有问题
        if (isPlaying && timeSinceLastUpdate.inSeconds > 15) {
          print('Possible streaming issue detected, checking...');

          // 检查带宽
          final bandwidthStats = _bandwidthMonitor.currentStats;
          if (bandwidthStats.currentBandwidth <= 0) {
            handleNetworkDisconnection(reason: '检测到网络问题');
          }
        }
      }

      // 更新状态时间戳（定期更新表示连接正常）
      _updateStatus(
        ConnectionState.connected,
        '播放正常',
      );
    } catch (e) {
      print('Health check error: $e');
    }
  }

  /// 更新连接状态
  void _updateStatus(ConnectionState state, String message, {int? retryCount}) {
    _connectionStatus = _connectionStatus.copyWith(
      state: state,
      message: message,
      timestamp: DateTime.now(),
      retryCount: retryCount ?? _connectionStatus.retryCount,
    );

    _statusController.add(_connectionStatus);
  }

  /// 手动重连
  Future<bool> manualReconnect() async {
    stopReconnection();
    _currentRetry = 0;

    await _performReconnection();

    return _connectionStatus.state == ConnectionState.connected;
  }

  /// 重置重连计数
  void resetRetryCount() {
    _currentRetry = 0;
  }

  /// 获取重连统计
  Map<String, dynamic> getReconnectionStats() {
    return {
      'currentRetry': _currentRetry,
      'maxRetries': _maxRetries,
      'autoReconnect': _autoReconnect,
      'connectionTimeout': _connectionTimeout.inSeconds,
      'lastCheckpoint': _checkpointPosition?.inMilliseconds,
      'wasPlaying': _wasPlaying,
      'status': _connectionStatus.toJson(),
    };
  }

  /// 设置高级配置
  void setAdvancedConfig({
    int? maxRetries,
    Duration? connectionTimeout,
    bool? autoReconnect,
    Duration? healthCheckInterval,
  }) {
    if (maxRetries != null) {
      setMaxRetries(maxRetries);
    }
    if (connectionTimeout != null) {
      setConnectionTimeout(connectionTimeout);
    }
    if (autoReconnect != null) {
      setAutoReconnect(autoReconnect);
    }
    if (healthCheckInterval != null) {
      _stopHealthCheck();
      if (_player != null) {
        _healthCheckTimer = Timer.periodic(healthCheckInterval, (_) {
          _performHealthCheck();
        });
      }
    }
  }

  /// 销毁服务
  void dispose() {
    unbindPlayer();
    _statusController.close();
  }

  @override
  String toString() {
    return '''
NetworkReconnectorService:
- Auto Reconnect: $_autoReconnect
- Current Retry: $_currentRetry/$_maxRetries
- Connection Timeout: ${_connectionTimeout.inSeconds}s
- Current Status: ${_connectionStatus.state.name} - ${_connectionStatus.message}
- Player Bound: ${_player != null}
- Current URL: $_currentUrl
- Checkpoint: ${_checkpointPosition?.inSeconds}s
    ''';
  }
}
