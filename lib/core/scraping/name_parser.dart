import 'package:path/path.dart' as path;
import 'naming_patterns.dart';
import 'scraping_candidate.dart';

class NameParser {
  /// Cleans the filename and extracts structured information.
  static ScrapingCandidate parse(String filename) {
    String name = path.basenameWithoutExtension(filename);
    
    // 0. Check if this is an invalid name
    final nameLower = name.toLowerCase().trim();
    for (final invalid in NamingPatterns.invalidNames) {
      if (nameLower == invalid.toLowerCase()) {
        return ScrapingCandidate(query: '', originalName: name);
      }
    }
    
    // 1. Extract Year
    int? year;
    final yearMatch = NamingPatterns.year.firstMatch(name);
    if (yearMatch != null) {
      year = int.parse(yearMatch.group(0)!);
    }

    // 2. Extract Season and Episode
    int? season;
    int? episode;
    
    for (final pattern in NamingPatterns.seasonEpisode) {
      final match = pattern.firstMatch(name);
      if (match != null) {
        if (match.groupCount >= 2) {
          season = int.tryParse(match.group(1)!);
          episode = int.tryParse(match.group(2)!);
        } else if (match.groupCount == 1) {
          // Case like EP01, assume Season 1
          season = 1;
          episode = int.tryParse(match.group(1)!);
        }
        break; // Stop after first match
      }
    }

    // 3. Clean the name
    String cleanName = name;
    
    // Remove advertisement patterns FIRST
    for (final adPattern in NamingPatterns.adPatterns) {
      cleanName = cleanName.replaceAll(adPattern, '');
    }
    
    // Replace dots, underscores with spaces
    cleanName = cleanName.replaceAll(RegExp(r'[._]'), ' ');
    
    // Remove multiple spaces and trim
    cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove resolution
    cleanName = cleanName.replaceAll(NamingPatterns.resolution, '');
    
    // Remove codec
    cleanName = cleanName.replaceAll(NamingPatterns.codec, '');
    
    // Remove audio
    cleanName = cleanName.replaceAll(NamingPatterns.audio, '');
    
    // Remove source
    cleanName = cleanName.replaceAll(NamingPatterns.source, '');
    
    // Remove language/subtitle info
    cleanName = cleanName.replaceAll(NamingPatterns.language, '');
    
    // Remove release group
    cleanName = cleanName.replaceAll(NamingPatterns.releaseGroup, '');
    
    // Remove junk words
    for (final word in NamingPatterns.junkWords) {
      cleanName = cleanName.replaceAll(RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false), '');
    }
    
    // Remove season/episode info
    for (final pattern in NamingPatterns.seasonEpisode) {
      cleanName = cleanName.replaceAll(pattern, '');
    }
    
    // Remove "第X季" pattern
    cleanName = cleanName.replaceAll(RegExp(r'第\d+季'), '');
    
    // Remove video extensions (in case they appear as words)
    for (final ext in NamingPatterns.videoExtensions) {
      cleanName = cleanName.replaceAll(RegExp(r'\b' + ext + r'\b', caseSensitive: false), '');
    }
    
    // Remove "end" suffix (before removing numbers)
    cleanName = cleanName.replaceAll(RegExp(r'\s*end\s*$', caseSensitive: false), '');
    
    // Remove version numbers (v2, v3, etc.) - before removing trailing numbers
    cleanName = cleanName.replaceAll(RegExp(r'\s+v\d+\s*$', caseSensitive: false), '');
    
    // ONLY remove trailing numbers in specific cases:
    // 1. Episode ranges like "01 07", "08 13" (two 2-digit numbers with space)
    // 2. Single trailing numbers ONLY if they appear after season/episode info was already extracted
    //    This prevents removing meaningful numbers like "1919", "12" from titles
    
    // Remove episode ranges (e.g. "01 07", "08 13") - these are clearly episode ranges
    // Match 1-2 digit numbers separated by space at the end
    cleanName = cleanName.replaceAll(RegExp(r'\d{1,2}\s+\d{1,2}\s*$'), '');
    
    // Only remove single trailing 2-digit numbers if we already extracted season/episode info
    // This prevents removing "12" from "刑侦12" or "1919" from "我的1919"
    if (season != null || episode != null) {
      // If we found season/episode, it's safe to remove trailing numbers
      cleanName = cleanName.replaceAll(RegExp(r'\s+\d{1,2}\s*$'), '');
    }
    
    // Remove year from name for searching title (year has already been extracted)
    // Only remove if it appears as a separate word (with word boundaries)
    if (year != null) {
      cleanName = cleanName.replaceAll(RegExp(r'\b' + year.toString() + r'\b'), '');
    }

