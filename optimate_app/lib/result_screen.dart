import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'final_result_screen.dart';

class ResultScreen extends StatefulWidget {
  final Uint8List capturedImage;
  final Map<String, dynamic> resultData;

  const ResultScreen({
    super.key,
    required this.capturedImage,
    required this.resultData,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // ================= STATIC FRAME VALUES =================
  static const double baseA = 45.0;
  static const double baseB = 28.0;
  static const double baseDBL = 16.0;
  static const double pxPerMm = 1.3;

  // ================= FRAME BOXES =================
  Rect leftBox = Rect.zero;
  Rect rightBox = Rect.zero;

  // ================= BACKEND DATA =================
  late final Offset leftEyeImg;
  late final Offset rightEyeImg;
  late final Size imageSize;

  late final double pdLeft;
  late final double pdRight;
  late final double pdTotal;

  Size? displaySize;

  // ================= VIEWER =================
  final TransformationController _viewerCtrl =
      TransformationController();

  // ================= CAPTURE =================
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    final l = widget.resultData["left_eye_center_px"];
    final r = widget.resultData["right_eye_center_px"];

    leftEyeImg = Offset(l[0].toDouble(), l[1].toDouble());
    rightEyeImg = Offset(r[0].toDouble(), r[1].toDouble());

    imageSize = Size(
      widget.resultData["image_width"].toDouble(),
      widget.resultData["image_height"].toDouble(),
    );

    pdLeft = (widget.resultData["pd_left_mm"] ?? 0).toDouble();
    pdRight = (widget.resultData["pd_right_mm"] ?? 0).toDouble();
    pdTotal = (widget.resultData["pd_total_mm"] ?? 0).toDouble();
  }

  // ================= IMAGE → SCREEN =================
  Offset mapImageToScreen(Offset p, Size display) {
    final scale = (display.width / imageSize.width)
        .clamp(0, display.height / imageSize.height);

    final dx = (display.width - imageSize.width * scale) / 2;
    final dy = (display.height - imageSize.height * scale) / 2;

    return Offset(p.dx * scale + dx, p.dy * scale + dy);
  }

  // ================= INIT BOXES =================
  void initBoxes(Size display) {
    if (leftBox != Rect.zero) return;

    final leftEye = mapImageToScreen(leftEyeImg, display);

    const w = baseA * pxPerMm;
    const h = baseB * pxPerMm;
    const dbl = baseDBL * pxPerMm;

    leftBox = Rect.fromCenter(center: leftEye, width: w, height: h);
    rightBox = Rect.fromCenter(
      center: Offset(leftEye.dx + w + dbl, leftEye.dy),
      width: w,
      height: h,
    );
  }

  // ================= MOVE =================
  void moveBox(bool left, Offset delta) {
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    setState(() {
      left
          ? leftBox = leftBox.shift(delta / scale)
          : rightBox = rightBox.shift(delta / scale);
    });
  }

  // ================= RESIZE =================
  void resizeBox(bool left, Alignment corner, Offset delta) {
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    final d = delta / scale;

    setState(() {
      Rect box = left ? leftBox : rightBox;

      double l = box.left;
      double t = box.top;
      double r = box.right;
      double b = box.bottom;

      if (corner.x < 0) l += d.dx;
      if (corner.x > 0) r += d.dx;
      if (corner.y < 0) t += d.dy;
      if (corner.y > 0) b += d.dy;

      final newBox = Rect.fromLTRB(
        l,
        t,
        (r - l).clamp(40, 300) + l,
        (b - t).clamp(30, 240) + t,
      );

      left ? leftBox = newBox : rightBox = newBox;
    });
  }

  // ================= CAPTURE =================
  Future<Uint8List> _captureAnnotatedImage() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;

    final ui.Image image =
        await boundary.toImage(pixelRatio: 3.0);

    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text("Frame Adjustment"),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final display = Size(c.maxWidth, c.maxHeight);
                displaySize ??= display;

                initBoxes(display);

                final le = mapImageToScreen(leftEyeImg, display);
                final re = mapImageToScreen(rightEyeImg, display);

                return RepaintBoundary(
                  key: _captureKey,
                  child: InteractiveViewer(
                    transformationController: _viewerCtrl,
                    minScale: 1.0,
                    maxScale: 4.0,
                    panEnabled: false,
                    scaleEnabled: true,
                    child: SizedBox(
                      width: display.width,
                      height: display.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(
                              widget.capturedImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                          _pdMarker(le),
                          _pdMarker(re),
                          _box(true),
                          _box(false),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 🔥 PD DISPLAY — RIGHT FIRST, THEN LEFT
          _row([
            _card("PD R", pdRight),
            _card("PD L", pdLeft),
            _card("PD", pdTotal),
          ]),

          _row([
            _card("A", leftBox.width / pxPerMm),
            _card("B", leftBox.height / pxPerMm),
            _card(
              "DBL",
              (rightBox.left - leftBox.right)
                      .clamp(0, 500) /
                  pxPerMm,
            ),
          ]),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child:
                    const Text("Confirm & View Final Result"),
                onPressed: () async {
                  final annotated =
                      await _captureAnnotatedImage();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinalResultScreen(
                        image: annotated,
                        pxPerMm: pxPerMm,
                        A: leftBox.width / pxPerMm,
                        B: leftBox.height / pxPerMm,
                        DBL: (rightBox.left -
                                leftBox.right) /
                            pxPerMm,
                        pdLeft: pdLeft,
                        pdRight: pdRight,
                        pdTotal: pdTotal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        child: Row(
          children: children
              .expand((w) => [
                    Expanded(child: w),
                    const SizedBox(width: 8),
                  ])
              .toList()
            ..removeLast(),
        ),
      );

  Widget _box(bool left) {
    final box = left ? leftBox : rightBox;

    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: Stack(
        children: [
          GestureDetector(
            onPanUpdate: (d) => moveBox(left, d.delta),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const ui.Color.fromARGB(
                      255, 84, 254, 62),
                  width: 1.2,
                ),
              ),
            ),
          ),
          _corner(left, Alignment.topLeft),
          _corner(left, Alignment.topRight),
          _corner(left, Alignment.bottomLeft),
          _corner(left, Alignment.bottomRight),
        ],
      ),
    );
  }

  Widget _corner(bool left, Alignment a) => Align(
        alignment: a,
        child: GestureDetector(
          onPanUpdate: (d) =>
              resizeBox(left, a, d.delta),
          child: Container(
            width: 4,
            height: 4,
            color: const ui.Color.fromARGB(
                255, 53, 241, 63),
          ),
        ),
      );

  Widget _pdMarker(Offset p) => Positioned(
        left: p.dx - 8,
        top: p.dy - 8,
        child: const IgnorePointer(
          child: Icon(
            Icons.add,
            size: 16,
            color: ui.Color.fromARGB(
                255, 48, 240, 57),
          ),
        ),
      );

  Widget _card(String t, double v) => Card(
        color: const Color(0xFF1E1E1E),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(t,
                  style: const TextStyle(
                      color: Colors.white70)),
              const SizedBox(height: 6),
              Text(
                "${v.toStringAsFixed(1)} mm",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
}
