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
    
    // Remove year from name for searching title
    if (year != null) {
      cleanName = cleanName.replaceAll(year.toString(), '');
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
