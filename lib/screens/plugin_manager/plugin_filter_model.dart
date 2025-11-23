import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';

/// 插件过滤器配置
class PluginFilter {
  final PluginState? state;
  final PluginLicense? license;
  final List<PluginPermission>? permissions;
  final List<String>? capabilities;
  final String? author;
  final bool onlyEnabled;
  final bool onlyDisabled;
  final bool onlyWithError;
  final bool onlyCommercial;
  final bool onlyFree;

  const PluginFilter({
    this.state,
    this.license,
    this.permissions,
    this.capabilities,
    this.author,
    this.onlyEnabled = false,
    this.onlyDisabled = false,
    this.onlyWithError = false,
    this.onlyCommercial = false,
    this.onlyFree = false,
  });

  PluginFilter copyWith({
    PluginState? state,
    PluginLicense? license,
    List<PluginPermission>? permissions,
    List<String>? capabilities,
    String? author,
    bool? onlyEnabled,
    bool? onlyDisabled,
    bool? onlyWithError,
    bool? onlyCommercial,
    bool? onlyFree,
  }) {
    return PluginFilter(
      state: state ?? this.state,
      license: license ?? this.license,
      permissions: permissions ?? this.permissions,
      capabilities: capabilities ?? this.capabilities,
      author: author ?? this.author,
      onlyEnabled: onlyEnabled ?? this.onlyEnabled,
      onlyDisabled: onlyDisabled ?? this.onlyDisabled,
      onlyWithError: onlyWithError ?? this.onlyWithError,
      onlyCommercial: onlyCommercial ?? this.onlyCommercial,
      onlyFree: onlyFree ?? this.onlyFree,
    );
  }

  bool get isEmpty =>
      state == null &&
      license == null &&
      (permissions == null || permissions!.isEmpty) &&
      (capabilities == null || capabilities!.isEmpty) &&
      author == null &&
      !onlyEnabled &&
      !onlyDisabled &&
      !onlyWithError &&
      !onlyCommercial &&
      !onlyFree;

  bool matches(CorePlugin plugin) {
    final metadata = plugin.metadata;

    // 状态过滤
    if (state != null && plugin.state != state) return false;

    // 许可证过滤
    if (license != null && metadata.license != license) return false;

    // 权限过滤
    if (permissions != null && permissions!.isNotEmpty) {
      if (!permissions!.any((permission) => metadata.permissions.contains(permission))) {
        return false;
      }
    }

    // 功能过滤
    if (capabilities != null && capabilities!.isNotEmpty) {
      if (!capabilities!.any((capability) =>
          metadata.capabilities.any((cap) => cap.toLowerCase().contains(capability.toLowerCase())))) {
        return false;
      }
    }

    // 作者过滤
    if (author != null && author!.isNotEmpty) {
      if (!metadata.author.toLowerCase().contains(author!.toLowerCase())) {
        return false;
      }
    }

    // 启用状态过滤
    if (onlyEnabled && !plugin.isActive) return false;
    if (onlyDisabled && plugin.isActive) return false;
    if (onlyWithError && plugin.state != PluginState.error) return false;

    // 商业/免费过滤
    if (onlyCommercial && metadata.license == PluginLicense.mit) return false;
    if (onlyFree && metadata.license != PluginLicense.mit) return false;

    return true;
  }
}

/// 插件排序配置
enum PluginSortOption {
  name,
  author,
  version,
  status,
  lastUpdated,
  capabilities,
  license,
}

enum SortOrder {
  ascending,
  descending,
}

class PluginSortConfig {
  final PluginSortOption option;
  final SortOrder order;

  const PluginSortConfig({
    required this.option,
    required this.order,
  });

  PluginSortConfig copyWith({
    PluginSortOption? option,
    SortOrder? order,
  }) {
    return PluginSortConfig(
      option: option ?? this.option,
      order: order ?? this.order,
    );
  }

  int compare(CorePlugin a, CorePlugin b) {
    final result = _compareValues(a, b);
    return order == SortOrder.ascending ? result : -result;
  }

  int _compareValues(CorePlugin a, CorePlugin b) {
    switch (option) {
      case PluginSortOption.name:
        return a.metadata.name.toLowerCase().compareTo(b.metadata.name.toLowerCase());
      case PluginSortOption.author:
        return a.metadata.author.toLowerCase().compareTo(b.metadata.author.toLowerCase());
      case PluginSortOption.version:
        return _compareVersion(a.metadata.version, b.metadata.version);
      case PluginSortOption.status:
        return a.state.index.compareTo(b.state.index);
      case PluginSortOption.capabilities:
        return a.metadata.capabilities.length.compareTo(b.metadata.capabilities.length);
      case PluginSortOption.license:
        return a.metadata.license.displayName.compareTo(b.metadata.license.displayName);
      case PluginSortOption.lastUpdated:
        // 假设插件元数据中有更新时间信息
        return 0; // 暂时返回相等，实际实现中需要添加时间戳比较
    }
  }

