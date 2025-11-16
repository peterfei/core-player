import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.color_lens),
            title: Text('外观设置'),
            subtitle: Text('更改应用的外观和感觉'),
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('通知设置'),
            subtitle: Text('管理通知偏好设置'),
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('关于应用'),
            subtitle: Text('应用版本和相关信息'),
          ),
        ],
      ),
    );
  }
}
