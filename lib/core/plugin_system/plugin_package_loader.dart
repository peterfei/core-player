import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'plugin_interface.dart';
import 'core_plugin.dart';

/// 插件包加载器
///
/// 支持从 .tar.gz 插件包中加载插件，验证插件元数据和许可证
class PluginPackageLoader {
  static PluginPackageLoader? _instance;
  static PluginPackageLoader get instance {
    _instance ??= PluginPackageLoader._internal();
    return _instance!;
  }

  PluginPackageLoader._internal();

  /// 已加载的插件包缓存
  final Map<String, PluginPackage> _loadedPackages = {};

  /// 从插件包加载插件
  ///
  /// [packagePath] 插件包文件路径
  /// [isProfessionalEdition] 当前应用是否为专业版
  ///
  /// 返回插件元数据
  Future<PluginMetadata> loadFromPackage(
    String packagePath, {
    bool isProfessionalEdition = false,
  }) async {
    try {
      // 检查缓存
      if (_loadedPackages.containsKey(packagePath)) {
        final cachedPackage = _loadedPackages[packagePath]!;
        final metadata = cachedPackage.metadata;
        if (metadata != null) {
          return metadata;
        }
      }

      // 验证文件存在
      if (!await File(packagePath).exists()) {
        throw PluginPackageException('插件包文件不存在: $packagePath');
      }

      // 解压插件包
      final package = await _extractPackage(packagePath);

      // 验证插件包结构
      await _validatePackageStructure(package);

      // 读取插件元数据
      final metadata = await _loadPluginMetadata(package);

      // 验证插件兼容性
      await _validatePluginCompatibility(metadata);

      // 验证许可证文件
      await _validateLicenseFiles(package, metadata);

      // 缓存插件包和元数据
      package.setMetadata(metadata);
      _loadedPackages[packagePath] = package;

      return metadata;
    } catch (e) {
      throw PluginPackageException('加载插件包失败: $e', originalError: e);
    }
  }

  /// 从插件包加载插件实例
  Future<CorePlugin> loadPluginInstance(
    String packagePath, {
    bool isProfessionalEdition = false,
  }) async {
    try {
      final metadata = await loadFromPackage(packagePath);

      // 检查插件是否可用于当前版本
      if (!metadata.isAvailableForEdition(isProfessionalEdition)) {
        throw PluginPackageException(
          '插件 ${metadata.name} 不可用于当前版本',
          pluginId: metadata.id,
        );
      }

      // TODO: 实现动态加载插件代码
      // 这需要更复杂的动态代码加载机制，可能需要使用 `dart:mirrors` 或类似的反射机制
      throw UnimplementedError('动态插件实例加载需要进一步实现');

    } catch (e) {
      throw PluginPackageException('加载插件实例失败: $e', originalError: e);
    }
  }

