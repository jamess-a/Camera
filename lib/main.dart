import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData.dark(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? controller;
  bool isRecording = false;
  Timer? recordingTimer;
  int recordingTime = 0;
  CameraDescription? currentCamera;
  late List<CameraDescription> cameras;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    currentCamera = cameras.first;
    controller = CameraController(currentCamera!, ResolutionPreset.high);
    await controller!.initialize();
    setState(() {});
  }

  Future<void> startVideoRecording() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    try {
      await controller!.startVideoRecording();
      setState(() {
        isRecording = true;
        recordingTime = 0;
        startRecordingTimer();
      });
    } on CameraException catch (e) {
      print('Error starting video recording: $e');
    }
  }

  Future<void> stopVideoRecording() async {
    if (controller == null || !controller!.value.isRecordingVideo) return;

    try {
      final player = AudioPlayer();
      await player.play(AssetSource('beep.mp3'));

      final video = await controller!.stopVideoRecording();
      setState(() {
        isRecording = false;
      });
      recordingTimer?.cancel();

      final directory = await getTemporaryDirectory();
      final videoPath = '${directory.path}/${DateTime.now()}.mp4';
      File(video.path).copy(videoPath);

      GallerySaver.saveVideo(videoPath).then((bool? success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: const Color.fromARGB(0, 0, 0, 0),
              content:
                  Text(success! ? 'Video saved!' : 'Failed to save video.')),
        );
      });
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
    }
  }

  void startRecordingTimer() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('beep.mp3'));

      recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          recordingTime++;
        });
      });
    } catch (e) {
      print('Error starting recording timer: $e');
    }
  }

  Future<void> takePicture() async {
    if (controller != null && controller!.value.isInitialized) {
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('camera-shutter-photo.mp3'));

        if (await Vibration.hasVibrator() ?? false) {
          print('Vibrating');
          Vibration.vibrate(duration: 100); 
        }

        setState(() {
          _showFlash = true;
        });

        await Future.delayed(const Duration(milliseconds: 100));

        setState(() {
          _showFlash = false;
        });

        // Take the picture
        final file = await controller!.takePicture();
        final bool? success = await GallerySaver.saveImage(file.path);

        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color.fromARGB(0, 0, 0, 0),
              content: Text(
                style: const TextStyle(color: Colors.white),
                'Picture saved to ${file.path}',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color.fromARGB(0, 0, 0, 0),
              content: Text(
                style: TextStyle(color: Colors.white),
                'Failed to save picture',
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void switchCamera() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('dslr-shutter-st.mp3'));

      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      final newIndex = cameras.indexOf(currentCamera!) == 0 ? 1 : 0;
      currentCamera = cameras[newIndex];
      controller = CameraController(currentCamera!, ResolutionPreset.high);
      controller!.initialize().then((_) {
        setState(() {});
      });
    });
  }

  bool _showFlash = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera App'),
      ),
      body: controller == null || !controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(controller!),
                if (isRecording)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Recording Time: ${recordingTime}s',
                        style: const TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    ),
                  ),
                // Flash effect overlay
                if (_showFlash)
                  Container(
                    color: Colors.white.withOpacity(0.7),
                  ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: takePicture,
            tooltip: 'Take Picture',
            child: const Icon(Icons.camera),
          ),
          const SizedBox(width: 20),
          FloatingActionButton(
            onPressed: isRecording ? stopVideoRecording : startVideoRecording,
            tooltip: isRecording ? 'Stop Recording' : 'Record Video',
            child: Icon(
              isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: isRecording
                  ? Colors.red
                  : const Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          const SizedBox(width: 20),
          FloatingActionButton(
            onPressed: switchCamera,
            tooltip: 'Switch Camera',
            child: const Icon(Icons.switch_camera),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    recordingTimer?.cancel();
    super.dispose();
  }
}
