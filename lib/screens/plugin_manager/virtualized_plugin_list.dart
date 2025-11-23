import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/screens/plugin_manager/plugin_card.dart';

/// 虚拟化插件列表组件
/// 用于处理大量插件时的性能优化
class VirtualizedPluginList extends StatefulWidget {
  final List<CorePlugin> plugins;
  final Function(CorePlugin) onPluginTap;
  final Function(CorePlugin) onPluginToggle;
  final Widget? emptyWidget;
  final double itemHeight;
  final int? estimatedItemCount;

  const VirtualizedPluginList({
    Key? key,
    required this.plugins,
    required this.onPluginTap,
    required this.onPluginToggle,
    this.emptyWidget,
    this.itemHeight = 120.0,
    this.estimatedItemCount,
  }) : super(key: key);

  @override
  State<VirtualizedPluginList> createState() => _VirtualizedPluginListState();
}

class _VirtualizedPluginListState extends State<VirtualizedPluginList>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final GlobalKey _listKey = GlobalKey();

  // 缓存相关
  final Map<String, Widget> _cardCache = {};
  final Set<String> _visibleItems = {};
  static const int _cacheSize = 50; // 缓存的项目数量

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cardCache.clear();
    super.dispose();
  }

  void _onScroll() {
    // 滚动时清理不可见的缓存项
    _cleanupInvisibleCache();
  }

  void _cleanupInvisibleCache() {
    if (_cardCache.length > _cacheSize) {
      final keysToRemove = <String>[];
      _cardCache.forEach((key, _) {
        if (!_visibleItems.contains(key)) {
          keysToRemove.add(key);
        }
      });

      for (final key in keysToRemove.take(_cacheSize ~/ 2)) {
        _cardCache.remove(key);
      }
    }
  }

  Widget _buildPluginCard(CorePlugin plugin) {
    final cacheKey = plugin.metadata.id;

    // 检查缓存
    if (_cardCache.containsKey(cacheKey)) {
      return _cardCache[cacheKey]!;
    }

    // 如果缓存满了，清理一些旧项
    if (_cardCache.length >= _cacheSize) {
      final firstKey = _cardCache.keys.first;
      _cardCache.remove(firstKey);
    }

    // 创建新的卡片并缓存
    final card = _createPluginCard(plugin);
    _cardCache[cacheKey] = card;
    return card;
  }

  Widget _createPluginCard(CorePlugin plugin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: PluginCard(
        plugin: plugin,
        onTap: () => widget.onPluginTap(plugin),
        onToggle: () => widget.onPluginToggle(plugin),
        key: ValueKey(plugin.metadata.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.plugins.isEmpty) {
      return widget.emptyWidget ?? _buildDefaultEmptyWidget();
    }

    // 如果插件数量较少，使用普通列表
    if (widget.plugins.length <= 20) {
      return ListView.builder(
        controller: _scrollController,
        itemCount: widget.plugins.length,
        itemBuilder: (context, index) {
          final plugin = widget.plugins[index];
          return _buildPluginCard(plugin);
        },
      );
    }

    // 对于大量插件，使用性能优化的列表
    return _buildOptimizedList();
  }

  Widget _buildOptimizedList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _updateVisibleItems();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.plugins.length,
        itemBuilder: (context, index) {
          final plugin = widget.plugins[index];
          final cacheKey = plugin.metadata.id;

          // 标记为可见
          _visibleItems.add(cacheKey);

          return VisibilityDetector(
            key: ValueKey('visible-${cacheKey}'),
            onVisibilityChanged: (visibilityInfo) {
              if (!visibilityInfo.visibleFraction.isNaN) {
                if (visibilityInfo.visibleFraction > 0) {
                  _visibleItems.add(cacheKey);
                } else {
                  _visibleItems.remove(cacheKey);
                }
              }
            },
            child: _buildPluginCard(plugin),
          );
        },
      ),
    );
  }

  Widget _buildDefaultEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.extension_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '未找到插件',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试调整搜索条件或过滤器',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _updateVisibleItems() {
    // 这里可以实现更精确的可见性检测
    // 目前使用简单的定时器清理机制
  }
}

