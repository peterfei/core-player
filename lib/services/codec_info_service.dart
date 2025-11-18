import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/models/codec_info.dart';

class CodecInfoService {
  static const String _codecInfoCacheKey = 'codecInfoCache';
  List<CodecInfo> _cachedCodecInfo = [];

  CodecInfoService() {
    _init();
  }

  Future<void> _init() async {
    _cachedCodecInfo = await _loadCodecInfoFromCache();
  }

  // Public method to update the codec information cache
  Future<void> updateCodecInfoCache(List<CodecInfo> codecInfoList) async {
    await _saveCodecInfoToCache(codecInfoList);
  }

  // Implement codec capability query
  Future<bool> supportsCodec(String codecName) async {
    if (_cachedCodecInfo.isEmpty) {
      // If cache is empty, try to load from persistent storage
      _cachedCodecInfo = await _loadCodecInfoFromCache();
      if (_cachedCodecInfo.isEmpty)
        return false; // If still empty, truly unsupported
    }
    return _cachedCodecInfo.any((info) =>
        info.codec.toLowerCase() == codecName.toLowerCase() &&
        info.supportStatus == CodecSupportStatus.fullySupported);
  }

  // Implement format support query (assuming format refers to codec support for now)
  Future<bool> supportsFormat(String formatName) async {
    // This might need more sophisticated logic based on what 'format' means.
    // For now, we'll treat it similarly to codec support.
    return supportsCodec(formatName);
  }

  // Implement codec friendly name mapping
  String getFriendlyCodecName(String codecName) {
    return CodecInfo.getCodecDisplayName(codecName);
  }

  // Save codec information to cache
  Future<void> _saveCodecInfoToCache(List<CodecInfo> codecInfoList) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString =
        jsonEncode(codecInfoList.map((e) => e.toJson()).toList());
    await prefs.setString(_codecInfoCacheKey, jsonString);
    _cachedCodecInfo = codecInfoList;
  }

  // Add a method to retrieve cached codec information
  Future<List<CodecInfo>> getCachedCodecInfo() async {
    return _cachedCodecInfo;
  }

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
