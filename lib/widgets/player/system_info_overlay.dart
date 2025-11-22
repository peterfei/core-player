import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';

/// 系统信息覆盖层（右上角显示时间和电量）
class SystemInfoOverlay extends StatefulWidget {
  const SystemInfoOverlay({super.key});

  @override
  State<SystemInfoOverlay> createState() => _SystemInfoOverlayState();
}

class _SystemInfoOverlayState extends State<SystemInfoOverlay> {
  final Battery _battery = Battery();
  Timer? _timeTimer;
  StreamSubscription<BatteryState>? _batterySubscription;
  String _currentTime = '';
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _updateBattery();
    
    // 每分钟更新一次时间
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTime());
    
    // 监听电池变化
    _batterySubscription = _battery.onBatteryStateChanged.listen((BatteryState state) {
      if (mounted) {
        setState(() {
          _batteryState = state;
        });
        _updateBattery();
      }
    });
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('HH:mm').format(DateTime.now());
    });
  }

  Future<void> _updateBattery() async {
    try {
      final level = await _battery.batteryLevel;
      setState(() {
        _batteryLevel = level;
      });
    } catch (e) {
      // 电量获取失败，保持默认值
    }
  }

  IconData _getBatteryIcon() {
    if (_batteryState == BatteryState.charging) {
      return Icons.battery_charging_full;
    }
    
    if (_batteryLevel > 90) return Icons.battery_full;
    if (_batteryLevel > 60) return Icons.battery_6_bar;
    if (_batteryLevel > 40) return Icons.battery_4_bar;
    if (_batteryLevel > 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _getBatteryColor() {
    if (_batteryState == BatteryState.charging) {
      return Colors.green;
    }
    if (_batteryLevel <= 20) return Colors.red;
    if (_batteryLevel <= 40) return Colors.orange;
    return Colors.white;
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 时间
          Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          // 电池图标
          Icon(
            _getBatteryIcon(),
            color: _getBatteryColor(),
            size: 20,
          ),
          const SizedBox(width: 4),
          // 电量百分比
          Text(
            '$_batteryLevel%',
            style: TextStyle(
              color: _getBatteryColor(),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
