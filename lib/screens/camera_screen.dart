import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_web_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? videoController;

  File? _imageFile;
  File? _videoFile;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isRearCameraSelected = true;
  bool _isVideoCameraSelected = false;
  bool _isRecordingInProgress = false;
  bool _isPCViewSelected = false;
  bool _isSettingsExpanded = false;

  // Current values
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];

  final resolutionPresets = ResolutionPreset.values;

  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      log('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      refreshAlreadyCapturedImages();
    } else {
      log('Camera Permission: DENIED');
    }
  }

  refreshAlreadyCapturedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];

    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      if (recentFileName.contains('.mp4')) {
        _videoFile = File('${directory.path}/$recentFileName');
        _imageFile = null;
        _startVideoPlayer();
      } else {
        _imageFile = File('${directory.path}/$recentFileName');
        _videoFile = null;
      }

      setState(() {});
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      log('Error occured while taking picture: $e');
      return null;
    }
  }

  Future<void> _startVideoPlayer() async {
    if (_videoFile != null) {
      videoController = VideoPlayerController.file(_videoFile!);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.seekTo(const Duration(seconds: 0));
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }

    try {
      await cameraController!.startVideoRecording();
      setState(() {
        _isRecordingInProgress = true;
        log(_isRecordingInProgress.toString());
      });
    } on CameraException catch (e) {
      log('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }

    try {
      XFile file = await controller!.stopVideoRecording();
      setState(() {
        _isRecordingInProgress = false;
      });
      return file;
    } on CameraException catch (e) {
      log('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }

    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      log('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }

    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      log('Error resuming video recording: $e');
    }
  }

  void resetCameraValues() async {}

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();

      _currentFlashMode = controller!.value.flashMode == FlashMode.auto
          ? FlashMode.off
          : controller!.value.flashMode;
    } on CameraException catch (e) {
      log('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  @override
  void initState() {
    // hide status bar on android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    getPermissionStatus();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isCameraPermissionGranted
            ? _isCameraInitialized
                ? Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / controller!.value.aspectRatio,
                        child: Stack(
                          children: [
                            CameraPreview(
                              controller!,
                              child: LayoutBuilder(builder:
                                  (BuildContext context,
                                      BoxConstraints constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (details) =>
                                      onViewFinderTap(details, constraints),
                                );
                              }),
                            ),
                            _isPCViewSelected
                                ? Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: Colors.black.withOpacity(0.8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade900,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 70,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 20, horizontal: 40),
                                          child: Column(
                                            children: [
                                              const Text(
                                                'PC Viewer',
                                                style: TextStyle(
                                                    fontSize: 34,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w900),
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'powered by Weylus (v0.1)',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(height: 16),
                                              InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          const LoginScreen(),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 30,
                                                    vertical: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                  ),
                                                  child: const Text(
                                                    'SIGN IN',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isSettingsExpanded)
                                          Container(
                                            height: 50,
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white30,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(width: 16),
                                                InkWell(
                                                  onTap: () {},
                                                  child: const Icon(
                                                    Icons.timer_outlined,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 32),
                                                InkWell(
                                                  onTap: () async {
                                                    setState(() {
                                                      if (_isVideoCameraSelected) {
                                                        _currentFlashMode =
                                                            _currentFlashMode ==
                                                                    FlashMode
                                                                        .off
                                                                ? FlashMode
                                                                    .torch
                                                                : FlashMode.off;
                                                      } else {
                                                        _currentFlashMode =
                                                            _currentFlashMode ==
                                                                    FlashMode
                                                                        .off
                                                                ? FlashMode
                                                                    .always
                                                                : FlashMode.off;
                                                      }
                                                    });
                                                    await controller!
                                                        .setFlashMode(
                                                            _currentFlashMode!);
                                                  },
                                                  child: Icon(
                                                    Icons.flash_on_rounded,
                                                    color: _currentFlashMode ==
                                                                FlashMode.off ||
                                                            _currentFlashMode ==
                                                                null
                                                        ? Colors.white
                                                        : Colors.yellow,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                              ],
                                            ),
                                          ),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isSettingsExpanded =
                                                  !_isSettingsExpanded;
                                            });
                                          },
                                          child: Container(
                                            width: 84,
                                            height: 32,
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: EdgeInsets.only(
                                                top: _isSettingsExpanded
                                                    ? 0
                                                    : 10,
                                                left: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white30,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: // rotated icon
                                                Transform.rotate(
                                              angle: 90 * 3.14 / 180,
                                              child: Icon(
                                                _isSettingsExpanded
                                                    ? Icons.arrow_forward_ios
                                                    : Icons.arrow_back_ios,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    InkWell(
                                      onTap: _imageFile != null ||
                                              _videoFile != null
                                          ? () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PreviewScreen(
                                                    imageFile: _imageFile ??
                                                        _videoFile!,
                                                    fileList: allFileList,
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          image: _imageFile != null
                                              ? DecorationImage(
                                                  image: FileImage(_imageFile!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: _videoFile != null &&
                                                videoController != null &&
                                                videoController!
                                                    .value.isInitialized
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                child: AspectRatio(
                                                  aspectRatio: videoController!
                                                      .value.aspectRatio,
                                                  child: VideoPlayer(
                                                      videoController!),
                                                ),
                                              )
                                            : Container(),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _isVideoCameraSelected
                                          ? () async {
                                              if (_isRecordingInProgress) {
                                                XFile? rawVideo =
                                                    await stopVideoRecording();
                                                File videoFile =
                                                    File(rawVideo!.path);

                                                int currentUnix = DateTime.now()
                                                    .millisecondsSinceEpoch;

                                                final directory =
                                                    await getApplicationDocumentsDirectory();

                                                String fileFormat = videoFile
                                                    .path
                                                    .split('.')
                                                    .last;

                                                _videoFile =
                                                    await videoFile.copy(
                                                  '${directory.path}/$currentUnix.$fileFormat',
                                                );

                                                _startVideoPlayer();
                                              } else {
                                                await startVideoRecording();
                                              }
                                            }
                                          : () async {
                                              XFile? rawImage =
                                                  await takePicture();
                                              File imageFile =
                                                  File(rawImage!.path);

                                              int currentUnix = DateTime.now()
                                                  .millisecondsSinceEpoch;

                                              final directory =
                                                  await getApplicationDocumentsDirectory();

                                              String fileFormat = imageFile.path
                                                  .split('.')
                                                  .last;

                                              log(fileFormat);

                                              await imageFile.copy(
                                                '${directory.path}/$currentUnix.$fileFormat',
                                              );

                                              refreshAlreadyCapturedImages();
                                            },
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            color: _isVideoCameraSelected
                                                ? Colors.red
                                                : Colors.white24,
                                            size: 80,
                                          ),
                                          const Icon(
                                            Icons.circle,
                                            color: Colors.white,
                                            size: 65,
                                          ),
                                          _isVideoCameraSelected &&
                                                  _isRecordingInProgress
                                              ? const Icon(
                                                  Icons.stop_rounded,
                                                  color: Colors.red,
                                                  size: 32,
                                                )
                                              : Container(),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _isRecordingInProgress
                                          ? () async {
                                              if (controller!
                                                  .value.isRecordingPaused) {
                                                await resumeVideoRecording();
                                              } else {
                                                await pauseVideoRecording();
                                              }
                                            }
                                          : () {
                                              setState(() {
                                                _isCameraInitialized = false;
                                              });
                                              onNewCameraSelected(cameras[
                                                  _isRearCameraSelected
                                                      ? 1
                                                      : 0]);
                                              setState(() {
                                                _isRearCameraSelected =
                                                    !_isRearCameraSelected;
                                              });
                                            },
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Icon(
                                            Icons.circle,
                                            color: Colors.black38,
                                            size: 62,
                                          ),
                                          _isRecordingInProgress
                                              ? controller!
                                                      .value.isRecordingPaused
                                                  ? const Icon(
                                                      Icons.play_arrow,
                                                      color: Colors.white,
                                                      size: 30,
                                                    )
                                                  : const Icon(
                                                      Icons.pause,
                                                      color: Colors.white,
                                                      size: 30,
                                                    )
                                              : const Icon(
                                                  Icons.refresh,
                                                  color: Colors.white,
                                                  size: 35,
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4.0, right: 8.0),
                                        child: GestureDetector(
                                          onTap: _isRecordingInProgress
                                              ? null
                                              : () {
                                                  if (_isVideoCameraSelected ||
                                                      _isPCViewSelected) {
                                                    setState(() {
                                                      _isPCViewSelected = false;
                                                      _isVideoCameraSelected =
                                                          false;
                                                    });
                                                  }
                                                },
                                          child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: !_isVideoCameraSelected &&
                                                      !_isPCViewSelected
                                                  ? Colors.grey.shade900
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Center(
                                                child: Text(
                                              'PHOTO',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      !_isVideoCameraSelected &&
                                                              !_isPCViewSelected
                                                          ? Colors.white
                                                          : Colors.black),
                                            )),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4.0, right: 8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            if (!_isVideoCameraSelected ||
                                                _isPCViewSelected) {
                                              setState(() {
                                                _isPCViewSelected = false;
                                                _isVideoCameraSelected = true;
                                              });
                                            }
                                          },
                                          child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _isVideoCameraSelected &&
                                                      !_isPCViewSelected
                                                  ? Colors.grey.shade900
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Center(
                                                child: Text(
                                              'VIDEO',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      _isVideoCameraSelected &&
                                                              !_isPCViewSelected
                                                          ? Colors.white
                                                          : Colors.black),
                                            )),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4.0, right: 8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isPCViewSelected =
                                                  !_isPCViewSelected;
                                            });
                                          },
                                          child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _isPCViewSelected
                                                  ? Colors.grey.shade900
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Center(
                                                child: Text(
                                              'PCVIEW',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: _isPCViewSelected
                                                      ? Colors.white
                                                      : Colors.black),
                                            )),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 8,
                    ),
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(),
                  const Text(
                    'Permission denied',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      getPermissionStatus();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Give permission',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