  /// 解压插件包
  Future<PluginPackage> _extractPackage(String packagePath) async {
    final file = File(packagePath);
    final bytes = await file.readAsBytes();

    // 解压 tar.gz
    final decompressed = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(decompressed);

    // 临时目录
    final tempDir = Directory.systemTemp.createTempSync('plugin_package_');

    // 解压文件到临时目录
    for (final file in archive) {
      final filePath = path.join(tempDir.path, file.name);

      if (file.isFile) {
        final outputFile = File(filePath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
      } else {
        // 这是一个目录
        await Directory(filePath).create(recursive: true);
      }
    }

    return PluginPackage(
      path: packagePath,
      extractPath: tempDir.path,
      files: archive.files.map((f) => f.name).toList(),
    );
  }

  /// 验证插件包结构
  Future<void> _validatePackageStructure(PluginPackage package) async {
    final requiredFiles = [
      'plugin.yaml',
      'lib/',
    ];

    final optionalFiles = [
      'LICENSE-MIT',
      'LICENSE-PROPRIETARY',
      'README.md',
    ];

    // 检查必需文件
    for (final requiredFile in requiredFiles) {
      if (!package.files.any((file) => file.startsWith(requiredFile))) {
        throw PluginPackageException('缺少必需文件: $requiredFile');
      }
    }

    // 检查 lib 目录结构
    if (!package.files.any((file) => file.startsWith('lib/') && file.endsWith('.dart'))) {
      throw PluginPackageException('缺少插件代码文件 (lib/*.dart)');
    }
  }

  /// 加载插件元数据
  Future<PluginMetadata> _loadPluginMetadata(PluginPackage package) async {
    final yamlPath = path.join(package.extractPath, 'plugin.yaml');
    final yamlFile = File(yamlPath);

    if (!await yamlFile.exists()) {
      throw PluginPackageException('插件元数据文件不存在: plugin.yaml');
    }

    try {
      final yamlContent = await yamlFile.readAsString();
      final yamlMap = loadYaml(yamlContent) as Map;

      return PluginMetadata.fromJson(Map<String, dynamic>.from(yamlMap));
    } catch (e) {
      throw PluginPackageException('解析插件元数据失败: $e');
    }
  }

  /// 验证插件兼容性
  Future<void> _validatePluginCompatibility(PluginMetadata metadata) async {
    try {
      // 检查核心版本兼容性
      final currentCoreVersion = await _getCurrentCoreVersion();
      if (!metadata.isCompatibleWith(currentCoreVersion)) {
        throw PluginPackageException(
          '插件版本不兼容。需要: ${metadata.minCoreVersion}-${metadata.maxCoreVersion}，当前: $currentCoreVersion',
          pluginId: metadata.id,
        );
      }

      // 检查依赖
      for (final dependency in metadata.dependencies) {
        // TODO: 实现依赖检查逻辑
        print('检查依赖: $dependency');
      }

      // 检查权限
      final grantedPermissions = await _getGrantedPermissions();
      for (final permission in metadata.permissions) {
        if (!grantedPermissions.contains(permission)) {
          throw PluginPackageException(
            '插件需要权限: ${permission.displayName}',
            pluginId: metadata.id,
          );
        }
      }
    } catch (e) {
      if (e is PluginPackageException) rethrow;
      throw PluginPackageException('插件兼容性检查失败: $e', pluginId: metadata.id);
    }
  }

  /// 验证许可证文件
  Future<void> _validateLicenseFiles(PluginPackage package, PluginMetadata metadata) async {
    if (metadata.edition == PluginEdition.both) {
      // 双版本插件需要两个许可证文件
      final mitLicense = File(path.join(package.extractPath, 'LICENSE-MIT'));
      final proprietaryLicense = File(path.join(package.extractPath, 'LICENSE-PROPRIETARY'));

      if (!await mitLicense.exists()) {
        throw PluginPackageException('双版本插件缺少 MIT 许可证文件: LICENSE-MIT');
      }

      if (!await proprietaryLicense.exists()) {
        throw PluginPackageException('双版本插件缺少 Proprietary 许可证文件: LICENSE-PROPRIETARY');
      }
    } else {
      // 单版本插件需要对应许可证文件
      final licenseFile = metadata.license == PluginLicense.mit
          ? File(path.join(package.extractPath, 'LICENSE-MIT'))
          : File(path.join(package.extractPath, 'LICENSE-PROPRIETARY'));

      if (!await licenseFile.exists()) {
        throw PluginPackageException('缺少许可证文件: ${licenseFile.path}');
      }
    }
  }

  /// 获取当前核心版本
  Future<String> _getCurrentCoreVersion() async {
    // TODO: 从应用配置或包信息中获取版本
    return '1.0.0'; // 暂时返回固定版本
  }

  /// 获取已授权的权限列表
  Future<Set<PluginPermission>> _getGrantedPermissions() async {
    // TODO: 从应用权限配置中获取
    return PluginPermission.values.toSet();
  }

  /// 清理临时文件
  Future<void> cleanup() async {
    for (final package in _loadedPackages.values) {
      try {
        final dir = Directory(package.extractPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        print('清理临时文件失败: $e');
      }
    }
    _loadedPackages.clear();
  }

  /// 验证插件包完整性
  Future<bool> verifyPackageIntegrity(String packagePath) async {
    try {
      await loadFromPackage(packagePath);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// 插件包信息
class PluginPackage {
  final String path;           // 原始包文件路径
  final String extractPath;    // 解压路径
  final List<String> files;    // 包含的文件列表
  PluginMetadata? _metadata;  // 🔥 缓存的元数据

  PluginPackage({
    required this.path,
    required this.extractPath,
    required this.files,
  });

  /// 获取插件元数据
  PluginMetadata? get metadata => _metadata;

  /// 设置插件元数据
  void setMetadata(PluginMetadata metadata) {
    _metadata = metadata;
  }
}

/// 插件包异常
class PluginPackageException extends PluginException {
  PluginPackageException(String message, {String? pluginId, dynamic originalError})
      : super(message, pluginId: pluginId, originalError: originalError);
}