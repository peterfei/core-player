class NamingPatterns {
  // Video extensions
  static const List<String> videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'mpg', 'mpeg', 'ts', 'iso'
  ];

  // Common resolution patterns
  static final RegExp resolution = RegExp(
    r'\b(4k|2160p|1080p|720p|480p|576p|8k|HD1080P?|HD720P?|BD1080P?|BD720P?|HD|BD)\b',
    caseSensitive: false,
  );

  // Common codec patterns
  static final RegExp codec = RegExp(
    r'(x264|x265|h264|h265|hevc|avc|divx|xvid|vp9|av1|H265)',
    caseSensitive: false,
  );

  // Common audio patterns
  static final RegExp audio = RegExp(
    r'(aac|ac3|dts|dts-hd|truehd|atmos|eac3|flac|mp3)',
    caseSensitive: false,
  );

  // Common source patterns
  static final RegExp source = RegExp(
    r'(bluray|blu-ray|web-dl|webrip|hdtv|dvdrip|bdrip|remux|BD|TCHD|蓝光)',
    caseSensitive: false,
  );

  // Release group patterns
  static final RegExp releaseGroup = RegExp(
    r'(-[a-zA-Z0-9]+$)',
  );

  // Year pattern (1900-2099)
  static final RegExp year = RegExp(
    r'\b(19|20)\d{2}\b',
  );

  // Season and Episode patterns
  static final List<RegExp> seasonEpisode = [
    RegExp(r'S(\d{1,2})E(\d{1,3})', caseSensitive: false), // S01E01
    RegExp(r'(\d{1,2})x(\d{1,3})', caseSensitive: false), // 1x01
    RegExp(r'EP(\d{1,3})', caseSensitive: false), // EP01
    RegExp(r'第(\d{1,3})[集话季]', caseSensitive: false), // 第01集
  ];

  // Website/advertisement patterns (需要移除的广告信息)
  static final List<RegExp> adPatterns = [
    RegExp(r'6v电影.*?收藏不迷路', caseSensitive: false),
    RegExp(r'电影港.*?收藏不迷路', caseSensitive: false),
    RegExp(r'阳光电影.*?(org|com|net)', caseSensitive: false),
    RegExp(r'www\s*\w+\s*(com|net|org|cn)', caseSensitive: false),
    RegExp(r'\d+v\d+.*?(com|net|org)', caseSensitive: false),
    RegExp(r'(dygod|ygdy8|dygang).*?(org|com|net)', caseSensitive: false),
  ];

  // Language/subtitle patterns (语言字幕信息)
  static final RegExp language = RegExp(
    r'(国语|英语|粤语|韩语|日语|国粤|中英|国英|中字|双语|双字|中英双字|国英双语|国粤双语|修正版)',
    caseSensitive: false,
  );

  // Junk words to remove
  static const List<String> junkWords = [
    'imax', 'uncut', 'extended', 'remastered', 'director\'s cut',
    'proper', 'repack', 'internal', 'complete', 'limited',
    'collector\'s cut', 'theatrical cut', 'unrated',
    '全集', '未删减', '高码版', '蓝光版'
  ];

  // Invalid folder names (无效的文件夹名，应该跳过)
  static const List<String> invalidNames = [
    '1080p', '720p', '480p', '4k', '2160p',
    '下载', '我的转存', '我的云盘缓存',
    'hd', 'bd', 'bluray', '蓝光版高码版'
  ];
}
