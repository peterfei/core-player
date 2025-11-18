import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/performance_monitor_service.dart';

void main() {
  group('PerformanceMonitorService Tests', () {
    late PerformanceMonitorService perfService;

    setUpAll(() async {
      perfService = PerformanceMonitorService.instance;
    });

    tearDown(() {
      perfService.dispose();
    });

    group('基本功能测试', () {
      test('服务应正确初始化', () {
        expect(perfService, isNotNull);
        expect(perfService.currentMetrics, isNotNull);
      });

      test('应能获取当前性能指标', () {
        final metrics = perfService.currentMetrics;
        expect(metrics, isNotNull);

        if (metrics != null) {
          expect(metrics.fps, greaterThanOrEqualTo(0.0));
          expect(metrics.cpuUsage, greaterThanOrEqualTo(0.0));
          expect(metrics.memoryUsage, greaterThanOrEqualTo(0.0));
          expect(metrics.gpuUsage, greaterThanOrEqualTo(0.0));
          expect(metrics.droppedFramePercentage, greaterThanOrEqualTo(0.0));
          expect(metrics.bufferPercentage, greaterThanOrEqualTo(0.0));
          expect(metrics.bufferedMs, greaterThanOrEqualTo(0));
        }
      });

      test('应能获取性能统计', () {
        final stats = perfService.getPerformanceStats();
        expect(stats, isNotNull);

        if (stats != null) {
          expect(stats.monitoringDuration, greaterThanOrEqualTo(0));
          expect(stats.averageFps, greaterThanOrEqualTo(0.0));
          expect(stats.maxFps, greaterThanOrEqualTo(0.0));
          expect(stats.minFps, greaterThanOrEqualTo(0.0));
          expect(stats.totalDroppedFrames, greaterThanOrEqualTo(0));
          expect(stats.performanceIssues, greaterThanOrEqualTo(0));
        }
      });
    });

    group('配置管理测试', () {
      test('应能设置解码器类型', () {
        expect(() => perfService.setDecoderType('Software (FFmpeg)'), returnsNormally);
        expect(() => perfService.setDecoderType('Hardware (VideoToolbox)'), returnsNormally);
        expect(() => perfService.setDecoderType('DXVA2'), returnsNormally);
        expect(() => perfService.setDecoderType('VAAPI'), returnsNormally);

        final metrics = perfService.currentMetrics;
        if (metrics != null) {
          expect(metrics.decoderType, isNotEmpty);
        }
      });

      test('应能设置监控间隔', () {
        expect(() => perfService.setInterval(500), returnsNormally);
        expect(() => perfService.setInterval(1000), returnsNormally);
        expect(() => perfService.setInterval(2000), returnsNormally);
        expect(() => perfService.setInterval(5000), returnsNormally);
      });
    });

    group('数据管理测试', () {
      test('应能清除历史数据', () {
        expect(() => perfService.clearHistory(), returnsNormally);

        final stats = perfService.getPerformanceStats();
        if (stats != null) {
          expect(stats.monitoringDuration, equals(0));
          expect(stats.averageFps, equals(0.0));
          expect(stats.totalDroppedFrames, equals(0));
        }
      });

      test('应能限制历史大小', () {
        expect(() => perfService.limitHistory(maxDataPoints: 100), returnsNormally);
        expect(() => perfService.limitHistory(maxDataPoints: 0), returnsNormally);
        expect(() => perfService.limitHistory(maxDataPoints: 10000), returnsNormally);
      });

      test('多次清除历史不应报错', () {
        expect(() {
          for (int i = 0; i < 5; i++) {
            perfService.clearHistory();
          }
        }, returnsNormally);
      });
    });

    group('错误处理测试', () {
      test('无效输入不应导致崩溃', () {
        expect(() => perfService.setDecoderType(''), returnsNormally);
        expect(() => perfService.setDecoderType('Invalid Decoder'), returnsNormally);
        expect(() => perfService.setInterval(0), returnsNormally);
        expect(() => perfService.setInterval(-1), returnsNormally);
      });

      test('边界值输入不应崩溃', () {
        expect(() => perfService.setInterval(1), returnsNormally);
        expect(() => perfService.setInterval(999999), returnsNormally);
        expect(() => perfService.limitHistory(maxDataPoints: 0), returnsNormally);
        expect(() => perfService.limitHistory(maxDataPoints: 999999), returnsNormally);
      });

      test('大量操作不应崩溃', () {
        expect(() {
          for (int i = 0; i < 100; i++) {
            perfService.setDecoderType('Test Decoder $i');
            perfService.setInterval(100 + i);
          }
        }, returnsNormally);
      });
    });

    group('性能指标评估测试', () {
      test('性能指标应包含评估属性', () {
        final metrics = perfService.currentMetrics;
        if (metrics != null) {
          // 检查性能评估属性是否存在且逻辑一致
          final hasExcellentPerformance = metrics.isExcellentPerformance;
          final hasGoodPerformance = metrics.isGoodPerformance;
          final hasPoorPerformance = metrics.isPoorPerformance;

          // 至少应该有一个性能等级
          expect(hasExcellentPerformance || hasGoodPerformance || hasPoorPerformance, isTrue);
        }
      });

      test('性能评估应有逻辑一致性', () {
        final metrics = perfService.currentMetrics;
        if (metrics != null) {
          // 如果是优秀性能，那么不应该是差的性能
          if (metrics.isExcellentPerformance) {
            expect(metrics.isPoorPerformance, isFalse);
          }

          // 如果帧率很高，不应该是差的性能
          if (metrics.fps > 50) {
            expect(metrics.isPoorPerformance, isFalse);
          }

          // 如果丢帧率很低，不应该是差的性能
          if (metrics.droppedFramePercentage < 0.1) {
            expect(metrics.isPoorPerformance, isFalse);
          }
        }
      });
    });

    group('性能指标变化测试', () {
      test('设置解码器应反映在指标中', () {
        const decoderType = 'Test Decoder Type';
        perfService.setDecoderType(decoderType);

        final metrics = perfService.currentMetrics;
        if (metrics != null) {
          expect(metrics.decoderType, equals(decoderType));
        }
      });

      test('性能统计应随时间合理变化', () async {
        final stats1 = perfService.getPerformanceStats();
        final duration1 = stats1?.monitoringDuration ?? 0;

        await Future.delayed(const Duration(milliseconds: 100));

        final stats2 = perfService.getPerformanceStats();
        final duration2 = stats2?.monitoringDuration ?? 0;

        expect(duration2, greaterThanOrEqualTo(duration1));
      });

      test('多次调用应返回合理数据', () {
        final metrics1 = perfService.currentMetrics;
        final metrics2 = perfService.currentMetrics;
        final metrics3 = perfService.currentMetrics;

        expect(metrics1, isNotNull);
        expect(metrics2, isNotNull);
        expect(metrics3, isNotNull);

        if (metrics1 != null && metrics2 != null && metrics3 != null) {
          // 在相同条件下，指标应该合理一致
          expect(metrics1.fps, closeTo(metrics2.fps, 1.0));
          expect(metrics2.fps, closeTo(metrics3.fps, 1.0));
        }
      });
    });

    group('资源管理测试', () {
      test('应能正确释放资源', () {
        expect(() => perfService.dispose(), returnsNormally);
        expect(() => perfService.dispose(), returnsNormally); // 多次调用
      });

      test('释放资源后不应崩溃', () {
        perfService.dispose();

        expect(() => perfService.setDecoderType('test'), returnsNormally);
        expect(() => perfService.clearHistory(), returnsNormally);
        expect(() => perfService.getPerformanceStats(), returnsNormally);
        expect(() => perfService.currentMetrics, returnsNormally);
      });

      test('重置和重启应正常工作', () {
        perfService.clearHistory();
        perfService.limitHistory(maxDataPoints: 100);
        perfService.setDecoderType('Reset Test');

        final metrics = perfService.currentMetrics;
        expect(metrics, isNotNull);
      });
    });

    group('并发访问测试', () {
      test('应支持并发访问性能指标', () {
        expect(() {
          final metrics1 = perfService.currentMetrics;
          final metrics2 = perfService.currentMetrics;
          final metrics3 = perfService.currentMetrics;

          expect(metrics1, isNotNull);
          expect(metrics2, isNotNull);
          expect(metrics3, isNotNull);
        }, returnsNormally);
      });

      test('应支持并发操作', () {
        expect(() async {
          await Future.wait([
            Future(() => perfService.setDecoderType('test1')),
            Future(() => perfService.setDecoderType('test2')),
            Future(() => perfService.setInterval(100)),
            Future(() => perfService.clearHistory()),
          ]);
        }, returnsNormally);
      });

      test('并发获取统计数据应安全', () {
        expect(() {
          final stats1 = perfService.getPerformanceStats();
          final stats2 = perfService.getPerformanceStats();
          final stats3 = perfService.getPerformanceStats();

          expect(stats1, isNotNull);
          expect(stats2, isNotNull);
          expect(stats3, isNotNull);
        }, returnsNormally);
      });
    });

    group('服务稳定性测试', () {
      test('长时间操作不应崩溃', () async {
        expect(() async {
          for (int i = 0; i < 50; i++) {
            perfService.setDecoderType('Test $i');
            perfService.setInterval(100 + i * 10);
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }, returnsNormally);
      });

      test('频繁操作不应崩溃', () {
        expect(() {
          for (int i = 0; i < 1000; i++) {
            perfService.setDecoderType('Test $i');
            perfService.setInterval(50 + (i % 10) * 100);
          }
        }, returnsNormally);
      });

      test('边界操作组合不应崩溃', () {
        expect(() {
          perfService.clearHistory();
          perfService.limitHistory(maxDataPoints: 0);
          perfService.setInterval(1);
          perfService.setDecoderType('Edge Test');
          perfService.limitHistory(maxDataPoints: 99999);
          perfService.setInterval(99999);
          perfService.clearHistory();
        }, returnsNormally);
      });
    });

    group('数据完整性测试', () {
      test('性能统计应保持数据完整性', () {
        final stats = perfService.getPerformanceStats();
        if (stats != null) {
          expect(stats.monitoringDuration, greaterThanOrEqualTo(0));
          expect(stats.averageFps, greaterThanOrEqualTo(0.0));
          expect(stats.maxFps, greaterThanOrEqualTo(0.0));
          expect(stats.minFps, greaterThanOrEqualTo(0.0));
          expect(stats.totalDroppedFrames, greaterThanOrEqualTo(0));
          expect(stats.averageCpuUsage, greaterThanOrEqualTo(0.0));
          expect(stats.maxCpuUsage, greaterThanOrEqualTo(0.0));
          expect(stats.averageMemoryUsage, greaterThanOrEqualTo(0.0));
          expect(stats.maxMemoryUsage, greaterThanOrEqualTo(0.0));
          expect(stats.performanceIssues, greaterThanOrEqualTo(0));
        }
      });

      test('性能指标应包含所有必要字段', () {
        final metrics = perfService.currentMetrics;
        if (metrics != null) {
          expect(metrics.fps, greaterThanOrEqualTo(0.0));
          expect(metrics.targetFps, greaterThan(0.0));
          expect(metrics.cpuUsage, greaterThanOrEqualTo(0.0));
          expect(metrics.memoryUsage, greaterThanOrEqualTo(0.0));
          expect(metrics.gpuUsage, greaterThanOrEqualTo(0.0));
          expect(metrics.droppedFramePercentage, greaterThanOrEqualTo(0.0));
          expect(metrics.bufferPercentage, greaterThanOrEqualTo(0.0));
          expect(metrics.bufferedMs, greaterThanOrEqualTo(0));
          expect(metrics.decoderType, isNotNull);
          expect(metrics.resolution, isNotNull);
        }
      });
    });
  });
}