import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/models/cover_gradient.dart';

void main() {
  test('CoverGradient presets should not be empty', () {
    expect(CoverGradient.presets, isNotEmpty);
  });
}