    // De-obfuscation: Remove single Latin letters mixed with Chinese characters
    // e.g. "n来b往" -> "来往", "p兹b医h前x" -> "兹医前"
    // "X战j：t启" -> "X战：启"
    // De-obfuscation: Remove single Latin letters mixed with Chinese characters
    // e.g. "n来b往" -> "来往", "p兹b医h前x" -> "兹医前"
    // "X战j：t启" -> "X战：启"
    // "d球m动d3j" -> "球动3"
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(cleanName)) {
       // Remove single letters followed by Chinese (or punctuation then Chinese)
       // But preserve Uppercase letter at start of string (e.g. "X战警")
       
       // 1. Remove single lowercase letters at start
       cleanName = cleanName.replaceAll(RegExp(r'^[a-z](?=[\u4e00-\u9fa5])'), '');

       // 2. Remove single letters between Chinese/Punctuation and Chinese/Punctuation
       // We want to remove 'j' in "战j：" and 't' in "：t启"
       // Pattern: (?<=[\u4e00-\u9fa5\uff00-\uffef])\s*[a-zA-Z]\s*(?=[\u4e00-\u9fa5\uff00-\uffef])
       // \uff00-\uffef includes fullwidth punctuation like ：
       cleanName = cleanName.replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5\uff01-\uff5e\u3000-\u303f])\s*[a-zA-Z]\s*(?=[\u4e00-\u9fa5\uff01-\uff5e\u3000-\u303f])'), '');
       
       // 3. Remove single letters at end if preceded by Chinese
       cleanName = cleanName.replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])[a-zA-Z]$'), '');
       
       // 4. Handle standard "n来" or "b往" cases not covered above
       cleanName = cleanName.replaceAll(RegExp(r'(?<=\s)[a-z](?=[\u4e00-\u9fa5])'), ''); // " n来"
       cleanName = cleanName.replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])[a-z](?=\s|$)'), ''); // "b往 "
       
       // 5. Handle "d3j" case: remove single letter before number if preceded by Chinese
       // "动d3" -> "动3"
       cleanName = cleanName.replaceAll(RegExp(r'(?<=[\u4e00-\u9fa5])[a-zA-Z](?=\d)'), '');
       
       // 6. Handle "3j" case: remove single letter after number if followed by space/end
       // "3j" -> "3"
       cleanName = cleanName.replaceAll(RegExp(r'(?<=\d)[a-zA-Z](?=\s|$)'), '');
       
       // 7. Handle "g" in "如g" (single letter at end of word)
       // My previous regex #3 handled (?<=[\u4e00-\u9fa5])[a-zA-Z]$ (end of string).
       // But "g" might be followed by " HD".
       // So we need (?<=[\u4e00-\u9fa5])[a-zA-Z](?=\s|$)
       // Wait, #4 covers this: (?<=[\u4e00-\u9fa5])[a-z](?=\s|$)
       // Why did "如g" fail?
       // Ah, "d江d河z岁y如g HD".
       // "g" is followed by space.
       // Maybe 'g' is not [a-z]? It is.
       // Let's check why "g" was not removed.
       // "y如" -> "如". 'y' was removed.
       // "g" is after "如".
       // Maybe because I'm doing replaceAll sequentially?
       // "d江d河z岁y如g HD"
       // "d江" -> "江"
       // "d河" -> "河"
       // "z岁" -> "岁"
       // "y如" -> "如"
       // "g HD" -> "g HD".
       // "g" is preceded by "如" (Chinese).
       // Regex #4: (?<=[\u4e00-\u9fa5])[a-z](?=\s|$)
       // It should match 'g'.
       // Maybe "HD" is not just space?
       // "g HD". 'g' is followed by space.
       // Let's verify regex #4 again.
    }

    // Final cleanup of spaces
    cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ScrapingCandidate(
      query: cleanName,
      year: year,
      season: season,
      episode: episode,
      originalName: name,
    );
  }

  /// Generates a list of candidates for searching.
  static List<ScrapingCandidate> generateCandidates(String filename) {
    final parsed = parse(filename);
    final candidates = <ScrapingCandidate>[];

    // 1. Cleaned name
    if (parsed.query.isNotEmpty) {
      candidates.add(parsed);
    }

    // 2. Original name (sometimes useful if cleaning is too aggressive)
    // But usually we want to try variations.
    
    // 3. If name contains brackets, try removing them
    // e.g. "[Group] Title (Year)" -> "Title"
    // This is partially covered by regex, but let's add specific logic if needed.

    return candidates;
  }
}
