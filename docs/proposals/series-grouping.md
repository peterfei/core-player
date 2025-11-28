# 剧集分组功能提案

## 背景

当前系统将每个文件夹都视为独立的剧集（Series），导致同一部剧的不同集数文件夹（如"刑侦12 第01-04集"、"刑侦12 第05-06集"）被分别显示。用户希望这些文件夹能够自动合并为一个剧集"刑侦12"，并显示总集数。

## 目标

实现智能剧集分组功能，自动识别并合并属于同一剧集的多个文件夹，提升用户体验。

## 核心功能

### 1. 剧集名称提取算法

从文件夹名称中提取剧集主标题，去除集数、季数等附加信息。

**示例：**
- `刑侦12 第01-04集` → `刑侦12`
- `刑侦12 第05-06集` → `刑侦12`
- `权力的游戏 第一季` → `权力的游戏`
- `Breaking.Bad.S01` → `Breaking Bad`

**提取规则：**
1. 移除集数标识：`第X-Y集`、`第X集`、`EP01-04`、`E01-E04`
2. 移除季数标识：`第X季`、`Season X`、`S01`
3. 移除技术参数：`1080p`、`4K`、`WEB-DL` 等
4. 移除网站标识和方括号内容
5. 标准化空格和标点符号

### 2. 数据模型调整

#### 新增 `SeriesGroup` 模型

```dart
class SeriesGroup {
  final String id;              // 分组ID（基于主标题哈希）
  final String title;           // 剧集主标题
  final List<Series> folders;   // 包含的文件夹列表
  final int totalEpisodes;      // 总集数
  final DateTime addedAt;       // 最早添加时间
  final String? coverPath;      // 封面路径（优先使用）
}
```

#### 修改现有 `Series` 模型

添加可选字段：
- `groupId`: 所属分组ID
- `episodeRange`: 集数范围（如 "01-04"）

### 3. 分组服务

创建 `SeriesGroupingService` 负责：
- 剧集名称提取和标准化
- 相似度匹配（处理轻微差异）
- 分组管理和缓存

### 4. UI 更新

#### 剧集列表视图
- 默认显示分组后的剧集
- 显示总集数（如 "25 集"）
- 点击展开可查看包含的文件夹

#### 剧集详情页
- 显示所有子文件夹
- 按集数范围排序
- 支持快速跳转到特定集数

## 实施计划

### 阶段 1: 名称提取算法
- [ ] 1.1 创建 `SeriesTitleExtractor` 工具类
- [ ] 1.2 实现正则表达式规则
- [ ] 1.3 编写单元测试（覆盖各种命名格式）

### 阶段 2: 数据模型
- [ ] 2.1 创建 `SeriesGroup` 模型
- [ ] 2.2 更新 `Series` 模型
- [ ] 2.3 创建 Hive 适配器

### 阶段 3: 分组服务
- [ ] 3.1 创建 `SeriesGroupingService`
- [ ] 3.2 实现分组逻辑
- [ ] 3.3 实现相似度匹配（可选，处理拼写差异）
- [ ] 3.4 添加缓存机制

### 阶段 4: 集成到媒体库
- [ ] 4.1 修改 `MediaLibraryService` 扫描逻辑
- [ ] 4.2 在扫描后自动执行分组
- [ ] 4.3 提供手动重新分组接口

### 阶段 5: UI 更新
- [ ] 5.1 更新剧集列表页面
- [ ] 5.2 添加展开/折叠功能
- [ ] 5.3 更新剧集详情页
- [ ] 5.4 添加分组设置选项

### 阶段 6: 设置和配置
- [ ] 6.1 添加"启用剧集分组"开关
- [ ] 6.2 添加"分组敏感度"配置
- [ ] 6.3 添加"手动调整分组"功能

### 阶段 7: 测试
- [ ] 7.1 单元测试（名称提取）
- [ ] 7.2 集成测试（分组逻辑）
- [ ] 7.3 UI 测试
- [ ] 7.4 性能测试（大量剧集）

### 阶段 8: 文档和优化
- [ ] 8.1 编写用户文档
- [ ] 8.2 性能优化
- [ ] 8.3 边缘情况处理

