import 'package:flutter/material.dart';
import '../plugins/builtin/ui_themes/theme_plugin.dart';
import '../services/plugin_lazy_loader.dart';
import '../core/plugin_system/plugin_interface.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  ThemePlugin? _themePlugin;
  List<PluginTheme> _availableThemes = [];
  String? _currentThemeId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePlugin();
  }

  Future<void> _loadThemePlugin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 从懒加载器获取主题插件实例
      final plugin = PluginLazyLoader().getPlugin('coreplayer.theme_manager');

      if (plugin != null && plugin is ThemePlugin) {
        _themePlugin = plugin;
        _availableThemes = plugin.getAvailableThemes();
        _currentThemeId = plugin.currentThemeInfo.id;
      } else {
        // 如果插件尚未加载，尝试加载它
        final loadedPlugin = await PluginLazyLoader().loadPlugin('coreplayer.theme_manager');
        if (loadedPlugin != null && loadedPlugin is ThemePlugin) {
          // 激活插件
          if (loadedPlugin.state != PluginState.active) {
            await loadedPlugin.activate();
          }

          _themePlugin = loadedPlugin;
          _availableThemes = loadedPlugin.getAvailableThemes();
          _currentThemeId = loadedPlugin.currentThemeInfo.id;
        }
      }
    } catch (e) {
      // Failed to load theme plugin
      if (mounted) {
        debugPrint('Failed to load theme plugin: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _applyTheme(String themeId) async {
    if (_themePlugin == null) return;

    try {
      await _themePlugin!.applyTheme(themeId);
      setState(() {
        _currentThemeId = themeId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('主题已应用'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('应用主题失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('外观设置'),
        actions: [
          if (_themePlugin != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showThemeStats,
              tooltip: '主题统计',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _themePlugin == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('主题插件未加载'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadThemePlugin,
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                )
              : _buildThemeList(),
    );
  }

  Widget _buildThemeList() {
    // 分组显示主题
    final builtinThemes = _availableThemes.where((t) => !t.isCustom).toList();
    final customThemes = _availableThemes.where((t) => t.isCustom).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前主题信息
        if (_themePlugin != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前主题',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _themePlugin!.currentThemeInfo.name,
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _themePlugin!.currentThemeInfo.isDark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _themePlugin!.currentThemeInfo.isDark ? '深色' : '浅色',
                      ),
                      if (_themePlugin!.currentThemeInfo.isCustom) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.edit, size: 16),
                        const SizedBox(width: 4),
                        const Text('自定义'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),

        // 内置主题
        _buildSectionHeader('内置主题'),
        const SizedBox(height: 8),
        ...builtinThemes.map((theme) => _buildThemeCard(theme)),

        // 自定义主题
        if (customThemes.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('自定义主题'),
          const SizedBox(height: 8),
          ...customThemes.map((theme) => _buildThemeCard(theme)),
        ],

        // 创建自定义主题按钮
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _showCreateCustomThemeDialog,
          icon: const Icon(Icons.add),
          label: const Text('创建自定义主题'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildThemeCard(PluginTheme theme) {
    final isSelected = _currentThemeId == theme.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () => _applyTheme(theme.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 主题名称和描述
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              theme.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : null,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 主题类型图标
                  Icon(
                    theme.isDark ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 颜色预览
              Row(
                children: [
                  _buildColorPreview(
                    theme.previewColors['primary'] ?? Colors.grey,
                    'Primary',
                  ),
                  const SizedBox(width: 12),
                  _buildColorPreview(
                    theme.previewColors['secondary'] ?? Colors.grey,
                    'Secondary',
                  ),
                  const SizedBox(width: 12),
                  _buildColorPreview(
                    theme.previewColors['background'] ?? Colors.grey,
                    'Background',
                  ),
                  const SizedBox(width: 12),
                  _buildColorPreview(
                    theme.previewColors['surface'] ?? Colors.grey,
                    'Surface',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPreview(Color color, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeStats() {
    if (_themePlugin == null) return;

    final stats = _themePlugin!.getThemeStats();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主题统计'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总主题数: ${stats.totalThemes}'),
            Text('内置主题: ${stats.builtinThemes}'),
            Text('自定义主题: ${stats.customThemes}'),
            const SizedBox(height: 8),
            Text('当前主题: ${stats.activeTheme}'),
            Text('当前模式: ${stats.isDarkMode ? "深色" : "浅色"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showCreateCustomThemeDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    Color primaryColor = Colors.blue;
    Color secondaryColor = Colors.orange;
    Color backgroundColor = const Color(0xFF121212);
    Color surfaceColor = const Color(0xFF1E1E1E);
    bool isDark = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建自定义主题'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '主题名称',
                      hintText: '我的自定义主题',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '主题描述',
                      hintText: '一个美丽的自定义主题',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('深色模式'),
                    value: isDark,
                    onChanged: (value) {
                      setState(() {
                        isDark = value;
                        if (isDark) {
                          backgroundColor = const Color(0xFF121212);
                          surfaceColor = const Color(0xFF1E1E1E);
                        } else {
                          backgroundColor = Colors.white;
                          surfaceColor = const Color(0xFFF5F5F5);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('颜色配置', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildColorPicker('主色调', primaryColor, (color) {
                    setState(() => primaryColor = color);
                  }),
                  _buildColorPicker('次要色', secondaryColor, (color) {
                    setState(() => secondaryColor = color);
                  }),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入主题名称')),
                );
                return;
              }

              _themePlugin!.createCustomTheme(
                name: nameController.text,
                description: descriptionController.text.isEmpty
                    ? '自定义主题'
                    : descriptionController.text,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                backgroundColor: backgroundColor,
                surfaceColor: surfaceColor,
                isDark: isDark,
              );

              Navigator.of(context).pop();
              _loadThemePlugin();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('自定义主题"${nameController.text}"已创建')),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(
    String label,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    return ListTile(
      title: Text(label),
      trailing: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
      ),
      onTap: () {
        // 这里可以集成一个颜色选择器
        // 为了简化，我们暂时使用随机颜色
        final colors = _themePlugin!.generateRandomColorScheme(isDark: true);
        onColorChanged(colors['primary']!);
      },
    );
  }
}
