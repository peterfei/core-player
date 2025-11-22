import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

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
    if (!isInitialized) return [];
    
    try {
      final queryParams = _getQueryParams({
        'query': query,
        'include_adult': 'false',
      });

      final uri = Uri.parse('$_baseUrl/search/tv').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _getHeaders());
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = List<Map<String, dynamic>>.from(data['results']);
        return results;
      } else {
        debugPrint('TMDB Search Error: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('TMDB Search Exception: $e');
      return [];
    }
  }

  /// 获取剧集详情
  static Future<Map<String, dynamic>?> getTVShowDetails(int tmdbId) async {
    if (!isInitialized) return null;
    
    try {
      final queryParams = _getQueryParams({});
      final uri = Uri.parse('$_baseUrl/tv/$tmdbId').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _getHeaders());
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('TMDB Details Exception: $e');
      return null;
    }
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
