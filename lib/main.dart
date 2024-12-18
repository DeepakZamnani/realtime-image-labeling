import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'dart:io';
import 'package:flutter/services.dart';

late List<CameraDescription> devices;
void main() async {
  devices = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: RealTimeCam(),
    );
  }
}

class RealTimeCam extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _real();
  }
}

class _real extends State<RealTimeCam> {
  @override
  bool isBusy = false;
  final ImageLabelerOptions options =
      ImageLabelerOptions(confidenceThreshold: 0.6);
  late ImageLabeler labeler;
  late CameraController controller;
  late String text;
  late int index;
  late double confidence;

  @override
  void initState() {
    controller = CameraController(
      devices[0],
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888,
    );
    labeler = ImageLabeler(options: options);
    text = '';
    index = 0;
    confidence = 0;
    super.initState();
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = devices[1];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  performLabeling(CameraImage img) async {
    text = '';
    InputImage? inpImage = _inputImageFromCameraImage(img);
    final List<ImageLabel> labels = await labeler.processImage(inpImage!);

    for (ImageLabel label in labels) {
      setState(() {
        text += '${label.label}\n';
        index += label.index;
        confidence += label.confidence;
      });
    }
    setState(() {
      text;
    });
  }

  startStream() {
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) {
        setState(() {
          performLabeling(image);
        });
      });
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
  }

  checkCAmera() {
    print(devices);
  }

  turnOfff() {
    setState(() {
      controller.stopImageStream();
    });
  }

  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text('RealTime Image Labeling'),
        backgroundColor: Colors.black12,
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 20,
          ),
          TextButton(
              onLongPress: () {
                turnOfff();
              },
              onPressed: () {
                startStream();
              },
              child: Text(
                'Turn On Camera!',
                style: TextStyle(fontSize: 20),
              )),
          const SizedBox(
            height: 20,
          ),
          Card(
            color: Colors.black12,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 400,
                  child: controller.value.isInitialized
                      ? CameraPreview(controller)
                      : Center(
                          child: Text(
                            'Please Start the Strean!',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                Text(text)
              ],
            ),
          ),
          const SizedBox(
            height: 40,
          ),
        ],
      ),
    );
  }
}
 ""