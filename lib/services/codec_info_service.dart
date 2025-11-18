import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/models/codec_info.dart';

/// Manages codec information, including querying capabilities and caching.
///
/// This service is a singleton and should be initialized once at app startup.
/// The cache is populated externally by calling [updateCodecInfoCache].
class CodecInfoService {
  static final CodecInfoService instance = CodecInfoService._internal();
  factory CodecInfoService() => instance;
  CodecInfoService._internal();

  static const String _codecInfoCacheKey = 'codecInfoCache';
  List<CodecInfo> _cachedCodecInfo = [];

  /// Initializes the service by loading codec information from the cache.
  /// This should be called once at application startup.
  Future<void> initialize() async {
    _cachedCodecInfo = await _loadCodecInfoFromCache();
  }

  /// Updates the codec information cache with the provided list of codecs.
  Future<void> updateCodecInfoCache(List<CodecInfo> codecInfoList) async {
    await _saveCodecInfoToCache(codecInfoList);
  }

  /// Checks if a given codec is supported.
  Future<bool> supportsCodec(String codecName) async {
    if (_cachedCodecInfo.isEmpty) {
      _cachedCodecInfo = await _loadCodecInfoFromCache();
      if (_cachedCodecInfo.isEmpty) {
        return false;
      }
    }
    return _cachedCodecInfo.any((info) =>
        info.codec.toLowerCase() == codecName.toLowerCase() &&
        info.supportStatus == CodecSupportStatus.fullySupported);
  }

  /// Checks if a given format is supported.
  Future<bool> supportsFormat(String formatName) async {
    return supportsCodec(formatName);
  }

  /// Returns a user-friendly name for the given codec.
  String getFriendlyCodecName(String codecName) {
    return CodecInfo.getCodecDisplayName(codecName);
  }

  /// Saves the provided list of codec information to the cache.
  Future<void> _saveCodecInfoToCache(List<CodecInfo> codecInfoList) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString =
        jsonEncode(codecInfoList.map((e) => e.toJson()).toList());
    await prefs.setString(_codecInfoCacheKey, jsonString);
    _cachedCodecInfo = codecInfoList;
  }

  /// Retrieves the cached codec information.
  List<CodecInfo> getCachedCodecInfo() {
    return _cachedCodecInfo;
  }

  /// Loads codec information from the cache (SharedPreferences).
  Future<List<CodecInfo>> _loadCodecInfoFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_codecInfoCacheKey);
    if (jsonString == null) {
      return [];
    }
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((e) => CodecInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
