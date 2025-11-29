import '../lib/core/scraping/similarity_calculator.dart';

void main() {
  final pairs = [
    ("江河岁如", "大江大河岁月如歌"),
    ("球动3", "地球脉动 3"),
    ("凡物观", "超凡动物奇观"),
    ("朝事之行", "唐朝诡事录之西行"),
    ("法们", "执法者们"),
    ("王王", "状王之王"),
    ("琊", "琅琊榜"),
    ("午云", "甲午风云"),
  ];

  for (final pair in pairs) {
    final score = SimilarityCalculator.calculate(pair.$1, pair.$2);
    print("'${pair.$1}' vs '${pair.$2}': ${score.toStringAsFixed(2)}");
  }
}
