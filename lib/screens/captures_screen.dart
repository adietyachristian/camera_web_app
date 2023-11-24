import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'preview_screen.dart';

class CapturesScreen extends StatefulWidget {
  final List<File> imageFileList;

  const CapturesScreen({super.key, required this.imageFileList});

  @override
  State<CapturesScreen> createState() => _CapturesScreenState();
}

class _CapturesScreenState extends State<CapturesScreen> {
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();

    for (var i = 0; i < widget.imageFileList.length; i++) {
      final imageFile = widget.imageFileList[i];
      if (imageFile.path.contains('.mp4')) {
        _startVideoPlayer(imageFile, i);
      }
    }
  }

  @override
  void dispose() {
    for (final videoController in _videoControllers.values) {
      videoController.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  Future<void> _startVideoPlayer(File file, int index) async {
    final videoController = VideoPlayerController.file(file);
    _videoControllers[index] = videoController;
    videoController.initialize().then((_) {
      // Ensure the first frame is shown after the video is initialized,
      // even before the play button has been pressed.
      setState(() {});
    });
    await videoController.seekTo(const Duration(seconds: 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Captures',
                style: TextStyle(
                  fontSize: 32.0,
                  color: Colors.white,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              children: List.generate(widget.imageFileList.length, (index) {
                final imageFile = widget.imageFileList[index];

                if (imageFile.path.contains('.mp4')) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => PreviewScreen(
                              fileList: widget.imageFileList,
                              imageFile: imageFile,
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          VideoPlayer(_videoControllers[index]!),
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 48.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => PreviewScreen(
                            fileList: widget.imageFileList,
                            imageFile: imageFile,
                          ),
                        ),
                      );
                    },
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
