import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class MetadataSettingsScreen extends StatefulWidget {
  const MetadataSettingsScreen({super.key});

  @override
  State<MetadataSettingsScreen> createState() => _MetadataSettingsScreenState();
}

class _MetadataSettingsScreenState extends State<MetadataSettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _accessTokenController = TextEditingController();
  bool _isLoading = true;

  bool _enableVideoThumbnails = false;
  String _defaultCoverStyle = 'gradient';
  
  int _scrapingRetryCount = 3;
  double _scrapingSimilarityThreshold = 0.8;
  double _scrapingMinConfidence = 0.4;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    _accessTokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final apiKey = await SettingsService.getTMDBApiKey();
    final accessToken = await SettingsService.getTMDBAccessToken();
    final enableVideoThumbnails = await SettingsService.isVideoThumbnailsEnabled();
    final defaultCoverStyle = await SettingsService.getDefaultCoverStyle();
    final scrapingRetryCount = await SettingsService.getScrapingRetryCount();
    final scrapingSimilarityThreshold = await SettingsService.getScrapingSimilarityThreshold();
    final scrapingMinConfidence = await SettingsService.getScrapingMinConfidence();

    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _accessTokenController.text = accessToken ?? '';
        _enableVideoThumbnails = enableVideoThumbnails;
        _defaultCoverStyle = defaultCoverStyle;
        _scrapingRetryCount = scrapingRetryCount;
        _scrapingSimilarityThreshold = scrapingSimilarityThreshold;
        _scrapingMinConfidence = scrapingMinConfidence;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final apiKey = _apiKeyController.text.trim();
    final accessToken = _accessTokenController.text.trim();
    
    await SettingsService.setTMDBApiKey(apiKey);
    await SettingsService.setTMDBAccessToken(accessToken);
    await SettingsService.setVideoThumbnailsEnabled(_enableVideoThumbnails);
    await SettingsService.setDefaultCoverStyle(_defaultCoverStyle);
    await SettingsService.setScrapingRetryCount(_scrapingRetryCount);
    await SettingsService.setScrapingSimilarityThreshold(_scrapingSimilarityThreshold);
    await SettingsService.setScrapingMinConfidence(_scrapingMinConfidence);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('元数据与封面设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '封面设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('使用视频截图作为封面 (专业版)'),
                  subtitle: const Text('当无法获取在线封面时，尝试从视频文件中提取截图'),
                  value: _enableVideoThumbnails,
                  onChanged: (value) {
                    setState(() {
                      _enableVideoThumbnails = value;
                    });
                  },
                ),
                ListTile(
                  title: const Text('默认封面样式'),
                  subtitle: const Text('当没有封面时显示的默认样式'),
                  trailing: DropdownButton<String>(
                    value: _defaultCoverStyle,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _defaultCoverStyle = newValue;
                        });
                      }
                    },
                    items: <String>['gradient', 'solid']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value == 'gradient' ? '渐变' : '纯色'),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 32),
                const Text(
                  'TMDB 设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '配置 TMDB API Key 可以让应用自动获取剧集的海报、背景图和简介等信息。',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'TMDB API Key',
                    hintText: '请输入您的 API Key (v3)',
                    border: OutlineInputBorder(),
                    helperText: '传统的 API Key 认证方式',
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _accessTokenController,
                  decoration: const InputDecoration(
                    labelText: 'TMDB API Read Access Token',
                    hintText: '请输入您的 API Read Access Token (v4)',
                    border: OutlineInputBorder(),
                    helperText: '推荐使用 Access Token，安全性更高',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 32),
                const Text(
                  '刮削高级设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('重试次数'),
                  subtitle: Text('网络请求失败时的重试次数: $_scrapingRetryCount'),
                  trailing: DropdownButton<int>(
                    value: _scrapingRetryCount,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _scrapingRetryCount = newValue;
                        });
                      }
                    },
                    items: <int>[1, 2, 3, 4, 5]
                        .map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                  ),
                ),
                ListTile(
                  title: const Text('相似度阈值'),
                  subtitle: Text('高于此值时立即停止搜索: ${_scrapingSimilarityThreshold.toStringAsFixed(2)}'),
                ),
                Slider(
                  value: _scrapingSimilarityThreshold,
                  min: 0.5,
                  max: 1.0,
                  divisions: 10,
                  label: _scrapingSimilarityThreshold.toStringAsFixed(2),
                  onChanged: (double value) {
                    setState(() {
                      _scrapingSimilarityThreshold = value;
                    });
                  },
                ),
                ListTile(
                  title: const Text('最低置信度'),
                  subtitle: Text('低于此值时视为未找到: ${_scrapingMinConfidence.toStringAsFixed(2)}'),
                ),
                Slider(
                  value: _scrapingMinConfidence,
                  min: 0.1,
                  max: 0.9,
                  divisions: 16,
                  label: _scrapingMinConfidence.toStringAsFixed(2),
                  onChanged: (double value) {
                    setState(() {
                      _scrapingMinConfidence = value;
                    });
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('保存设置'),
                ),
              ],
            ),
    );
  }
}
