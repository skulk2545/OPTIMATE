import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img hide Image;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'result_pdf.dart';
import 'landing_page.dart';

class FinalResultScreen extends StatefulWidget {
  final Uint8List image;
  final double pxPerMm;

  final double A, B, DBL;
  final double pdLeft, pdRight, pdTotal;

  final Offset leftEyePx;
  final Offset rightEyePx;

  final Rect? leftFramePx;
  final Rect? rightFramePx;

  final double imageWidth;
  final double imageHeight;

  const FinalResultScreen({
    super.key,
    required this.image,
    required this.pxPerMm,
    required this.A,
    required this.B,
    required this.DBL,
    required this.pdLeft,
    required this.pdRight,
    required this.pdTotal,
    required this.leftEyePx,
    required this.rightEyePx,
    required this.leftFramePx,
    required this.rightFramePx,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  late Uint8List displayImage;
  late Uint8List pdfImage;

  late double displayHeight;
  late double topCropPx;

  bool manualEntry = false;

  final aCtrl = TextEditingController();
  final bCtrl = TextEditingController();
  final dblCtrl = TextEditingController();
  final pdLCtrl = TextEditingController();
  final pdRCtrl = TextEditingController();
  final pdTCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    displayImage = _cropForDisplay();
    pdfImage = _cropForPdf();

    aCtrl.text = widget.A.toStringAsFixed(1);
    bCtrl.text = widget.B.toStringAsFixed(1);
    dblCtrl.text = widget.DBL.toStringAsFixed(1);
    pdLCtrl.text = widget.pdLeft.toStringAsFixed(1);
    pdRCtrl.text = widget.pdRight.toStringAsFixed(1);
    pdTCtrl.text = widget.pdTotal.toStringAsFixed(1);
  }

  @override
  void dispose() {
    aCtrl.dispose();
    bCtrl.dispose();
    dblCtrl.dispose();
    pdLCtrl.dispose();
    pdRCtrl.dispose();
    pdTCtrl.dispose();
    super.dispose();
  }

  // ==========================================================
  // DISPLAY CROP (TOP 40mm, BOTTOM 140mm)
  // ==========================================================
  Uint8List _cropForDisplay() {
    final decoded = img.decodeImage(widget.image);
    if (decoded == null) {
      topCropPx = 0;
      displayHeight = widget.imageHeight;
      return widget.image;
    }

    const topMm = 440.0;
    const bottomMm = 750.0;

    topCropPx = topMm * widget.pxPerMm;
    final bottomPx = bottomMm * widget.pxPerMm;

    final imgH = decoded.height.toDouble();

    final safeTop = topCropPx.clamp(0, imgH - 1);
    final safeBottom = (imgH - bottomPx).clamp(safeTop + 1, imgH);

    final cropH = (safeBottom - safeTop).round();
    displayHeight = cropH.toDouble();

    final cropped = img.copyCrop(
      decoded,
      x: 0,
      y: safeTop.round(),
      width: decoded.width,
      height: cropH,
    );

    return Uint8List.fromList(img.encodePng(cropped));
  }

  // ==========================================================
  // PDF CROP (SAFE — NEVER FAILS SILENTLY)
  // ==========================================================
  Uint8List _cropForPdf() {
    final decoded = img.decodeImage(widget.image);
    if (decoded == null) return widget.image;

    const topMm = 30.0;
    const bottomMm = 48.0;

    final topPx = topMm * widget.pxPerMm;
    final bottomPx = bottomMm * widget.pxPerMm;

    final imgH = decoded.height.toDouble();

    final safeTop = topPx.clamp(0, imgH - 1);
    final safeBottom = (imgH - bottomPx).clamp(safeTop + 1, imgH);

    final cropH = (safeBottom - safeTop).round();

    if (cropH <= 1) return widget.image;

    final cropped = img.copyCrop(
      decoded,
      x: 0,
      y: safeTop.round(),
      width: decoded.width,
      height: cropH,
    );

    return Uint8List.fromList(img.encodePng(cropped));
  }

  // ==========================================================
  // OPEN PDF
  // ==========================================================
  Future<void> _openPdf() async {
    final pdfBytes = await ResultPdfGenerator.generate(
      image: pdfImage, // ✅ CROPPED IMAGE PASSED
      A: widget.A,
      B: widget.B,
      DBL: widget.DBL,
      pdLeft: widget.pdLeft,
      pdRight: widget.pdRight,
      pdTotal: widget.pdTotal,
      manualValues: manualEntry
          ? {
              "A (mm)": double.tryParse(aCtrl.text) ?? widget.A,
              "B (mm)": double.tryParse(bCtrl.text) ?? widget.B,
              "DBL (mm)": double.tryParse(dblCtrl.text) ?? widget.DBL,
              "PD Right (mm)": double.tryParse(pdRCtrl.text) ?? widget.pdRight,
              "PD Left (mm)": double.tryParse(pdLCtrl.text) ?? widget.pdLeft,
              "PD Total (mm)": double.tryParse(pdTCtrl.text) ?? widget.pdTotal,
            }
          : null,
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      "${dir.path}/optical_report_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );

    await file.writeAsBytes(pdfBytes);
    await OpenFilex.open(file.path);
  }

  void _goToLanding() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final showFrame =
        widget.leftFramePx != null && widget.rightFramePx != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F0C),
        title: const Text("Result – Image & Readings"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: widget.imageWidth / displayHeight,
              child: LayoutBuilder(
                builder: (context, c) {
                  final scale = c.maxWidth / widget.imageWidth;
                  final dx =
                      (c.maxWidth - widget.imageWidth * scale) / 2;
                  final dy =
                      (c.maxHeight - displayHeight * scale) / 2;

                  Offset toUi(Offset p) => Offset(
                        dx + p.dx * scale,
                        dy + (p.dy - topCropPx) * scale,
                      );

                  Rect toUiRect(Rect r) => Rect.fromLTWH(
                        dx + r.left * scale,
                        dy + (r.top - topCropPx) * scale,
                        r.width * scale,
                        r.height * scale,
                      );

                  return Stack(
                    children: [
                      Image.memory(displayImage, fit: BoxFit.contain),
                      _pdMarker(toUi(widget.leftEyePx)),
                      _pdMarker(toUi(widget.rightEyePx)),
                      if (showFrame) ...[
                        _frameBox(toUiRect(widget.leftFramePx!)),
                        _frameBox(toUiRect(widget.rightFramePx!)),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                _valueCard("PD Values", {
                  "Right": widget.pdRight,
                  "Left": widget.pdLeft,
                  "Total": widget.pdTotal,
                }),
                const SizedBox(width: 14),
                if (showFrame)
                  _valueCard("Frame", {
                    "A": widget.A,
                    "B": widget.B,
                    "DBL": widget.DBL,
                  }),
              ],
            ),

            const SizedBox(height: 20),

            _toggleRow(),

            if (manualEntry) ...[
              const SizedBox(height: 14),
              _manualEntryCard(),
            ],

            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Open PDF"),
                    onPressed: _openPdf,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 239, 225, 240),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Done"),
                    onPressed: _goToLanding,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================
  Widget _pdMarker(Offset p) => Positioned(
        left: p.dx - 10,
        top: p.dy - 10,
        child: const Icon(
          Icons.add,
          size: 20,
          color: Color(0xFF1AFF00),
        ),
      );

  Widget _frameBox(Rect r) => Positioned(
        left: r.left,
        top: r.top,
        child: Container(
          width: r.width,
          height: r.height,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1AFF00)),
          ),
        ),
      );

  Widget _valueCard(String title, Map<String, double> rows) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            ...rows.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key,
                        style:
                            const TextStyle(color: Colors.white70)),
                    Text(
                      e.value.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Manual Entry",
              style:
                  TextStyle(color: Colors.white, fontSize: 16)),
          Switch(
            value: manualEntry,
            activeThumbColor: Colors.greenAccent,
            onChanged: (v) => setState(() => manualEntry = v),
          ),
        ],
      ),
    );
  }

  Widget _manualEntryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _rowInputs(["A", "B", "DBL"], [aCtrl, bCtrl, dblCtrl]),
          const SizedBox(height: 12),
          _rowInputs(
            ["R-PD", "L-PD", "Total"],
            [pdRCtrl, pdLCtrl, pdTCtrl],
          ),
        ],
      ),
    );
  }

  Widget _rowInputs(
      List<String> labels, List<TextEditingController> ctrls) {
    return Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: i < labels.length - 1 ? 10 : 0),
            child: TextField(
              controller: ctrls[i],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: labels[i],
                labelStyle:
                    const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