/// 可见性检测组件
/// 用于检测子组件是否可见
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final Key key;
  final Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    required this.key,
    required this.child,
    required this.onVisibilityChanged,
  }) : super(key: key);

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  final GlobalKey _key = GlobalKey();
  bool _hasNotified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_checkVisibility);
  }

  @override
  void didUpdateWidget(VisibilityDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_checkVisibility);
  }

  void _checkVisibility() {
    if (!mounted) return;

    final renderObject = _key.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      final offset = renderObject.localToGlobal(Offset.zero);

      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      // 计算可见区域
      final visibleRect = Rect.fromLTWH(0, 0, screenWidth, screenHeight);
      final widgetRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        size.width,
        size.height,
      );

      // 计算可见比例
      final visibleFraction = _calculateVisibleFraction(visibleRect, widgetRect);

      // 避免重复通知相同状态
      if (!_hasNotified || visibleFraction > 0) {
        widget.onVisibilityChanged(VisibilityInfo(
          visibleFraction: visibleFraction,
          size: size,
          offset: offset,
        ));
        _hasNotified = visibleFraction <= 0;
      }
    }
  }

  double _calculateVisibleFraction(Rect visibleRect, Rect widgetRect) {
    final intersection = visibleRect.intersect(widgetRect);
    if (intersection.isEmpty) return 0.0;

    final widgetArea = widgetRect.width * widgetRect.height;
    final visibleArea = intersection.width * intersection.height;

    return visibleArea / widgetArea;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}

/// 可见性信息
class VisibilityInfo {
  final double visibleFraction;
  final Size size;
  final Offset offset;

  const VisibilityInfo({
    required this.visibleFraction,
    required this.size,
    required this.offset,
  });
}

/// 插件列表性能监控组件
/// 用于监控和优化列表性能
class PluginListPerformanceMonitor extends StatefulWidget {
  final Widget child;
  final int itemCount;
  final Function(double fps)? onPerformanceUpdate;

  const PluginListPerformanceMonitor({
    Key? key,
    required this.child,
    required this.itemCount,
    this.onPerformanceUpdate,
  }) : super(key: key);

  @override
  State<PluginListPerformanceMonitor> createState() => _PluginListPerformanceMonitorState();
}

class _PluginListPerformanceMonitorState extends State<PluginListPerformanceMonitor>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();
  double _currentFPS = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _frameCount++;
    final now = DateTime.now();
    final duration = now.difference(_lastTime);

    if (duration.inMilliseconds >= 1000) {
      setState(() {
        _currentFPS = (_frameCount * 1000.0) / duration.inMilliseconds;
        _frameCount = 0;
        _lastTime = now;
      });

      widget.onPerformanceUpdate?.call(_currentFPS);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // 性能指示器（仅在调试模式下显示）
        if (widget.itemCount > 50)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.speed,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentFPS.toStringAsFixed(1)} FPS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 延迟加载插件卡片
/// 用于在滚动时延迟渲染插件卡片
class LazyPluginCard extends StatefulWidget {
  final CorePlugin plugin;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final Widget? placeholder;

  const LazyPluginCard({
    Key? key,
    required this.plugin,
    this.onTap,
    this.onToggle,
    this.placeholder,
  }) : super(key: key);

  @override
  State<LazyPluginCard> createState() => _LazyPluginCardState();
}

class _LazyPluginCardState extends State<LazyPluginCard>
    with AutomaticKeepAliveClientMixin {
  bool _isLoaded = false;
  bool _isVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 延迟加载，避免滚动时的性能问题
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isLoaded) {
      return widget.placeholder ?? _buildPlaceholder();
    }

    return VisibilityDetector(
      key: ValueKey('lazy-${widget.plugin.metadata.id}'),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0 && !_isVisible) {
          setState(() {
            _isVisible = true;
          });
        } else if (visibilityInfo.visibleFraction == 0 && _isVisible) {
          setState(() {
            _isVisible = false;
          });
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isVisible ? 1.0 : 0.3,
        child: PluginCard(
          plugin: widget.plugin,
          onTap: widget.onTap,
          onToggle: widget.onToggle,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final metadata = widget.plugin.metadata;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标占位符
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.extension, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 标题占位符
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 描述占位符
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}