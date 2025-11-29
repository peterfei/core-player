import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/core/scraping/name_parser.dart';
import 'package:yinghe_player/core/scraping/similarity_calculator.dart';
import 'package:yinghe_player/services/settings_service.dart';

void main() {
  group('NameParser Tests', () {
    test('Should parse simple movie name', () {
      final result = NameParser.parse('Inception.2010.1080p.BluRay.x264.mp4');
      expect(result.query, 'Inception');
      expect(result.year, 2010);
    });

    test('Should parse TV show with SxxExx', () {
      final result = NameParser.parse('Breaking.Bad.S01E01.720p.HDTV.x264.mkv');
      expect(result.query, 'Breaking Bad');
      expect(result.season, 1);
      expect(result.episode, 1);
    });

    test('Should parse TV show with 1x01', () {
      final result = NameParser.parse('Friends.1x01.The.One.Where.Monica.Gets.A.Roommate.avi');
      expect(result.query, 'Friends The One Where Monica Gets A Roommate');
      expect(result.season, 1);
      expect(result.episode, 1);
    });
    
    test('Should clean junk words', () {
      final result = NameParser.parse('Avatar.2009.Extended.Collector\'s.Cut.1080p.BluRay.x264.mp4');
      expect(result.query, 'Avatar');
      expect(result.year, 2009);
    });
    
    test('Should remove advertisement info', () {
      final result = NameParser.parse('坏蛋联盟：偷偷来搞鬼 6v电影地址发布页 www 6v123 net 收藏不迷路');
      expect(result.query, '坏蛋联盟：偷偷来搞鬼');
    });
    
    test('Should remove language and subtitle info', () {
      final result = NameParser.parse('功夫 2004 BD1080p 国粤双语中字 mp4');
      expect(result.query, '功夫');
      expect(result.year, 2004);
    });
    
    test('Should handle season info in Chinese', () {
      final result = NameParser.parse('权力的游戏第3季');
      expect(result.query, '权力的游戏');
    });
    
    test('Should detect invalid folder names', () {
      final result = NameParser.parse('1080p');
      expect(result.query, '');
    });
    
    test('Should handle complex mixed naming', () {
      final result = NameParser.parse('阳光电影dygod org 封神第一部：朝歌风云 2023 HD');
      expect(result.query, '封神第一部：朝歌风云');
      expect(result.year, 2023);
    });
    
    test('Should remove trailing episode range numbers', () {
      final result = NameParser.parse('法证先锋6之幸存者的救赎01 07');
      expect(result.query, '法证先锋6之幸存者的救赎');
    });
    
    test('Should remove trailing single numbers when season/episode exists', () {
      final result = NameParser.parse('冰与火之歌：权力的游戏全集 Game of Thrones S02E01 10 BD1080P');
      expect(result.query, '冰与火之歌：权力的游戏全集 Game of Thrones');
      expect(result.season, 2);
      expect(result.episode, 1);
    });
    
    test('Should NOT remove meaningful numbers from titles', () {
      final result = NameParser.parse('刑侦12');
      expect(result.query, '刑侦12');
    });
    
    test('Should remove end suffix', () {
      final result = NameParser.parse('大考end mp4');
      expect(result.query, '大考');
    });
    
    test('Should remove version numbers', () {
      final result = NameParser.parse('t朝g事l之x行 HD1080p v2 mp4');
      expect(result.query, 't朝g事l之x行');
    });
  });

  group('SimilarityCalculator Tests', () {
    test('Should calculate exact match', () {
      expect(SimilarityCalculator.calculate('Avatar', 'Avatar'), 1.0);
    });

    test('Should calculate close match', () {
      final score = SimilarityCalculator.calculate('Avengers Infinity War', 'Avengers: Infinity War');
      expect(score, greaterThan(0.9));
    });

    test('Should calculate mismatch', () {
      final score = SimilarityCalculator.calculate('Avatar', 'Titanic');
      expect(score, lessThan(0.3));
    });
    
    test('Should be case insensitive', () {
      expect(SimilarityCalculator.calculate('avatar', 'AVATAR'), 1.0);
    });
  });

  group('SettingsService Tests', () {
    test('Should save and load scraping settings', () async {
      SharedPreferences.setMockInitialValues({});
      
      // Default values
      expect(await SettingsService.getScrapingRetryCount(), 3);
      expect(await SettingsService.getScrapingSimilarityThreshold(), 0.8);
      
      // Set values
      await SettingsService.setScrapingRetryCount(5);
      await SettingsService.setScrapingSimilarityThreshold(0.9);
      
      // Verify values
      expect(await SettingsService.getScrapingRetryCount(), 5);
      expect(await SettingsService.getScrapingSimilarityThreshold(), 0.9);
    });
  });
}
