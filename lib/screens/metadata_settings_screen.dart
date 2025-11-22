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
    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _accessTokenController.text = accessToken ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final apiKey = _apiKeyController.text.trim();
    final accessToken = _accessTokenController.text.trim();
    
    await SettingsService.setTMDBApiKey(apiKey);
    await SettingsService.setTMDBAccessToken(accessToken);
    
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
        title: const Text('元数据设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('保存设置'),
                ),
              ],
            ),
    );
  }
}
