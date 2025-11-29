import '../lib/core/scraping/name_parser.dart';

void main() {
  final filenames = [
    "nz2",
    "n来b往 HD",
    "p兹b医h前x 2025 HD",
    "t朝g事l HD",
    "t朝g事l之x行 HD",
    "wsxj 6v电影地址发布页 www 6v123 net 收藏",
    "x巷r家 HD",
    "y叔g来: 囚... 2024 HD",
    "p兹b医h前x 2025 HD",
    "t朝g事l之x行 HD",
    "X战j：t启 2016 BD1080p 国英双语中英双字 mp4",
    "d江d河z岁y如g HD",
    "d球m动d3j HD",
    "c凡d物q观中配版 HD",
    "t朝g事l之x行",
    "z法z们",
    "z王z王",
    "l琊b",
    "j午f云 1894 1962"
  ];

  print("Parsing Results:");
  for (final name in filenames) {
    final result = NameParser.parse(name);
    print("Original: $name");
    print("Parsed:   '${result.query}'");
    print("Year:     ${result.year}");
    print("---");
  }
}
