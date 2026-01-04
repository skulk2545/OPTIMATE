import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'result_pdf.dart';

class FinalResultScreen extends StatefulWidget {
  final Uint8List image;
  final double pxPerMm;

  // AUTO VALUES
  final double A;
  final double B;
  final double DBL;
  final double pdLeft;
  final double pdRight;
  final double pdTotal;

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
  });

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  late final Uint8List croppedImage;
  bool manualEntry = false;

  // MANUAL CONTROLLERS (SEPARATE)
  final aCtrl = TextEditingController();
  final bCtrl = TextEditingController();
  final dblCtrl = TextEditingController();
  final pdLCtrl = TextEditingController();
  final pdRCtrl = TextEditingController();
  final pdTCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    croppedImage = _cropImage();

    // preload manual fields (copy only)
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

  // ---------------- CROP ----------------
  Uint8List _cropImage() {
    final decoded = img.decodeImage(widget.image)!;

    final topPx = 300 * widget.pxPerMm;
    final bottomPx = 480 * widget.pxPerMm;

    double top = topPx;
    double bottom = decoded.height - bottomPx;

    top = top.clamp(0, decoded.height.toDouble());
    bottom = bottom.clamp(0, decoded.height.toDouble());

    final cropH = (bottom - top).round();
    if (cropH <= 0) return widget.image;

    final cropped = img.copyCrop(
      decoded,
      x: 0,
      y: top.round(),
      width: decoded.width,
      height: cropH,
    );

    return Uint8List.fromList(img.encodePng(cropped));
  }

  // ---------------- SAVE & OPEN PDF (MIUI SAFE) ----------------
  Future<void> _openPdf() async {
    final pdfBytes = await ResultPdfGenerator.generate(
      image: croppedImage,
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

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F0C),
        title: const Text("Result – Image & Readings"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _openPdf,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ---------- IMAGE CARD ----------
              Container(
                height: h * 0.28,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF050505),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    croppedImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---------- AUTO VALUE CARDS ----------
              Row(
                children: [
                  _valueCard(
                    title: "PD Values (Auto)",
                    rows: {
                      
                      "R-PD": widget.pdRight,
                      "L-PD": widget.pdLeft,
                      "Total": widget.pdTotal,
                    },
                  ),
                  const SizedBox(width: 16),
                  _valueCard(
                    title: "A / B / DBL (Auto)",
                    rows: {
                      "A": widget.A,
                      "B": widget.B,
                      "DBL": widget.DBL,
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------- MANUAL TOGGLE ----------
              _toggleRow(),

              if (manualEntry) ...[
                const SizedBox(height: 20),
                _manualEntryCard(),
              ],

              const SizedBox(height: 30),

              // ---------- OPEN PDF ----------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Open PDF Report"),
                  onPressed: _openPdf,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

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
          const Text(
            "Manual Entry",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Manual Measurements",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _rowInputs(["A", "B", "DBL"], [aCtrl, bCtrl, dblCtrl]),
          const SizedBox(height: 12),
          _rowInputs(
            ["R-PD", "L-PD", "Total PD"],
            [pdLCtrl, pdRCtrl, pdTCtrl],
          ),
        ],
      ),
    );
  }

  Widget _rowInputs(
    List<String> labels,
    List<TextEditingController> ctrls,
  ) {
    return Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 10 : 0),
            child: TextField(
              controller: ctrls[i],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: labels[i],
                labelStyle: const TextStyle(color: Colors.white70),
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

  Widget _valueCard({
    required String title,
    required Map<String, double> rows,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...rows.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${e.value.toStringAsFixed(1)} mm",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
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
}
