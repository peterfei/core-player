import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Robust Fix: Require "季" for Chinese season parsing', () {
    // New strategy: 
    // 1. Match "Season X" or "S X" (suffix optional)
    // 2. Match "第 X 季" (suffix REQUIRED)
    final seasonPattern = RegExp(r'(?:Season|S)\s*(\d+)|第\s*(\d+)\s*季', caseSensitive: false);
    
    // Case 1: "大考 第10集" -> Should NOT match
    var match = seasonPattern.firstMatch('大考 第10集');
    expect(match, null);

    // Case 2: "大考 第1季" -> Should match group 2
    match = seasonPattern.firstMatch('大考 第1季');
    expect(match, isNotNull);
    expect(match!.group(2), '1');

    // Case 3: "Season 2" -> Should match group 1
    match = seasonPattern.firstMatch('Season 2');
    expect(match, isNotNull);
    expect(match!.group(1), '2');

    // Case 4: "S03" -> Should match group 1
    match = seasonPattern.firstMatch('S03');
    expect(match, isNotNull);
    expect(match!.group(1), '03');
  });
}
