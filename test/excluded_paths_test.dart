import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/services/excluded_paths_service.dart';

void main() {
  group('ExcludedPathsService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ExcludedPathsService.init();
    });

    test('Should correctly identify excluded paths', () async {
      final excludedPath = '/data/movies/excluded_folder';
      await ExcludedPathsService.addPath(excludedPath);

      // Exact match
      expect(ExcludedPathsService.isExcluded('/data/movies/excluded_folder'), isTrue);
      
      // Sub-file
      expect(ExcludedPathsService.isExcluded('/data/movies/excluded_folder/movie.mp4'), isTrue);
      
      // Sub-folder
      expect(ExcludedPathsService.isExcluded('/data/movies/excluded_folder/season1'), isTrue);
      
      // Parent folder (should NOT be excluded)
      expect(ExcludedPathsService.isExcluded('/data/movies'), isFalse);
      
      // Sibling folder (should NOT be excluded)
      expect(ExcludedPathsService.isExcluded('/data/movies/other_folder'), isFalse);
      
      // Partial match but different folder name (should NOT be excluded)
      expect(ExcludedPathsService.isExcluded('/data/movies/excluded_folder_2'), isFalse);
    });
  });
}