## 技术细节

### 名称提取正则表达式

```dart
class SeriesTitleExtractor {
  static String extract(String folderName) {
    var title = folderName;
    
    // 1. 移除方括号内容
    title = title.replaceAll(RegExp(r'[\[【].*?[\]】]'), '');
    
    // 2. 移除集数标识
    title = title.replaceAll(RegExp(r'第?\s*\d+\s*-?\s*\d*\s*集'), '');
    title = title.replaceAll(RegExp(r'EP?\d+(-\d+)?', caseSensitive: false), '');
    
    // 3. 移除季数标识
    title = title.replaceAll(RegExp(r'第?\s*[一二三四五]\s*季'), '');
    title = title.replaceAll(RegExp(r'Season\s*\d+', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'S\d+', caseSensitive: false), '');
    
    // 4. 移除技术参数
    title = title.replaceAll(RegExp(r'(1080p|2160p|4K|WEB-DL|BluRay).*', caseSensitive: false), '');
    
    // 5. 标准化
    title = title.replaceAll(RegExp(r'[._]'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ');
    
    return title.trim();
  }
}
```

### 分组算法

```dart
class SeriesGroupingService {
  static Map<String, SeriesGroup> groupSeries(List<Series> seriesList) {
    final groups = <String, List<Series>>{};
    
    for (final series in seriesList) {
      final title = SeriesTitleExtractor.extract(series.name);
      final groupId = _generateGroupId(title);
      
      if (!groups.containsKey(groupId)) {
        groups[groupId] = [];
      }
      groups[groupId]!.add(series);
    }
    
    return groups.map((id, folders) => MapEntry(
      id,
      SeriesGroup(
        id: id,
        title: SeriesTitleExtractor.extract(folders.first.name),
        folders: folders,
        totalEpisodes: folders.fold(0, (sum, s) => sum + s.episodeCount),
        addedAt: folders.map((s) => s.addedAt).reduce((a, b) => a.isBefore(b) ? a : b),
      ),
    ));
  }
}
```

## 用户体验改进

### 设置界面

在"媒体库设置"中添加：
- **启用剧集分组**: 开关（默认开启）
- **分组模式**: 
  - 严格模式：只合并完全匹配的剧集
  - 智能模式：使用相似度匹配（推荐）
  - 手动模式：用户手动调整分组

### 剧集卡片显示

分组后的剧集卡片显示：
- 主标题（如"刑侦12"）
- 总集数（如"25 集"）
- 包含的文件夹数量（小字，如"5 个文件夹"）

点击卡片进入详情页，显示：
- 所有子文件夹列表
- 按集数范围排序
- 每个文件夹的集数和路径

## 兼容性考虑

- **向后兼容**: 未启用分组时，保持原有显示方式
- **数据迁移**: 自动检测并分组现有剧集
- **性能**: 分组结果缓存，避免重复计算

## 验证计划

### 单元测试
```bash
flutter test test/services/series_title_extractor_test.dart
flutter test test/services/series_grouping_service_test.dart
```

测试用例应覆盖：
- 各种命名格式的标题提取
- 分组逻辑正确性
- 边缘情况（空标题、特殊字符等）

### 手动测试
1. 准备测试数据：创建多个"刑侦12"文件夹（第01-04集、第05-06集等）
2. 扫描媒体库
3. 验证剧集列表只显示一个"刑侦12"条目
4. 验证总集数正确
5. 点击展开，验证所有子文件夹都显示
6. 测试关闭分组功能，验证恢复原有显示

## 风险和挑战

1. **命名多样性**: 不同来源的剧集命名格式差异大，需要持续优化正则表达式
2. **误分组**: 可能将不同剧集错误合并（如"刑侦12"和"刑侦13"）
3. **性能**: 大量剧集时分组计算可能耗时
4. **用户习惯**: 部分用户可能更喜欢原有的文件夹视图

## 后续优化方向

- 支持用户手动调整分组
- 机器学习优化标题提取
- 支持多语言剧集名称
- 与 TMDB 元数据结合，提高准确性
