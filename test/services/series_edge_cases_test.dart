import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/series_service.dart';

void main() {
  group('Series Name Cleaning Edge Cases', () {
    // 盗墓笔记系列 - 截图中的高亮案例
    test('Cleans Dao Mu Bi Ji variations', () {
      const name1 = '盗墓笔记.重启之极海听雷.S01';
      const name2 = '盗墓笔记.重启之极海听雷.S02';
      const name3 = '盗墓笔记.重启之极海听雷.第二季';
      
      expect(SeriesService.cleanSeriesName(name1), '盗墓笔记重启之极海听雷');
      expect(SeriesService.cleanSeriesName(name2), '盗墓笔记重启之极海听雷');
      expect(SeriesService.cleanSeriesName(name3), '盗墓笔记重启之极海听雷');
    });

    // 中文无空格 vs 有空格/点分隔
    test('Normalizes Chinese series names with/without separators', () {
      const nameWithDots = '盗墓笔记.重启之极海听雷';
      const nameNoSep = '盗墓笔记重启之极海听雷';
      const nameWithSpaces = '盗墓笔记 重启之极海听雷';
      
      final cleanedDots = SeriesService.cleanSeriesName(nameWithDots);
      final cleanedNoSep = SeriesService.cleanSeriesName(nameNoSep);
      final cleanedSpaces = SeriesService.cleanSeriesName(nameWithSpaces);
      
      // 我们希望它们能匹配
      expect(cleanedDots, cleanedNoSep, reason: 'Dots vs No Separator: "$cleanedDots" vs "$cleanedNoSep"');
      expect(cleanedSpaces, cleanedNoSep, reason: 'Spaces vs No Separator: "$cleanedSpaces" vs "$cleanedNoSep"');
    });
  });
}

