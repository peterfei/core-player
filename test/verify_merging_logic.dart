import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/series_service.dart';
import 'package:yinghe_player/models/series.dart';

void main() {
  group('SeriesService Merging Logic', () {
    test('Should merge series with same TMDB ID', () {
      final s1 = Series(
        id: '1',
        name: 'Game of Thrones S1',
        folderPath: '/vol1/GoT_S1',
        episodeCount: 10,
        addedAt: DateTime.now(),
        tmdbId: 1399,
      );
      
      final s2 = Series(
        id: '2',
        name: 'Game of Thrones S2',
        folderPath: '/vol1/GoT_S2',
        episodeCount: 10,
        addedAt: DateTime.now(),
        tmdbId: 1399,
      );
      
      final s3 = Series(
        id: '3',
        name: 'Breaking Bad',
        folderPath: '/vol1/BB',
        episodeCount: 62,
        addedAt: DateTime.now(),
        tmdbId: 1396,
      );

      final merged = SeriesService.mergeSeriesList([s1, s2, s3]);

      expect(merged.length, 2);
      
      // Check merged GoT
      final got = merged.firstWhere((s) => s.tmdbId == 1399);
      expect(got.folderPaths.length, 2);
      expect(got.folderPaths, containsAll(['/vol1/GoT_S1', '/vol1/GoT_S2']));
      expect(got.episodeCount, 20);
      
      // Check BB
      final bb = merged.firstWhere((s) => s.tmdbId == 1396);
      expect(bb.folderPaths.length, 1);
      expect(bb.episodeCount, 62);
    });

    test('Should not merge series with null or 0 TMDB ID', () {
      final s1 = Series(
        id: '1',
        name: 'Unknown Show 1',
        folderPath: '/vol1/Unknown1',
        episodeCount: 5,
        addedAt: DateTime.now(),
        tmdbId: null,
      );
      
      final s2 = Series(
        id: '2',
        name: 'Unknown Show 2',
        folderPath: '/vol1/Unknown2',
        episodeCount: 5,
        addedAt: DateTime.now(),
        tmdbId: 0,
      );

      final merged = SeriesService.mergeSeriesList([s1, s2]);

      expect(merged.length, 2);
    });
  });

  group('SeriesService Parsing Logic', () {
    test('Should parse S01E01 format', () {
      final result = SeriesService.parseSeasonAndEpisode('Game.of.Thrones.S01E01.mkv');
      expect(result.season, 1);
      expect(result.episode, 1);
    });

    test('Should parse Chinese format', () {
      final result = SeriesService.parseSeasonAndEpisode('权力的游戏 第1季 第01集.mp4');
      expect(result.season, 1);
      expect(result.episode, 1);
    });
    
    test('Should parse Chinese format with spaces', () {
      final result = SeriesService.parseSeasonAndEpisode('第 2 季 第 5 集');
      expect(result.season, 2);
      expect(result.episode, 5);
    });

    test('Should parse episode only', () {
      final result = SeriesService.parseSeasonAndEpisode('E05.mkv');
      expect(result.season, null);
      expect(result.episode, 5);
    });
    
    test('Should parse simple number', () {
      final result = SeriesService.parseSeasonAndEpisode('05.mp4');
      expect(result.season, null);
      expect(result.episode, 5);
    });
  });
}
