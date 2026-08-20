import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Fills the available space like DramaBox/TikTok (cover crop).
class VerticalVideoView extends StatelessWidget {
  final VideoPlayerController controller;

  const VerticalVideoView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
