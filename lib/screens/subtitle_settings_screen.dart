import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/subtitle_service.dart';
import '../models/subtitle_config.dart';
import '../models/subtitle_track.dart';

/// 字幕设置界面
class SubtitleSettingsScreen extends StatefulWidget {
  const SubtitleSettingsScreen({super.key});

  @override
  State<SubtitleSettingsScreen> createState() => _SubtitleSettingsScreenState();
}

class _SubtitleSettingsScreenState extends State<SubtitleSettingsScreen> {
  final SubtitleService _subtitleService = SubtitleService.instance;
  late SubtitleConfig _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = _subtitleService.config;
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subtitle config: $e');
      setState(() {
        _config = SubtitleConfig.defaultConfig();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    try {
      await _subtitleService.saveConfig(_config);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('字幕设置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving subtitle config: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _config = SubtitleConfig.defaultConfig();
    });
    await _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('字幕设置'),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: _saveConfig,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGeneralSettings(),
          const SizedBox(height: 32),
          _buildStyleSettings(),
          const SizedBox(height: 32),
          _buildPositionSettings(),
          const SizedBox(height: 32),
          _buildLanguageSettings(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return _buildSection(
      '基本设置',
      children: [
        SwitchListTile(
          title: const Text('启用字幕'),
          subtitle: const Text('开启或关闭字幕功能'),
          value: _config.enabled,
          onChanged: (value) {
            setState(() {
              _config = _config.copyWith(enabled: value);
            });
          },
        ),
        SwitchListTile(
          title: const Text('自动加载同名字幕'),
          subtitle: const Text('播放视频时自动查找同名字幕文件'),
          value: _config.autoLoad,
          onChanged: (value) {
            setState(() {
              _config = _config.copyWith(autoLoad: value);
            });
          },
        ),
        ListTile(
          title: const Text('字幕编码'),
          subtitle: Text(_config.preferredEncoding),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showEncodingSelector(),
        ),
      ],
    );
  }

  Widget _buildStyleSettings() {
    return _buildSection(
      '样式设置',
      children: [
        ListTile(
          title: const Text('字体大小'),
          subtitle: Text('${_config.fontSize.toInt()} 像素'),
          trailing: SizedBox(
            width: 150,
            child: Slider(
              value: _config.fontSize,
              min: 24.0,
              max: 72.0,
              divisions: 12,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(fontSize: value);
                });
              },
            ),
          ),
        ),
        ListTile(
          title: const Text('字体颜色'),
          subtitle: const Text('选择字幕文字颜色'),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(_config.fontColor),
              border: Border.all(color: Colors.white),
            ),
          ),
          onTap: () => _showColorSelector('字体颜色', (color) {
            setState(() {
              _config = _config.copyWith(fontColor: color.value);
            });
          }),
        ),
        ListTile(
          title: const Text('背景颜色'),
          subtitle: const Text('选择字幕背景颜色'),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(_config.backgroundColor),
              border: Border.all(color: Colors.white),
            ),
          ),
          onTap: () => _showColorSelector('背景颜色', (color) {
            setState(() {
              _config = _config.copyWith(backgroundColor: color.value);
            });
          }),
        ),
        ListTile(
          title: const Text('背景透明度'),
          subtitle: Text('${(_config.backgroundOpacity * 100).toInt()}%'),
          trailing: SizedBox(
            width: 150,
            child: Slider(
              value: _config.backgroundOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(backgroundOpacity: value);
                });
              },
            ),
          ),
        ),
        ListTile(
          title: const Text('描边颜色'),
          subtitle: const Text('选择字幕描边颜色'),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(_config.outlineColor),
              border: Border.all(color: Colors.white),
            ),
          ),
          onTap: () => _showColorSelector('描边颜色', (color) {
            setState(() {
              _config = _config.copyWith(outlineColor: color.value);
            });
          }),
        ),
        ListTile(
          title: const Text('描边宽度'),
          subtitle: Text('${_config.outlineWidth.toInt()} 像素'),
          trailing: SizedBox(
            width: 150,
            child: Slider(
              value: _config.outlineWidth,
              min: 0.0,
              max: 5.0,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(outlineWidth: value);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionSettings() {
    return _buildSection(
      '位置设置',
      children: [
        ListTile(
          title: const Text('字幕位置'),
          subtitle: Text(_positionToString(_config.position)),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showPositionSelector(),
        ),
      ],
    );
  }

  Widget _buildLanguageSettings() {
    return _buildSection(
      '语言设置',
      children: [
        ListTile(
          title: const Text('首选语言'),
          subtitle: Text(_config.preferredLanguages.join(', ')),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showLanguageSelector(),
        ),
      ],
    );
  }

  Widget _buildSection(String title, {required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  void _showColorSelector(String title, Function(Color) onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => _ColorSelectorDialog(
        title: title,
        initialColor: Color(title == '字体颜色'
            ? _config.fontColor
            : title == '背景颜色'
                ? _config.backgroundColor
                : _config.outlineColor),
        onColorSelected: onColorSelected,
      ),
    );
  }

  void _showPositionSelector() {
    showDialog(
      context: context,
      builder: (context) => _PositionSelectorDialog(
        initialPosition: _config.position,
        onPositionSelected: (position) {
          setState(() {
            _config = _config.copyWith(position: position);
          });
        },
      ),
    );
  }

  void _showEncodingSelector() {
    final encodings = ['UTF-8', 'GBK', 'BIG5', 'SHIFT_JIS', 'EUC-KR'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择编码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: encodings
              .map((encoding) => RadioListTile<String>(
                    title: Text(encoding),
                    value: encoding,
                    groupValue: _config.preferredEncoding,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _config = _config.copyWith(preferredEncoding: value);
                        });
                        Navigator.of(context).pop();
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => _LanguageSelectorDialog(
        initialLanguages: _config.preferredLanguages,
        onLanguagesSelected: (languages) {
          setState(() {
            _config = _config.copyWith(preferredLanguages: languages);
          });
        },
      ),
    );
  }

  String _positionToString(SubtitlePosition position) {
    switch (position) {
      case SubtitlePosition.top:
        return '顶部';
      case SubtitlePosition.center:
        return '居中';
      case SubtitlePosition.bottom:
        return '底部';
    }
  }
}

/// 颜色选择器对话框
class _ColorSelectorDialog extends StatefulWidget {
  final String title;
  final Color initialColor;
  final Function(Color) onColorSelected;

  const _ColorSelectorDialog({
    required this.title,
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorSelectorDialog> createState() => _ColorSelectorDialogState();
}

class _ColorSelectorDialogState extends State<_ColorSelectorDialog> {
  late Color _selectedColor;
  final List<Color> _presetColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
    Colors.orange,
    Colors.purple,
    Colors.transparent,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('选择${widget.title}'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 预设颜色
            const Text('预设颜色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetColors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color:
                            _selectedColor == color ? Colors.blue : Colors.grey,
                        width: _selectedColor == color ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 当前选择预览
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: _selectedColor,
                border: Border.all(color: Colors.white),
              ),
              child: Center(
                child: Text(
                  '示例字幕文本',
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onColorSelected(_selectedColor);
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 位置选择器对话框
class _PositionSelectorDialog extends StatefulWidget {
  final SubtitlePosition initialPosition;
  final Function(SubtitlePosition) onPositionSelected;

  const _PositionSelectorDialog({
    required this.initialPosition,
    required this.onPositionSelected,
  });

  @override
  State<_PositionSelectorDialog> createState() =>
      _PositionSelectorDialogState();
}

class _PositionSelectorDialogState extends State<_PositionSelectorDialog> {
  late SubtitlePosition _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择字幕位置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: SubtitlePosition.values.map((position) {
          return RadioListTile<SubtitlePosition>(
            title: Text(_positionToString(position)),
            value: position,
            groupValue: _selectedPosition,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPosition = value;
                });
              }
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onPositionSelected(_selectedPosition);
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  String _positionToString(SubtitlePosition position) {
    switch (position) {
      case SubtitlePosition.top:
        return '顶部';
      case SubtitlePosition.center:
        return '居中';
      case SubtitlePosition.bottom:
        return '底部';
    }
  }
}

/// 语言选择器对话框
class _LanguageSelectorDialog extends StatefulWidget {
  final List<String> initialLanguages;
  final Function(List<String>) onLanguagesSelected;

  const _LanguageSelectorDialog({
    required this.initialLanguages,
    required this.onLanguagesSelected,
  });

  @override
  State<_LanguageSelectorDialog> createState() =>
      _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<_LanguageSelectorDialog> {
  late Set<String> _selectedLanguages;

  final Map<String, String> _languageMap = {
    'zh': '简体中文',
    'zh-CN': '简体中文',
    'zh-TW': '繁体中文',
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
  };

  @override
  void initState() {
    super.initState();
    _selectedLanguages = widget.initialLanguages.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择首选语言'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: ListView(
          children: _languageMap.entries.map((entry) {
            final code = entry.key;
            final name = entry.value;
            final isSelected = _selectedLanguages.contains(code);

            return CheckboxListTile(
              title: Text(name),
              subtitle: Text('($code)'),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedLanguages.add(code);
                  } else {
                    _selectedLanguages.remove(code);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onLanguagesSelected(_selectedLanguages.toList());
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
