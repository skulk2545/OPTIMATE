import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  int selectedCamera = 0;
  bool busy = false;

  // ================= BACKEND =================
  static const String backendUrl =
      "http://15.207.247.69";

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera(widget.cameras[selectedCamera]);
  }

  @override
  void dispose() {
    controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ================= CAMERA =================
  Future<void> _initCamera(CameraDescription cam) async {
    controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> toggleCamera() async {
    if (busy || widget.cameras.length < 2) return;
    await controller?.dispose();
    controller = null;
    selectedCamera = (selectedCamera + 1) % widget.cameras.length;
    await _initCamera(widget.cameras[selectedCamera]);
  }

  // ================= NETWORK =================
  Future<http.Response> _sendRequest(Uint8List bytes) {
    return http
        .post(
          Uri.parse("$backendUrl/process"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"image_b64": base64Encode(bytes)}),
        )
        .timeout(const Duration(seconds: 30));
  }

  // ================= MAIN ACTION =================
  Future<void> captureAndSend() async {
    if (busy || controller == null || !controller!.value.isInitialized) return;
    setState(() => busy = true);

    try {
      final file = await controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      http.Response res;

      // 🔁 First attempt
      try {
        res = await _sendRequest(bytes);
      } catch (_) {
        // 🔁 Retry once (Render cold start)
        await Future.delayed(const Duration(seconds: 2));
        res = await _sendRequest(bytes);
      }

      if (res.statusCode != 200) {
        throw Exception("Server error ${res.statusCode}");
      }

      late final Map<String, dynamic> data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        throw Exception("Invalid response from server");
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            resultData: data,
            capturedImage: bytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller!.value.isInitialized)
            CameraPreview(controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // ✅ BLACK MASK
          const BlackOvalMask(),

          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: toggleCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  iconSize: 30,
                ),
                GestureDetector(
                  onTap: busy ? null : captureAndSend,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: busy ? Colors.grey : Colors.yellow,
                    ),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 34,
                            color: Colors.black,
                          ),
                  ),
                ),
                const SizedBox(width: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// BLACK OVAL MASK (STABLE)
// =====================================================

class BlackOvalMask extends StatelessWidget {
  const BlackOvalMask({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _BlackOvalPainter(),
      ),
    );
  }
}

class _BlackOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(rect, Paint());

    canvas.drawRect(
      rect,
      Paint()..color = Colors.black.withOpacity(0.8),
    );

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.48),
      width: size.width * 0.74,
      height: size.height * 0.56,
    );

    canvas.drawOval(
      ovalRect,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
