import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/core/scraping/name_parser.dart';

void main() {
  test('Parse 哈利波特全集', () {
    final input = '哈利波特全集';
    final result = NameParser.parse(input);
    print('Input: $input');
    print('Query: ${result.query}');
    print('RawQuery: ${result.rawQuery}');
  });
}
