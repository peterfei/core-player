import 'dart:math';

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

    // Return the maximum
    return [levenshteinScore, jaccardScore, subsequenceScore].reduce(max);
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
