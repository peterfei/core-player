import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/series_service.dart';

void main() {
  group('SeriesService Name Extraction', () {
    test('Extracts simple names', () {
      expect(SeriesService.cleanSeriesName('刑侦12'), '刑侦12');
      expect(SeriesService.cleanSeriesName('权力的游戏'), '权力的游戏');
    });

    test('Removes episode ranges', () {
      expect(SeriesService.cleanSeriesName('刑侦12 第01-04集'), '刑侦12');
      expect(SeriesService.cleanSeriesName('刑侦12 第05-06集'), '刑侦12');
      expect(SeriesService.cleanSeriesName('Series Name EP01-04'), 'Series Name');
      expect(SeriesService.cleanSeriesName('Series Name E01-E04'), 'Series Name');
    });

    test('Removes season info', () {
      expect(SeriesService.cleanSeriesName('权力的游戏 第一季'), '权力的游戏');
      expect(SeriesService.cleanSeriesName('权力的游戏 S01'), '权力的游戏');
      expect(SeriesService.cleanSeriesName('Breaking.Bad.Season.1'), 'Breaking Bad');
    });

    test('Removes brackets and tech info', () {
      expect(SeriesService.cleanSeriesName('【字幕组】刑侦12[1080p]'), '刑侦12');
      expect(SeriesService.cleanSeriesName('Movie.Name.2023.WEB-DL.4K'), 'Movie Name 2023'); 
    });

    test('Normalizes separators', () {
      expect(SeriesService.cleanSeriesName('Breaking.Bad.S01'), 'Breaking Bad');
      expect(SeriesService.cleanSeriesName('My_Series_Name'), 'My Series Name');
    });
  });
}
