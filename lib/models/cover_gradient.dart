import 'package:flutter/material.dart';

class CoverGradient {
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  const CoverGradient({
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  LinearGradient toLinearGradient() {
    return LinearGradient(
      colors: colors,
      begin: begin,
      end: end,
    );
  }

  static const List<CoverGradient> presets = [
    CoverGradient(colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)]), // Warm Flame
    CoverGradient(colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)]), // Night Fade
    CoverGradient(colors: [Color(0xFF84FAB0), Color(0xFF8FD3F4)]), // Spring Warmth
    CoverGradient(colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)]), // Cold Mart
    CoverGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]), // Green Beach
    CoverGradient(colors: [Color(0xFFFA709A), Color(0xFFFEE140)]), // Juicy Peach
    CoverGradient(colors: [Color(0xFF30CFD0), Color(0xFF330867)]), // Deep Blue
    CoverGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]), // Plum Plate
  ];

  static CoverGradient fromString(String input) {
    if (input.isEmpty) return presets[0];
    final int hash = input.hashCode;
    final int index = (hash.abs()) % presets.length;
    return presets[index];
  }
}
