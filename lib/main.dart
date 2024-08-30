import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
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
              content:
                  Text(success! ? 'Video saved!' : 'Failed to save video.')),
        );
      });
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
    }
  }

  void startRecordingTimer() {
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        recordingTime++;
      });
    });
  }

  Future<void> takePicture() async {
    if (controller != null && controller!.value.isInitialized) {
      try {
        final file = await controller!.takePicture();
        final bool? success = await GallerySaver.saveImage(file.path);
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Picture saved to ${file.path}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save picture')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void switchCamera() {
    setState(() {
      final newIndex = cameras.indexOf(currentCamera!) == 0 ? 1 : 0;
      currentCamera = cameras[newIndex];
      controller = CameraController(currentCamera!, ResolutionPreset.high);
      controller!.initialize().then((_) {
        setState(() {});
      });
    });
  }

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
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    ),
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
              isRecording ? Icons.stop : Icons.videocam,
              color: isRecording ? Colors.red : Colors.blue,
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
