import 'dart:convert';

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

  bool busy = false;
  bool _isCapturing = false;

  int selectedCamera = 0;
  Key previewKey = UniqueKey();

  static const String backendUrl = "https://api.optifocus.in";

  bool captureWithFrame = true;

  bool get canFlip => widget.cameras.length > 1;

  bool get isFrontCamera =>
      widget.cameras[selectedCamera].lensDirection ==
      CameraLensDirection.front;

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

  Future<void> _initCamera(CameraDescription cam) async {
    await controller?.dispose();
    controller = null;

    final newController = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await newController.initialize();
    if (!mounted) return;

    setState(() {
      controller = newController;
      previewKey = UniqueKey();
    });
  }

  Future<void> flipCamera() async {
    if (busy || !canFlip) return;
    setState(() => busy = true);

    final currentLens = widget.cameras[selectedCamera].lensDirection;
    final newIndex =
        widget.cameras.indexWhere((c) => c.lensDirection != currentLens);

    if (newIndex != -1) {
      selectedCamera = newIndex;
      await _initCamera(widget.cameras[selectedCamera]);
    }

    if (mounted) setState(() => busy = false);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= CAPTURE =================
  Future<void> captureAndSend() async {
    if (_isCapturing) return;
    if (controller == null) return;
    if (!controller!.value.isInitialized) return;
    if (controller!.value.isTakingPicture) return;

    _isCapturing = true;
    setState(() => busy = true);

    try {
      await Future.delayed(const Duration(milliseconds: 120));

      final XFile file = await controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      final res = await http.post(
        Uri.parse("$backendUrl/process"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "image_b64": base64Encode(bytes),
          "meta": {
            "lens": isFrontCamera ? "front" : "back",
            "mirrored": isFrontCamera,
            "rotation_deg": 0,
            "capture_with_frame": captureWithFrame,
          }
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("Backend error ${res.statusCode}");
      }

      final data = jsonDecode(res.body);
      data["capture_with_frame"] = captureWithFrame;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            capturedImage: bytes,
            resultData: data,
          ),
        ),
      );
    } catch (e) {
      _showMessage("Capture failed. Hold still and try again.");
    } finally {
      _isCapturing = false;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    final mmToPx = (160 / 25.4) / dpr;
    final fourMmPx = 4 * mmToPx;

    const ovalHeight = 300.0;
    final ovalCenterY = size.height * 0.42;
    final ovalTopY = ovalCenterY - ovalHeight / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (controller != null && controller!.value.isInitialized)
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                maxHeight: size.height * 1.25,
                child: Transform.scale(
                  scale: 1.15,
                  child: CameraPreview(controller!, key: previewKey),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // ✅ ALWAYS SHOW OVAL OVERLAY
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _FaceGuidePainter(),
            ),
          ),

          Positioned(
            top: ovalTopY - 40,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                "Align your face to the oval",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // 🔴 RED DOT ONLY WHEN FRAME MODE
          if (isFrontCamera)
            Positioned(
              left: (size.width / 2) - 12,
              top: ovalTopY - fourMmPx - 140,
              child: IgnorePointer(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 12,
            child: canFlip
                ? IconButton(
                    icon: const Icon(Icons.cameraswitch,
                        color: Colors.white, size: 28),
                    onPressed: busy ? null : flipCamera,
                  )
                : const SizedBox.shrink(),
          ),

          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: ToggleButtons(
                isSelected: [captureWithFrame, !captureWithFrame],
                onPressed: busy
                    ? null
                    : (index) =>
                        setState(() => captureWithFrame = index == 0),
                borderRadius: BorderRadius.circular(20),
                color: Colors.white70,
                selectedColor: Colors.black,
                fillColor: Colors.yellow,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("With Frame"),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Without Frame"),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: busy ? null : captureAndSend,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: busy ? Colors.grey : Colors.yellow,
                  ),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.camera_alt,
                          size: 32, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= FACE GUIDE =================
class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.8);

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    final center = Offset(size.width / 2, size.height * 0.42);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: 240,
      height: 340,
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawOval(ovalRect, clearPaint);
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
