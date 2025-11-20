import 'dart:async';

/// 流量监控服务
/// 用于汇总和广播应用内的网络流量速度
class TrafficMonitorService {
  static final TrafficMonitorService _instance = TrafficMonitorService._internal();
  static TrafficMonitorService get instance => _instance;

  TrafficMonitorService._internal() {
    // 每秒计算一次速度
    _timer = Timer.periodic(const Duration(seconds: 1), _calculateSpeed);
  }

  final StreamController<int> _speedController = StreamController<int>.broadcast();
  Stream<int> get speedStream => _speedController.stream;

  Timer? _timer;
  int _bytesSinceLastTick = 0;
  int _currentSpeed = 0; // bytes per second

  /// 报告已传输的字节数
  void reportBytes(int bytes) {
    _bytesSinceLastTick += bytes;
  }

  /// 计算当前速度
  void _calculateSpeed(Timer timer) {
    _currentSpeed = _bytesSinceLastTick;
    _bytesSinceLastTick = 0;
    _speedController.add(_currentSpeed);
  }

  /// 获取当前速度 (B/s)
  int get currentSpeed => _currentSpeed;

  void dispose() {
    _timer?.cancel();
    _speedController.close();
  }
}
