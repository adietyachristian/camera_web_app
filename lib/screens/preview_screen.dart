import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'captures_screen.dart';

class PreviewScreen extends StatefulWidget {
  final File imageFile;
  final List<File> fileList;

  const PreviewScreen({
    super.key,
    required this.imageFile,
    required this.fileList,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? videoController;

  @override
  void initState() {
    print("MASUK INIT STATE" + widget.imageFile.path);
    super.initState();
    if (widget.imageFile.path.contains('.mp4')) _startVideoPlayer();
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  Future<void> _startVideoPlayer() async {
    if (widget.imageFile.path.contains('.mp4')) {
      videoController = VideoPlayerController.file(widget.imageFile);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.seekTo(const Duration(seconds: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => CapturesScreen(
                      imageFileList: widget.fileList,
                    ),
                  ),
                );
              },
              child: Text('Go to all captures'),
              style: TextButton.styleFrom(
                primary: Colors.black,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: widget.imageFile.path.contains('.mp4')
                ? Column(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: videoController!.value.aspectRatio,
                          child: Expanded(child: VideoPlayer(videoController!)),
                        ),
                      ),
                      // play or pause button
                      IconButton(
                        iconSize: 48,
                        onPressed: () {
                          setState(() {
                            if (videoController!.value.isPlaying) {
                              videoController!.pause();
                            } else {
                              videoController!.play();
                            }
                          });
                        },
                        icon: Icon(
                          videoController!.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 48.0,
                        ),
                      ),
                    ],
                  )
                : Image.file(widget.imageFile),
          ),
        ],
      ),
    );
  }
}
