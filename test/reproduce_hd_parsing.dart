import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/core/scraping/name_parser.dart';

void main() {
  group('HD Parsing Reproduction', () {
    test('Should parse obfuscated titles with HD suffix', () {
      final inputs = [
        'p兹b医h前x HD1080p',
        't朝g事l之x行 HD1080p',
        'p兹b医h前x HD',
        't朝g事l之x行 HD',
      ];

      for (final input in inputs) {
        final result = NameParser.parse(input);
        print('Input: "$input" -> Query: "${result.query}"');
      }
    });
  });
}