  int _compareVersion(String versionA, String versionB) {
    final aParts = versionA.split('.').map(int.tryParse).toList();
    final bParts = versionB.split('.').map(int.tryParse).toList();

    final maxLength = aParts.length > bParts.length ? aParts.length : bParts.length;

    for (int i = 0; i < maxLength; i++) {
      final aPart = i < aParts.length ? aParts[i] ?? 0 : 0;
      final bPart = i < bParts.length ? bParts[i] ?? 0 : 0;

      if (aPart != bPart) {
        return aPart.compareTo(bPart);
      }
    }

    return 0;
  }
}

/// 插件搜索配置
class PluginSearchConfig {
  final String query;
  final bool searchName;
  final bool searchDescription;
  final bool searchAuthor;
  final bool searchCapabilities;
  final bool searchPermissions;
  final bool caseSensitive;

  const PluginSearchConfig({
    this.query = '',
    this.searchName = true,
    this.searchDescription = true,
    this.searchAuthor = true,
    this.searchCapabilities = true,
    this.searchPermissions = false,
    this.caseSensitive = false,
  });

  PluginSearchConfig copyWith({
    String? query,
    bool? searchName,
    bool? searchDescription,
    bool? searchAuthor,
    bool? searchCapabilities,
    bool? searchPermissions,
    bool? caseSensitive,
  }) {
    return PluginSearchConfig(
      query: query ?? this.query,
      searchName: searchName ?? this.searchName,
      searchDescription: searchDescription ?? this.searchDescription,
      searchAuthor: searchAuthor ?? this.searchAuthor,
      searchCapabilities: searchCapabilities ?? this.searchCapabilities,
      searchPermissions: searchPermissions ?? this.searchPermissions,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  bool matches(CorePlugin plugin) {
    if (query.isEmpty) return true;

    final searchQuery = caseSensitive ? query : query.toLowerCase();

    // 搜索名称
    if (searchName) {
      final name = caseSensitive ? plugin.metadata.name : plugin.metadata.name.toLowerCase();
      if (name.contains(searchQuery)) return true;
    }

    // 搜索描述
    if (searchDescription) {
      final description = caseSensitive
          ? plugin.metadata.description
          : plugin.metadata.description.toLowerCase();
      if (description.contains(searchQuery)) return true;
    }

    // 搜索作者
    if (searchAuthor) {
      final author = caseSensitive
          ? plugin.metadata.author
          : plugin.metadata.author.toLowerCase();
      if (author.contains(searchQuery)) return true;
    }

    // 搜索功能
    if (searchCapabilities) {
      for (final capability in plugin.metadata.capabilities) {
        final cap = caseSensitive ? capability : capability.toLowerCase();
        if (cap.contains(searchQuery)) return true;
      }
    }

    // 搜索权限
    if (searchPermissions) {
      for (final permission in plugin.metadata.permissions) {
        final perm = caseSensitive ? permission.displayName : permission.displayName.toLowerCase();
        if (perm.contains(searchQuery)) return true;
      }
    }

    return false;
  }
}

/// 插件展示配置
class PluginDisplayConfig {
  final PluginFilter filter;
  final PluginSortConfig sortConfig;
  final PluginSearchConfig searchConfig;
  final int itemsPerPage;
  final bool showPreviews;
  final bool showStatusBadges;
  final bool showCapabilities;
  final bool showAuthor;

  const PluginDisplayConfig({
    this.filter = const PluginFilter(),
    this.sortConfig = const PluginSortConfig(
      option: PluginSortOption.name,
      order: SortOrder.ascending,
    ),
    this.searchConfig = const PluginSearchConfig(),
    this.itemsPerPage = 20,
    this.showPreviews = true,
    this.showStatusBadges = true,
    this.showCapabilities = true,
    this.showAuthor = true,
  });

  PluginDisplayConfig copyWith({
    PluginFilter? filter,
    PluginSortConfig? sortConfig,
    PluginSearchConfig? searchConfig,
    int? itemsPerPage,
    bool? showPreviews,
    bool? showStatusBadges,
    bool? showCapabilities,
    bool? showAuthor,
  }) {
    return PluginDisplayConfig(
      filter: filter ?? this.filter,
      sortConfig: sortConfig ?? this.sortConfig,
      searchConfig: searchConfig ?? this.searchConfig,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      showPreviews: showPreviews ?? this.showPreviews,
      showStatusBadges: showStatusBadges ?? this.showStatusBadges,
      showCapabilities: showCapabilities ?? this.showCapabilities,
      showAuthor: showAuthor ?? this.showAuthor,
    );
  }
}