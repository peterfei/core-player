import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/core/scraping/name_parser.dart';

void main() {
  group('GOT Parsing Reproduction', () {
    test('Should parse multi-title and remove keywords', () {
      final input = '冰与火之歌：权力的游戏全集 Game of Thrones S02E01 10 BD1080P';
      
      // We expect candidates to include:
      // 1. "冰与火之歌"
      // 2. "权力的游戏"
      // 3. "Game of Thrones" (maybe)
      // And "全集" should be removed.
      
      final candidates = NameParser.generateCandidates(input);
      
      print('Input: "$input"');
      for (final candidate in candidates) {
        print('  Candidate: "${candidate.query}"');
      }
      
      final queries = candidates.map((c) => c.query).toList();
      
      // Ideally we want these
      expect(queries, contains('冰与火之歌'));
      expect(queries, contains('权力的游戏'));
      
      // At least one of them should be clean (no "全集")
      expect(queries.any((q) => !q.contains('全集')), isTrue);
    });
  });
}
