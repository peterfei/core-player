import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:yinghe_player/screens/home_screen.dart';

void main() {
  // Initialize media_kit
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '影核播放器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}