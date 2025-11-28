import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/series_service.dart';
import 'package:yinghe_player/services/media_library_service.dart';

void main() {
  group('SeriesService Advanced Grouping', () {
    test('Groups multiple folders with same cleaned name', () {
      final videos = [
        ScannedVideo(path: '/media/Game of Thrones S01/S01E01.mkv', name: 'S01E01.mkv', size: 1000),
        ScannedVideo(path: '/media/Game of Thrones S02/S02E01.mkv', name: 'S02E01.mkv', size: 1000),
        ScannedVideo(path: '/media/Game.of.Thrones.S03/S03E01.mkv', name: 'S03E01.mkv', size: 1000),
      ];

      final seriesList = SeriesService.groupVideosBySeries(videos);

      expect(seriesList.length, 1);
      expect(seriesList.first.name, 'Game of Thrones');
      expect(seriesList.first.episodeCount, 3);
    });

    test('Groups folders with different naming styles', () {
      final videos = [
        ScannedVideo(path: '/media/刑侦12/第01集.mkv', name: '第01集.mkv', size: 1000),
        ScannedVideo(path: '/media/刑侦12 第01-04集/第02集.mkv', name: '第02集.mkv', size: 1000),
      ];

      final seriesList = SeriesService.groupVideosBySeries(videos);

      expect(seriesList.length, 1);
      expect(seriesList.first.name, '刑侦12');
      expect(seriesList.first.episodeCount, 2);
    });
    
    test('Does not group distinct series', () {
      final videos = [
        ScannedVideo(path: '/media/Breaking Bad/S01E01.mkv', name: 'S01E01.mkv', size: 1000),
        ScannedVideo(path: '/media/Better Call Saul/S01E01.mkv', name: 'S01E01.mkv', size: 1000),
      ];

      final seriesList = SeriesService.groupVideosBySeries(videos);

      expect(seriesList.length, 2);
    });
  });
}
