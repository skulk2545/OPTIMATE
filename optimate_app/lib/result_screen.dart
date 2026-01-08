import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'final_result_screen.dart';

enum AdjustMode { none, pd, frame }

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
  // ================= STATIC FRAME DEFAULTS =================
  static const double STATIC_A_MM = 48.0;
  static const double STATIC_B_MM = 30.0;
  static const double STATIC_DBL_MM = 18.0;

  // ================= UI =================
  AdjustMode mode = AdjustMode.none;
  final TransformationController zoomCtrl = TransformationController();

  late bool captureWithFrame;

  // ================= IMAGE =================
  late double imgW, imgH, mmPerPx;

  // ================= PD =================
  late double basePdLeft, basePdRight, basePdTotal;
  late Offset baseLeftPx, baseRightPx;
  late Offset leftPx, rightPx;
  double pdLeft = 0, pdRight = 0, pdTotal = 0;

  // ================= FRAME =================
  Rect? leftFramePx, rightFramePx;
  double A = 0, B = 0, DBL = 0;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    captureWithFrame = widget.resultData["capture_with_frame"] == true;

    final pd = widget.resultData["pd"];
    final eyes = widget.resultData["eyes"];
    final img = widget.resultData["image"];

    imgW = (img["width"] as num).toDouble();
    imgH = (img["height"] as num).toDouble();
    mmPerPx = (pd["scale_mm_per_px"] as num).toDouble();

    basePdLeft = (pd["left_mm"] as num).toDouble();
    basePdRight = (pd["right_mm"] as num).toDouble();
    basePdTotal = (pd["total_mm"] as num).toDouble();

    baseLeftPx = Offset(
      (eyes["left_center_px"][0] as num).toDouble(),
      (eyes["left_center_px"][1] as num).toDouble(),
    );
    baseRightPx = Offset(
      (eyes["right_center_px"][0] as num).toDouble(),
      (eyes["right_center_px"][1] as num).toDouble(),
    );

    leftPx = baseLeftPx;
    rightPx = baseRightPx;

    pdLeft = basePdLeft;
    pdRight = basePdRight;
    pdTotal = basePdTotal;

    // ================= FRAME INIT (STATIC ONLY) =================
    if (captureWithFrame) {
      A = STATIC_A_MM;
      B = STATIC_B_MM;
      DBL = STATIC_DBL_MM;

      final wPx = A / mmPerPx;
      final hPx = B / mmPerPx;
      final verticalShift = imgH * 0.10;

      leftFramePx = Rect.fromCenter(
        center: Offset(imgW * 0.35, imgH * 0.5 - verticalShift),
        width: wPx,
        height: hPx,
      );

      rightFramePx = Rect.fromCenter(
        center: Offset(
          imgW * 0.35 + wPx + (DBL / mmPerPx),
          imgH * 0.5 - verticalShift,
        ),
        width: wPx,
        height: hPx,
      );
    }
  }

  void _recomputePD() {
    final leftDxPx = leftPx.dx - baseLeftPx.dx;
    final rightDxPx = rightPx.dx - baseRightPx.dx;

    final leftDeltaMm = leftDxPx.abs() * mmPerPx;
    final rightDeltaMm = rightDxPx.abs() * mmPerPx;

    pdLeft =
        leftDxPx >= 0 ? basePdLeft - leftDeltaMm : basePdLeft + leftDeltaMm;
    pdRight =
        rightDxPx >= 0 ? basePdRight + rightDeltaMm : basePdRight - rightDeltaMm;

    pdTotal = pdLeft + pdRight;
  }

  void _recomputeFrame() {
    if (!captureWithFrame) return;
    if (leftFramePx == null || rightFramePx == null) return;

    A = leftFramePx!.width * mmPerPx;
    B = leftFramePx!.height * mmPerPx;
    DBL = (rightFramePx!.left - leftFramePx!.right) * mmPerPx;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Measurement Result",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _modeButton(
                    "Adjust PD",
                    mode == AdjustMode.pd,
                    () => setState(() => mode = AdjustMode.pd),
                  ),
                ),
                if (captureWithFrame) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeButton(
                      "Adjust Frame",
                      mode == AdjustMode.frame,
                      () => setState(() => mode = AdjustMode.frame),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: imgW / imgH,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final scale = c.maxWidth / imgW;
                    final dx = (c.maxWidth - imgW * scale) / 2;
                    final dy = (c.maxHeight - imgH * scale) / 2;

                    Offset toUi(Offset p) =>
                        Offset(dx + p.dx * scale, dy + p.dy * scale);
                    Offset toImg(Offset p) =>
                        Offset((p.dx - dx) / scale, (p.dy - dy) / scale);

                    Rect toUiRect(Rect r) => Rect.fromLTWH(
                          dx + r.left * scale,
                          dy + r.top * scale,
                          r.width * scale,
                          r.height * scale,
                        );
                    Rect toImgRect(Rect r) => Rect.fromLTWH(
                          (r.left - dx) / scale,
                          (r.top - dy) / scale,
                          r.width / scale,
                          r.height / scale,
                        );

                    return InteractiveViewer(
                      transformationController: zoomCtrl,
                      minScale: 1,
                      maxScale: 5,
                      child: Stack(
                        children: [
                          Image.memory(widget.capturedImage),

                          _pdMarker(
                            toUi(leftPx),
                            mode == AdjustMode.pd,
                            (p) => setState(() {
                              leftPx = toImg(p);
                              _recomputePD();
                            }),
                          ),
                          _pdMarker(
                            toUi(rightPx),
                            mode == AdjustMode.pd,
                            (p) => setState(() {
                              rightPx = toImg(p);
                              _recomputePD();
                            }),
                          ),

                          if (captureWithFrame && leftFramePx != null)
                            _frameBox(
                              toUiRect(leftFramePx!),
                              mode == AdjustMode.frame,
                              (r) => setState(() {
                                leftFramePx = toImgRect(r);
                                _recomputeFrame();
                              }),
                            ),

                          if (captureWithFrame && rightFramePx != null)
                            _frameBox(
                              toUiRect(rightFramePx!),
                              mode == AdjustMode.frame,
                              (r) => setState(() {
                                rightFramePx = toImgRect(r);
                                _recomputeFrame();
                              }),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _card("PD R", pdRight),
                _card("PD L", pdLeft),
                _card("PD T", pdTotal),
              ],
            ),
            if (captureWithFrame) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _card("A", A),
                  _card("B", B),
                  _card("DBL", DBL),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text("Continue"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinalResultScreen(
                        image: widget.capturedImage,
                        pxPerMm: mmPerPx,
                        A: A,
                        B: B,
                        DBL: DBL,
                        pdLeft: pdLeft,
                        pdRight: pdRight,
                        pdTotal: pdTotal,
                        leftEyePx: leftPx,
                        rightEyePx: rightPx,
                        leftFramePx:
                            captureWithFrame ? leftFramePx : null,
                        rightFramePx:
                            captureWithFrame ? rightFramePx : null,
                        imageWidth: imgW,
                        imageHeight: imgH,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _pdMarker(Offset p, bool active, ValueChanged<Offset> onMove) =>
      Positioned(
        left: p.dx - 6,
        top: p.dy - 6,
        child: IgnorePointer(
          ignoring: !active,
          child: GestureDetector(
            onPanUpdate:
                active ? (d) => onMove(p + d.delta) : null,
            child: const Icon(Icons.add,
                size: 14, color: Color(0xFF1AFF00)),
          ),
        ),
      );

  Widget _frameBox(Rect r, bool active, ValueChanged<Rect> onUpdate) {
    const handle = 6.0;
    return Positioned(
      left: r.left,
      top: r.top,
      child: IgnorePointer(
        ignoring: !active,
        child: Opacity(
          opacity: active ? 1 : 0.6,
          child: Stack(children: [
            GestureDetector(
              onPanUpdate: (d) => onUpdate(r.shift(d.delta)),
              child: Container(
                width: r.width,
                height: r.height,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color(0xFF1AFF00)),
                ),
              ),
            ),
            for (final dx in [-3.0, r.width - 3])
              for (final dy in [-3.0, r.height - 3])
                Positioned(
                  left: dx,
                  top: dy,
                  child: GestureDetector(
                    onPanUpdate: (d) => onUpdate(
                      Rect.fromLTRB(
                        r.left,
                        r.top,
                        r.right + d.delta.dx,
                        r.bottom + d.delta.dy,
                      ),
                    ),
                    child: Container(
                      width: handle,
                      height: handle,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1AFF00),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
          ]),
        ),
      ),
    );
  }

  Widget _modeButton(String t, bool a, VoidCallback onTap) =>
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: a ? Colors.greenAccent : Colors.grey.shade800,
          foregroundColor: Colors.black,
        ),
        child: Text(t),
      );

  Widget _card(String l, double v) => Expanded(
        child: Card(
          color: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(l, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(v.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
}
