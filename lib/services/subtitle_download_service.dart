import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// 字幕下载服务
/// 提供从在线源搜索和下载字幕的功能
class SubtitleDownloadService {
  static final SubtitleDownloadService instance =
      SubtitleDownloadService._internal();

  factory SubtitleDownloadService() => instance;
  SubtitleDownloadService._internal();

  // SubHD 配置
  static const String _subhdBaseUrl = 'https://subhd.tv';
  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // OpenSubtitles API 配置（备用）
  static const String _openSubtitlesBaseUrl =
      'https://api.opensubtitles.com/api/v1';
  static const String _openSubtitlesApiKey = 'EUdOSyWZsFnUGEdCqFgh8XQbE509poUT';

  /// 搜索字幕
  Future<List<SubtitleSearchResult>> searchSubtitles({
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      debugPrint('Searching subtitles for: $query');

      // 使用多个源搜索字幕
      final results = <SubtitleSearchResult>[];

      // 源1: SubHD（中文字幕网站，优先）
      final subhdResults = await _searchSubHD(query);
      results.addAll(subhdResults);

      // 源2: OpenSubtitles REST API（备用）
      if (results.isEmpty) {
        debugPrint('No results from SubHD, trying OpenSubtitles');
        final openSubtitlesResults =
            await _searchOpenSubtitles(query, language, page: page);
        results.addAll(openSubtitlesResults);
      }

      // 如果都没有结果，添加模拟结果作为备用（仅调试模式）
      if (results.isEmpty && kDebugMode) {
        debugPrint('No results from any source, adding mock results');
        results.addAll(_getMockResults(query));
      }

      // 去重并排序
      final uniqueResults = _deduplicateResults(results);

      debugPrint('Found ${uniqueResults.length} subtitle results');
      return uniqueResults.take(limit).toList();
    } catch (e) {
      debugPrint('Error searching subtitles: $e');
      // 发生错误时返回模拟结果（仅调试模式）
      if (kDebugMode) {
        return _getMockResults(query);
      }
      return [];
    }
  }

