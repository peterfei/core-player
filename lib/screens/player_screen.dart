import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  final File videoFile;
  const PlayerScreen({super.key, required this.videoFile});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Create a [Player] instance from `media_kit`.
  late final Player player = Player();
  // Create a [VideoController] instance from `media_kit_video`.
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    // Open the video file and start playing.
    player.open(Media(widget.videoFile.path), play: true);
  }

  @override
  void dispose() {
    // Make sure to dispose the player and controller.
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.videoFile.path.split('/').last),
      ),
      body: Center(
        child: Video(
          controller: controller,
        ),
      ),
    );
  }
}
