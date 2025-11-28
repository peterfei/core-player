import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/series_service.dart';
import 'package:yinghe_player/services/media_library_service.dart';

void main() {
  group('SeriesService', () {
    test('groupVideosBySeries groups videos by folder', () {
      final videos = [
        ScannedVideo(path: '/media/Series1/S01E01.mkv', name: 'S01E01.mkv', size: 1000),
        ScannedVideo(path: '/media/Series1/S01E02.mkv', name: 'S01E02.mkv', size: 1000),
        ScannedVideo(path: '/media/Movies/Movie1.mkv', name: 'Movie1.mkv', size: 2000),
      ];

      final seriesList = SeriesService.groupVideosBySeries(videos);

      expect(seriesList.length, 2);
      
      final series1 = seriesList.firstWhere((s) => s.name == 'Series1');
      expect(series1.episodeCount, 2);

      final movies = seriesList.firstWhere((s) => s.name == 'Movies');
      expect(movies.episodeCount, 1);
    });

    test('parseEpisodeNumber parses common formats', () {
      expect(SeriesService.parseEpisodeNumber('Series Name S01E05.mkv'), 5);
      expect(SeriesService.parseEpisodeNumber('Series.Name.E05.mkv'), 5);
      expect(SeriesService.parseEpisodeNumber('第05集.mp4'), 5);
      expect(SeriesService.parseEpisodeNumber('05.mp4'), 5);
    });
  });
}