  /// 从 SubHD 搜索字幕
  Future<List<SubtitleSearchResult>> _searchSubHD(String query) async {
    try {
      debugPrint('Searching SubHD for: $query');

      // 方法1：使用精确搜索 API（返回 JSON）
      final encodedQuery = Uri.encodeComponent(query);
      final searchDUrl = '$_subhdBaseUrl/searchD/$encodedQuery';

      debugPrint('SubHD searchD API URL: $searchDUrl');

      final searchDResponse = await http.get(
        Uri.parse(searchDUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      debugPrint(
          'SubHD searchD response status: ${searchDResponse.statusCode}');

      if (searchDResponse.statusCode == 200) {
        try {
          final jsonData = json.decode(searchDResponse.body);
          if (jsonData['success'] == true && jsonData['text'] != null) {
            final htmlText = jsonData['text'].toString();
            final movieResults = _parseSubHDSearchDResults(htmlText);

            if (movieResults.isNotEmpty) {
              // 获取每部电影的字幕列表
              final allSubtitles = <SubtitleSearchResult>[];
              for (final movieResult in movieResults.take(3)) {
                // 限制只查询前3部电影
                final subtitles = await _getSubHDMovieSubtitles(movieResult);
                allSubtitles.addAll(subtitles);
              }
              if (allSubtitles.isNotEmpty) {
                return allSubtitles;
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing SubHD searchD response: $e');
        }
      }

      // 方法2：降级到搜索结果页面解析
      debugPrint('Falling back to SubHD search page');
      final searchUrl = '$_subhdBaseUrl/search/$encodedQuery';

      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      );

      debugPrint('SubHD search page response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final html = response.body;
        return _parseSubHDSearchResults(html);
      } else {
        debugPrint('SubHD search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error searching SubHD: $e');
      return [];
    }
  }

  /// 解析 SubHD searchD API 返回的电影列表
  List<Map<String, String>> _parseSubHDSearchDResults(String htmlText) {
    final results = <Map<String, String>>[];

    try {
      // 解析格式: <a class="dropdown-item px-3" href="/d/[ID]">[标题]</a>
      final linkPattern = RegExp(
        r'<a[^>]*href="/d/(\d+)"[^>]*>([^<]+)</a>',
        dotAll: true,
      );

      final matches = linkPattern.allMatches(htmlText);

      for (final match in matches) {
        final id = match.group(1) ?? '';
        final title = match.group(2)?.trim() ?? '';

        if (id.isNotEmpty && title.isNotEmpty) {
          results.add({
            'id': id,
            'title': title,
          });
          debugPrint('Found movie: $title (ID: $id)');
        }
      }

      debugPrint('Parsed ${results.length} movies from SubHD searchD');
    } catch (e) {
      debugPrint('Error parsing SubHD searchD results: $e');
    }

    return results;
  }

  /// 获取 SubHD 电影的字幕列表
  Future<List<SubtitleSearchResult>> _getSubHDMovieSubtitles(
      Map<String, String> movie) async {
    final results = <SubtitleSearchResult>[];

    try {
      final movieId = movie['id'] ?? '';
      final movieTitle = movie['title'] ?? '';

      if (movieId.isEmpty) return results;

      final detailUrl = '$_subhdBaseUrl/d/$movieId';
      debugPrint('Fetching subtitles for movie: $movieTitle ($detailUrl)');

      final response = await http.get(
        Uri.parse(detailUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to fetch movie detail: ${response.statusCode}');
        return results;
      }

      final html = response.body;

      // 解析字幕文件链接: /a/[code]
      final subtitlePattern = RegExp(
        r'<a[^>]*href="/a/([^"]+)"[^>]*>([^<]+)</a>',
        dotAll: true,
      );

      // 查找下载次数
      final downloadPattern = RegExp(r'(\d{2,})\s*(?:次)?(?:</|$)');

      // 查找语言标签
      final langPattern = RegExp(r'(简体|繁体|英语|双语|中英|中文)');

      // 查找格式标签
      final formatPattern =
          RegExp(r'\b(SRT|ASS|SSA|SUP|SUB|VTT)\b', caseSensitive: false);

      final matches = subtitlePattern.allMatches(html);
      int count = 0;

      for (final match in matches) {
        if (count >= 10) break; // 每部电影最多10个字幕

        final code = match.group(1) ?? '';
        final rawTitle = match.group(2) ?? '';

        // 清理标题
        final title = rawTitle.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (code.isEmpty || title.isEmpty) continue;
        if (title.length < 3) continue; // 跳过过短的标题

        // 获取该字幕条目附近的上下文
        final matchIndex = html.indexOf('/a/$code');
        final contextStart = (matchIndex - 200).clamp(0, html.length);
        final contextEnd = (matchIndex + 500).clamp(0, html.length);
        final context = html.substring(contextStart, contextEnd);

        // 提取下载次数
        int downloads = 0;
        final dlMatch = downloadPattern.firstMatch(context);
        if (dlMatch != null) {
          downloads = int.tryParse(dlMatch.group(1) ?? '0') ?? 0;
        }

        // 检测语言
        String language = 'zh';
        String languageName = '简体中文';
        final langMatch = langPattern.firstMatch(context);
        if (langMatch != null) {
          final langText = langMatch.group(1) ?? '';
          if (langText.contains('繁')) {
            language = 'zh-tw';
            languageName = '繁体中文';
          } else if (langText == '英语') {
            language = 'en';
            languageName = 'English';
          } else if (langText.contains('双') || langText.contains('中英')) {
            language = 'zh';
            languageName = '中英双语';
          }
        }

        // 检测格式
        String format = 'srt';
        final formatMatch = formatPattern.firstMatch(title + context);
        if (formatMatch != null) {
          format = formatMatch.group(1)?.toLowerCase() ?? 'srt';
        }

        results.add(SubtitleSearchResult(
          id: 'subhd_$code',
          title: '[$movieTitle] $title',
          language: language,
          languageName: languageName,
          format: format,
          rating: 4.5,
          downloads: downloads,
          uploadDate: DateTime.now(),
          downloadUrl: 'subhd://$code', // 使用字幕文件代码
          source: 'SubHD',
        ));

        count++;
      }

      debugPrint('Found ${results.length} subtitles for movie $movieTitle');
    } catch (e) {
      debugPrint('Error getting SubHD movie subtitles: $e');
    }

    return results;
  }

  /// 解析 SubHD 搜索结果页面
  List<SubtitleSearchResult> _parseSubHDSearchResults(String html) {
    final results = <SubtitleSearchResult>[];

    try {
      // 使用正则表达式匹配搜索结果
      // SubHD 的搜索结果格式: <a href="/d/xxx">标题</a>
      final linkPattern = RegExp(
        r'<a[^>]*href="(/d/\d+)"[^>]*>(.*?)</a>',
        dotAll: true,
      );

      // 匹配下载次数
      final downloadPattern = RegExp(r'(\d+)\s*次下载');

      // 匹配语言标签
      final langPattern =
          RegExp(r'class="[^"]*lang[^"]*"[^>]*>(简体|繁体|英文|双语|中英)</');

      final matches = linkPattern.allMatches(html);
      int count = 0;

      for (final match in matches) {
        if (count >= 20) break; // 限制结果数量

        final detailPath = match.group(1) ?? '';
        final rawTitle = match.group(2) ?? '';

        // 清理标题中的 HTML 标签
        final title = rawTitle
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (title.isEmpty || detailPath.isEmpty) continue;
        if (!detailPath.startsWith('/d/')) continue;

        // 提取 ID
        final idMatch = RegExp(r'/d/(\d+)').firstMatch(detailPath);
        if (idMatch == null) continue;
        final id = idMatch.group(1) ?? '';

        // 查找该条目附近的下载次数
        final contextStart = html.indexOf(detailPath);
        final contextEnd = (contextStart + 500).clamp(0, html.length);
        final context = html.substring(contextStart, contextEnd);

        int downloads = 0;
        final dlMatch = downloadPattern.firstMatch(context);
        if (dlMatch != null) {
          downloads = int.tryParse(dlMatch.group(1) ?? '0') ?? 0;
        }

        // 检测语言
        String language = 'zh';
        String languageName = '简体中文';
        final langMatch = langPattern.firstMatch(context);
        if (langMatch != null) {
          final langText = langMatch.group(1) ?? '';
          if (langText.contains('繁')) {
            language = 'zh-tw';
            languageName = '繁体中文';
          } else if (langText.contains('英')) {
            language = 'en';
            languageName = 'English';
          } else if (langText.contains('双') || langText.contains('中英')) {
            language = 'zh';
            languageName = '中英双语';
          }
        }

        results.add(SubtitleSearchResult(
          id: 'subhd_$id',
          title: title,
          language: language,
          languageName: languageName,
          format: 'srt', // 默认格式
          rating: 4.5, // SubHD 没有评分，使用默认值
          downloads: downloads,
          uploadDate: DateTime.now(), // SubHD 搜索结果中没有日期
          downloadUrl: 'subhd://$id', // 使用特殊协议
          source: 'SubHD',
        ));

        count++;
      }

      debugPrint('Parsed ${results.length} results from SubHD');
      return results;
    } catch (e) {
      debugPrint('Error parsing SubHD results: $e');
      return [];
    }
  }

  /// 下载字幕
  Future<String?> downloadSubtitle(
      SubtitleSearchResult result, String targetPath) async {
    try {
      debugPrint('Downloading subtitle: ${result.title}');

      // 根据下载URL的字幕来源执行相应的下载逻辑
      if (result.downloadUrl.startsWith('subhd://')) {
        // SubHD 下载
        final subhdResult = await _downloadFromSubHD(result, targetPath);
        if (subhdResult != null) {
          return subhdResult;
        }

        // SubHD 下载失败，尝试从 OpenSubtitles 搜索并下载同名字幕
        debugPrint('SubHD download failed, trying OpenSubtitles fallback...');
        final fallbackResult =
            await _fallbackToOpenSubtitles(result, targetPath);
        if (fallbackResult != null) {
          return fallbackResult;
        }

        debugPrint('All download methods failed for SubHD subtitle');
        return null;
      } else if (result.downloadUrl.startsWith('opensubtitles://')) {
        // OpenSubtitles REST API 下载
        return await _downloadFromOpenSubtitles(result, targetPath);
      } else if (result.downloadUrl.startsWith('mock://')) {
        // 模拟下载（调试模式）
        return await _downloadMockSubtitle(result, targetPath);
      } else {
        // 直接 URL 下载
        return await _downloadRealSubtitle(result, targetPath);
      }
    } catch (e) {
      debugPrint('Error downloading subtitle: $e');
      return null;
    }
  }

  /// 从 OpenSubtitles 回退下载
  Future<String?> _fallbackToOpenSubtitles(
      SubtitleSearchResult subhdResult, String targetPath) async {
    try {
      // 提取电影名称（去掉方括号中的内容）
      String searchQuery = subhdResult.title;
      final bracketMatch = RegExp(r'\[([^\]]+)\]').firstMatch(searchQuery);
      if (bracketMatch != null) {
        searchQuery = bracketMatch.group(1) ?? searchQuery;
      }

      // 清理搜索词（只保留英文名称部分）
      final englishMatch = RegExp(r'([A-Za-z\s]+)').firstMatch(searchQuery);
      if (englishMatch != null) {
        final englishName = englishMatch.group(1)?.trim() ?? '';
        if (englishName.length > 3) {
          searchQuery = englishName;
        }
      }

      debugPrint('OpenSubtitles fallback search: $searchQuery');

      // 搜索 OpenSubtitles
      final openSubResults =
          await _searchOpenSubtitles(searchQuery, subhdResult.language);

      if (openSubResults.isEmpty) {
        debugPrint('No results from OpenSubtitles fallback');
        return null;
      }

      // 下载第一个结果
      final firstResult = openSubResults.first;
      debugPrint('Found OpenSubtitles fallback: ${firstResult.title}');

      return await _downloadFromOpenSubtitles(firstResult, targetPath);
    } catch (e) {
      debugPrint('Error in OpenSubtitles fallback: $e');
      return null;
    }
  }

  /// 从 SubHD 下载字幕
  Future<String?> _downloadFromSubHD(
      SubtitleSearchResult result, String targetPath) async {
    try {
      // 从 URL 中提取字幕代码（如 QRM8SA）
      final code = result.downloadUrl.replaceFirst('subhd://', '');
      debugPrint('Downloading from SubHD, code: $code');

      // 访问字幕文件详情页
      final detailUrl = '$_subhdBaseUrl/a/$code';
      final detailResponse = await http.get(
        Uri.parse(detailUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': _subhdBaseUrl,
        },
      );

      if (detailResponse.statusCode != 200) {
        debugPrint(
            'Failed to load SubHD subtitle page: ${detailResponse.statusCode}');
        return null;
      }

      final html = detailResponse.body;

      // 检查是否被 Cloudflare 阻止
      if (html.contains('cf-browser-verification') ||
          html.contains('challenge-platform')) {
        debugPrint('SubHD is protected by Cloudflare challenge');
        // 尝试使用代码作为 SID 直接调用预览 API
        final directPreview = await _tryDirectPreviewAPI(code);
        if (directPreview != null) {
          final fileName =
              '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
          final filePath = path.join(path.dirname(targetPath), fileName);
          await File(filePath).writeAsString(directPreview);
          debugPrint('Downloaded via direct preview API to: $filePath');
          return filePath;
        }
      }

      // 方法1：尝试通过预览 API 获取字幕内容
      final previewContent = await _getSubHDPreview(code, html);
      if (previewContent != null && previewContent.isNotEmpty) {
        // 保存字幕文件
        final fileName =
            '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
        final filePath = path.join(path.dirname(targetPath), fileName);

        final file = File(filePath);
        await file.writeAsString(previewContent);

        debugPrint('Downloaded subtitle from SubHD preview to: $filePath');
        return filePath;
      }

      // 方法2：尝试直接下载链接 /down/[code]
      final downloadUrl = '$_subhdBaseUrl/down/$code';
      debugPrint('Trying direct download: $downloadUrl');

      final downloadResponse = await http.get(
        Uri.parse(downloadUrl),
        headers: {
          'User-Agent': _userAgent,
          'Referer': detailUrl,
          'Accept': '*/*',
        },
      );

      if (downloadResponse.statusCode == 200) {
        // 检查是否是有效的字幕内容（不是 HTML 错误页面）
        final contentType = downloadResponse.headers['content-type'] ?? '';
        final bodyStart = downloadResponse.body
            .substring(0, (100).clamp(0, downloadResponse.body.length));

        if (!contentType.contains('html') && !bodyStart.contains('<!DOCTYPE')) {
          final fileName =
              '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
          final filePath = path.join(path.dirname(targetPath), fileName);

          final file = File(filePath);
          await file.writeAsBytes(downloadResponse.bodyBytes);

          debugPrint(
              'Downloaded subtitle from SubHD direct link to: $filePath');
          return filePath;
        } else {
          debugPrint(
              'SubHD direct download returned HTML (possibly login/captcha required)');
        }
      }

      // 方法3：尝试从详情页提取其他下载链接
      final alternateLink = _extractSubHDDownloadLink(html);
      if (alternateLink != null) {
        debugPrint('Found alternate SubHD download link: $alternateLink');

        final altResponse = await http.get(
          Uri.parse(alternateLink),
          headers: {
            'User-Agent': _userAgent,
            'Referer': detailUrl,
          },
        );

        if (altResponse.statusCode == 200) {
          final fileName =
              '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
          final filePath = path.join(path.dirname(targetPath), fileName);

          final file = File(filePath);
          await file.writeAsBytes(altResponse.bodyBytes);

          debugPrint(
              'Downloaded subtitle from SubHD alternate link to: $filePath');
          return filePath;
        }
      }

      debugPrint('SubHD download failed: no valid download method available');
      debugPrint('SubHD requires login/captcha verification for downloads');
      return null;
    } catch (e) {
      debugPrint('Error downloading from SubHD: $e');
      return null;
    }
  }

  /// 尝试直接调用预览 API（绕过页面解析）
  Future<String?> _tryDirectPreviewAPI(String code) async {
    try {
      // 尝试多种可能的 API 调用方式
      final apis = [
        {'url': '$_subhdBaseUrl/ajax/file_ajax', 'body': 'sid=$code'},
        {'url': '$_subhdBaseUrl/ajax/down_ajax', 'body': 'sub_id=$code'},
        {'url': '$_subhdBaseUrl/api/sub/preview', 'body': 'id=$code'},
      ];

      for (final api in apis) {
        try {
          debugPrint('Trying direct API: ${api['url']}');
          final response = await http.post(
            Uri.parse(api['url']!),
            headers: {
              'User-Agent': _userAgent,
              'Content-Type': 'application/x-www-form-urlencoded',
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': _subhdBaseUrl,
              'Referer': '$_subhdBaseUrl/a/$code',
            },
            body: api['body'],
          );

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            // 尝试解析 JSON
            try {
              final jsonData = json.decode(response.body);
              if (jsonData['success'] == true && jsonData['content'] != null) {
                debugPrint('Direct API success: ${api['url']}');
                return jsonData['content'].toString();
              }
            } catch (e) {
              // 如果不是 JSON，检查是否是有效的字幕内容
              if (!response.body.contains('<!DOCTYPE') &&
                  !response.body.contains('<html')) {
                if (response.body.contains('-->') ||
                    response.body.contains('Dialogue:')) {
                  debugPrint('Direct API returned subtitle content');
                  return response.body;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('API ${api['url']} failed: $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error in direct preview API: $e');
      return null;
    }
  }

  /// 通过预览 API 获取 SubHD 字幕内容
  Future<String?> _getSubHDPreview(String code, String detailHtml) async {
    try {
      // 查找 SID 的多种模式
      String? sid;

      // 模式1: sid="数字"
      final sidPattern1 = RegExp(r'sid="(\d+)"');
      var match = sidPattern1.firstMatch(detailHtml);
      if (match != null) {
        sid = match.group(1);
        debugPrint('Found SID pattern 1: $sid');
      }

      // 模式2: data-sid="数字"
      if (sid == null) {
        final sidPattern2 = RegExp(r'data-sid="(\d+)"');
        match = sidPattern2.firstMatch(detailHtml);
        if (match != null) {
          sid = match.group(1);
          debugPrint('Found SID pattern 2: $sid');
        }
      }

      // 模式3: class="down" sid="数字" (在属性中)
      if (sid == null) {
        final sidPattern3 = RegExp(r'class="[^"]*down[^"]*"[^>]*sid="(\d+)"');
        match = sidPattern3.firstMatch(detailHtml);
        if (match != null) {
          sid = match.group(1);
          debugPrint('Found SID pattern 3: $sid');
        }
      }

      // 模式4: JavaScript 变量 var sid = 数字
      if (sid == null) {
        final sidPattern4 = RegExp(r'var\s+sid\s*=\s*(\d+)');
        match = sidPattern4.firstMatch(detailHtml);
        if (match != null) {
          sid = match.group(1);
          debugPrint('Found SID pattern 4: $sid');
        }
      }

      // 模式5: 从 URL 或 script 中查找数字 ID
      if (sid == null) {
        final sidPattern5 = RegExp(r'/ajax/file_ajax[^"]*sid=(\d+)');
        match = sidPattern5.firstMatch(detailHtml);
        if (match != null) {
          sid = match.group(1);
          debugPrint('Found SID pattern 5: $sid');
        }
      }

      // 模式6: 查找页面中的大数字（可能是 SID）
      if (sid == null) {
        // 在特定上下文中查找（如 down 按钮附近）
        final downButtonPattern =
            RegExp(r'class="[^"]*down[^"]*"[^>]*>.*?(\d{5,})', dotAll: true);
        match = downButtonPattern.firstMatch(detailHtml);
        if (match != null) {
          sid = match.group(1);
          debugPrint('Found SID pattern 6: $sid');
        }
      }

      if (sid == null || sid.isEmpty) {
        debugPrint('No preview SID found in SubHD subtitle page');
        debugPrint(
            'HTML sample: ${detailHtml.substring(0, (2000).clamp(0, detailHtml.length))}');
        return null;
      }

      debugPrint('Using SubHD preview SID: $sid');

      // 调用预览 API
      final previewResponse = await http.post(
        Uri.parse('$_subhdBaseUrl/ajax/file_ajax'),
        headers: {
          'User-Agent': _userAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': '$_subhdBaseUrl/a/$code',
          'Origin': _subhdBaseUrl,
        },
        body: 'sid=$sid',
      );

      debugPrint('SubHD preview API response: ${previewResponse.statusCode}');

      if (previewResponse.statusCode == 200) {
        try {
          final jsonData = json.decode(previewResponse.body);
          if (jsonData['success'] == true && jsonData['content'] != null) {
            final content = jsonData['content'].toString();
            debugPrint('Got SubHD preview content (${content.length} chars)');
            return content;
          } else {
            debugPrint('SubHD preview API returned: $jsonData');
          }
        } catch (e) {
          // 可能直接返回文本内容
          final text = previewResponse.body;
          if (text.isNotEmpty &&
              !text.startsWith('{') &&
              !text.startsWith('<')) {
            debugPrint('Got SubHD preview as plain text');
            return text;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting SubHD preview: $e');
      return null;
    }
  }

  /// 从详情页提取直接下载链接
  String? _extractSubHDDownloadLink(String html) {
    try {
      // 查找下载链接
      final downloadPattern = RegExp(r'href="([^"]*download[^"]*)"');
      final match = downloadPattern.firstMatch(html);

      if (match != null) {
        final link = match.group(1) ?? '';
        if (link.startsWith('http')) {
          return link;
        } else if (link.startsWith('/')) {
          return '$_subhdBaseUrl$link';
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting SubHD download link: $e');
      return null;
    }
  }

  /// 从 OpenSubtitles API 下载字幕
  Future<String?> _downloadFromOpenSubtitles(
      SubtitleSearchResult result, String targetPath) async {
    try {
      // 从 URL 中提取 file_id
      final fileId = result.downloadUrl.replaceFirst('opensubtitles://', '');

      debugPrint('Downloading from OpenSubtitles, file_id: $fileId');

      // 调用下载 API 获取下载链接
      final downloadResponse = await http.post(
        Uri.parse('$_openSubtitlesBaseUrl/download'),
        headers: {
          'Api-Key': _openSubtitlesApiKey,
          'User-Agent': _userAgent,
          'Content-Type': 'application/json',
        },
        body: json.encode({'file_id': int.parse(fileId)}),
      );

      debugPrint(
          'OpenSubtitles download API response: ${downloadResponse.statusCode}');

      if (downloadResponse.statusCode == 200) {
        final jsonData = json.decode(downloadResponse.body);
        final downloadLink = jsonData['link']?.toString();

        if (downloadLink == null || downloadLink.isEmpty) {
          debugPrint('No download link in response');
          return null;
        }

        debugPrint('Got download link: $downloadLink');

        // 下载实际的字幕文件
        final subtitleResponse = await http.get(Uri.parse(downloadLink));

        if (subtitleResponse.statusCode == 200) {
          // 保存字幕文件
          final fileName =
              '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
          final filePath = path.join(path.dirname(targetPath), fileName);

          final file = File(filePath);
          await file.writeAsBytes(subtitleResponse.bodyBytes);

          debugPrint('Downloaded subtitle to: $filePath');
          return filePath;
        } else {
          debugPrint(
              'Failed to download subtitle file: HTTP ${subtitleResponse.statusCode}');
          return null;
        }
      } else if (downloadResponse.statusCode == 406) {
        debugPrint('OpenSubtitles download quota exceeded');
        return null;
      } else {
        debugPrint(
            'OpenSubtitles download API error: ${downloadResponse.statusCode} - ${downloadResponse.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading from OpenSubtitles: $e');
      return null;
    }
  }

  /// 从 OpenSubtitles REST API 搜索
  Future<List<SubtitleSearchResult>> _searchOpenSubtitles(
      String query, String? language,
      {int page = 1}) async {
    try {
      debugPrint('Searching OpenSubtitles API for: $query');

      // 构建查询参数
      final queryParams = <String, String>{
        'query': query,
        'page': page.toString(),
      };

      // 添加语言过滤（使用 ISO 639-2B 代码）
      if (language != null && language.isNotEmpty) {
        // 转换常见的语言代码
        String langCode = _convertToISO6392B(language);
        queryParams['languages'] = langCode;
      } else {
        // 默认搜索中文和英文
        queryParams['languages'] = 'zh,en';
      }

      final uri = Uri.parse('$_openSubtitlesBaseUrl/subtitles')
          .replace(queryParameters: queryParams);

      debugPrint('OpenSubtitles API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Api-Key': _openSubtitlesApiKey,
          'User-Agent': _userAgent,
          'Content-Type': 'application/json',
        },
      );

      debugPrint('OpenSubtitles API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final data = jsonData['data'] as List<dynamic>? ?? [];

        debugPrint('OpenSubtitles returned ${data.length} results');

        final results = <SubtitleSearchResult>[];

        for (final item in data) {
          try {
            final attributes = item['attributes'] as Map<String, dynamic>;
            final files = attributes['files'] as List<dynamic>? ?? [];

            if (files.isEmpty) continue;

            // 获取第一个文件的 file_id
            final firstFile = files[0] as Map<String, dynamic>;
            final fileId = firstFile['file_id']?.toString() ?? '';

            if (fileId.isEmpty) continue;

            // 解析上传日期
            DateTime uploadDate = DateTime.now();
            if (attributes['upload_date'] != null) {
              try {
                uploadDate =
                    DateTime.parse(attributes['upload_date'].toString());
              } catch (e) {
                // 使用默认日期
              }
            }

            // 获取语言名称
            final langCode = attributes['language']?.toString() ?? 'unknown';
            final langName = _getLanguageNameFromCode(langCode);

            // 获取特性详情（电影/剧集名称）
            final featureDetails =
                attributes['feature_details'] as Map<String, dynamic>? ?? {};
            final featureTitle = featureDetails['title']?.toString() ?? query;
            final releaseTitle =
                attributes['release']?.toString() ?? featureTitle;

            results.add(SubtitleSearchResult(
              id: fileId,
              title: releaseTitle,
              language: langCode,
              languageName: langName,
              format:
                  firstFile['file_name']?.toString().split('.').last ?? 'srt',
              rating: (attributes['ratings']?.toDouble() ?? 0.0),
              downloads: attributes['download_count']?.toInt() ?? 0,
              uploadDate: uploadDate,
              downloadUrl: 'opensubtitles://$fileId', // 使用特殊协议标识
              source: 'OpenSubtitles',
            ));
          } catch (e) {
            debugPrint('Error parsing subtitle result: $e');
            continue;
          }
        }

        return results;
      } else if (response.statusCode == 401) {
        debugPrint('OpenSubtitles API authentication failed');
        return [];
      } else if (response.statusCode == 429) {
        debugPrint('OpenSubtitles API rate limit exceeded');
        return [];
      } else {
        debugPrint(
            'OpenSubtitles API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error searching OpenSubtitles: $e');
      return [];
    }
  }

  /// 转换语言代码到 ISO 639-2B
  String _convertToISO6392B(String langCode) {
    final Map<String, String> langMap = {
      'zh': 'zh',
      'zh-cn': 'zh',
      'zh-tw': 'zh',
      'en': 'en',
      'ja': 'ja',
      'ko': 'ko',
      'fr': 'fr',
      'de': 'de',
      'es': 'es',
      'it': 'it',
      'pt': 'pt',
      'ru': 'ru',
    };
    return langMap[langCode.toLowerCase()] ?? langCode;
  }

  /// 获取语言名称
  String _getLanguageNameFromCode(String code) {
    final Map<String, String> langNames = {
      'zh': '简体中文',
      'en': 'English',
      'ja': '日本語',
      'ko': '한국어',
      'fr': 'Français',
      'de': 'Deutsch',
      'es': 'Español',
      'it': 'Italiano',
      'pt': 'Português',
      'ru': 'Русский',
    };
    return langNames[code] ?? code;
  }

  /// 获取模拟结果（调试用）
  List<SubtitleSearchResult> _getMockResults(String query) {
    return [
      SubtitleSearchResult(
        id: 'mock_1',
        title: '$query - 完美匹配字幕',
        language: 'zh',
        languageName: '简体中文',
        format: 'srt',
        rating: 5.0,
        downloads: 9999,
        uploadDate: DateTime.now(),
        downloadUrl: 'mock://perfect/1',
        source: 'Mock',
      ),
    ];
  }

  /// 去重结果
  List<SubtitleSearchResult> _deduplicateResults(
      List<SubtitleSearchResult> results) {
    final seen = <String>{};
    final uniqueResults = <SubtitleSearchResult>[];

    for (final result in results) {
      final key = '${result.title.toLowerCase()}_${result.language}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueResults.add(result);
      }
    }

    // 按评分和下载量排序
    uniqueResults.sort((a, b) {
      if (a.rating != b.rating) {
        return b.rating.compareTo(a.rating);
      }
      return b.downloads.compareTo(a.downloads);
    });

    return uniqueResults;
  }

  /// 真实字幕下载
  Future<String?> _downloadRealSubtitle(
      SubtitleSearchResult result, String targetPath) async {
    try {
      final response = await http.get(Uri.parse(result.downloadUrl));

      if (response.statusCode == 200) {
        final fileName =
            '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
        final filePath = path.join(path.dirname(targetPath), fileName);

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('Downloaded subtitle to: $filePath');
        return filePath;
      } else {
        debugPrint('Failed to download subtitle: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in real subtitle download: $e');
      return null;
    }
  }

  /// 模拟字幕下载（调试用）
  Future<String?> _downloadMockSubtitle(
      SubtitleSearchResult result, String targetPath) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // 模拟下载时间

      // 创建一个简单的字幕文件内容
      final subtitleContent = _generateMockSubtitleContent(result);

      final fileName =
          '${path.basenameWithoutExtension(targetPath)}_${result.id}.${result.format}';
      final filePath = path.join(path.dirname(targetPath), fileName);

      final file = File(filePath);
      await file.writeAsString(subtitleContent);

      debugPrint('Created mock subtitle: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error in mock subtitle download: $e');
      return null;
    }
  }

  /// 生成模拟字幕内容
  String _generateMockSubtitleContent(SubtitleSearchResult result) {
    final timestamp = DateTime.now();
    return '''1
00:00:01,000 --> 00:00:03,000
这是模拟的字幕内容

2
00:00:03,500 --> 00:00:06,000
视频名称: ${result.title}

3
00:00:06,500 --> 00:00:09,000
语言: ${result.languageName}

4
00:00:09,500 --> 00:00:12,000
评分: ${result.rating.toString()}

5
00:00:12,500 --> 00:00:15,000
下载次数: ${result.downloads.toString()}

6
00:00:15,500 --> 00:00:18,000
生成时间: ${timestamp.toString()}

7
00:00:18,500 --> 00:00:21,000
这是一个用于测试的字幕文件

8
00:00:21,500 --> 00:00:24,000
在实际使用中，这里应该是真实的字幕内容

9
00:00:24,500 --> 00:00:27,000
感谢使用影核播放器！
''';
  }

  /// 从文件选择器选择本地字幕文件
  Future<String?> pickLocalSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }

      return null;
    } catch (e) {
      debugPrint('Error picking local subtitle file: $e');
      return null;
    }
  }

  /// 获取支持的语言列表
  List<SubtitleLanguage> getSupportedLanguages() {
    return [
      const SubtitleLanguage(code: 'zh', name: '简体中文'),
      const SubtitleLanguage(code: 'zh-CN', name: '简体中文'),
      const SubtitleLanguage(code: 'zh-TW', name: '繁体中文'),
      const SubtitleLanguage(code: 'en', name: 'English'),
      const SubtitleLanguage(code: 'ja', name: '日本語'),
      const SubtitleLanguage(code: 'ko', name: '한국어'),
      const SubtitleLanguage(code: 'fr', name: 'Français'),
      const SubtitleLanguage(code: 'de', name: 'Deutsch'),
      const SubtitleLanguage(code: 'es', name: 'Español'),
      const SubtitleLanguage(code: 'it', name: 'Italiano'),
      const SubtitleLanguage(code: 'pt', name: 'Português'),
      const SubtitleLanguage(code: 'ru', name: 'Русский'),
      const SubtitleLanguage(code: 'ar', name: 'العربية'),
      const SubtitleLanguage(code: 'hi', name: 'हिन्दी'),
      const SubtitleLanguage(code: 'th', name: 'ไทย'),
      const SubtitleLanguage(code: 'vi', name: 'Tiếng Việt'),
    ];
  }
}

/// 字幕搜索结果
class SubtitleSearchResult {
  final String id;
  final String title;
  final String language;
  final String languageName;
  final String format;
  final double rating;
  final int downloads;
  final DateTime uploadDate;
  final String downloadUrl;
  final String source;

  const SubtitleSearchResult({
    required this.id,
    required this.title,
    required this.language,
    required this.languageName,
    required this.format,
    required this.rating,
    required this.downloads,
    required this.uploadDate,
    required this.downloadUrl,
    required this.source,
  });

  @override
  String toString() {
    return 'SubtitleSearchResult(id: $id, title: $title, language: $language, rating: $rating)';
  }
}

/// 字幕语言
class SubtitleLanguage {
  final String code;
  final String name;

  const SubtitleLanguage({
    required this.code,
    required this.name,
  });
}
