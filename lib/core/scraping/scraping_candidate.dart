class ScrapingCandidate {
  final String query;
  final int? year;
  final int? season;
  final int? episode;
  final String? originalName;
  final double confidence;

  ScrapingCandidate({
    required this.query,
    this.year,
    this.season,
    this.episode,
    this.originalName,
    this.confidence = 1.0,
  });

  @override
  String toString() {
    return 'ScrapingCandidate(query: $query, year: $year, season: $season, episode: $episode, confidence: $confidence)';
  }
  
  ScrapingCandidate copyWith({
    String? query,
    int? year,
    int? season,
    int? episode,
    String? originalName,
    double? confidence,
  }) {
    return ScrapingCandidate(
      query: query ?? this.query,
      year: year ?? this.year,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      originalName: originalName ?? this.originalName,
      confidence: confidence ?? this.confidence,
    );
  }
}
