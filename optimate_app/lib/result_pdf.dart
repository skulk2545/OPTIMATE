import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img hide Image;

class ResultPdfGenerator {
  static Future<Uint8List> generate({
    required Uint8List image,
    required double A,
    required double B,
    required double DBL,
    required double pdLeft,
    required double pdRight,
    required double pdTotal,
    Map<String, double>? manualValues,
  }) async {
    final pdf = pw.Document();

    // =========================================================
    // ✅ HARD CROP INSIDE PDF (TOP & BOTTOM)
    // =========================================================
    final decoded = img.decodeImage(image);
    if (decoded == null) {
      throw Exception("PDF image decode failed");
    }

    const double cropTop = 200.0;
    const double cropBottom = 380.0;

    final imgH = decoded.height.toDouble();

    final safeTop = cropTop.clamp(0, imgH - 1);
    final safeBottom =
        (imgH - cropBottom).clamp(safeTop + 1, imgH);

    final cropHeight = (safeBottom - safeTop).round();

    final cropped = img.copyCrop(
      decoded,
      x: 0,
      y: safeTop.round(),
      width: decoded.width,
      height: cropHeight,
    );

    final fixedBytes = Uint8List.fromList(
      img.encodePng(cropped),
    );

    final mainImg = pw.MemoryImage(fixedBytes);

    // =========================================================
    // LOAD LOGO (SAFE)
    // =========================================================
    pw.MemoryImage? logoImg;
    try {
      final data =
          await rootBundle.load('assets/images/OPTIFOCUS_LOGO.png');
      logoImg = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logoImg = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 50),

        // ================= HEADER =================
        header: (_) => pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text(
            "FOR BETA TESTING",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        ),

        // ================= FOOTER =================
        footer: (_) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            "© copyright 2026 Optifocus Pvt. Ltd.",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),

        build: (_) => [
          if (logoImg != null) ...[
            pw.Center(child: pw.Image(logoImg, height: 160)),
            pw.SizedBox(height: 8),
          ],

          pw.Center(
            child: pw.Text(
              "Optical Measurement Report",
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 20),

          // ================= CROPPED IMAGE =================
          pw.Container(
            height: 220,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Image(
              mainImg,
              fit: pw.BoxFit.contain,
            ),
          ),

          pw.SizedBox(height: 24),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _table(
                  "PD Measurements (Auto)",
                  {
                    "PD Right (mm)": pdRight,
                    "PD Left (mm)": pdLeft,
                    "PD Total (mm)": pdTotal,
                  },
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _table(
                  "Frame Measurements (Auto)",
                  {
                    "A (mm)": A,
                    "B (mm)": B,
                    "DBL (mm)": DBL,
                  },
                ),
              ),
            ],
          ),

          if (manualValues != null) ...[
            pw.SizedBox(height: 28),
            pw.Text(
              "Manual Measurements",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _table(
                    "PD (Manual)",
                    {
                      "PD Right (mm)": manualValues["PD Right (mm)"]!,
                      "PD Left (mm)": manualValues["PD Left (mm)"]!,
                      "PD Total (mm)": manualValues["PD Total (mm)"]!,
                    },
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _table(
                    "Frame (Manual)",
                    {
                      "A (mm)": manualValues["A (mm)"]!,
                      "B (mm)": manualValues["B (mm)"]!,
                      "DBL (mm)": manualValues["DBL (mm)"]!,
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // =========================================================
  static pw.Widget _table(String title, Map<String, double> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey400,
            width: 0.8,
          ),
          children: rows.entries.map(
            (e) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.key),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    e.value.toStringAsFixed(1),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ).toList(),
        ),
      ],
    );
  }
}
