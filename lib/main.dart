import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The current device's available cameras.
List<CameraDescription> cameras = [];

/// Init available cameras once on startup.
Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    _logError(e.code, e.description);
  }
}

void main() {
  init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(MyApp());
  });
}

/// Minimal reproducible example showing that we can't get a better resolution
/// than 720p in the image stream provided by the camera plugin.
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Plugin Low Resolution',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CameraExampleHome(),
    );
  }
}

/// Stateful widget.
class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Unknown lens direction');
}

void _logError(String code, String message) => print("Error #$code: $message");

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  CameraController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        onNewCameraSelected(_controller.description);
      }
    }
  }

  Widget _cameraPreviewWidget() {
    if (_controller == null || !_controller.value.isInitialized) {
      return TextButton(
          onPressed: () {},
          child: Text('Select a camera',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24.0,
                fontWeight: FontWeight.w900,
              )));
    } else {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[CameraPreview(_controller)],
      );
    }
  }

  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      return Text("No Camera Found");
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(Expanded(
            flex: 1,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: _controller?.description,
              value: cameraDescription,
              onChanged: _controller != null ? null : onNewCameraSelected,
            )));
      }
    }
    return Row(children: toggles, mainAxisAlignment: MainAxisAlignment.start);
  }

  void onNewCameraSelected(final CameraDescription cameraDescription) async {
    await _controller?.dispose();

    // TODO: here we request max resolution
    _controller = CameraController(cameraDescription, ResolutionPreset.max,
        enableAudio: false);

    try {
      await _controller.initialize();
    } on CameraException catch (e) {
      _logError(e.code, e.description);
    }

    if (mounted) {
      setState(() {});
      await _controller.startImageStream((image) {
        // TODO: the maximum we receive here is 720p
        print("Actual image size: ${image.width}x${image.height}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
            title: Text("Camera Plugin Low Resolution"),
            backgroundColor: Colors.white),
        body: Column(children: <Widget>[
          Expanded(
              child: Container(
                  child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Center(
                        child: _cameraPreviewWidget(),
                      )))),
          Padding(
              padding: const EdgeInsets.all(5.0),
              child: Center(
                child: _cameraTogglesRowWidget(),
              ))
        ]));
  }
}
