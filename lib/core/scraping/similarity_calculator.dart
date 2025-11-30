import 'dart:math';
import 'package:lpinyin/lpinyin.dart';

class SimilarityCalculator {
  /// Calculates the similarity between two strings (0.0 to 1.0).
  /// Uses a hybrid approach or defaults to Levenshtein.
  static double calculate(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final s1Lower = s1.toLowerCase().trim();
    final s2Lower = s2.toLowerCase().trim();

    if (s1Lower == s2Lower) return 1.0;

    // Calculate Levenshtein similarity
    final levenshteinScore = _calculateLevenshteinSimilarity(s1Lower, s2Lower);
    
    // Calculate Jaccard similarity (token based)
    final jaccardScore = _calculateJaccardSimilarity(s1Lower, s2Lower);

    // Calculate Subsequence similarity
    final subsequenceScore = _calculateSubsequenceSimilarity(s1Lower, s2Lower);

    // Calculate Pinyin similarity (useful for obfuscated titles like "p兹b医h前x")
    final pinyinScore = _calculatePinyinSimilarity(s1Lower, s2Lower);

    // Return the maximum
    return [levenshteinScore, jaccardScore, subsequenceScore, pinyinScore].reduce(max);
  }

  /// Calculates similarity based on Pinyin matching using LCS (Longest Common Subsequence).
  /// Useful for obfuscated titles where some characters are replaced by their Pinyin initials.
  /// e.g. "p兹b医h前x" vs "匹兹堡医护前线"
  static double _calculatePinyinSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final lcsLength = _calculatePinyinLCS(s1, s2);
    final maxLength = max(s1.length, s2.length);
    
    if (maxLength == 0) return 0.0;
    
    // Boost the score slightly if it's a good match
    double score = lcsLength / maxLength;
    
    // If coverage is high for at least one string, boost it
    // e.g. "wsxj" (4) vs "我是刑警" (4) -> 4/4 = 1.0
    // "d球m动d3j" (7) vs "地球脉动3" (5) -> LCS=5. Score=5/7=0.71.
    
    return score;
  }

  static int _calculatePinyinLCS(String s1, String s2) {
    final n = s1.length;
    final m = s2.length;
    
    // dp[i][j] stores the length of LCS of s1[0..i-1] and s2[0..j-1]
    List<List<int>> dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    
    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final c1 = s1[i - 1];
        final c2 = s2[j - 1];
        
        bool match = false;
        if (c1 == c2) {
          match = true;
        } else if (_isLetter(c1) && _isChinese(c2)) {
          match = _checkPinyinMatch(c1, c2);
        } else if (_isChinese(c1) && _isLetter(c2)) {
          match = _checkPinyinMatch(c2, c1);
        }
        
        if (match) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }
    
    return dp[n][m];
  }

  static bool _checkPinyinMatch(String letter, String chinese) {
    try {
      List<String> pinyins = PinyinHelper.getPinyin(chinese).split(',');
      for (final pinyin in pinyins) {
        if (pinyin.isNotEmpty && pinyin[0].toLowerCase() == letter.toLowerCase()) {
          return true;
        }
      }
    } catch (e) {
      // Ignore
    }
    return false;
  }

  static bool _isLetter(String char) {
    return RegExp(r'[a-zA-Z]').hasMatch(char);
  }

  static bool _isChinese(String char) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(char);
  }


  static double _calculateLevenshteinSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = max(s1.length, s2.length);
    if (maxLength == 0) return 1.0;
    return 1.0 - (distance / maxLength);
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }

      for (int j = 0; j < s2.length + 1; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[s2.length];
  }

  static double _calculateJaccardSimilarity(String s1, String s2) {
    final set1 = s1.split(RegExp(r'\s+')).toSet();
    final set2 = s2.split(RegExp(r'\s+')).toSet();

    if (set1.isEmpty && set2.isEmpty) return 1.0;

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    if (union == 0) return 0.0;

    return intersection / union;
  }

  /// Calculates similarity based on whether s1 is a subsequence of s2 (or vice versa).
  /// Useful for cases like "江河岁如" matching "大江大河岁月如歌".
  static double _calculateSubsequenceSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Check if s1 is a subsequence of s2
    double score1 = _isSubsequence(s1, s2) ? (s1.length / s2.length) : 0.0;
    
    // Check if s2 is a subsequence of s1
    double score2 = _isSubsequence(s2, s1) ? (s2.length / s1.length) : 0.0;
    
    // Boost the score significantly if it is a subsequence
    // e.g. 4/8 = 0.5. We might want to boost this to 0.8 or 0.9 if it's a clean subsequence.
    // But we should be careful about short strings (e.g. "ab" in "absolute").
    // Let's require at least 3 characters or 50% length match.
    
    double maxScore = max(score1, score2);
    if (maxScore > 0) {
       // Apply a boost
       return 0.5 + (maxScore * 0.5); 
    }
    return 0.0;
  }

  static bool _isSubsequence(String s1, String s2) {
    int i = 0; // index for s1
    int j = 0; // index for s2
    
    while (i < s1.length && j < s2.length) {
      if (s1[i] == s2[j]) {
        i++;
      }
      j++;
    }
    return i == s1.length;
  }
}
