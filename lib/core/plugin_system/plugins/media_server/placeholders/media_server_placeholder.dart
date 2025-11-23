import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core_plugin.dart';
import '../../../plugin_interface.dart';

/// 社区版媒体服务器占位符插件
class MediaServerPlaceholderPlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'com.coreplayer.mediaserver.placeholder',
    name: '媒体服务器支持 (社区版)',
    version: '1.0.0',
    description: '媒体服务器功能占位符，升级到专业版以获得完整功能',
    author: 'CorePlayer Team',
    icon: Icons.cloud_off,
    capabilities: ['placeholder'],
    license: PluginLicense.proprietary,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  MediaServerPlaceholderPlugin();

  @override
  PluginMetadata get metadata => _metadata;

  @override
  PluginState get state => _internalState;

  @override
  void setStateInternal(PluginState newState) {
    _internalState = newState;
  }

  @override
  Future<void> onInitialize() async {
    // 占位符实现，仅记录初始化
    print('MediaServerPlaceholderPlugin initialized (Community Edition)');
  }

  @override
  Future<void> onActivate() async {
    // 占位符实现，抛出功能不可用异常
    throw FeatureNotAvailableException(
      '媒体服务器功能仅专业版可用，请升级到专业版以获得SMB、Emby、Jellyfin等媒体服务器支持',
      upgradeUrl: 'https://coreplayer.example.com/upgrade',
    );
  }

  @override
  Future<void> onDeactivate() async {
    // 占位符实现，仅记录停用
    print('MediaServerPlaceholderPlugin deactivated');
  }

  @override
  Future<void> onDispose() async {
    print('MediaServerPlaceholderPlugin disposed');
  }

  @override
  Future<bool> onHealthCheck() async {
    // 占位符健康检查
    return true;
  }

  /// 获取升级URL
  String getUpgradeUrl() {
    return 'https://coreplayer.example.com/upgrade';
  }

  /// 获取升级提示消息
  String getUpgradeMessage() {
    return '要使用媒体服务器功能，请升级到专业版';
  }
}