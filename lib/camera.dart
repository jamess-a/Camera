import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:gallery_saver/gallery_saver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(cameras: cameras),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const TakePictureScreen({super.key, required this.cameras});

  @override
  _TakePictureScreenState createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late CameraDescription _currentCamera;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingTime = 0;

  @override
  void initState() {
    super.initState();
    _currentCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    _initializeCamera();
  }

  void _initializeCamera() {
    _controller = CameraController(
      _currentCamera,
      ResolutionPreset.max,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  void _switchCamera() {
    setState(() {
      _currentCamera = _currentCamera.lensDirection == CameraLensDirection.back
          ? widget.cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
            )
          : widget.cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
            );
      _initializeCamera();
    });
  }

  void _startRecordingTimer() {
    _recordingTime = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingTime++;
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
  }

  Future<void> _toggleRecording() async {
    try {
      await _initializeControllerFuture;

      if (_isRecording) {
        if (_controller.value.isRecordingVideo) {
          final videoFile = await _controller.stopVideoRecording();
          final videoPath = videoFile.path;
          // Save the video to the gallery
          final result = await GallerySaver.saveVideo(videoPath);
          print('Video saved to gallery: $result');
          setState(() {
            _isRecording = false;
          });
          _stopRecordingTimer();
        } else {
          print('No video is currently recording.');
        }
      } else {
        await _controller.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
        _startRecordingTimer();
      }
    } catch (e) {
      print('Error in _toggleRecording: $e');
    }
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      // Save the image to the gallery
      final result = await ImageGallerySaver.saveFile(image.path);
      print('Image saved to gallery: $result');

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DisplayPictureScreen(imagePath: image.path),
        ),
      );
    } catch (e) {
      print('Error in _takePicture: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                if (_isRecording)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Recording Time: ${_recordingTime}s',
                        style: const TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    ),
                  ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.switch_camera),
                    color: Colors.white,
                    onPressed: _switchCamera,
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.camera),
              color: Colors.white,
              onPressed: _takePicture,
            ),
            IconButton(
              icon: Icon(
                _isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: _isRecording ? Colors.red : Colors.white,
              ),
              onPressed: _toggleRecording,
            ),
          ],
        ),
      ),
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.file(File(imagePath)),
          const SizedBox(height: 16),
          Center(
            child: Text('Saved to: $imagePath'),
          ),
        ],
      ),
    );
  }
}
