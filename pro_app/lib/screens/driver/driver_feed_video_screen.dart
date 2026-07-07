import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lecture plein écran d'une vidéo du fil d'actualité.
class DriverFeedVideoScreen extends StatefulWidget {
  final String videoUrl;

  const DriverFeedVideoScreen({super.key, required this.videoUrl});

  @override
  State<DriverFeedVideoScreen> createState() => _DriverFeedVideoScreenState();
}

class _DriverFeedVideoScreenState extends State<DriverFeedVideoScreen> {
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
          showControlsOnInitialize: true,
        );
      });
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de lire la vidéo');
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : (_chewieController == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Chewie(controller: _chewieController!)),
      ),
    );
  }
}
