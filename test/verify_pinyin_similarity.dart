import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/core/scraping/name_parser.dart';
import 'package:yinghe_player/core/scraping/similarity_calculator.dart';

void main() {
  group('Pinyin Similarity Verification', () {
    test('Should match obfuscated titles with Pinyin', () {
      final cases = [
        // Query (obfuscated), Target (correct)
        ('p兹b医h前x', '匹兹堡医护前线'),
        ('t朝g事l之x行', '唐朝诡事录之西行'),
        ('wsxj', '我是刑警'), // Full pinyin initials
        ('z法z们', '执法者们'),
        ('d球m动d3j', '地球脉动3'), // Mixed
      ];

      for (final (query, target) in cases) {
        final score = SimilarityCalculator.calculate(query, target);
        print('Query: "$query" vs Target: "$target" -> Score: $score');
        
        // For mixed cases like "d球m动d3j" (7 chars) vs "地球脉动3" (5 chars), score is 5/7 = 0.71
        // For perfect matches like "wsxj" (4) vs "我是刑警" (4), score is 1.0
        if (query == 'd球m动d3j') {
          expect(score, greaterThanOrEqualTo(0.7), reason: 'Failed for $query vs $target');
        } else {
          expect(score, greaterThanOrEqualTo(0.9), reason: 'Failed for $query vs $target');
        }
      }
    });

    test('NameParser should preserve rawQuery', () {
      final inputs = [
        'p兹b医h前x HD1080p',
        't朝g事l之x行.HD1080p',
      ];

      for (final input in inputs) {
        final result = NameParser.parse(input);
        print('Input: "$input"');
        print('  Query: "${result.query}"');
        print('  RawQuery: "${result.rawQuery}"');
        
        expect(result.rawQuery, isNotNull);
        expect(result.rawQuery, contains(RegExp(r'[a-z]'))); // Should contain letters
        expect(result.rawQuery, isNot(contains('HD'))); // Should NOT contain HD
      }
    });
  });
}
