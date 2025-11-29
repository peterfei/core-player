import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/scraping/retry_helper.dart';
import 'settings_service.dart';

class TMDBService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/original';
  
  // TODO: 应该从设置中获取
  // TODO: 应该从设置中获取
  static String? _apiKey;
  static String? _accessToken;
  static String _language = 'zh-CN';

  static void init(String apiKey, {String? accessToken, String language = 'zh-CN'}) {
    _apiKey = apiKey;
    _accessToken = accessToken;
    _language = language;
  }
  
  static bool get isInitialized => (_apiKey != null && _apiKey!.isNotEmpty) || (_accessToken != null && _accessToken!.isNotEmpty);

  static Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json;charset=utf-8',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  static Map<String, String> _getQueryParams(Map<String, String> params) {
    final queryParams = Map<String, String>.from(params);
    queryParams['language'] = _language;
    
    // 如果没有 Access Token，则使用 API Key
    if ((_accessToken == null || _accessToken!.isEmpty) && _apiKey != null) {
      queryParams['api_key'] = _apiKey!;
    }
    return queryParams;
  }

  /// 搜索剧集
  static Future<List<Map<String, dynamic>>> searchTVShow(String query) async {
    return _search('tv', query);
  }

  /// 搜索电影
  static Future<List<Map<String, dynamic>>> searchMovie(String query) async {
    return _search('movie', query);
  }

  static Future<List<Map<String, dynamic>>> _search(String type, String query) async {
    if (!isInitialized) return [];
    
    final retryCount = await SettingsService.getScrapingRetryCount();

    try {
      return await RetryHelper.retry(() async {
        final queryParams = _getQueryParams({
          'query': query,
          'include_adult': 'false',
        });

        final uri = Uri.parse('$_baseUrl/search/$type').replace(queryParameters: queryParams);
        
        final response = await http.get(uri, headers: _getHeaders());
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = List<Map<String, dynamic>>.from(data['results']);
          return results;
        } else {
          debugPrint('TMDB Search $type Error: ${response.statusCode} ${response.body}');
          throw Exception('TMDB API Error: ${response.statusCode}');
        }
      }, maxAttempts: retryCount);
    } catch (e) {
      debugPrint('TMDB Search $type Exception: $e');
      return [];
    }
  }

  /// 获取详情 (支持电影和剧集)
  static Future<Map<String, dynamic>?> getDetails(int tmdbId, {String type = 'tv'}) async {
    if (!isInitialized) return null;
    
    final retryCount = await SettingsService.getScrapingRetryCount();

    try {
      return await RetryHelper.retry(() async {
        final queryParams = _getQueryParams({});
        final uri = Uri.parse('$_baseUrl/$type/$tmdbId').replace(queryParameters: queryParams);
        
        final response = await http.get(uri, headers: _getHeaders());
        
        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
        return null;
      }, maxAttempts: retryCount);
    } catch (e) {
      debugPrint('TMDB Details Exception: $e');
      return null;
    }
  }

  /// 获取剧集详情 (兼容旧方法)
  static Future<Map<String, dynamic>?> getTVShowDetails(int tmdbId) async {
    return getDetails(tmdbId, type: 'tv');
  }

  /// 获取季详情（包含集数信息）
  static Future<Map<String, dynamic>?> getSeasonDetails(int tmdbId, int seasonNumber) async {
    if (!isInitialized) return null;
    
    try {
      final queryParams = _getQueryParams({});
      final uri = Uri.parse('$_baseUrl/tv/$tmdbId/season/$seasonNumber').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _getHeaders());
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('TMDB Season Exception: $e');
      return null;
    }
  }
  
  /// 获取完整的图片URL
  static String? getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$_imageBaseUrl$path';
  }
}
