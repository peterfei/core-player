import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/core/scraping/name_parser.dart';

void main() {
  group('Harry Potter Parsing', () {
    final inputs = [
      '哈利波特1：魔法石.mp4',
      '哈利波特2：密室.mp4',
      '哈利波特3：阿兹卡班的囚徒.mp4',
      'Harry Potter and the Sorcerer\'s Stone.mp4',
      'Harry.Potter.and.the.Chamber.of.Secrets.2002.1080p.BluRay.x264.mp4',
      'Harry Potter 1.mp4',
      'Harry Potter 7 Part 1.mp4',
      'Harry Potter 7 Part 2.mp4',
    ];

    test('Should parse Harry Potter filenames correctly', () {
      for (final input in inputs) {
        final result = NameParser.parse(input);
        print('Input: "$input"');
        print('  Query: "${result.query}"');
        print('  Season: ${result.season}');
        print('  Episode: ${result.episode}');
        print('  Year: ${result.year}');
      }
    });
  });
}
